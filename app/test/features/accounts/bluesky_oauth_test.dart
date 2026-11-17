import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/bluesky_oauth.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../support/account_fixture.dart';
import '../../support/bluesky_fixture.dart';

void main() {
  test('real SDK handles PAR and API nonce challenge through secure stores', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    h.challengePar = true;
    h.challengeApi = true;
    await h.connect();
    final client = await h.connection.authorizedClient(expectedDid: blueskyDid);
    final profile = await client.actor.getProfile(actor: blueskyDid);
    expect(profile.data.did, blueskyDid);
    expect(h.pars, 2);
    expect(h.apis, 2);
    expect(
      h.requests
          .firstWhere((r) => r.url.path == '/oauth/par')
          .bodyFields['scope'],
      'atproto repo:app.bsky.feed.post?action=create blob:image/* blob:video/*',
    );
    expect(h.proofs.first['htm'], 'POST');
    expect(h.proofs.first['htu'], 'https://bsky.social/oauth/par');
    expect(h.proofs[1]['nonce'], 'synthetic-/oauth/par-nonce');
    expect(h.proofs[0]['jti'], isNot(h.proofs[1]['jti']));
    final rows = await h.fixture.database.db.query('accounts');
    expect(jsonEncode(rows), isNot(contains('synthetic-access')));
    expect(h.vault.value, contains('dpop_private_key'));
  });
  for (final name in ['client', 'redirect', 'native', 'dpop', 'scopes']) {
    test('rejects invalid client metadata $name before discovery', () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      h.changeMetadata = (j) {
        switch (name) {
          case 'client':
            j['client_id'] = 'https://foreign.example/client.json';
          case 'redirect':
            j['redirect_uris'] = ['com.example.caption://wrong/callback'];
          case 'native':
            j['application_type'] = 'web';
          case 'dpop':
            j.remove('dpop_bound_access_tokens');
          case 'scopes':
            j['scope'] = 'atproto';
        }
      };
      await expectLater(
        h.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.requests, hasLength(1));
      expect(h.tokens, 0);
    });
  }
  for (final name in [
    'missing',
    'throws',
    'issuer',
    'par',
    'S256',
    'ES256',
    'iss',
    'required',
  ]) {
    test(
      'swallowed invalid AS discovery $name cannot admit guessed endpoints',
      () async {
        final h = await HostedBlueskyHarness.create();
        addTearDown(h.close);
        h.metadataMissing = name == 'missing';
        if (name == 'throws') {
          h.errorPath = '/.well-known/oauth-authorization-server';
          h.requestError = http.ClientException('synthetic');
        }
        h.changeDiscovery = (j) {
          switch (name) {
            case 'issuer':
              j['issuer'] = 'https://evil.example';
            case 'par':
              j['pushed_authorization_request_endpoint'] =
                  'https://evil.example/oauth/par';
            case 'S256':
              j['code_challenge_methods_supported'] = ['plain'];
            case 'ES256':
              j['dpop_signing_alg_values_supported'] = ['RS256'];
            case 'iss':
              j['authorization_response_iss_parameter_supported'] = false;
            case 'required':
              j['require_pushed_authorization_requests'] = false;
          }
        };
        await expectLater(
          h.connect(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        expect(h.pars, 0);
        expect(h.tokens, 0);
        expect(h.requests.any((r) => r.method == 'POST'), isFalse);
      },
    );
  }
  for (final target in [
    'com.example.other:/callback',
    'com.example.caption:/wrong',
    'com.example.caption://evil/callback',
    'com.example.caption:/callback#fragment',
  ]) {
    test(
      'wrong exact callback target $target is rejected before exchange',
      () async {
        final h = await HostedBlueskyHarness.create();
        addTearDown(h.close);
        h.changeCallback = (value) =>
            value.replaceFirst('com.example.caption:/callback', target);
        await expectLater(
          h.connect(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        expect(h.tokens, 0);
      },
    );
  }
  for (final suffix in [
    '&state=duplicate',
    '&code=duplicate',
    '&iss=https://evil.example',
    '&error=denied',
  ]) {
    test('ambiguous callback $suffix is rejected before exchange', () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      h.changeCallback = (value) => '$value$suffix';
      await expectLater(
        h.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.tokens, 0);
    });
  }
  for (final name in [
    'bearer',
    'missing-type',
    'missing-sub',
    'changed-sub',
    'missing-scope',
    'reduced-scope',
    'wrong-client',
  ]) {
    test(
      'raw invalid token $name is rejected before secure session persistence',
      () async {
        final h = await HostedBlueskyHarness.create();
        addTearDown(h.close);
        h.changeToken = (j) {
          switch (name) {
            case 'bearer':
              j['token_type'] = 'Bearer';
            case 'missing-type':
              j.remove('token_type');
            case 'missing-sub':
              j.remove('sub');
            case 'changed-sub':
              j['sub'] = 'did:plc:zzzzzzzzzzzzzzzzzzzzzzzz';
            case 'missing-scope':
              j.remove('scope');
            case 'reduced-scope':
              j['scope'] = 'atproto';
            case 'wrong-client':
              j['client_id'] = 'https://foreign.example/client.json';
          }
        };
        await expectLater(
          h.connect(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        expect(jsonDecode(h.vault.value!)['session'], isNull);
        expect(
          (await h.accounts.get(Destination.bluesky)).state,
          isNot(AccountState.connected),
        );
      },
    );
  }
  for (final path in ['/oauth/par', '/oauth/token']) {
    test('signed $path requires response nonce', () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      h.omitNoncePath = path;
      await expectLater(
        h.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(
        (await h.accounts.get(Destination.bluesky)).state,
        isNot(AccountState.connected),
      );
    });
  }
  test(
    'custom PDS and did:web fail before sending credentials outside provider',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      h.pds = 'https://pds.other.example';
      await expectLater(h.connect(), throwsA(isA<UnsupportedBlueskyAccount>()));
      expect(
        h.requests.every(
          (r) =>
              r.url.host == 'caption.example.com' ||
              r.url.host == 'public.api.bsky.app' ||
              r.url.host == 'plc.directory',
        ),
        isTrue,
      );
      h.pds = blueskyPds;
      h.resolvedDid = 'did:web:evil.example';
      await expectLater(h.connect(), throwsA(isA<UnsupportedBlueskyAccount>()));
      expect(h.requests.any((r) => r.url.host == 'evil.example'), isFalse);
    },
  );
  test('malicious resource metadata never contacts a foreign issuer', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    h.changeResource = (j) =>
        j['authorization_servers'] = ['https://evil.example'];
    await expectLater(
      h.connect(),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    expect(h.requests.any((r) => r.url.host == 'evil.example'), isFalse);
    expect(h.pars, 0);
  });
  test('API GET, create, binary and error responses all enforce nonce with no ambiguous resend', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    await h.connect();
    final client = await h.connection.authorizedClient(expectedDid: blueskyDid);
    h.omitNonce = true;
    await expectLater(
      client.actor.getProfile(actor: blueskyDid),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    await expectLater(
      client.atproto.repo.createRecord(
        repo: blueskyDid,
        collection: 'app.bsky.feed.post',
        record: {'text': 'synthetic'},
      ),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    await expectLater(
      client.atproto.repo.uploadBlob(bytes: Uint8List.fromList([1, 2])),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    h.responseStatus = 503;
    await expectLater(
      client.atproto.repo.createRecord(
        repo: blueskyDid,
        collection: 'app.bsky.feed.post',
        record: {'text': 'synthetic'},
      ),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    expect(h.apis, 4);
  });
  test('foreign API service override is denied before network and stale client is fenced', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    await h.connect();
    final client = await h.connection.authorizedClient(expectedDid: blueskyDid);
    final count = h.requests.length;
    await expectLater(
      client.actor.getProfile(actor: blueskyDid, $service: 'evil.example'),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    expect(h.requests, hasLength(count));
    await h.connection.disconnect();
    await expectLater(
      client.actor.getProfile(actor: blueskyDid),
      throwsA(isA<AccountConnectionCancelled>()),
    );
    expect(h.requests, hasLength(count));
  });
  test(
    'refresh single-flights and awaits secure rotation before an action',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      await h.connect();
      await h.expireStoredSession();
      h.tokenStarted = Completer<void>();
      h.tokenBarrier = Completer<void>();
      var done = false;
      final checking = Future.wait([
        h.connection.ensureAuthorized(),
        h.connection.ensureAuthorized(),
      ]).then((_) => done = true);
      await h.tokenStarted!.future;
      h.vault.writeBarrier = Completer<void>();
      h.vault.writeStarted = Completer<void>();
      h.tokenBarrier!.complete();
      await h.vault.writeStarted!.future;
      expect(done, isFalse);
      expect(h.refreshes, 1);
      h.vault.writeBarrier!.complete();
      await checking;
      expect(h.vault.value, contains('synthetic-refresh-1'));
      h.vault.writeBarrier = null;
      h.vault.writeStarted = null;
      h.rebuild();
      await h.connection.ensureAuthorized();
      expect(h.refreshes, 1);
    },
  );
  test(
    'offline refresh preserves session; invalid_grant marks expired',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      await h.connect();
      await h.expireStoredSession();
      final stored = h.vault.value;
      h.errorPath = '/oauth/token';
      h.requestError = const SocketException('synthetic');
      await expectLater(
        h.connection.ensureAuthorized(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.vault.value, stored);
      expect(
        (await h.accounts.get(Destination.bluesky)).state,
        AccountState.connected,
      );
      h.requestError = null;
      h.responseStatus = 400;
      h.changeToken = (j) {
        j.clear();
        j['error'] = 'invalid_grant';
      };
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
  test('acquired client revocation expires immediately and fences further network use', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    await h.connect();
    final client = await h.connection.authorizedClient(expectedDid: blueskyDid);
    h.override = (request) {
      final path = request.url.path;
      if (path == '/xrpc/app.bsky.actor.getProfile') {
        return h.json(
          {'error': 'ExpiredToken'},
          status: 401,
          signed: true,
          path: path,
        );
      }
      if (path == '/oauth/token') {
        return h.json(
          {'error': 'invalid_grant'},
          status: 400,
          signed: true,
          path: path,
        );
      }
      return null;
    };
    await expectLater(
      client.actor
          .getProfile(actor: blueskyDid)
          .timeout(const Duration(seconds: 5)),
      throwsException,
    );
    expect(
      h.requests.where(
        (r) =>
            r.url.path == '/oauth/token' &&
            r.bodyFields['grant_type'] == 'refresh_token',
      ),
      hasLength(1),
    );
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.expired,
    );
    final envelope = jsonDecode(h.vault.value!) as Map<String, dynamic>;
    expect(envelope['session'], isNull);
    expect(envelope['identity'], isNull);
    final count = h.requests.length;
    await expectLater(
      client.actor.getProfile(actor: blueskyDid),
      throwsA(isA<AccountConnectionCancelled>()),
    );
    expect(h.requests, hasLength(count));
    await expectLater(
      h.connection.ensureAuthorized(),
      throwsA(isA<AccountConnectionExpired>()),
    );
    h.rebuild();
    await expectLater(
      h.connection.ensureAuthorized(),
      throwsA(isA<AccountConnectionExpired>()),
    );
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.expired,
    );
    expect(h.requests, hasLength(count));
  });
  test('same DID handle refresh persists before public reconciliation and survives ensure and restart', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    await h.connect();
    final reviewed = await h.accounts.get(Destination.bluesky);
    await h.expireStoredSession();
    h.override = (request) => request.url.host == 'plc.directory'
        ? h.json({
            'id': blueskyDid,
            'alsoKnownAs': ['at://renamed.test'],
            'service': [
              {
                'id': '#atproto_pds',
                'type': 'AtprotoPersonalDataServer',
                'serviceEndpoint': blueskyPds,
              },
            ],
          })
        : null;
    h.tokenStarted = Completer<void>();
    h.tokenBarrier = Completer<void>();
    final checking = h.connection.ensureAuthorized();
    await h.tokenStarted!.future;
    h.vault.writeBarrier = Completer<void>();
    h.vault.writeStarted = Completer<void>();
    h.tokenBarrier!.complete();
    await h.vault.writeStarted!.future;
    expect(await h.accounts.get(Destination.bluesky), reviewed);
    expect(
      (jsonDecode(h.vault.value!)['identity'] as Map)['handle'],
      '@person.test',
    );
    h.vault.writeBarrier!.complete();
    await checking;
    h.vault.writeBarrier = null;
    h.vault.writeStarted = null;
    final current = await h.accounts.get(Destination.bluesky);
    expect(current.state, AccountState.connected);
    expect(current.identity?.subject, blueskyDid);
    expect(current.identity?.handle, '@renamed.test');
    expect(reviewed.identity?.handle, '@person.test');
    await h.connection.ensureAuthorized();
    // Simulate process loss after a secure commit but before the public update.
    await h.accounts.save(reviewed);
    await h.fixture.reopen();
    h.rebuild();
    await h.connection.ensureAuthorized();
    expect(await h.accounts.get(Destination.bluesky), current);
    expect(h.refreshes, 1);
    await expectLater(
      h.connection.authorizedClient(
        expectedDid: 'did:plc:zzzzzzzzzzzzzzzzzzzzzzzz',
      ),
      throwsA(isA<AccountConnectionExpired>()),
    );
  });
  for (final recovery in ['repair', 'removal']) {
    test(
      'compound nonce and SQLite failure requires explicit $recovery after stores recover',
      () async {
        final h = await HostedBlueskyHarness.create();
        addTearDown(h.close);
        await h.connect();
        final client = await h.connection.authorizedClient(
          expectedDid: blueskyDid,
        );
        await h.fixture.database.db.execute("""
      CREATE TRIGGER reject_bluesky_account_write BEFORE INSERT ON accounts
      WHEN NEW.destination = 'bluesky'
      BEGIN SELECT RAISE(FAIL, 'synthetic public write failure'); END
    """);
        h.vault.writeFails = true;
        await expectLater(
          client.actor.getProfile(actor: blueskyDid),
          throwsA(isA<CredentialStorageFailure>()),
        );
        h.vault.writeFails = false;
        final count = h.requests.length;
        await expectLater(
          client.actor.getProfile(actor: blueskyDid),
          throwsA(isA<AccountConnectionCancelled>()),
        );
        expect(h.requests, hasLength(count));
        await h.fixture.database.db.execute(
          'DROP TRIGGER reject_bluesky_account_write',
        );
        await expectLater(
          h.connection.authorizedClient(expectedDid: blueskyDid),
          throwsA(isA<CredentialStorageFailure>()),
        );
        expect(h.requests, hasLength(count));
        expect(
          (await h.accounts.get(Destination.bluesky)).state,
          AccountState.repairRequired,
        );
        if (recovery == 'repair') {
          h.vault.repairFails = true;
          await expectLater(
            h.connection.repairCredentials(),
            throwsA(isA<CredentialStorageFailure>()),
          );
          h.vault.repairFails = false;
        } else {
          h.vault.deleteFails = true;
          await expectLater(
            h.connection.disconnect(),
            throwsA(isA<CredentialStorageFailure>()),
          );
          h.vault.deleteFails = false;
        }
        await expectLater(
          h.connection.authorizedClient(expectedDid: blueskyDid),
          throwsA(isA<CredentialStorageFailure>()),
        );
        expect(
          (await h.accounts.get(Destination.bluesky)).state,
          recovery == 'repair'
              ? AccountState.repairRequired
              : AccountState.removalPending,
        );
        await expectLater(
          h.connect(),
          throwsA(isA<CredentialStorageFailure>()),
        );
        expect(h.requests, hasLength(count));
        if (recovery == 'repair') {
          await h.connection.repairCredentials();
        } else {
          await h.connection.disconnect();
        }
        expect(
          (await h.accounts.get(Destination.bluesky)).state,
          AccountState.disconnected,
        );
        expect(h.vault.value, isNull);
        await h.connect();
        await h.connection.ensureAuthorized();
        expect(
          (await h.accounts.get(Destination.bluesky)).state,
          AccountState.connected,
        );
      },
    );
  }

  test(
    'refresh failure to save rotation requires repair and blocks action',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      await h.connect();
      await h.expireStoredSession();
      h.tokenStarted = Completer<void>();
      h.tokenBarrier = Completer<void>();
      final checking = h.connection.ensureAuthorized();
      final failed = expectLater(
        checking,
        throwsA(isA<CredentialStorageFailure>()),
      );
      await h.tokenStarted!.future;
      h.vault.writeFails = true;
      h.tokenBarrier!.complete();
      await failed;
      expect(
        (await h.accounts.get(Destination.bluesky)).state,
        AccountState.repairRequired,
      );
      h.vault.writeFails = false;
      // A readable vault does not clear the owner's explicit-repair latch.
      await expectLater(
        h.connection.authorizedClient(expectedDid: blueskyDid),
        throwsA(isA<CredentialStorageFailure>()),
      );
    },
  );
  test(
    'redirect and oversized metadata are rejected without downstream requests',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      h.override = (_) =>
          http.Response('', 302, headers: {'location': 'https://evil.example'});
      await expectLater(
        h.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.requests, hasLength(1));
      h.override = (_) => http.Response('x' * (512 * 1024 + 1), 200);
      await expectLater(
        h.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.requests, hasLength(2));
    },
  );
  for (final name in [
    'missing-type',
    'missing-sub',
    'missing-scope',
    'reduced-scope',
    'changed-sub',
  ]) {
    test(
      'raw refresh $name cannot replace the persisted bound session',
      () async {
        final h = await HostedBlueskyHarness.create();
        addTearDown(h.close);
        await h.connect();
        await h.expireStoredSession();
        final before =
            (jsonDecode(h.vault.value!) as Map<String, dynamic>)['session'];
        h.changeToken = (j) {
          switch (name) {
            case 'missing-type':
              j.remove('token_type');
            case 'missing-sub':
              j.remove('sub');
            case 'missing-scope':
              j.remove('scope');
            case 'reduced-scope':
              j['scope'] = 'atproto';
            case 'changed-sub':
              j['sub'] = 'did:plc:zzzzzzzzzzzzzzzzzzzzzzzz';
          }
        };
        await expectLater(
          h.connection.ensureAuthorized(),
          throwsA(isA<AccountConnectionUnavailable>()),
        );
        expect(
          (jsonDecode(h.vault.value!) as Map<String, dynamic>)['session'],
          before,
        );
        expect(h.refreshes, 1);
      },
    );
  }
  test(
    'disconnect fences refresh that completes after secure removal',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      await h.connect();
      await h.expireStoredSession();
      h.tokenStarted = Completer<void>();
      h.tokenBarrier = Completer<void>();
      final checking = h.connection.ensureAuthorized();
      final failed = expectLater(
        checking,
        throwsA(isA<AccountConnectionCancelled>()),
      );
      await h.tokenStarted!.future;
      await h.connection.disconnect();
      h.tokenBarrier!.complete();
      await failed;
      expect(h.vault.value, isNull);
      expect(
        (await h.accounts.get(Destination.bluesky)).state,
        AccountState.disconnected,
      );
    },
  );
  test(
    'unsupported reconnect preserves the previous usable identity and session',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      await h.connect();
      final before = await h.accounts.get(Destination.bluesky);
      final stored = h.vault.value;
      h.pds = 'https://other.example';
      await expectLater(h.connect(), throwsA(isA<UnsupportedBlueskyAccount>()));
      expect(await h.accounts.get(Destination.bluesky), before);
      expect(h.vault.value, stored);
      h.pds = blueskyPds;
      await h.connection.ensureAuthorized();
    },
  );
  test('API nonce success persistence is awaited and a failure blocks subsequent use', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    await h.connect();
    final client = await h.connection.authorizedClient(expectedDid: blueskyDid);
    h.vault.writeBarrier = Completer<void>();
    h.vault.writeStarted = Completer<void>();
    var done = false;
    final call = client.actor
        .getProfile(actor: blueskyDid)
        .then((_) => done = true);
    await h.vault.writeStarted!.future;
    expect(done, isFalse);
    h.vault.writeBarrier!.complete();
    await call;
    h.vault.writeBarrier = null;
    h.vault.writeStarted = null;
    h.clock.value = h.clock.value.add(const Duration(minutes: 6));
    h.vault.writeFails = true;
    await expectLater(
      client.actor.getProfile(actor: blueskyDid),
      throwsA(isA<CredentialStorageFailure>()),
    );
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.repairRequired,
    );
    final count = h.apis;
    await expectLater(
      client.actor.getProfile(actor: blueskyDid),
      throwsA(isA<AccountConnectionCancelled>()),
    );
    expect(h.apis, count);
  });
  test(
    'API challenge retries are bounded and ambiguous create is not resent',
    () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      await h.connect();
      final client = await h.connection.authorizedClient(
        expectedDid: blueskyDid,
      );
      h.alwaysChallengeApi = true;
      await expectLater(
        client.actor.getProfile(actor: blueskyDid),
        throwsException,
      );
      expect(h.apis, 4);
      h.alwaysChallengeApi = false;
      h.responseStatus = 503;
      await expectLater(
        client.atproto.repo.createRecord(
          repo: blueskyDid,
          collection: 'app.bsky.feed.post',
          record: {'text': 'synthetic'},
        ),
        throwsException,
      );
      expect(h.apis, 5);
    },
  );
  test('pending process-loss state is cancelled without losing an existing session', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    await h.connect();
    final before = await h.accounts.get(Destination.bluesky);
    h.browser = Completer<String>();
    final reconnecting = h.connection.connect(handle: 'person.test');
    final failed = expectLater(
      reconnecting,
      throwsA(isA<AccountConnectionCancelled>()),
    );
    // Await the real SDK's persisted new flow, then retain its disk snapshot as
    // the restarted process would see it; no old process callback can resume.
    for (
      var n = 0;
      n < 100 && !(h.vault.value?.contains('"pending"') ?? false);
      n++
    ) {
      await pumpEventQueue();
    }
    final snapshot = h.vault.value;
    expect(snapshot, contains('"pending"'));
    await h.connection.disconnect();
    h.browser!.complete('ignored');
    await failed;
    h.vault.value = snapshot;
    await h.accounts.save(before);
    h.rebuild();
    await h.connection.ensureAuthorized();
    expect(h.vault.value, isNot(contains('"pending"')));
    expect(h.vault.value, contains('synthetic-refresh-0'));
    expect(await h.stores.states.find(h.state!), isNull);
  });

  for (final name in [
    'forged-state',
    'forged-issuer',
    'missing-issuer',
    'expired-state',
  ]) {
    test('callback $name is rejected without token exchange', () async {
      final h = await HostedBlueskyHarness.create();
      addTearDown(h.close);
      h.changeCallback = (value) {
        switch (name) {
          case 'forged-state':
            return value.replaceFirst('state=${h.state}', 'state=forged');
          case 'forged-issuer':
            return value.replaceFirst(
              'https%3A%2F%2Fbsky.social',
              'https%3A%2F%2Fevil.example',
            );
          case 'missing-issuer':
            return value.replaceFirst('&iss=https%3A%2F%2Fbsky.social', '');
          case 'expired-state':
            h.clock.value = h.clock.value.add(const Duration(minutes: 11));
            return value;
        }
        return value;
      };
      await expectLater(
        h.connect(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(h.tokens, 0);
      expect(h.vault.value, isNot(contains('"pending"')));
    });
  }
  test('a durably validated session becomes Connected without another network dependency', () async {
    final h = await HostedBlueskyHarness.create();
    addTearDown(h.close);
    h.override = (request) {
      if (request.url.host == 'plc.directory' &&
          h.requests.where((r) => r.url.host == 'plc.directory').length > 2) {
        return http.Response('synthetic outage', 503);
      }
      return null;
    };
    await h.connect();
    expect(
      (await h.accounts.get(Destination.bluesky)).state,
      AccountState.connected,
    );
  });
}
