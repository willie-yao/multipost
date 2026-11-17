import 'dart:typed_data';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_fixture.dart';
import '../../support/publisher_fixture.dart';

void main() {
  test('video admission rejects OAuth, arbitrary Bearer, wrong audiences and origins before network', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    final client = await h.account.connection.authorizedClient(
      expectedDid: blueskyDid,
    );
    final count = h.account.requests.length;
    await expectLater(client.video.getUploadLimits(), throwsA(anything));
    await expectLater(
      client.video.getUploadLimitsWithAuthToken('arbitrary-token'),
      throwsA(anything),
    );
    await expectLater(
      client.video.uploadVideoWithAuthToken(
        'arbitrary-token',
        bytes: Uint8List(4),
      ),
      throwsA(anything),
    );
    await expectLater(
      client.atproto.server.getServiceAuth(
        aud: 'did:web:evil.example',
        lxm: 'com.atproto.repo.uploadBlob',
      ),
      throwsA(anything),
    );
    await expectLater(
      client.atproto.server.getServiceAuth(
        aud: 'did:web:video.bsky.app',
        lxm: 'app.bsky.actor.getProfile',
      ),
      throwsA(anything),
    );
    expect(h.account.requests.length, count);
    await expectLater(
      h.account.connection.videoJobStatus(
        expectedDid: 'did:plc:wrong',
        jobId: 'synthetic-job',
      ),
      throwsA(isA<AccountConnectionExpired>()),
    );
  });
  test(
    'minted service tokens are restricted to their endpoint and bound DID',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      final client = await h.account.connection.authorizedClient(
        expectedDid: blueskyDid,
      );
      final token = (await client.video.getUploadLimitsAuth()).data.token;
      final count = h.account.requests.length;
      await expectLater(
        client.video.uploadVideoWithAuthToken(token, bytes: Uint8List(4)),
        throwsA(anything),
      );
      await expectLater(
        client.video.getUploadLimitsWithAuthToken(
          token,
          $service: 'evil.example',
        ),
        throwsA(anything),
      );
      expect(h.account.requests.length, count);
    },
  );
  test(
    'bare upload with mixed errors is rejected before SDK readiness',
    () async {
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
      final client = await h.account.connection.authorizedClient(
        expectedDid: blueskyDid,
      );
      final token = (await client.video.getUploadVideoAuth()).data.token;
      await expectLater(
        client.video.uploadVideoWithAuthToken(token, bytes: Uint8List(4)),
        throwsA(anything),
      );
    },
  );
  test(
    'status envelope with mixed errors cannot return successful job evidence',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      await h.prepareVideo();
      h.videoState = 'JOB_STATE_COMPLETED';
      final original = h.account.override!;
      h.account.override = (request) {
        if (request.url.path == '/xrpc/app.bsky.video.getJobStatus') {
          return h.account.json({
            'jobStatus': h.job,
            'errors': 'synthetic ambiguous envelope',
          });
        }
        return original(request);
      };
      await expectLater(
        h.account.connection.videoJobStatus(
          expectedDid: blueskyDid,
          jobId: 'synthetic-job',
        ),
        throwsA(anything),
      );
    },
  );
}
