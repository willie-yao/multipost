# Multipost brand

**Multipost is a temporary working name.** On 2026-11-17 a basic web search found other posting products using it: an open-source multi-platform publishing extension (multipost.app), multipost.social and multipostapp.co.uk. That search is not legal or trademark clearance. The identity below does not depend on the name, so a rename only swaps the wordmark text and the Android label.

## Direction: Impression

Every destination gets an impression of the same post. Every result is a dated mark you can trust.

- **The post sheet.** The post sits on one plain sheet. Write shows photos and the shared caption there. Results shows the post's first photo and a one-line outcome per destination.
- **Shared or own.** A destination using the shared caption shows a ditto sign (〃, "the same again") and the words *Shared caption*. A destination with its own caption shows that caption in ultramarine inside a ruled frame, with the words *Own caption*. The words always carry the meaning. Ultramarine is reserved for this one job.
- **Dated impressions for state.** Each outcome is a small mark with an icon, a word and, where known, a time. The mark's shape repeats its meaning:
  - Filled: confirmed, by the provider (*Published*) or by you (*Marked posted*).
  - Outline: waiting on you or failed (*Ready to share*, *Handed off*, *Not published*, *Connection needed*).
  - Dashed: *Unknown*.
- **Familiar controls.** Material buttons, tabs, fields, checkboxes, chips, dialogs and snackbars are themed, not replaced. Each screen has one filled ink action.

This direction replaced the dark "Caption" subtitle world. The concept boards and the alternative are in [docs/design/multipost](../design/multipost/README.md).

## Assets

| File | Use |
| --- | --- |
| `src/mark.svg` | Master mark on the 108-unit adaptive-icon grid (full bleed, 66-unit safe zone). |
| `src/mark-foreground.svg` | Foreground and monochrome layer only, on a transparent background. |
| `app/android/app/src/main/res/drawable/ic_launcher_foreground.xml` | Android vector foreground, also used as the themed monochrome icon. |
| `app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Adaptive icon: ultramarine background, white mark. |
| `app/android/app/src/main/res/mipmap-*/ic_launcher.png` | Legacy square fallbacks, rendered from `src/legacy.html`. The minimum SDK (29) always uses the adaptive icon. |
| `png/launcher-512.png` | Square 512 px render for listings and docs. |
| `src/lockup.html`, `png/lockup-light.png`, `png/lockup-dark.png` | Mark + wordmark + tagline lockup. |
| `app/lib/design/brand_mark.dart` | In-app mark, ditto glyph and lockup, drawn in code from the same geometry. |

Mark geometry (108 grid): two round-capped strokes, 10 units wide, from (48.5, 38.5) to (42.5, 59.5) and from (65.5, 38.5) to (59.5, 59.5). Below them, a bar at x 35, y 67.5, size 38 × 7, radius 3.5. Ink is white (`#FFFFFF`) on ultramarine (`#2B3BC9`). The mark keeps these colours in both themes.

Wordmark: "Multipost" in Rubik Bold, tracking −0.5 at 34 sp in the app. Tagline: "Write once. Share your way." in Atkinson Hyperlegible Next.

To re-render the PNGs, open the `src/*.html` files with headless Edge at the target size, as `docs/design/multipost/src/render.sh` does.

## Colour

| Role | Light | Dark | Job |
| --- | --- | --- | --- |
| ground | `#F2F3F0` | `#121315` | Screen ground |
| sheet | `#FFFFFF` | `#1C1E21` | The post sheet; the one raised row that needs action |
| raised / raised2 | `#E6E8E4` / `#D9DCD7` | `#26292D` / `#32363B` | Notices, placeholders, disabled fills |
| text (ink) | `#16171A` | `#F1F2EE` | Text and the filled action |
| secondary | `#4B5058` | `#B4B9BF` | Supporting text |
| own | `#2B3BC9` | `#A9B4FF` | A destination's own caption, always labelled |
| hairline / boundary | `#D9DCDF` / `#7A7F87` | `#2E3135` / `#7D848C` | Dividers / control outlines (≥3:1) |
| success / error / warning | `#1C6B3A` / `#B3261E` / `#7A5300` | `#86D3A0` / `#FF9C94` / `#E9C46A` | State marks, always with icon and word |

`app/test/design/caption_tokens_test.dart` checks WCAG contrast for both schemes: text pairs at 4.5:1 or more, boundaries and state fills at 3:1 or more. The app follows the phone's light or dark setting.

## Type

- **Rubik** (600–700): screen titles, section titles, destination names, state marks and the wordmark.
- **Atkinson Hyperlegible Next**: the person's words, body text and every control.

Sizes are in sp and scale with system text size. Body text is 16, captions 18–20, section titles 19 and screen titles 24.

## Provenance and licences

- The mark, ditto glyph, lockups and launcher renders are original work authored for this project as SVG, Android vector XML and Flutter `CustomPainter` code. No image generation or stock artwork was used. The PNGs are headless-Edge renders of the SVG and HTML sources in `src/`.
- **Rubik**: Copyright 2015 The Rubik Project Authors, SIL Open Font License 1.1. It comes from github.com/google/fonts (`ofl/rubik`, `Rubik[wght].ttf`), retrieved 2026-11-17. The licence ships next to it at `app/assets/fonts/Rubik-OFL.txt`.
- **Atkinson Hyperlegible Next**: unchanged, under its existing OFL (`app/assets/fonts/AtkinsonHyperlegibleNext-OFL.txt`).
- The project's own licence (MIT) is selected, but the copyright holder is still unresolved. Nothing here sets it.
