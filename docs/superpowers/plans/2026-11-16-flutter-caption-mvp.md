# Flutter Caption MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Android-first Flutter app that preserves Caption v2's reviewed flow, reliably saves local posts, assists personal Instagram posting, and publishes to X and Bluesky through verified official integrations.

**Architecture:** A local-first Flutter application with feature-owned controllers, immutable content models, SQLite transactions, app-owned media files, and OS-backed credential storage. Direct publishers sit behind provider interfaces; Instagram is a separate local preparation and Android sharing workflow. There is no required application backend, cloud draft store, or unattended sending; any discovered service requirement returns to product review.

**Tech Stack:** Flutter stable with bundled Dart >=3.8; Material 3 themed with Caption tokens; built-in ChangeNotifier/ListenableBuilder; SQLite through sqflite; locally bundled Atkinson Hyperlegible Next; Android system photo picker, MediaStore, and FileProvider; official OAuth using vetted libraries.

**Spec:** `PRODUCT.md`; `docs/design/design-review.md` sections 1–6 and 8–10; `docs/design/options-dark/README.md` (Caption v2 and remaining screens); `docs/design/options-dark/a-caption-v2-board.png`; all four `docs/design/options-dark/caption/*-board.png` files. Paths are relative to the repository root. Read both the behavioral brief and current visual references before executing.

## Global Constraints

- "Phone first. The primary user owns an Android phone. Other platforms are an interest for later; no additional launch platform is committed."
- "Individuals who personally compose and publish their own posts. The app is human operated, not an agency dashboard or an AI-agent tool."
- "The user prefers on-device drafts and no server to manage."
- "No unofficial APIs, password collection, browser automation, required AI services, or agent-driven workflows."
- "Instagram MVP preparation covers feed photos and carousels. Instagram video, Reels, and Stories are deferred. Shared-composer video for X and Bluesky remains in scope subject to feasibility."
- "Opening Instagram alone does not advance Ready to share."
- "No automatic resend occurs on app launch or network return."
- "Text and media inheritance are independent."
- "Published snapshots remain immutable."
- "Each screen has one white action."
- "Cyan always marks a destination's own caption."
- "Review separates \"Publish now\" from \"Prepare only\". The button says both: \"Publish & prepare\"."
- "The user finishes publication inside Instagram. Distinguish ready to share, handed off, and user marked as posted. Opening Instagram is not proof of publication."
- "48 × 48dp minimum touch targets, at least 4.5:1 normal-text contrast and 3:1 meaningful component boundaries."
- "Test system text enlargement through 200% without truncating actions or instructions; layouts grow and scroll rather than shrink type."
- No scheduling, analytics, teams, required AI, social feeds, cloud sync, remote edit/delete, or multiple accounts per platform in this plan.
- Current authorization is **planning only**. All unchecked actions below are future work requiring explicit implementation authorization. No SDK installation, scaffold, probe, connection, publication, deployment, or release was performed to write this plan.

---

## 1. Status, precedence, and scope decisions

Prepared 2026-11-16. Caption v2 is the selected design direction; the user reviewed the additional screens positively. This plan operationalizes that direction without claiming a completed visual system or authorizing its execution.

Precedence: current user instructions → Caption v2/remaining-screen behavior → original behavioral brief. The original brief's section 7 and its opening reference to Dispatch/Margin are historical. Do not copy their plum palette, Roboto recommendation, or old compositions. Do not reuse the alternative Contact Sheet or Margin Night treatments.

Repository inspection found an initialized Git repository with **no HEAD commit** and untracked `PRODUCT.md`/`docs/`. There is no Flutter project or installed Flutter/Dart executable found on PATH. Preserve the existing design artifacts. At execution time, use the worktree skill if isolation is wanted; an unborn repository cannot be treated as an ordinary checkout with a base commit. First create an explicitly scoped design/plan baseline or work in the existing directory with authorization. Never stage everything with `git add .`, reset the design files, or run `flutter create` over this root.

Planning defaults (reviewable assumptions, not prior user decisions):

| Decision | Proposed default | Gate |
| --- | --- | --- |
| First target | Android only; Flutter project under `app/` | Other platforms need their own plan. |
| OS floor | Android 10 / API 29 for scoped media export | Verify the user's phone and plugin minimums before platform code. Revise this default if it excludes the primary device. |
| Toolchain | Stable Flutter with Dart >=3.8; record exact SDK and resolved package versions | Do not invent a Flutter version from the static drawings. |
| Theme | Caption dark only for the first implementation milestone | A light theme is separate design work, not an automatic inversion. |
| Accounts | One account for X and one for Bluesky; no app-specific login | A connected account's stable ID is bound to the reviewed snapshot. |
| Media | Ordered photo set or one video per destination | No mixed set, silent cropping, video trimming, or server transcoding. |
| Persistence | SQLite metadata + immutable app-owned files; drafts/attempts separate | No cloud backup; warn about uninstall/data clearing. |
| Background behavior | Foreground posting with durable recovery | No background scheduler or automatic resume/send. |
| Dependencies | Small set, adapters around external SDKs | Vetted maintenance/license/platform compatibility checked before pinning. |
| Distribution identity | Working Dart name `cross_posting_app`; development-only `org.example.crossposting` | Final package ID, name, OAuth redirect ownership, and signing identity must be chosen before provider registration/release. |
| License | Open source required; license selection remains a release decision | Do not invent a copyright owner or silently choose a license for the user. |
| Backup/export | No full draft export in MVP; Copy text recovery included | Adding portable backup requires a scope decision. |

## 2. Execution map: four independently reviewable milestones

Read this parent document for every milestone. Each child has its own file map, interfaces, failing-test examples, implementation excerpts, commands, and commit boundaries. Test examples are normative examples; they are not claims of executed tests. Resolve SDK import/API differences during the first compatibility gate and update the affected contract before dependent work.

| Plan | Deliverable | Prerequisite | Review gate |
| --- | --- | --- | --- |
| [01 — Local drafts and Caption UI](2026-11-16-flutter-caption-01-local.md) | Usable offline first-run/library/Choose/Write/version/Review flow with owned media and durable drafts | Explicit implementation authorization | No lost committed draft; native editor works; no fake account connection or publishing. |
| [02 — Assisted Instagram](2026-11-16-flutter-caption-02-instagram.md) | Complete local prepare/copy/save/manual-finish workflow | Plan 01 | Two-photo fallback succeeds; launch never claims handoff/publication; confirmation is reversible. |
| [03 — Official connections and publishing](2026-11-16-flutter-caption-03-publishing.md) | Real direct providers, immutable attempts, truthful partial results and scoped retry | Plan 01; Plan 02 for mixed-destination acceptance | Official auth, access/cost and media tests pass; no duplicate-prone retry. |
| [04 — Device validation and release readiness](2026-11-16-flutter-caption-04-release.md) | Verified Android candidate and open-source maintenance/release documentation | Plans 01–03 | Accessibility, recovery, privacy, signing and provider evidence reviewed. |

These are dependent product slices, not separate services. Stop a blocked provider task without discarding useful local work. A milestone with disabled providers is a partial milestone, not completion of the full three-destination MVP.

### Decision gates

1. **Before SDK/platform code:** confirm execution authorization, supported Android floor, exact development toolchain, package namespace, and local worktree/baseline handling.
2. **Before official connection code:** document X client registration/billing, Bluesky metadata URL and native redirect ownership, secure storage, and whether direct access needs any operated service. Static public metadata hosting is different from a running backend. Do not silently add either.
3. **Before any live test:** identify authorized test accounts, exact sample caption/media, possible charges, visibility and cleanup expectations. Mock tests do not require accounts. Do not post, buy credits, register an app, or delete a test post without authorization covering that action.
4. **Before enabling a capability:** evidence for text/photos/video is separate per provider. Unsupported video is explicitly unavailable with a scoped explanation, not silently removed from the requested MVP. Return the scope consequence for review.
5. **Before public release:** final name/package identity/license/distribution, hosted metadata ownership, and who pays X charges are decided. No store upload or public GitHub release is implied by implementing these plans.

## 3. File structure and responsibility map

All application paths below are new. Existing design assets remain reference inputs. All Flutter commands in child plans run from `app/`; Git commands run from the repository root unless stated otherwise.

```text
app/
  lib/main.dart                         bootstrap storage and services
  lib/app/app.dart                      MaterialApp and top-level route ownership
  lib/app/services.dart                 explicit dependency composition; no service locator
  lib/design/caption_tokens.dart        current colors and typography
  lib/design/caption_theme.dart         Material component themes
  lib/design/caption_scaffold.dart      black app bars, safe areas, scroll/action layout
  lib/design/caption_text.dart          read-only subtitle treatment and native editor style
  lib/core/clock.dart                   injectable UTC clock
  lib/core/ids.dart                     UUID generation
  lib/storage/local_database.dart      schema and transactional opening/migrations
  lib/storage/media_files.dart         import, immutable derivatives, safe cleanup
  lib/features/drafts/draft.dart        content, assets, overrides, stages and codecs
  lib/features/drafts/draft_editor.dart pure inheritance/edit rules
  lib/features/drafts/draft_repository.dart SQLite-backed draft persistence
  lib/features/drafts/draft_controller.dart ordered saves and dirty/saved/error state
  lib/features/library/library_screen.dart first run, drafts, attention/results
  lib/features/compose/choose_screen.dart destination selection
  lib/features/compose/write_screen.dart shared text/media editor
  lib/features/compose/version_screen.dart independent text/media overrides
  lib/features/media/media_editor_screen.dart alt text, reorder, replace, rotate/crop
  lib/features/review/review.dart        resolved snapshot and validation models
  lib/features/review/review_service.dart validation and exact snapshot creation
  lib/features/review/review_screen.dart review groups and explicit action
  lib/features/accounts/account.dart    public identity/state; no tokens
  lib/features/accounts/account_repository.dart sanitized account metadata
  lib/features/accounts/accounts_screen.dart capabilities/connect/reconnect/disconnect
  lib/features/accounts/credential_vault.dart secure OAuth/session material
  lib/features/accounts/x_connection.dart X public-client OAuth
  lib/features/accounts/bluesky_connection.dart AT Protocol OAuth
  lib/features/instagram/instagram_package.dart immutable preparation and local events
  lib/features/instagram/instagram_repository.dart package/event persistence
  lib/features/instagram/instagram_service.dart preparation, confirmation, undo
  lib/features/instagram/android_transfer.dart typed native clipboard/export/launch/share adapter
  lib/features/instagram/instagram_screen.dart finish, return and confirmation UI
  lib/features/publishing/attempt.dart   attempts, outcomes and evidence source
  lib/features/publishing/attempt_repository.dart durable dispatch and outcome records
  lib/features/publishing/publish_coordinator.dart explicit send/retry; concurrency guard
  lib/features/publishing/results_screen.dart individual results and safe actions
  lib/features/providers/provider.dart  official provider port and capability models
  lib/features/providers/capabilities.dart evidence-backed validators
  lib/features/providers/x_publisher.dart X media and post requests
  lib/features/providers/bluesky_publisher.dart AT Protocol media and record requests
  lib/features/providers/provider_errors.dart stage-aware error classification
  assets/fonts/AtkinsonHyperlegibleNext.ttf
  assets/fonts/AtkinsonHyperlegibleNext-OFL.txt
  android/app/src/main/kotlin/org/example/crossposting/
    MainActivity.kt                    register the Android transfer channel
    InstagramTransfer.kt              narrow native sharing/launch operations
    MediaExporter.kt                  MediaStore writes and receipts
  android/app/src/main/res/xml/
    file_paths.xml                    only prepared-package file sharing
    backup_rules.xml                  exclude private drafts and credentials
    data_extraction_rules.xml         same policy on modern Android
  test/                               mirrors feature boundaries; deterministic fakes
  integration_test/                   native workflow and restart checkpoints
docs/engineering/                     toolchain, capabilities and protocol evidence
docs/testing/                         manual device evidence and release matrix
docs/release/                         setup, cost, signing and distribution guidance
```

Do not introduce a generic plugin platform, backend framework, repository-per-entity abstraction hierarchy, or global event bus. Small pure models plus feature services are enough. Keep each widget/controller focused; split a screen's media list or destination row when its responsibility separates, not at an arbitrary line count.

## 4. Design contract to carry into code

Extracted from `a-caption.css`, `a-caption-v2.css`, and `a-caption-more.css`:

| Role | Value |
| --- | --- |
| stage / ground / raised / raised2 | `#000000` / `#131517` / `#1D2023` / `#2A2E32` |
| text / secondary / own caption | `#F2F2EE` / `#B6BBC0` / `#7DD7E9` |
| decorative divider / meaningful boundary | `#2C3034` / `#6A7179` |
| success / error / warning | `#8CD9A4` / `#FF9F9F` / `#F0CF72` |
| text on white or cyan fill | `#0B0C0D` |
| family | Atkinson Hyperlegible Next, local font with OFL retained |
| screen title | 26sp, weight 800 |
| shared/own caption entry | 21sp, weight 600, approximately 34sp baseline rhythm |
| body / supporting / primary label | 16sp / minimum 14sp / 17sp weight 700 |
| content gutters / row gaps | 16dp / 8dp; grow with content |
| button radius / minimum visual height | 6dp / 52dp; grow under text scaling |
| touch target | minimum 48 × 48dp, including 40–44px-looking controls in drawings |

The 390×844 drawings are a composition reference, not a fixed canvas. Never draw fake status bars, gesture bars, time, battery, mock accounts or permanent fixture content in the real app. Use actual Android insets, edge-to-edge rules and system navigation. Black subtitle backgrounds must remain opaque over photos. Text-only results use a black text frame, not an empty image slot.

Use a real single Flutter TextField for editing, preserving composing regions, selection, cursor, clipboard and TalkBack. Begin with text background styling inside the native field. Exact line-padding ornament is subordinate to correct editing; do not make a transparent input over a duplicate painted caption or split editing into one field per line. Any necessary visible deviation is reviewed against Caption rather than importing a new visual system.

A status has words and an icon, not color alone. Cyan describes caption ownership, not errors or success. Preserve the selected semantic greens/reds/amber from Caption; "no new colors" does not mean discarding those existing status colors.

## 5. Runtime invariants

1. A reviewed snapshot binds content, ordered immutable media, destination set, provider capability version and stable account IDs. Any relevant edit/reconnection to a different account invalidates that review.
2. Persist the attempt before any upload, and persist the dispatch marker before the final create-post request. An application crash after that marker recovers as unknown, never a normal retry.
3. An upload or processing response is not a publication receipt. Provider-confirmed and user-reported outcomes are different enum values and different copy.
4. Retry creates a child attempt only for explicitly selected eligible failures. It does not rerun an entire group, mutate a published snapshot, or accidentally prepare a second Instagram package.
5. No claims of universal exactly-once delivery: use provider-supported idempotency/reconciliation where verified; otherwise uncertainty remains visible and resending requires an explicit duplicate-risk decision.
6. Save state uses durable revision acknowledgements. A completed save of revision N cannot mark newer in-memory revision N+1 saved.
7. Imported picker files are copied to private durable storage before a draft references them. Immutable derived images never overwrite originals. Files referenced by attempts/packages survive draft deletion.
8. Instagram-ready means an immutable package exists. Open, chooser, identifiable dispatch, and user confirmation are distinct events. Return prompts are correlated to a launch, asked once, and never change publication status themselves.
9. Credentials and DPoP keys live only in OS-backed secure storage. Public identity is separate. No credentials in draft JSON, logs, screenshots, source, fixtures, CI artifacts or backups.
10. Tests default to fake transport. Production cannot report a simulated provider success.

## 6. Source and feasibility evidence

Planning references checked during this conversation; recheck owning documentation before enabling providers:

- X native public-client OAuth/PKCE: https://docs.x.com/fundamentals/authentication/oauth-2-0/authorization-code
- X current API access/prices: https://docs.x.com/x-api/getting-started/pricing
- AT Protocol OAuth profile, including PKCE/PAR/DPoP, issuer/account binding and native redirects: https://atproto.com/specs/oauth
- Candidate Dart OAuth package: https://pub.dev/packages/atproto_oauth ; package API reported `0.8.3`, Dart `>=3.8.0 <4.0.0` on 2026-11-16. Its repository README demonstrates OAuthClient, FlutterWebAuth2, secure session serialization, OAuthSessionManager and Bluesky.fromOAuth. The README on main is not proof of the published version's API; match source/tag and run a focused compatibility test before pinning.
- Android media saving: https://developer.android.com/training/data-storage/shared/media
- Android secure file sharing: https://developer.android.com/training/secure-file-sharing
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility

Neither generic `flutter_appauth` nor PKCE alone implements AT Protocol's full OAuth profile. Do not replace missing DPoP/PAR support with app-password collection. A public client ID may ship in the app; a confidential client secret may not.

## 7. Definition of complete and coverage index

| Spec requirement | Implementation task(s) |
| --- | --- |
| Caption identity, real text editing, first run | L1, L5 |
| Local drafts, interruption, owned media, save failures | L2–L4, R1 |
| Choose/write/review, no accounts required to draft | L5–L7 |
| Independent text/media overrides, restore shared + undo | L2, L6 |
| Descriptions, order, replace, remove, rotate/crop | L3, L6 |
| Exact previews and per-platform validation | L7, P1, P4–P5 |
| Accounts, official auth, expiry/reconnect/disconnect | P1–P3 |
| Images and supported video on X/Bluesky | P4–P5 |
| Partial results, uncertainty, child retries and duplicate prevention | P6–P7 |
| Instagram package, fallback, partial saves, open vs handoff | I1–I3 |
| Instagram return, confirmation, timestamp and undo | I4 |
| Empty/loading/offline/disconnected/storage/error states | L4–L7, I2–I4, P2–P7 |
| 200% text, 320dp, TalkBack, keyboard, dialogs/undo | L1, L5–L7, I4, R1 |
| Open-source maintenance, no required service/AI, distribution | P1, R2–R3 |

The full MVP is complete only when all required local behavior and direct-provider capabilities are implemented and verified, or the user explicitly accepts a documented scope change. "Build passes", a screenshot, or mocked successful publication is insufficient. Report verified devices, accounts/formats tested, known limitations and remaining gates separately.

## 8. Plan review record

This plan package is a planning artifact. Its review checks cover spec-to-task mapping, file/interface naming, dependency ordering, state/evidence distinctions and explicit gates. Code examples have not been compiled because this session has not created a Flutter application or installed its SDK. Executors must run each red/green cycle and native checks rather than treating the snippets as tested code.

Documentation verification on 2026-11-16 found five plan documents, 21 unique task IDs and 118 unchecked work steps, with required headers, balanced code fences, valid sibling-plan links and no unresolved planning markers. Self-review corrected early fixture dependencies, account codec ordering, validator-registry signatures, the native package/FileProvider path, persisted reconciliation context and atomic claim projections. Spec coverage is mapped above. No `app/` directory was created and no runtime test was run. The 21 task boundaries are review units; execute their individual test/setup/edit/check/commit actions incrementally rather than treating a whole provider as a single unreviewed patch.

Execution choices after the user authorizes implementation: **Subagent-Driven** (fresh worker per task with review gates) or **Inline Execution** (task batches with checkpoints). Either approach starts with L1's readiness checks and P1's read-only feasibility record; neither authorizes live posts or deployment beyond the separately agreed scope.
