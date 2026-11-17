import 'dart:io';

import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/providers/provider.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<NativeFixtureServices> nativeFixture(
  Directory root, {
  Map<Destination, PublishProvider> providers = const {},
  MediaFiles Function(LocalDatabase, Directory)? mediaFactory,
}) async {
  await root.create(recursive: true);
  final db = await LocalDatabase.open(
    databaseFactory,
    p.join(root.path, 'fixture.db'),
  );
  final mediaRoot = Directory(p.join(root.path, 'media'));
  final media =
      mediaFactory?.call(db, mediaRoot) ??
      MediaFiles(db, mediaRoot, const Ids());
  return NativeFixtureServices(
    database: db,
    media: media,
    root: root,
    providers: providers,
  );
}

class NativeFixtureServices extends AppServices {
  NativeFixtureServices({
    required super.database,
    required super.media,
    required Directory root,
    required Map<Destination, PublishProvider> providers,
  }) : super(
         drafts: SqliteDraftRepository(database, media: media),
         accounts: LocalAccountRepository(database),
         clock: const Clock(),
         ids: const Ids(),
         instagramPackageRoot: Directory(p.join(root.path, 'packages')),
         publishProviders: providers,
         publishingOnline: () => true,
       );
  @override
  ReviewService get review => _fixtureReview;
  late final _fixtureReview = ReviewService(
    drafts,
    media,
    accounts,
    _NativeValidators(this),
    clock,
  );
}

class _NativeValidators implements ValidatorRegistry, DestinationValidator {
  _NativeValidators(this.app);
  final AppServices app;
  @override
  DestinationValidator forDestination(Destination d) =>
      d == Destination.instagram ? app.instagramPolicy : this;
  @override
  String get version => 'r1-SYNTHETIC-only-1';
  @override
  List<ReviewIssue> validate(ResolvedPost post) => [];
}

class NativePublisher implements PublishProvider {
  NativePublisher(this.destination, this.status);
  @override
  final Destination destination;
  PublishStatus status;
  int sends = 0;
  Future<PublishOutcome> Function(ResolvedPost, PublishContext)? onSend;
  @override
  Future<PublishOutcome> send(ResolvedPost post, PublishContext context) async {
    sends++;
    if (onSend != null) return onSend!(post, context);
    if (status == PublishStatus.published || status == PublishStatus.unknown) {
      await context.markDispatch();
    }
    return PublishOutcome(
      status: status,
      source: status == PublishStatus.published
          ? EvidenceSource.provider
          : EvidenceSource.local,
      at: DateTime.now().toUtc(),
      remoteId: status == PublishStatus.published
          ? destination == Destination.x
                ? '1234567890'
                : 'at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/3lbrt5aaa2222'
          : null,
    );
  }

  @override
  Future<PublishOutcome> check(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  ) async => previous;
}

Future<void> connectNativeFixtures(AppServices app) async {
  for (final d in [Destination.x, Destination.bluesky]) {
    await app.accounts.save(
      AccountView(
        destination: d,
        state: AccountState.connected,
        capability: 'Synthetic fixture only; no live provider acceptance',
        identity: AccountIdentity(
          destination: d,
          subject: d == Destination.x
              ? '101'
              : 'did:plc:abcdefghijklmnopqrstuvwx',
          handle: d == Destination.x
              ? '@synthetic_handle_with_a_long_name'
              : 'synthetic-long-handle.bsky.social',
        ),
      ),
    );
  }
}

Future<XFile> syntheticPhoto(Directory root, int ordinal) async {
  final image = img.Image(width: 720, height: 480);
  img.fill(image, color: img.ColorRgb8(255, 246, 190));
  img.fillRect(
    image,
    x1: 0,
    y1: 240,
    x2: 720,
    y2: 480,
    color: ordinal.isEven
        ? img.ColorRgb8(255, 198, 0)
        : img.ColorRgb8(0, 130, 170),
  );
  final source = File(p.join(root.path, 'synthetic-picker-$ordinal.png'));
  await source.writeAsBytes(img.encodePng(image), flush: true);
  return XFile(source.path);
}

Future<void> nativeSettle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
