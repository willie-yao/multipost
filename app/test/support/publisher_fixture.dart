import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/providers/x_publisher.dart';
import 'package:cross_posting_app/features/providers/x_text_counter.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'account_fixture.dart';

// Synthetic protocol transport only; files and SQLite ownership are real.
class XPublisherHarness {
  XPublisherHarness(this.account, {this.createResponseLost = false});
  final AccountHarness account;
  final bool createResponseLost;
  late final XPublisher provider;
  late final http.Client client;
  late ResolvedPost photoPost;
  late ResolvedPost textPost;
  final requests = <http.Request>[];
  final uploadState = <String, String>{};
  bool dispatchMarked = false;
  int createRequestCount = 0;
  int uploads = 0;
  int? failUpload;
  int metadataStatus = 200;
  int createStatus = 201;
  int lookupStatus = 200;
  String lookupSubject = '12345';
  late String createBody;
  Map<String, String> createHeaders = {};
  String processingState = 'succeeded';
  Future<void> Function(http.Request)? beforeResponse;
  Future<void> Function()? onMarkDispatch;
  final phases = <String>[];

  PublishContext context() => PublishContext(
    attemptId: 'attempt-x-1',
    uploadState: uploadState,
    markDispatch: () async {
      await onMarkDispatch?.call();
      dispatchMarked = true;
      phases.add('dispatch');
    },
    saveUpload: (k, v) async {
      uploadState[k] = v;
      phases.add(k);
    },
  );
  Future<void> initialize() async {
    final protocol = jsonDecode(
      await File('test/fixtures/providers/x/protocol.json').readAsString(),
    ) as Map<String, dynamic>;
    createBody = jsonEncode(protocol['create']);
    await account.x.connect();
    final asset = await account.fixture.files.importFile(
      await account.fixture.photo('publisher.png'),
    );
    final identity = (await account.accounts.get(Destination.x)).identity;
    textPost = ResolvedPost(
      destination: Destination.x,
      content: PostContent(
        text: '  Caption e\u0301 https://example.com/long/path  ',
      ),
      ownCaption: false,
      assets: [],
      account: identity,
    );
    photoPost = textPost.copyWith(
      content: PostContent(
        text: textPost.content.text,
        media: [Attachment(assetId: asset.id, altText: 'A fixture photo')],
      ),
      assets: [asset],
    );
    client = MockClient((request) async {
      requests.add(request);
      await beforeResponse?.call(request);
      final path = request.url.path;
      if (path == '/2/tweets') {
        createRequestCount++;
        phases.add('create');
        if (createResponseLost) throw const SocketException('synthetic loss');
        return http.Response(createBody, createStatus, headers: createHeaders);
      }
      if (path == '/2/tweets/999') {
        return http.Response(
          jsonEncode({
            'data': {
              'id': '999',
              'author_id': lookupSubject,
              'text': 'fixture',
            },
          }),
          lookupStatus,
        );
      }
      if (path == '/2/media/metadata') {
        final id = (jsonDecode(request.body) as Map)['id'];
        return http.Response(
          jsonEncode({
            'data': {'id': id},
          }),
          metadataStatus,
        );
      }
      if (path == '/2/media/upload' && request.method == 'POST') {
        uploads++;
        if (failUpload == uploads) return http.Response('{}', 500);
        final data = Map<String, dynamic>.from(
          (protocol['upload'] as Map)['data'] as Map,
        )..['id'] = '${100 + uploads}';
        return http.Response(jsonEncode({'data': data}), 200);
      }
      if (path.endsWith('/initialize')) {
        return http.Response(jsonEncode(protocol['initialize']), 200);
      }
      if (path.endsWith('/append')) {
        return http.Response(jsonEncode(protocol['append']), 200);
      }
      if (path.endsWith('/finalize') ||
          (path == '/2/media/upload' && request.method == 'GET')) {
        return http.Response(
          jsonEncode({
            'data': {
              'id': '201',
              'expires_after_secs': 86400,
              'processing_info': {
                'state': processingState,
                'check_after_secs': 1,
              },
            },
          }),
          200,
        );
      }
      throw StateError('Unexpected synthetic request: ${request.method} $path');
    });
    provider = XPublisher(
      connection: account.x,
      client: client,
      media: account.fixture.files,
      counter: const FixtureXCounter(),
      capabilities: ProviderCapabilities(
        destination: Destination.x,
        version: 'SYNTHETIC-only',
        verifiedAt: account.clock.now(),
        status: CapabilityStatus.current,
        text: true,
        photos: true,
        video: true,
        maxPhotos: 4,
        maxTextUnits: 280,
        maxPhotoBytes: 5000000,
        maxVideoBytes: 5000000,
        maxVideoDurationMs: 120000,
        mimeTypes: {'image/png', 'image/jpeg', 'video/mp4'},
      ),
      clock: account.clock,
    );
  }

  Future<void> close() async {
    client.close();
    await account.close();
  }
}

class FixtureXCounter implements XTextCounter {
  const FixtureXCounter();
  @override
  TextMeasurement measure(String text) => TextMeasurement(
    units: text.runes.length,
    valid: !text.contains('\uFFFF'),
  );
}

Future<XPublisherHarness> xPublisherHarness({
  bool createResponseLost = false,
}) async {
  final h = XPublisherHarness(
    await accountHarness(),
    createResponseLost: createResponseLost,
  );
  await h.initialize();
  return h;
}
