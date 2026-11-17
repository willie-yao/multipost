import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/provider.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';

import 'review_fixtures.dart';

// Real host, storage, policy and coordinator; only direct validation/transport
// is synthetic. This never enables production capability gates.
class FixturePublishingServices extends AppServices {
  FixturePublishingServices(
    AppServices base, {
    required Map<Destination, PublishProvider> providers,
    required bool? Function() online,
  }) : super(
         database: base.database,
         media: base.media,
         drafts: base.drafts,
         accounts: base.accounts,
         clock: base.clock,
         ids: base.ids,
         instagramPackageRoot: base.instagramPackageRoot,
         publishProviders: providers,
         publishingOnline: online,
       );
  @override
  ReviewService get review => _fixtureReview;
  late final _fixtureReview = ReviewService(
    drafts,
    media,
    accounts,
    CapabilityRegistry({
      Destination.x: TestValidators(),
      Destination.bluesky: TestValidators(),
      Destination.instagram: instagramPolicy,
    }),
    clock,
  );
}
