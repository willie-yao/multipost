import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../drafts/draft.dart';

abstract interface class CredentialVault {
  Future<String?> read(Destination destination);
  Future<void> write(Destination destination, String session);
  Future<void> delete(Destination destination);
}

class CredentialStorageFailure implements Exception {
  const CredentialStorageFailure();
  @override
  String toString() => "Couldn't securely save this connection. Try again.";
}

/// Android Keystore-backed package encryption, with an awaited disk barrier.
/// The barrier is coupled to flutter_secure_storage 11.2.0's fixed namespace.
class SecureCredentialVault implements CredentialVault {
  const SecureCredentialVault();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'caption_credentials',
    ),
  );
  static const _channel = MethodChannel('crossposting/accounts');
  String _key(Destination destination) => 'session.${destination.name}';

  @override
  Future<String?> read(Destination destination) async {
    try {
      return await _storage.read(key: _key(destination));
    } catch (_) {
      throw const CredentialStorageFailure();
    }
  }

  @override
  Future<void> write(Destination destination, String session) async {
    try {
      await _storage.write(key: _key(destination), value: session);
      await _commit();
    } catch (_) {
      throw const CredentialStorageFailure();
    }
  }

  @override
  Future<void> delete(Destination destination) async {
    try {
      await _storage.delete(key: _key(destination));
      await _commit();
    } catch (_) {
      throw const CredentialStorageFailure();
    }
  }

  Future<void> _commit() async {
    if (await _channel.invokeMethod<bool>('commitCredentials') != true) {
      throw const CredentialStorageFailure();
    }
  }
}
