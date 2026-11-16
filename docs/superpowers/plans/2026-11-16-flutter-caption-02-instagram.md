# Flutter Caption Assisted Instagram Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the reviewed feed-photo/carousel workflow usable through durable preparation, caption copying, photo saving and explicit manual completion.

**Architecture:** Instagram packages are immutable local snapshots with a separate append-only activity/confirmation record. A narrow Android adapter exports owned files and launches supported intents; it cannot report publication. The fallback is the required path and optional targeted sharing is capability-gated.

**Tech Stack:** Flutter, existing SQLite/media services, Flutter Clipboard API, Kotlin MediaStore/FileProvider/Intent integration through a MethodChannel, widget/unit tests plus manual Android evidence.

**Spec:** `docs/design/design-review.md` sections 5–6 and 8; `docs/design/options-dark/a-caption-v2-instagram.png`; `docs/design/options-dark/caption/caption-states-instagram-board.png`; parent `2026-11-16-flutter-caption-mvp.md`. Depends on Plan 01's models, storage and review interfaces.

## Global Constraints

- "Opening Instagram alone does not advance Ready to share."
- "Opening the Android share chooser does not prove a handoff either."
- "A returned focus event never implies publication."
- "Manual posting cannot be rolled back from this app. Undo on \"User marked as posted\" changes only the local record, returning to the prior pending state; the label makes this clear."
- "Instagram MVP preparation covers feed photos and carousels. Instagram video, Reels, and Stories are deferred."
- "No unofficial APIs, password collection, browser automation, required AI services, or agent-driven workflows."
- "Each screen has one white action."
- All parent accessibility, persistence and authorization constraints apply. A live manual Instagram post is separately authorized; opening a UI or preparing a package is not authorization to publish it.

---

## File ownership

Own `app/lib/features/instagram/`, native `InstagramTransfer.kt`/`MediaExporter.kt`, scoped FileProvider configuration, and Instagram tests. Extend DB migrations, AppServices, Review and Library to integrate actual preparation. Do not introduce an Instagram account token, server endpoint, WebView login or background worker.

### Task I1: Freeze and persist an Instagram package

**Files:** Create `app/lib/features/instagram/{instagram_package,instagram_repository,instagram_service}.dart`, generated codecs, `app/test/features/instagram/package_test.dart`; modify local_database.dart, app/services.dart, review_service.dart and library repository to expose pending packages.

**Interfaces:** Models below have JSON codecs. `InstagramRepository.create(InstagramPackage) -> Future<void>`, `get(String) -> Future<InstagramPackage?>`, `progress(String) -> Future<InstagramProgress>`, `append(String packageId,InstagramEvent) -> Future<void>`, `pending() -> Future<List<InstagramPackage>>`. `InstagramService.prepare(ReviewedPost,{required String operationId}) -> Future<InstagramPackage>`. `InstagramPhotoPolicy({required bool verified,required int maxPhotos,required Set<String> mimeTypes,required String evidenceVersion})` has `List<ReviewIssue> validate(ResolvedPost)`. Production numbers come from dated official/device evidence; tests use explicitly labeled fixture limits.

- [ ] **Step 1: Write the snapshot and deduplication test.**

```dart
test('preparation pins reviewed words and reuses the same operation', () async {
  final s = await instagramTestServices();
  addTearDown(s.close);
  final review = await s.reviewTwoPhotos('Reviewed caption');
  final one = await s.instagram.prepare(review, operationId: 'prepare-1');
  final two = await s.instagram.prepare(review, operationId: 'prepare-1');
  expect(two.id, one.id);
  expect(one.caption, 'Reviewed caption');
  expect(one.photos.map((p) => p.ordinal), [1, 2]);
  expect((await s.instagramRepo.progress(one.id)).state, InstagramState.ready);
  expect(one.revision, review.revision);
});
```

Create `app/test/support/instagram_fixture.dart`: `instagramTestServices() -> Future<InstagramTestServices>`. This fixture wrapper owns the local AppServices, getters `instagram:InstagramService` and `instagramRepo:InstagramRepository`, `Future<ReviewedPost> reviewTwoPhotos(String caption)`, and `Future<void> close()`. Add a verified fixture-only policy maxPhotos=2 and MIME image/png, two generated PNG assets imported through MediaFiles, and a ValidatorRegistry that delegates direct validation to LocalValidators and Instagram to that fixture policy. I2 adds the optional transfer parameter when that interface exists. Its fixture limits are not release capabilities. Run `flutter test test/features/instagram/package_test.dart`; expect missing service.
- [ ] **Step 2: Define package and progress as separate persisted records.**

```dart
enum InstagramState { preparing, ready, handedOff, userMarked }
enum InstagramEventKind { captionCopied, photoSaved, opened, chooserOpened,
  targetDispatched, returnAcknowledged, markedPosted, markUndone }
@freezed
abstract class PreparedPhoto with _$PreparedPhoto {
  const factory PreparedPhoto({required String assetId,required String relativePath,
    required String sha256,required int ordinal,required String altText}) = _PreparedPhoto;
  factory PreparedPhoto.fromJson(Map<String,dynamic> json) => _$PreparedPhotoFromJson(json);
}
@freezed
abstract class InstagramPackage with _$InstagramPackage {
  const factory InstagramPackage({required String id,required String operationId,
    required String draftId,required int revision,required String caption,
    required List<PreparedPhoto> photos,required DateTime createdAt}) = _InstagramPackage;
  factory InstagramPackage.fromJson(Map<String,dynamic> json) => _$InstagramPackageFromJson(json);
}
@freezed
abstract class InstagramEvent with _$InstagramEvent {
  const factory InstagramEvent({required String id,required InstagramEventKind kind,
    required DateTime at,int? photoOrdinal,String? uri,String? launchId,
    String? targetPackage}) = _InstagramEvent;
  factory InstagramEvent.fromJson(Map<String,dynamic> json) => _$InstagramEventFromJson(json);
}
@freezed
abstract class InstagramProgress with _$InstagramProgress {
  const factory InstagramProgress({required InstagramState state,
    InstagramState? priorPending,DateTime? confirmedAt,String? activeLaunchId,
    String? promptedLaunchId,@Default({}) Map<int,String> savedUris}) = _InstagramProgress;
  factory InstagramProgress.fromJson(Map<String,dynamic> json) => _$InstagramProgressFromJson(json);
}
```

The field schema above is the exact constructor contract, not arbitrary event JSON. Add schema version 2 tables:

```sql
CREATE TABLE instagram_packages(id TEXT PRIMARY KEY, operation_id TEXT UNIQUE NOT NULL,
  draft_id TEXT NOT NULL, revision INTEGER NOT NULL, payload TEXT NOT NULL);
CREATE TABLE instagram_events(id TEXT PRIMARY KEY, package_id TEXT NOT NULL,
  kind TEXT NOT NULL, at TEXT NOT NULL, payload TEXT NOT NULL,
  FOREIGN KEY(package_id) REFERENCES instagram_packages(id));
CREATE TABLE export_jobs(id TEXT PRIMARY KEY, package_id TEXT NOT NULL,
  ordinal INTEGER NOT NULL, uri TEXT, completed INTEGER NOT NULL DEFAULT 0,
  UNIQUE(package_id, ordinal));
```

No cascading draft foreign key: deleting a draft cannot delete its pending package. Project progress from ordered events; tie-break equal timestamps with a monotonic SQLite sequence/row order, not wall-clock order alone.
- [ ] **Step 3: Implement preparation as a durable local operation.** Revalidate the exact Instagram ResolvedPost, require policy evidence and photo-only content, copy reviewed prepared photos into the package UUID directory below `getApplicationSupportDirectory()/instagram-packages/` with ordered names, and verify hashes. Confirm that this directory maps to Android filesDir so I3's FileProvider path matches exactly. Promote the complete directory and insert the package once; state becomes ready only after durable files and DB record exist. A failed operation retains the previous ready package and reports the affected photo. Repeated operationId returns the existing package; the same operationId with different snapshot content fails explicitly. Do not use the draft revision as the only idempotency key across deliberate new attempts.

```dart
final existing = await repository.findByOperation(operationId);
if (existing != null) {
  if (!samePackageSource(existing, reviewed)) throw StateError('Preparation changed');
  return existing;
}
final post = reviewed.posts[Destination.instagram];
if (post == null) throw StateError('Instagram is not selected');
final issues = policy.validate(post);
if (issues.any((i) => i.blocking)) throw InstagramPreparationRejected(issues);
```

Add `findByOperation(String) -> Future<InstagramPackage?>`, `samePackageSource(InstagramPackage,ReviewedPost) -> bool`, and `InstagramPreparationRejected(List<ReviewIssue>)` in this task. Compare caption, ordered asset hashes/alt text and revision. Use the same UUID/hash/file rules as L3 with a package-scoped destination. The source draft can evolve without changing this package. `Prepare updated version` creates a new operation/package and preserves old activity.
- [ ] **Step 4: Connect Instagram-only Review and Library.** `Prepare Instagram` calls this service after a fresh flush/review, then opens the real finish screen introduced in I2/I4; until that screen exists expose a read-only prepared-package view with selectable caption/photos. Direct selected providers remain blocked until Plan 03. Add pending packages to attention-first library rows; show preparation failure as a local preparation problem, never a failed Instagram publication.
- [ ] **Step 5: Run tests for unchanged prepared content after draft editing, broken/missing files, low space, repeat taps, crash before package DB commit and recovery of pending packages after draft deletion.** Run `flutter analyze`. Expected no incomplete ready package and no duplicate package for the same operation.
- [ ] **Step 6: Commit** the exact owned files with message `feat: prepare immutable Instagram photo packages`.

### Task I2: Ship copy-caption and save-photo fallback

**Files:** Create `app/lib/features/instagram/{android_transfer,instagram_screen}.dart`, `app/android/app/src/main/kotlin/org/example/crossposting/MediaExporter.kt`, `app/test/features/instagram/export_test.dart`, `app/integration_test/instagram_export_test.dart`; modify MainActivity, InstagramRepository/Service and manifest as needed for scoped export.

**Interfaces:** `AndroidTransfer.copyCaption(String) -> Future<void>`; `savePhotos(InstagramPackage,Set<int> ordinals) -> Future<List<PhotoSaveResult>>`; `PhotoSaveResult({required int ordinal,String? uri,String? errorCode})`, success only when uri is non-null and errorCode is null. `InstagramService.copyCaption(String packageId)`, `saveMissingPhotos(String packageId) -> Future<List<PhotoSaveResult>>`. MethodChannel name `crossposting/instagram`; native method `savePhoto` arguments `{jobId,sourcePath,displayName,mimeType}` returns `{uri}` only on committed save.

- [ ] **Step 1: Test partial saves without retrying completed exports.**

```dart
test('only missing photo exports are retried', () async {
  final fake = FakeAndroidTransfer(failOrdinals: {2});
  final s = await instagramTestServices(transfer: fake);
  addTearDown(s.close);
  final p = await s.instagram.prepare(await s.reviewTwoPhotos('Caption'), operationId: 'p');
  await s.instagram.saveMissingPhotos(p.id);
  expect((await s.instagramRepo.progress(p.id)).savedUris.keys, [1]);
  fake.failOrdinals.clear();
  await s.instagram.saveMissingPhotos(p.id);
  expect(fake.savedBatches, [{1, 2}, {2}]);
  expect((await s.instagramRepo.progress(p.id)).savedUris.length, 2);
});
```

Define FakeAndroidTransfer in `app/test/support/fake_android_transfer.dart`, storing `List<Set<int>> savedBatches` and returning a synthetic `Uri(scheme: 'content', host: 'caption-test', path: '/$ordinal').toString()` for successes. Its constructor accepts `Set<int> failOrdinals = const {}` and stores a mutable copy. Copy failures are injectable Exceptions. Update the fixture signature to `instagramTestServices({AndroidTransfer? transfer}) -> Future<InstagramTestServices>` and inject that port into InstagramService. Run the test to see missing service/native adapter.
- [ ] **Step 2: Implement clipboard writes and transactional media export.** Caption copying uses `await Clipboard.setData(ClipboardData(text: package.caption))`; record captionCopied only on success. On failure retain selectable full text and Retry copy. Do not read the user's clipboard. Save uses Android MediaStore on API29+, RELATIVE_PATH `Pictures/CrossPosting`, per-job identifiable filenames and IS_PENDING. Core native operation:

```kotlin
val values = ContentValues().apply {
    put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
    put(MediaStore.Images.Media.MIME_TYPE, mimeType)
    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/CrossPosting")
    put(MediaStore.Images.Media.IS_PENDING, 1)
}
val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
    ?: throw IOException("Could not create gallery item")
try {
    resolver.openOutputStream(uri, "w")!!.use { output ->
        FileInputStream(sourceFile).use { input -> input.copyTo(output) }
        output.flush()
    }
    resolver.update(uri, ContentValues().apply {
        put(MediaStore.Images.Media.IS_PENDING, 0)
    }, null, null)
} catch (error: Exception) {
    resolver.delete(uri, null, null)
    throw error
}
```

Run file I/O off the Android main thread; report MethodChannel results on the main thread. Persist an export job before invoking native work. On interrupted export reconcile only the app-owned row with that job's unique filename/URI: finish a verified complete row or remove its incomplete row and retry. Never delete or enumerate unrelated gallery media. A Dart persistence failure after export must be recoverable from that journal rather than creating duplicate gallery copies on every retry. Validate the passed source path under the prepared package root in native code as well as Dart.
- [ ] **Step 3: Wire accurate fallback UI and activity.** Show all photos in order, actual saved count, and known gallery destination. `1 of 2 saved` offers Retry remaining photo, not Save all again. Preserve descriptions as selectable text with guidance to enter them inside Instagram if needed; never imply sharing carries alt text. Recheck saved URIs when resuming so externally deleted exports can be saved again. Do not assume gallery sorting follows filenames. Keep originals untouched and private copies retained.
- [ ] **Step 4: Run unit tests and the Android integration check.** Run `flutter test test/features/instagram/export_test.dart`. Set the task-specific `CAPTION_TEST_DEVICE` environment variable to the authorized test device ID from `flutter devices`; fail rather than choosing an arbitrary attached device if it is absent. Then run `flutter test integration_test/instagram_export_test.dart -d $env:CAPTION_TEST_DEVICE`. Device check exports two clearly numbered sample photos, then the human opens Instagram, selects them in order and pastes the caption. Publishing requires separate authorization. Repeat with failed write, deleted export, no storage and process death between export and receipt persistence. Record exact outcomes in `docs/testing/instagram-fallback.md`.
- [ ] **Step 5: Commit** with message `feat: add reliable Instagram caption and gallery fallback`.

### Task I3: Add truthful launch and optional identifiable handoff

**Files:** Create `app/android/app/src/main/kotlin/org/example/crossposting/InstagramTransfer.kt`, `app/android/app/src/main/res/xml/file_paths.xml`, `app/test/features/instagram/handoff_test.dart`; modify android_transfer.dart, InstagramService/Screen, MainActivity and AndroidManifest.xml.

**Interfaces:** `LaunchResult { opened,unavailable,failed }`; `ShareDispatch { dispatchedToInstagram,chooserOpened,cancelled,unavailable,failed }`; `AndroidTransfer.openInstagram() -> Future<LaunchResult>`, `sharePhotos(InstagramPackage) -> Future<ShareDispatch>`. `InstagramService.open(String packageId) -> Future<LaunchResult>` and `share(String packageId) -> Future<ShareDispatch>` append only events justified by these results. `InstagramShareCapability` stores `singlePhoto`, `carousel`, and dated device/Instagram evidence; default both false.

- [ ] **Step 1: Test launch cannot advance the package.**

```dart
test('opening Instagram is an activity, not a handoff', () async {
  final s = await instagramTestServices(transfer: FakeAndroidTransfer());
  addTearDown(s.close);
  final p = await s.instagram.prepare(await s.reviewTwoPhotos('Caption'), operationId: 'p');
  expect(await s.instagram.open(p.id), LaunchResult.opened);
  expect((await s.instagramRepo.progress(p.id)).state, InstagramState.ready);
  expect((await s.instagramRepo.events(p.id)).last.kind, InstagramEventKind.opened);
});
```

Add repository `events(String) -> Future<List<InstagramEvent>>`. FakeAndroidTransfer exposes configurable launch/share result values. Run the test; expect missing behavior.
- [ ] **Step 2: Implement the standard launch.** Query only the installed Instagram package (`com.instagram.android`, verified during device probing), request its package launch intent and catch ActivityNotFoundException. Manifest `<queries>` lists only that package and required intent handlers; do not request QUERY_ALL_PACKAGES or broad media permissions. Launch result opened appends opened with a new launchId; state remains ready or its prior pending state. Unavailable shows `Open Instagram yourself` with fallback instructions and no successful-open event.
- [ ] **Step 3: Add the optional supported share path behind device evidence.** FileProvider exposes only the prepared package directory via `<files-path name="instagram_packages" path="instagram-packages/"/>`; make the actual package storage directory match that path. No root-path, external-path wildcard or exported provider. Grant temporary read access with ClipData for every content URI. Use ACTION_SEND for one image and ACTION_SEND_MULTIPLE for a supported photo set, correct image MIME and EXTRA_STREAM. An explicitly targeted supported Instagram intent that the OS accepts may produce `dispatchedToInstagram`, whose UI meaning is only dispatch. A chooser opening/target selection alone stays `chooserOpened`; cancellation never advances. Do not drop all but the first photo to make a carousel appear supported.

```dart
final outcome = await transfer.sharePhotos(package);
final kind = switch (outcome) {
  ShareDispatch.dispatchedToInstagram => InstagramEventKind.targetDispatched,
  ShareDispatch.chooserOpened => InstagramEventKind.chooserOpened,
  _ => null,
};
if (kind != null) {
  await repository.append(package.id, InstagramEvent(id: ids.next(), kind: kind,
    at: clock.now(), launchId: launchId,
    targetPackage: outcome == ShareDispatch.dispatchedToInstagram ? 'com.instagram.android' : null));
}
```

Preserve private files long enough for receiving-app reads; do not revoke access or delete the package on activity resume. Copy caption remains separate because intents do not prove caption import.
- [ ] **Step 4: Run unit tests and record the real matrix.** Test one photo, multiple photos, wrong/unknown target, cancelled chooser, Instagram absent, revoked URI access, app-switch return and process recreation. Test actual receiving-app import manually; do not automate Instagram. Enable shortcuts only for documented supported paths. The two-photo fallback from I2 remains required even if every shortcut fails.
- [ ] **Step 5: Commit** with message `feat: distinguish Instagram launch from supported file handoff`.

### Task I4: Ask once on return and record reversible user confirmation

**Files:** Modify instagram_package.dart, instagram_service.dart, instagram_screen.dart and generated codecs; create `app/test/features/instagram/{confirmation_test,return_screen_test}.dart`; extend Library attention summaries and local package result view.

**Interfaces:** `InstagramService.onResume(String packageId) -> Future<bool>` returns whether to show the return prompt; `acknowledgeReturn(String packageId)`, `markPosted(String packageId)`, `undoMarked(String packageId)` each return Future<void>. Marking takes no claimed provider receipt. `InstagramProgress` carries priorPending/confirmedAt and correlated launch IDs defined in I1.

- [ ] **Step 1: Test confirmation source and Undo.**

```dart
test('manual marking is timestamped and Undo restores prior pending state', () async {
  final s = await instagramTestServices();
  addTearDown(s.close);
  final p = await s.instagram.prepare(await s.reviewTwoPhotos('Caption'), operationId: 'p');
  await s.instagram.markPosted(p.id);
  final marked = await s.instagramRepo.progress(p.id);
  expect(marked.state, InstagramState.userMarked);
  expect(marked.confirmedAt, isNotNull);
  expect(marked.priorPending, InstagramState.ready);
  await s.instagram.undoMarked(p.id);
  final undone = await s.instagramRepo.progress(p.id);
  expect(undone.state, InstagramState.ready);
  expect(undone.confirmedAt, isNull);
});
```

Run the test to establish missing confirmation behavior. Repeat with a previously handed-off package; Undo must return to handedOff, not always ready.
- [ ] **Step 2: Implement the event projection and correlated prompt.** A markedPosted event is accepted only from ready/handedOff and records its clock time and prior pending state; a markUndone event restores that state while retaining history. Duplicate marking is a no-op, not another confirmation event. Append operations are transactional and idempotent for duplicate taps. `onResume` checks activeLaunchId != promptedLaunchId, pending package state and the actual external-launch session; unrelated keyboard/dialog/account resumes do not prompt. Persist acknowledgment when the return question is shown/dismissed so relaunch does not repeatedly ask for the same trip. After a later deliberate launch, a new ID permits a new prompt. Reopening a pending package always leaves an explicit confirmation action available.
- [ ] **Step 3: Wire the exact dialog and accessible Undo.**

```dart
final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
  title: const Text('Mark Instagram as posted?'),
  content: const Text("This records your confirmation on this phone. The app can't verify that the post is live."),
  actions: [
    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark as posted')),
  ],
));
if (confirmed == true) await service.markPosted(packageId);
```

Return view says `Status: still Ready to share` after open-only, with I've posted it and Not yet. If only a generic chooser was opened, say `Back to your post` rather than claiming Instagram was visited. Results say `Marked posted`, `Your confirmation at [local time]. Not verified by the app.` Announce the change once without stealing focus. Offer SnackbarAction Undo, honoring accessibleNavigation; also keep an accessible `Undo my confirmation` action in package details so correction never depends on a short timer. Undo says it changes only this phone's record. Dialog focus returns to its initiating control and content scrolls at 200%.
- [ ] **Step 4: Run confirmation/return widget tests.** Assert cancel leaves state unchanged, background/resume alone never marks posted, one prompt per launch, mark survives restart, double taps produce one event, and Undo preserves the package/files. Manually check TalkBack reading/focus, 320dp/200% text and persistent correction after the snackbar disappears.
- [ ] **Step 5: Commit** with message `feat: record explicit reversible Instagram completion`.

## Milestone exit

A person can prepare two reviewed photos, copy text, save both, switch to Instagram, return and deliberately record or defer completion, even with no direct-sharing shortcut. No Instagram sign-in, official publishing API or automation is involved. Keep the final manual publication step human-operated. Any provider-dependent live testing remains outside this milestone's default authorization.
