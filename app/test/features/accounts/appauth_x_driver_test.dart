import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/x_connection.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic setup acceptance exists only in this test, never a build flag.
class _AcceptedFixture extends AppConfiguration {
  _AcceptedFixture()
    : super(
        xClientId: 'public-fixture',
        xRedirectUri: Uri.parse('com.example.caption:/x'),
        blueskyMetadataUri: Uri(),
        blueskyCallbackScheme: '',
      );
  @override
  ConnectionGate connection(Destination destination) => const ConnectionGate(
    configured: true,
    available: true,
    reason: 'Synthetic fixture only',
  );
}

class _AppAuth extends FlutterAppAuth {
  Object? error;
  AuthorizationTokenRequest? authorization;
  TokenRequest? refresh;
  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    authorization = request;
    if (error case final value?) throw value;
    return AuthorizationTokenResponse(
      'opaque-access',
      'opaque-refresh',
      DateTime.utc(2027),
      null,
      'Bearer',
      request.scopes,
      null,
      null,
    );
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    refresh = request;
    if (error case final value?) throw value;
    return TokenResponse(
      'opaque-rotated',
      'opaque-rotated-refresh',
      DateTime.utc(2027),
      null,
      'Bearer',
      null,
      null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('crossposting/accounts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('syntax alone cannot open a browser in production', () async {
    final configuration = AppConfiguration(
      xClientId: 'public-fixture',
      xRedirectUri: Uri.parse('com.example.caption:/x'),
      blueskyMetadataUri: Uri(),
      blueskyCallbackScheme: '',
    );
    final native = _AppAuth();
    await expectLater(
      AppAuthXDriver(configuration, appAuth: native).authorize(),
      throwsA(isA<AccountConnectionUnavailable>()),
    );
    expect(native.authorization, isNull);
  });

  test(
    'native redirect mismatch fails before any browser authorization',
    () async {
      final native = _AppAuth();
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      await expectLater(
        AppAuthXDriver(_AcceptedFixture(), appAuth: native).authorize(),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(native.authorization, isNull);
    },
  );

  test(
    'official public-client request has all required scopes and no secret',
    () async {
      final native = _AppAuth();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'prepareXAuthorization') {
          expect(call.arguments, 'com.example.caption:/x');
        }
        return true;
      });
      final tokens = await AppAuthXDriver(
        _AcceptedFixture(),
        appAuth: native,
      ).authorize();
      expect(tokens.refreshToken, 'opaque-refresh');
      final request = native.authorization!;
      expect(request.clientSecret, isNull);
      expect(request.allowInsecureConnections, isFalse);
      expect(
        request.serviceConfiguration!.authorizationEndpoint,
        'https://x.com/i/oauth2/authorize',
      );
      expect(
        request.serviceConfiguration!.tokenEndpoint,
        'https://api.x.com/2/oauth2/token',
      );
      expect(request.scopes, [
        'tweet.read',
        'tweet.write',
        'users.read',
        'offline.access',
        'media.write',
      ]);
      expect(calls, ['prepareXAuthorization', 'finishXAuthorization']);
    },
  );

  test('native cancel and state mismatch cannot produce token success or unsafe errors', () async {
    final native = _AppAuth();
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    final driver = AppAuthXDriver(_AcceptedFixture(), appAuth: native);
    native.error = FlutterAppAuthUserCancelledException(
      code: 'cancel',
      platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
        errorDescription: 'private callback',
      ),
    );
    await expectLater(
      driver.authorize(),
      throwsA(isA<AccountConnectionCancelled>()),
    );
    native.error = FlutterAppAuthPlatformException(
      code: 'authorize_and_exchange_code_failed',
      platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
        code: '9',
        errorDescription: 'private state mismatch',
      ),
    );
    try {
      await driver.authorize();
      fail('must fail');
    } catch (error) {
      expect(error, isA<AccountConnectionUnavailable>());
      expect(error.toString(), isNot(contains('private')));
    }
  });

  test(
    'only rejected refresh expires account and no client secret is sent',
    () async {
      final native = _AppAuth();
      final driver = AppAuthXDriver(_AcceptedFixture(), appAuth: native);
      await driver.refresh('opaque-refresh');
      expect(native.refresh!.clientSecret, isNull);
      expect(native.refresh!.refreshToken, 'opaque-refresh');
      native.error = FlutterAppAuthPlatformException(
        code: 'token_failed',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
          error: 'invalid_grant',
        ),
      );
      await expectLater(
        driver.refresh('opaque-refresh'),
        throwsA(isA<AccountConnectionExpired>()),
      );
      native.error = FlutterAppAuthPlatformException(
        code: 'token_failed',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
          error: 'server_error',
          errorDescription: 'private',
        ),
      );
      await expectLater(
        driver.refresh('opaque-refresh'),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
    },
  );
}
