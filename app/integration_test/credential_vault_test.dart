import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('P2_VAULT_PHASE');
  const first = 'caption-p2-native-vault-v1-synthetic-only';
  const rotated = 'caption-p2-native-vault-v2-synthetic-only';
  const vault = SecureCredentialVault();
  testWidgets('native credential durability $phase (synthetic only)', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      final stored = await vault.read(Destination.x);
      switch (phase) {
        case 'write':
          // Never print or replace credentials already present on this test app.
          if (stored != null) {
            fail('Existing X material found; fixture left untouched.');
          }
          const channel = MethodChannel('crossposting/accounts');
          expect(
            await channel.invokeMethod<bool>(
              'prepareXAuthorization',
              'com.example.caption:/wrong',
            ),
            isFalse,
          );
          expect(
            await channel.invokeMethod<bool>(
              'prepareXAuthorization',
              'com.example.caption:/x',
            ),
            isTrue,
          );
          expect(
            await channel.invokeMethod<bool>(
              'prepareXAuthorization',
              'com.example.caption:/x',
            ),
            isFalse,
          );
          await channel.invokeMethod<void>('finishXAuthorization');
          await vault.write(Destination.x, first);
        case 'rotate':
          if (stored != first) {
            fail('Unexpected X material; fixture left untouched.');
          }
          await vault.write(Destination.x, rotated);
        case 'delete':
          if (stored != rotated) {
            fail('Unexpected X material; fixture left untouched.');
          }
          await vault.delete(Destination.x);
        case 'absent':
          if (stored != null) {
            fail('X deletion did not persist; material left untouched.');
          }
        default:
          fail('Select one explicitly authorized P2 fixture phase.');
      }
    });
    debugPrint('P2 native vault phase $phase verified');
  });
}
