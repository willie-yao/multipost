import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/publisher_fixture.dart';

// Synthetic owned MP4 bytes and measured metadata. This does not claim codec,
// device, provider entitlement, or live video acceptance.
Future<void> videoPost(XPublisherHarness h) async {
  final bytes = List<int>.generate(40, (i) => i);
  const id = 'synthetic-video';
  final file = File('${h.account.fixture.files.root.path}/assets/$id');
  await file.writeAsBytes(bytes);
  final asset = MediaAsset(
    id: id,
    relativePath: 'assets/$id',
    mimeType: 'video/mp4',
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    width: 64,
    height: 64,
    durationMs: 1000,
  );
  await h.account.fixture.database.db.insert('assets', {
    'id': id,
    'payload': jsonEncode(asset.toJson()),
  });
  h.photoPost = h.textPost.copyWith(
    content: PostContent(
      text: '',
      media: [const Attachment(assetId: id, altText: 'A synthetic video')],
    ),
    assets: [asset],
  );
}

void main() {
  test(
    'video initializes appends finalizes then creates after metadata',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      await videoPost(h);
      final result = await h.provider.send(h.photoPost, h.context());
      expect(result.status, PublishStatus.published);
      expect(h.requests.map((r) => r.url.path), [
        '/2/media/upload/initialize',
        '/2/media/upload/201/append',
        '/2/media/upload/201/finalize',
        '/2/media/metadata',
        '/2/tweets',
      ]);
      expect(jsonDecode(h.requests.first.body), {
        'media_type': 'video/mp4',
        'media_category': 'tweet_video',
        'total_bytes': 40,
      });
      expect(h.requests[1].body, contains('name="segment_index"\r\n\r\n0'));
      expect(
        h.requests[1].bodyBytes,
        containsAllInOrder(List<int>.generate(40, (i) => i)),
      );
      expect(jsonDecode(h.requests.last.body), {
        'text': '',
        'media': {
          'media_ids': ['201'],
        },
      });
    },
  );
  test(
    'processing is persisted and checked after restart without reupload',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      await videoPost(h);
      h.processingState = 'in_progress';
      final processing = await h.provider.send(h.photoPost, h.context());
      expect(processing.status, PublishStatus.processing);
      expect(h.createRequestCount, 0);
      expect(h.dispatchMarked, isFalse);
      expect(h.uploadState.values.single, contains('201'));
      final count = h.requests.length;
      expect(
        (await h.provider.check(h.photoPost, processing, h.context())).status,
        PublishStatus.processing,
      );
      expect(h.requests.length, count);
      h.account.clock.value = h.account.clock.value.add(
        const Duration(seconds: 1),
      );
      h.processingState = 'succeeded';
      final ready = await h.provider.check(
        h.photoPost,
        processing,
        h.context(),
      );
      expect(ready.status, PublishStatus.processing);
      expect(ready.reasonCode, 'preparation-ready');
      expect(h.createRequestCount, 0);
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.published,
      );
      expect(
        h.requests.where((r) => r.url.path.endsWith('/initialize')).length,
        1,
      );
      expect(
        h.requests.singleWhere((r) => r.method == 'GET').url.queryParameters,
        {'command': 'STATUS', 'media_id': '201'},
      );
    },
  );
  test(
    'explicit send continuation polls only when due and reuses saved upload',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      await videoPost(h);
      h.processingState = 'in_progress';
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.processing,
      );
      final requestCount = h.requests.length;
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.processing,
      );
      expect(h.requests.length, requestCount);
      h.account.clock.value = h.account.clock.value.add(
        const Duration(seconds: 1),
      );
      h.processingState = 'succeeded';
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.published,
      );
      expect(
        h.requests.where((r) => r.url.path.endsWith('/initialize')),
        hasLength(1),
      );
      expect(
        h.requests.singleWhere((r) => r.method == 'GET').url.queryParameters,
        {'command': 'STATUS', 'media_id': '201'},
      );
      expect(
        jsonDecode(h.uploadState['x.media.synthetic-video']!)['state'],
        'succeeded',
      );
      expect(h.createRequestCount, 1);
    },
  );
  test(
    'failed processing stays a safe failure across reconstructed contexts',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      await videoPost(h);
      h.processingState = 'failed';
      final failed = await h.provider.send(h.photoPost, h.context());
      expect(failed.status, PublishStatus.notPublished);
      expect(h.createRequestCount, 0);
      final count = h.requests.length;
      h.processingState = 'succeeded';
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.notPublished,
      );
      expect(h.requests.length, count);
    },
  );
  test(
    'entire photo set is verified before any upload and media-only photos work',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      final second = await h.account.fixture.files.importFile(
        await h.account.fixture.photo('set-second.png'),
      );
      final photo = h.photoPost;
      final set = photo.copyWith(
        content: PostContent(
          text: '',
          media: [
            ...photo.content.media,
            Attachment(assetId: second.id),
          ],
        ),
        assets: [...photo.assets, second],
      );
      expect(
        (await h.provider.send(set, h.context())).status,
        PublishStatus.published,
      );
      expect((jsonDecode(h.requests.last.body) as Map)['media'], {
        'media_ids': ['101', '102'],
      });
      final h2 = await xPublisherHarness();
      addTearDown(h2.close);
      final damaged = h2.photoPost.copyWith(
        content: PostContent(
          text: '',
          media: [
            ...h2.photoPost.content.media,
            Attachment(assetId: second.id),
          ],
        ),
        assets: [...h2.photoPost.assets, second],
      );
      expect(
        (await h2.provider.send(damaged, h2.context())).status,
        PublishStatus.notPublished,
      );
      expect(h2.uploads, 0);
    },
  );
}
