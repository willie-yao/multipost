import 'package:flutter/services.dart';

import '../drafts/draft.dart';
import 'attempt.dart';

/// Android point-in-time observations and explicit official-link launches.
/// No listener, callback, or browser return can create publication evidence.
class PublishingBoundary {
  const PublishingBoundary();
  static const _channel = MethodChannel('crossposting/publishing');

  Future<bool?> online() async {
    try {
      return await _channel.invokeMethod<bool>('networkAvailability');
    } catch (_) {
      return null;
    }
  }

  Future<bool> open(Destination destination, Uri uri) async {
    if (!officialPublishingUrl(destination, uri)) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openOfficialUrl',
            uri.toString(),
          ) ==
          true;
    } catch (_) {
      return false;
    }
  }
}

bool officialPublishingUrl(Destination destination, Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  if (destination == Destination.x && uri.host == 'x.com') {
    return RegExp(r'^/i/status/[1-9][0-9]*$').hasMatch(uri.path) ||
        RegExp(r'^/[A-Za-z0-9_]{1,15}$').hasMatch(uri.path) &&
            !{
              'intent',
              'settings',
              'home',
              'compose',
              'search',
              'login',
              'logout',
              'i',
            }.contains(uri.path.substring(1).toLowerCase());
  }
  if (destination == Destination.bluesky && uri.host == 'bsky.app') {
    return RegExp(
      r'^/profile/(?:did:plc:[a-z2-7]{24}|[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,})(?:/post/[234567abcdefghijklmnopqrstuvwxyz]{13})?$',
    ).hasMatch(uri.path);
  }
  return false;
}

/// Receipt URLs are derived from the exact retained provider ID, never arbitrary
/// provider text. With no valid ID, Check can open only the frozen profile.
Uri? officialAttemptUrl(
  DestinationAttempt attempt, {
  bool profileFallback = false,
}) {
  final destination = attempt.snapshot.destination;
  final id = attempt.outcome.remoteId;
  Uri? url;
  if (id != null &&
      destination == Destination.x &&
      RegExp(r'^[1-9][0-9]*$').hasMatch(id)) {
    url = Uri.https('x.com', '/i/status/$id');
  } else if (id != null && destination == Destination.bluesky) {
    final match = RegExp(
      r'^at://(did:plc:[a-z2-7]{24})/app.bsky.feed.post/([234567abcdefghijklmnopqrstuvwxyz]{13})$',
    ).firstMatch(id);
    if (match != null && match[1] == attempt.snapshot.account?.subject) {
      url = Uri.https('bsky.app', '/profile/${match[1]}/post/${match[2]}');
    }
  }
  if (url == null && profileFallback) {
    final account = attempt.snapshot.account;
    if (destination == Destination.x && account != null) {
      url = Uri.https(
        'x.com',
        '/${account.handle.replaceFirst(RegExp(r"^@"), "")}',
      );
    } else if (destination == Destination.bluesky && account != null) {
      url = Uri.https('bsky.app', '/profile/${account.subject}');
    }
  }
  return url != null && officialPublishingUrl(destination, url) ? url : null;
}
