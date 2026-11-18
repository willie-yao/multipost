---
version: 1
slug: "app-lib"
primary_target: "app/lib"
related_targets: []
---

Scope: the Android app (Library, Choose, Write, destination version, Review, Results, Accounts, Instagram finish, media editors). Mode: Operate. Working name "Multipost" is a temporary placeholder.

Audience and job: one person composing their own post, choosing X/Bluesky/Instagram, reviewing what each destination receives, and recovering honestly from partial results. Constraints: preserve every behaviour, gate and truthful state in PRODUCT.md and README; standard Material controls; 48 dp targets; 200% text; light and dark schemes following the system setting.

## Direction contract

THESIS: Every destination receives an impression of the same post, and every outcome is a dated mark you can trust. Refuses the category's white-card dashboard with coloured status pills and gradient brand.

OWN-WORLD: Light: card-stock ground #F2F3F0, white post sheet, ink #16171A type and the single filled action, pencil #4B5058 secondary, ultramarine #2B3BC9 reserved for a destination's own caption and the mark. Dark: ink-pad ground, raised sheet, paper-white ink, lifted ultramarine. Rubik for names, titles and state marks; Atkinson Hyperlegible Next for the user's words and every control. Hairline rows, not cards.

STORY: The person sees one post sheet that keeps its composition from Write to Results, knows at a glance which destinations share the caption (ditto mark + "Shared caption") or have their own (ultramarine frame + "Own caption"), and reads every result as a dated impression: filled = confirmed, outline = waiting on you, dashed = unknown.

FIRST VIEWPORT: Library: lockup (ditto mark tile + wordmark) in the app bar; "Needs you" raised white row with per-destination impressions and "Open results"; drafts as hairline rows; ink extended FAB "New post" bottom-right. Composer: app bar, Choose/Write/Review tabs, white post sheet (photos, shared caption field), destination rows, ink "Review post" bar.

FORM: Impression (rubber/date-stamp impressions), position 6 of 7 on the grounded list, seed:f588c1d19b25ebbd. Raises: tonal ramp (exposure record), shape-coded states (labanotation), fixed post plate (botanical folio), fixed destination furniture (character catalog), focus the one row needing action (transit diagram), type as interface (metro). Signature: the dated impression state mark. Motion: none beyond Material defaults; reduced-motion respected.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Recorded adaptations (2026-11-17)

- Library app bar shows the mark tile with the screen title "Your posts", not the wordmark. "Multipost" is a temporary name, so the wordmark appears only in the first-run lockup, where the person meets the app. A rename then touches one string.
- The primary Library action is the full-width ink "New post" bar in the shared bottom slot, not a bottom-right extended FAB. Every screen keeps one filled action in the same place, it never covers the last row, and at 200% text its label stays on one 52 dp target.
- The "Needs your attention" row carries one state mark per destination (the same label and tone as Results), so the signature mark appears on the first screen.
