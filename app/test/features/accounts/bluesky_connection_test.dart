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

  for (final state in [
    AccountState.connected,
    AccountState.removalPending,
    AccountState.repairRequired,
    AccountState.disconnected,
  ]) {
    test(
      'session deletion expires only a connected owner from $state',
      () async {
        final h = await blueskyAccountHarness();
        addTearDown(h.close);
        await h.connection.connect(handle: 'person.test');
        await h.accounts.setState(Destination.bluesky, state);
        await h.stores.sessions
            .delete(blueskyDid)
            .timeout(const Duration(seconds: 5));
        final expected = state == AccountState.connected
            ? AccountState.expired
            : state;
        expect((await h.accounts.get(Destination.bluesky)).state, expected);
        expect(jsonDecode(h.vault.value!)['session'], isNull);
        await expectLater(
          h.connection.ensureAuthorized(),
          throwsA(isA<AccountConnectionExpired>()),
        );
        expect((await h.accounts.get(Destination.bluesky)).state, expected);
      },
    );
  }
  test('stale session deletion cannot expire a newer connection', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    await h.connection.connect(handle: 'person.test');
    final oldStores = h.stores;
    await h.connection.connect(handle: 'person.test');
    final before = h.vault.value;
    await expectLater(
      oldStores.sessions.delete(blueskyDid),
      throwsA(isA<AccountConnectionCancelled>()),
    );
    expect(h.vault.value, before);
    await h.connection.ensureAuthorized();
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.connected,
    );
  });
  test('compound vault and public write failure still invalidates the owner safely', () async {
    final h = await blueskyAccountHarness();
    addTearDown(h.close);
    await h.connection.connect(handle: 'person.test');
    final oldStores = h.stores;
    await h.fixture.database.db.execute("""
      CREATE TRIGGER reject_bluesky_account_write BEFORE INSERT ON accounts
      WHEN NEW.destination = 'bluesky'
      BEGIN SELECT RAISE(FAIL, 'synthetic public write failure'); END
    """);
    h.vault.readFails = true;
    await expectLater(
      h.connection.ensureAuthorized(),
      throwsA(isA<CredentialStorageFailure>()),
    );
    h.vault.readFails = false;
    expect(oldStores.checkCurrent, throwsA(isA<AccountConnectionCancelled>()));
    await expectLater(
      oldStores.sessions.find(blueskyDid),
      throwsA(isA<AccountConnectionCancelled>()),
    );
  });
  for (final field in ['destination', 'subject']) {
    test(
      'stored identity $field remains bound while handles can change',
      () async {
        final h = await blueskyAccountHarness();
        addTearDown(h.close);
        await h.connection.connect(handle: 'person.test');
        final envelope = jsonDecode(h.vault.value!) as Map<String, dynamic>;
        (envelope['identity'] as Map<String, dynamic>)[field] =
            field == 'destination' ? 'x' : 'did:plc:zzzzzzzzzzzzzzzzzzzzzzzz';
        h.vault.value = jsonEncode(envelope);
        await h.restartConnection();
        await expectLater(
          h.connection.ensureAuthorized(),
          throwsA(isA<AccountConnectionExpired>()),
        );
        expect(
          (await h.accounts.get(Destination.bluesky)).state,
          AccountState.expired,
        );
      },
    );
  }

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
