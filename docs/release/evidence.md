# Local implementation and release evidence

Recorded 2026-11-17. This is portable repository evidence, independent of ignored
session reports. It does not declare the full three-provider MVP complete or
authorize public release. The [release checklist](release-checklist.md) preserves
outstanding identity, license-holder, distribution, provider and device gates.

## Existing accepted implementation evidence

| Source/evidence | Scope and limits |
| --- | --- |
| R1 native acceptance recorded in [Android acceptance](../testing/android-acceptance.md) and [visual acceptance](../testing/visual-acceptance.md) | API 29 x86_64 owned emulator, Skia runtime override; six official process-death fixture launches and one corrected visual-only pass, 31 widget captures. Synthetic media/accounts/providers. Representative 320 dp/200% and landscape reflow, not real TalkBack/OS display scaling/default Impeller/hardware acceptance. |
| R2 source `fecd340a32b45c61ec02303feed6de07cfde0ff6` | Safe UI error boundaries, app-private content versus credential-vault separation, explicit backup/data-transfer exclusions and narrow release AppAuth logging removal. 391 affected host tests and 6 debug JVM tests passed at that task; these are prior scoped results, not the R3 full suite. |
| R2 minified x64 evaluation APK | SHA256 `98ede8ec6a4516a0a2008bab6fc90ae980403bafdee752782808499305330a48`, 23,841,283 bytes; ordinary main entrypoint but reserved public fixture metadata and debug signing. It is an optimizer/privacy evaluation, not the final ordinary app or a public release. |

R2 inspected the actual merged/compiled manifest and every packaged DEX table:
backup and cleartext disabled, all five backup/transfer data domains excluded,
no broad storage/QUERY_ALL_PACKAGES permission, and a non-exported
instagram-packages-only FileProvider. AppAuth Logger type/method references,
state-warning strings and logging tag were absent from the minified DEX, while
AuthorizationManagementActivity remained. This is compiled-artifact evidence,
not execution of a live callback, device logcat, OEM migration or a guarantee
about every dependency's logging. Debug builds retain AppAuth's upstream logging
risk and must use synthetic OAuth material only. See
[privacy and storage](../engineering/privacy-and-storage.md).

The first R2 `--release --no-pub` evaluation inherited a debug/integration plugin
registrant and failed against excluded dev-only `integration_test`. The normal
supported `flutter build apk --release` path regenerated the mode-specific
registrant and passed without changing dependencies or generated/SDK source by
hand. All reproduction builds use supported Flutter tooling generation.

## Formats and acceptance boundaries

Local import validates nonanimated JPEG/PNG/WebP; recognized MP4, QuickTime and
WebM containers require a successful native device probe. Photo transforms
produce owned files. Instagram's independent feed policy accepts 1–20 JPEG/PNG
photos. WebP must be replaced for Instagram; GIF/HEIC/animations, Instagram video,
Reels and Stories are unsupported. Shared video draft handling does not establish
accepted X/Bluesky video publishing.

Direct providers retain dated documentary JPEG/PNG profiles (up to 4 images) and
closed production connection gates. X weighted text/native parser and Bluesky
SDK transports, DPoP/session boundaries, upload/create/reconcile/retry behavior
have fake transport coverage. Documentary limits and synthetic success do not
prove account entitlements or real text/photo/video upload/publication. No live
provider account was connected or charged here. Instagram receipt/manual return,
real TalkBack/IME/OS text scaling, native full-storage and OEM migration acceptance
remain unavailable. No new emulator run is required for this documentation and
build handoff.

## R3 clean source reproduction and ordinary app

The verified application source is commit
`dff67897744812737fb202e2cb1ee8bfccf853ed`, app tree
`695e4640bbf6f111e412fd8d596954296fde93ef`. This evidence is recorded in a
subsequent documentation-only commit; application inputs are unchanged.

A fresh tracked/new-source export under the owned `.tools/tmp` root copied and
SHA256-verified 398 source files. It began without app build/.dart_tool outputs,
local.properties, wrapper launchers/JAR or generated registrants. It used the
same pinned installed tools and Pub/Gradle download caches, without copying prior
app build outputs. After the checks, all 208 app source files matched both the
workspace and an archive of the exact source commit byte for byte. The local app
input manifest SHA256 is
`803EF09FF546903863F317952B7F49F56A0D5520F2F7CD0E2DF24655DE45F459`.
The ignored manifest/logs are supplementary; the source commit and
[setup commands](setup.md) are sufficient to repeat the checks.

| Clean export check | Result |
| --- | --- |
| `flutter pub get --enforce-lockfile` | PASS, no lockfile change |
| `dart run build_runner build` | PASS; all 8 tracked Freezed/JSON files and pubspec.lock match the first workspace generation |
| `flutter analyze` | PASS, no issues |
| `flutter test --reporter expanded` | PASS, 549 tests; 1m14s test body / 111.656s wall |
| `flutter build apk --debug --target lib/main.dart` | PASS; 324.7s Gradle / 328.991s wall |
| `:app:testDebugUnitTest --offline --max-workers=1 -Ptarget-platform=android-x64` | PASS; 6 tests, 0 failures/errors/skips; 43s Gradle / 43.883s wall |

The first workspace generation used the historical
`--delete-conflicting-outputs` flag; pinned build_runner 2.17.1 warned that it was
removed and ignored it. The clean reproduction and setup use supported plain
`build`. Both passes matched every tracked generated file and the lockfile.
Pub advertised 8 newer incompatible package versions; none was upgraded.

Successful assembly is not warning-free toolchain acceptance. The pinned
`flutter_web_auth_2` plugin triggers Flutter's future Built-in Kotlin migration
warning. The JVM invocation also reports deprecated `android.builtInKotlin=false`
and `android.newDsl=false`, obsolete `applicationVariants`, `testVariants`,
`unitTestVariants` and `libraryVariants` APIs, and deprecated
`org.jetbrains.kotlin.android` application in the app/dependency projects. AGP
warns these legacy options/APIs will be removed in 10.0. Gradle emits an
incubating problems report and suggests its optional configuration cache. The
existing test-resource declaration now sits inside the Android block; its prior
deprecated Project.android accessor warning was not observed. No warning
suppression, plugin upgrade or toolchain migration was added.

The ordinary local handoff APK is frozen at
`.tools/task21-caption-main-debug.apk`; the same verified bytes were copied to
`app/build/app/outputs/flutter-apk/app-debug.apk` after preserving the old visual
integration APK separately. It is not uploaded or included in source commits.

| Artifact field | Verified value |
| --- | --- |
| Source / entrypoint | Source commit above; `lib/main.dart` |
| Build | Debug, default targets; no Dart define or define-file arguments |
| Public metadata | Unconfigured defaults; generated native callback strings empty and both compiled X/Bluesky receivers disabled |
| Package / version | `org.example.crossposting`, `0.1.0+1`, min API 29 / target API 36 |
| Included native ABIs | arm64-v8a, armeabi-v7a, x86_64; compilation does not prove physical-device acceptance |
| Signer | Android Debug (`C=US, O=Android, CN=Android Debug`); debuggable/development only |
| Bytes | 198,917,011 |
| APK SHA256 | `62ED430F264718EB6FA53BF2695A38D18EDEF3F8A80D51341CA8176BB989F0FB` |
| Debug certificate SHA256 | `04dff4fb727d7b43b4f77cf71d6c96ed6ed9d7f6b0ec1ca83ce80213b95e43b9` |

Android build-tools 36.0.0 `aapt2 dump badging`, compiled manifest `xmltree` and
`apksigner verify --verbose --print-certs` each exited 0 on the frozen artifact.
This establishes build/configuration/signature identity, not installation or
live-provider/renderer acceptance. The clean export's artifact is the handoff;
no duplicate assembly was run solely to attach a later commit number. This is
repeatable source/generation/build evidence, not a byte-identical APK claim
across machines, paths, timestamps or debug keystores. The AVD stayed off and no
native/device acceptance was repeated.


## Final correction wave and current ordinary app

The current application source is commit `69001de07526609f419cabda40c0b94057952e69`, app tree
`8cc5e8305093cd3836bcaac9583180cbe98fccb1`. It corrects frozen retry-owned
continuation, serializes full Instagram integrity decoding per service instance,
and includes the final review's picker, copy, cleanup and setup corrections.
Original draft retries and full integrity validation remain supported.

The R3 clean-export section above remains historical evidence for dff6789 and its
preserved `.tools/task21-caption-main-debug.apk`. It does not validate this changed
application source. This bounded correction reused the accepted workspace and
installed tools/caches; a new clean export, generator/JVM pass or device/emulator
run was not performed. Earlier native/JVM/generation evidence retains its stated
scope and limits.

| Current correction check | Result |
| --- | --- |
| `flutter test --reporter expanded` | PASS, 560 tests; 1m21s test body / 90.676s wall |
| `flutter analyze` | PASS, no issues; 40.490s wall |
| `dart format --output=none --set-exit-if-changed` on all 15 touched Dart files | PASS, 0 changes |
| `flutter build apk --debug --target lib/main.dart` | PASS; 161.8s Gradle / 166.225s wall |
| Post-build tracked app input proof | All 208 files match the checked input manifest, workspace and exact code-commit archive; 0 mismatches |

The checked input manifest SHA256 is
`B89461F945E92E35D84DD4281C36F9C0FE86A03FAA791B3D450A803194A23EC1`.
The ordinary build used Flutter 3.50.0 / Dart 3.14.0 and the existing process-local
JDK/SDK/cache and memory-cap setup in [setup](setup.md), with no Dart define or
define-file arguments. No lockfile or generated app source changed during checks
or assembly. The existing flutter_web_auth_2 Built-in Kotlin migration warning
remains; this correction does not upgrade the pinned toolchain.

The current ordinary debug artifact is `.tools/final-fix-caption-main-debug.apk`:

| Artifact field | Verified value |
| --- | --- |
| Source / entrypoint | `69001de07526609f419cabda40c0b94057952e69`; `lib/main.dart` |
| Build / configuration | Debug, default targets, no public metadata configured |
| Provider callbacks | Compiled X and Bluesky callback activities disabled; generated native redirect strings empty |
| Package / version | `org.example.crossposting`, `0.1.0+1`, min API 29 / target API 36 |
| Included native ABIs | arm64-v8a, armeabi-v7a, x86_64 |
| Signer | Android Debug, development only; debuggable=true |
| Bytes | 255,989,378 |
| APK SHA256 | `C66F4FDB76CE63579FC19601DF5AB058E4336ACBFFEFF6F1B740D1A971084267` |
| Debug certificate SHA256 | `04dff4fb727d7b43b4f77cf71d6c96ed6ed9d7f6b0ec1ca83ce80213b95e43b9` |

Build-tools 36.0.0 aapt2 badging/compiled-manifest and apksigner verification each
exited 0 on these exact frozen bytes. The larger incremental workspace APK has
450 indexed ZIP members with 198,776,869 compressed member bytes, compared with
450 / 198,775,748 in the earlier clean-export APK; unused regions between ZIP
members account for the large file-size difference. This is the actual default
build output, not a byte-identical or fresh-export reproduction claim. No second
assembly was run solely to change packaging size or attach a documentation SHA.
The prior R3 artifact/hash is unchanged.

These host/build/configuration checks do not establish device, native fault,
TalkBack/IME/default renderer, live-provider, Instagram receiving-app or public
release acceptance. The [release checklist](release-checklist.md) still owns
identity, MIT holder, signing, distribution and external acceptance gates. A
subsequent evidence-only documentation commit leaves the application tree above
unchanged and does not require another build.
