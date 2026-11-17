import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/bluesky_browser.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _AcceptedTestConfiguration extends AppConfiguration {
  _AcceptedTestConfiguration()
    : super(
        xClientId: '',
        xRedirectUri: Uri(),
        blueskyMetadataUri: Uri.parse(
          'https://caption.example.com/client.json',
        ),
        blueskyCallbackScheme: 'com.example.caption',
      );
  @override
  ConnectionGate connection(Destination destination) => const ConnectionGate(
    configured: true,
    available: true,
    reason: 'Synthetic acceptance',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const accounts = MethodChannel('crossposting/accounts');
  const web = MethodChannel('flutter_web_auth_2');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(accounts, null);
    messenger.setMockMethodCallHandler(web, null);
  });
  test(
    'production gate prevents native preflight and browser launch',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(accounts, (_) async {
        calls++;
        return true;
      });
      messenger.setMockMethodCallHandler(web, (_) async {
        calls++;
        return '';
      });
      final config = AppConfiguration(
        xClientId: '',
        xRedirectUri: Uri(),
        blueskyMetadataUri: Uri.parse(
          'https://caption.example.com/client.json',
        ),
        blueskyCallbackScheme: 'com.example.caption',
      );
      await expectLater(
        BlueskyBrowser(config)
            .open(Uri.parse('https://bsky.social/oauth/authorize')),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(calls, 0);
    },
  );
  test(
    'preflight sends exact compiled redirect before external browser bridge',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(accounts, (call) async {
        calls.add(call.method);
        expect(call.arguments, 'com.example.caption:/callback');
        return true;
      });
      messenger.setMockMethodCallHandler(web, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        expect(args['callbackUrlScheme'], 'com.example.caption');
        return 'com.example.caption:/callback?code=synthetic';
      });
      final returned = await BlueskyBrowser(_AcceptedTestConfiguration()).open(
        Uri.parse('https://bsky.social/oauth/authorize?request_uri=synthetic'),
      );
      expect(returned, contains('code=synthetic'));
      expect(calls, ['prepareBlueskyAuthorization', 'authenticate']);
    },
  );
  test(
    'native mismatch prevents browser and native cancellation is sanitized',
    () async {
      var webCalls = 0;
      messenger.setMockMethodCallHandler(accounts, (_) async => false);
      messenger.setMockMethodCallHandler(web, (_) async {
        webCalls++;
        throw PlatformException(code: 'CANCELED', message: 'sensitive');
      });
      final browser = BlueskyBrowser(_AcceptedTestConfiguration());
      await expectLater(
        browser.open(Uri.parse('https://bsky.social/oauth/authorize')),
        throwsA(isA<AccountConnectionUnavailable>()),
      );
      expect(webCalls, 0);
      messenger.setMockMethodCallHandler(accounts, (_) async => true);
      await expectLater(
        browser.open(Uri.parse('https://bsky.social/oauth/authorize')),
        throwsA(isA<AccountConnectionCancelled>()),
      );
      expect(webCalls, 1);
    },
  );
}
