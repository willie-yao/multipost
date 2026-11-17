import 'dart:convert';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/bluesky_publisher.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/publisher_fixture.dart';

void main() {
  test(
    'checking a lost response does not create another Bluesky record',
    () async {
      final h = await blueskyPublisherHarness(createResponseLost: true);
      addTearDown(h.close);
      final outcome = await h.provider.send(h.photoPost, h.context);
      expect(outcome.status, PublishStatus.unknown);
      final checked = await h.provider.check(h.photoPost, outcome, h.context);
      expect(checked.status, PublishStatus.published);
      expect(h.createRequestCount, 1);
      expect(h.lookups, 1);
      expect(
        h.phases.indexOf('bluesky-record'),
        lessThan(h.phases.indexOf('dispatch')),
      );
      expect(
        h.phases.indexOf('dispatch'),
        lessThan(h.phases.indexOf('create')),
      );
      final identity = jsonDecode(h.uploadState['bluesky-record']!) as Map;
      expect(identity['identity']['rkey'], h.created!['rkey']);
      expect(
        h.account.requests.last.url.queryParameters['rkey'],
        h.created!['rkey'],
      );
      expect(
        h.created!['rkey'],
        matches(RegExp(r'^[234567abcdefghijklmnopqrstuvwxyz]{13}$')),
      );
    },
  );
  test(
    'exact caption and UTF8 facets survive emoji newlines and own caption',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      final post = h.textPost.copyWith(
        ownCaption: true,
        content: PostContent(
          text: '👩🏽‍🚀 e\u0301\n@person.bsky.social https://example.com [label](https://other.example)',
        ),
      );
      expect(
        (await h.provider.send(post, h.context)).status,
        PublishStatus.published,
      );
      final record = h.created!['record'] as Map;
      expect(record['text'], post.content.text);
      final bytes = utf8.encode(post.content.text);
      final facets = record['facets'] as List;
      final tokens = facets
          .map(
            (f) => utf8.decode(
              bytes.sublist(
                f['index']['byteStart'] as int,
                f['index']['byteEnd'] as int,
              ),
            ),
          )
          .toList();
      expect(tokens, contains('@person.bsky.social'));
      expect(tokens, contains('https://example.com'));
      expect(
        facets.firstWhere(
          (f) => (f['features'] as List).first['did'] != null,
        )['features'][0]['did'],
        post.account!.subject,
      );
    },
  );
  test(
    'Bluesky measures graphemes and enforces the independent byte bound',
    () {
      const counter = BlueskyTextCounter();
      expect(counter.measure('👩🏽‍🚀e\u0301\n').units, 3);
      expect(counter.measure('a${'\u0301' * 1600}').units, 1);
      expect(counter.measure('a${'\u0301' * 1600}').valid, isFalse);
      expect(counter.measure('a' * 301).valid, isFalse);
    },
  );
  test(
    'unresolved mentions remain plain text with conditional preview warning',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      h.unresolved = true;
      final post = h.textPost.copyWith(
        content: PostContent(text: 'Hello @missing.bsky.social'),
      );
      final issues = await h.provider.validator.validate(post);
      expect(
        issues.any(
          (i) => !i.blocking && i.code == 'mentions-resolved-at-publication',
        ),
        isTrue,
      );
      expect(
        (await h.provider.send(post, h.context)).status,
        PublishStatus.published,
      );
      expect((h.created!['record'] as Map)['text'], post.content.text);
      expect((h.created!['record'] as Map)['facets'] ?? [], isEmpty);
    },
  );
  test('ordered selected photos keep corresponding alt strings', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    final second = await h.account.fixture.files.importFile(
      await h.account.fixture.photo('second.png', width: 10),
    );
    final post = h.photoPost.copyWith(
      content: PostContent(
        text: '',
        media: [
          h.photoPost.content.media.first,
          Attachment(assetId: second.id, altText: 'Second description'),
        ],
      ),
      assets: [h.photoPost.assets.first, second],
    );
    expect(
      (await h.provider.send(post, h.context)).status,
      PublishStatus.published,
    );
    expect(
      ((h.created!['record'] as Map)['embed']['images'] as List).map(
        (i) => i['alt'],
      ),
      ['A fixture photo', 'Second description'],
    );
    expect(h.uploads, 2);
    final images = (h.created!['record'] as Map)['embed']['images'] as List;
    expect(images[0]['image']['ref'], isNot(images[1]['image']['ref']));
    final uploads = h.account.requests
        .where((r) => r.url.path.endsWith('uploadBlob'))
        .toList();
    expect(
      uploads.map((r) => r.bodyBytes.length),
      post.assets.map((a) => a.bytes),
    );
  });
  test(
    'complete frozen record mismatch and missing record remain unknown',
    () async {
      final h = await blueskyPublisherHarness(createResponseLost: true);
      addTearDown(h.close);
      final outcome = await h.provider.send(h.photoPost, h.context);
      h.alterRecord = true;
      expect(
        (await h.provider.check(h.photoPost, outcome, h.context)).status,
        PublishStatus.unknown,
      );
      h.alterRecord = false;
      h.recordExists = false;
      expect(
        (await h.provider.check(h.photoPost, outcome, h.context)).status,
        PublishStatus.unknown,
      );
      expect(h.createRequestCount, 1);
      expect(h.uploads, 1);
    },
  );
  test(
    'changed frozen source cannot reconcile or send prior identity',
    () async {
      final h = await blueskyPublisherHarness(createResponseLost: true);
      addTearDown(h.close);
      final outcome = await h.provider.send(h.textPost, h.context);
      final changed = h.textPost.copyWith(content: PostContent(text: 'Other'));
      expect(
        (await h.provider.check(changed, outcome, h.context)).status,
        PublishStatus.unknown,
      );
      expect(
        (await h.provider.send(changed, h.context)).status,
        PublishStatus.unknown,
      );
      expect(h.lookups, 0);
      expect(h.createRequestCount, 1);
    },
  );
  test(
    'denied upload never crosses dispatch and malformed receipt is uncertain',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      h.denyUpload = true;
      expect(
        (await h.provider.send(h.photoPost, h.context)).status,
        PublishStatus.notPublished,
      );
      expect(h.createRequestCount, 0);
      expect(h.phases, isNot(contains('dispatch')));
      h.denyUpload = false;
      h.wrongReceipt = true;
      expect(
        (await h.provider.send(h.textPost, h.context)).status,
        PublishStatus.unknown,
      );
    },
  );
  test('durable identity or boundary failure never creates', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    h.beforeSave = (k, v) async {
      if (k == 'bluesky-record') throw StateError('synthetic storage failure');
    };
    expect(
      (await h.provider.send(h.textPost, h.context)).status,
      PublishStatus.notPublished,
    );
    expect(h.createRequestCount, 0);
  });
  test('reviewed account and reconnect during awaited boundary cannot switch clients', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    final wrong = h.textPost.copyWith(
      account: const AccountIdentity(
        destination: Destination.bluesky,
        subject: 'did:plc:wrong',
        handle: '@other.test',
      ),
    );
    expect(
      (await h.provider.send(wrong, h.context)).status,
      PublishStatus.connectionNeeded,
    );
    h.onMarkDispatch = () async {
      await h.account.connection.disconnect();
      await h.account.connect();
    };
    expect(
      (await h.provider.send(h.textPost, h.context)).status,
      PublishStatus.unknown,
    );
    expect(h.createRequestCount, 0);
  });
  test('only documented final rejection settles nonpublication', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    h.createStatus = 400;
    expect(
      (await h.provider.send(h.textPost, h.context)).status,
      PublishStatus.notPublished,
    );
    final second = await blueskyPublisherHarness();
    addTearDown(second.close);
    second.createStatus = 500;
    expect(
      (await second.provider.send(second.textPost, second.context)).status,
      PublishStatus.unknown,
    );
  });
  test(
    'invalid UTF16 cannot silently become replacement characters on wire',
    () {
      expect(const BlueskyTextCounter().measure('\uD800').valid, isFalse);
    },
  );
  test('DPoP rejection retry keeps exact record identity and body', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    h.createNonceChallenge = true;
    final result = await h.provider.send(h.textPost, h.context);
    expect(result.status, PublishStatus.published);
    expect(h.createRequestCount, 2);
    final requests = h.account.requests
        .where((r) => r.url.path.endsWith('createRecord'))
        .toList();
    expect(requests[0].body, requests[1].body);
    expect(requests[0].headers['dpop'], isNot(requests[1].headers['dpop']));
  });
  test(
    'expired session refresh completes before final SDK record dispatch',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      await h.account.expireStoredSession();
      h.provider = BlueskyPublisher(
        connection: h.account.connection,
        media: h.account.fixture.files,
        capabilities: h.provider.capabilities,
        clock: h.account.clock,
      );
      expect(
        (await h.provider.send(h.textPost, h.context)).status,
        PublishStatus.published,
      );
      expect(h.account.refreshes, 1);
      expect(h.createRequestCount, 1);
    },
  );
  test('wrong canonical CID cannot confirm the exact durable record', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    h.wrongCid = true;
    expect(
      (await h.provider.send(h.textPost, h.context)).status,
      PublishStatus.unknown,
    );
  });
  test(
    'production Bluesky review surfaces the conditional mention warning',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      final registry = CapabilityRegistry.production(
        instagram: h.provider.validator,
      );
      final issues = await registry
          .forDestination(Destination.bluesky)
          .validate(
            h.textPost.copyWith(
              content: PostContent(text: '@person.bsky.social'),
            ),
          );
      expect(
        issues.any(
          (i) => i.code == 'mentions-resolved-at-publication' && !i.blocking,
        ),
        isTrue,
      );
      expect(
        issues.any((i) => i.blocking && i.code == 'requirements-unverified'),
        isTrue,
      );
    },
  );
  test('a valid-looking receipt carrying errors remains unknown', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    h.ambiguousReceipt = true;
    expect(
      (await h.provider.send(h.textPost, h.context)).status,
      PublishStatus.unknown,
    );
    expect(h.createRequestCount, 1);
  });
  test('same-length owned file corruption blocks the complete set before uploading', () async {
    final h = await blueskyPublisherHarness();
    addTearDown(h.close);
    final file = await h.account.fixture.files.fileFor(
      h.photoPost.assets.single.id,
    );
    final bytes = await file.readAsBytes();
    bytes[bytes.length - 1] ^= 1;
    await file.writeAsBytes(bytes);
    expect(
      (await h.provider.send(h.photoPost, h.context)).status,
      PublishStatus.notPublished,
    );
    expect(h.uploads, 0);
    expect(h.createRequestCount, 0);
  });
  test(
    'durable boundary acknowledgment loss is conservative without dispatch',
    () async {
      final h = await blueskyPublisherHarness();
      addTearDown(h.close);
      h.onMarkDispatch = () async {
        throw StateError('synthetic acknowledgment loss');
      };
      final outcome = await h.provider.send(h.textPost, h.context);
      expect(outcome.status, PublishStatus.unknown);
      expect(h.createRequestCount, 0);
      expect(
        (await h.provider.send(h.textPost, h.context)).status,
        PublishStatus.unknown,
      );
      expect(h.createRequestCount, 0);
    },
  );
  test('persisted record identity enforces the lexicon TID high bit', () {
    expect(
      () => RecordIdentity(
        repoDid: 'did:plc:abcdefghijklmnopqrstuvwx',
        collection: 'app.bsky.feed.post',
        rkey: 'zzzzzzzzzzzzz',
      ),
      throwsA(anything),
    );
  });
}
