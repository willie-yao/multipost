import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

import '../../app/app_configuration.dart';
import '../../core/clock.dart';
import '../drafts/draft.dart';
import 'account.dart';
import 'account_repository.dart';
import 'credential_vault.dart';

class XTokenSet {
  const XTokenSet({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

abstract interface class XOAuthDriver {
  Future<XTokenSet> authorize();
  Future<XTokenSet> refresh(String refreshToken);
}

/// Native AppAuth owns the random state, S256 verifier and code exchange.
/// The Android receiver admits one exact-target callback within ten minutes.
class AppAuthXDriver implements XOAuthDriver {
  const AppAuthXDriver(
    this.configuration, {
    this.appAuth = const FlutterAppAuth(),
  });
  final AppConfiguration configuration;
  final FlutterAppAuth appAuth;
  static const _channel = MethodChannel('crossposting/accounts');
  static const _service = AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://x.com/i/oauth2/authorize',
    tokenEndpoint: 'https://api.x.com/2/oauth2/token',
  );
  static const _scopes = [
    'tweet.read',
    'tweet.write',
    'users.read',
    'offline.access',
    'media.write',
  ];

  void _requireAvailable() {
    if (!configuration.connection(Destination.x).available) {
      throw const AccountConnectionUnavailable();
    }
  }

  @override
  Future<XTokenSet> authorize() async {
    _requireAvailable();
    var prepared = false;
    try {
      prepared =
          await _channel.invokeMethod<bool>(
            'prepareXAuthorization',
            configuration.xRedirectUri.toString(),
          ) ==
          true;
      if (!prepared) throw const AccountConnectionUnavailable();
      final response = await appAuth
          .authorizeAndExchangeCode(
            AuthorizationTokenRequest(
              configuration.xClientId,
              configuration.xRedirectUri.toString(),
              serviceConfiguration: _service,
              scopes: _scopes,
            ),
          )
          .timeout(const Duration(minutes: 10));
      return _tokens(response);
    } on FlutterAppAuthUserCancelledException {
      throw const AccountConnectionCancelled();
    } catch (_) {
      throw const AccountConnectionUnavailable();
    } finally {
      if (prepared) {
        try {
          await _channel.invokeMethod<void>('finishXAuthorization');
        } catch (_) {
          /* No credentials are persisted by this driver. */
        }
      }
    }
  }

  @override
  Future<XTokenSet> refresh(String refreshToken) async {
    _requireAvailable();
    try {
      final response = await appAuth
          .token(
            TokenRequest(
              configuration.xClientId,
              configuration.xRedirectUri.toString(),
              serviceConfiguration: _service,
              refreshToken: refreshToken,
            ),
          )
          .timeout(const Duration(seconds: 30));
      return _tokens(response);
    } on FlutterAppAuthPlatformException catch (error) {
      if (error.platformErrorDetails.error ==
          FlutterAppAuthOAuthError.invalidGrant) {
        throw const AccountConnectionExpired();
      }
      throw const AccountConnectionUnavailable();
    } catch (_) {
      throw const AccountConnectionUnavailable();
    }
  }

  XTokenSet _tokens(TokenResponse response) {
    final access = response.accessToken;
    final refresh = response.refreshToken;
    final expiry = response.accessTokenExpirationDateTime;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty ||
        expiry == null) {
      throw const AccountConnectionExpired();
    }
    return XTokenSet(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiry.toUtc(),
    );
  }
}

/// One instance owns X account operations. Network work may overlap disconnect;
/// the generation fence plus serial durable mutations reject its late results.
class XConnection implements AccountConnection {
  XConnection({
    required this.configuration,
    required this.driver,
    required this.vault,
    required this.accounts,
    required this.client,
    this.clock = const Clock(),
  });
  final AppConfiguration configuration;
  final XOAuthDriver driver;
  final CredentialVault vault;
  final AccountRepository accounts;
  final http.Client client;
  final Clock clock;
  int _generation = 0;
  Future<void> _mutations = Future.value();
  Future<AccountIdentity>? _connecting;
  Future<void>? _refreshing;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _mutations.then((_) => action());
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _current(int generation) {
    if (generation != _generation) throw const AccountConnectionCancelled();
  }

  @override
  Future<AccountIdentity> connect({String? handle}) =>
      _connecting ??= _connect(++_generation)
          .whenComplete(() => _connecting = null);

  Future<AccountIdentity> _connect(int generation) async {
    try {
      await _serial(() async {
        _current(generation);
        final state = (await accounts.get(Destination.x)).state;
        if (state == AccountState.removalPending ||
            state == AccountState.repairRequired) {
          throw const CredentialStorageFailure();
        }
      });
      _current(generation);
      final tokens = await driver.authorize();
      _current(generation);
      _validateTokens(tokens);
      final identity = await _identity(tokens.accessToken);
      _current(generation);
      return await _serial(() async {
        _current(generation);
        try {
          await vault.write(
            Destination.x,
            jsonEncode({
              'version': 1,
              'clientId': configuration.xClientId,
              'redirectUri': configuration.xRedirectUri.toString(),
              'identity': identity.toJson(),
              'accessToken': tokens.accessToken,
              'refreshToken': tokens.refreshToken,
              'expiresAt': tokens.expiresAt.toIso8601String(),
            }),
          );
        } catch (_) {
          await accounts.setState(Destination.x, AccountState.repairRequired);
          throw const CredentialStorageFailure();
        }
        _current(generation);
        await accounts.save(
          AccountView(
            destination: Destination.x,
            state: AccountState.connected,
            identity: identity,
            capability: configuration.connection(Destination.x).reason,
          ),
        );
        _current(generation);
        return identity;
      });
    } on AccountConnectionCancelled {
      rethrow;
    } on CredentialStorageFailure {
      rethrow;
    } on AccountConnectionExpired {
      rethrow;
    } catch (_) {
      throw const AccountConnectionUnavailable();
    }
  }

  Future<AccountIdentity> _identity(String token) async {
    final request =
        http.Request('GET', Uri.parse('https://api.x.com/2/users/me'))
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $token';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) throw const AccountConnectionExpired();
    if (response.statusCode != 200) throw const AccountConnectionUnavailable();
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 65536) throw const AccountConnectionUnavailable();
    }
    final data =
        (jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final subject = data['id'];
    final handle = data['username'];
    if (subject is! String ||
        !RegExp(r'^[0-9]+$').hasMatch(subject) ||
        handle is! String ||
        !RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(handle)) {
      throw const AccountConnectionUnavailable();
    }
    return AccountIdentity(
      destination: Destination.x,
      subject: subject,
      handle: '@$handle',
    );
  }

  @override
  Future<void> ensureAuthorized() {
    if (_connecting != null) {
      return Future.error(const AccountConnectionUnavailable());
    }
    return _refreshing ??= _ensure(_generation)
        .whenComplete(() => _refreshing = null);
  }

  Future<void> _ensure(int generation) async {
    try {
      final session = await _serial(() async {
        _current(generation);
        final account = await accounts.get(Destination.x);
        if (account.state != AccountState.connected) {
          throw const AccountConnectionExpired();
        }
        String? stored;
        try {
          stored = await vault.read(Destination.x);
        } catch (_) {
          await accounts.setState(Destination.x, AccountState.repairRequired);
          throw const CredentialStorageFailure();
        }
        try {
          final data = jsonDecode(stored!) as Map<String, dynamic>;
          final identity = AccountIdentity.fromJson(
            data['identity'] as Map<String, dynamic>,
          );
          if (data['version'] != 1 ||
              data['clientId'] != configuration.xClientId ||
              data['redirectUri'] != configuration.xRedirectUri.toString() ||
              identity != account.identity) {
            throw const FormatException();
          }
          _validateTokens(_decodeTokens(data), allowExpired: true);
          return data;
        } catch (_) {
          await accounts.setState(Destination.x, AccountState.expired);
          throw const AccountConnectionExpired();
        }
      });
      _current(generation);
      final tokens = _decodeTokens(session);
      if (tokens.expiresAt.isAfter(
        clock.now().add(const Duration(seconds: 30)),
      )) {
        return;
      }
      XTokenSet rotated;
      try {
        rotated = await driver.refresh(tokens.refreshToken);
        _validateTokens(rotated);
      } on AccountConnectionExpired {
        await _expire(generation);
        rethrow;
      } catch (_) {
        _current(generation);
        throw const AccountConnectionUnavailable();
      }
      await _serial(() async {
        _current(generation);
        try {
          await vault.write(
            Destination.x,
            jsonEncode({
              ...session,
              'accessToken': rotated.accessToken,
              'refreshToken': rotated.refreshToken,
              'expiresAt': rotated.expiresAt.toIso8601String(),
            }),
          );
        } catch (_) {
          await accounts.setState(Destination.x, AccountState.repairRequired);
          throw const CredentialStorageFailure();
        }
        _current(generation);
      });
    } on AccountConnectionCancelled {
      rethrow;
    } on AccountConnectionExpired {
      rethrow;
    } on CredentialStorageFailure {
      rethrow;
    } catch (_) {
      throw const AccountConnectionUnavailable();
    }
  }

  /// Captured before preparation and checked synchronously immediately before
  /// dispatch. Reconnect/disconnect invalidate even the same subject's session.
  int get authorizationGeneration => _generation;
  void requireAuthorizationGeneration(int generation) => _current(generation);

  /// Tokens and public metadata are read in the same serialized operation.
  /// A mismatched reviewed subject never returns the new account's credential.
  Future<String> accessToken({required String expectedSubject}) async {
    final generation = _generation;
    await ensureAuthorized();
    _current(generation);
    return _serial(() async {
      _current(generation);
      final account = await accounts.get(Destination.x);
      final stored = await vault.read(Destination.x);
      _current(generation);
      if (account.state != AccountState.connected ||
          account.identity?.subject != expectedSubject ||
          stored == null) {
        throw const AccountConnectionExpired();
      }
      try {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        final identity = AccountIdentity.fromJson(
          data['identity'] as Map<String, dynamic>,
        );
        final tokens = _decodeTokens(data);
        if (data['version'] != 1 ||
            data['clientId'] != configuration.xClientId ||
            data['redirectUri'] != configuration.xRedirectUri.toString() ||
            identity != account.identity ||
            identity.subject != expectedSubject) {
          throw const FormatException();
        }
        _validateTokens(tokens);
        return tokens.accessToken;
      } catch (_) {
        throw const AccountConnectionExpired();
      }
    });
  }

  XTokenSet _decodeTokens(Map<String, dynamic> data) => XTokenSet(
    accessToken: data['accessToken'] as String,
    refreshToken: data['refreshToken'] as String,
    expiresAt: DateTime.parse(data['expiresAt'] as String),
  );
  void _validateTokens(XTokenSet tokens, {bool allowExpired = false}) {
    if (tokens.accessToken.isEmpty ||
        tokens.refreshToken.isEmpty ||
        (!allowExpired && !tokens.expiresAt.isAfter(clock.now()))) {
      throw const AccountConnectionExpired();
    }
  }

  Future<void> _expire(int generation) => _serial(() async {
    _current(generation);
    await accounts.setState(Destination.x, AccountState.expired);
  });

  @override
  Future<void> repairCredentials() {
    final generation = ++_generation;
    return _serial(() async {
      _current(generation);
      final before = await accounts.get(Destination.x);
      await accounts.save(
        AccountView(
          destination: Destination.x,
          state: before.state == AccountState.removalPending
              ? AccountState.removalPending
              : AccountState.repairRequired,
          capability: configuration.connection(Destination.x).reason,
        ),
      );
      await vault.repair(Destination.x);
      _current(generation);
      await accounts.save(
        AccountView(
          destination: Destination.x,
          state: AccountState.disconnected,
          capability: configuration.connection(Destination.x).reason,
        ),
      );
    });
  }

  @override
  Future<void> disconnect() {
    ++_generation;
    return _serial(() async {
      // Persist the removal intent before touching secrets. It remains discoverable
      // after failure/process death; authorization is blocked until completion.
      await accounts.save(
        AccountView(
          destination: Destination.x,
          state: AccountState.removalPending,
          capability: configuration.connection(Destination.x).reason,
        ),
      );
      try {
        await vault.delete(Destination.x);
      } catch (_) {
        throw const CredentialStorageFailure();
      }
      await accounts.save(
        AccountView(
          destination: Destination.x,
          state: AccountState.disconnected,
          capability: configuration.connection(Destination.x).reason,
        ),
      );
    });
  }
}
