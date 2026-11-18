# Multipost brand directions (concepts)

17 November 2026. These are **static concept drawings**, not app screenshots. Accounts, photos and times are illustrative. "Multipost" is a temporary working name.

Two directions were drawn on the same content. Each board shows a brand panel (mark, palette, type, states), Library, Composer and Results:

- [A · Impression](a-impression-board.png): **selected**, with a matching dark scheme added at implementation.
- [B · Caption, evolved](b-caption-board.png): the incumbent dark subtitle world with a new mark. Not selected.

The implemented brand is documented in [docs/brand](../../brand/README.md). Native evidence is in [docs/testing/multipost-visual.md](../../testing/multipost-visual.md). The boards are composition references, not pixel targets.

## Exploration record

The Impeccable direction roll used `seed:f588c1d19b25ebbd`, operate mode. Seven grounded candidates were ranked by resonance for one person sharing their own words and photos:

1. Carbon-copy forms
2. Broadcast captions (the incumbent)
3. Numbered print editions
4. Index cards
5. Risograph zine
6. Rubber and date stamps
7. Contact sheet

The roll assigned candidate 6, which became **A · Impression**. Carbon-copy forms duplicated A's idea, so its best feature folded into A: a destination's own version gets its own visible treatment. The incumbent became B.

Six catalogue challengers each lost on audience fit and product clarity. Each lent A one discipline:

- **Darkroom exposure record** → a strict tonal ramp of ground, sheet, raised and raised2.
- **Labanotation** → shape encodes state: filled, outline or dashed, always with a word and an icon.
- **Botanical folio** → the post sheet keeps its composition from Write to Results.
- **Character goods catalogue** → each destination's name, account and caption source sit in fixed places.
- **Midnight transit diagram** → only the row that needs action is raised.
- **Metro tiles** → confident type as the interface, with less chrome.

## Files

- `src/`: generator (`build.py`), CSS, `render.sh` (headless Edge at 2x).
- `assets/`: Atkinson Hyperlegible Next and Rubik (OFL, licences alongside). The sample photos are the same Unsplash images as `../options-dark/assets` (sources listed there); they are not the user's photos.
