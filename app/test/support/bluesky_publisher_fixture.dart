import 'dart:convert';
import 'dart:io';

import 'package:atproto_core/atproto_core.dart';
import 'package:crypto/crypto.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/bluesky_publisher.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/review/review.dart';

import 'account_fixture.dart';
import 'bluesky_fixture.dart';

class BlueskyPublisherHarness {
  BlueskyPublisherHarness(this.account);
  final HostedBlueskyHarness account;
  late BlueskyPublisher provider;
  late Map<String, dynamic> protocol;
  late ResolvedPost textPost, photoPost;
  final uploadState = <String, String>{};
  final phases = <String>[];
  int createRequestCount = 0, uploads = 0, lookups = 0;
  bool createResponseLost = false, recordExists = true, alterRecord = false;
  bool wrongReceipt = false, denyUpload = false, unresolved = false;
  bool wrongCid = false, createNonceChallenge = false, ambiguousReceipt = false;
  int createStatus = 200;
  String createError = 'InvalidSwap';
  bool canUpload = true, emailConfirmed = true;
  bool wrappedVideoUpload = true,
      reuseBlob = false,
      malformedVideo = false,
      errorVideo = false,
      mixedVideo = false;
  String videoState = 'JOB_STATE_ENCODING';
  int videoUploads = 0, videoPolls = 0;
  Map<String, dynamic>? created;
  Future<void> Function()? onMarkDispatch;
  Future<void> Function(String, String)? beforeSave;
  final blobCid = computeRecordCid({'\$type': 'fixture.blob', 'text': 'owned'});
  PublishContext get context => PublishContext(
    attemptId: 'attempt-bluesky-1',
    uploadState: uploadState,
    markDispatch: () async {
      await onMarkDispatch?.call();
      phases.add('dispatch');
    },
    saveUpload: (k, v) async {
      await beforeSave?.call(k, v);
      uploadState[k] = v;
      phases.add(k);
    },
  );
  Map<String, dynamic> get blob => {
    '\$type': 'blob',
    'ref': {'\$link': blobCid},
    'mimeType': 'image/png',
    'size': photoPost.assets.first.bytes,
  };
  Future<void> initialize() async {
    protocol = jsonDecode(
      await File('test/fixtures/providers/bluesky/protocol.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    await account.connect();
    final asset = await account.fixture.files.importFile(
      await account.fixture.photo('bsky.png'),
    );
    textPost = ResolvedPost(
      destination: Destination.bluesky,
      content: PostContent(
        text: '  Caption e\u0301 👩🏽‍🚀\nhttps://example.com/long/path  ',
      ),
      ownCaption: false,
      assets: [],
      account: (await account.accounts.get(Destination.bluesky)).identity,
    );
    photoPost = textPost.copyWith(
      content: PostContent(
        text: textPost.content.text,
        media: [Attachment(assetId: asset.id, altText: 'A fixture photo')],
      ),
      assets: [asset],
    );
    account.override = (request) {
      final path = request.url.path;
      if (path == '/xrpc/com.atproto.identity.resolveHandle' &&
          request.url.host != 'public.api.bsky.app') {
        return account.json(
          unresolved ? {'error': 'HandleNotFound'} : {'did': blueskyDid},
          status: unresolved ? 400 : 200,
          signed: true,
          path: path,
        );
      }
      if (path == '/xrpc/com.atproto.server.getSession') {
        return account.json(
          {
            'did': blueskyDid,
            'handle': 'person.test',
            'email': 'private@example.test',
            'emailConfirmed': emailConfirmed,
          },
          signed: true,
          path: path,
        );
      }
      if (path == '/xrpc/com.atproto.server.getServiceAuth') {
        return account.json(
          {'token': 'synthetic-service-${request.url.queryParameters['lxm']}'},
          signed: true,
          path: path,
        );
      }
      if (path == '/xrpc/app.bsky.video.getUploadLimits') {
        return account.json({
          'canUpload': canUpload,
          'remainingDailyVideos': 2,
          'remainingDailyBytes': 5000,
        });
      }
      if (path == '/xrpc/app.bsky.video.uploadVideo') {
        videoUploads++;
        return account.json(
          (errorVideo || mixedVideo)
              ? {'error': 'synthetic', 'jobStatus': job}
              : malformedVideo
              ? {'jobStatus': {}}
              : wrappedVideoUpload
              ? {'jobStatus': job}
              : job,
          status: errorVideo ? 400 : 200,
        );
      }
      if (path == '/xrpc/app.bsky.video.getJobStatus') {
        videoPolls++;
        return account.json({'jobStatus': job});
      }
      if (path == '/xrpc/com.atproto.repo.uploadBlob') {
        uploads++;
        phases.add('upload');
        return account.json(
          denyUpload
              ? {'error': 'BlobTooLarge'}
              : {
                  'blob': {
                    ...blob,
                    'size': request.bodyBytes.length,
                    'ref': {
                      '\$link': CID
                          .createFromBytes(request.bodyBytes, Multicodec.raw)
                          .toString(),
                    },
                  },
                },
          status: denyUpload ? 400 : 200,
          signed: true,
          path: path,
        );
      }
      if (path == '/xrpc/com.atproto.repo.createRecord') {
        createRequestCount++;
        phases.add('create');
        created = jsonDecode(request.body) as Map<String, dynamic>;
        if (createNonceChallenge && createRequestCount == 1) {
          return account.json(
            {'error': 'use_dpop_nonce'},
            status: 401,
            signed: true,
            path: path,
          );
        }
        if (createResponseLost) {
          throw const SocketException('synthetic response loss');
        }
        if (createStatus != 200) {
          return account.json(
            {'error': createError},
            status: createStatus,
            signed: true,
            path: path,
          );
        }
        return account.json(
          {
            if (ambiguousReceipt) 'errors': 'synthetic ambiguous envelope',
            'uri': uri.replaceFirst(
              blueskyDid,
              wrongReceipt ? 'did:plc:wrong' : blueskyDid,
            ),
            'cid': wrongCid
                ? blobCid
                : computeRecordCid(created!['record'] as Map<String, dynamic>),
          },
          signed: true,
          path: path,
        );
      }
      if (path == '/xrpc/com.atproto.repo.getRecord') {
        lookups++;
        if (!recordExists) {
          return account.json(
            {'error': 'RecordNotFound'},
            status: 400,
            signed: true,
            path: path,
          );
        }
        final value = Map<String, dynamic>.from(created!['record'] as Map);
        if (alterRecord) value['text'] = 'Different content';
        return account.json(
          {'uri': uri, 'cid': computeRecordCid(value), 'value': value},
          signed: true,
          path: path,
        );
      }
      return null;
    };
    provider = BlueskyPublisher(
      connection: account.connection,
      media: account.fixture.files,
      capabilities: ProviderCapabilities(
        destination: Destination.bluesky,
        version: 'SYNTHETIC-only',
        verifiedAt: account.clock.now(),
        status: CapabilityStatus.current,
        text: true,
        photos: true,
        video: false,
        maxPhotos: 4,
        maxTextUnits: 300,
        maxTextBytes: 3000,
        maxPhotoBytes: 2000000,
        maxVideoBytes: 0,
        maxVideoDurationMs: 0,
        mimeTypes: {'image/png', 'image/jpeg'},
      ),
      clock: account.clock,
    );
  }

  Map<String, dynamic> get job => {
    ...Map<String, dynamic>.from(protocol['videoJob'] as Map),
    'state': videoState,
    if (reuseBlob) 'error': 'already_exists',
    if (videoState == 'JOB_STATE_COMPLETED' || reuseBlob)
      'blob': {
        '\$type': 'blob',
        'ref': {'\$link': blobCid},
        'mimeType': 'video/mp4',
        'size': 40,
      },
  };
  Future<void> prepareVideo() async {
    final bytes = List<int>.generate(40, (i) => i);
    const id = 'synthetic-bsky-video';
    final file = File('${account.fixture.files.root.path}/assets/$id');
    await file.writeAsBytes(bytes);
    final asset = MediaAsset(
      id: id,
      relativePath: 'assets/$id',
      mimeType: 'video/mp4',
      bytes: 40,
      sha256: sha256.convert(bytes).toString(),
      width: 64,
      height: 64,
      durationMs: 1000,
    );
    await account.fixture.database.db.insert('assets', {
      'id': id,
      'payload': jsonEncode(asset.toJson()),
    });
    photoPost = textPost.copyWith(
      content: PostContent(
        text: '',
        media: [const Attachment(assetId: id, altText: 'A synthetic video')],
      ),
      assets: [asset],
    );
    provider = BlueskyPublisher(
      connection: account.connection,
      media: account.fixture.files,
      clock: account.clock,
      capabilities: ProviderCapabilities(
        destination: Destination.bluesky,
        version: 'SYNTHETIC-video-only',
        verifiedAt: account.clock.now(),
        status: CapabilityStatus.current,
        text: true,
        photos: true,
        video: true,
        maxPhotos: 4,
        maxTextUnits: 300,
        maxTextBytes: 3000,
        maxPhotoBytes: 2000000,
        maxVideoBytes: 5000000,
        maxVideoDurationMs: 60000,
        mimeTypes: {'image/png', 'image/jpeg', 'video/mp4'},
      ),
    );
  }

  String get uri => 'at://$blueskyDid/app.bsky.feed.post/${created!['rkey']}';
  Future<void> close() => account.close();
}

Future<BlueskyPublisherHarness> blueskyPublisherHarness({
  bool createResponseLost = false,
  bool recordExists = true,
}) async {
  final h = BlueskyPublisherHarness(await HostedBlueskyHarness.create())
    ..createResponseLost = createResponseLost
    ..recordExists = recordExists;
  await h.initialize();
  return h;
}
