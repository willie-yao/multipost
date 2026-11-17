import 'dart:async';
import 'dart:convert';

import 'package:cross_posting_app/features/providers/bluesky_publisher.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_fixture.dart';
import '../../support/publisher_fixture.dart';

void main() {
  test('video processing persists then read-only check only prepares explicit continuation', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    await h.prepareVideo();
    final initial = await h.provider.send(h.photoPost, h.context);
    expect(initial.status, PublishStatus.processing);
    expect(h.createRequestCount, 0);
    expect(h.videoUploads, 1);
    final saved = jsonEncode(h.uploadState);
    expect(saved, contains('synthetic-job'));
    expect(saved, isNot(contains('synthetic-service')));
    expect(saved, isNot(contains('private@example.test')));
    h.videoState = 'JOB_STATE_COMPLETED';
    final checked = await h.provider.check(h.photoPost, initial, h.context);
    expect(checked.status, PublishStatus.processing);
    expect(checked.reasonCode, 'preparation-ready');
    expect(h.createRequestCount, 0);
    expect(h.videoUploads, 1);
    expect(h.videoPolls, 1);
    final terminal = h.uploadState['bluesky.video'];
    final repeated = await h.provider.check(h.photoPost, checked, h.context);
    expect(repeated.reasonCode, 'preparation-ready');
    expect(h.videoPolls, 1);
    expect(h.uploadState['bluesky.video'], terminal);
    expect(h.createRequestCount, 0);
    expect(
      (await h.provider.send(h.photoPost, h.context)).status,
      PublishStatus.published,
    );
    expect(h.videoUploads, 1);
    expect(h.createRequestCount, 1);
    expect((h.created!['record'] as Map)['embed']['alt'], 'A synthetic video');
    final requests = h.account.requests;
    final service = requests
        .where((r) => r.url.path.endsWith('getServiceAuth'))
        .toList();
    expect(service.map((r) => r.url.queryParameters['aud']), [
      'did:web:video.bsky.app',
      'did:web:${Uri.parse(blueskyPds).host}',
    ]);
    expect(service.map((r) => r.url.queryParameters['lxm']), [
      'app.bsky.video.getUploadLimits',
      'com.atproto.repo.uploadBlob',
    ]);
    final video = requests
        .where((r) => r.url.host == 'video.bsky.app')
        .toList();
    expect(video.length, 3);
    for (final r in video) {
      expect(
        r.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('dpop')),
      );
      expect(r.headers.values.join(' '), isNot(contains('synthetic-access')));
    }
    expect(
      video[0].headers['authorization'],
      'Bearer synthetic-service-app.bsky.video.getUploadLimits',
    );
    expect(
      video[1].headers['authorization'],
      'Bearer synthetic-service-com.atproto.repo.uploadBlob',
    );
    expect(video[1].headers['content-type'], 'video/mp4');
    expect(video[1].url.queryParameters['did'], blueskyDid);
    expect(video[2].headers['authorization'], isNull);
  });
  test('unverified email and denied limits never upload or create', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    await h.prepareVideo();
    h.emailConfirmed = false;
    expect(
      (await h.provider.send(h.photoPost, h.context)).status,
      PublishStatus.notPublished,
    );
    expect(h.videoUploads, 0);
    expect(h.createRequestCount, 0);
    h.emailConfirmed = true;
    h.canUpload = false;
    expect(
      (await h.provider.send(h.photoPost, h.context)).status,
      PublishStatus.notPublished,
    );
    expect(h.videoUploads, 0);
    expect(h.createRequestCount, 0);
  });
  test(
    'failed and unfamiliar video processing states never claim publication',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      await h.prepareVideo();
      var result = await h.provider.send(h.photoPost, h.context);
      h.videoState = 'FUTURE_STATE';
      result = await h.provider.check(h.photoPost, result, h.context);
      expect(result.status, PublishStatus.processing);
      expect(h.createRequestCount, 0);
      h.videoState = 'JOB_STATE_FAILED';
      result = await h.provider.check(h.photoPost, result, h.context);
      expect(result.status, PublishStatus.notPublished);
      expect(h.createRequestCount, 0);
      expect(h.videoUploads, 1);
    },
  );
  test('bare SDK-guide upload success also starts preparation', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    await h.prepareVideo();
    h.wrappedVideoUpload = false;
    expect(
      (await h.provider.send(h.photoPost, h.context)).status,
      PublishStatus.processing,
    );
  });
  test(
    'malformed and error upload envelopes never create or become ready',
    () async {
      for (final mode in [0, 1, 2]) {
        final h = await blueskyPublisherHarness();
        addTearDown(h.close);
        await h.prepareVideo();
        h.malformedVideo = mode == 0;
        h.errorVideo = mode == 1;
        h.mixedVideo = mode == 2;
        expect(
          (await h.provider.send(h.photoPost, h.context)).status,
          PublishStatus.notPublished,
        );
        expect(h.createRequestCount, 0);
        expect(h.uploadState.containsKey('bluesky.video'), isFalse);
      }
    },
  );
  test(
    'already_exists with matching reusable blob is readiness without create',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      await h.prepareVideo();
      final first = await h.provider.send(h.photoPost, h.context);
      h.videoState = 'JOB_STATE_FAILED';
      h.reuseBlob = true;
      final checked = await h.provider.check(h.photoPost, first, h.context);
      expect(checked.reasonCode, 'preparation-ready');
      expect(h.createRequestCount, 0);
      expect(
        (await h.provider.send(h.photoPost, h.context)).status,
        PublishStatus.published,
      );
      expect(h.videoUploads, 1);
    },
  );
  test('bare video success carrying errors must not dispatch a post', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    await h.prepareVideo();
    h.videoState = 'JOB_STATE_COMPLETED';
    final original = h.account.override!;
    h.account.override = (request) {
      if (request.url.path == '/xrpc/app.bsky.video.uploadVideo') {
        return h.account.json({
          ...h.job,
          'errors': 'synthetic ambiguous envelope',
        });
      }
      return original(request);
    };
    final result = await h.provider.send(h.photoPost, h.context);
    expect(h.createRequestCount, 0, reason: 'ambiguous media must not create');
    expect(result.status, PublishStatus.notPublished);
    expect(h.uploadState.containsKey('bluesky.video'), isFalse);
  });
  for (final contradiction in [
    {'error': 'synthetic encoding error'},
    {'failureCode': 'encoding_failure'},
    {'error': 'already_exists', 'failureCode': 'encoding_failure'},
  ]) {
    test(
      'completed upload rejects contradictory evidence $contradiction',
      () async {
        final h = await blueskyPublisherHarness();
        addTearDown(h.close);
        await h.prepareVideo();
        h.videoState = 'JOB_STATE_COMPLETED';
        final original = h.account.override!;
        h.account.override = (request) {
          if (request.url.path == '/xrpc/app.bsky.video.uploadVideo') {
            return h.account.json({
              'jobStatus': {...h.job, ...contradiction},
            });
          }
          return original(request);
        };
        final result = await h.provider.send(h.photoPost, h.context);
        expect(h.createRequestCount, 0);
        expect(result.status, PublishStatus.notPublished);
        expect(h.uploadState.containsKey('bluesky.video'), isFalse);
      },
    );
  }
  for (final contradiction in [
    {'errors': 'synthetic ambiguous envelope'},
    {'error': 'synthetic encoding error'},
    {'failureCode': 'encoding_failure'},
    {'error': 'already_exists', 'failureCode': 'encoding_failure'},
  ]) {
    test(
      'polled readiness rejects contradictory evidence $contradiction',
      () async {
        final h = await blueskyPublisherHarness();
        addTearDown(h.close);
        await h.prepareVideo();
        final initial = await h.provider.send(h.photoPost, h.context);
        final saved = h.uploadState['bluesky.video'];
        h.videoState = 'JOB_STATE_COMPLETED';
        final original = h.account.override!;
        h.account.override = (request) {
          if (request.url.path == '/xrpc/app.bsky.video.getJobStatus') {
            return h.account.json({
              'jobStatus': {...h.job, ...contradiction},
            });
          }
          return original(request);
        };
        final checked = await h.provider.check(h.photoPost, initial, h.context);
        expect(checked.reasonCode, 'media-processing');
        expect(h.uploadState['bluesky.video'], saved);
        expect(h.createRequestCount, 0);
        expect(
          (await h.provider.send(h.photoPost, h.context)).status,
          PublishStatus.notPublished,
        );
        expect(h.uploadState['bluesky.video'], saved);
        expect(h.createRequestCount, 0);
        expect(h.videoUploads, 1);
      },
    );
  }
  for (final contradiction in [
    {'errors': 'synthetic ambiguous envelope'},
    {'error': 'synthetic encoding error'},
    {'failureCode': 'encoding_failure'},
  ]) {
    test(
      'reconstructed readiness rejects contradictory evidence $contradiction',
      () async {
        final h = await blueskyPublisherHarness();
        addTearDown(h.close);
        await h.prepareVideo();
        final initial = await h.provider.send(h.photoPost, h.context);
        final saved =
            jsonDecode(h.uploadState['bluesky.video']!) as Map<String, dynamic>;
        h.videoState = 'JOB_STATE_COMPLETED';
        h.uploadState['bluesky.video'] = jsonEncode({
          ...saved,
          'job': {...h.job, ...contradiction},
        });
        h.provider = BlueskyPublisher(
          connection: h.account.connection,
          media: h.account.fixture.files,
          capabilities: h.provider.capabilities,
          clock: h.account.clock,
        );
        final checked = await h.provider.check(h.photoPost, initial, h.context);
        expect(checked.reasonCode, 'media-processing');
        expect(
          (await h.provider.send(h.photoPost, h.context)).status,
          PublishStatus.notPublished,
        );
        expect(h.videoPolls, 0);
        expect(h.videoUploads, 1);
        expect(h.createRequestCount, 0);
      },
    );
  }
  test(
    'saved ordinary failure stays terminal for check and explicit continuation',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      await h.prepareVideo();
      final initial = await h.provider.send(h.photoPost, h.context);
      h.videoState = 'JOB_STATE_FAILED';
      final original = h.account.override!;
      h.account.override = (request) {
        if (request.url.path == '/xrpc/app.bsky.video.getJobStatus') {
          return h.account.json({
            'jobStatus': {
              ...h.job,
              'error': 'synthetic encoding error',
              'failureCode': 'encoding_failure',
            },
          });
        }
        return original(request);
      };
      final failed = await h.provider.check(h.photoPost, initial, h.context);
      expect(failed.status, PublishStatus.notPublished);
      expect(failed.reasonCode, 'video-processing-failed');
      expect(
        h.account.requests
            .where((r) => r.url.path.endsWith('getJobStatus'))
            .length,
        1,
      );
      h.videoState = 'JOB_STATE_COMPLETED';
      final checked = await h.provider.check(h.photoPost, initial, h.context);
      expect(checked.reasonCode, 'video-processing-failed');
      final continued = await h.provider.send(h.photoPost, h.context);
      expect(continued.reasonCode, 'video-processing-failed');
      expect(
        h.account.requests
            .where((r) => r.url.path.endsWith('getJobStatus'))
            .length,
        1,
      );
      expect(h.videoUploads, 1);
      expect(h.createRequestCount, 0);
    },
  );
  test('explicit continuation polls and saves before creating', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    await h.prepareVideo();
    await h.provider.send(h.photoPost, h.context);
    h.videoState = 'JOB_STATE_COMPLETED';
    final continued = await h.provider.send(h.photoPost, h.context);
    expect(continued.status, PublishStatus.published);
    expect(h.videoPolls, 1);
    expect(h.videoUploads, 1);
    expect(h.createRequestCount, 1);
    expect(
      h.phases.lastIndexOf('bluesky.video'),
      lessThan(h.phases.indexOf('dispatch')),
    );
  });
  for (final checkOnly in [true, false]) {
    test(
      '${checkOnly ? 'check' : 'continuation'} awaits status persistence and cannot use a failed save',
      () async {
        final h = await blueskyPublisherHarness();
        addTearDown(h.close);
        await h.prepareVideo();
        final initial = await h.provider.send(h.photoPost, h.context);
        final saved = h.uploadState['bluesky.video'];
        h.videoState = 'JOB_STATE_COMPLETED';
        final saving = Completer<void>();
        final release = Completer<void>();
        h.beforeSave = (key, value) async {
          if (key == 'bluesky.video') {
            saving.complete();
            await release.future;
            throw StateError('synthetic status persistence failure');
          }
        };
        var finished = false;
        final pending =
            (checkOnly
                    ? h.provider.check(h.photoPost, initial, h.context)
                    : h.provider.send(h.photoPost, h.context))
                .then((result) {
                  finished = true;
                  return result;
                });
        await saving.future;
        expect(finished, isFalse);
        expect(h.createRequestCount, 0);
        release.complete();
        final result = await pending;
        expect(
          result.status,
          checkOnly ? PublishStatus.processing : PublishStatus.notPublished,
        );
        expect(result.reasonCode, isNot('preparation-ready'));
        expect(h.uploadState['bluesky.video'], saved);
        expect(h.videoPolls, 1);
        expect(h.videoUploads, 1);
        expect(h.createRequestCount, 0);
      },
    );
  }
}
