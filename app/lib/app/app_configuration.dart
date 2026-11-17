import '../features/drafts/draft.dart';

/// Public build metadata only; never accepts a client secret or credentials.
class AppConfiguration {
  const AppConfiguration({
    required this.xClientId,
    required this.xRedirectUri,
    required this.blueskyMetadataUri,
    required this.blueskyCallbackScheme,
  });
  final String xClientId;
  final Uri xRedirectUri;
  final Uri blueskyMetadataUri;
  final String blueskyCallbackScheme;

  factory AppConfiguration.fromEnvironment() => AppConfiguration(
    xClientId: const String.fromEnvironment('X_CLIENT_ID'),
    xRedirectUri: _uri(const String.fromEnvironment('X_REDIRECT_URI')),
    blueskyMetadataUri: _uri(
      const String.fromEnvironment('BLUESKY_METADATA_URI'),
    ),
    blueskyCallbackScheme: const String.fromEnvironment(
      'BLUESKY_CALLBACK_SCHEME',
    ),
  );

  Uri get blueskyRedirectUri =>
      Uri(scheme: blueskyCallbackScheme, path: '/callback');

  ConnectionGate connection(Destination destination) {
    switch (destination) {
      case Destination.instagram:
        return const ConnectionGate(
          configured: true,
          available: true,
          reason: 'Prepare photos locally and finish in Instagram.',
        );
      case Destination.x:
        if (!RegExp(r'^[\x21-\x7e]+$').hasMatch(xClientId) ||
            !_xCallback(xRedirectUri)) {
          return const ConnectionGate(
            configured: false,
            available: false,
            reason: 'X connection setup is missing or invalid. Keep drafting while the app owner supplies the public client ID and registered callback.',
          );
        }
        return const ConnectionGate(
          configured: true,
          available: false,
          reason: 'X connection verification is incomplete in this build. Keep drafting while app setup and provider checks are completed.',
        );
      case Destination.bluesky:
        if (!_metadata(blueskyMetadataUri) ||
            blueskyCallbackScheme !=
                blueskyMetadataUri.host.split('.').reversed.join('.')) {
          return const ConnectionGate(
            configured: false,
            available: false,
            reason: 'Bluesky connection setup is missing or invalid. The app owner must supply HTTPS client metadata and its matching native callback scheme. Keep drafting.',
          );
        }
        return const ConnectionGate(
          configured: true,
          available: false,
          reason: 'Bluesky connection verification is incomplete in this build. Keep drafting while app setup and provider checks are completed.',
        );
    }
  }
}

class ConnectionGate {
  const ConnectionGate({
    required this.configured,
    required this.available,
    required this.reason,
  });
  final bool configured;
  final bool available;
  final String reason;
}

Uri _uri(String raw) => Uri.tryParse(raw) ?? Uri();
bool _cleanTarget(Uri uri) =>
    !uri.hasQuery && !uri.hasFragment && uri.userInfo.isEmpty;
bool _publicHost(String host) =>
    RegExp(r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]$')
        .hasMatch(host) &&
    ![
      'localhost',
      'local',
      'internal',
    ].any((suffix) => host.endsWith('.$suffix'));
bool _metadata(Uri uri) =>
    uri.scheme == 'https' &&
    _publicHost(uri.host) &&
    !uri.hasPort &&
    uri.path.isNotEmpty &&
    _cleanTarget(uri);
bool _xCallback(Uri uri) =>
    _cleanTarget(uri) &&
    uri.path.startsWith('/') &&
    ((uri.scheme == 'https' && _publicHost(uri.host) && !uri.hasPort) ||
        (_publicHost(uri.scheme) && !uri.hasAuthority));
