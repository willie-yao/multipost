"""Static contrast checks: token boundary pairs + pixels sampled from the rendered PNGs (2x)."""
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parent.parent
def hx(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def lum(c):
    f = lambda v: (v/255)/12.92 if v/255 <= 0.03928 else (((v/255)+0.055)/1.055)**2.4
    r, g, b = c[:3]; return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def ratio(a, b):
    l1, l2 = sorted((lum(a), lum(b)), reverse=True); return round((l1+0.05)/(l2+0.05), 2)
# meaningful boundaries / indicators (need 3:1)
B = {
 "a-caption": [("outline", "#6A7179", "#131517"), ("outline on focus row", "#6A7179", "#1D2023"), ("field indicator", "#F2F2EE", "#000000"),
               ("tab indicator", "#F2F2EE", "#131517"), ("own-caption cyan on caption box", "#7DD7E9", "#000000"), ("caret", "#7DD7E9", "#000000")],
 "b-contact": [("outline", "#7A6A5B", "#17120E"), ("add-slot border", "#7A6A5B", "#0A0806"), ("field indicator", "#F2E9DB", "#221B16"),
               ("tab indicator", "#F2E9DB", "#17120E"), ("ladder rule", "#7A6A5B", "#17120E")],
 "c-margin-night": [("outline", "#75738F", "#13131C"), ("tab indicator", "#B5B2FF", "#13131C"), ("primary fill vs ground", "#B5B2FF", "#13131C"),
               ("caret", "#B5B2FF", "#13131C")],
}
INFO = [{"pair": "tonal button fills vs ground (all options)", "note": "Fill-to-ground is about 1.3:1 by design (Material tonal button). Not a WCAG 1.4.11 requirement: the text label identifies the control and its text contrast is checked. Native focus/pressed states must still be tested."}]
out = {"info": INFO, "method": "Boundary ratios from design tokens (WCAG 2.x relative luminance). Rendered pixels sampled from 2x PNGs at fixed CSS points.", "boundaries": [], "sampled": []}
for d, pairs in B.items():
    for name, fg, bg in pairs:
        r = ratio(hx(fg), hx(bg)); out["boundaries"].append({"option": d, "pair": name, "fg": fg, "bg": bg, "ratio": r, "need": 3, "pass": r >= 3})
# rendered sampling: (label, css x, css y) on single-screen PNGs; text colour = token, bg = sampled pixel
S = {
 "a-caption-composer": [("ground", 8, 760, "#B6BBC0"), ("primary button", 30, 795, "#0B0C0D"), ("caption field", 22, 400, "#F2F2EE")],
 "b-contact-composer": [("ground", 8, 760, "#C6B9A6"), ("primary button", 30, 795, "#17120E"), ("rebate strip", 6, 200, "#C6B9A6")],
 "c-margin-night-composer": [("ground", 8, 760, "#BBB8C9"), ("primary button", 40, 795, "#17163A")],
 "a-caption-results": [("focus row", 8, 470, "#B6BBC0")],
 "b-contact-instagram": [("caption block", 120, 410, "#F2E9DB")],
 "c-margin-night-instagram": [("tonal button", 140, 360, "#EEEAE0")],
}
for png, pts in S.items():
    im = Image.open(ROOT / f"{png}.png").convert("RGB")
    for label, x, y, txt in pts:
        px = im.getpixel((x*2, y*2)); r = ratio(hx(txt), px)
        out["sampled"].append({"screen": png, "where": label, "css_xy": [x, y], "pixel": "#%02X%02X%02X" % px, "text_token": txt, "ratio": r, "pass": r >= 4.5})
(ROOT / "checks.json").write_text(json.dumps(out, indent=2))
fails = [x for x in out["boundaries"] + out["sampled"] if not x["pass"]]
print(len(out["boundaries"]), "boundaries;", len(out["sampled"]), "samples; fails:", json.dumps(fails, indent=1))
for s in out["sampled"]: print(s["screen"], s["where"], s["pixel"], s["ratio"])
