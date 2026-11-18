---
name: Multipost (working name)
description: A personal Android app that sends one post to X, Bluesky and Instagram and reports every outcome as a dated, labelled mark.
colors:
  ground: "#F2F3F0"
  sheet: "#FFFFFF"
  raised: "#E6E8E4"
  raised-2: "#D9DCD7"
  ink: "#16171A"
  pencil: "#4B5058"
  own-ultramarine: "#2B3BC9"
  hairline: "#D9DCDF"
  boundary: "#7A7F87"
  success: "#1C6B3A"
  on-success: "#FFFFFF"
  error: "#B3261E"
  warning: "#7A5300"
  on-action: "#FFFFFF"
  ground-dark: "#121315"
  sheet-dark: "#1C1E21"
  raised-dark: "#26292D"
  raised-2-dark: "#32363B"
  ink-dark: "#F1F2EE"
  pencil-dark: "#B4B9BF"
  own-ultramarine-dark: "#A9B4FF"
  hairline-dark: "#2E3135"
  boundary-dark: "#7D848C"
  success-dark: "#86D3A0"
  on-success-dark: "#0B1A10"
  error-dark: "#FF9C94"
  warning-dark: "#E9C46A"
  on-action-dark: "#16171A"
  mark-ultramarine: "#2B3BC9"
  mark-paper: "#FFFFFF"
typography:
  wordmark:
    fontFamily: "Rubik"
    fontSize: "34sp"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.5"
  title-large:
    fontFamily: "Rubik"
    fontSize: "24sp"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "-0.2"
  dialog-title:
    fontFamily: "Rubik"
    fontSize: "21sp"
    fontWeight: 600
  title-medium:
    fontFamily: "Rubik"
    fontSize: "19sp"
    fontWeight: 600
    lineHeight: 1.3
  title-small:
    fontFamily: "Rubik"
    fontSize: "16sp"
    fontWeight: 600
  mark-label:
    fontFamily: "Rubik"
    fontSize: "15sp"
    fontWeight: 600
    lineHeight: 1.3
  caption-editor:
    fontFamily: "Atkinson Hyperlegible Next"
    fontSize: "20sp"
    fontWeight: 600
    lineHeight: 1.45
  caption:
    fontFamily: "Atkinson Hyperlegible Next"
    fontSize: "18sp"
    fontWeight: 600
    lineHeight: 1.45
  body:
    fontFamily: "Atkinson Hyperlegible Next"
    fontSize: "16sp"
    fontWeight: 400
    lineHeight: 1.45
  body-small:
    fontFamily: "Atkinson Hyperlegible Next"
    fontSize: "14sp"
    fontWeight: 400
    lineHeight: 1.4
  label-button:
    fontFamily: "Atkinson Hyperlegible Next"
    fontSize: "17sp"
    fontWeight: 700
rounded:
  mark: "6dp"
  chip: "8dp"
  control: "10dp"
  sheet: "12dp"
  dialog: "16dp"
spacing:
  xs: "4dp"
  sm: "8dp"
  md: "12dp"
  gutter: "16dp"
  lg: "24dp"
  xl: "32dp"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-action}"
    typography: "{typography.label-button}"
    rounded: "{rounded.control}"
    padding: "14dp 18dp"
    height: "52dp"
  button-primary-dark:
    backgroundColor: "{colors.ink-dark}"
    textColor: "{colors.on-action-dark}"
  button-primary-disabled:
    backgroundColor: "{colors.raised-2}"
    textColor: "{colors.pencil}"
  button-outlined:
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "10dp 16dp"
    height: "48dp"
  chip-own-caption-selected:
    backgroundColor: "{colors.own-ultramarine}"
    textColor: "{colors.on-action}"
    rounded: "{rounded.chip}"
  post-sheet:
    backgroundColor: "{colors.sheet}"
    rounded: "{rounded.sheet}"
    padding: "12dp"
  impression-confirmed:
    backgroundColor: "{colors.success}"
    textColor: "{colors.on-success}"
    typography: "{typography.mark-label}"
    rounded: "{rounded.mark}"
    padding: "5dp 10dp 5dp 8dp"
    height: "32dp"
  impression-user:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.ground}"
    typography: "{typography.mark-label}"
    rounded: "{rounded.mark}"
    height: "32dp"
  impression-attention:
    textColor: "{colors.error}"
    typography: "{typography.mark-label}"
    rounded: "{rounded.mark}"
    height: "32dp"
  impression-waiting:
    textColor: "{colors.ink}"
    typography: "{typography.mark-label}"
    rounded: "{rounded.mark}"
    height: "32dp"
  impression-unknown:
    textColor: "{colors.warning}"
    typography: "{typography.mark-label}"
    rounded: "{rounded.mark}"
    height: "32dp"
  caption-own:
    textColor: "{colors.own-ultramarine}"
    typography: "{typography.caption}"
    rounded: "{rounded.mark}"
    padding: "6dp 10dp"
  text-field:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    padding: "14dp 12dp"
---

# Design System: Multipost (working name)

**Multipost is a temporary placeholder name.** Other products already use it, and no clearance exists. Nothing in this system depends on the name. A rename swaps the wordmark string in `BrandLockup` and the Android label, nothing else. Brand rationale, assets, mark geometry and font licences live in [docs/brand/README.md](docs/brand/README.md). This file does not repeat them.

## Overview

**Creative North Star: "The Impression"**

Every destination receives an impression of the same post, and every outcome is a dated mark you can trust. The world borrows from rubber date stamps on card stock. Ink on paper, a single white post sheet, hairline rows, and one reserved ultramarine for a destination's own words. It is calm and dense in the way a ledger is dense: rows, not cards; words, not pills.

The app is Flutter on Android, Material 3 underneath. Material controls are themed, never replaced. Colour roles live in `CaptionTokens` (a `ThemeExtension`, `app/lib/design/caption_tokens.dart`); `captionTheme()` maps them onto Material (`app/lib/design/caption_theme.dart`). Light and dark follow the phone's system setting. Motion is Material defaults only, and reduced motion is respected.

**Key Characteristics:**
- Ink on card stock: neutral ground, white post sheet, near-black ink type and action.
- Ultramarine means "own caption" and nothing else, and it is always labelled.
- State is a dated impression mark: shape, icon, word and, where known, a time.
- One filled ink action per screen, always in the bottom slot.
- Hairline rows instead of cards; flat surfaces, no shadows.

## Colors

A near-neutral ink-and-paper palette with one reserved accent and three state colours. Each role has one job. Hex values for both schemes are in the frontmatter (`*-dark` keys are the dark scheme).

### Primary
- **Ink** (`ink` / `ink-dark`): all text, and the single filled action (`primary` in Material). Also the selected checkbox, switch track, chip fill, focus underline, cursor and selected stage tab. In dark it becomes paper-white, and the action's label flips to ink (`on-action-dark`).

### Secondary
- **Own Ultramarine** (`own-ultramarine` / `own-ultramarine-dark`): a destination's own caption. It colours the caption text, its 2dp ruled frame, the "Own caption" label and pencil icon, and the selected "Own caption" chip. Nothing else.

### Tertiary
- **State colours**: Proof Green (`success`), Signal Red (`error`), Ochre (`warning`). Used only by state marks and their icons, and by error text. Each appears with an icon and a word.

### Neutral
- **Card-stock Ground** (`ground`): every screen, the status bar and the bottom action slot.
- **Post Sheet** (`sheet`): the `PostSheet`, dialogs, filled text fields, and the one result row that still needs action.
- **Raised / Raised 2** (`raised`, `raised-2`): tonal fills for notices, media placeholders, switch tracks and disabled fills.
- **Pencil** (`pencil`): supporting text, field labels, list subtitles, the ditto glyph and "Shared caption".
- **Hairline** (`hairline`): dividers, the sheet's 1dp edge, the line above the bottom slot.
- **Boundary** (`boundary`): control outlines (chips, field underline, switch outline). Meets 3:1.

### Named Rules
**The Reserved Ultramarine Rule.** Ultramarine marks a destination's own caption and is always next to the words "Own caption". Material `tertiary` maps to ink and text selection is an ink tint (22% alpha) on purpose, so no stock widget can leak ultramarine. Never use it for links, focus, selection, emphasis or brand decoration.

**The Fixed Mark Rule.** The brand mark is white on ultramarine (`mark-paper` on `mark-ultramarine`) in both schemes. It is the only place ultramarine appears without a label, because it is the logo, not UI.

## Typography

**Display Font:** Rubik (bundled variable font, 600–700)
**Body Font:** Atkinson Hyperlegible Next (bundled; the app's default `fontFamily`)

**Character:** Rubik's soft geometry gives names and marks a stamped, sturdy voice. Atkinson carries everything the person reads or touches, chosen for legibility first.

### Hierarchy
All sizes are sp and scale with the system text size.
- **Wordmark** (Rubik 700, 34sp, -0.5 tracking): first-run lockup only.
- **Title Large** (Rubik 600, 24sp, 1.25): screen titles in the scaffold header.
- **Dialog Title** (Rubik 600, 21sp): dialog headings.
- **Title Medium** (Rubik 600, 19sp, 1.3): section titles ("Needs your attention", "Destinations").
- **Title Small** (Rubik 600, 16sp): destination names.
- **Mark Label** (Rubik 600, 15sp, 1.3): state-mark words; the time is weight 400 with tabular figures.
- **Caption Editor** (Atkinson 600, 20sp, 1.45): the caption being written.
- **Caption** (Atkinson 600, 18sp, 1.45): the person's caption shown back to them.
- **Body** (Atkinson 400, 16sp, 1.45): running text, dialog content, chip labels.
- **Body Small** (Atkinson 400, 14sp, 1.4): meta lines, counters, caption-source labels. List subtitles use 15sp.
- **Label Button** (Atkinson 700, 17sp): filled buttons; outlined and text buttons use 16sp.

### Named Rules
**The Two Voices Rule.** Rubik speaks for the app: titles, names, marks. Atkinson speaks for the person and for every control. Never set the person's caption or a button in Rubik.

**The No Floor Below 14 Rule.** No text is smaller than 14sp.

## Layout

Single column, phone first. The page gutter is 16dp. `CaptionScaffold` scrolls the header (back button, optional mark, title, actions) with the body, so nothing pins except the bottom slot. Composer screens put the read-only Choose / Write / Review stage indicator under the header, with a 3dp ink underline on the current step and a hairline below.

The bottom slot sits on ground with a hairline above, inset 16dp sides, 12dp top and 16dp bottom. It holds one full-width action at least 52dp tall. Lists are hairline-divided rows (`Divider`, 1dp hairline), with 24–32dp dividers between sections. The rhythm is 4 / 8 / 12 / 16 / 24 / 32dp.

Layouts wrap rather than truncate at 200% text: state marks let their time drop below the word, stage tabs wrap, and action labels stay on one 52dp target.

## Elevation & Depth

Flat. There are no shadows and no surface tint (`surfaceTint` is transparent). Depth is tonal: ground, then sheet for the post and the one row that needs action, then raised fills for notices. A 1dp hairline edges the sheet. Material's container roles collapse onto sheet so dialogs and menus stay flat.

**The Paper Stack Rule.** Lift is shown by a lighter sheet on ground, never by a shadow. If two surfaces nest, one of them is a mistake.

## Shapes

Small, firm corners: 6dp on marks, media thumbnails and the own-caption frame; 8dp chips; 10dp buttons and snackbars; 12dp post sheet; 16dp dialogs. Strokes are 2dp for meaning (mark edges, own-caption frame, outlined buttons, checkboxes, focus underline) and 1dp for structure (hairlines, chip outlines). The brand tile clips to 25% of its size.

## Components

### Buttons
- **Primary:** filled ink with on-action label, 10dp corners, 14×18dp padding, minimum 52dp tall. Exactly one per screen, in the scaffold's bottom slot. Disabled uses raised-2 fill with pencil text.
- **Outlined:** 2dp ink border, ink label, 48dp minimum. Secondary choices such as "Set up accounts" or "Review posting results". Disabled border is boundary.
- **Text / Icon:** ink, 48dp minimum.

### Chips
- **Style:** sheet fill, 1dp boundary outline, 8dp corners, 16sp Atkinson.
- **Selected:** ink fill, on-action label and check. The one exception is the "Own caption" choice, which fills with ultramarine because it is labelled.

### Cards / Containers
- **PostSheet** (`app/lib/design/post_sheet.dart`): sheet fill, 1dp hairline, 12dp corners, 12dp padding. It holds the post itself (photos and shared caption on Write, the first photo and per-destination summary on Results) or the single "Needs your attention" row on Library. It is not a general card.

### Inputs / Fields
- **Style:** filled with sheet, boundary underline, pencil label.
- **Focus:** 2dp ink underline. The cursor is ink for shared captions and ultramarine in an own-caption editor.

### Navigation
- Header row inside the scroll: back arrow, title in Title Large, optional actions. Library shows the 32dp brand tile before the title "Your posts". The wordmark appears only in the first-run lockup.
- Library uses Drafts / Results tabs with an ink indicator.

### Impression Mark (signature)
`ImpressionMark` (`app/lib/design/impression.dart`) is the only way to show an outcome. It always has an icon, a word, and a time where one is known ("Published 1:12 PM"). It is at least 32dp tall with 6dp corners and a 2dp edge. Shape repeats the meaning, so colour is never alone:
- **Filled, confirmed** (`confirmed`): proof-green fill, check icon. A provider confirmed it ("Published").
- **Filled, by you** (`user`): ink fill, person icon. You confirmed it ("Marked posted").
- **Outline, attention** (`attention`): red edge and text, error icon. Failed or needs you ("Not published", "Connection needed").
- **Outline, waiting** (`waiting`): ink edge and text, radio icon. Waiting on you ("Ready to share", "Handed off").
- **Dashed, unknown** (`unknown`): ochre dashed edge (5 on, 4 off), help icon. "Unknown".

Screen readers hear one label, "word, time". Outside a mark, `ImpressionMark.iconColor` gives the bare icon its tone, as in the Results summary lines.

### Caption Source
- **Shared:** ditto glyph (〃) in pencil plus "Shared caption"; the caption itself is plain ink.
- **Own:** pencil-edit icon plus "Own caption" in bold ultramarine; the caption is ultramarine inside a 2dp ultramarine frame with 6dp corners (`CaptionText(own: true)`, 24dp total inset).
The words carry the meaning; the colour and sign only repeat it.

**Media source** (`MediaSourceLabel`) sits under the caption source wherever a destination is listed (Write, Review), because media inheritance is independent of the caption's: ditto plus "Shared media", or a photo icon plus "Own media · N" in bold ink. Ultramarine is never used for media. The destination version screen chooses both sources the same way: "Shared … / Own …" chip pairs under "Caption" and "Media" (or "Photos" for Instagram).

**Readiness and connection marks.** Choose and Accounts show each destination's connection as an `ImpressionMark` ("Connected", "Not connected", "Not available", "Connection expired"…). Review shows each destination's readiness ("Ready to publish", "Ready to prepare", or the first blocking problem in the attention tone), and its footer names the first blocker. Setup detail sits behind "Why…?" or "Details", never in the main line.

### Accounts ledger
Each destination is one row: name (title) and its connection mark on the same line, then the handle (or one plain line only for repair / removal), then its actions — one outlined recovery action, "Details" or "Why isn't X available?", and a red "Disconnect X" last. Rows sit on hairlines; only a row that needs the person (expired, needs repair, removal pending) is raised on a `PostSheet`. While saved state loads, every row shows at once with a "Checking…" mark and fills in with a short size transition (none under reduced motion), so nothing pops in.

### Step navigation
The Choose / Write / Review indicator is a real control for earlier steps: tapping a completed step returns to it, and Back (arrow or system gesture) goes to the previous step after a successful save. Back from Choose leaves the draft. Later steps are never tappable. Retry versions opened from Results keep Back returning to Results. At large text or on short screens the indicator collapses to one line ("Step 2 of 3 · Write").

### Scaffold
`CaptionScaffold` (`app/lib/design/caption_scaffold.dart`): ground background, system bars tinted to ground, scrolling header and body, and the fixed bottom slot for the one filled action.

## Do's and Don'ts

### Do:
- **Do** read every colour from `CaptionTokens.of(context)` or the Material scheme; never hard-code hex in a screen.
- **Do** show every outcome as an `ImpressionMark` with icon, word and, where known, a time.
- **Do** pair ultramarine with the words "Own caption", and the ditto glyph with "Shared caption".
- **Do** keep one filled ink action per screen, in the bottom slot, at least 52dp tall.
- **Do** keep every touch target at least 48dp and check every screen at 200% text in both schemes.
- **Do** add a new colour pair to `app/test/design/caption_tokens_test.dart`: text at 4.5:1 or more, boundaries and state fills at 3:1 or more.
- **Do** use hairline rows for lists and keep `PostSheet` for the post or the one row that needs action.

### Don't:
- **Don't** use ultramarine for links, focus, selection, highlights or decoration.
- **Don't** signal state by colour alone, or show a state without its word.
- **Don't** use gradients, glass or blur, shadows, or nested cards.
- **Don't** add decorative metrics, counters-as-ornament or dashboard tiles.
- **Don't** add AI sparkle icons or "magic" styling; the app has no AI features.
- **Don't** add a second filled action or a floating action button.
- **Don't** put the working name anywhere beyond the lockup and the Android label.
