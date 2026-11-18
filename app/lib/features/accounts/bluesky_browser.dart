import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../app/app_configuration.dart';
import '../drafts/draft.dart';
import 'account.dart';

/// Android-first external browser bridge. The OAuth driver validates the exact
/// returned target and durable state before the SDK may exchange a code.
/// Browsers whose Auth Tab returns the sign-in result itself. Bluesky's
/// "Sign-in complete" page redirects by script, which an ordinary custom tab
/// may refuse to hand to the app without a tap. When none is installed, the
/// default browser and the callback activity are used.
const authTabBrowsers = [
  'com.android.chrome',
  'com.chrome.beta',
  'com.chrome.dev',
  'com.microsoft.emmx',
];

class BlueskyBrowser {
  const BlueskyBrowser(this.configuration);
  final AppConfiguration configuration;
  static const _channel = MethodChannel('crossposting/accounts');

  Future<String> open(Uri authorizationUrl) async {
    if (!configuration.connection(Destination.bluesky).available) {
      throw const AccountConnectionUnavailable();
    }
    try {
      if (await _channel.invokeMethod<bool>(
            'prepareBlueskyAuthorization',
            configuration.blueskyRedirectUri.toString(),
          ) !=
          true) {
        throw const AccountConnectionUnavailable();
      }
      return await FlutterWebAuth2.authenticate(
        url: authorizationUrl.toString(),
        callbackUrlScheme: configuration.blueskyCallbackScheme,
        options: const FlutterWebAuth2Options(
          customTabsPackageOrder: authTabBrowsers,
        ),
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') throw const AccountConnectionCancelled();
      throw const AccountConnectionUnavailable();
    } catch (_) {
      throw const AccountConnectionUnavailable();
    }
  }
}
