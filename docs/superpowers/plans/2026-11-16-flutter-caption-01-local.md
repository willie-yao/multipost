# Flutter Caption Local Drafting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a working offline Caption application for creating, recovering, customizing and reviewing posts without connecting accounts.

**Architecture:** Immutable Dart content models feed feature controllers and native Flutter fields. A transactional SQLite store owns revisions; immutable private files preserve selected media independently of picker access. The app has no publishing transport in this milestone.

**Tech Stack:** Flutter/Dart, Material 3, ChangeNotifier, freezed/json_serializable for immutable models and codecs, sqflite, path_provider, image_picker, image, crypto, uuid; sqflite_common_ffi and flutter_test for tests.

**Spec:** `PRODUCT.md`; `docs/design/design-review.md` sections 1–3, 6, 8; `docs/design/options-dark/README.md`; Caption v2 composer and `caption-flow-board.png`/`caption-library-board.png`; parent `2026-11-16-flutter-caption-mvp.md` for source precedence, complete constraints, file map and gates.

## Global Constraints

- "Text and media inheritance are independent."
- "Published snapshots remain immutable."
- "Each screen has one white action."
- "Cyan always marks a destination's own caption."
- "No automatic resend occurs on app launch or network return."
- "48 × 48dp minimum touch targets, at least 4.5:1 normal-text contrast and 3:1 meaningful component boundaries."
- "Test system text enlargement through 200% without truncating actions or instructions; layouts grow and scroll rather than shrink type."
- Parent global constraints apply in full. Planning only until explicit execution authorization; no live account calls in this milestone.

---

## File ownership and commands

Create the `app/` subtree only at execution time. Models live next to their feature, not in a generic shared DTO directory. Generated `*.freezed.dart` and `*.g.dart` files belong to their corresponding model task; generate and commit them consistently with the lockfile. Do not copy sample photos into production assets. Test-only sample fixtures must retain provenance.

All `flutter`/`dart` commands below run in `app/`. Commit commands use `git -C ..` from that directory and explicitly list only owned files. Every task includes a red/green cycle; large device checks are independently logged rather than called unit-test coverage.

### Task L1: Bootstrap a reproducible Android shell and Caption components

**Files:** Create `app/pubspec.yaml`, `app/pubspec.lock`, `app/analysis_options.yaml`, `app/.gitignore`, generated Android scaffold, `app/lib/main.dart`, `app/lib/app/app.dart`, `app/lib/design/{caption_tokens,caption_theme,caption_scaffold,caption_text}.dart`, `app/assets/fonts/{AtkinsonHyperlegibleNext.ttf,AtkinsonHyperlegibleNext-OFL.txt}`, `app/test/design/caption_scaffold_test.dart`, `docs/engineering/toolchain.md`. Copy the font/license from `docs/design/options-dark/assets/`.

**Interfaces:** Produces `CaptionApp({required Widget home})`, `CaptionScaffold({required String title, required Widget body, Widget? primaryAction, Widget? stageIndicator, List<Widget> actions = const []})`, `CaptionText(String text, {bool own = false})`, `CaptionTokens`, `ThemeData captionTheme()`. These are presentation-only; the shell sends nothing.

- [ ] **Step 1: Resolve readiness and record the actual toolchain.** Check authorization, Git baseline and Android floor per the parent. Inspect `flutter --version --machine`, `flutter doctor -v`, and `flutter devices`; install/configure the SDK only within execution authorization. Record versions and unresolved device prerequisites in `toolchain.md`. A missing device does not count as a passed Android test.
- [ ] **Step 2: Generate only the nested project.** From repository root run `flutter create --platforms=android --org org.example --project-name cross_posting_app app`. Change the Android applicationId/namespace and Kotlin directory consistently to the working `org.example.crossposting`. Set proposed minSdk 29 only after the floor gate. Remove the generated counter example/test. In `app/`, add `freezed_annotation`, `json_annotation`, `sqflite`, `path_provider`, `path`, `image_picker`, `image`, `crypto`, `uuid`, and `characters`; add dev dependencies `build_runner`, `freezed`, `json_serializable`, `sqflite_common_ffi`. Pin the resolved lockfile and record the Flutter SDK; do not pin unverified versions from examples.
- [ ] **Step 3: Write and run the first failing component test.**

```dart
testWidgets('large text leaves the next action reachable', (tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(CaptionApp(home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2)),
    child: CaptionScaffold(
      title: 'Your posts',
      body: const Text('Drafts are saved on this device.'),
      primaryAction: FilledButton(onPressed: () {}, child: const Text('Create a draft')),
    ),
  )));
  expect(tester.takeException(), isNull);
  expect(find.text('Create a draft').hitTestable(), findsOneWidget);
});
```

Run `flutter test test/design/caption_scaffold_test.dart`. Expected first failure: missing Caption components, not a missing Flutter SDK. Test imports are Flutter material/flutter_test and the component files named above; each test file wraps tests in `void main()`.

- [ ] **Step 4: Add tokens and the real inset-aware scaffold.**

```dart
abstract final class CaptionTokens {
  static const stage = Color(0xFF000000);
  static const ground = Color(0xFF131517);
  static const raised = Color(0xFF1D2023);
  static const raised2 = Color(0xFF2A2E32);
  static const text = Color(0xFFF2F2EE);
  static const secondary = Color(0xFFB6BBC0);
  static const own = Color(0xFF7DD7E9);
  static const hairline = Color(0xFF2C3034);
  static const boundary = Color(0xFF6A7179);
  static const success = Color(0xFF8CD9A4);
  static const error = Color(0xFFFF9F9F);
  static const warning = Color(0xFFF0CF72);
  static const onAction = Color(0xFF0B0C0D);
}
```

Use a dark Material 3 ColorScheme mapped to those roles; disable dynamic color. Bundle the variable font under the family `Atkinson Hyperlegible Next`. Set 26sp/800 titles, 21sp/600 caption fields, 16sp body, minimum 14sp supporting text, 17sp/700 button text. Scaffold body is scrollable and expands with content; bottom action is in SafeArea with minimum height 52, never a fixed 52 at large text. Set `resizeToAvoidBottomInset: true`; let Android draw system chrome. Use the actual stage tab labels and semantics. CaptionText uses a black text background on a single text span and normal wrapping; do not split words into unsemantic boxes. Initial main can show a noninteractive Caption title while bootstrapping; it must not have fake connected accounts or send controls.
- [ ] **Step 5: Run `flutter test test/design/caption_scaffold_test.dart` and `flutter analyze`.** Expected pass and zero overflow at 320dp/200%. Inspect a device/emulator frame at 390dp and 320dp; this checks native composition, not exact pixels of browser-rendered mockups.
- [ ] **Step 6: Commit only the new scaffold, font assets, design components and test.** Use explicit paths from this task; `git -C .. commit -m "feat: establish Caption Android shell"`. Never include the untracked design tree opportunistically.

### Task L2: Model drafts and independent platform versions

**Files:** Create `app/lib/core/{clock,ids}.dart`, `app/lib/features/drafts/{draft,draft_editor}.dart`, generated draft codec files, `app/test/features/drafts/draft_editor_test.dart`, `app/test/support/draft_fixtures.dart`.

**Interfaces:** Produces enums `Destination { x, bluesky, instagram }`, `ComposeStage { choose, write, review }`; immutable models below; `PostContent resolveContent(Draft, Destination)`; pure edit functions `editSharedCaption`, `editOwnCaption`, `restoreSharedCaption`, `editSharedMedia`, `editOwnMedia`, `restoreSharedMedia`, `setDestination`, `setStage`. Each edit accepts `DateTime now`, returns a new Draft, increments `revision`, and never mutates its argument. `Clock.now()` returns UTC; `Ids.next()` returns UUID v4.

- [ ] **Step 1: Write the inheritance test before defining the models.**

```dart
test('own caption survives shared edits; its media still inherits', () {
  var d = sampleDraft();
  d = editOwnCaption(d, Destination.bluesky, 'My own words', DateTime.utc(2026));
  d = editSharedCaption(d, 'Changed shared words', DateTime.utc(2026, 1, 2));
  d = editSharedMedia(d, const [Attachment(assetId: 'photo-2')], DateTime.utc(2026, 1, 3));
  expect(resolveContent(d, Destination.bluesky).text, 'My own words');
  expect(resolveContent(d, Destination.bluesky).media.single.assetId, 'photo-2');
  expect(resolveContent(d, Destination.x).text, 'Changed shared words');
  d = setDestination(d, Destination.bluesky, false, DateTime.utc(2026, 1, 4));
  d = setDestination(d, Destination.bluesky, true, DateTime.utc(2026, 1, 5));
  expect(resolveContent(d, Destination.bluesky).text, 'My own words');
  expect(Draft.fromJson(d.toJson()), d);
});
```

Run `flutter test test/features/drafts/draft_editor_test.dart`; expect missing model/edit APIs.
- [ ] **Step 2: Define the immutable schema and generated codecs.** In `draft.dart`, import freezed_annotation, declare `part 'draft.freezed.dart'; part 'draft.g.dart';`, and use this schema:

```dart
@freezed
abstract class Attachment with _$Attachment {
  const factory Attachment({required String assetId, @Default('') String altText}) = _Attachment;
  factory Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);
}
@freezed
abstract class PostContent with _$PostContent {
  const factory PostContent({@Default('') String text, @Default([]) List<Attachment> media}) = _PostContent;
  factory PostContent.fromJson(Map<String, dynamic> json) => _$PostContentFromJson(json);
}
@freezed
abstract class DestinationVersion with _$DestinationVersion {
  const factory DestinationVersion({String? ownText, List<Attachment>? ownMedia,
    int? baseTextRevision, int? baseMediaRevision}) = _DestinationVersion;
  factory DestinationVersion.fromJson(Map<String, dynamic> json) => _$DestinationVersionFromJson(json);
}
@freezed
abstract class Draft with _$Draft {
  const factory Draft({required String id, required DateTime updatedAt,
    @Default(0) int revision, @Default(0) int sharedTextRevision,
    @Default(0) int sharedMediaRevision, @Default(ComposeStage.choose) ComposeStage stage,
    @Default({}) Set<Destination> selected, @Default(PostContent()) PostContent shared,
    @Default({}) Map<Destination, DestinationVersion> versions, DateTime? deletedAt}) = _Draft;
  factory Draft.fromJson(Map<String, dynamic> json) => _$DraftFromJson(json);
}
@freezed
abstract class MediaAsset with _$MediaAsset {
  const factory MediaAsset({required String id, required String relativePath,
    required String mimeType, required int bytes, required String sha256,
    required int width, required int height, int? durationMs,
    String? originalAssetId}) = _MediaAsset;
  factory MediaAsset.fromJson(Map<String, dynamic> json) => _$MediaAssetFromJson(json);
}
```

Null override means inherit; empty string/list means an intentional override, subsequently validated. Require `explicitToJson: true` in a `build.yaml` JSON builder setting so nested objects produce JSON maps; include that file in this task.

- [ ] **Step 3: Implement the edit rules and fixture.**

```dart
PostContent resolveContent(Draft d, Destination target) {
  final v = d.versions[target];
  return PostContent(text: v?.ownText ?? d.shared.text,
    media: v?.ownMedia ?? d.shared.media);
}
Draft editOwnCaption(Draft d, Destination target, String text, DateTime now) {
  final previous = d.versions[target] ?? const DestinationVersion();
  return d.copyWith(revision: d.revision + 1, updatedAt: now,
    versions: {...d.versions, target: previous.copyWith(
      ownText: text, baseTextRevision: d.sharedTextRevision)});
}
Draft editSharedCaption(Draft d, String text, DateTime now) => d.copyWith(
  revision: d.revision + 1, updatedAt: now,
  sharedTextRevision: d.sharedTextRevision + 1,
  shared: d.shared.copyWith(text: text));
Draft sampleDraft() => Draft(id: 'draft-1', updatedAt: DateTime.utc(2026, 11, 16),
  selected: {Destination.x, Destination.bluesky, Destination.instagram},
  shared: const PostContent(text: 'A little color from today’s walk.'));
```

The remaining edit signatures are `Draft restoreSharedCaption(Draft, Destination, DateTime)`, `Draft editSharedMedia(Draft,List<Attachment>,DateTime)`, `Draft editOwnMedia(Draft,Destination,List<Attachment>,DateTime)`, `Draft restoreSharedMedia(Draft,Destination,DateTime)`, `Draft setDestination(Draft,Destination,bool,DateTime)`, `Draft setStage(Draft,ComposeStage,DateTime)`. Implement via copyWith: reset only the corresponding nullable override and base revision; modify selection without deleting versions; media edits increment sharedMediaRevision only when shared media changes. Add `Draft restoreVersion(Draft,Destination,DestinationVersion,DateTime)` for one-step override Undo without overwriting shared edits.
- [ ] **Step 4: Add cases for explicit empty override, reset of text retaining own media, deselection round trip, and change-warning revision comparison.** Use `ownText != null && baseTextRevision != sharedTextRevision` for the text warning; changing shared photos must not trigger it. Run `dart run build_runner build --delete-conflicting-outputs`, then the test and `flutter analyze`. Expected all pass.
- [ ] **Step 5: Commit the model, editor, codec settings/generated files and tests** with message `feat: model shared posts and independent platform versions`.

### Task L3: Import and edit media without depending on picker cache

**Files:** Create `app/lib/storage/{local_database,media_files}.dart`, `app/lib/features/media/media_probe.dart`, `app/android/app/src/main/kotlin/org/example/crossposting/MediaProbe.kt`, `app/test/storage/media_files_test.dart`, `app/test/support/database_fixture.dart`; modify MainActivity to register the metadata channel.

**Interfaces:** `LocalDatabase.open(DatabaseFactory factory,String path) -> Future<LocalDatabase>` exposes `Database db` and `Future<void> close()`; `MediaFiles(LocalDatabase,Directory root,Ids)` exposes `Future<MediaAsset> importFile(XFile file)`, `Future<File> fileFor(String assetId)`, `Future<MediaAsset> transform(String assetId,{required int quarterTurns,Rect? cropPixels})`, `Future<MediaAsset?> find(String assetId)`. `MediaProbe.inspect(String path,String mimeType) -> Future<({int width,int height,int? durationMs})>`.

- [ ] **Step 1: Write the durable-copy test.**

```dart
test('import owns its bytes after picker source disappears', () async {
  sqfliteFfiInit();
  final tmp = await Directory.systemTemp.createTemp('caption-media-');
  final db = await LocalDatabase.open(databaseFactoryFfi, '${tmp.path}/test.db');
  addTearDown(() async { await db.close(); await tmp.delete(recursive: true); });
  final source = File('${tmp.path}/source.png');
  await source.writeAsBytes(img.encodePng(img.Image(width: 8, height: 8)));
  final files = MediaFiles(db, Directory('${tmp.path}/owned'), Ids());
  final asset = await files.importFile(XFile(source.path));
  await source.delete();
  expect(await (await files.fileFor(asset.id)).length(), asset.bytes);
  expect(asset.sha256, isNotEmpty);
  expect((await files.find(asset.id))?.width, 8);
});
```

Imports include dart:io, image as img, image_picker XFile, sqflite_common_ffi, and the named project files. Run `flutter test test/storage/media_files_test.dart`; expect missing storage implementation.
- [ ] **Step 2: Create schema version 1 and transactional opening.**

```sql
PRAGMA foreign_keys = ON;
CREATE TABLE assets(id TEXT PRIMARY KEY, payload TEXT NOT NULL);
CREATE TABLE drafts(id TEXT PRIMARY KEY, revision INTEGER NOT NULL,
  updated_at TEXT NOT NULL, deleted_at TEXT, payload TEXT NOT NULL);
```

Use SQLite transactions and an onUpgrade migration list. Do not silently recreate a database on parse/migration error; retain it and show a recoverable storage error. Runtime uses sqflite's factory; tests inject databaseFactoryFfi.
- [ ] **Step 3: Implement file ownership with atomic promotion.** Create an ID-named `.part` file below `root/imports`; stream `XFile.openRead()` into it, flush/close, inspect type/dimensions/duration, compute streamed SHA-256, then rename to an immutable UUID filename under `root/assets`. Only after promotion insert its MediaAsset JSON in a DB transaction. A failure leaves the prior draft unchanged; remove only this task's partial file. An orphaned promoted file is safe to remove during a later explicit cleanup only if absent from every persisted reference. Reject asset paths escaping the resolved private root.

```dart
final sink = partial.openWrite();
await file.openRead().pipe(sink);
final digest = await sha256.bind(partial.openRead()).first;
await partial.rename(destination.path);
// Persist the complete MediaAsset only after its file exists.
await database.db.insert('assets', {'id': asset.id, 'payload': jsonEncode(asset.toJson())});
```

`partial`, `destination`, `asset`, `database` and the picker `file` are local variables of `MediaFiles.importFile`, constructed from the interface above; no source path is stored as the only media copy. Detect MIME from bytes/metadata, not a user filename. Inspect photos in an isolate with bounded decoding; video uses Android MediaMetadataRetriever on a worker thread and never loads all video bytes into Dart memory. Metadata failure keeps the item invalid with Replace/Remove options, not guessed dimensions.
- [ ] **Step 4: Implement explicit photo derivatives.** `transform` decodes the owned original in an isolate, applies the user-confirmed crop and quarter-turn rotation, writes a new asset ID with originalAssetId, and leaves original bytes untouched. Show original and expected crop before committing. Do not turn preview thumbnail crops into exported crops. Re-encode supported images without location EXIF; label that export behavior in the media UI. For video retain original bytes and show unsupported requirements; no trimming/transcoding package in this milestone.
- [ ] **Step 5: Extend tests to failed import, corrupt file, transformation preserving original hash, two distinct ordered references, missing owned file, and cancelled picker.** Run the media tests and `flutter analyze`. On device import two photos, restart, revoke source access, and confirm the private copies still open. Register lost-picker-result recovery using image_picker's documented Android mechanism at bootstrap; deduplicate recovered imports by their import operation ID.
- [ ] **Step 6: Commit the storage/probe files and tests** with message `feat: preserve owned media and explicit photo edits`.

### Task L4: Save drafts transactionally and expose honest recovery state

**Files:** Create `app/lib/features/drafts/{draft_repository,draft_controller}.dart`, `app/test/features/drafts/{draft_repository_test,draft_controller_test}.dart`.

**Interfaces:** `DraftRepository` methods `Future<Draft?> get(String id)`, `Future<List<Draft>> list()`, `Future<void> save(Draft draft,{required int expectedRevision})`, `Future<void> setDeleted(String id,DateTime? at)`. `SqliteDraftRepository(LocalDatabase)` implements it. `DraftController(Draft initial,DraftRepository repo,Clock clock)` exposes `Draft draft`, `SaveState saveState`, `int savedRevision`, `void change(Draft next)`, `Future<bool> flush()`, `Future<bool> retrySave()`; enum `SaveState { saving,saved,failed }`. Controller owns a single serial save lane per draft.

- [ ] **Step 1: Test DB recovery with real SQLite.**

```dart
test('reopen restores overrides and the last stage', () async {
  sqfliteFfiInit();
  final tmp = await Directory.systemTemp.createTemp('caption-draft-');
  final path = '${tmp.path}/drafts.db';
  var db = await LocalDatabase.open(databaseFactoryFfi, path);
  var d = sampleDraft();
  d = editOwnCaption(d, Destination.bluesky, 'Own caption', DateTime.utc(2026));
  d = setStage(d, ComposeStage.review, DateTime.utc(2026, 1, 2));
  await SqliteDraftRepository(db).save(d, expectedRevision: -1);
  await db.close();
  db = await LocalDatabase.open(databaseFactoryFfi, path);
  expect(await SqliteDraftRepository(db).get(d.id), d);
  await db.close();
  await tmp.delete(recursive: true);
});
```

Run `flutter test test/features/drafts/draft_repository_test.dart`; first failure is missing repository.
- [ ] **Step 2: Implement compare-and-swap persistence.** An expectedRevision of -1 means insert only if absent. Updates use `WHERE id = ? AND revision = ?`; zero changed rows throws `DraftConflict` without overwriting. Verify all referenced media exist before the transaction. Store JSON and index fields in the same transaction. The database codec carries a schema version; corrupt content produces a recovery notice with the original row retained. Tombstone deletion hides drafts but never cascades into assets, packages or attempts. Undo clears the tombstone.

```dart
final changed = await tx.update('drafts', {
  'revision': draft.revision, 'updated_at': draft.updatedAt.toIso8601String(),
  'deleted_at': draft.deletedAt?.toIso8601String(), 'payload': jsonEncode(draft.toJson()),
}, where: 'id = ? AND revision = ?', whereArgs: [draft.id, expectedRevision]);
if (changed != 1) throw DraftConflict(draft.id);
```

Define `DraftConflict implements Exception` with its String draftId in this file. Ensure metadata/file errors become `SaveState.failed`, not silent skips.
- [ ] **Step 3: Test stale save acknowledgements using a controlled repository.** Define `DelayedDraftRepository implements DraftRepository` in the controller test; its save method appends the Draft and returns a Completer-controlled future, while get/list use an in-memory Map and setDeleted copies deletedAt. Set revision 1 then 2 while the first save is pending. Complete save 1 and assert `savedRevision == 1` and `saveState != saved`; complete save 2 and assert saved. Inject one IOException and assert the last complete DB revision remains readable and retrySave persists the current text.
- [ ] **Step 4: Implement autosave and back handling.** Debounce at most 250ms as a planning default, then serialize writes; `flush` cancels the debounce and awaits the current/latest snapshot. A save acknowledgment only marks saved if its revision equals the in-memory revision. Flush before stage transitions, launching pickers/accounts/Instagram, review snapshots, and graceful backgrounding. A force-kill can lose unacknowledged edits; never label those saved. On back with a failed save, keep the editor and show `Couldn't save — keep this screen open`, selectable text, Copy text and Retry saving. A conflict preserves the unsaved in-memory content and offers reload only after explicit choice.
- [ ] **Step 5: Run both test files and `flutter analyze`.** Verify deletion/Undo, storage-full simulation, repeated quick edits and media replacement failure. Native process-death evidence is recorded in R1, not assumed from widget disposal.
- [ ] **Step 6: Commit** with message `feat: add revision-safe autosave and draft recovery`.

### Task L5: Wire first run, local library and destination selection

**Files:** Create `app/lib/app/services.dart`, `app/lib/features/library/{library_repository,library_screen}.dart`, `app/lib/features/compose/choose_screen.dart`, `app/lib/features/accounts/{account,account_repository,accounts_screen}.dart`, `app/test/features/library/library_flow_test.dart`; modify main/app bootstrap.

**Interfaces:** `AccountIdentity({required Destination destination,required String subject,required String handle})`; `AccountState { disconnected,connecting,connected,expired,unavailable }`; `AccountView({required Destination destination,required AccountState state,AccountIdentity? identity,required String capability})`. Define AccountIdentity and AccountView with freezed/fromJson/toJson now, because Review codecs depend on them. `AccountRepository.list() -> Future<List<AccountView>>`. Local implementation returns disconnected X/Bluesky and assisted Instagram without fabricated identity. `LibraryRepository.listDrafts() -> Future<List<Draft>>`. `LibraryScreen({required AppServices services})`; `ChooseScreen({required DraftController controller,required AccountRepository accounts,required VoidCallback onContinue})`. `AppServices` initially owns fields `database:LocalDatabase`, `media:MediaFiles`, `drafts:DraftRepository`, `accounts:AccountRepository`, `clock:Clock`, `ids:Ids`, and `Future<void> close()`; later plans add concrete services through its constructor/bootstrap.

- [ ] **Step 1: Write the actual navigation test.**

```dart
testWidgets('draft creation requires no account and no selected default', (tester) async {
  final services = await localTestServices();
  addTearDown(services.close);
  await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: services)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create a draft'));
  await tester.pumpAndSettle();
  expect(find.text('Where should this go?'), findsOneWidget);
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,
    'Continue to writing')).onPressed, isNull);
  await tester.tap(find.byKey(const ValueKey('choose-instagram')));
  await tester.pumpAndSettle();
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,
    'Continue to writing')).onPressed, isNotNull);
});
```

Define `localTestServices()` in `app/test/support/app_fixture.dart`: initialize FFI, create a temporary directory, open LocalDatabase, construct real SqliteDraftRepository/MediaFiles and local AccountRepository plus Clock/Ids; return AppServices with `close()` closing DB and deleting only that temporary directory. Add that exact fixture file to this task. Run this test; expected missing screen/composition.
- [ ] **Step 2: Wire real first run and library.** Use the exact introductory copy in the current library board; one white Create a draft/New post action. New draft has no destinations and is persisted before opening Choose. Library shows attention items above drafts as they become available in later plans, tabs for Drafts/Results, saved time, selected destinations and resume stage. Empty Results says `No posting results yet`. No analytics counts. A loading spinner/progress label remains until the actual query completes; failed DB load offers Retry and preserves disk data.
- [ ] **Step 3: Implement Choose and Accounts.** Use CheckboxListTile semantics with the key pattern in the test. X/Bluesky may be selected while disconnected; label `Connect before publishing`. Instagram says `You finish it in Instagram · choose the account there`. Continue needs at least one selection, not a connection. Accounts explains capabilities and permits drafting immediately; until P2/P3 the real connection action says `Connection setup required` and explains unavailable configuration, never simulates success. Instagram assisted-sharing toggle is a local preference; switching it off never deletes an existing package and prompts before removing it from the current draft. Back and stage transitions await controller.flush.
- [ ] **Step 4: Run navigation tests and add reopen/resume, empty library, load failure, and delete/Undo cases.** `flutter test test/features/library/library_flow_test.dart`; `flutter analyze`. Ensure future results/packages can remain visible after their source draft is tombstoned.
- [ ] **Step 5: Commit** with message `feat: connect local library and destination selection`.

### Task L6: Implement shared writing, media editing and own versions

**Files:** Create `app/lib/features/compose/{write_screen,version_screen}.dart`, `app/lib/features/media/media_editor_screen.dart`, `app/test/features/compose/{write_screen_test,version_screen_test}.dart`; extend caption_text.dart, navigation and app_fixture.dart.

**Interfaces:** `WriteScreen({required DraftController controller,required MediaFiles media,required VoidCallback onReview})`; `VersionScreen({required DraftController controller,required Destination destination,required MediaFiles media})`; `MediaEditorScreen({required List<Attachment> items,required MediaFiles media,required ValueChanged<List<Attachment>> onChanged})`; `CaptionEditor({required TextEditingController controller,required String label,required bool own,required ValueChanged<String> onChanged})`.

- [ ] **Step 1: Write the edit/ownership widget test.**

```dart
testWidgets('a destination editor announces own caption without changing shared', (tester) async {
  final s = await localTestServices();
  addTearDown(s.close);
  final c = DraftController(sampleDraft(), s.drafts, s.clock);
  await tester.pumpWidget(CaptionApp(home: VersionScreen(
    controller: c, destination: Destination.bluesky, media: s.media)));
  await tester.tap(find.text('Own caption'));
  await tester.pump();
  await tester.enterText(find.byType(TextField), 'Bluesky words');
  expect(resolveContent(c.draft, Destination.bluesky).text, 'Bluesky words');
  expect(c.draft.shared.text, sampleDraft().shared.text);
  expect(find.text('Use shared photos'), findsOneWidget);
});
```

Run the test; first failure is the missing editor/screen.
- [ ] **Step 2: Use a native text field, preserving the composing region.**

```dart
TextField(
  controller: controller, minLines: 3, maxLines: null,
  keyboardType: TextInputType.multiline, textCapitalization: TextCapitalization.sentences,
  style: TextStyle(fontFamily: 'Atkinson Hyperlegible Next', fontSize: 21,
    fontWeight: FontWeight.w600, height: 34 / 21,
    color: own ? CaptionTokens.own : CaptionTokens.text,
    backgroundColor: CaptionTokens.stage),
  cursorColor: CaptionTokens.own,
  decoration: InputDecoration(labelText: label, alignLabelWithHint: true,
    filled: true, fillColor: CaptionTokens.raised),
  onChanged: onChanged,
)
```

Do not rebuild the TextEditingController on every keystroke. External changes preserve selection/composing bounds when valid. Label/counter/saving status are accessible separately. In the shared editor show ordered thumbnails above the field and the current destination caption samples below, with Shared/Own caption labels. Use Add media in shared UI so supported X/Bluesky video is discoverable; Instagram-specific UI remains photos-only.
- [ ] **Step 3: Implement version reset and comparison.** Own caption uses cyan; shared uses white. Compare captions shows full shared/own text in a scrollable modal/full screen. Switching back to shared prompts only if customized work would be discarded, then stores the previous DestinationVersion for one-step Undo. Undo is valid only while that same field has not been edited again; do not overwrite newer edits. Text and media switches are separate. Returning Done flushes before popping.
- [ ] **Step 4: Wire media editing controls.** Each attachment exposes Add/Edit description, Move earlier, Move later, Replace, Remove, Rotate and Crop. Reorder buttons are always available; drag is optional. Validate new copy/transform before changing references. Description belongs to the attachment version, not globally to every use of a physical photo. Media-only overrides retain inherited text. Video plus Instagram produces a scoped Review issue with actions to choose Instagram photos or deselect Instagram, never deletes the video.
- [ ] **Step 5: Run both test files and verify keyboard/large-text behavior.** Add assertions for blank caption input, IME composing text retained, reset cancel/confirm/Undo, independent media override, reorder accessibility actions, failed import retaining prior attachment, and Back dismissing keyboard before leaving. Run `flutter analyze`; inspect the composer and own-version screen against the boards.
- [ ] **Step 6: Commit** with message `feat: implement Caption writing and destination edits`.

### Task L7: Resolve exact review snapshots and truthful validation

**Files:** Create `app/lib/features/review/{review,review_service,review_screen}.dart`, `app/test/features/review/review_service_test.dart`, `app/test/features/review/review_screen_test.dart`; modify navigation.

**Interfaces:** `ResolvedPost({required Destination destination,required PostContent content,required List<MediaAsset> assets,AccountIdentity? account})`; `ReviewIssue({required Destination destination,required String code,required String message,required bool blocking})`; `ReviewedPost({required String draftId,required int revision,required Map<Destination,ResolvedPost> posts,required Map<Destination,String> capabilityVersions,required DateTime reviewedAt})`; these immutable models have generated JSON codecs. `ReviewResult({required ReviewedPost snapshot,required List<ReviewIssue> issues})` has `bool get canProceed`. `ReviewService(DraftRepository,MediaFiles,AccountRepository,ValidatorRegistry,Clock)` exposes `review(Draft) -> Future<ReviewResult>`. Define `DestinationValidator.validate(ResolvedPost) -> List<ReviewIssue>` and `String get version`, and `ValidatorRegistry.forDestination(Destination) -> DestinationValidator`. `ReviewScreen({required DraftController controller,required ReviewService service,required Future<void> Function(ReviewedPost) onConfirm})`.

- [ ] **Step 1: Test that no selected destination is silently removed.**

```dart
test('review keeps disconnected selections and blocks direct publishing', () async {
  final s = await localTestServices();
  addTearDown(s.close);
  final d = sampleDraft();
  await s.drafts.save(d, expectedRevision: -1);
  final result = await ReviewService(s.drafts, s.media, s.accounts,
    const LocalValidators(), s.clock).review(d);
  expect(result.snapshot.posts.keys.toSet(), d.selected);
  expect(result.canProceed, isFalse);
  expect(result.issues.any((i) => i.destination == Destination.bluesky &&
    i.code == 'connection-needed'), isTrue);
});
```

Define `LocalValidators implements ValidatorRegistry` with a const constructor in review_service.dart. It returns conservative validators: direct providers return a blocking `requirements-unverified` issue until P1/P4/P5 supply verified profiles; Instagram validates local photos/presence/order and remains blocked for preparation until I1 supplies a verified photo policy. Run the test to see missing service, then implement.
- [ ] **Step 2: Resolve all content and validate before displaying the final action.** For every selected destination load immutable assets, validate existence/hash metadata, account identity and per-destination content. Missing media blocks that destination. Empty text is allowed only if its verified provider permits media-only posts; empty text + no media always blocks. Photo/video mixtures and multiple videos block. Numeric provider limits/counting rules are injected from verified profiles in P1, not invented from mockups. If validation cannot run, show `Couldn't check current requirements` and do not infer Ready. Local saving always remains available.
- [ ] **Step 3: Implement the preview and exact action labels.**

```dart
String reviewActionLabel(Set<Destination> destinations) {
  final direct = destinations.where((d) => d != Destination.instagram).toList();
  if (destinations.contains(Destination.instagram)) {
    return direct.isEmpty ? 'Prepare Instagram' : 'Publish & prepare';
  }
  return direct.length == 1
    ? 'Publish to ${direct.single == Destination.x ? 'X' : 'Bluesky'}'
    : 'Publish to ${direct.length} accounts';
}
```

Separate Publish now and Prepare only, show account handles, Shared/Own caption, all media and descriptions, and Approximate preview. Long previews expand fully. An expired account row offers Reconnect and Leave [platform] out; the latter changes selection only after a deliberate tap, then rebuilds review. Offline blocks selected direct destinations; Instagram-only local preparation remains available. Network restoration never invokes onConfirm. In this milestone the onConfirm action remains disabled with `Preparation setup required` until I1 wires the real local preparation; there is no success simulation.
- [ ] **Step 4: Make final confirmation reject stale reviews.** Flush, reload persisted draft revision and selected account identities, compare to ReviewedPost, and run current validation again immediately before delegating. Any mismatch returns to Review with `This post changed. Review it again.` Disable the button during the operation; duplicate protection is reinforced in P6.
- [ ] **Step 5: Run Review tests, all local tests and analyze.** Add a widget test that tapping Continue/Review never invokes onConfirm, no-destination guard, explicit deselection, failed-save blocker, stale snapshot, caption-source display, video/Instagram issue, and 200% expanded preview. Milestone acceptance: cold start → create → choose → edit → close/reopen → own version → Review restores exact local content without network calls.
- [ ] **Step 6: Commit** with message `feat: add explicit per-destination review snapshots`.

## Milestone exit

Record the device/toolchain used, successful recovery cases and known limitations in `docs/testing/local-drafts.md`. L1–L7 produce a functioning drafting/review application; they do not prove any platform can publish. Proceed to Instagram's fallback and provider feasibility independently, preserving that distinction in UI and reports.
