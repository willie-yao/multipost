import '../../app/app_configuration.dart';
import '../../storage/local_database.dart';
import '../drafts/draft.dart';
import 'account.dart';

abstract interface class AccountRepository {
  Future<List<AccountView>> list();
  Future<bool> instagramAssistedSharing();
  Future<void> setInstagramAssistedSharing(bool enabled);
}

/// Capability metadata only. Official connection flows arrive in P2/P3.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(this.database, {AppConfiguration? configuration})
    : configuration = configuration ?? AppConfiguration.fromEnvironment();
  final LocalDatabase database;
  final AppConfiguration configuration;

  @override
  Future<List<AccountView>> list() async => List<AccountView>.unmodifiable([
    for (final destination in [Destination.x, Destination.bluesky])
      AccountView(
        destination: destination,
        state: configuration.connection(destination).available
            ? AccountState.disconnected
            : AccountState.unavailable,
        capability: configuration.connection(destination).reason,
      ),
    const AccountView(
      destination: Destination.instagram,
      state: AccountState.unavailable,
      capability: 'You finish it in Instagram · choose the account there',
    ),
  ]);

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
