import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/providers/provider.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_fixtures.dart';

void main() async {
  Future<List<String>> codes(
    ProviderCapabilities profile,
    ResolvedPost post,
  ) async =>
      (await CapabilityValidator(profile, FixtureTextCounter()).validate(post))
          .map((i) => i.code)
          .toList();

  test('unsupported video blocks only its destination', () async {
    final profile = fixtureCapabilities(video: false);
    final issues = await CapabilityValidator(
      profile,
      FixtureTextCounter(),
    ).validate(fixtureVideoPost(Destination.bluesky));
    expect(issues.single.code, 'video-unavailable');
    expect(issues.single.destination, Destination.bluesky);
    expect(issues.single.blocking, isTrue);
  });

  test('exact fixture text/photo/video boundaries pass', () async {
    final profile = fixtureCapabilities();
    expect(await codes(profile, fixturePost(text: 'a' * 20)), isEmpty);
    expect(
      await codes(
        profile,
        fixturePost(
          assets: [
            fixtureAsset(),
            fixtureAsset(id: 'second'),
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      await codes(profile, fixtureVideoPost(Destination.bluesky)),
      isEmpty,
    );
  });

  test('uses injected text units and separate UTF8 byte ceiling', () async {
    final profile = fixtureCapabilities(maxTextBytes: 40);
    expect(await codes(profile, fixturePost(text: '👨‍👩‍👧‍👦')), isEmpty);
    expect(await codes(profile, fixturePost(text: 'a' * 21)), [
      'text-too-long',
    ]);
    expect(await codes(profile, fixturePost(text: '👨‍👩‍👧‍👦' * 2)), [
      'text-bytes-too-large',
    ]);
  });

  test(
    'unsupported text and photos remain explicit destination issues',
    () async {
      expect(await codes(fixtureCapabilities(text: false), fixturePost()), [
        'text-unavailable',
      ]);
      expect(
        await codes(
          fixtureCapabilities(photos: false),
          fixturePost(assets: [fixtureAsset()]),
        ),
        ['photos-unavailable'],
      );
    },
  );

  test(
    'photo count, media type and byte limits block invalid inputs',
    () async {
      final profile = fixtureCapabilities();
      expect(
        await codes(
          profile,
          fixturePost(
            assets: [
              fixtureAsset(),
              fixtureAsset(id: '2'),
              fixtureAsset(id: '3'),
            ],
          ),
        ),
        contains('photo-count'),
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(mimeType: 'image/gif')]),
        ),
        contains('mime-unavailable'),
      );
      expect(
        await codes(
          profile,
          fixturePost(
            assets: [fixtureAsset(mimeType: 'application/octet-stream')],
          ),
        ),
        contains('mime-unavailable'),
      );
      expect(
        await codes(profile, fixturePost(assets: [fixtureAsset(bytes: 101)])),
        contains('photo-bytes-too-large'),
      );
      final video = fixtureVideoPost(Destination.bluesky);
      expect(
        await codes(
          profile,
          video.copyWith(assets: [video.assets.single.copyWith(bytes: 201)]),
        ),
        contains('video-bytes-too-large'),
      );
      expect(
        await codes(
          profile,
          video.copyWith(
            assets: [video.assets.single.copyWith(durationMs: 1001)],
          ),
        ),
        contains('video-duration-too-long'),
      );
    },
  );

  test('missing and nonpositive media metadata cannot pass', () async {
    final profile = fixtureCapabilities();
    for (final asset in [
      fixtureAsset(bytes: 0),
      fixtureAsset(width: 0),
      fixtureAsset(height: -1),
    ]) {
      expect(
        await codes(profile, fixturePost(assets: [asset])),
        contains('media-metadata-unavailable'),
      );
    }
    final video = fixtureVideoPost(Destination.bluesky);
    expect(
      await codes(
        profile,
        video.copyWith(
          assets: [video.assets.single.copyWith(durationMs: null)],
        ),
      ),
      contains('media-metadata-unavailable'),
    );
    expect(
      await codes(
        profile,
        video.copyWith(assets: [video.assets.single.copyWith(durationMs: 0)]),
      ),
      contains('media-metadata-unavailable'),
    );
  });

  test(
    'named dimension and aspect restrictions apply at exact boundaries',
    () async {
      final profile = fixtureCapabilities(
        minWidth: 6,
        maxWidth: 8,
        minHeight: 4,
        maxHeight: 6,
        minAspectRatio: 1,
        maxAspectRatio: 2,
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(width: 6, height: 6)]),
        ),
        isEmpty,
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(width: 8, height: 4)]),
        ),
        isEmpty,
      );
      expect(
        await codes(profile, fixturePost(assets: [fixtureAsset(width: 5)])),
        contains('media-dimensions'),
      );
      expect(
        await codes(profile, fixturePost(assets: [fixtureAsset(width: 9)])),
        contains('media-dimensions'),
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(width: 6, height: 3)]),
        ),
        contains('media-dimensions'),
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(width: 8, height: 7)]),
        ),
        contains('media-dimensions'),
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(width: 6, height: 7)]),
        ),
        contains('media-aspect'),
      );
      expect(
        await codes(
          profile,
          fixturePost(assets: [fixtureAsset(width: 8, height: 3)]),
        ),
        contains('media-aspect'),
      );
    },
  );

  test('mismatched resolved media and destination cannot pass', () async {
    final profile = fixtureCapabilities();
    expect(
      await codes(
        profile,
        fixturePost(assets: [fixtureAsset()]).copyWith(assets: []),
      ),
      ['media-unavailable'],
    );
    expect(
      await codes(
        profile,
        fixturePost(assets: [fixtureAsset()])
            .copyWith(assets: [fixtureAsset(id: 'other')]),
      ),
      ['media-unavailable'],
    );
    expect(await codes(profile, fixturePost(destination: Destination.x)), [
      'requirements-unverified',
    ]);
  });

  test('unavailable and superseded profiles never authorize content', () async {
    for (final status in [
      CapabilityStatus.unavailable,
      CapabilityStatus.superseded,
    ]) {
      final issues = await CapabilityValidator(
        fixtureCapabilities(status: status),
        FixtureTextCounter(),
      ).validate(fixturePost());
      expect(issues.single.message, "Couldn't check current requirements");
      expect(issues.single.blocking, isTrue);
    }
  });

  test('capability inputs and registry own their collections', () async {
    final types = {'image/png'};
    final profile = fixtureCapabilities(mimeTypes: types);
    types.clear();
    expect(
      await codes(profile, fixturePost(assets: [fixtureAsset()])),
      isEmpty,
    );
    expect(() => profile.mimeTypes.clear(), throwsUnsupportedError);
    final policy = InstagramPhotoPolicy.localPreparation();
    final validators = <Destination, DestinationValidator>{
      Destination.instagram: policy,
    };
    final registry = CapabilityRegistry(validators);
    validators.clear();
    expect(registry.forDestination(Destination.instagram), same(policy));
    expect(
      (await registry
              .forDestination(Destination.x)
              .validate(fixturePost(destination: Destination.x)))
          .single
          .blocking,
      isTrue,
    );
  });

  test(
    'shipping registry preserves Instagram local preparation independently',
    () async {
      final policy = InstagramPhotoPolicy.localPreparation();
      final registry = CapabilityRegistry.production(instagram: policy);
      expect(
        await registry
            .forDestination(Destination.instagram)
            .validate(
              fixturePost(
                destination: Destination.instagram,
                assets: [fixtureAsset()],
              ),
            ),
        isEmpty,
      );
      for (final destination in [Destination.x, Destination.bluesky]) {
        final validator = registry.forDestination(destination);
        expect(validator.version, contains('2026-11-16'));
        expect(
          (await validator.validate(fixturePost(destination: destination)))
              .single
              .code,
          'requirements-unverified',
        );
      }
      expect(platformName(Destination.x), 'X');
      expect(platformName(Destination.bluesky), 'Bluesky');
      expect(platformName(Destination.instagram), 'Instagram');
    },
  );
}
