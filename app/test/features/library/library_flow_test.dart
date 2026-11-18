import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/accounts/accounts_screen.dart';
import 'package:cross_posting_app/features/compose/draft_session.dart';
import 'package:cross_posting_app/features/compose/choose_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/app_fixture.dart';
import '../../support/coordinator_fixture.dart';

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  for (final reopenedFromLibrary in [false, true]) {
    testWidgets(
      'completed retry ${reopenedFromLibrary ? 'reopened from Library' : 'opened from Results'} leaves one Results and one Back reaches Library',
      (tester) async {
        final h = (await tester.runAsync(
          () => coordinatorHarness(
            selected: {Destination.x, Destination.bluesky},
            bluesky: [PublishStatus.notPublished, PublishStatus.published],
          ),
        ))!;
        addTearDown(h.close);
        final groupId = (await tester.runAsync(
          () => h.coordinator.confirm(h.review, operationId: 'original'),
        ))!;
        final services = _AcceptedPublishingServices(h);
        if (reopenedFromLibrary) {
          await tester.runAsync(() async {
            final parent = (await h.attempts.effectiveAttempts(groupId)).last;
            await services.retryEdits.open(parent.id);
          });
        }
        await tester.pumpWidget(
          CaptionApp(home: LibraryScreen(services: services)),
        );
        await settleStorage(tester);
        if (reopenedFromLibrary) {
          await tester.tap(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.text('Frozen caption'),
            ),
          );
        } else {
          await tester.tap(find.text('Review posting results'));
          await settleStorage(tester);
          await tester.ensureVisible(find.text('Retry Bluesky'));
          await tester.tap(find.text('Retry Bluesky'));
        }
        await settleEditorUntil(tester, () {
          final action = find.widgetWithText(
            FilledButton,
            'Publish to Bluesky',
          );
          return action.evaluate().isNotEmpty &&
              tester.widget<FilledButton>(action).onPressed != null;
        });
        await tester.tap(
          find.widgetWithText(FilledButton, 'Publish to Bluesky'),
        );
        await settleEditorUntil(
          tester,
          () => find.text('Bluesky · Published').evaluate().isNotEmpty,
        );
        expect(find.byType(ResultsScreen, skipOffstage: false), findsOneWidget);
        expect(find.text('Retry Bluesky'), findsNothing);
        expect(h.x.sent, hasLength(1));
        expect(h.bluesky.sent, hasLength(2));
        await tester.ensureVisible(find.byTooltip('Back to library'));
        await tester.tap(find.byTooltip('Back to library'));
        await settleStorage(tester);
        expect(find.byType(LibraryScreen), findsOneWidget);
        expect(find.byType(ResultsScreen, skipOffstage: false), findsNothing);
        expect(find.text('Needs your attention'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'result lookup failure keeps the draft route closed and offers local recovery',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      final draft = Draft(
        id: 'route-read-failure',
        updatedAt: services.clock.now(),
        shared: PostContent(text: 'Retained route words'),
      );
      await tester.runAsync(
        () => services.drafts.save(draft, expectedRevision: -1),
      );
      await tester.pumpWidget(
        CaptionApp(home: LibraryScreen(services: services)),
      );
      await settleStorage(tester);
      await tester.runAsync(services.database.close);
      await tester.tap(find.text('Retained route words'));
      await settleStorage(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'This action could not finish. Keep this library open and retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Where should this go?'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('draft creation requires no account and no selected default', (
    tester,
  ) async {
    final services = (await tester.runAsync(localTestServices))!;
    addTearDown(services.close);
    await tester.pumpWidget(
      CaptionApp(home: LibraryScreen(services: services)),
    );
    await settleStorage(tester);
    await tester.tap(find.text('New post'));
    await settleStorage(tester);
    expect(find.text('Where should this go?'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
    final saved = await tester.runAsync(services.drafts.list);
    expect(saved, hasLength(1));
    expect(saved!.single.selected, isEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('choose-instagram')));
    await tester.tap(find.byKey(const ValueKey('choose-instagram')));
    await settleStorage(tester);
    expect(continueButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Continue to writing'));
    await settleStorage(tester);
    expect(find.widgetWithText(TextField, 'Shared caption'), findsOneWidget);
    expect(find.text('Review post'), findsOneWidget);
    final writing = await tester.runAsync(services.drafts.list);
    expect(writing!.single.stage, ComposeStage.write);
    expect(writing.single.selected, {Destination.instagram});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty library exposes results without invented counts', (
    tester,
  ) async {
    final services = (await tester.runAsync(localTestServices))!;
    addTearDown(services.close);
    await tester.pumpWidget(
      CaptionApp(home: LibraryScreen(services: services)),
    );
    await settleStorage(tester);
    expect(find.text('Your next post starts here.'), findsOneWidget);
    expect(
      find.text(
        "Posting to X and Bluesky isn't available in this build. You finish Instagram posts in Instagram.",
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'New post'), findsOneWidget);
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('No posting results yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reopen resumes durable stage and Delete Undo retains the draft',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      final draft = Draft(
        id: 'resume',
        updatedAt: DateTime.utc(2026, 11, 16),
        stage: ComposeStage.review,
        selected: {Destination.bluesky},
        shared: PostContent(text: 'Kept locally'),
      );
      await tester.runAsync(
        () => services.drafts.save(draft, expectedRevision: -1),
      );
      await tester.pumpWidget(
        CaptionApp(home: LibraryScreen(services: services)),
      );
      await settleStorage(tester);
      expect(find.textContaining('Bluesky · Review'), findsOneWidget);
      await tester.tap(find.text('Kept locally'));
      await settleStorage(tester);
      expect(find.text('Publish now'), findsOneWidget);
      // The footer names the first destination that blocks publishing.
      expect(find.textContaining(RegExp(r'^(X|Bluesky) · ')), findsOneWidget);
      // Back steps through the stages: Review → Write → Choose → library.
      for (final back in ['Back to Write', 'Back to Choose', 'Back']) {
        await tester.tap(find.byTooltip(back));
        await settleStorage(tester);
      }
      await tester.tap(find.byTooltip('Delete draft'));
      await settleStorage(tester);
      expect(find.text('Kept locally'), findsNothing);
      final deleted = await tester.runAsync(
        () => services.drafts.get('resume'),
      );
      expect(deleted!.deletedAt, isNotNull);
      await tester.tap(find.text('Undo'));
      await settleStorage(tester);
      expect(find.text('Kept locally'), findsOneWidget);
      final restored = await tester.runAsync(
        () => services.drafts.get('resume'),
      );
      expect(restored!.shared.text, 'Kept locally');
      expect(restored.deletedAt, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('load failure shows Retry and leaves corrupt saved data intact', (
    tester,
  ) async {
    final services = (await tester.runAsync(localTestServices))!;
    addTearDown(services.close);
    await tester.runAsync(
      () => services.database.db.insert('drafts', {
        'id': 'corrupt',
        'revision': 0,
        'updated_at': 'invalid',
        'payload': '{broken',
      }),
    );
    await tester.pumpWidget(
      CaptionApp(home: LibraryScreen(services: services)),
    );
    await settleStorage(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('New post'), findsNothing);
    await tester.tap(find.text('Retry'));
    await settleStorage(tester);
    final rows = await tester.runAsync(
      () => services.database.db.query('drafts'),
    );
    expect(rows!.single['payload'], '{broken');
    expect(find.textContaining('cannot be read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loading persists until the library query actually completes', (
    tester,
  ) async {
    final base = (await tester.runAsync(localTestServices))!;
    addTearDown(base.close);
    final pending = Completer<List<Draft>>();
    final services = withDrafts(
      base,
      _DelayedDrafts(base.drafts, pending.future),
    );
    await tester.pumpWidget(
      CaptionApp(home: LibraryScreen(services: services)),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Loading drafts…'), findsOneWidget);
    expect(find.text('New post'), findsNothing);
    pending.complete([]);
    await settleStorage(tester);
    expect(find.text('New post'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed save blocks Continue and Back and preserves text for retry',
    (tester) async {
      final base = (await tester.runAsync(localTestServices))!;
      addTearDown(base.close);
      final draft = Draft(
        id: 'blocked',
        updatedAt: DateTime.utc(2026),
        selected: {Destination.x},
        shared: PostContent(text: 'Keep my words'),
      );
      await tester.runAsync(
        () => base.drafts.save(draft, expectedRevision: -1),
      );
      final failing = _FailingDrafts(base.drafts);
      final controller = DraftController(draft, failing, base.clock);
      addTearDown(controller.dispose);
      var continued = false;
      await tester.pumpWidget(
        CaptionApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChooseScreen(
                    controller: controller,
                    accounts: base.accounts,
                    onContinue: () => continued = true,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settleStorage(tester);
      controller.change(
        editSharedCaption(
          controller.draft,
          'Keep these newer words',
          base.clock.now(),
        ),
      );
      await tester.tap(find.text('Continue to writing'));
      await settleStorage(tester);
      expect(continued, isFalse);
      expect(
        find.text("Couldn't save — keep this screen open"),
        findsOneWidget,
      );
      expect(find.text('Keep these newer words'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await settleStorage(tester);
      expect(find.text('Where should this go?'), findsOneWidget);
      expect(find.text('Copy text'), findsOneWidget);
      failing.fail = false;
      await tester.tap(find.text('Retry saving'));
      await settleStorage(tester);
      expect(find.text("Couldn't save — keep this screen open"), findsNothing);
      final stored = await tester.runAsync(() => base.drafts.get('blocked'));
      expect(stored!.shared.text, 'Keep these newer words');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'accounts never fabricate connection and preference requires confirmation',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      final draft = Draft(
        id: 'prefs',
        updatedAt: DateTime.utc(2026),
        selected: {Destination.instagram},
      );
      await tester.runAsync(
        () => services.drafts.save(draft, expectedRevision: -1),
      );
      final controller = DraftController(
        draft,
        services.drafts,
        services.clock,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: ChooseScreen(
            controller: controller,
            accounts: services.accounts,
            onContinue: () {},
          ),
        ),
      );
      await settleStorage(tester);
      await tester.ensureVisible(find.text('Manage accounts'));
      await tester.tap(find.text('Manage accounts'));
      await settleStorage(tester);
      await tester.tap(find.text("Why isn't X available?"));
      await tester.pumpAndSettle();
      final xAccount = (await tester.runAsync(
        () => services.accounts.get(Destination.x),
      ))!;
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(xAccount.capability),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep drafting'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(controller.draft.selected, {Destination.instagram});
      await tester.tap(find.text('Keep enabled'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(services.accounts.instagramAssistedSharing),
        isTrue,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn off'));
      await settleStorage(tester);
      expect(
        await tester.runAsync(services.accounts.instagramAssistedSharing),
        isFalse,
      );
      expect(controller.draft.selected, isEmpty);
      expect(
        (await tester.runAsync(services.accounts.list))!.every(
          (v) => v.identity == null && v.state != AccountState.connected,
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Choose reflows at 320dp and 200 percent with reachable action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = (await tester.runAsync(localTestServices))!;
    addTearDown(services.close);
    final controller = DraftController(
      Draft(id: 'large', updatedAt: services.clock.now()),
      services.drafts,
      services.clock,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ChooseScreen(
            controller: controller,
            accounts: services.accounts,
            onContinue: () {},
          ),
        ),
      ),
    );
    await settleStorage(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('choose-instagram')));
    await tester.tap(find.byKey(const ValueKey('choose-instagram')));
    await settleStorage(tester);
    expect(continueButton(tester).onPressed, isNotNull);
    expect(find.text('Continue to writing').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'account codecs preserve identity and preferences survive storage reopen',
    () async {
      final services = await localTestServices();
      addTearDown(services.close);
      const view = AccountView(
        destination: Destination.bluesky,
        state: AccountState.connected,
        capability: 'Publishes from this app.',
        identity: AccountIdentity(
          destination: Destination.bluesky,
          subject: 'did:plc:synthetic',
          handle: 'synthetic.test',
        ),
      );
      expect(AccountView.fromJson(view.toJson()), view);
      await services.accounts.setInstagramAssistedSharing(false);
      final path = services.database.db.path;
      await services.database.close();
      final reopened = await LocalDatabase.open(
        databaseFactoryFfiNoIsolate,
        path,
      );
      addTearDown(reopened.close);
      expect(
        await LocalAccountRepository(reopened).instagramAssistedSharing(),
        isFalse,
      );
    },
  );

  test(
    'bootstrap recovery barrier retains interrupted original operation',
    () async {
      final services = await localTestServices();
      addTearDown(services.close);
      final pending = await services.pickerImports.begin(
        draftId: 'original',
        draftRevision: 7,
        destination: Destination.bluesky,
      );
      final response = Completer<LostDataResponse>();
      final recovery = services.recoverPicker(_TestPicker(response.future));
      expect(services.pickerRecoveryReady, isFalse);
      response.complete(LostDataResponse.empty());
      await recovery;
      expect(services.pickerRecoveryReady, isFalse);
      expect(services.pickerRecoveryError, isNotNull);
      expect(services.recoveredPicker!.draftId, 'original');
      expect(services.recoveredPicker!.destination, Destination.bluesky);
      await services.discardRecovered(pending);
      expect(services.pickerRecoveryReady, isTrue);
      expect(await services.pickerImports.unresolved(), isNull);
    },
  );

  test('recovered media attaches only to original destination and acknowledges after save', () async {
    final services = await localTestServices();
    addTearDown(services.close);
    await services.drafts.save(
      Draft(
        id: 'original',
        updatedAt: services.clock.now(),
        selected: {Destination.bluesky},
      ),
      expectedRevision: -1,
    );
    await services.drafts.save(
      Draft(id: 'other', updatedAt: services.clock.now()),
      expectedRevision: -1,
    );
    final pending = await services.pickerImports.begin(
      draftId: 'original',
      draftRevision: 0,
      destination: Destination.bluesky,
    );
    final operation = await services.pickerImports.complete(pending.id, [
      await photo(services),
    ]);
    expect((await services.drafts.get('original'))!.versions, isEmpty);
    await services.attachRecovered(operation);
    final draft = (await services.drafts.get('original'))!;
    expect(draft.shared.media, isEmpty);
    expect(
      draft.versions[Destination.bluesky]!.ownMedia!.single.assetId,
      operation.assets.single.id,
    );
    expect((await services.drafts.get('other'))!.shared.media, isEmpty);
    expect(await services.pickerImports.unresolved(), isNull);
  });

  test('changed original draft refuses recovered attachment without losing operation', () async {
    final services = await localTestServices();
    addTearDown(services.close);
    final draft = Draft(id: 'original', updatedAt: services.clock.now());
    await services.drafts.save(draft, expectedRevision: -1);
    final pending = await services.pickerImports.begin(
      draftId: draft.id,
      draftRevision: 0,
    );
    final operation = await services.pickerImports.complete(pending.id, [
      await photo(services),
    ]);
    await services.drafts.save(
      editSharedCaption(draft, 'Changed after picker', services.clock.now()),
      expectedRevision: 0,
    );
    await expectLater(services.attachRecovered(operation), throwsStateError);
    expect((await services.drafts.get(draft.id))!.shared.media, isEmpty);
    expect((await services.pickerImports.unresolved())!.id, operation.id);
  });

  test(
    'recovered save failure keeps journal unresolved and prior draft intact',
    () async {
      final services = await localTestServices();
      addTearDown(services.close);
      await services.drafts.save(
        Draft(id: 'original', updatedAt: services.clock.now()),
        expectedRevision: -1,
      );
      final pending = await services.pickerImports.begin(
        draftId: 'original',
        draftRevision: 0,
      );
      final operation = await services.pickerImports.complete(pending.id, [
        await photo(services),
      ]);
      final failing = withDrafts(services, _FailingDrafts(services.drafts));
      await expectLater(
        failing.attachRecovered(operation),
        throwsA(isA<LocalStorageException>()),
      );
      expect((await services.drafts.get('original'))!.shared.media, isEmpty);
      expect((await services.pickerImports.unresolved())!.id, operation.id);
    },
  );

  test('save-before-ack reopen recognizes operation assets without duplicate attachment', () async {
    final services = await localTestServices();
    addTearDown(services.close);
    final draft = Draft(id: 'original', updatedAt: services.clock.now());
    await services.drafts.save(draft, expectedRevision: -1);
    final pending = await services.pickerImports.begin(
      draftId: draft.id,
      draftRevision: 0,
    );
    final operation = await services.pickerImports.complete(pending.id, [
      await photo(services),
    ]);
    await services.drafts.save(
      editSharedMedia(draft, [
        Attachment(assetId: operation.assets.single.id),
      ], services.clock.now()),
      expectedRevision: 0,
    );
    final path = services.database.db.path;
    await services.database.close();
    final reopened = await LocalDatabase.open(
      databaseFactoryFfiNoIsolate,
      path,
    );
    addTearDown(reopened.close);
    final media = MediaFiles(reopened, services.media.root, services.ids);
    final recovered = AppServices(
      instagramPackageRoot: services.instagramPackageRoot,
      database: reopened,
      media: media,
      drafts: SqliteDraftRepository(reopened, media: media),
      accounts: LocalAccountRepository(reopened),
      clock: services.clock,
      ids: services.ids,
    );
    // MediaFiles also owns the old DB, so reconstruct it against the same owned root.
    await expectLater(recovered.attachRecovered(operation), completes);
    expect(
      (await recovered.drafts.get('original'))!.shared.media,
      hasLength(1),
    );
    expect((await recovered.drafts.get('original'))!.revision, 1);
    expect(await recovered.pickerImports.unresolved(), isNull);
  });
  testWidgets(
    'failed-save recovery stays scrollable with long text at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      final draft = Draft(
        id: 'long-failure',
        updatedAt: services.clock.now(),
        selected: {Destination.x},
      );
      final controller = DraftController(
        draft,
        _FailingDrafts(services.drafts),
        services.clock,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ChooseScreen(
              controller: controller,
              accounts: services.accounts,
              onContinue: () {},
            ),
          ),
        ),
      );
      await settleStorage(tester);
      controller.change(
        editSharedCaption(
          draft,
          List.filled(80, 'Keep these words.').join(' '),
          services.clock.now(),
        ),
      );
      await tester.runAsync(controller.flush);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Copy text'));
      expect(find.text('Copy text').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('background lifecycle flush saves before the debounce timer', (
    tester,
  ) async {
    final services = (await tester.runAsync(localTestServices))!;
    addTearDown(services.close);
    final draft = Draft(id: 'background', updatedAt: services.clock.now());
    final controller = DraftController(draft, services.drafts, services.clock);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CaptionApp(
        home: ChooseScreen(
          controller: controller,
          accounts: services.accounts,
          onContinue: () {},
        ),
      ),
    );
    await settleStorage(tester);
    controller.change(
      editSharedCaption(
        controller.draft,
        'Save on background',
        services.clock.now(),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final saved = await tester.runAsync(
      () => services.drafts.get('background'),
    );
    expect(saved!.shared.text, 'Save on background');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('discarded recovered selection cannot later attach through a stale confirmation', () async {
    final services = await localTestServices();
    addTearDown(services.close);
    await services.drafts.save(
      Draft(id: 'original', updatedAt: services.clock.now()),
      expectedRevision: -1,
    );
    final pending = await services.pickerImports.begin(
      draftId: 'original',
      draftRevision: 0,
    );
    final operation = await services.pickerImports.complete(pending.id, [
      await photo(services),
    ]);
    await services.discardRecovered(operation);
    await expectLater(services.attachRecovered(operation), throwsStateError);
    expect((await services.drafts.get('original'))!.shared.media, isEmpty);
  });

  testWidgets(
    'recovered selection waits for explicit original-target confirmation',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      await tester.runAsync(() async {
        await services.drafts.save(
          Draft(id: 'original', updatedAt: services.clock.now()),
          expectedRevision: -1,
        );
        await services.pickerImports.begin(
          draftId: 'original',
          draftRevision: 0,
          destination: Destination.bluesky,
        );
        await services.recoverPicker(
          _TestPicker(
            Future.value(LostDataResponse(files: [await photo(services)])),
          ),
        );
      });
      expect(services.pickerRecoveryReady, isTrue);
      await tester.pumpWidget(
        CaptionApp(home: LibraryScreen(services: services)),
      );
      await settleStorage(tester);
      expect(
        find.textContaining('Original draft: original · Bluesky'),
        findsOneWidget,
      );
      expect(
        (await tester.runAsync(() => services.drafts.get('original')))!
            .versions,
        isEmpty,
      );
      await tester.tap(find.text('Review recovered selection'));
      await tester.pumpAndSettle();
      expect(find.text('Attach to original draft'), findsOneWidget);
      expect(
        (await tester.runAsync(() => services.drafts.get('original')))!
            .versions,
        isEmpty,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Attach to original draft'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settleStorage(tester);
      final draft = await tester.runAsync(
        () => services.drafts.get('original'),
      );
      expect(
        draft!.versions.keys,
        contains(Destination.bluesky),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? w.textSpan?.toPlainText())
            .join('\n'),
      );
      expect(draft.versions[Destination.bluesky]!.ownMedia, hasLength(1));
      expect(await tester.runAsync(services.pickerImports.unresolved), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'library refresh discovers a newly interrupted picker operation',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      await tester.runAsync(
        () => services.pickerImports.begin(
          draftId: 'original-picker-draft',
          draftRevision: 3,
          destination: Destination.x,
        ),
      );
      expect(services.recoveredPicker, isNull);
      await tester.pumpWidget(
        CaptionApp(home: LibraryScreen(services: services)),
      );
      await settleStorage(tester);
      expect(
        find.textContaining('Original draft: original-picker-draft · X'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'refresh alone never clears a failed bootstrap recovery barrier',
    () async {
      final services = await localTestServices();
      addTearDown(services.close);
      await services.recoverPicker(_FailedPicker());
      await services.refreshPicker();
      expect(services.pickerRecoveryReady, isFalse);
      expect(services.pickerRecoveryError, isNotNull);
    },
  );
  testWidgets(
    'delayed Back blocks competing Accounts navigation until its save completes',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      final draft = Draft(
        id: 'back-account-guard',
        updatedAt: services.clock.now(),
        selected: {Destination.x},
      );
      await tester.runAsync(
        () => services.drafts.save(draft, expectedRevision: -1),
      );
      final delayed = _ControlledSaves(services.drafts);
      final controller = DraftController(draft, delayed, services.clock);
      try {
        await showChooseRoute(tester, services, controller);
        controller.change(
          editSharedCaption(
            controller.draft,
            'Wait for this save',
            services.clock.now(),
          ),
        );
        await tester.tap(find.byTooltip('Back'));
        await settleStorage(tester);
        expect(delayed.started.isCompleted, isTrue);
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Manage accounts'),
              )
              .onPressed,
          isNull,
        );
        expect(continueButton(tester).onPressed, isNull);
        delayed.release.complete();
        await settleStorage(tester);
        expect(find.text('Open draft'), findsOneWidget);
        expect(find.text('Accounts'), findsNothing);
        expect(
          (await tester.runAsync(() => services.drafts.get(draft.id)))!
              .shared
              .text,
          'Wait for this save',
        );
      } finally {
        if (!delayed.release.isCompleted) delayed.release.complete();
        await settleStorage(tester);
        await settleStorage(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('Back cannot abandon a pending Continue stage save', (
    tester,
  ) async {
    final services = (await tester.runAsync(localTestServices))!;
    addTearDown(services.close);
    final draft = Draft(
      id: 'continue-back-guard',
      updatedAt: services.clock.now(),
      selected: {Destination.x},
    );
    await tester.runAsync(
      () => services.drafts.save(draft, expectedRevision: -1),
    );
    final delayed = _ControlledSaves(services.drafts);
    final controller = DraftController(draft, delayed, services.clock);
    try {
      await showChooseRoute(tester, services, controller);
      await tester.tap(find.text('Continue to writing'));
      await settleStorage(tester);
      expect(delayed.started.isCompleted, isTrue);
      await tester.binding.handlePopRoute();
      await settleStorage(tester);
      delayed.release.complete();
      await settleStorage(tester);
      expect(find.text('Where should this go?'), findsOneWidget);
      expect(controller.draft.stage, ComposeStage.write);
    } finally {
      if (!delayed.release.isCompleted) delayed.release.complete();
      await settleStorage(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'covered delayed Back stays guarded after Accounts return and a failed edit',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      final draft = Draft(
        id: 'cancelled-back',
        updatedAt: services.clock.now(),
        selected: {Destination.x},
      );
      await tester.runAsync(
        () => services.drafts.save(draft, expectedRevision: -1),
      );
      final delayed = _ControlledSaves(services.drafts);
      final controller = DraftController(draft, delayed, services.clock);
      try {
        await showChooseRoute(tester, services, controller);
        final navigator = Navigator.of(
          tester.element(find.text('Where should this go?')),
        );
        controller.change(
          editSharedCaption(
            controller.draft,
            'Saved before Accounts',
            services.clock.now(),
          ),
        );
        await tester.tap(find.byTooltip('Back'));
        await settleStorage(tester);
        expect(delayed.started.isCompleted, isTrue);
        // A route already queued by a platform callback can still cover Choose.
        // Its cancelled Back must never leave permission for the next edit to pop.
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => DraftSession(
                controller: controller,
                child: AccountsScreen(
                  accounts: services.accounts,
                  controller: controller,
                ),
              ),
            ),
          ),
        );
        await settleStorage(tester);
        delayed.release.complete();
        await settleStorage(tester);
        expect(find.text('Accounts'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await settleStorage(tester);
        expect(find.text('Where should this go?'), findsOneWidget);
        delayed.fail = true;
        controller.change(
          setDestination(
            controller.draft,
            Destination.bluesky,
            true,
            services.clock.now(),
          ),
        );
        await tester.tap(find.byTooltip('Back'));
        await settleStorage(tester);
        expect(find.text('Where should this go?'), findsOneWidget);
        expect(
          find.text("Couldn't save — keep this screen open"),
          findsOneWidget,
        );
        expect(
          (await tester.runAsync(() => services.drafts.get(draft.id)))!
              .selected,
          {Destination.x},
        );
      } finally {
        if (!delayed.release.isCompleted) delayed.release.complete();
        await settleStorage(tester);
        await settleStorage(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'delayed recovery save blocks contradictory discard and retry commands',
    (tester) async {
      final base = (await tester.runAsync(localTestServices))!;
      addTearDown(base.close);
      await tester.runAsync(
        () => base.drafts.save(
          Draft(id: 'recover-guard', updatedAt: base.clock.now()),
          expectedRevision: -1,
        ),
      );
      final operation = (await tester.runAsync(() async {
        final pending = await base.pickerImports.begin(
          draftId: 'recover-guard',
          draftRevision: 0,
        );
        return base.pickerImports.complete(pending.id, [await photo(base)]);
      }))!;
      final delayed = _ControlledSaves(base.drafts);
      final services = withDrafts(base, delayed);
      await tester.runAsync(() => services.recoverPicker(_FailedPicker()));
      try {
        await tester.pumpWidget(
          CaptionApp(home: LibraryScreen(services: services)),
        );
        await settleStorage(tester);
        final staleDiscard = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Discard recovered selection'),
            )
            .onPressed!;
        final staleRetry = tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry media recovery'),
            )
            .onPressed!;
        await tester.tap(find.text('Review recovered selection'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Attach to original draft'));
        await settleStorage(tester);
        expect(delayed.started.isCompleted, isTrue);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  'Review recovered selection',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Discard recovered selection'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Retry media recovery'),
              )
              .onPressed,
          isNull,
        );
        // A previously captured callback models a rapid action queued before repaint.
        staleDiscard();
        staleRetry();
        await settleStorage(tester);
        expect(find.text('Discard this selection?'), findsNothing);
        expect(
          (await tester.runAsync(services.pickerImports.unresolved))!.id,
          operation.id,
        );
        expect(
          (await tester.runAsync(() => services.drafts.get('recover-guard')))!
              .shared
              .media,
          isEmpty,
        );
        delayed.release.complete();
        await settleStorage(tester);
        expect(
          await tester.runAsync(services.pickerImports.unresolved),
          isNull,
        );
        expect(
          (await tester.runAsync(() => services.drafts.get('recover-guard')))!
              .shared
              .media
              .single
              .assetId,
          operation.assets.single.id,
        );
      } finally {
        if (!delayed.release.isCompleted) delayed.release.complete();
        await settleStorage(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}

FilledButton continueButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Continue to writing'),
);
Future<void> settleStorage(WidgetTester tester) async {
  // Native filesystem callbacks and sqflite lock continuations alternate with
  // Flutter's fake frame clock. Yield both rather than mocking private storage.
  for (var step = 0; step < 20; step++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  await tester.pumpAndSettle();
}

AppServices withDrafts(AppServices base, DraftRepository drafts) => AppServices(
  instagramPackageRoot: base.instagramPackageRoot,
  database: base.database,
  media: base.media,
  drafts: drafts,
  accounts: base.accounts,
  clock: base.clock,
  ids: base.ids,
);
Future<XFile> photo(AppServices services) async {
  final source = File(
    '${File(services.database.db.path).parent.path}/source.png',
  );
  await source.writeAsBytes(img.encodePng(img.Image(width: 8, height: 8)));
  return XFile(source.path);
}

class _TestPicker extends ImagePicker {
  _TestPicker(this.response);
  final Future<LostDataResponse> response;
  @override
  Future<LostDataResponse> retrieveLostData() => response;
}

class _DelayedDrafts implements DraftRepository {
  _DelayedDrafts(this.delegate, this.pending);
  final DraftRepository delegate;
  final Future<List<Draft>> pending;
  @override
  Future<List<Draft>> list() => pending;
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) =>
      delegate.save(draft, expectedRevision: expectedRevision);
  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
}

class _FailingDrafts implements DraftRepository {
  _FailingDrafts(this.delegate);
  final DraftRepository delegate;
  bool fail = true;
  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async {
    if (fail) throw const LocalStorageException('Storage unavailable');
    await delegate.save(draft, expectedRevision: expectedRevision);
  }

  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
}

class _FailedPicker extends ImagePicker {
  @override
  Future<LostDataResponse> retrieveLostData() async {
    throw StateError('Recovery unavailable');
  }
}

Future<void> showChooseRoute(
  WidgetTester tester,
  AppServices services,
  DraftController controller,
) async {
  await tester.pumpWidget(
    CaptionApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ChooseScreen(
                controller: controller,
                accounts: services.accounts,
                onContinue: () {},
              ),
            ),
          ),
          child: const Text('Open draft'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open draft'));
  await settleStorage(tester);
}

class _ControlledSaves implements DraftRepository {
  _ControlledSaves(this.delegate);
  final DraftRepository delegate;
  final started = Completer<void>();
  final release = Completer<void>();
  bool fail = false;
  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    if (fail) throw const LocalStorageException('Storage unavailable');
    await delegate.save(draft, expectedRevision: expectedRevision);
  }

  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
}

// Real host/repositories/coordinator; only external publishers and accepted
// capability validation come from the existing synthetic coordinator fixture.
class _AcceptedPublishingServices extends AppServices {
  _AcceptedPublishingServices(this.harness)
    : super(
        database: harness.app.database,
        media: harness.app.media,
        drafts: harness.app.drafts,
        accounts: harness.app.accounts,
        clock: harness.clock,
        ids: harness.app.ids,
        instagramPackageRoot: harness.app.instagramPackageRoot,
        publishProviders: {
          Destination.x: harness.x,
          Destination.bluesky: harness.bluesky,
        },
        publishingOnline: () => harness.online,
      );
  final CoordinatorHarness harness;
  @override
  ReviewService get review => harness.reviewService;
}
