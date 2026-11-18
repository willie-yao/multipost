import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_fixtures.dart';

void main() {
  BlueskyValidator validator({required bool devAccepted}) => BlueskyValidator(
    ProviderCapabilities.documented(
      Destination.bluesky,
      devAccepted: devAccepted,
    ),
  );

  test('ordinary builds keep Bluesky posting unverified', () async {
    final issues = await validator(devAccepted: false).validate(fixturePost());
    expect(issues.map((i) => i.code), contains('requirements-unverified'));
    expect(issues.any((i) => i.blocking), isTrue);
  });

  test('a dev-accepted build allows Bluesky text and photo posts', () async {
    final v = validator(devAccepted: true);
    expect(await v.validate(fixturePost(text: 'Hello Bluesky')), isEmpty);
    final photo = fixturePost(
      assets: [fixtureAsset(id: 'photo', mimeType: 'image/jpeg', bytes: 1000)],
    );
    expect((await v.validate(photo)).where((i) => i.blocking), isEmpty);
  });

  test('a dev-accepted build still blocks video and over-limit text', () async {
    final v = validator(devAccepted: true);
    expect(
      (await v.validate(fixtureVideoPost(Destination.bluesky)))
          .any((i) => i.blocking),
      isTrue,
    );
    expect(
      (await v.validate(fixturePost(text: 'a' * 301))).any((i) => i.blocking),
      isTrue,
    );
  });

  test('X is never accepted by the Bluesky switch', () {
    final x = ProviderCapabilities.documented(Destination.x, devAccepted: true);
    expect(x.status, CapabilityStatus.unavailable);
  });

  test('posting needs both dev switches and valid owned setup', () {
    AppConfiguration build({required bool connect, required bool post}) =>
        AppConfiguration(
          xClientId: '',
          xRedirectUri: Uri(),
          blueskyMetadataUri: Uri.parse(
            'https://willie-yao.github.io/multipost/client-metadata.json',
          ),
          blueskyCallbackScheme: 'io.github.willie-yao',
          blueskyDevConnect: connect,
          blueskyDevPost: post,
        );
    expect(build(connect: true, post: true).blueskyPostingAccepted, isTrue);
    expect(build(connect: true, post: false).blueskyPostingAccepted, isFalse);
    expect(build(connect: false, post: true).blueskyPostingAccepted, isFalse);
  });
}
