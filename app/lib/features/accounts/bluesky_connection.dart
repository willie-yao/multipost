import 'dart:async';
import 'dart:convert';

import 'package:atproto_oauth/atproto_oauth.dart';
import 'package:bluesky/bluesky.dart';

import '../../app/app_configuration.dart';
import '../../core/clock.dart';
import '../drafts/draft.dart';
import 'account.dart';
import 'account_repository.dart';
import 'bluesky_oauth.dart';
import 'credential_vault.dart';

/// One owner, one SDK manager, one serialized secure envelope per connection.
class BlueskyConnection implements AccountConnection {
  BlueskyConnection({
    required this.configuration,
    required this.vault,
    required this.accounts,
    required this.driverFactory,
    required this.authorizeInBrowser,
    this.clock = const Clock(),
  });
  final AppConfiguration configuration;
  final CredentialVault vault;
  final AccountRepository accounts;
  final ATProtoOAuthDriver Function(BlueskyOAuthStores) driverFactory;
  final Future<String> Function(Uri) authorizeInBrowser;
  final Clock clock;
  int _generation = 0;
  bool _credentialRepairRequired = false;
  Future<void> _mutations = Future.value();
  Future<AccountIdentity>? _connecting;
  Future<void>? _ensuring;
  ATProtoOAuthDriver? _driver;
  OAuthSessionManager? _manager;
  String? _pendingState;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _mutations.then((_) => action());
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _current(int generation) {
    if (_generation != generation) throw const AccountConnectionCancelled();
  }

  ATProtoOAuthDriver _createDriver(int generation) => driverFactory(
    BlueskyOAuthStores(
      states: _States(this, generation),
      sessions: _Sessions(this, generation),
      nonces: _Nonces(this, generation),
      checkCurrent: () => _current(generation),
    ),
  );

  Map<String, dynamic> _empty() => {
    'version': 1,
    'clientId': configuration.blueskyMetadataUri.toString(),
    'redirectUri': configuration.blueskyRedirectUri.toString(),
  };

  Future<Map<String, dynamic>> _read(int generation) async {
    _current(generation);
    String? value;
    try {
      value = await vault.read(Destination.bluesky);
    } catch (_) {
      await _storageFailed(generation);
    }
    _current(generation);
    if (value == null) return _empty();
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['version'] != 1 ||
          json['clientId'] != configuration.blueskyMetadataUri.toString() ||
          json['redirectUri'] != configuration.blueskyRedirectUri.toString()) {
        throw const FormatException();
      }
      return json;
    } catch (_) {
      throw const AccountConnectionExpired();
    }
  }

  Future<void> _write(int generation, Map<String, dynamic> value) async {
    _current(generation);
    try {
      await vault.write(Destination.bluesky, jsonEncode(value));
    } catch (_) {
      await _storageFailed(generation);
    }
    _current(generation);
  }

  int _invalidate() {
    ++_generation;
    _manager = null;
    _driver = null;
    _pendingState = null;
    return _generation;
  }

  Future<Never> _storageFailed(int generation) async {
    _current(generation);
    // Fence every acquired client before any fallible public-state write.
    _credentialRepairRequired = true;
    await _persistRepairRequired(_invalidate());
    throw const CredentialStorageFailure();
  }

  Future<void> _requireHealthyStorage(int generation) async {
    _current(generation);
    if (!_credentialRepairRequired) return;
    await _persistRepairRequired(generation);
    throw const CredentialStorageFailure();
  }

  Future<void> _persistRepairRequired(int generation) async {
    try {
      final account = await accounts.get(Destination.bluesky);
      if (_generation == generation &&
          account.state != AccountState.removalPending) {
        await accounts.save(
          account.copyWith(state: AccountState.repairRequired),
        );
      }
    } catch (_) {
      // A compound SQLite failure cannot undo the fence or expose its details.
    }
  }

  @override
  Future<AccountIdentity> connect({String? handle}) => _connecting ??= _connect(
    handle,
    ++_generation,
  ).whenComplete(() => _connecting = null);

  Future<AccountIdentity> _connect(String? handle, int generation) async {
    try {
      if (handle == null || handle.trim().isEmpty) {
        throw const AccountConnectionUnavailable();
      }
      await _serial(() async {
        await _requireHealthyStorage(generation);
        final account = await accounts.get(Destination.bluesky);
        if (account.state == AccountState.repairRequired ||
            account.state == AccountState.removalPending) {
          throw const CredentialStorageFailure();
        }
        // Browser work is explicitly cancelled after process loss. Preserve a prior session.
        final envelope = await _read(generation);
        if (envelope.remove('pending') != null) {
          await _write(generation, envelope);
        }
      });
      _manager = null;
      final driver = _driver = _createDriver(generation);
      final url = await driver.authorize(handle.trim());
      _current(generation);
      final callback = await authorizeInBrowser(url)
          .timeout(const Duration(minutes: 10));
      _current(generation);
      final session = await driver.callback(callback);
      _current(generation);
      final identity = await _serial(() async {
        _current(generation);
        final envelope = await _read(generation);
        // The driver must have awaited its SDK session-store hook.
        if (jsonEncode(envelope['session']) != jsonEncode(session.toJson())) {
          throw const AccountConnectionExpired();
        }
        final identity = AccountIdentity.fromJson(
          envelope['identity'] as Map<String, dynamic>,
        );
        if (identity.destination != Destination.bluesky ||
            identity.subject != session.sub) {
          throw const AccountConnectionExpired();
        }
        await accounts.save(
          AccountView(
            destination: Destination.bluesky,
            state: AccountState.connected,
            identity: identity,
            capability: configuration.connection(Destination.bluesky).reason,
          ),
        );
        _current(generation);
        return identity;
      });
      _manager = await driver.restore(jsonEncode(session.toJson()));
      _current(generation);
      return identity;
    } catch (error) {
      _driver = null;
      _manager = null;
      _throwSafe(error);
    } finally {
      if (generation == _generation && _pendingState != null) {
        await _serial(() async {
          final envelope = await _read(generation);
          envelope.remove('pending');
          await _write(generation, envelope);
          _pendingState = null;
        });
      }
    }
  }

  @override
  Future<void> ensureAuthorized() {
    if (_connecting != null) {
      return Future.error(const AccountConnectionUnavailable());
    }
    return _ensuring ??= _ensure(_generation)
        .whenComplete(() => _ensuring = null);
  }

  Future<void> _ensure(int generation) async {
    try {
      final stored = await _serial(() async {
        await _requireHealthyStorage(generation);
        final account = await accounts.get(Destination.bluesky);
        if (account.state != AccountState.connected ||
            account.identity == null) {
          throw const AccountConnectionExpired();
        }
        final envelope = await _read(generation);
        // There is no cold-process callback resume. Remove stale pending keys durably.
        if (envelope.remove('pending') != null) {
          await _write(generation, envelope);
        }
        final session = _decodeSession(envelope['session']);
        final AccountIdentity identity;
        try {
          identity = AccountIdentity.fromJson(
            envelope['identity'] as Map<String, dynamic>,
          );
        } catch (_) {
          throw const AccountConnectionExpired();
        }
        if (identity.subject != account.identity!.subject ||
            identity.destination != account.identity!.destination ||
            identity.subject != session.sub ||
            identity.destination != Destination.bluesky ||
            identity.handle.isEmpty) {
          throw const AccountConnectionExpired();
        }
        // A handle is mutable display metadata. The validated secure DID owns
        // the connection; also repair a public update interrupted by process loss.
        if (identity != account.identity) {
          await accounts.save(account.copyWith(identity: identity));
          _current(generation);
        }
        return session;
      });
      _current(generation);
      final driver = _driver ??= _createDriver(generation);
      final manager = _manager ??= await driver.restore(
        jsonEncode(stored.toJson()),
      );
      final session = await manager.getSession();
      _current(generation);
      validateBlueskySession(session, configuration);
      if (session.sub != stored.sub ||
          session.issuer != stored.issuer ||
          session.pds != stored.pds) {
        throw const AccountConnectionExpired();
      }
    } on OAuthSessionRevokedException {
      await _expire(generation);
      throw const AccountConnectionExpired();
    } on AccountConnectionExpired {
      await _expire(generation);
      rethrow;
    } catch (error) {
      _throwSafe(error);
    }
  }

  Future<void> _expire(int generation) =>
      _serial(() => _expireCurrent(generation));

  // Already inside the owner's queue. The SDK's session-deletion hook and
  // _ensure share this transition without recursively waiting on that queue.
  Future<void> _expireCurrent(int generation, {String? expectedDid}) async {
    // Revocation may already have expired this generation in the SDK hook.
    // An older operation must never change a newer connection's public state.
    if (generation != _generation) return;
    final invalidated = _invalidate();
    final account = await accounts.get(Destination.bluesky);
    _current(invalidated);
    if (account.state == AccountState.connected &&
        (expectedDid == null || account.identity?.subject == expectedDid)) {
      await accounts.save(account.copyWith(state: AccountState.expired));
    }
  }

  OAuthSession _decodeSession(dynamic value) {
    try {
      final json = value as Map<String, dynamic>;
      if (json['token_type'] != 'DPoP') throw const FormatException();
      final session = OAuthSession.fromJson(json);
      validateBlueskySession(session, configuration);
      return session;
    } catch (_) {
      throw const AccountConnectionExpired();
    }
  }

  /// The provider adapter must supply the DID held by the immutable review.
  Future<Bluesky> authorizedClient({required String expectedDid}) async {
    await ensureAuthorized();
    final generation = _generation;
    final account = await accounts.get(Destination.bluesky);
    _current(generation);
    if (account.identity?.subject != expectedDid ||
        _manager?.currentSub != expectedDid) {
      throw const AccountConnectionExpired();
    }
    return _driver!.client(_manager!, expectedDid);
  }

  @override
  Future<void> disconnect() {
    ++_generation;
    _manager = null;
    _driver = null;
    _pendingState = null;
    return _serial(() async {
      await _publicState(AccountState.removalPending);
      try {
        await vault.delete(Destination.bluesky);
      } catch (_) {
        throw const CredentialStorageFailure();
      }
      await _publicState(AccountState.disconnected);
      _credentialRepairRequired = false;
    });
  }

  @override
  Future<void> repairCredentials() {
    final generation = ++_generation;
    _manager = null;
    _driver = null;
    _pendingState = null;
    return _serial(() async {
      _current(generation);
      final before = await accounts.get(Destination.bluesky);
      await _publicState(
        before.state == AccountState.removalPending
            ? AccountState.removalPending
            : AccountState.repairRequired,
      );
      await vault.repair(Destination.bluesky);
      _current(generation);
      await _publicState(AccountState.disconnected);
      _current(generation);
      _credentialRepairRequired = false;
    });
  }

  Future<void> _publicState(AccountState state) => accounts.save(
    AccountView(
      destination: Destination.bluesky,
      state: state,
      capability: configuration.connection(Destination.bluesky).reason,
    ),
  );

  Never _throwSafe(Object error) {
    if (error is AccountConnectionCancelled ||
        error is AccountConnectionExpired ||
        error is CredentialStorageFailure ||
        error is UnsupportedBlueskyAccount) {
      throw error;
    }
    throw const AccountConnectionUnavailable();
  }
}

class _States implements OAuthStateStore {
  const _States(this.owner, this.generation);
  final BlueskyConnection owner;
  final int generation;
  @override
  Future<void> set(String key, OAuthContext value) => owner._serial(() async {
    owner._current(generation);
    if (key != value.state ||
        value.expectedSub == null ||
        value.issuer != 'https://bsky.social' ||
        !isHostedBlueskyPds(value.pds ?? '')) {
      throw const AccountConnectionUnavailable();
    }
    final json = await owner._read(generation);
    json['pending'] = {
      'key': key,
      'context': value.toJson(),
      'claimed': false,
      'issuedAt': owner.clock.now().toIso8601String(),
    };
    await owner._write(generation, json);
    owner._pendingState = key;
  });
  @override
  Future<OAuthContext?> find(String key) => owner._serial(() async {
    final json = await owner._read(generation);
    final pending = json['pending'] as Map<String, dynamic>?;
    if (owner._pendingState != key ||
        pending == null ||
        pending['key'] != key ||
        pending['claimed'] != false) {
      return null;
    }
    final issued = DateTime.parse(pending['issuedAt'] as String);
    final now = owner.clock.now();
    if (issued.isAfter(now) ||
        now.difference(issued) >= const Duration(minutes: 10)) {
      json.remove('pending');
      await owner._write(generation, json);
      return null;
    }
    final context = OAuthContext.fromJson(
      pending['context'] as Map<String, dynamic>,
    );
    pending['claimed'] = true;
    await owner._write(
      generation,
      json,
    ); // Durable single-use claim BEFORE SDK sees keys.
    return context;
  });
  @override
  Future<void> delete(String key) => owner._serial(() async {
    final json = await owner._read(generation);
    if ((json['pending'] as Map<String, dynamic>?)?['key'] == key) {
      json.remove('pending');
      await owner._write(generation, json);
    }
    if (owner._pendingState == key) owner._pendingState = null;
  });
}

class _Sessions implements OAuthSessionStore {
  const _Sessions(this.owner, this.generation);
  final BlueskyConnection owner;
  final int generation;
  @override
  Future<void> set(String key, OAuthSession value) async {
    owner._current(generation);
    validateBlueskySession(value, owner.configuration);
    if (key != value.sub) throw const AccountConnectionExpired();
    final identity = await owner._driver!.identityFromSession(value);
    await owner._serial(() async {
      final json = await owner._read(generation);
      final pending = json['pending'] as Map<String, dynamic>?;
      final expected = pending == null
          ? ((json['session'] as Map<String, dynamic>?)?['sub'])
          : (pending['context'] as Map<String, dynamic>)['expectedSub'];
      if (expected != value.sub) throw const AccountConnectionExpired();
      json['session'] = value.toJson();
      json['identity'] = identity.toJson();
      await owner._write(generation, json);
      final account = await owner.accounts.get(Destination.bluesky);
      owner._current(generation);
      if (account.state == AccountState.connected &&
          account.identity?.destination == identity.destination &&
          account.identity?.subject == identity.subject &&
          account.identity != identity) {
        // Only publish the freshly validated handle after secure persistence.
        await owner.accounts.save(account.copyWith(identity: identity));
        owner._current(generation);
      }
    });
  }

  @override
  Future<OAuthSession?> find(String key) => owner._serial(() async {
    final json = await owner._read(generation);
    final session = json['session'];
    if (session == null) return null;
    final value = owner._decodeSession(session);
    if (value.sub != key) return null;
    return value;
  });
  @override
  Future<void> delete(String key) => owner._serial(() async {
    final json = await owner._read(generation);
    if ((json['session'] as Map<String, dynamic>?)?['sub'] == key) {
      json.remove('session');
      json.remove('identity');
      await owner._write(generation, json);
      await owner._expireCurrent(generation, expectedDid: key);
    }
  });
}

class _Nonces implements DPoPNonceCache {
  const _Nonces(this.owner, this.generation);
  final BlueskyConnection owner;
  final int generation;
  bool _origin(String value) =>
      value == 'https://bsky.social' || isHostedBlueskyPds(value);
  @override
  Future<String?> find(String origin) => owner._serial(() async {
    if (!_origin(origin)) throw const AccountConnectionUnavailable();
    final json = await owner._read(generation);
    final value =
        (json['nonces'] as Map<String, dynamic>?)?[origin]
            as Map<String, dynamic>?;
    if (value == null) return null;
    final until = DateTime.parse(value['until'] as String);
    return until.isAfter(owner.clock.now()) ? value['nonce'] as String : null;
  });
  @override
  Future<void> set(String origin, String nonce) => owner._serial(() async {
    if (!_origin(origin) || nonce.trim().isEmpty || nonce.length > 4096) {
      throw const AccountConnectionUnavailable();
    }
    final json = await owner._read(generation);
    final nonces = json['nonces'] as Map<String, dynamic>? ?? {};
    final existing = nonces[origin] as Map<String, dynamic>?;
    if (existing?['nonce'] == nonce &&
        DateTime.parse(existing!['until'] as String)
            .isAfter(owner.clock.now())) {
      return;
    }
    nonces[origin] = {
      'nonce': nonce,
      'until': owner.clock
          .now()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    json['nonces'] = nonces;
    await owner._write(generation, json);
  });
}
