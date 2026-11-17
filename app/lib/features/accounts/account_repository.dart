import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../app/app_configuration.dart';
import '../../storage/local_database.dart';
import '../drafts/draft.dart';
import 'account.dart';

abstract interface class AccountRepository {
  Future<List<AccountView>> list();
  Future<AccountView> get(Destination destination);
  Future<void> save(AccountView account);
  Future<void> setState(Destination destination, AccountState state);
  Future<bool> instagramAssistedSharing();
  Future<void> setInstagramAssistedSharing(bool enabled);
}

/// Public identity metadata only; opaque credentials belong in CredentialVault.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this.database, {AppConfiguration? configuration})
    : configuration = configuration ?? AppConfiguration.fromEnvironment();
  final LocalDatabase database;
  final AppConfiguration configuration;

  @override
  Future<List<AccountView>> list() async => List<AccountView>.unmodifiable([
    for (final destination in Destination.values) await get(destination),
  ]);

  @override
  Future<AccountView> get(Destination destination) async {
    if (destination == Destination.instagram) {
      return const AccountView(
        destination: Destination.instagram,
        state: AccountState.unavailable,
        capability: 'You finish it in Instagram · choose the account there',
      );
    }
    final rows = await database.db.query(
      'accounts',
      where: 'destination = ?',
      whereArgs: [destination.name],
    );
    final gate = configuration.connection(destination);
    if (rows.isEmpty) {
      return AccountView(
        destination: destination,
        state: gate.available
            ? AccountState.disconnected
            : AccountState.unavailable,
        capability: gate.reason,
      );
    }
    try {
      final account = AccountView.fromJson(
        jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>,
      );
      _validate(account);
      if (account.destination != destination) throw const FormatException();
      return account.copyWith(capability: gate.reason);
    } catch (_) {
      throw const LocalStorageException(
        'This connection cannot be read. Reconnect without changing your drafts.',
      );
    }
  }

  void _validate(AccountView account) {
    if (account.destination == Destination.instagram ||
        (account.identity != null &&
            (account.identity!.destination != account.destination ||
                account.identity!.subject.isEmpty ||
                account.identity!.handle.isEmpty)) ||
        (account.state == AccountState.connected && account.identity == null)) {
      throw ArgumentError('Invalid public connection metadata.');
    }
  }

  @override
  Future<void> save(AccountView account) async {
    _validate(account);
    await database.db.insert('accounts', {
      'destination': account.destination.name,
      'payload': jsonEncode(account.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> setState(Destination destination, AccountState state) async {
    final account = await get(destination);
    await save(account.copyWith(state: state));
  }

  @override
  Future<bool> instagramAssistedSharing() async {
    final rows = await database.db.query(
      'local_preferences',
      where: 'name = ?',
      whereArgs: ['instagram_assisted'],
    );
    return rows.isEmpty || rows.single['value'] == 'true';
  }

  @override
  Future<void> setInstagramAssistedSharing(bool enabled) async {
    await database.db.transaction((tx) async {
      await tx.delete(
        'local_preferences',
        where: 'name = ?',
        whereArgs: ['instagram_assisted'],
      );
      await tx.insert('local_preferences', {
        'name': 'instagram_assisted',
        'value': '$enabled',
      });
    });
  }
}
