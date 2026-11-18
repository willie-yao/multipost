import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/accepted_app_fixture.dart';
import '../support/app_fixture.dart';
import '../support/coordinator_fixture.dart';

void main() {
  testWidgets(
    'real host Unknown final-risk cancel, reentry and database restart require a new decision',
    (tester) async {
      final h = (await tester.runAsync(
        () => coordinatorHarness(
          selected: {Destination.x, Destination.bluesky},
          bluesky: [PublishStatus.unknown, PublishStatus.published],
        ),
      ))!;
      final base = h.app;
      AppServices current = base;
      addTearDown(() async {
        await current.close();
      });
      final group = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      FixturePublishingServices services(AppServices app) =>
          FixturePublishingServices(
            app,
            providers: {Destination.x: h.x, Destination.bluesky: h.bluesky},
            online: () => true,
          );
      Future<void> openLibrary() async {
        await tester.pumpWidget(
          CaptionApp(
            key: UniqueKey(),
            home: LibraryScreen(services: services(current)),
          ),
        );
        await settleEditor(tester);
      }

      Future<void> openRiskReview() async {
        await tester.ensureVisible(find.text('Review posting results'));
        await tester.tap(find.text('Review posting results'));
        await settleEditor(tester);
        await tester.ensureVisible(find.text('Send again…'));
        await tester.tap(find.text('Send again…'));
        await settleEditorUntil(tester, () {
          final button = find.widgetWithText(
            FilledButton,
            'Publish to Bluesky',
          );
          return button.evaluate().isNotEmpty &&
              tester.widget<FilledButton>(button).onPressed != null;
        });
        expect(find.text('This could create a duplicate post'), findsNothing);
        expect(h.bluesky.sent, hasLength(1));
      }

      Future<void> openFinalDecision() async {
        await tester.tap(
          find.widgetWithText(FilledButton, 'Publish to Bluesky'),
        );
        // Review remains busy while its final decision is open.
        for (
          var i = 0;
          i < 300 &&
              find
                  .text('This could create a duplicate post')
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 25));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('This could create a duplicate post'), findsOneWidget);
        expect(h.bluesky.sent, hasLength(1));
      }

      await openLibrary();
      // The attention row carries the same per-destination marks as Results.
      expect(find.text('Bluesky · Unknown'), findsOneWidget);
      await openRiskReview();
      await openFinalDecision();
      await tester.tap(find.text('Keep checking'));
      await settleEditor(tester);
      expect(find.text('This could create a duplicate post'), findsNothing);
      expect(h.bluesky.sent, hasLength(1));
      await openFinalDecision();
      await tester.binding.handlePopRoute();
      await settleEditor(tester);
      expect(find.text('This could create a duplicate post'), findsNothing);
      expect(h.bluesky.sent, hasLength(1));
      await tester.ensureVisible(find.byTooltip('Back to library'));
      await tester.tap(find.byTooltip('Back to library'));
      await settleEditor(tester);
      expect(find.text('Bluesky · Unknown'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Back to library'));
      await tester.tap(find.byTooltip('Back to library'));
      await settleEditor(tester);
      await openRiskReview();
      await openFinalDecision();
      await tester.tap(find.text('Keep checking'));
      await settleEditor(tester);
      final path = current.database.db.path;
      final mediaRoot = current.media.root;
      final packageRoot = current.instagramPackageRoot;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(current.database.close);
      current = (await tester.runAsync(() async {
        final db = await LocalDatabase.open(databaseFactoryFfiNoIsolate, path);
        final media = MediaFiles(db, mediaRoot, base.ids);
        return AppServices(
          database: db,
          media: media,
          drafts: SqliteDraftRepository(db, media: media),
          accounts: LocalAccountRepository(db),
          clock: base.clock,
          ids: base.ids,
          instagramPackageRoot: packageRoot,
          onClose: () => Directory(path).parent.delete(recursive: true),
        );
      }))!;
      await tester.runAsync(current.attempts.recoverInterrupted);
      await openLibrary();
      expect(h.bluesky.sent, hasLength(1));
      await openRiskReview();
      await openFinalDecision();
      await tester.tap(find.text('I accept the duplicate risk'));
      await settleEditorUntil(
        tester,
        () => find.text('Bluesky · Published').evaluate().isNotEmpty,
      );
      expect(h.x.sent, hasLength(1));
      expect(h.bluesky.sent, hasLength(2));
      final history = (await tester.runAsync(
        () => current.attempts.attempts(group),
      ))!;
      expect(history, hasLength(3));
      expect(
        history
            .where((a) => a.snapshot.destination == Destination.bluesky)
            .first
            .outcome
            .status,
        PublishStatus.unknown,
      );
      expect(history.last.parentId, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
