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
