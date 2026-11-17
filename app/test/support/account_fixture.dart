import 'dart:async';
import 'dart:convert';

import 'package:atproto_oauth/atproto_oauth.dart';
import 'package:bluesky/bluesky.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/bluesky_connection.dart';
import 'package:cross_posting_app/features/accounts/bluesky_oauth.dart';

import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/accounts/x_connection.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'database_fixture.dart';

class AccountClock extends Clock {
  DateTime value = DateTime.utc(2026, 11, 16);
  @override
  DateTime now() => value;
}

class MemoryCredentialVault implements CredentialVault {
  MemoryCredentialVault({this.primaryDestination = Destination.x});
  final Destination primaryDestination;
  final values = <Destination, String>{};
  String? get value => values[primaryDestination];
  set value(String? next) {
    if (next == null) {
      values.remove(primaryDestination);
    } else {
      values[primaryDestination] = next;
    }
  }

  bool writeFails = false;
  bool readFails = false;
  bool deleteFails = false;
  Completer<void>? writeBarrier;
  Completer<void>? writeStarted;
  Completer<void>? repairStarted;
  Completer<void>? repairBarrier;
  bool repairFails = false;
  @override
  Future<String?> read(Destination destination) async {
    if (readFails) throw const CredentialStorageFailure();
    return values[destination];
  }

  @override
  Future<void> write(Destination destination, String session) async {
    if (!(writeStarted?.isCompleted ?? true)) writeStarted!.complete();
    await writeBarrier?.future;
    if (writeFails) throw const CredentialStorageFailure();
    values[destination] = session;
  }

  @override
  Future<void> repair(Destination destination) async {
    repairStarted?.complete();
    await repairBarrier?.future;
    if (repairFails) throw const CredentialStorageFailure();
    values.remove(destination);
    readFails = false;
    writeFails = false;
    deleteFails = false;
  }

  @override
  Future<void> delete(Destination destination) async {
    if (deleteFails) throw const CredentialStorageFailure();
    values.remove(destination);
  }
}

class FakeXOAuthDriver implements XOAuthDriver {
  FakeXOAuthDriver(this.clock);
  final Clock clock;
  Object? authorizeError;
  Object? refreshError;
  Completer<XTokenSet>? authorization;
  Completer<XTokenSet>? rotation;
  int refreshCalls = 0;
  int authorizeCalls = 0;
  final refreshStarted = Completer<void>();
  XTokenSet tokens([String suffix = 'initial']) => XTokenSet(
    accessToken: 'opaque-access-$suffix',
    refreshToken: 'opaque-refresh-$suffix',
    expiresAt: clock.now().add(const Duration(hours: 2)),
  );
  @override
  Future<XTokenSet> authorize() async {
    authorizeCalls++;
    if (authorizeError case final error?) throw error;
    return authorization == null ? tokens() : authorization!.future;
  }

  @override
  Future<XTokenSet> refresh(String refreshToken) async {
    refreshCalls++;
    if (!refreshStarted.isCompleted) refreshStarted.complete();
    if (refreshError case final error?) throw error;
    return rotation == null ? tokens('rotated') : rotation!.future;
  }
}

class AccountHarness {
  AccountHarness._(this.fixture) {
    accounts = LocalAccountRepository(
      fixture.database,
      configuration: configuration,
    );
    drafts = SqliteDraftRepository(fixture.database, media: fixture.files);
    oauth = FakeXOAuthDriver(clock);
    client = MockClient((request) async {
      identityRequests++;
      lastIdentityRequest = request;
      if (identityError case final error?) throw error;
      return http.Response(
        '{"data":{"id":"$subject","username":"$handle"}}',
        identityStatus,
      );
    });
    x = XConnection(
      configuration: configuration,
      driver: oauth,
      vault: vault,
      accounts: accounts,
      client: client,
      clock: clock,
    );
  }
  final DatabaseFixture fixture;
  final configuration = AppConfiguration(
    xClientId: 'public-fixture-id',
    xRedirectUri: Uri.parse('com.example.caption:/x'),
    blueskyMetadataUri: Uri(),
    blueskyCallbackScheme: '',
  );
  final clock = AccountClock();
  final vault = MemoryCredentialVault();
  late final LocalAccountRepository accounts;
  late final DraftRepository drafts;
  late final FakeXOAuthDriver oauth;
  late final http.Client client;
  late final XConnection x;
  Object? identityError;
  int identityStatus = 200;
  String subject = '12345';
  String handle = 'person';
  int identityRequests = 0;
  http.Request? lastIdentityRequest;

  static Future<AccountHarness> create({bool vaultWriteFails = false}) async {
    final h = AccountHarness._(await DatabaseFixture.create());
    h.vault.writeFails = vaultWriteFails;
    await h.drafts.save(
      Draft(
        id: 'draft-1',
        updatedAt: h.clock.now(),
        shared: PostContent(text: 'Kept draft'),
        selected: {Destination.x},
      ),
      expectedRevision: -1,
    );
    return h;
  }

  Future<void> close() async {
    client.close();
    await fixture.dispose();
  }
}

Future<AccountHarness> accountHarness({bool vaultWriteFails = false}) =>
    AccountHarness.create(vaultWriteFails: vaultWriteFails);

const blueskyDid = 'did:plc:abcdefghijklmnopqrstuvwx';
const blueskyPds = 'https://test.us-east.host.bsky.network';

class FakeATProtoOAuthDriver implements ATProtoOAuthDriver {
  FakeATProtoOAuthDriver(this.stores, this.configuration);
  final BlueskyOAuthStores stores;
  final AppConfiguration configuration;
  int restoreCount = 0;
  Object? authorizeError;
  Object? identityError;
  Completer<void>? callbackBarrier;
  final callbackStarted = Completer<void>();
  OAuthSession session() => OAuthSession(
    accessToken: 'synthetic-access',
    refreshToken: 'synthetic-refresh',
    tokenType: 'DPoP',
    scope: blueskyWriteScope,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    sub: blueskyDid,
    issuer: 'https://bsky.social',
    pds: blueskyPds,
    clientId: configuration.blueskyMetadataUri.toString(),
    dpopPublicKey: 'public-test-key',
    dpopPrivateKey: 'private-test-key',
  );
  @override
  Future<Uri> authorize(String handle) async {
    if (authorizeError case final error?) throw error;
    await stores.states.set(
      'synthetic-state',
      const OAuthContext(
        codeVerifier: 'synthetic-verifier',
        state: 'synthetic-state',
        issuer: 'https://bsky.social',
        tokenEndpoint: 'https://bsky.social/oauth/token',
        dpopPublicKey: 'public-test-key',
        dpopPrivateKey: 'private-test-key',
        pds: blueskyPds,
        expectedSub: blueskyDid,
      ),
    );
    return Uri.parse(
      'https://bsky.social/oauth/authorize?request_uri=synthetic',
    );
  }

  @override
  Future<OAuthSession> callback(String url) async {
    if (!callbackStarted.isCompleted) callbackStarted.complete();
    await callbackBarrier?.future;
    final context = await stores.states.find('synthetic-state');
    if (context == null) throw const AccountConnectionUnavailable();
    final value = session();
    await stores.sessions.set(value.sub, value);
    await stores.states.delete('synthetic-state');
    return value;
  }

  @override
  Future<AccountIdentity> identityFromSession(OAuthSession session) async {
    if (identityError case final error?) throw error;
    return AccountIdentity(
      destination: Destination.bluesky,
      subject: session.sub,
      handle: '@person.test',
    );
  }

  @override
  Future<OAuthSessionManager> restore(String serializedSession) async {
    restoreCount++;
    return OAuthSessionManager.fromSession(
      OAuthSession.fromJson(
        jsonDecode(serializedSession) as Map<String, dynamic>,
      ),
    );
  }

  @override
  Bluesky client(OAuthSessionManager manager, String expectedDid) =>
      Bluesky.fromOAuth(manager);
}

class BlueskyAccountHarness {
  BlueskyAccountHarness._(this.fixture) {
    accounts = LocalAccountRepository(
      fixture.database,
      configuration: configuration,
    );
    _build();
  }
  final DatabaseFixture fixture;
  final configuration = AppConfiguration(
    xClientId: '',
    xRedirectUri: Uri(),
    blueskyMetadataUri: Uri.parse('https://caption.example.com/client.json'),
    blueskyCallbackScheme: 'com.example.caption',
  );
  final clock = AccountClock();
  final vault = MemoryCredentialVault(primaryDestination: Destination.bluesky);
  late LocalAccountRepository accounts;
  late BlueskyConnection connection;
  late FakeATProtoOAuthDriver driver;
  late BlueskyOAuthStores stores;
  Object? browserError;
  Completer<String>? browser;
  final browserStarted = Completer<void>();
  void _build() {
    connection = BlueskyConnection(
      configuration: configuration,
      vault: vault,
      accounts: accounts,
      clock: clock,
      driverFactory: (value) {
        stores = value;
        return driver = FakeATProtoOAuthDriver(value, configuration);
      },
      authorizeInBrowser: (url) async {
        if (!browserStarted.isCompleted) browserStarted.complete();
        if (browserError case final error?) throw error;
        return browser?.future ??
            '${configuration.blueskyRedirectUri}?state=synthetic-state&iss=https%3A%2F%2Fbsky.social&code=synthetic';
      },
    );
  }

  Future<void> restartConnection() async {
    accounts = LocalAccountRepository(
      fixture.database,
      configuration: configuration,
    );
    _build();
  }

  Future<void> close() => fixture.dispose();
  static Future<BlueskyAccountHarness> create() async =>
      BlueskyAccountHarness._(await DatabaseFixture.create());
}

Future<BlueskyAccountHarness> blueskyAccountHarness() =>
    BlueskyAccountHarness.create();
