import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../drafts/draft.dart';

abstract interface class CredentialVault {
  Future<String?> read(Destination destination);
  Future<void> write(Destination destination, String session);
  Future<void> delete(Destination destination);

  /// Destructive only after an explicit user-confirmed account repair.
  Future<void> repair(Destination destination);
}

class CredentialStorageFailure implements Exception {
  const CredentialStorageFailure();
  @override
  String toString() => "Couldn't securely save this connection. Try again.";
}

/// Fixed provider namespaces isolate ciphertext, wrapped keys and Keystore aliases.
/// Coupled to flutter_secure_storage 11.2.0's cache and disk-write contract.
class SecureCredentialVault implements CredentialVault {
  const SecureCredentialVault();
  static const _x = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'caption_x_credentials',
    ),
  );
  static const _bluesky = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'caption_bluesky_credentials',
    ),
  );
  static const _repairX = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      migrateOnAlgorithmChange: false,
      storageNamespace: 'caption_x_credentials',
    ),
  );
  static const _repairBluesky = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      migrateOnAlgorithmChange: false,
      storageNamespace: 'caption_bluesky_credentials',
    ),
  );
  static const _channel = MethodChannel('crossposting/accounts');
  // Plugin recreation affects its whole in-memory cache. Serialize EVERY call,
  // including other provider/other vault instances, across the repair boundary.
  static Future<void> _operations = Future.value();
  static bool _cacheReady = true;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _operations.then((_) async {
      try {
        return await action();
      } catch (_) {
        throw const CredentialStorageFailure();
      }
    });
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  FlutterSecureStorage _storage(Destination destination) {
    if (!_cacheReady) throw const CredentialStorageFailure();
    return switch (destination) {
      Destination.x => _x,
      Destination.bluesky => _bluesky,
      Destination.instagram => throw const CredentialStorageFailure(),
    };
  }

  String _key(Destination destination) => 'session.${destination.name}';

  @override
  Future<String?> read(Destination destination) =>
      _serial(() => _storage(destination).read(key: _key(destination)));

  @override
  Future<void> write(Destination destination, String session) =>
      _serial(() async {
        await _storage(destination)
            .write(key: _key(destination), value: session);
        await _commit(destination);
      });

  @override
  Future<void> delete(Destination destination) => _serial(() async {
    await _storage(destination).delete(key: _key(destination));
    await _commit(destination);
  });

  @override
  Future<void> repair(Destination destination) => _serial(() async {
    final storage = switch (destination) {
      Destination.x => _repairX,
      Destination.bluesky => _repairBluesky,
      Destination.instagram => throw const CredentialStorageFailure(),
    };
    _cacheReady = false;
    try {
      await _reinitialize();
      // Supported reset/reinitialization handles an unusable wrapping key;
      // deleteAll also removes a healthy session on this deliberate action.
      await storage.deleteAll();
      await _commit(destination);
    } finally {
      // initialize() caches resetOnError; never let ordinary operations inherit true.
      await _reinitialize();
      _cacheReady = true;
    }
  });

  Future<void> _reinitialize() async {
    if (await _channel.invokeMethod<bool>('reinitializeCredentialStorage') !=
        true) {
      throw const CredentialStorageFailure();
    }
  }

  Future<void> _commit(Destination destination) async {
    if (await _channel.invokeMethod<bool>(
          'commitCredentials',
          destination.name,
        ) !=
        true) {
      throw const CredentialStorageFailure();
    }
  }
}
