import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';
import '../../support/review_fixtures.dart';

void main() {
  test(
    'account repository surfaces build gates without dropping destinations',
    () async {
      final services = await localTestServices();
      addTearDown(services.close);
      final accounts = await LocalAccountRepository(
        services.database,
        configuration: AppConfiguration(
          xClientId: 'public-fixture-id',
          xRedirectUri: Uri.parse('com.example.caption:/x'),
          blueskyMetadataUri: Uri(),
          blueskyCallbackScheme: '',
        ),
      ).list();
      expect(
        accounts.map((a) => a.destination).toSet(),
        Destination.values.toSet(),
      );
      final x = accounts.singleWhere((a) => a.destination == Destination.x);
      final bluesky = accounts.singleWhere(
        (a) => a.destination == Destination.bluesky,
      );
      expect(x.state, AccountState.unavailable);
      expect(x.capability, contains('verification'));
      expect(bluesky.state, AccountState.unavailable);
      expect(bluesky.capability, contains('missing or invalid'));
      expect(await services.accounts.instagramAssistedSharing(), isTrue);
    },
  );

  test('app composition preserves offline draft content and local Instagram review', () async {
    final services = await localTestServices();
    addTearDown(services.close);
    final asset = await photo(
      services.media.root,
      services.media.importFile,
      'p1-photo',
    );
    final draft = sampleDraft().copyWith(
      shared: PostContent(
        text: 'Kept offline',
        media: [Attachment(assetId: asset.id)],
      ),
    );
    await services.drafts.save(draft, expectedRevision: -1);
    expect(services.validators, isA<CapabilityRegistry>());
    final result = await services.review.review(draft, directOnline: false);
    expect(result.snapshot.posts.keys.toSet(), Destination.values.toSet());
    expect(
      result.snapshot.posts.values.every(
        (p) => p.content.text == 'Kept offline',
      ),
      isTrue,
    );
    expect(
      result.issues.where((i) => i.destination == Destination.instagram),
      isEmpty,
    );
    for (final destination in [Destination.x, Destination.bluesky]) {
      expect(
        result.issues.any(
          (i) =>
              i.destination == destination &&
              i.code == 'requirements-unverified' &&
              i.blocking,
        ),
        isTrue,
      );
    }
    expect(await services.drafts.get(draft.id), draft);
  });
}
