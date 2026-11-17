import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/publishing/publishing_boundary.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('crossposting/publishing');
  const boundary = PublishingBoundary();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'network observation is fresh and preserves offline and unverified',
    () async {
      final answers = <Object?>[
        false,
        null,
        true,
        PlatformException(code: 'unavailable'),
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'networkAvailability');
            final next = answers.removeAt(0);
            if (next is Exception) throw next;
            return next;
          });
      expect(await boundary.online(), false);
      expect(await boundary.online(), null);
      expect(await boundary.online(), true);
      expect(await boundary.online(), null);
    },
  );
  test(
    'only official exact post/profile URLs cross explicit browser boundary',
    () async {
      final opened = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            opened.add(call.arguments as String);
            return true;
          });
      for (final url in [
        'https://x.com.evil.test/i/status/1',
        'http://x.com/i/status/1',
        'https://x.com/intent/post',
        'https://bsky.app/settings',
        'https://x.com/person?redirect=https://evil.test',
        'https://user@x.com/person',
      ]) {
        expect(await boundary.open(Destination.x, Uri.parse(url)), false);
      }
      expect(opened, isEmpty);
      expect(
        await boundary.open(
          Destination.x,
          Uri.parse('https://x.com/i/status/1234567890'),
        ),
        true,
      );
      expect(
        await boundary.open(
          Destination.bluesky,
          Uri.parse('https://bsky.app/profile/person.bsky.social'),
        ),
        true,
      );
      expect(opened, [
        'https://x.com/i/status/1234567890',
        'https://bsky.app/profile/person.bsky.social',
      ]);
    },
  );
}
