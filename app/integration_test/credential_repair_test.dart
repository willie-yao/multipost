import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/accounts/x_connection.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class _Clock extends Clock {
  @override
  DateTime now() => DateTime.utc(2026, 11, 16);
}

class _Driver implements XOAuthDriver {
  String version = 'old';
  @override
  Future<XTokenSet> authorize() async => XTokenSet(
    accessToken: 'p2-repair-$version-access-synthetic',
    refreshToken: 'p2-repair-$version-refresh-synthetic',
    expiresAt: DateTime.utc(2027),
  );
  @override
  Future<XTokenSet> refresh(String refreshToken) =>
      throw StateError('No native network fixture');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('P2_REPAIR_PHASE');
  const fixtureId = String.fromEnvironment('P2_REPAIR_RUN_ID');
  const vault = SecureCredentialVault();
  testWidgets('native explicit credential repair $phase (synthetic only)', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(fixtureId)) {
        fail('Explicit synthetic run identity required.');
      }
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        p.join(support.path, 'p2-repair-native-fixture'),
      );
      final marker = File(p.join(directory.path, 'marker'));
      final blue = 'p2-repair-bluesky-synthetic-$fixtureId';
      if (!await marker.exists() || await marker.readAsString() != fixtureId) {
        fail('Unexpected fixture marker; native material left untouched.');
      }
      if (phase == 'seed' &&
          (await File(p.join(directory.path, 'fixture.db')).exists() ||
              await vault.read(Destination.x) != null ||
              await vault.read(Destination.bluesky) != null)) {
        fail('Existing material found; native fixtures left untouched.');
      }
      final database = await LocalDatabase.open(
        databaseFactory,
        p.join(directory.path, 'fixture.db'),
      );
      final accounts = LocalAccountRepository(
        database,
        configuration: AppConfiguration(
          xClientId: 'p2-repair-synthetic',
          xRedirectUri: Uri.parse('com.example.caption:/x'),
          blueskyMetadataUri: Uri(),
          blueskyCallbackScheme: '',
        ),
      );
      final driver = _Driver();
      final client = MockClient(
        (_) async => http.Response(
          '{"data":{"id":"112233","username":"p2fixture"}}',
          200,
        ),
      );
      final connection = XConnection(
        configuration: accounts.configuration,
        driver: driver,
        vault: vault,
        accounts: accounts,
        client: client,
        clock: _Clock(),
      );
      try {
        switch (phase) {
          case 'seed':
            await vault.write(Destination.bluesky, blue);
            await connection.connect();
            expect(
              (await accounts.get(Destination.x)).state,
              AccountState.connected,
            );
          case 'repair':
            if (await vault.read(Destination.bluesky) != blue) {
              fail('Unexpected other-provider material; fixtures preserved.');
            }
            await expectLater(
              connection.ensureAuthorized(),
              throwsA(isA<CredentialStorageFailure>()),
            );
            expect(
              (await accounts.get(Destination.x)).state,
              AccountState.repairRequired,
            );
            // The ordinary package paths must not silently erase the broken session.
            await expectLater(
              vault.read(Destination.x),
              throwsA(isA<CredentialStorageFailure>()),
            );
            await expectLater(
              vault.write(Destination.x, 'must-not-write'),
              throwsA(isA<CredentialStorageFailure>()),
            );
            await expectLater(
              vault.delete(Destination.x),
              throwsA(isA<CredentialStorageFailure>()),
            );
            await connection.repairCredentials();
            expect(
              (await accounts.get(Destination.x)).state,
              AccountState.disconnected,
            );
            if (await vault.read(Destination.x) != null) {
              fail('Unexpected X material; fixtures preserved.');
            }
            if (await vault.read(Destination.bluesky) != blue) {
              fail('Unexpected other-provider material; fixtures preserved.');
            }
            driver.version = 'new';
            await connection.connect();
            expect(
              (await accounts.get(Destination.x)).state,
              AccountState.connected,
            );
          case 'verify':
            final stored = await vault.read(Destination.x);
            if (stored == null) {
              fail('Repaired session missing; fixtures preserved.');
            }
            var expectedSession = false;
            try {
              final session = jsonDecode(stored) as Map<String, dynamic>;
              final identity = session['identity'] as Map<String, dynamic>;
              expectedSession =
                  session.length == 7 &&
                  session['version'] == 1 &&
                  session['accessToken'] == 'p2-repair-new-access-synthetic' &&
                  session['refreshToken'] ==
                      'p2-repair-new-refresh-synthetic' &&
                  session['clientId'] == 'p2-repair-synthetic' &&
                  session['redirectUri'] == 'com.example.caption:/x' &&
                  session['expiresAt'] == '2027-01-01T00:00:00.000Z' &&
                  identity.length == 3 &&
                  identity['destination'] == 'x' &&
                  identity['subject'] == '112233' &&
                  identity['handle'] == '@p2fixture';
            } catch (_) {
              /* Never print unexpected sensitive material. */
            }
            if (!expectedSession ||
                await vault.read(Destination.bluesky) != blue) {
              fail('Unexpected material; native fixtures preserved.');
            }
            expect(
              (await accounts.get(Destination.x)).state,
              AccountState.connected,
            );
            await connection.ensureAuthorized();
            await connection.disconnect();
            await vault.delete(Destination.bluesky);
            if (await vault.read(Destination.x) != null) {
              fail('Unexpected X material; fixtures preserved.');
            }
            if (await vault.read(Destination.bluesky) != null) {
              fail('Unexpected other-provider material; fixtures preserved.');
            }
          default:
            fail('Select one explicitly authorized native repair phase.');
        }
      } finally {
        client.close();
        await database.close();
      }
      if (phase == 'verify') {
        // Bound cleanup to this exact app-owned fixture root and run marker.
        final expected = p.normalize(
          p.join(support.path, 'p2-repair-native-fixture'),
        );
        if (p.normalize(directory.absolute.path) != expected ||
            await marker.readAsString() != fixtureId) {
          fail('Fixture cleanup guard failed; files preserved.');
        }
        await directory.delete(recursive: true);
      }
    });
    debugPrint('P2 native repair phase $phase verified');
  });
}
