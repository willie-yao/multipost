import 'package:cross_posting_app/features/drafts/draft_repository.dart';

import 'dart:async';

import 'package:atproto_oauth/atproto_oauth.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';

import 'dart:convert';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_fixture.dart';

void main() {
  test(
    'restoring Bluesky preserves private OAuth data only in the vault',
    () async {
      final h = await blueskyAccountHarness();
      addTearDown(h.close);
      await h.connection.connect(handle: 'person.test');
      final account = await h.accounts.get(Destination.bluesky);
      expect(account.identity?.subject, 'did:plc:abcdefghijklmnopqrstuvwx');
      expect(jsonEncode(account.toJson()), isNot(contains('private-test-key')));
      expect(
        await h.vault.read(Destination.bluesky),
        contains('private-test-key'),
      );
      await h.restartConnection();
      await h.connection.ensureAuthorized();
      expect(h.driver.restoreCount, 1);
      expect(
        (await h.accounts.get(Destination.bluesky)).state,
        AccountState.connected,
      );
    },
  );
  test(
    'browser cancellation preserves the prior secure session and identity',
    () async {
      final h = await blueskyAccountHarness();
      addTearDown(h.close);
      await h.connection.connect(handle: 'person.test');
      final before = await h.accounts.get(Destination.bluesky);
      h.browserError = const AccountConnectionCancelled();
      await expectLater(
        h.connection.connect(handle: 'person.test'),
        throwsA(isA<AccountConnectionCancelled>()),
      );
      expect(await h.accounts.get(Destination.bluesky), before);
      expect(h.vault.value, contains('private-test-key'));
      expect(h.vault.value, isNot(contains('pending')));
      await h.connection.ensureAuthorized();
    },
  );
  test('state is durably single-use before disconnect', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    h.browser = Completer<String>();
    final connecting = h.connection.connect(handle: 'person.test');
    final failed = expectLater(
      connecting,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.browserStarted.future;
    final claims = await Future.wait([
      h.stores.states.find('synthetic-state'),
      h.stores.states.find('synthetic-state'),
    ]);
    expect(claims.whereType<OAuthContext>(), hasLength(1));
    expect(h.vault.value, contains('"claimed":true'));
    await h.connection.disconnect();
    h.browser!.complete('ignored');
    await failed;
    expect(h.vault.value, isNull);
  });
  test('late callback cannot resurrect a disconnected session', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    h.browser = Completer<String>();
    final connecting = h.connection.connect(handle: 'person.test');
    final failed = expectLater(
      connecting,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.browserStarted.future;
    await h.connection.disconnect();
    h.browser!.complete('ignored');
    await failed;
    expect(h.vault.value, isNull);
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.disconnected,
    );
  });
  test(
    'failed removal survives SQLite restart and blocks fresh connection',
    () async {
      final h = await blueskyAccountHarness();
      addTearDown(h.close);
      await h.connection.connect(handle: 'person.test');
      h.vault.deleteFails = true;
      await expectLater(
        h.connection.disconnect(),
        throwsA(isA<CredentialStorageFailure>()),
      );
      await h.fixture.reopen();
      await h.restartConnection();
      expect(
        (await h.accounts.get(Destination.bluesky)).state,
        AccountState.removalPending,
      );
      await expectLater(
        h.connection.connect(handle: 'person.test'),
        throwsA(isA<CredentialStorageFailure>()),
      );
      h.vault.deleteFails = false;
      await h.connection.disconnect();
      expect(h.vault.value, isNull);
    },
  );
  test('unreadable vault requires explicit repair before a separate fresh connection', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    await h.connection.connect(handle: 'person.test');
    h.vault.readFails = true;
    await expectLater(
      h.connection.ensureAuthorized(),
      throwsA(isA<CredentialStorageFailure>()),
    );
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.repairRequired,
    );
    await expectLater(
      h.connection.connect(handle: 'person.test'),
      throwsA(isA<CredentialStorageFailure>()),
    );
    await h.connection.repairCredentials();
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.disconnected,
    );
    await h.connection.connect(handle: 'person.test');
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.connected,
    );
  });
  test('reviewed DID mismatch blocks API client acquisition', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    await h.connection.connect(handle: 'person.test');
    await expectLater(
      h.connection.authorizedClient(expectedDid: 'did:plc:other'),
      throwsA(isA<AccountConnectionExpired>()),
    );
    expect(
      (await h.connection.authorizedClient(expectedDid: blueskyDid))
          .oAuthSessionManager!
          .currentSub,
      blueskyDid,
    );
  });
  test(
    'callback waits for the secure claim before exposing its context',
    () async {
      final h = await blueskyAccountHarness();
      addTearDown(h.close);
      h.browser = Completer<String>();
      final connecting = h.connection.connect(handle: 'person.test');
      final failed = expectLater(
        connecting,
        throwsA(isA<AccountConnectionCancelled>()),
      );
      await h.browserStarted.future;
      h.vault.writeBarrier = Completer<void>();
      h.vault.writeStarted = Completer<void>();
      var done = false;
      final claim = h.stores.states.find('synthetic-state').then((v) {
        done = true;
        return v;
      });
      await h.vault.writeStarted!.future;
      expect(done, isFalse);
      h.vault.writeBarrier!.complete();
      await claim;
      h.vault.writeBarrier = null;
      h.vault.writeStarted = null;
      await h.connection.disconnect();
      h.browser!.complete('ignored');
      await failed;
    },
  );
  test('malformed stored session expires the account without resetting credentials', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    await h.connection.connect(handle: 'person.test');
    final json = jsonDecode(h.vault.value!) as Map<String, dynamic>;
    json['session'] = null;
    h.vault.value = jsonEncode(json);
    final stored = h.vault.value;
    await h.restartConnection();
    await expectLater(
      h.connection.ensureAuthorized(),
      throwsA(isA<AccountConnectionExpired>()),
    );
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.expired,
    );
    expect(h.vault.value, stored);
  });

  test(
    'Bluesky private persistence and removal preserve X credentials and drafts',
    () async {
      final h = await blueskyAccountHarness();
      addTearDown(h.close);
      h.vault.values[Destination.x] = 'synthetic-independent-X-session';
      final drafts = SqliteDraftRepository(
        h.fixture.database,
        media: h.fixture.files,
      );
      await drafts.save(
        Draft(
          id: 'blue-draft',
          updatedAt: h.clock.now(),
          shared: PostContent(text: 'Kept Bluesky draft'),
          selected: {Destination.bluesky},
        ),
        expectedRevision: -1,
      );
      await h.connection.connect(handle: 'person.test');
      final rows = await h.fixture.database.db.query('drafts');
      expect(jsonEncode(rows), isNot(contains('private-test-key')));
      await h.connection.disconnect();
      expect(
        await h.vault.read(Destination.x),
        'synthetic-independent-X-session',
      );
      expect(
        (await drafts.get('blue-draft'))!.shared.text,
        'Kept Bluesky draft',
      );
      expect(await h.vault.read(Destination.bluesky), isNull);
    },
  );
}
