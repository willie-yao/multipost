import 'dart:async';
import 'dart:convert';

import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/accounts/bluesky_connection.dart';
import 'package:cross_posting_app/features/accounts/bluesky_oauth.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'account_fixture.dart';
import 'database_fixture.dart';

/// Real pinned OAuth/identity/crypto and app stores; only the network/browser are fake.
class HostedBlueskyHarness {
  HostedBlueskyHarness._(this.fixture) {
    accounts = LocalAccountRepository(
      fixture.database,
      configuration: configuration,
    );
    httpClient = MockClient(_request);
    rebuild();
  }
  final DatabaseFixture fixture;
  final vault = MemoryCredentialVault(primaryDestination: Destination.bluesky);
  final configuration = AppConfiguration(
    xClientId: '',
    xRedirectUri: Uri(),
    blueskyMetadataUri: Uri.parse('https://caption.example.com/client.json'),
    blueskyCallbackScheme: 'com.example.caption',
  );
  late LocalAccountRepository accounts;
  late http.Client httpClient;
  late BlueskyConnection connection;
  late HostedATProtoOAuthDriver driver;
  late BlueskyOAuthStores stores;
  final requests = <http.Request>[];
  final proofs = <Map<String, dynamic>>[];
  final clock = AccountClock();
  String pds = blueskyPds;
  String resolvedDid = blueskyDid;
  String? state;
  int pars = 0, tokens = 0, refreshes = 0, apis = 0;
  bool challengePar = false, challengeApi = false;
  bool alwaysChallengeApi = false;
  bool metadataMissing = false;
  bool omitNonce = false;
  String? omitNoncePath;
  Object? requestError;
  String? errorPath;
  int? responseStatus;
  Completer<void>? tokenStarted, tokenBarrier;
  Completer<String>? browser;
  String Function(String)? changeCallback;
  void Function(Map<String, dynamic>)? changeMetadata,
      changeDiscovery,
      changeToken,
      changeResource;
  http.Response? Function(http.Request)? override;
  void rebuild() {
    accounts = LocalAccountRepository(
      fixture.database,
      configuration: configuration,
    );
    connection = BlueskyConnection(
      configuration: configuration,
      vault: vault,
      accounts: accounts,
      clock: clock,
      driverFactory: (s) {
        stores = s;
        return driver = HostedATProtoOAuthDriver(configuration, s, httpClient);
      },
      authorizeInBrowser: (url) async {
        final value =
            '${configuration.blueskyRedirectUri}?state=$state&iss=https%3A%2F%2Fbsky.social&code=synthetic-code';
        return browser?.future ?? changeCallback?.call(value) ?? value;
      },
    );
  }

  http.Response json(
    Object value, {
    int status = 200,
    bool signed = false,
    String? path,
  }) => http.Response(
    jsonEncode(value),
    status,
    headers: {
      'content-type': 'application/json',
      if (signed && !omitNonce && omitNoncePath != path)
        'DPoP-Nonce': 'synthetic-$path-nonce',
    },
  );
  Future<http.Response> _request(http.Request request) async {
    requests.add(request);
    if (request.followRedirects) {
      throw StateError('Redirect following was enabled');
    }
    if (errorPath == request.url.path && requestError != null) {
      throw requestError!;
    }
    if (override?.call(request) case final value?) return value;
    final path = request.url.path;
    if (path == '/client.json') {
      final value = <String, dynamic>{
        'client_id': 'https://caption.example.com/client.json',
        'application_type': 'native',
        'client_name': 'Caption test',
        'client_uri': 'https://caption.example.com',
        'dpop_bound_access_tokens': true,
        'grant_types': ['authorization_code', 'refresh_token'],
        'redirect_uris': ['com.example.caption:/callback'],
        'response_types': ['code'],
        'scope': blueskyWriteScope,
        'token_endpoint_auth_method': 'none',
      };
      changeMetadata?.call(value);
      return json(value);
    }
    if (path == '/xrpc/com.atproto.identity.resolveHandle') {
      return json({'did': resolvedDid});
    }
    if (request.url.host == 'plc.directory') {
      return json({
        'id': resolvedDid,
        'alsoKnownAs': ['at://person.test'],
        'service': [
          {
            'id': '#atproto_pds',
            'type': 'AtprotoPersonalDataServer',
            'serviceEndpoint': pds,
          },
        ],
      });
    }
    if (path == '/.well-known/oauth-protected-resource') {
      final value = <String, dynamic>{
        'resource': pds,
        'authorization_servers': ['https://bsky.social'],
      };
      changeResource?.call(value);
      return json(value);
    }
    if (path == '/.well-known/oauth-authorization-server') {
      if (metadataMissing) return json({'error': 'missing'}, status: 404);
      final value = <String, dynamic>{
        'issuer': 'https://bsky.social',
        'authorization_endpoint': 'https://bsky.social/oauth/authorize',
        'token_endpoint': 'https://bsky.social/oauth/token',
        'pushed_authorization_request_endpoint':
            'https://bsky.social/oauth/par',
        'require_pushed_authorization_requests': true,
        'response_types_supported': ['code'],
        'grant_types_supported': ['authorization_code', 'refresh_token'],
        'code_challenge_methods_supported': ['S256'],
        'dpop_signing_alg_values_supported': ['ES256'],
        'authorization_response_iss_parameter_supported': true,
        'token_endpoint_auth_methods_supported': ['none'],
      };
      changeDiscovery?.call(value);
      return json(value);
    }
    final proof = request.headers['dpop'];
    if (proof == null) throw StateError('Unsigned provider request');
    proofs.add(
      jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(proof.split('.')[1]))),
      ) as Map<String, dynamic>,
    );
    if (path == '/oauth/par') {
      pars++;
      state = request.bodyFields['state'];
      if (challengePar && pars == 1) {
        return json(
          {'error': 'use_dpop_nonce'},
          status: 400,
          signed: true,
          path: path,
        );
      }
      return json(
        {
          'request_uri': 'urn:ietf:params:oauth:request_uri:fixture',
          'expires_in': 60,
        },
        status: 201,
        signed: true,
        path: path,
      );
    }
    if (path == '/oauth/token') {
      tokens++;
      if (request.bodyFields['grant_type'] == 'refresh_token') refreshes++;
      if (!(tokenStarted?.isCompleted ?? true)) tokenStarted!.complete();
      await tokenBarrier?.future;
      final value = <String, dynamic>{
        'access_token': 'synthetic-access-$refreshes',
        'refresh_token': 'synthetic-refresh-$refreshes',
        'token_type': 'DPoP',
        'scope': blueskyWriteScope,
        'sub': blueskyDid,
        'expires_in': 3600,
      };
      changeToken?.call(value);
      return json(
        value,
        signed: true,
        path: path,
        status: responseStatus ?? 200,
      );
    }
    if (path.startsWith('/xrpc/')) {
      apis++;
      if ((challengeApi && apis == 1) || alwaysChallengeApi) {
        return json(
          {'error': 'use_dpop_nonce'},
          status: 401,
          signed: true,
          path: path,
        );
      }
      if (responseStatus != null) {
        return json(
          {'error': 'synthetic'},
          status: responseStatus!,
          signed: true,
          path: path,
        );
      }
      return json(
        {
          'did': blueskyDid,
          'handle': 'person.test',
          'uri': 'at://$blueskyDid/app.bsky.feed.post/synthetic',
          'cid': 'synthetic',
        },
        signed: true,
        path: path,
      );
    }
    throw StateError('Unexpected admitted request');
  }

  Future<void> connect() async {
    await connection.connect(handle: 'person.test');
  }

  Future<void> expireStoredSession() async {
    final json = jsonDecode(vault.value!) as Map<String, dynamic>;
    (json['session'] as Map<String, dynamic>)['expires_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 1))
        .toIso8601String();
    vault.value = jsonEncode(json);
    rebuild();
  }

  Future<void> close() async {
    httpClient.close();
    await fixture.dispose();
  }

  static Future<HostedBlueskyHarness> create() async =>
      HostedBlueskyHarness._(await DatabaseFixture.create());
}
