import 'dart:convert';

import 'package:atproto_core/atproto_core.dart' as core;
import 'package:atproto_oauth/atproto_oauth.dart';
import 'package:bluesky/bluesky.dart';
import 'package:bluesky/app_bsky_video_defs.dart';
import 'package:http/http.dart' as http;

import '../../app/app_configuration.dart';
import '../drafts/draft.dart';
import 'account.dart';

const blueskyWriteScope =
    'atproto repo:app.bsky.feed.post?action=create blob:image/* blob:video/* '
    'account:email?action=read rpc:app.bsky.video.getUploadLimits?aud=* '
    'rpc:com.atproto.repo.uploadBlob?aud=*';
const _issuer = 'https://bsky.social';

/// The MVP supports the provider's documented PDS deployment, not federation.
bool isHostedBlueskyPds(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      !uri.hasPort &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.isEmpty &&
      RegExp(
        r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.host\.bsky\.network$',
      ).hasMatch(uri.host);
}

class UnsupportedBlueskyAccount implements Exception {
  const UnsupportedBlueskyAccount();
  @override
  String toString() =>
      'This build supports Bluesky-hosted accounts using did:plc. Custom PDS and did:web accounts are not supported. Your existing connection and drafts are safe.';
}

class BlueskyOAuthStores {
  const BlueskyOAuthStores({
    required this.states,
    required this.sessions,
    required this.nonces,
    required this.checkCurrent,
  });
  final OAuthStateStore states;
  final OAuthSessionStore sessions;
  final DPoPNonceCache nonces;
  final void Function() checkCurrent;
}

abstract interface class ATProtoOAuthDriver {
  Future<Uri> authorize(String handle);
  Future<OAuthSession> callback(String url);
  Future<OAuthSessionManager> restore(String serializedSession);
  Future<AccountIdentity> identityFromSession(OAuthSession session);
  Bluesky client(OAuthSessionManager manager, String expectedDid);
  Future<JobStatus> videoJobStatus({
    required String expectedDid,
    required String jobId,
  });
}

/// Uses only the pinned SDK's public store, resolver, signer and HTTP hooks.
/// Its transport admits provider-owned HTTPS origins with ordinary verified TLS.
/// AppServices separately prevents production entry until acceptance is complete.
class HostedATProtoOAuthDriver implements ATProtoOAuthDriver {
  HostedATProtoOAuthDriver(
    this.configuration,
    this.stores,
    http.Client httpClient,
  ) {
    _http = _HostedHttp(configuration, stores, httpClient);
    _sdkNonces = _CommittedNonceCache(stores);
    _resolver = HttpIdentityResolver(httpClient: _http, allowedHosts: const {});
  }
  final AppConfiguration configuration;
  final BlueskyOAuthStores stores;
  late final _HostedHttp _http;
  late final DPoPNonceCache _sdkNonces;
  late final HttpIdentityResolver _resolver;
  OAuthClient? _oauth;

  Future<OAuthClient> _client() async {
    stores.checkCurrent();
    if (_oauth case final existing?) return existing;
    if (!configuration.connection(Destination.bluesky).configured) {
      throw const AccountConnectionUnavailable();
    }
    final metadata = await getClientMetadata(
      configuration.blueskyMetadataUri.toString(),
      client: _http,
    );
    stores.checkCurrent();
    return _oauth ??= OAuthClient(
      metadata,
      httpClient: _http,
      identityResolver: _HostedResolver(this),
      stateStore: stores.states,
      sessionStore: stores.sessions,
      nonceCache: _sdkNonces,
    );
  }

  @override
  Future<Uri> authorize(String handle) async {
    if (handle.trim().isEmpty) throw const AccountConnectionUnavailable();
    if (handle.trim().startsWith('did:') &&
        !handle.trim().startsWith('did:plc:')) {
      throw const UnsupportedBlueskyAccount();
    }
    final url = await (await _client()).authorize(handle);
    stores.checkCurrent();
    if (!_http.authorizationTarget(url)) {
      throw const AccountConnectionUnavailable();
    }
    return url;
  }

  @override
  Future<OAuthSession> callback(String url) async {
    final uri = Uri.tryParse(url);
    final expected = configuration.blueskyRedirectUri;
    if (uri == null ||
        uri.scheme != expected.scheme ||
        uri.authority != expected.authority ||
        uri.path != expected.path ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const AccountConnectionUnavailable();
    }
    final q = uri.queryParametersAll;
    for (final name in ['state', 'iss', 'code', 'error']) {
      if (q.containsKey(name) &&
          (q[name]!.length != 1 || q[name]!.single.isEmpty)) {
        throw const AccountConnectionUnavailable();
      }
    }
    if (q['state'] == null ||
        q['iss']?.single != _issuer ||
        (q.containsKey('code') == q.containsKey('error'))) {
      throw const AccountConnectionUnavailable();
    }
    return (await _client()).callback(url);
  }

  @override
  Future<AccountIdentity> identityFromSession(OAuthSession session) async {
    validateBlueskySession(session, configuration);
    final identity = await _resolve(session.sub);
    if (identity.did != session.sub || identity.pds != session.pds) {
      throw const AccountConnectionExpired();
    }
    return AccountIdentity(
      destination: Destination.bluesky,
      subject: identity.did,
      handle: '@${identity.handle}',
    );
  }

  Future<ResolvedIdentity> _resolve(String identity) async {
    final resolved = await _resolver.resolve(identity);
    stores.checkCurrent();
    if (!resolved.did.startsWith('did:plc:') ||
        !isHostedBlueskyPds(resolved.pds)) {
      throw const UnsupportedBlueskyAccount();
    }
    if (resolved.handle == 'handle.invalid' || resolved.handle.isEmpty) {
      throw const AccountConnectionUnavailable();
    }
    _http.bind(resolved.did, resolved.pds);
    return resolved;
  }

  @override
  Future<OAuthSessionManager> restore(String serializedSession) async {
    final session = OAuthSession.fromJson(
      jsonDecode(serializedSession) as Map<String, dynamic>,
    );
    validateBlueskySession(session, configuration);
    _http.bind(session.sub, session.pds);
    return OAuthSessionManager.fromSession(
      session,
      client: await _client(),
      nonceCache: _sdkNonces,
    );
  }

  @override
  Bluesky client(OAuthSessionManager manager, String expectedDid) {
    stores.checkCurrent();
    if (manager.currentSub != expectedDid || _http.did != expectedDid) {
      throw const AccountConnectionExpired();
    }
    Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
      _checkManager(manager, expectedDid);
      return _http.get(url, headers: headers);
    }

    Future<http.Response> post(
      Uri url, {
      Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
    }) async {
      _checkManager(manager, expectedDid);
      return _http.post(url, headers: headers, body: body, encoding: encoding);
    }

    return Bluesky.fromOAuth(
      manager,
      getClient: get,
      postClient: post,
      retryConfig: core.RetryConfig(maxAttempts: 0),
    );
  }

  @override
  Future<JobStatus> videoJobStatus({
    required String expectedDid,
    required String jobId,
  }) async {
    stores.checkCurrent();
    if (_http.did != expectedDid || jobId.isEmpty || jobId.length > 1024) {
      throw const AccountConnectionExpired();
    }
    final client = Bluesky.anonymous(
      // No OAuth manager or credentials exist on this fixed read-only client.
      // The same transport still fences its generation and admits only the
      // exact public video status GET outside the bound PDS.
      getClient: _http.get,
      retryConfig: core.RetryConfig(maxAttempts: 0),
    );
    final result = await client.video.getJobStatus(jobId: jobId);
    stores.checkCurrent();
    if (result.data.jobStatus.did != expectedDid ||
        result.data.jobStatus.jobId != jobId) {
      throw const AccountConnectionUnavailable();
    }
    return result.data.jobStatus;
  }

  void _checkManager(OAuthSessionManager manager, String expectedDid) {
    stores.checkCurrent();
    if (manager.currentSub != expectedDid || _http.did != expectedDid) {
      throw const AccountConnectionExpired();
    }
  }
}

/// Every signed response is persisted by _HostedHttp before reaching the SDK.
/// The SDK also emits a fire-and-forget success notification. It must not start
/// a second secure mutation after an authenticated call has already completed.
class _CommittedNonceCache implements DPoPNonceCache {
  const _CommittedNonceCache(this.stores);
  final BlueskyOAuthStores stores;
  @override
  Future<String?> find(String origin) => stores.nonces.find(origin);
  @override
  Future<void> set(String origin, String nonce) async {
    stores.checkCurrent();
  }
}

class _HostedResolver implements IdentityResolver {
  const _HostedResolver(this.driver);
  final HostedATProtoOAuthDriver driver;
  @override
  Future<ResolvedIdentity> resolve(String identity) =>
      driver._resolve(identity);
}

void validateBlueskySession(
  OAuthSession session,
  AppConfiguration configuration,
) {
  if (!session.sub.startsWith('did:plc:') || !isHostedBlueskyPds(session.pds)) {
    throw const UnsupportedBlueskyAccount();
  }
  if (session.issuer != _issuer ||
      session.clientId != configuration.blueskyMetadataUri.toString() ||
      session.tokenType != 'DPoP' ||
      session.accessToken.isEmpty ||
      (session.refreshToken?.isEmpty ?? true) ||
      session.expiresAt == null ||
      session.dpopPrivateKey.isEmpty ||
      session.dpopPublicKey.isEmpty ||
      !_hasScopes(session.scope)) {
    throw const AccountConnectionExpired();
  }
}

bool _hasScopes(String scope) {
  final actual = scope.split(' ').where((s) => s.isNotEmpty).toSet();
  final required = blueskyWriteScope.split(' ').toSet();
  return actual.length == required.length && actual.containsAll(required);
}

/// Feature-owned admission policy. No caller-supplied trusted URI bypass exists.
class _HostedHttp extends http.BaseClient {
  _HostedHttp(this.configuration, this.stores, this.inner);
  final AppConfiguration configuration;
  final BlueskyOAuthStores stores;
  final http.Client inner;
  String? did, pds;
  Uri? _par, _token, _authorization;

  void bind(String sub, String origin) {
    if (!sub.startsWith('did:plc:') || !isHostedBlueskyPds(origin)) {
      throw const UnsupportedBlueskyAccount();
    }
    if (did != null && (did != sub || pds != origin)) {
      throw const AccountConnectionExpired();
    }
    did = sub;
    pds = origin;
  }

  // Ephemeral service JWTs are never written to the public DB or uploadState.
  final _videoTokens = <String, String>{};
  void _admitVideoDelegation(http.BaseRequest request) {
    final q = request.url.queryParametersAll;
    if (request.method != 'GET' ||
        q.values.any((v) => v.length != 1) ||
        q.keys.any((k) => !{'aud', 'lxm', 'exp'}.contains(k))) {
      _reject();
    }
    final lxm = request.url.queryParameters['lxm'];
    final expectedAudience = switch (lxm) {
      'app.bsky.video.getUploadLimits' => 'did:web:video.bsky.app',
      'com.atproto.repo.uploadBlob' => 'did:web:${Uri.parse(pds!).host}',
      _ => null,
    };
    if (expectedAudience == null ||
        request.url.queryParameters['aud'] != expectedAudience) {
      _reject();
    }
    if (request.url.queryParameters['exp'] case final encoded?) {
      final exp = int.tryParse(encoded);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (exp == null || exp <= now || exp > now + 1800) _reject();
    }
  }

  void _admitVideo(
    http.BaseRequest request, {
    required bool signed,
    required bool auth,
  }) {
    if (signed) _reject();
    final uri = request.url;
    final authorization = request.headers['authorization'];
    final q = uri.queryParametersAll;
    if (q.values.any((v) => v.length != 1)) _reject();
    if (uri.path == '/xrpc/app.bsky.video.getJobStatus') {
      if (request.method != 'GET' ||
          auth ||
          q.length != 1 ||
          !(uri.queryParameters['jobId']?.isNotEmpty ?? false)) {
        _reject();
      }
    } else if (uri.path == '/xrpc/app.bsky.video.getUploadLimits') {
      final token = _videoTokens['app.bsky.video.getUploadLimits'];
      if (request.method != 'GET' ||
          uri.hasQuery ||
          token == null ||
          authorization != 'Bearer $token') {
        _reject();
      }
    } else if (uri.path == '/xrpc/app.bsky.video.uploadVideo') {
      final token = _videoTokens['com.atproto.repo.uploadBlob'];
      if (request.method != 'POST' ||
          token == null ||
          authorization != 'Bearer $token' ||
          request.headers['content-type'] != 'video/mp4' ||
          q.length != 2 ||
          uri.queryParameters['did'] != did ||
          !(uri.queryParameters['name']?.endsWith('.mp4') ?? false)) {
        _reject();
      }
    } else {
      _reject();
    }
  }

  bool authorizationTarget(Uri uri) =>
      _authorization != null &&
      uri.origin == _authorization!.origin &&
      uri.path == _authorization!.path &&
      !uri.hasFragment &&
      uri.queryParametersAll.length == 2 &&
      uri.queryParametersAll['client_id']?.single ==
          configuration.blueskyMetadataUri.toString() &&
      (uri.queryParametersAll['request_uri']?.single.isNotEmpty ?? false);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    stores.checkCurrent();
    final uri = request.url;
    if (uri.scheme != 'https' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      _reject();
    }
    final signed = request.headers.keys.any((h) => h.toLowerCase() == 'dpop');
    final auth = request.headers.keys.any(
      (h) => h.toLowerCase() == 'authorization',
    );
    final metadata =
        uri.toString() == configuration.blueskyMetadataUri.toString();
    final resolver =
        uri.origin == 'https://public.api.bsky.app' &&
        uri.path == '/xrpc/com.atproto.identity.resolveHandle';
    final plc =
        uri.origin == 'https://plc.directory' &&
        RegExp(r'^/did:plc:[a-z2-7]{24}$').hasMatch(uri.path) &&
        !uri.hasQuery;
    final resource =
        pds != null &&
        uri.toString() == '$pds/.well-known/oauth-protected-resource';
    final discovery =
        uri.toString() == '$_issuer/.well-known/oauth-authorization-server';
    final par = _par != null && uri == _par;
    final token = _token != null && uri == _token;
    final serviceAuth =
        pds != null &&
        uri.origin == pds &&
        uri.path == '/xrpc/com.atproto.server.getServiceAuth';
    if (serviceAuth) _admitVideoDelegation(request);
    final video = uri.origin == 'https://video.bsky.app';
    final api =
        pds != null && uri.origin == pds && uri.path.startsWith('/xrpc/');
    if (metadata || resolver || plc || resource || discovery) {
      if (request.method != 'GET' || signed || auth) _reject();
    } else if (par || token) {
      if (request.method != 'POST' ||
          !signed ||
          auth ||
          request is! http.Request ||
          request.bodyFields['client_id'] !=
              configuration.blueskyMetadataUri.toString()) {
        _reject();
      }
    } else if (video) {
      _admitVideo(request, signed: signed, auth: auth);
    } else if (api) {
      if (!{'GET', 'POST'}.contains(request.method) || !signed || !auth) {
        _reject();
      }
    } else {
      // Includes guessed PAR/token endpoints after swallowed discovery failures.
      _reject();
    }
    if (discovery) {
      _par = null;
      _token = null;
      _authorization = null;
    }
    request.followRedirects = false;
    final response = await inner
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 300 && response.statusCode < 400) _reject();
    final bytes = <int>[];
    await response.stream
        .forEach((chunk) {
          bytes.addAll(chunk);
          if (bytes.length > 512 * 1024) _reject();
        })
        .timeout(const Duration(seconds: 20));
    stores.checkCurrent();
    final result = http.Response.bytes(
      bytes,
      response.statusCode,
      headers: response.headers,
    );
    if (signed) {
      final nonce = response.headers.entries
          .where((e) => e.key.toLowerCase() == 'dpop-nonce')
          .map((e) => e.value)
          .firstOrNull;
      if (nonce == null || nonce.trim().isEmpty || nonce.length > 4096) {
        _reject();
      }
      // Also awaits nonce persistence on API successes (SDK otherwise does not).
      await stores.nonces.set(uri.origin, nonce);
    }
    if (serviceAuth && response.statusCode == 200) {
      final value = jsonDecode(result.body) as Map<String, dynamic>;
      final token = value['token'];
      if (token is! String || token.isEmpty) _reject();
      _videoTokens[uri.queryParameters['lxm']!] = token;
    }
    if (metadata ||
        resolver ||
        resource ||
        discovery ||
        (token && response.statusCode == 200)) {
      if (response.statusCode != 200 ||
          result.headers['content-type']
                  ?.split(';')
                  .first
                  .trim()
                  .toLowerCase() !=
              'application/json') {
        _reject();
      }
      final json = jsonDecode(result.body) as Map<String, dynamic>;
      if (metadata) _metadata(json);
      if (resolver &&
          (json['did'] is! String ||
              !(json['did'] as String).startsWith('did:plc:'))) {
        throw const UnsupportedBlueskyAccount();
      }
      if (resource &&
          (json['resource'] != pds ||
              jsonEncode(json['authorization_servers']) !=
                  jsonEncode([_issuer]))) {
        _reject();
      }
      if (discovery) _discovery(json);
      if (token) _rawToken(json);
    }
    var forwardedBytes = bytes;
    if (video &&
        uri.path == '/xrpc/app.bsky.video.uploadVideo' &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      final body = jsonDecode(result.body) as Map<String, dynamic>;
      // Current lexicon wraps jobStatus; the pinned SDK and official guide
      // decode a bare JobStatus. Normalize only this proven success envelope.
      final Map<String, dynamic> value;
      if (body.containsKey('jobStatus')) {
        if (body.length != 1 || body['jobStatus'] is! Map<String, dynamic>) {
          _reject();
        }
        value = body['jobStatus'] as Map<String, dynamic>;
      } else {
        value = body;
      }
      final job = JobStatus.fromJson(value);
      if (job.did != did || job.jobId.isEmpty || job.jobId.length > 1024) {
        _reject();
      }
      if (job.blob case final blob?) {
        core.CID.parse(blob.ref.link);
        if (blob.mimeType != 'video/mp4' ||
            blob.size <= 0 ||
            blob.size > 300000000) {
          _reject();
        }
      }
      forwardedBytes = utf8.encode(jsonEncode(value));
    }
    return http.StreamedResponse(
      Stream.value(forwardedBytes),
      response.statusCode,
      request: request,
      headers: {
        'content-length': forwardedBytes.length.toString(),
        for (final entry in response.headers.entries)
          if (entry.key.toLowerCase() != 'content-length')
            entry.key.toLowerCase(): entry.value,
      },
    );
  }

  void _metadata(Map<String, dynamic> json) {
    if (json['client_id'] != configuration.blueskyMetadataUri.toString() ||
        json['application_type'] != 'native' ||
        json['token_endpoint_auth_method'] != 'none' ||
        json['dpop_bound_access_tokens'] != true ||
        jsonEncode(json['redirect_uris']) !=
            jsonEncode([configuration.blueskyRedirectUri.toString()]) ||
        !(json['grant_types'] is List &&
            (json['grant_types'] as List).toSet().containsAll([
              'authorization_code',
              'refresh_token',
            ])) ||
        jsonEncode(json['response_types']) != '["code"]' ||
        json['scope'] is! String ||
        !_hasScopes(json['scope'] as String)) {
      _reject();
    }
  }

  void _discovery(Map<String, dynamic> json) {
    bool supports(String field, String value) =>
        json[field] is List && (json[field] as List).contains(value);
    if (json['issuer'] != _issuer ||
        json['require_pushed_authorization_requests'] != true ||
        json['authorization_response_iss_parameter_supported'] != true ||
        !supports('code_challenge_methods_supported', 'S256') ||
        !supports('dpop_signing_alg_values_supported', 'ES256') ||
        !supports('response_types_supported', 'code') ||
        !supports('grant_types_supported', 'authorization_code') ||
        !supports('grant_types_supported', 'refresh_token') ||
        !supports('token_endpoint_auth_methods_supported', 'none')) {
      _reject();
    }
    Uri endpoint(String key) {
      final raw = json[key];
      if (raw is! String) _reject();
      final uri = Uri.parse(raw);
      if (uri.origin != _issuer ||
          uri.scheme != 'https' ||
          uri.hasPort ||
          uri.path.isEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.userInfo.isNotEmpty ||
          uri.toString() != raw) {
        _reject();
      }
      return uri;
    }

    final par = endpoint('pushed_authorization_request_endpoint');
    final token = endpoint('token_endpoint');
    final authorization = endpoint('authorization_endpoint');
    if ({par, token, authorization}.length != 3) _reject();
    _par = par;
    _token = token;
    _authorization = authorization;
  }

  void _rawToken(Map<String, dynamic> json) {
    if (json['token_type'] != 'DPoP' ||
        json['sub'] != did ||
        json['scope'] is! String ||
        !_hasScopes(json['scope'] as String) ||
        json['access_token'] is! String ||
        (json['access_token'] as String).isEmpty ||
        json['expires_in'] is! num ||
        (json['expires_in'] as num) <= 0 ||
        (json.containsKey('client_id') &&
            json['client_id'] != configuration.blueskyMetadataUri.toString()) ||
        (json.containsKey('iss') && json['iss'] != _issuer)) {
      _reject();
    }
  }

  Never _reject() => throw const AccountConnectionUnavailable();
}
