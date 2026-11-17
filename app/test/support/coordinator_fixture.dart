import 'dart:async';

import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/providers/provider.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/attempt_repository.dart';
import 'package:cross_posting_app/features/publishing/publish_coordinator.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/review/review_service.dart';

import 'app_fixture.dart';
import 'instagram_fixture.dart';
import 'review_fixtures.dart';

class CoordinatorClock extends Clock {
  DateTime value = DateTime.utc(2026, 11, 17);
  @override
  DateTime now() => value;
}

class FixturePublisher implements PublishProvider {
  FixturePublisher(this.destination, this.clock, this.outcomes);
  @override
  final Destination destination;
  final Clock clock;
  final List<PublishStatus> outcomes;
  final sent = <ResolvedPost>[];
  final contexts = <PublishContext>[];
  int createCount = 0;
  int checkCount = 0;
  Future<PublishOutcome> Function(ResolvedPost, PublishContext)? onSend;
  Future<PublishOutcome> Function(ResolvedPost, PublishOutcome, PublishContext)?
  onCheck;
  PublishOutcome outcome(PublishStatus status) => PublishOutcome(
    status: status,
    source: status == PublishStatus.published
        ? EvidenceSource.provider
        : EvidenceSource.local,
    at: clock.now(),
    remoteId: status != PublishStatus.published
        ? null
        : destination == Destination.x
        ? '1234567890'
        : 'at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/3lbrt5aaa2222',
  );
  @override
  Future<PublishOutcome> send(ResolvedPost post, PublishContext context) async {
    sent.add(post);
    contexts.add(context);
    if (onSend != null) return onSend!(post, context);
    final status = outcomes[(sent.length - 1).clamp(0, outcomes.length - 1)];
    if (status == PublishStatus.published || status == PublishStatus.unknown) {
      await context.markDispatch();
      createCount++;
    }
    return outcome(status);
  }

  @override
  Future<PublishOutcome> check(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  ) async {
    checkCount++;
    return onCheck == null ? previous : onCheck!(post, previous, context);
  }
}

class CountedInstagram extends InstagramService {
  CountedInstagram(AppServices app, Clock clock)
    : super(
        app.instagramRepo,
        app.media,
        app.instagramPackageRoot,
        fixtureInstagramPolicy,
        app.ids,
        clock,
      );
  int prepareCount = 0;
  bool fail = false;
  @override
  Future<InstagramPackage> prepare(
    ReviewedPost reviewed, {
    required String operationId,
  }) async {
    prepareCount++;
    if (fail) {
      throw const InstagramPreparationException(
        'Synthetic preparation failure',
      );
    }
    return super.prepare(reviewed, operationId: operationId);
  }
}

class CoordinatorHarness {
  CoordinatorHarness._(this.app);
  final AppServices app;
  final clock = CoordinatorClock();
  final directValidator = TestValidators();
  late final validators = CapabilityRegistry({
    Destination.x: directValidator,
    Destination.bluesky: directValidator,
    Destination.instagram: fixtureInstagramPolicy,
  });
  late final reviewService = ReviewService(
    app.drafts,
    app.media,
    app.accounts,
    validators,
    clock,
  );
  late final attempts = AttemptRepository(app.database, clock, app.ids);
  late final instagram = CountedInstagram(app, clock);
  late final FixturePublisher x;
  late final FixturePublisher bluesky;
  late ReviewedPost review;
  bool? online = true;
  late final coordinator = makeCoordinator();
  PublishCoordinator makeCoordinator({AttemptRepository? repository}) =>
      PublishCoordinator(
        attempts: repository ?? attempts,
        review: reviewService,
        instagram: instagram,
        providers: {Destination.x: x, Destination.bluesky: bluesky},
        clock: clock,
        directOnline: () => online,
      );
  Future<ReviewedPost> reviewDraft(Draft draft) async {
    final result = await reviewService.review(draft, directOnline: online);
    if (!result.canProceed) {
      throw StateError('Fixture review blocked: ${result.issues}');
    }
    return result.snapshot;
  }

  Future<void> close() => app.close();
}

Future<CoordinatorHarness> coordinatorHarness({
  List<PublishStatus> x = const [PublishStatus.published],
  List<PublishStatus> bluesky = const [PublishStatus.notPublished],
  Set<Destination> selected = const {
    Destination.x,
    Destination.bluesky,
    Destination.instagram,
  },
}) async {
  final app = await localTestServices();
  final h = CoordinatorHarness._(app);
  h.x = FixturePublisher(Destination.x, h.clock, x);
  h.bluesky = FixturePublisher(Destination.bluesky, h.clock, bluesky);
  for (final destination in [Destination.x, Destination.bluesky]) {
    await app.accounts.save(
      AccountView(
        destination: destination,
        state: AccountState.connected,
        capability: 'SYNTHETIC-only',
        identity: AccountIdentity(
          destination: destination,
          subject: destination == Destination.x
              ? 'person'
              : 'did:plc:abcdefghijklmnopqrstuvwx',
          handle: '@person',
        ),
      ),
    );
  }
  final asset = await photo(
    app.media.root,
    app.media.importFile,
    'coordinator',
  );
  final draft = Draft(
    id: app.ids.next(),
    updatedAt: h.clock.now(),
    selected: selected,
    shared: PostContent(
      text: 'Frozen caption',
      media: [Attachment(assetId: asset.id, altText: 'Exact description')],
    ),
  );
  await app.drafts.save(draft, expectedRevision: -1);
  h.review = await h.reviewDraft(draft);
  return h;
}

class ReceiptAcknowledgmentLostRepository extends AttemptRepository {
  ReceiptAcknowledgmentLostRepository(super.database, super.clock, super.ids);
  bool lost = false;
  @override
  Future<void> record(String id, PublishOutcome outcome) async {
    await super.record(id, outcome);
    if (!lost && outcome.status == PublishStatus.published) {
      lost = true;
      throw UnrecordedReceipt(outcome.remoteId!);
    }
  }
}
