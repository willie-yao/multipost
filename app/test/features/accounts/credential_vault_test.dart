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
      String? namespace;
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        expect(args['key'], 'session.x');
        final options = args['options'] as Map;
        namespace = options['storageNamespace'] as String?;
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
      expect(namespace, 'caption_x_credentials');
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
  test('explicit repair resets only its provider then restores non-destructive calls', () async {
    final calls = <String>[];
    final namespaces = <String>[];
    final resetFlags = <String>[];
    final commit = Completer<bool>();
    final started = Completer<void>();
    messenger.setMockMethodCallHandler(storage, (call) async {
      calls.add(call.method);
      final options = (call.arguments as Map)['options'] as Map;
      namespaces.add(options['storageNamespace'] as String);
      resetFlags.add(options['resetOnError'] as String);
      return null;
    });
    messenger.setMockMethodCallHandler(accounts, (call) async {
      calls.add(call.method);
      if (call.method == 'commitCredentials') {
        expect(call.arguments, 'x');
        started.complete();
        return commit.future;
      }
      return true;
    });
    var done = false;
    final repairing = vault.repair(Destination.x).then((_) => done = true);
    await started.future;
    final otherProviderRead = const SecureCredentialVault().read(
      Destination.bluesky,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, isNot(contains("read")));
    expect(done, isFalse);
    commit.complete(true);
    await repairing;
    await otherProviderRead;
    await vault.read(Destination.x);
    expect(calls, [
      'reinitializeCredentialStorage',
      'deleteAll',
      'commitCredentials',
      'reinitializeCredentialStorage',
      'read',
      'read',
    ]);
    expect(namespaces, [
      'caption_x_credentials',
      'caption_bluesky_credentials',
      'caption_x_credentials',
    ]);
    expect(resetFlags, ['true', 'false', 'false']);
  });

  test(
    'repair failure still discards destructive cache and returns safe error',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(
        storage,
        (_) async => throw PlatformException(
          code: 'key_lost',
          message: 'private key data',
        ),
      );
      messenger.setMockMethodCallHandler(accounts, (call) async {
        calls.add(call.method);
        return true;
      });
      await expectLater(
        vault.repair(Destination.x),
        throwsA(isA<CredentialStorageFailure>()),
      );
      expect(calls, [
        'reinitializeCredentialStorage',
        'reinitializeCredentialStorage',
      ]);
    },
  );
  test('failed final cache restoration blocks every normal vault instance until repair', () async {
    var reinitializations = 0;
    var packageCalls = 0;
    messenger.setMockMethodCallHandler(storage, (_) async {
      packageCalls++;
      return null;
    });
    messenger.setMockMethodCallHandler(accounts, (call) async {
      if (call.method == 'reinitializeCredentialStorage') {
        reinitializations++;
        return reinitializations != 2;
      }
      return true;
    });
    await expectLater(
      vault.repair(Destination.x),
      throwsA(isA<CredentialStorageFailure>()),
    );
    final before = packageCalls;
    await expectLater(
      const SecureCredentialVault().read(Destination.bluesky),
      throwsA(isA<CredentialStorageFailure>()),
    );
    expect(packageCalls, before);
    // A successful explicit retry restores the shared cache for all vaults.
    await vault.repair(Destination.x);
    expect(
      await const SecureCredentialVault().read(Destination.bluesky),
      isNull,
    );
  });
}
