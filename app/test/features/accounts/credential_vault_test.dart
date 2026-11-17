import 'dart:async';

import 'package:cross_posting_app/features/accounts/credential_vault.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const accounts = MethodChannel('crossposting/accounts');
  const vault = SecureCredentialVault();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(storage, null);
    messenger.setMockMethodCallHandler(accounts, null);
  });

  test(
    'write uses isolated encryption namespace and waits for disk commit',
    () async {
      final commits = Completer<bool>();
      final commitStarted = Completer<void>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        expect(args['key'], 'session.x');
        final options = args['options'] as Map;
        expect(options['storageNamespace'], 'caption_credentials');
        expect(options['resetOnError'], 'false');
        return null;
      });
      messenger.setMockMethodCallHandler(accounts, (call) async {
        calls.add(call.method);
        commitStarted.complete();
        return commits.future;
      });
      var done = false;
      final writing = vault
          .write(Destination.x, 'opaque-synthetic')
          .then((_) => done = true);
      await commitStarted.future;
      expect(done, isFalse);
      commits.complete(true);
      await writing;
      expect(calls, ['write', 'commitCredentials']);
    },
  );

  test(
    'disk commit failure and native write errors become safe storage failure',
    () async {
      messenger.setMockMethodCallHandler(storage, (_) async => null);
      messenger.setMockMethodCallHandler(accounts, (_) async => false);
      await expectLater(
        vault.write(Destination.x, 'opaque-sensitive'),
        throwsA(isA<CredentialStorageFailure>()),
      );
      messenger.setMockMethodCallHandler(
        storage,
        (_) async => throw PlatformException(
          code: 'failed',
          message: 'opaque-sensitive callback?code=private',
        ),
      );
      try {
        await vault.write(Destination.x, 'opaque-sensitive');
        fail('must fail');
      } catch (error) {
        expect(error, isA<CredentialStorageFailure>());
        expect(
          error.toString(),
          "Couldn't securely save this connection. Try again.",
        );
      }
    },
  );

  test(
    'delete waits for durable removal and read keeps opaque serialized bytes',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        return call.method == 'read' ? 'opaque-session-json' : null;
      });
      messenger.setMockMethodCallHandler(accounts, (call) async {
        calls.add(call.method);
        return true;
      });
      expect(await vault.read(Destination.bluesky), 'opaque-session-json');
      await vault.delete(Destination.bluesky);
      expect(calls, ['read', 'delete', 'commitCredentials']);
      messenger.setMockMethodCallHandler(accounts, (_) async => false);
      await expectLater(
        vault.delete(Destination.x),
        throwsA(isA<CredentialStorageFailure>()),
      );
    },
  );

  test('keystore invalidation never exposes platform exception text', () async {
    messenger.setMockMethodCallHandler(
      storage,
      (_) async => throw PlatformException(
        code: 'KeyPermanentlyInvalidatedException',
        message: 'private credentials',
      ),
    );
    await expectLater(
      vault.read(Destination.x),
      throwsA(isA<CredentialStorageFailure>()),
    );
  });
}
