import 'package:cross_posting_app/features/publishing/attempt.dart';

import 'dart:convert';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/providers/x_publisher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/publisher_fixture.dart';

void main() {
  test('lost create response after upload remains unknown', () async {
    final h = await xPublisherHarness(createResponseLost: true);
    addTearDown(h.close);
    final result = await h.provider.send(h.photoPost, h.context());
    expect(h.dispatchMarked, isTrue);
    expect(result.status, PublishStatus.unknown);
    expect(result.remoteId, isNull);
    expect(h.createRequestCount, 1);
  });
  test(
    'text and ordered photos publish only from a valid create receipt',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      final result = await h.provider.send(h.photoPost, h.context());
      expect(result.status, PublishStatus.published);
      expect(result.remoteId, '999');
      expect(result.url.toString(), 'https://x.com/i/status/999');
      final create = h.requests.singleWhere((r) => r.url.path == '/2/tweets');
      expect(jsonDecode(create.body), {
        'text': h.photoPost.content.text,
        'media': {
          'media_ids': ['101'],
        },
      });
      final metadata = h.requests.singleWhere(
        (r) => r.url.path == '/2/media/metadata',
      );
      expect(jsonDecode(metadata.body), {
        'id': '101',
        'metadata': {
          'alt_text': {'text': 'A fixture photo'},
        },
      });
      expect(h.requests.every((r) => !r.followRedirects), isTrue);
      expect(
        h.phases.indexOf('dispatch'),
        lessThan(h.phases.indexOf('create')),
      );
      expect(h.uploadState.values.any((s) => s.contains('101')), isTrue);
    },
  );
  test(
    'simple photo wire body contains exactly category and owned media parts',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.published,
      );
      final upload = h.requests.singleWhere(
        (r) => r.method == 'POST' && r.url.path == '/2/media/upload',
      );
      final contentType = upload.headers['content-type']!;
      expect(contentType, startsWith('multipart/form-data; boundary='));
      final boundary = contentType.substring(
        contentType.indexOf('boundary=') + 'boundary='.length,
      );
      final sections = latin1.decode(upload.bodyBytes).split('--$boundary');
      expect(sections.first, isEmpty);
      expect(sections.last, '--\r\n');
      final parts = sections.sublist(1, sections.length - 1);
      // Exact schema property/part set: an extra field cannot hide behind an
      // accepting fake response. No additional_owners is sent for owned media.
      expect(parts, hasLength(2));
      final dispositions = parts
          .map(
            (part) => RegExp(
              r'content-disposition: form-data; name="([^"]+)"(?:; filename="([^"]*)")?',
              caseSensitive: false,
            ).firstMatch(part)!,
          )
          .toList();
      expect(dispositions.map((m) => m.group(1)), ['media_category', 'media']);
      expect(dispositions.map((m) => m.group(2)), [null, 'photo.png']);
      expect(
        parts.first,
        '\r\ncontent-disposition: form-data; name="media_category"\r\n\r\ntweet_image\r\n',
      );
      final filePart = parts.last;
      final headerEnd = filePart.indexOf('\r\n\r\n');
      expect(headerEnd, greaterThan(0));
      expect(filePart.endsWith('\r\n'), isTrue);
      final file = await h.account.fixture.files.fileFor(
        h.photoPost.assets.single.id,
      );
      expect(
        latin1.encode(filePart.substring(headerEnd + 4, filePart.length - 2)),
        await file.readAsBytes(),
      );
    },
  );
  test('text only preserves the exact caption and links', () async {
    final h = await xPublisherHarness();
    addTearDown(h.close);
    expect(
      (await h.provider.send(h.textPost, h.context())).status,
      PublishStatus.published,
    );
    expect(h.uploads, 0);
    expect(jsonDecode(h.requests.single.body), {
      'text': h.textPost.content.text,
    });
  });
  test('malformed success or generic create errors remain unknown', () async {
    for (final (status, body) in [
      (201, '{}'),
      (201, '{"data":{"id":"999","text":"fixture"},"errors":"malformed"}'),
      (201, '{"data":{"id":"bad"}}'),
      (503, '{}'),
      (403, '{}'),
      (302, '{}'),
    ]) {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      h.createStatus = status;
      h.createBody = body;
      expect(
        (await h.provider.send(h.textPost, h.context())).status,
        PublishStatus.unknown,
      );
      expect(h.createRequestCount, 1);
    }
  });
  test(
    'rate rejection is definitive while generic credit failure stays unknown',
    () async {
      for (final code in ['usage-capped', 'undocumented-credit-error']) {
        final h = await xPublisherHarness();
        addTearDown(h.close);
        h.createStatus = code == 'usage-capped' ? 429 : 402;
        h.createBody = jsonEncode({
          'type': 'https://api.x.com/2/problems/$code',
          'title': 'Synthetic rejection',
        });
        h.createHeaders = {'retry-after': '60'};
        final result = await h.provider.send(h.textPost, h.context());
        expect(
          result.status,
          code == 'usage-capped'
              ? PublishStatus.notPublished
              : PublishStatus.unknown,
        );
        expect(
          result.retryAfter,
          h.account.clock.now().add(const Duration(minutes: 1)),
        );
        expect(result.message, isNotEmpty);
      }
    },
  );
  test(
    'metadata failure and partial photo upload cannot dispatch create',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      h.metadataStatus = 500;
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.notPublished,
      );
      expect(h.createRequestCount, 0);
      expect(h.dispatchMarked, isFalse);
      final h2 = await xPublisherHarness();
      addTearDown(h2.close);
      final second = await h2.account.fixture.files.importFile(
        await h2.account.fixture.photo('second.png'),
      );
      h2.failUpload = 2;
      final post = h2.photoPost.copyWith(
        content: h2.photoPost.content.copyWith(
          media: [
            ...h2.photoPost.content.media,
            Attachment(assetId: second.id),
          ],
        ),
        assets: [...h2.photoPost.assets, second],
      );
      expect(
        (await h2.provider.send(post, h2.context())).status,
        PublishStatus.notPublished,
      );
      expect(h2.createRequestCount, 0);
      expect(h2.uploads, 2);
      expect(h2.uploadState, isNotEmpty);
    },
  );
  test('account changes during upload or durable boundary never select the new account', () async {
    for (final atDispatch in [false, true]) {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      Future<void> switchAccount() async {
        await h.account.x.disconnect();
        h.account.subject = '67890';
        await h.account.x.connect();
      }

      if (atDispatch) {
        h.onMarkDispatch = switchAccount;
      } else {
        h.beforeResponse = (r) async {
          if (r.url.path == '/2/media/upload') await switchAccount();
        };
      }
      final result = await h.provider.send(h.photoPost, h.context());
      expect(
        result.status,
        atDispatch ? PublishStatus.unknown : PublishStatus.connectionNeeded,
      );
      expect(h.createRequestCount, 0);
    }
  });
  test(
    'expired token is refreshed and durably persisted before final create',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      h.beforeResponse = (r) async {
        if (r.url.path == '/2/media/metadata') {
          h.account.clock.value = h.account.clock.value.add(
            const Duration(hours: 3),
          );
        }
      };
      expect(
        (await h.provider.send(h.photoPost, h.context())).status,
        PublishStatus.published,
      );
      expect(h.account.oauth.refreshCalls, 1);
      expect(
        h.requests.last.headers['Authorization'],
        'Bearer opaque-access-rotated',
      );
      expect(h.account.vault.value, contains('opaque-access-rotated'));
    },
  );
  test('unavailable capabilities, invalid text, account mismatch, and missing media block before HTTP', () async {
    final h = await xPublisherHarness();
    addTearDown(h.close);
    final unavailable = XPublisher(
      connection: h.account.x,
      client: h.client,
      media: h.account.fixture.files,
      counter: const FixtureXCounter(),
      capabilities: ProviderCapabilities.documented(Destination.x),
    );
    expect(
      (await unavailable.send(h.photoPost, h.context())).status,
      PublishStatus.notPublished,
    );
    expect(
      (await h.provider.send(
        h.textPost.copyWith(content: PostContent(text: 'invalid\uFFFF')),
        h.context(),
      )).status,
      PublishStatus.notPublished,
    );
    expect(
      (await h.provider.send(
        h.textPost.copyWith(
          account: h.textPost.account!.copyWith(subject: '000'),
        ),
        h.context(),
      )).status,
      PublishStatus.connectionNeeded,
    );
    final file = await h.account.fixture.files.fileFor(
      h.photoPost.assets.single.id,
    );
    await file.writeAsBytes(List.filled(h.photoPost.assets.single.bytes, 0));
    expect(
      (await h.provider.send(h.photoPost, h.context())).status,
      PublishStatus.notPublished,
    );
    expect(h.requests, isEmpty);
  });
  test(
    'check without an official post id cannot infer failure or create again',
    () async {
      final h = await xPublisherHarness(createResponseLost: true);
      addTearDown(h.close);
      final previous = await h.provider.send(h.textPost, h.context());
      expect(
        (await h.provider.check(h.textPost, previous, h.context())).status,
        PublishStatus.unknown,
      );
      expect(
        (await h.provider.send(h.textPost, h.context())).status,
        PublishStatus.unknown,
      );
      expect(h.createRequestCount, 1);
    },
  );
  test('durable boundary errors are conservative and never create', () async {
    final h = await xPublisherHarness();
    addTearDown(h.close);
    h.onMarkDispatch = () async {
      h.dispatchMarked = true;
      throw StateError('synthetic persistence receipt loss');
    };
    final result = await h.provider.send(h.textPost, h.context());
    expect(result.status, PublishStatus.unknown);
    expect(h.createRequestCount, 0);
  });
  test('expired media cannot be attached after slow preparation', () async {
    final h = await xPublisherHarness();
    addTearDown(h.close);
    h.beforeResponse = (r) async {
      if (r.url.path == '/2/media/metadata') {
        h.account.clock.value = h.account.clock.value.add(
          const Duration(days: 2),
        );
      }
    };
    final result = await h.provider.send(h.photoPost, h.context());
    expect(result.status, PublishStatus.notPublished);
    expect(result.reasonCode, 'upload-expired');
    expect(h.createRequestCount, 0);
    expect(h.dispatchMarked, isFalse);
  });
  test(
    'token expiry during durable dispatch is refreshed before create',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      h.onMarkDispatch = () async {
        h.account.clock.value = h.account.clock.value.add(
          const Duration(hours: 3),
        );
      };
      expect(
        (await h.provider.send(h.textPost, h.context())).status,
        PublishStatus.published,
      );
      expect(
        h.requests.last.headers['Authorization'],
        'Bearer opaque-access-rotated',
      );
    },
  );
  test(
    'only an official known-id lookup for the reviewed author reconciles',
    () async {
      final h = await xPublisherHarness();
      addTearDown(h.close);
      final previous = PublishOutcome(
        status: PublishStatus.unknown,
        source: EvidenceSource.provider,
        at: h.account.clock.now(),
        remoteId: '999',
      );
      final confirmed = await h.provider.check(
        h.textPost,
        previous,
        h.context(),
      );
      expect(confirmed.status, PublishStatus.published);
      expect(h.createRequestCount, 0);
      expect(h.requests.last.url.queryParameters, {
        'tweet.fields': 'author_id',
      });
      h.lookupSubject = '67890';
      expect(
        await h.provider.check(h.textPost, previous, h.context()),
        same(previous),
      );
      h.lookupSubject = '12345';
      h.lookupStatus = 404;
      expect(
        await h.provider.check(h.textPost, previous, h.context()),
        same(previous),
      );
      expect(h.createRequestCount, 0);
    },
  );
}
