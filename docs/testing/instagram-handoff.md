# Instagram launch and photo handoff evidence

Recorded 2026-11-16 for I3. This is assisted, human-operated feed-photo work.
Opening an app, showing a chooser, sending an identifiable intent, and a user's
later confirmation are separate activities. None verifies publication.

## Shipped behavior

- `InstagramService.open(packageId)` records `opened` only after Android accepts
  Instagram's package launch intent. It creates a new launch identity while
  preserving the current ready/handed-off/user-marked state.
- An absent app shows **Open Instagram yourself** with the gallery and caption
  fallback. Copy caption and save/retry photos remain separate explicit actions.
- `InstagramShareCapability` defaults to `singlePhoto=false`, `carousel=false`.
  An enabled path requires a date, device description and Instagram version.
  Production composition supplies no receiving-app evidence and enables neither.
- If a supported path is deliberately composed later, all prepared photos are
  validated, kept in order and sent using `ACTION_SEND` or `ACTION_SEND_MULTIPLE`.
  The private FileProvider exposes only `filesDir/instagram-packages/`, is not
  exported, and grants temporary read permission with every URI in ClipData.
- Android accepting an intent explicitly targeted at `com.instagram.android`
  records `targetDispatched`. A chooser result can record only `chooserOpened`;
  cancellation, unavailable and failed outcomes record no successful handoff.
  The native implementation currently offers only the targeted path and never
  guesses a chooser target or infers receipt from an app return.
- Caption/description import is never assumed. Resume checks existing gallery
  receipts, does not send files, and does not delete private packages or revoke
  the read grants needed by a receiving activity. Confirmation/return prompts
  are the separate I4 task.

## Observed matrix

| Scenario | Host evidence | Android API29 evidence | Actual Instagram import |
| --- | --- | --- | --- |
| Open app | Configured outcomes, append-only launch identity, pending state preserved | Instagram absent returns unavailable | Pending; app not installed |
| One photo | Adapter preserves one file and exact target requirement | Scoped URI construction and absent target return unavailable | Pending |
| Multiple photos | Adapter sends every ordered file; missing photo blocks whole set | Mixed PNG/JPEG pair processed; corrupt second hash rejects whole request | Pending |
| Wrong/unknown target | Adapter refuses dispatch proof without exact package; repository rejects unidentifiable dispatch events | Native target is fixed to Instagram | Pending |
| Chooser opened/cancelled | Distinct results; chooser stays ready and cancellation records no event | No chooser path enabled | Pending |
| Revoked URI access | Platform access-revoked maps to failed, never dispatch | Receiving-app grant revocation unverified | Pending |
| Return from app switch | Widget lifecycle return never repeats launch/share and stays pending | No automatic send callback installed | Pending |
| Recreation | Database close/reopen preserves launch event, caption and files; new service sends nothing | I2 retained rows15/16 rechecked after app force-stop without recopy | I3 receiver process death pending |
| Private path/hash | Service checks frozen file membership/bytes | Escaping root, dot traversal, wrong package/MIME/hash rejected; export handler remains active | Not receiving-app evidence |

Native protocol runs used only the verified task-local `caption_local_api29`
AOSP emulator (`emulator-5582`), with no Instagram package, account or live post.
The official Flutter driver preserved app data with `--keep-app-running` and
`--no-uninstall-first`; software GLES/Impeller warnings prevent treating those
runs as visual or TalkBack acceptance. No broad media/storage permissions or
package enumeration were added.

## Before enabling a shortcut

A human must test the actual supported photo path on the intended device and
official Instagram version. Record the date, device/OS and Instagram version;
check every photo, order, crop, account choice, caption paste and descriptions.
Check cancellation, return, delayed URI reads and process recreation without
claiming a post was published. Keep the two-photo gallery fallback available.
No supported receiver evidence has been recorded, so both capabilities remain
false. Do not install an unofficial APK or automate Instagram to fill this gap.
