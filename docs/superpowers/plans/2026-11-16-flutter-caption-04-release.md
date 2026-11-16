# Flutter Caption Device Validation and Release Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a verified Android release candidate and maintainable open-source handoff without silently publishing a release or opening a hosted service.

**Architecture:** Validate the integrated local-first application on real Android behavior, keep credentials outside content and backups, and make the build reproducible. CI runs deterministic checks without provider credentials; human-controlled live probes are documented separately.

**Tech Stack:** Flutter unit/widget/integration tests, Android emulator and the user's authorized test device, Android accessibility tools/TalkBack, GitHub Actions if the eventual repository uses GitHub, locally managed release signing.

**Spec:** All parent `2026-11-16-flutter-caption-mvp.md` constraints and gates; `docs/design/design-review.md` accessibility/recovery/state requirements; Caption v2 and all four remaining-screen boards. Depends on Plans 01–03.

## Global Constraints

- "Test system text enlargement through 200% without truncating actions or instructions; layouts grow and scroll rather than shrink type."
- "48 × 48dp minimum touch targets, at least 4.5:1 normal-text contrast and 3:1 meaningful component boundaries."
- "No automatic resend occurs on app launch or network return."
- "On-device storage is not a cloud backup."
- "Open-source and approachable to run and maintain."
- Parent constraints apply in full. No store upload, public source publication, paid enrollment, public release, new service, or live test publication without authorization covering it.

---

## File ownership

Own cross-feature acceptance tests, Android backup/security configuration, reproducible CI/build documentation and release checklists. Fix actual defects in the owning feature files and rerun their focused tests. Do not redesign Caption, introduce a second theme, add analytics, or convert an incomplete integration into an unexplained unavailable feature.

### Task R1: Validate native accessibility, interruption and the full workflow

**Files:** Create `app/test/acceptance/accessibility_test.dart`, `app/integration_test/{local_recovery_test,mixed_results_test}.dart`, `docs/testing/{android-acceptance,visual-acceptance}.md`; modify only affected feature/design files when checks identify defects.

**Interfaces:** Consumes AppServices, local/Instagram/coordinator fixtures and all real screens. Produces a dated evidence matrix with device model, Android version, app commit, Flutter version, test case, observed result and remaining limitation. No new runtime abstraction is needed.

- [ ] **Step 1: Write a native-widget accessibility regression check.**

```dart
testWidgets('first run remains operable at 320dp and 200 percent text', (tester) async {
  final s = await localTestServices();
  addTearDown(s.close);
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(CaptionApp(home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2), accessibleNavigation: true),
    child: LibraryScreen(services: s))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await tester.ensureVisible(find.text('Create a draft'));
  await tester.tap(find.text('Create a draft'));
  await tester.pumpAndSettle();
  expect(find.text('Where should this go?'), findsOneWidget);
});
```

Run `flutter test test/acceptance/accessibility_test.dart`; if it already passes, retain it as an acceptance guard rather than manufacturing a failure. Add a failing test for each actual defect before the corresponding repair. Do not add assertions merely checking that a style constant equals itself.
- [ ] **Step 2: Exercise the complete visual/state matrix.** Capture native screens at 390dp/100%, 320dp/200% and landscape. Use first run, empty library, populated attention-first library, Choose (no selection/disconnected), Write (empty/text/photo/video/keyboard), own version/comparison/reset dialog, Review (valid/blocked/offline/long text), Accounts (connecting/expired), Results (partial/processing/unknown/user-report), Instagram (ready/partial save/return/dialog/marked/Undo). Compare composition to current boards; browser goldens are visual references, not pixel-exact Flutter goldens. Dark system bars, black stage, opaque subtitles, Atkinson font, cyan ownership and one white action must remain coherent. Capture text-only and bright-photo cases. Check font fallback with emoji and non-Latin captions; do not strip unsupported user text to preserve a visual style.
- [ ] **Step 3: Check real interaction accessibility.** With TalkBack, traverse in task order, select destinations, edit a long caption, navigate the IME, move/remove photos without dragging, edit descriptions, compare/reset an override, expand a review, hear one result announcement, open and cancel the confirmation dialog, and undo a manual mark after the snackbar is gone. Check focus restoration and that disabled actions have an adjacent reason. System Back first closes keyboard/dialog, then flushes/navigation. Test reduced motion, large display scaling, long handles, selection handles and continuous composing text. Fix clipping by reflow/scroll, never shrinking fonts or dropping labels.
- [ ] **Step 4: Validate real process-death recovery with synthetic data.** On an authorized disposable test install create an owned two-photo draft, reach Saved, force-stop using `adb shell am force-stop org.example.crossposting`, and relaunch. Confirm text/versions/order/stage and packages. Remove original picker files/access and reopen. Repeat while importing, saving, exporting, uploading, immediately before dispatch and after the durable dispatch marker using injected fake transport. Expected: only committed revisions claimed saved, prior complete content retained, files still referenced preserved, pending sends not automatically resumed, dispatched requests unknown unless exact provider evidence resolves them. Use fake full-storage/write failures instead of filling the user's device. Android "Don't keep activities" is additional testing, not equivalent to process death.
- [ ] **Step 5: Run the integrated checks.** Set `CAPTION_TEST_DEVICE` to the authorized test device ID from `flutter devices`. In PowerShell, fail early with `if (-not $env:CAPTION_TEST_DEVICE) { throw 'Select the authorized test device first.' }`. From app run `flutter analyze`; `flutter test`; `flutter test integration_test/local_recovery_test.dart -d $env:CAPTION_TEST_DEVICE`; `flutter test integration_test/mixed_results_test.dart -d $env:CAPTION_TEST_DEVICE`. Never present these commands as executed without a device result. Integrated tests use fake providers and generated media unless separate live-test authorization exists. The manual fallback into Instagram is human-operated.
- [ ] **Step 6: Commit verified fixes, tests and evidence** with message `test: validate Caption accessibility and interrupted workflows`. Report unavailable device checks as unavailable, not passed based on mock contrast numbers.

### Task R2: Verify credential boundaries, backup policy and permissions

**Files:** Create `app/lib/core/safe_errors.dart`, `app/test/core/safe_errors_test.dart`, `app/android/app/src/main/res/xml/{backup_rules,data_extraction_rules}.xml`, `docs/engineering/privacy-and-storage.md`; modify AndroidManifest.xml and only the error boundaries that still expose exception details.

**Interfaces:** `String userSafeMessage(String reasonCode)` maps a small allowlist to stable UX copy, never takes raw response bodies or tokens. Existing credential vault remains the only OAuth/DPoP persistence port. Diagnostics may record operation/destination/reason codes; no caption, file path, handle, token or full URL/query.

- [ ] **Step 1: Test unknown errors cannot echo private payloads.**

```dart
test('unrecognized server detail cannot enter the UI message', () {
  final message = userSafeMessage('access_token=secret-caption-and-key');
  expect(message, 'Something interrupted this action. Your saved work is still available.');
  expect(message, isNot(contains('secret-caption')));
});
```

Run `flutter test test/core/safe_errors_test.dart`; expect missing mapper. Implement a literal switch over reason codes, including connection-needed, storage-failed, rate-limited, access-unavailable, and unknown. The generic saved-work sentence is used only where there is a known committed snapshot; failed-save screens keep their specific `Couldn't save — keep this screen open` warning. Do not use the generic message to imply unsaved text is durable.

```dart
String userSafeMessage(String reasonCode) => switch (reasonCode) {
  'connection-needed' => 'Reconnect this account before publishing.',
  'storage-failed' => "Couldn't save — keep this screen open",
  'rate-limited' => 'This service needs you to wait before trying again.',
  'access-unavailable' => 'Publishing access is unavailable for this account.',
  _ => 'Something interrupted this action. Your saved work is still available.',
};
```

- [ ] **Step 2: Declare backup/data-transfer exclusions.** Set `android:allowBackup="false"`, reference the rules below and explicitly exclude root/file/database/sharedpref/external paths for cloud backup and device transfer on supported Android versions. Keep OS-backed credential configuration consistent with flutter_secure_storage's pinned version; don't back up encrypted data that cannot be decrypted without the original key.

```xml
<!-- backup_rules.xml -->
<full-backup-content>
  <exclude domain="root" path="."/>
  <exclude domain="file" path="."/>
  <exclude domain="database" path="."/>
  <exclude domain="sharedpref" path="."/>
  <exclude domain="external" path="."/>
</full-backup-content>
```

For `data_extraction_rules.xml`, use a `<data-extraction-rules>` root containing `<cloud-backup>` and `<device-transfer>`, each with the same five explicit excludes. Document that drafts are local, uninstall/clear-data loses them, and cloud backup is outside this MVP. Verify actual supported-device behavior; OEM transfer differences cannot be ruled out by XML inspection alone.
- [ ] **Step 3: Review network and native boundaries.** Set `android:usesCleartextTraffic="false"`; request only permissions needed by the supported picker, network and export paths. No broad storage or QUERY_ALL_PACKAGES permission. Verify FileProvider is non-exported with read-only temporary URI grants and a narrow package path. OAuth callbacks match exact configured scheme/host/path and pending state; untrusted incoming URLs cannot cause a publish, arbitrary file export or token exfiltration. Credential loss/Keystore failure returns to reconnect without deleting content. Imported filenames and callbacks cannot escape private roots. The OAuth SDK owns protocol checks; test adapters do not bypass them in production.
- [ ] **Step 4: Inspect storage and logs with synthetic secrets.** Use fake credentials/DPoP values in a test build, trigger failed auth, refresh, failed upload and interrupted send, then confirm values are absent from ordinary SQLite draft/attempt/package tables, crash-visible messages and log output. Never dump a real user's vault or paste actual tokens into the report. Confirm browsing the local library makes no network call and reads no clipboard or unrelated gallery files. Test account disconnect and reinstall on a disposable install only.
- [ ] **Step 5: Run the new test plus affected account/provider tests, then commit** with message `fix: enforce private credential and backup boundaries`.

### Task R3: Make builds repeatable and prepare the open-source release handoff

**Files:** Create `app/.flutter-version`, `.github/workflows/flutter.yml` if GitHub is selected, `README.md`, `CONTRIBUTING.md`, `docs/release/{setup,signing,release-checklist,costs}.md`; create `LICENSE` only after license/owner selection. Retain the font OFL. Modify root/app ignore files narrowly to exclude local keys/config.

**Interfaces:** Consumes exact SDK/package lockfiles and completed capability/device evidence. Produces reproducible build instructions and a release checklist. Does not publish source, release an APK or enroll in an app store.

- [ ] **Step 1: Resolve release-only decisions and record them.** Confirm final application name/package ID, open-source license/copyright owner, intended initial distribution (personal APK, direct open-source release, or Play), OAuth callback/static metadata domain ownership and X billing model. If the namespace changes, update Kotlin directories, manifests, tests, redirect registrations and docs as one reviewed change. Do not ship org.example as the final identity or select a license merely because a file is missing. Remaining undecided items block public release, not local acceptance testing.
- [ ] **Step 2: Record and reproduce the locked toolchain.** In app run:

```powershell
$flutterInfo = flutter --version --machine | ConvertFrom-Json
$flutterInfo.frameworkVersion | Set-Content -LiteralPath '.flutter-version'
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --debug
```

These are future execution commands, not commands run during plan writing. Compare generated-file changes and lockfile on a second clean checkout. Record Java/Android SDK versions needed by the selected Flutter toolchain. Any new generation drift is fixed rather than ignored.
- [ ] **Step 3: Add a read-only CI validation workflow if the repository uses GitHub.** Initial reviewed workflow shape:

```yaml
name: Flutter checks
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - id: sdk
        shell: bash
        run: echo "version=$(cat app/.flutter-version)" >> "$GITHUB_OUTPUT"
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ steps.sdk.outputs.version }}
          cache: true
      - run: flutter pub get
        working-directory: app
      - run: dart run build_runner build --delete-conflicting-outputs
        working-directory: app
      - run: git diff --exit-code
      - run: flutter analyze
        working-directory: app
      - run: flutter test
        working-directory: app
      - run: flutter build apk --debug
        working-directory: app
```

Resolve the chosen action releases to reviewed immutable SHAs for the final workflow; use the JDK version actually verified in toolchain.md if different from 17. CI contains no provider credentials, release signing key, paid API test, deployment or write token. Fork PRs run the same fake-transport tests safely. Public release/signing is a separate manually authorized workflow, not an automatic consequence of a passing build.
- [ ] **Step 4: Write actionable setup, maintenance and cost documentation.** README explains Android scope, assisted Instagram, supported/unsupported media, local-data loss conditions, and actual verified features. setup.md lists SDK install/pinned version, `flutter pub get`, generation/test/build/run commands, public X client ID and Bluesky metadata/redirect setup, and safe secret storage. Explain developer setup separately from ordinary account connection. costs.md separates app hosting/static metadata costs from current X API fees, links to official prices and dates the estimate; avoid promising a permanently free API. CONTRIBUTING explains modules, provider fake tests and accessibility requirements. No user has to operate an app backend unless that architecture change was explicitly accepted.
- [ ] **Step 5: Prepare signing without leaking keys or distributing artifacts.** signing.md explains generating/owning a release keystore, local/environment-based signing configuration, secure backup, and signature continuity for updates. `.gitignore` excludes keystores, key.properties, local.properties, private environment files and captured account data. LICENSE uses the selected license's full official text and actual owner; retain third-party notices and font OFL. Do not include stock mockup media or accounts in the released app. The checklist names Play verification/testing or direct-download update responsibilities appropriate to the selected channel. No enrollment fee is paid by this task.
- [ ] **Step 6: Verify the handoff and commit** with message `docs: prepare reproducible open-source Android release`. On a clean checkout follow setup exactly; run the documented checks and build a local candidate only after signing authorization. Report unresolved gates, device coverage and supported provider formats. Do not upload the APK, create a public release, push commits or submit to a store without the corresponding user instruction.

## Release readiness decision

All required local/device checks, provider evidence and manual Instagram fallback must pass. If direct video or a provider remains unavailable, present the exact scope difference for review instead of declaring the original MVP complete. A release candidate is not a deployed product, and a passing test suite is not proof of actual publication on a social platform.
