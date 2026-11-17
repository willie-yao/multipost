# Instagram gallery fallback checks

Evidence date: 2026-11-16. Development-only `org.example.crossposting`. Synthetic images only; no Instagram app, account, selection/paste receiver test, or publication was available or performed.

## Behavior and boundaries

Copy writes the frozen package caption with `Clipboard.setData`; it never reads the clipboard. A failed write keeps selectable full text and Retry copy. If the write succeeds but recording its activity fails, the message distinguishes those outcomes. A historical copy event is labeled as previous activity, never proof of current clipboard contents.

Photo saves use one durable export job per immutable package/ordinal. The journal exists before native work. Only missing photos are sent on retry. Receipt plus photoSaved activity commit atomically. A derived latest receiptEventId is compared transactionally to reject stale results, including the same URI disappearing and returning. Reconciliation with a durable receipt queries that exact canonical primary-volume MediaStore image URI and verifies its owner before reading bytes, so a valid saved photo survives gallery filename or folder changes. Without a receipt, crash recovery queries only the generated UUID filename, Pictures/CrossPosting/ path and owner. Both paths use streaming SHA-256, include pending rows, and explicitly exclude trashed rows on API30+. A complete pending row can be finalized; incomplete pending bytes are removed. Resume never inserts a row or recopies bytes. Missing/revoked receipts append photoUnavailable, preserving historical saves; explicit Save/Retry can export missing photos later. Private prepared copies and original assets stay retained.

Native input is canonicalized under exactly filesDir/instagram-packages/<UUID>/<01..20>.(png|jpg), with generated job display names and frozen expected hashes. Android's legitimate /data/user/0 and /data/data aliases resolve to the same canonical root. Traversal, outside-root files and arbitrary display names are rejected. The optional channel uri must equal content://media/external_primary/images/media/<positive ID> exactly; alternate authorities/volumes, query strings, fragments and noncanonical item paths are rejected. Changed visible bytes are preserved and reported as a check failure. File I/O is on the exporter worker; channel results return on the main thread. No storage-related permission was added.

## Host evidence

The final guarded host candidate passed 206/206 (the core implementation passed 205/205 before the additional freshness regression). Focused export, adapter and screen tests exercise partial retry ({1,2} then {2}), journal-before-native, journal failure blocking export, native-success/receipt-commit failure recovery, deleted receipt count and explicit retry, stale receipt rejection, damaged source rejection, copy failure/retry/history, clipboard write only, synthetic write/no-space PlatformExceptions, duplicate/foreign jobs, cached integrity futures and bounded preview decode. Full storage/write errors here are injected port/channel failures, not device filesystem exhaustion. Later self-review checks and exact final counts are in task-9-report.md.

Commands use task-local Flutter 3.50.0/Dart 3.14.0, PUB_CACHE and disabled analytics:

```powershell
flutter test --no-pub test/features/instagram/export_test.dart
flutter test --no-pub
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
```

## API29 native evidence

Verified disposable AOSP AVD caption_local_api29, emulator-5582, API29, boot_completed=1. SDK/AVD/user/Gradle/Pub paths stayed inside ignored .tools; only this AVD ran. It used headless/hidden software rendering, 2 CPUs, 2048 MB, no snapshot/audio/boot animation. The test identified its serial using flutter devices before assigning CAPTION_TEST_DEVICE. Task-local Gradle caps: heap1536m, metaspace512m, code cache128m, two workers; Kotlin daemon heap512m. The actual daemon log confirmed those JVM limits.

| Check | Observed outcome |
| --- | --- |
| Two numbered 400x300 PNGs, copy-caption activity, gallery save, recheck, second save | Native assertions passed: two committed content://media/external_primary rows; second save returned no new work; URIs unchanged. |
| Native boundary negatives | Assertions rejected an outside-package source and traversal display name. |
| Process death after native export before receipt recording | Official driver write phase exited0 with rows15/16 exported while SQLite progress was empty; explicit force-stop followed by recovery phase exited0, recovered the exact same URIs and returned no save work. |
| Actual owner/path receipt metadata | Exact row queries confirmed owner org.example.crossposting, generated caption-<jobUUID>-01/02.png names, Pictures/CrossPosting/, is_pending=0. No unrelated gallery query or mutation. |
| Native pending-row finalize/removal, external deletion/revocation, null output stream, zero-row finalization, API30+ query branch | Not device-run in I2; retain as R1 acceptance work. Host deletion/receipt-failure tests do not establish device proof. |
| Full-storage/failed output write | Host injection only; device/host was never deliberately filled. |
| Instagram photo selection order, caption paste, descriptions and publication | Unavailable. No Instagram APK/account was installed or accessed. No publishing authorized. |

A native Flutter-surface capture was inspected at .superpowers/sdd/2026-11-16-flutter-caption-mvp/i2-api29-normal.png. It shows functional controls/count and existing typography/colors. It is not final composition/accessibility acceptance; I4 owns the approved photo/status-first finish composition. No claim about gallery sort order or receiving-app metadata transfer follows from it.

## Runner correction and reproducible paired check

The prescribed `flutter test --no-pub --no-uninstall integration_test/instagram_export_test.dart -d $env:CAPTION_TEST_DEVICE` was attempted. Default DDS intermittently failed to attach (WebSocket closed before headers / later stalled socket). With --no-dds the native normal test body passed, but Flutter test's host golden listener failed streamListen for integration_test.VmServiceProxyGoldenFileComparator; runner exit1 is not a pass. A bounded clean AVD reboot preserved userdata; shared adb and unrelated processes were untouched.

The installed official SDK documentation at .tools/flutter/packages/integration_test/README.md:39-83 documents the minimal app/test_driver/integration_test.dart entrypoint and `flutter drive --driver --target`. That exact two-line driver is committed. Installed commands/drive.dart skips driverService.stop only when --keep-app-running is set; drive_service.dart otherwise uninstalls the app. Therefore the successful paired command explicitly uses --keep-app-running and --no-uninstall-first (drive does not use flutter test's --no-uninstall switch):

```powershell
# Set process-local JAVA_HOME, ANDROID_SDK_ROOT/HOME, ANDROID_USER_HOME,
# ANDROID_AVD_HOME, GRADLE_USER_HOME, PUB_CACHE and PATH as in toolchain.md.
# Verify adb devices, adb -s <serial> emu avd name, API and flutter devices.
# Fail if the exact authorized serial is absent; never choose an arbitrary device.
$env:CAPTION_TEST_DEVICE = 'emulator-5582'
flutter drive --no-pub --no-dds --keep-app-running --no-uninstall-first `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/instagram_export_test.dart `
  --dart-define=I2_PHASE=gap-write -d $env:CAPTION_TEST_DEVICE
adb -s $env:CAPTION_TEST_DEVICE shell am force-stop org.example.crossposting
flutter drive --no-pub --no-dds --keep-app-running --no-uninstall-first `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/instagram_export_test.dart `
  --dart-define=I2_PHASE=gap-recover -d $env:CAPTION_TEST_DEVICE
```

These phases intentionally use operation i2-native-gap-v1 in isolated i2-export-test.db and the real filesDir/instagram-packages root. Run the pair once per fresh disposable fixture; gap-recover expects receipts to be absent before recovery. Never uninstall between phases. They leave synthetic data in the disposable AVD for inspection. Extra gap-pending-complete/gap-incomplete/gap-deleted phases are staged for explicit exact-owned-row setup in R1 and were not run here.

The successful official-drive logs include GLES/Impeller fragment-uniform-limit shader errors on this software AVD. They did not fail the protocol assertions, but those logs are not clean renderer or visual acceptance evidence. R1 should inspect supported renderer options without changing production defaults. API36/modern pending-query behavior, TalkBack, enlarged native layouts and human receiver behavior remain unverified. The final API29 AVD was identity-checked and shut down; userdata was retained.

## Durable receipt regression (I2 fix round 1)

The host regression first failed because the adapter omitted the saved URI; it passed after the optional uri argument was forwarded. The channel mock changes both filename and folder and returns the existing row only through its durable URI. Covering export, adapter and screen checks passed 20/20. The native gap-renamed phase reuses the retained synthetic rows15/16, checks unchanged receipts and no new save activity, and rejects unrelated authority, alternate volume, zero ID, query and fragment inputs. The single coordinated official-drive run exited0 after Kotlin compilation. It preserved content://media/external_primary/images/media/15 and /16, returned no missing-photo save work, added no activity, and passed all five invalid-uri assertions.

API30+ uses version-gated QUERY_ARG_MATCH_TRASHED/MATCH_EXCLUDE alongside QUERY_ARG_MATCH_PENDING/MATCH_INCLUDE. The [official MediaStore reference](https://developer.android.com/reference/android/provider/MediaStore) documents both trash constants as API30; that branch remains source-backed until a modern-device run. No production gallery mutation API was added.

Native setup queried only exact synthetic row15, verified org.example.crossposting ownership and committed state, and changed its display name to i2-renamed-photo.png. API29 ignored the requested folder update; its folder stayed Pictures/CrossPosting/. Therefore device evidence establishes rename survival; folder-change survival is covered by the host channel contract and native source review. No additional move/permission attempts were made. Row16 retained its original generated name. The task AVD was process/AVD-identity checked and shut down, with userdata retained. GLES/Impeller uniform-limit shader errors persist in the successful runner log, so this is not clean visual/renderer acceptance.

The approved regression command (same process-local toolchain environment and data-preserving flags as above) was:

```powershell
flutter drive --no-pub --no-dds --keep-app-running --no-uninstall-first `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/instagram_export_test.dart `
  --dart-define=I2_PHASE=gap-renamed -d $env:CAPTION_TEST_DEVICE
```

This phase requires the retained gap-write/gap-recover synthetic fixture with both receipts already persisted and exact-owned-row rename setup. It adds no production mutation entrypoint and performs no gallery writes during the assertions. Modern API trash filtering, pending/fault branches, TalkBack and receiver acceptance remain pending as listed above. Full analysis passed, and the three touched Dart files passed formatting with zero changes; no full host-suite rerun was requested for this narrow fix.
