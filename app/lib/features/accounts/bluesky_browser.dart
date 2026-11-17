import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../app/app_configuration.dart';
import '../drafts/draft.dart';
import 'account.dart';

/// Android-first external browser bridge. The OAuth driver validates the exact
/// returned target and durable state before the SDK may exchange a code.
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
      ).timeout(const Duration(minutes: 10));
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') throw const AccountConnectionCancelled();
      throw const AccountConnectionUnavailable();
    } catch (_) {
      throw const AccountConnectionUnavailable();
    }
  }
}
