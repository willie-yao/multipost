# Android acceptance — Caption

Evidence date: **2026-11-17**. The R1 commit containing this record adds acceptance coverage and the concrete visual/reflow fixes found by it, based on `08f6846a70d9d0ecb0ac7b96a47af1eddbf2abb0`. Production provider gates remain unchanged. Live X/Bluesky publishing and Instagram receiving-app acceptance remain unavailable.

## Executed environment and source identities

- Flutter **3.50.0**, framework `ab2912035e160d9cad6306df307576da6128ebdb`, engine `371f77202a73e8dff57a8b3bff75bca55c090aee`, Dart **3.14.0**.
- Owned AVD `caption_local_api29`, device `emulator-5582`, model **Android SDK built for x86_64**, Android **10 / API 29**, physical **1080×2400**, density **420**. No personal device or second AVD was used.
- Both APKs were built with the AVD off, process-local Gradle caps (1536 MiB daemon heap, 768 MiB metaspace, 256 MiB code cache, one worker, no parallel build, Kotlin in-process; wrapper heap 512 MiB). The AVD ran hidden with 2 cores / 2048 MiB, software GPU and no snapshot load/save.
- Native runs used the official minimal integration driver, a prebuilt debug APK, DDS disabled, preserved app data, and the documented runtime **Skia** override. This does not establish default Impeller or hardware performance acceptance.

| Frozen artifact | Build | APK SHA256 | 118-input manifest SHA256 |
| --- | --- | --- | --- |
| Recovery: `local_recovery_test.dart`, including the initial matrix | PASS, 200.6s, exit 0 | `B1B2F68893F4082F515FA0B639B4EB22C3F5FC84088AB432B6B652A691204688` | `8C48BB55CEA62F7F3FCD170899FC5054E6BF2A0CB14D10EC976E0009DF838C02` |
| Corrected visual-only: `mixed_results_test.dart` | PASS, 208.2s, exit 0 | `9575368B5B05BC199BCC8D63903B5C875BD6E97BB8EF180ABEFF2E11828F1B9F` | `4CA6B9700AD0EA75CC12598EE32CD81BC26F6B54C36CAEBA364B6A95940E0312` |

All 118 recovery inputs matched their manifest before the capture-only correction. The two builds differ only in `integration_test/mixed_results_test.dart`: the correction waits for settled/rendered frames and asserts visible target geometry/hit-testing. Production sources are identical. All 118 final visual inputs matched their manifest during the corrected run; both frozen APKs were retained separately. The final visual test source SHA256 is `10493EAE387612BF2B387B878C968F109A4E67D91794B761900D7A4720304C4A`.

## Observed acceptance

| Acceptance case | Observed result and evidence | Practical limit |
| --- | --- | --- |
| First run/Choose at 320×720 and 720×320, 200% text | Host real Library creation/Choose selection, reachable labeled actions, Android target guideline and leading Back geometry | Host semantics/layout do not establish TalkBack focus or OS display scaling |
| Black top inset/full-width first-run stage | Rendered RGBA sampling plus inspected native ADB first-run full frame; real status/navigation chrome black | Stage width is the constrained 390 dp surface; widget PNGs alone omit system chrome |
| Write, own version, comparison/reset, media, Review, Accounts, Results | Host interaction coverage at both enlarged-text sizes: preserved emoji/Japanese/Arabic composing value, comparison/reset cancel, non-drag ordering/removal and saved descriptions, enabled Review/reachable Results action | Host IME protocol; real selection handles/keyboard traversal remain manual |
| Unknown final-risk flow | Actual Library→Results→scoped Review/coordinator; cancel, System Back, reentry, true SQLite close/reopen, then a fresh explicit accept; only Bluesky resent, X stayed frozen | Synthetic external publishers/direct validation; no live provider claim |
| Late browser response after disconnect/repair | Existing X tests await `authorizeStarted` and assert one authorization call before invalidation, then complete the late response | Synthetic OAuth/vault; earlier immediate invalidation did not prove the late-response path |
| Native mixed states/representative sizes | Corrected visual-only official driver **PASS, exit 0**, 2m 59s body; 31 widget PNGs; 4 scrolled target assertions and 4 distinct before/after image pairs | Synthetic accounts/media/providers. See [visual acceptance](visual-acceptance.md) for exact captured cases |
| Native process death | Six official driver launches, each **exit 0**, markers 1→6, with 5 actual force-stops and distinct app PIDs | Actual SQLite/media/journal/process lifetime; held import/save/export/provider boundaries are synthetic |
| Real TalkBack order/focus/audible announcements, native IME/selection handles and OS font/display scaling | **Unavailable** | Requires manual/device acceptance; host semantics and MediaQuery text 2 are insufficient |
| Live provider authorization/entitlements/upload/publication; Instagram photo/carousel receipt | **Unavailable** | No live accounts/posting or receiving-app testing performed |
| Default Impeller/API 36 artifact/hardware performance | **Unavailable** | API 29 Skia cannot resolve prior API 36 green-frame/EGL issues; renderer/frame warnings remain in logs |

## Actual force-stop chain

The recovery APK was built once. The official driver reinstalled that identical frozen binary while preserving app data on each of six launches with `--no-uninstall-first --keep-app-running`. Each completed test acknowledges a checkpoint with deliberately held fixture work. A marker alone is not a passing test result. Between phases, exact AVD/marker/PID were checked, `am force-stop org.example.crossposting` ran, and `pidof` was empty with exit 1 before relaunch. No app data reset or six-phase retry occurred.

| Phase / PID | Durable checkpoint and next-launch observation | Official exit |
| --- | --- | --- |
| 0 / 3153 | Saved revision 0 owned two-photo draft, own caption/reversed order/Review stage, immutable package; original picker files removed; real import journal had 1 imported / 1 held item; next 1 | 0 |
| 1 / 3457 | Retained content/package/order/hashes/partial import after kill; synthetic pending sources removed/import canceled; newer revision 1 held before commit with Saving/savedRevision 0/durable revision 0; next 2 | 0 |
| 2 / 3560 | Prior complete revision retained/import resolved; 2 real export jobs committed before held fake transfer, no saved URI evidence; next 3 | 0 |
| 3 / 3652 | Export jobs/package retained; synthetic provider upload state durable, preparing/no dispatch, held; next 4 | 0 |
| 4 / 3799 | Prior attempt recovered Pending/no dispatch with upload state/no startup sends; another attempt held after real durable markDispatch; next 5 | 0 |
| 5 / 3893 | Prior Pending versus post-dispatch Unknown (`interrupted-after-dispatch`), retained upload/content/package/hashes; fresh sends 0; next 6 and DB closed | 0 |

Export evidence is **fake transfer plus real job journal and process death**, not real MediaStore pending-row or receiving-app crash acceptance. No test filled storage. Existing bounded injected storage/write-failure checks do not establish native full-storage behavior. Native pending rows, revocation/deletion, null-stream/zero-update/full-storage branches and API 30+ trash behavior retain their earlier unverified limits.

## Commands and local evidence

From `app`, after selecting and verifying the authorized task device and loading the task-local SDK environment:

```powershell
if (-not $env:CAPTION_TEST_DEVICE) { throw 'Select the authorized test device first.' }
flutter test --reporter expanded
flutter analyze --no-pub
# Prebuild with AVD off; freeze/copy each successful APK before booting.
flutter build apk --debug --no-pub --target=integration_test/local_recovery_test.dart
flutter drive --no-pub --no-dds --keep-app-running --no-uninstall-first --no-enable-impeller --use-application-binary=<frozen-recovery-apk> --driver=test_driver/integration_test.dart --target=integration_test/local_recovery_test.dart -d $env:CAPTION_TEST_DEVICE
# Separate approved capture-only build/pass; do not rerun recovery phases.
flutter build apk --debug --no-pub --target=integration_test/mixed_results_test.dart
flutter drive --no-pub --no-dds --keep-app-running --no-uninstall-first --no-enable-impeller --use-application-binary=<frozen-visual-apk> --driver=test_driver/integration_test.dart --target=integration_test/mixed_results_test.dart -d $env:CAPTION_TEST_DEVICE
```

The recovery drive command ran 6 times using the same APK, with explicit force-stop/checkpoint verification between calls. The visual drive command ran once after its separate test-only rebuild. These are actual official-driver results; no separate `flutter test -d` result is claimed.

Final settled host verification with the AVD off: `flutter test --reporter expanded` **532 passed, 1m 45s test body, exit 0** (122.22s command wall time). `flutter analyze --no-pub`: **No issues found, 63.8s, exit 0**. Scoped formatter verification covered 20 changed/new Dart files with 0 changes; the preexisting formatting of `retry_edits_test.dart` was retained around its two name corrections. `git diff --check` passed. All 118 final build inputs still matched after these checks.

Full logs, input manifests, original/corrected captures, frozen source/synthetic recovery archives and the detailed Task 19 report remain **local-only**, under `.superpowers/sdd/2026-11-16-flutter-caption-mvp/` in the authorized worktree. They follow the repository's existing ignored-evidence convention and are not required files in a clean clone. Frozen test APKs remain local under ignored `.tools/`; they are integration fixtures, not a release or ordinary-app handoff.

Only verified `files/r1-native-recovery`, `files/r1-native-visual` and `files/r1-native-captures` task roots were cleaned. An initial cleanup guard found the old completed recovery root after the visual AVD boot; its exact package/marker 6 were verified before removing that task root again. The final pre-shutdown inventory preserved preexisting I2/I4/P7/main app files; the synthetic app was force-stopped, owned AVD shut down, ADB devices empty and owned emulator processes 0. This is point-in-time cleanup evidence, not proof after another AVD boot; no extra cleanup-only emulator launch was performed. No shared ADB restart, main DB/gallery reset or OS font/density change occurred. Reproduction must inspect completed fixture markers before a new recovery batch; never clear the whole app to bypass a completed marker.
