# Caption for Android

Caption is a human-operated personal posting app built with Flutter. Compose a
shared post, choose destinations, make independent caption/media overrides and
review each destination before taking action. Drafts and imported media stay on
the current Android installation; there is no Caption backend to operate.

This repository contains a local development implementation, not a public release
or a completed three-provider MVP. Android 10 / API 29 is the provisional floor.
X and Bluesky production connection and publishing remain unavailable, even when
public build metadata is supplied. No live account or paid API acceptance is
claimed. The development app name is **Caption**; the final public name and
application ID are still release decisions.

## What works locally

- Offline draft library, owned media import, durable saves/recovery, shared text
  and independent destination text/media, descriptions, crop/rotation for photos,
  Choose → Write → Review, and immutable submission snapshots.
- Instagram feed-photo preparation with numbered owned photos and a caption,
  explicit save/copy fallback, and a manual posting journal with Undo. The user
  finishes publication in Instagram. Opening Instagram, opening a chooser or
  handing off files never proves publication. Real receiving-app photo/carousel
  acceptance remains outstanding.
- Durable per-destination attempt/result/retry logic, including interrupted
  Pending versus Unknown states, exercised with fake providers. There is no
  automatic resend on startup or network return. A submitted source draft ID
  reopens its existing result even after edits; use a new draft for a new post.
  Explicit destination retries create child snapshots and preserve prior results.

Local photo import accepts nonanimated JPEG, PNG and WebP after validation;
Instagram preparation accepts JPEG/PNG feed photos (1–20), not WebP, video, Reels
or Stories. MP4, QuickTime and WebM containers are recognized for shared drafts
only when native device probing succeeds; direct-provider video availability
remains blocked. GIF/animated images, HEIC and unidentified formats are rejected.
X/Bluesky documented JPEG/PNG photo profiles and fake transport
coverage are not production upload support. See [current evidence](docs/release/evidence.md)
for the exact limits and provider/device distinctions.

## Develop and verify

Follow [setup](docs/release/setup.md) for Flutter **3.50.0**, locked dependencies,
code generation, analysis, tests and the ordinary `lib/main.dart` debug build.
The [toolchain record](docs/engineering/toolchain.md) includes archive hashes.
[CONTRIBUTING](CONTRIBUTING.md) explains the feature boundaries and accessibility
requirements. No developer account or provider metadata is needed for local
drafting or the fake transport suite.

Clearing app data or uninstalling loses the local library and connections. There
is no cloud backup/sync or supported device-transfer promise. Saved gallery photos
and clipboard copies have their own OS/user backup lifetimes. See
[privacy and storage](docs/engineering/privacy-and-storage.md).

Before distributing anything, complete the [release checklist](docs/release/release-checklist.md),
[signing handoff](docs/release/signing.md) and [ownership/cost decisions](docs/release/costs.md).
This repository has no remote or selected hosting platform; CI has not been
configured. Local checks do not publish source or APKs.

## License and design references

MIT was selected on 2026-11-17. The copyright-holder name is still awaiting the
owner's answer, so the final `LICENSE` is pending and public source release is
blocked. Do not infer the holder from a workstation username or treat this
selection as a completed license grant. Retain the bundled Atkinson Hyperlegible
Next [OFL](app/assets/fonts/AtkinsonHyperlegibleNext-OFL.txt), Android
[twitter-text notice](app/android/app/src/main/assets/licenses/twitter-text-LICENSE.txt)
and dependency notices; MIT does not replace third-party terms.

`PRODUCT.md` and `docs/design/` preserve the product/design history. Native and
host evidence lives in tracked `docs/testing/` and the compact release evidence
record; ignored local session logs are supplementary and are not required to
build a clean checkout. Mockup media/accounts are illustrative and are not app
runtime assets.
