import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/accounts/x_connection.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/account_fixture.dart';
import '../../support/review_fixtures.dart';

void main() {
  test(
    'failed credential persistence never reports connected and keeps drafts',
    () async {
      final h = await accountHarness(vaultWriteFails: true);
      addTearDown(h.close);
      await expectLater(
        h.x.connect(),
        throwsA(isA<CredentialStorageFailure>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state,
        isNot(AccountState.connected),
      );
      expect((await h.drafts.get('draft-1'))!.shared.text, 'Kept draft');
    },
  );

  test(
    'cancelled sign-in does not persist credentials or change public account',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      final before = await h.accounts.get(Destination.x);
      h.oauth.authorizeError = const AccountConnectionCancelled();
      await expectLater(
        h.x.connect(),
        throwsA(isA<AccountConnectionCancelled>()),
      );
      expect(h.vault.value, isNull);
      expect(await h.accounts.get(Destination.x), before);
      expect(h.identityRequests, 0);
    },
  );

  test(
    'connect awaits secure persistence before saving stable public identity',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      h.vault.writeBarrier = Completer<void>();
      h.vault.writeStarted = Completer<void>();
      final connecting = h.x.connect(handle: 'ignored');
      await h.vault.writeStarted!.future;
      expect(
        (await h.accounts.get(Destination.x)).state,
        isNot(AccountState.connected),
      );
      h.vault.writeBarrier!.complete();
      final identity = await connecting;
      expect(identity.subject, '12345');
      expect(identity.handle, '@person');
      expect((await h.accounts.get(Destination.x)).identity, identity);
      expect(
        h.lastIdentityRequest!.url.toString(),
        'https://api.x.com/2/users/me',
      );
      expect(h.lastIdentityRequest!.followRedirects, isFalse);
      final rows = await h.fixture.database.db.query('accounts');
      expect(jsonEncode(rows), isNot(contains('opaque-')));
      await h.fixture.reopen();
      expect((await h.fixture.database.db.query('accounts')).length, 1);
    },
  );

  test(
    'concurrent authorization checks share refresh and await rotated storage',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      h.clock.value = h.clock.value.add(const Duration(hours: 3));
      h.oauth.rotation = Completer<XTokenSet>();
      h.vault.writeBarrier = Completer<void>();
      var done = false;
      final checks = Future.wait([
        h.x.ensureAuthorized(),
        h.x.ensureAuthorized(),
      ]).then((_) => done = true);
      await h.oauth.refreshStarted.future;
      expect(h.oauth.refreshCalls, 1);
      h.oauth.rotation!.complete(h.oauth.tokens('rotated'));
      await pumpEventQueue();
      expect(done, isFalse);
      h.vault.writeBarrier!.complete();
      await checks;
      expect(h.vault.value, contains('opaque-refresh-rotated'));
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.connected,
      );
    },
  );

  test(
    'revoked refresh requires reconnection while offline keeps credentials',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      final stored = h.vault.value;
      h.clock.value = h.clock.value.add(const Duration(hours: 3));
      h.oauth.refreshError = const SocketException(
        'sensitive raw network detail',
      );
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.vault.value, stored);
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.connected,
      );
      h.oauth.refreshError = const AccountConnectionExpired();
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<AccountConnectionExpired>()),
      );
      expect((await h.accounts.get(Destination.x)).state, AccountState.expired);
      expect(h.vault.value, stored);
      expect(await h.drafts.get('draft-1'), isNotNull);
    },
  );

  test(
    'failed rotated-token storage blocks future healthy authorization',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      h.clock.value = h.clock.value.add(const Duration(hours: 3));
      h.vault.writeFails = true;
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<CredentialStorageFailure>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.repairRequired,
      );
      h.vault.writeFails = false;
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<AccountConnectionExpired>()),
      );
      expect(h.oauth.refreshCalls, 1);
    },
  );

  test(
    'keystore read failure requires deliberate repair and preserves draft',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      h.vault.readFails = true;
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<CredentialStorageFailure>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.repairRequired,
      );
      expect(await h.drafts.get('draft-1'), isNotNull);
    },
  );

  test(
    'disconnect clears secrets and public identity while keeping drafts',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      await h.x.disconnect();
      expect(h.vault.value, isNull);
      final account = await h.accounts.get(Destination.x);
      expect(account.state, AccountState.disconnected);
      expect(account.identity, isNull);
      expect(await h.drafts.get('draft-1'), isNotNull);
    },
  );

  test(
    'late browser completion cannot resurrect a disconnected session',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      h.oauth.authorization = Completer<XTokenSet>();
      final connecting = h.x.connect();
      final rejected = expectLater(
        connecting,
        throwsA(isA<AccountConnectionCancelled>()),
      );
      await h.oauth.authorizeStarted.future;
      expect(h.oauth.authorizeCalls, 1);
      await h.x.disconnect();
      h.oauth.authorization!.complete(h.oauth.tokens());
      await rejected;
      expect(h.vault.value, isNull);
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.disconnected,
      );
    },
  );

  test('late refresh cannot resurrect a disconnected session', () async {
    final h = await accountHarness();
    addTearDown(h.close);
    await h.x.connect();
    h.clock.value = h.clock.value.add(const Duration(hours: 3));
    h.oauth.rotation = Completer<XTokenSet>();
    final refreshing = h.x.ensureAuthorized();
    final rejected = expectLater(
      refreshing,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.oauth.refreshStarted.future;
    await h.x.disconnect();
    h.oauth.rotation!.complete(h.oauth.tokens('late'));
    await rejected;
    expect(h.vault.value, isNull);
    expect(
      (await h.accounts.get(Destination.x)).state,
      AccountState.disconnected,
    );
  });
  test('disconnect waits for an in-flight secure write then removes its late session', () async {
    final h = await accountHarness();
    addTearDown(h.close);
    h.vault.writeStarted = Completer<void>();
    h.vault.writeBarrier = Completer<void>();
    final connecting = h.x.connect();
    final rejected = expectLater(
      connecting,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.vault.writeStarted!.future;
    var disconnected = false;
    final disconnecting = h.x.disconnect().then((_) => disconnected = true);
    await pumpEventQueue();
    expect(disconnected, isFalse);
    h.vault.writeBarrier!.complete();
    await rejected;
    await disconnecting;
    expect(h.vault.value, isNull);
    expect((await h.accounts.get(Destination.x)).identity, isNull);
    expect(
      (await h.accounts.get(Destination.x)).state,
      AccountState.disconnected,
    );
  });

  test(
    'secure delete failure clears Connected and prevents retained token reuse',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      h.vault.deleteFails = true;
      await expectLater(
        h.x.disconnect(),
        throwsA(isA<CredentialStorageFailure>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.removalPending,
      );
      expect((await h.accounts.get(Destination.x)).identity, isNull);
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<AccountConnectionExpired>()),
      );
      expect(await h.drafts.get('draft-1'), isNotNull);
    },
  );

  test(
    'reconnecting another subject invalidates its immutable review',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      final draft = (await h.drafts.get('draft-1'))!;
      final review = ReviewService(
        h.drafts,
        h.fixture.files,
        h.accounts,
        TestValidators(),
        h.clock,
      );
      final reviewed = await review.review(draft, directOnline: true);
      expect(reviewed.snapshot.posts[Destination.x]!.account!.subject, '12345');
      h.subject = '98765';
      h.handle = 'other';
      await h.x.connect();
      await expectLater(
        review.revalidate(reviewed.snapshot, draft, directOnline: true),
        throwsA(isA<StaleReviewException>()),
      );
      expect((await h.accounts.get(Destination.x)).identity!.subject, '98765');
      expect((await h.drafts.get('draft-1')), draft);
    },
  );

  test(
    'identity rejection or offline failure cannot save a connected account',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      h.identityStatus = 401;
      await expectLater(
        h.x.connect(),
        throwsA(isA<AccountConnectionExpired>()),
      );
      expect(h.vault.value, isNull);
      h.identityError = TimeoutException('private endpoint/callback');
      await expectLater(
        h.x.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state,
        isNot(AccountState.connected),
      );
      expect(h.vault.value, isNull);
    },
  );
  test(
    'already expired response tokens never become a connected session',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      h.oauth.authorization = Completer<XTokenSet>()
        ..complete(
          XTokenSet(
            accessToken: 'opaque-access',
            refreshToken: 'opaque-refresh',
            expiresAt: h.clock.now().subtract(const Duration(minutes: 1)),
          ),
        );
      await expectLater(
        h.x.connect(),
        throwsA(isA<AccountConnectionExpired>()),
      );
      expect(h.identityRequests, 0);
      expect(h.vault.value, isNull);
    },
  );
  test(
    'failed removal remains durable and can retry without reauthorization',
    () async {
      final h = await accountHarness();
      addTearDown(h.close);
      await h.x.connect();
      h.vault.deleteFails = true;
      await expectLater(
        h.x.disconnect(),
        throwsA(isA<CredentialStorageFailure>()),
      );
      expect(
        (await h.accounts.get(Destination.x)).state.name,
        'removalPending',
      );
      expect((await h.accounts.get(Destination.x)).identity, isNull);
      final stored = await h.fixture.database.db.query('accounts');
      expect(stored.single['payload'], contains('removalPending'));
      await expectLater(
        h.x.ensureAuthorized(),
        throwsA(isA<AccountConnectionExpired>()),
      );
      h.vault.deleteFails = false;
      await h.x.disconnect();
      expect(h.vault.value, isNull);
      expect(
        (await h.accounts.get(Destination.x)).state,
        AccountState.disconnected,
      );
      expect((await h.drafts.get('draft-1'))!.shared.text, 'Kept draft');
    },
  );
  test('deliberate repair fences old authorization and never connects by resetting', () async {
    final h = await accountHarness();
    addTearDown(h.close);
    await h.x.connect();
    h.vault.readFails = true;
    h.vault.writeFails = true;
    await expectLater(
      h.x.ensureAuthorized(),
      throwsA(isA<CredentialStorageFailure>()),
    );
    expect((await h.accounts.get(Destination.x)).state.name, 'repairRequired');
    await h.x.repairCredentials();
    expect(h.vault.value, isNull);
    expect(
      (await h.accounts.get(Destination.x)).state,
      AccountState.disconnected,
    );
    await expectLater(
      h.x.ensureAuthorized(),
      throwsA(isA<AccountConnectionExpired>()),
    );
    await h.x.connect();
    expect((await h.accounts.get(Destination.x)).state, AccountState.connected);
    expect(h.vault.value, isNotNull);
    expect((await h.drafts.get('draft-1'))!.shared.text, 'Kept draft');
  });

  test('repair cancels late browser and refresh writes; disconnect wins during repair', () async {
    final h = await accountHarness();
    addTearDown(h.close);
    h.oauth.authorization = Completer<XTokenSet>();
    final connecting = h.x.connect();
    final cancelled = expectLater(
      connecting,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.oauth.authorizeStarted.future;
    expect(h.oauth.authorizeCalls, 1);
    await h.x.repairCredentials();
    h.oauth.authorization!.complete(h.oauth.tokens());
    await cancelled;
    expect(h.vault.value, isNull);
    h.oauth.authorization = null;
    await h.x.connect();
    h.clock.value = h.clock.value.add(const Duration(hours: 3));
    h.oauth.rotation = Completer<XTokenSet>();
    final refreshing = h.x.ensureAuthorized();
    final refreshCancelled = expectLater(
      refreshing,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.oauth.refreshStarted.future;
    await h.x.repairCredentials();
    h.oauth.rotation!.complete(h.oauth.tokens('too-late'));
    await refreshCancelled;
    expect(h.vault.value, isNull);
    h.vault.repairStarted = Completer<void>();
    h.vault.repairBarrier = Completer<void>();
    final repairing = h.x.repairCredentials();
    final repairCancelled = expectLater(
      repairing,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    await h.vault.repairStarted!.future;
    final disconnecting = h.x.disconnect();
    h.vault.repairBarrier!.complete();
    await repairCancelled;
    await disconnecting;
    expect(h.vault.value, isNull);
    expect(
      (await h.accounts.get(Destination.x)).state,
      AccountState.disconnected,
    );
  });
  test('removal and failed repair survive database reopen without changing content', () async {
    final h = await accountHarness();
    addTearDown(h.close);
    await h.accounts.setInstagramAssistedSharing(false);
    await h.fixture.database.db.insert('instagram_packages', {
      'id': 'kept-package',
      'operation_id': 'kept-op',
      'draft_id': 'draft-1',
      'revision': 0,
      'payload': 'original Instagram package',
    });
    await h.fixture.database.db.insert('instagram_events', {
      'id': 'kept-event',
      'package_id': 'kept-package',
      'kind': 'userConfirmed',
      'at': 'time',
      'payload': 'original Instagram result',
    });
    await h.fixture.database.db.insert('export_jobs', {
      'id': 'kept-job',
      'package_id': 'kept-package',
      'ordinal': 0,
      'uri': 'content://synthetic/kept',
      'completed': 1,
    });
    await h.x.connect();
    h.vault.deleteFails = true;
    await expectLater(
      h.x.disconnect(),
      throwsA(isA<CredentialStorageFailure>()),
    );
    await h.fixture.reopen();
    var accounts = LocalAccountRepository(
      h.fixture.database,
      configuration: h.configuration,
    );
    XConnection connection() => XConnection(
      configuration: h.configuration,
      driver: h.oauth,
      vault: h.vault,
      accounts: accounts,
      client: h.client,
      clock: h.clock,
    );
    expect(
      (await accounts.get(Destination.x)).state,
      AccountState.removalPending,
    );
    final requests = h.identityRequests;
    await expectLater(
      connection().connect(),
      throwsA(isA<CredentialStorageFailure>()),
    );
    expect(h.identityRequests, requests);
    h.vault.repairFails = true;
    await expectLater(
      connection().repairCredentials(),
      throwsA(isA<CredentialStorageFailure>()),
    );
    await h.fixture.reopen();
    accounts = LocalAccountRepository(
      h.fixture.database,
      configuration: h.configuration,
    );
    expect(
      (await accounts.get(Destination.x)).state,
      AccountState.removalPending,
    );
    h.vault.deleteFails = false;
    await connection().disconnect();
    await connection().disconnect();
    expect(h.vault.value, isNull);
    expect(
      (await accounts.get(Destination.x)).state,
      AccountState.disconnected,
    );
    expect(await accounts.instagramAssistedSharing(), isFalse);
    expect(
      (await SqliteDraftRepository(
        h.fixture.database,
        media: h.fixture.files,
      ).get('draft-1'))!.shared.text,
      'Kept draft',
    );
    expect(
      (await h.fixture.database.db.query('instagram_packages'))
          .single['payload'],
      'original Instagram package',
    );
    expect(
      (await h.fixture.database.db.query('instagram_events')).single['payload'],
      'original Instagram result',
    );
    expect(
      (await h.fixture.database.db.query('export_jobs')).single['uri'],
      'content://synthetic/kept',
    );
  });
}
