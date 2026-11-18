# Visual acceptance — Multipost

Evidence date: 2026-11-17. "Multipost" is a temporary working name. The identity is the "Impression" direction ([docs/brand](../brand/README.md), [DESIGN.md](../../DESIGN.md)). It has a light scheme and a matching dark scheme, and the app follows the system setting.

This record covers only what was run. Everything else is listed under [Not established](#not-established).

## Host checks

All run on the final source (Flutter 3.50.0, Dart 3.14):

- `dart format --set-exit-if-changed lib test integration_test`: 153 files, 0 changed.
- `flutter analyze`: no issues.
- `flutter test --no-pub`: **562 passed**. The last edit (system-bar scrim and removal of an unused FAB theme) came after this full run. Analysis and `test/design` plus `test/acceptance/accessibility_test.dart` were rerun afterwards and passed (12 tests).
- `app/test/design/caption_tokens_test.dart` checks WCAG contrast in both schemes: text pairs at 4.5:1 or more, control boundaries and success fills at 3:1 or more.
- Existing behaviour tests are unchanged in intent. They cover drafts and recovery, shared versus own content, immutable reviewed versions, per-destination outcomes, eligible-only retry, Unknown with duplicate-risk confirmation, no automatic resend, and Instagram Ready / Handed off / Marked posted with Undo. Restyle-only assertions (colours, the Results header finder) were updated. New assertions cover the Library attention marks (`Bluesky · Unknown`, `Instagram · Ready to share`).

## Native captures (API 29 emulator)

Device: AVD `caption_local_api29`, 1080×2400 at 420 dpi, Skia (`--no-enable-impeller`). The fixture `integration_test/mixed_results_test.dart` renders real screens with synthetic data in constrained logical viewports (390×844, 320×844 and 720×320 dp; 100% and 200% text through MediaQuery).

| Run | APK | Result |
| --- | --- | --- |
| Light | visual build 12:41 | exit 0, 32 files (31 widget surfaces + marker) |
| Dark | visual build with `--dart-define=CAPTURE_BRIGHTNESS=dark` | exit 0, 32 files |

Dark captures use a test-only brightness override. This AVD image locks system night mode (`mNightModeLocked=true`), so `cmd uimode night yes` has no effect on it.

These captures predate two later source changes:

1. The Library attention row now shows one state mark per destination instead of plain text "X · Bluesky · Instagram". The `library-attention-first` images show the old row; host tests cover the new one.
2. The system-bar scrim fix.

The visual APKs were rebuilt with the Library change at 13:50, but the rerun was stopped when the machine ran low on memory, so it produced no captures.

A first light run and a first dark run each hung once at startup: the app stayed on its launch window and the driver never attached. Both were stopped and rerun; neither failure involved a test assertion.

Representative images are in [multipost/](multipost/): `light-*` and `dark-*` for first run, attention-first Library, Write with bright photos, Results Unknown actions, Instagram marked, and Results at 320 dp / 200%.

Inspection notes:

- Every screen keeps one filled ink action in the bottom slot.
- Shared captions show the ditto sign and "Shared caption". Own captions show the ultramarine frame and "Own caption". Ultramarine appears nowhere else: Material `tertiary` maps to ink, and text selection is an ink tint.
- State marks: filled for Published / Marked posted, outline for Ready to share / Not published, dashed for Unknown. Each has an icon, a word and a time when one is known. Times older than today include the date.
- At 320 dp / 200% the Results header puts the photo above the summary, so each outcome line keeps the full width. Titles, tabs and marks wrap rather than clip.
- No renderer exceptions were reported. The driver asserts `takeException() == null` before each capture.

## Ordinary app (system chrome)

- **API 29**, main debug APK: full frame of Library with light status and navigation bars (`api29-library-full-frame.png`). The app drawer shows the adaptive icon labelled "Multipost" (`api29-launcher.png`).
- **API 36** (`caption_local_api36`): real system dark mode via `cmd uimode night yes`.
  - The Android 12+ splash shows the icon on the dark ground (`api36-dark-launch.png`).
  - Library follows dark, then light, while the app stays open (`api36-system-dark.png`, `api36-system-light.png`).
  - Fix found on this device: Android 15+ edge-to-edge kept a stale light scrim behind the navigation bar after a runtime switch to dark. `captionOverlay` now turns off the system contrast scrims, so the app ground shows behind both bars. Rechecked on a cold light start, after a switch to dark, and after a switch back to light.
  - The AVD has a forced density of 443 on a 320×640 px screen (about 116 dp wide, a prior stress setting). It was set to 160 for these frames and restored to 443 afterwards.

APKs (local, ignored `.tools/`):

| File | SHA-256 prefix | Built |
| --- | --- | --- |
| `multipost-main-debug.apk` (ordinary entrypoint, final source) | `ab23b0976746a37a` | 13:59 |
| `multipost-visual-debug.apk` (light fixture) | `be08e40846a2724f` | 13:50 |
| `multipost-visual-dark-debug.apk` (dark fixture) | `b73f0c20847e3cc3` | 13:51 |

## Not established

- **Device and provider checks.** TalkBack and spoken announcements, physical hardware, live X / Bluesky / Instagram connections or posting, and the Instagram receiving app (handoff, return, gallery order).
- **Native interaction.** The keyboard (IME), selection handles and keyboard insets on device. Host tests cover these.
- **OS-level enlargement.** System font scale or display size changed at the OS level; the 200% evidence comes from MediaQuery.
- **Renderer.** Default Impeller rendering.
- **Dark mode on API 29 from the system setting.** The image locks night mode. API 36 covers the system switch, but only for Library and the launch window.
- **Fresh native captures** of the new Library marks and the bar fix (see above).

The independent review used a Claude reviewer (Impeccable finish reviewer), not the requested GPT-6 Astra, which was not available here. It returned "fix, then ship". Its fixes were applied:

- Line endings restored to LF.
- Ultramarine removed from `tertiary` and text selection.
- Library attention marks added.
- Library adaptations recorded in `.impeccable/surfaces/app-lib.md`.
- Dark mode checked against the real system setting on API 36.
