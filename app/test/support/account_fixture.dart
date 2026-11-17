import 'dart:async';

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
  String? value;
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
    return value;
  }

  @override
  Future<void> write(Destination destination, String session) async {
    writeStarted?.complete();
    await writeBarrier?.future;
    if (writeFails) throw const CredentialStorageFailure();
    value = session;
  }

  @override
  Future<void> repair(Destination destination) async {
    repairStarted?.complete();
    await repairBarrier?.future;
    if (repairFails) throw const CredentialStorageFailure();
    value = null;
    readFails = false;
    writeFails = false;
    deleteFails = false;
  }

  @override
  Future<void> delete(Destination destination) async {
    if (deleteFails) throw const CredentialStorageFailure();
    value = null;
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
