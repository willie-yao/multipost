# Public release checklist

Local implementation and build evidence do not complete the three-provider MVP.
All boxes below describe future public release work unless explicitly completed.
Nothing here authorizes remote creation, push, publication, paid enrollment,
real provider posting or distribution. See [evidence](evidence.md) for local facts.

## Owner decisions blocking public release

- [ ] Confirm the final product name and unique application ID. Caption and
  `org.example.crossposting` remain development identities. If changed, review
  Kotlin directories/packages, manifests/FileProvider authorities, tests,
  callback registration and docs together.
- [x] MIT selected on 2026-11-17.
- [ ] Obtain the actual copyright-holder name; add the complete official MIT
  text to root `LICENSE` with that holder. Do not infer identity or ship a
  placeholder grant. Review ownership of contributed assets/code.
- [ ] Select personal APK, direct open-source download or Play as the initial
  channel; assign a maintainer and update policy. No remote/hosting is selected.
- [ ] Assign owner-controlled callback/static-metadata domain and host, native
  registrations/exact redirects and metadata availability/renewal responsibility.
- [ ] Decide X billing/access responsibility, eligible endpoints, spending limits
  and account entitlement using [current official prices](costs.md). No paid
  request or ordinary-user developer registration is implied.

## Acceptance and clean build

- [ ] Complete actual X/Bluesky native browser cold/warm/cancel, credential
  recovery/rotation, scopes/account entitlement and separately authorized live
  text/photo/video acceptance. Current production gates remain closed. Format
  support must be claimed per provider/account/evidence, not from fake success.
- [ ] Complete actual Instagram feed photo/carousel receipt and save/copy/return
  fallback acceptance. Never infer publication from chooser/open/handoff.
- [ ] Complete real-device TalkBack/focus/audible feedback, native IME/selection,
  OS text/display enlargement through 200%, full-storage/MediaStore failure,
  OEM backup/transfer and default-renderer/hardware acceptance. Preserve the
  API 29/Skia versus API 36/default-renderer distinctions in existing evidence.
- [ ] Re-run [setup](setup.md) from the selected immutable source commit with
  pinned SDK/lockfile and no app build outputs. Record generation/lock equality,
  analyzer/full host suite, JVM checks, build warnings and exact commands.
- [ ] Confirm no test-only fixture entrypoint/configuration is the ordinary app.
  Record `lib/main.dart`, build mode/public defines/source commit/APK SHA256.
  Do not describe repeatable generation as byte-identical APK reproducibility.
- [ ] Reinspect compiled manifest/backup exclusions, permissions, non-exported
  FileProvider scope and minified AppAuth logging removal. Never treat a debug
  build as satisfying the release logging policy.

## Source and signing review

- [ ] Verify `LICENSE`, dependency notices and bundled font OFL are retained.
  The Android twitter-text notice and Flutter dependency license registry also
  remain necessary. Include no stock mockup media, accounts or personal captures
  in runtime assets. Preserve historical design references with honest labels.
- [ ] Review tracked/staged files for secrets, local config, account data,
  captures, SDKs/caches and large fixture archives. `.superpowers` reports are
  local supplementary evidence; clean-clone instructions must not require them.
- [ ] If GitHub is selected later, review a credential-free CI using immutable
  action SHAs, contents:read and checkout persist-credentials:false. Match the
  verified JDK/Flutter/generation/tests/build. No paid calls/signing/deployment
  secrets or automatic release, including from fork pull requests.
- [ ] Authorize and configure real release signing as described in
  [signing](signing.md); verify backups, signer identity, application ID,
  increasing version code and update continuity. Current release type is debug
  signed; there is no production candidate.

## Channel responsibilities after selection

- [ ] For personal/direct APK distribution: verify actual signatures/hashes,
  provide installation/update instructions and trusted download ownership,
  retain signed artifacts/source identities, and define vulnerability/update
  delivery and key-loss handling. Android install-source restrictions still
  apply; do not promise frictionless installation or automatic updates.
- [ ] For Play: complete current developer identity/device verification,
  applicable closed testing/production access, app-signing/upload-key decisions,
  store privacy/Data safety/content declarations, target API and policy checks.
  Confirm current rules/fee through the official links in [costs](costs.md).
- [ ] Obtain explicit authorization for each source push, public release,
  artifact upload or store submission. A local commit/passing build is not that
  authorization. Record final source, signer and artifact hashes after approval.
