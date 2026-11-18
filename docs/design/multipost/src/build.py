"""Generate the Multipost brand-direction concept drawings (static HTML).

Design-only artifact: authored HTML/CSS, rendered with headless Edge by render.sh.
Nothing here is app code. Accounts, photos and times are illustrative.
"""
from pathlib import Path

OUT = Path(__file__).parent / "html"
OUT.mkdir(exist_ok=True)

NAME = "Multipost"  # temporary working name; the identity does not depend on it
TAG = "Write once. Share your way."
CAPTION = "A little color from today's walk. The city always leaves something worth noticing."
BSKY = "Poppies along the reservoir path."
P1, P2 = "../../assets/flowers.jpg", "../../assets/leaves.jpg"

ICONS = {
    "back": '<path d="M20 12H5M11 5l-7 7 7 7"/>',
    "more": '<circle cx="12" cy="5" r="1.7" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.7" fill="currentColor" stroke="none"/><circle cx="12" cy="19" r="1.7" fill="currentColor" stroke="none"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "chev": '<path d="M9 5l7 7-7 7"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "open": '<path d="M14 4h6v6M20 4l-9 9M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4"/>',
    "retry": '<path d="M20 12a8 8 0 1 1-2.6-5.9M20 4v5h-5"/>',
    "okc": '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>',
    "errc": '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.6v.01"/>',
    "ready": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3.2" fill="currentColor" stroke="none"/>',
    "q": '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.3a2.6 2.6 0 0 1 5 .9c0 1.8-2.6 2.2-2.6 3.8M12 17v.01"/>',
    "handoff": '<circle cx="12" cy="12" r="9"/><path d="M8 12h8M13 9l3 3-3 3"/>',
    "you": '<circle cx="12" cy="8" r="3.6"/><path d="M5 20c1-4 4-5.5 7-5.5s6 1.5 7 5.5"/>',
    "arrow": '<path d="M5 12h13M13 6l6 6-6 6"/>',
    "person": '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.2-4.5 4.4-6 8-6s6.8 1.5 8 6"/>',
}


def ic(name, cls=""):
    return f'<svg class="i {cls}" viewBox="0 0 24 24" aria-hidden="true">{ICONS[name]}</svg>'


# Launcher marks on the Android adaptive-icon grid (108 x 108, 66 dp safe zone).
def mark_a(fg="#FFFFFF", bg="#2B3BC9"):
    # A ditto mark ("the same again") over a ruled line: one post, carried again.
    return (f'<rect width="108" height="108" fill="{bg}"/>'
            f'<path d="M47 37 L41 58 M64 37 L58 58" stroke="{fg}" stroke-width="10" stroke-linecap="round"/>'
            f'<rect x="35" y="66" width="38" height="7" rx="3.5" fill="{fg}"/>')


def mark_b():
    # Two subtitle lines: the shared caption (white) and a destination's own (cyan).
    return ('<rect width="108" height="108" fill="#000"/>'
            '<rect x="27" y="40" width="54" height="12" rx="1.5" fill="#F2F2EE"/>'
            '<rect x="27" y="57" width="38" height="12" rx="1.5" fill="#7DD7E9"/>')


def icon(mark, size, shape="circle"):
    clip = ('<circle cx="54" cy="54" r="54"/>' if shape == "circle"
            else '<rect width="108" height="108" rx="30"/>')
    cid = f"c{size}{shape}{abs(hash(mark)) % 9999}"
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 108 108" aria-hidden="true">'
            f'<defs><clipPath id="{cid}">{clip}</clipPath></defs><g clip-path="url(#{cid})">{mark}</g></svg>')


def statusbar():
    return '<div class="sb"><span>9:41</span><span class="sys"><i class="sig"></i><i class="bat"></i></span></div>'


def appbar(title, back=True):
    lead = f'<div class="iconbtn">{ic("back")}</div>' if back else ""
    return f'<div class="appbar">{lead}<div class="title">{title}</div><div class="iconbtn">{ic("more")}</div></div>'


def tabs(cur=2):
    names = ["Choose", "Write", "Review"]
    out = "".join(f'<div class="tab{" on" if i + 1 == cur else ""}">{i + 1}&nbsp;&nbsp;{n}</div>' for i, n in enumerate(names))
    return f'<div class="tabs">{out}</div>'


def gesture():
    return '<div class="gesture"><i></i></div>'


def phone(cls, *parts):
    return f'<div class="phone {cls}">{"".join(parts)}</div>'


# ------------------------------------------------------------- A · Impression
def a_imp(kind, label, time="", icon_name="", size=""):
    t = f' <time>{time}</time>' if time else ""
    return f'<span class="imp {kind} {size}">{ic(icon_name, "s18")}{label}{t}</span>'


A_PUB = lambda s="": a_imp("ok solid", "Published", "21:14", "check", s)
A_NOT = lambda s="": a_imp("err", "Not published", "21:14", "errc", s)
A_UNK = lambda s="": a_imp("warn", "Unknown", "21:14", "q", s)
A_READY = lambda s="": a_imp("ink", "Ready to share", "", "ready", s)
A_HAND = lambda s="": a_imp("ink", "Handed off", "21:16", "handoff", s)
A_YOU = lambda s="": a_imp("ink solid", "You marked posted", "21:20", "you", s)


def a_library():
    body = f"""
<div class="body">
  <div class="sec">
    <div class="sech"><b>Needs you</b></div>
  </div>
  <div class="res focus" style="border-top:0;border-bottom:1px solid var(--hair)">
    <div class="mini"><img src="{P1}" alt=""><div class="grow"><div class="ell" style="font-size:16px;font-weight:600">A little color from today's walk.</div>
      <div class="meta num">Sent today at 21:14</div></div></div>
    <div style="display:flex;flex-direction:column;gap:6px;margin-top:12px">
      <div class="row" style="gap:10px"><span class="nm" style="width:92px;font-size:16px">X</span>{A_PUB("sm")}</div>
      <div class="row" style="gap:10px"><span class="nm" style="width:92px;font-size:16px">Bluesky</span>{A_NOT("sm")}</div>
      <div class="row" style="gap:10px"><span class="nm" style="width:92px;font-size:16px">Instagram</span>{A_READY("sm")}</div>
    </div>
    <div style="margin-top:12px"><span class="btn sm outline">Open results {ic("arrow","s20")}</span></div>
  </div>
  <div class="sec">
    <div class="sech"><b>Drafts · 2</b></div>
    <div class="dest"><div class="mini grow"><img src="{P2}" alt=""><div class="grow"><div style="font-size:16px;line-height:1.35">Ferns along the reservoir path, after the rain.</div>
      <div class="meta num">Saved 20:41 · X, Bluesky · Write</div></div></div></div>
    <div class="dest"><div class="mini grow"><div class="aa">Aa</div><div class="grow"><div style="font-size:16px;line-height:1.35">Thinking about trying film again this spring.</div>
      <div class="meta">Saved yesterday · X · Choose</div></div></div></div>
    <p class="meta" style="margin-top:14px;max-width:30ch;font-size:15px;line-height:1.45">Drafts live on this device only. Uninstalling the app removes them.</p>
  </div>
  <span class="fab">{ic("plus")}New post</span>
</div>"""
    head = (f'<div class="appbar" style="padding:0 4px 0 16px;gap:10px">{icon(mark_a(), 32, "rect")}'
            f'<div class="title" style="padding-left:0">{NAME}</div><div class="iconbtn">{ic("person")}</div></div>')
    return phone("a", statusbar(), head, body, gesture())


def a_composer():
    body = f"""
<div class="body">
  <div class="plate">
    <div class="hd"><b>Photos · 2</b><span class="tbtn">{ic("plus","s20")}Add photos</span></div>
    <div class="frames">
      <div class="frame"><img src="{P1}" alt=""><span class="n">1</span></div>
      <div class="frame"><img src="{P2}" alt=""><span class="n">2</span></div>
    </div>
    <div class="lbl"><span>Shared caption</span><span class="saved">{ic("check","s18")}Saved on this device</span></div>
    <div class="field">{CAPTION}<i class="caret"></i></div>
  </div>
  <div class="sec">
    <div class="sech"><b>Destinations</b><span class="tbtn">Change</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">X</span><span class="acct">@alexdemo</span></div>
      <div class="sample"><span class="src"><span class="ditto">〃</span>Shared caption</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Bluesky</span><span class="acct">@alex.example</span></div>
      <div class="sample"><span class="t own">{BSKY}</span><span class="src ownl">Own caption</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Instagram</span><span class="acct">You finish it there</span></div>
      <div class="sample"><span class="src"><span class="ditto">〃</span>Shared caption</span></div></div><span class="chev">{ic("chev")}</span></div>
  </div>
</div>"""
    bottom = f'<div class="bottom"><div class="btn primary">Review post {ic("arrow","s20")}</div></div>'
    return phone("a", statusbar(), appbar("New post"), tabs(2), body, bottom, gesture())


def a_results():
    body = f"""
<div class="body">
  <div class="plate" style="padding:10px">
    <div class="mini"><img src="{P1}" alt=""><div class="grow"><div class="ell" style="font-size:16px;font-weight:600">A little color from today's walk.</div>
      <div class="meta num">2 photos · reviewed 21:13 · kept on this device</div></div></div>
  </div>
  <div style="height:12px"></div>
  <div class="res">
    <div class="top"><div><span class="nm">X</span><span class="acct">@alexdemo</span></div></div><div class="mark">{A_PUB()}</div>
    <p>Confirmed by X.</p>
    <div class="acts"><span class="btn text">{ic("open","s20")}View post</span></div>
  </div>
  <div class="res focus">
    <div class="top"><div><span class="nm">Bluesky</span><span class="acct">@alex.example</span></div></div><div class="mark">{A_NOT()}</div>
    <p>Couldn't connect. Nothing was posted.</p>
    <div class="acts"><span class="btn sm outline">{ic("retry","s20")}Retry Bluesky</span><span>X won't post again.</span></div>
  </div>
  <div class="res">
    <div class="top"><div><span class="nm">Instagram</span></div></div><div class="mark">{A_READY()}</div>
    <p>Photos and caption are prepared. You publish it in Instagram.</p>
  </div>
</div>"""
    bottom = f'<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>'
    return phone("a", statusbar(), appbar("Results"), body, bottom, gesture())


def a_brand():
    chips = [("#F2F3F0", "Card", "ground"), ("#FFFFFF", "Sheet", "the post"), ("#16171A", "Ink", "text, main action"),
             ("#4B5058", "Pencil", "secondary text"), ("#2B3BC9", "Ultramarine", "own caption, mark"),
             ("#1C6B3A", "Green", "published"), ("#B3261E", "Red", "not published"), ("#7A5300", "Ochre", "unknown")]
    chip_html = "".join(f'<div><i style="background:{c}"></i><span>{n} <em>{h}</em></span></div>'
                        for c, n, h in chips)
    return f"""<div class="phone a brand" style="border-radius:20px">
  <div class="lockup">{icon(mark_a(), 64, "rect")}<span class="wm">{NAME}</span></div>
  <div class="tag">{TAG}</div>
  <div class="bh">Launcher icon (adaptive: rounded, circle, small)</div>
  <div class="icons">{icon(mark_a(), 88, "rect")}{icon(mark_a(), 64)}{icon(mark_a(), 44)}
    {icon(mark_a("#2B3BC9", "#FFFFFF"), 64)}</div>
  <div class="bh">Palette</div>
  <div class="chips">{chip_html}</div>
  <div class="bh">Type</div>
  <div class="spec"><span class="disp" style="font-weight:600;font-size:22px">Rubik · names, titles, states</span>
    <span style="font-size:18px;font-weight:600">Atkinson Hyperlegible Next · your words, every control</span></div>
  <div class="bh">States are dated impressions: shape, word and icon</div>
  <div class="imps">{A_PUB("sm")}{A_NOT("sm")}{A_UNK("sm")}{A_READY("sm")}{A_HAND("sm")}{A_YOU("sm")}</div>
</div>"""


# ------------------------------------------------------- B · Caption, evolved
def b_bug(kind, label, time="", icon_name=""):
    t = f' <time>{time}</time>' if time else ""
    return f'<span class="bug {kind}">{ic(icon_name, "s18")}{label}{t}</span>'


B_PUB = lambda: b_bug("ok", "Published", "21:14", "okc")
B_NOT = lambda: b_bug("err", "Not published", "21:14", "errc")
B_UNK = lambda: b_bug("warn", "Unknown", "21:14", "q")
B_READY = lambda: b_bug("", "Ready to share", "", "ready")
B_HAND = lambda: b_bug("", "Handed off", "21:16", "handoff")
B_YOU = lambda: b_bug("", "You marked posted", "21:20", "you")


def b_library():
    body = f"""
<div class="body">
  <div class="needs">
    <div class="subs"><span class="cap">Bluesky didn't send.</span><br><span class="cap">Instagram is ready for you.</span></div>
    <div class="meta num" style="margin-top:6px">From "A little color from today's walk" · 21:14</div>
    <div style="margin-top:12px"><span class="btn sm tonal">Open results {ic("arrow","s20")}</span></div>
  </div>
  <div class="sec">
    <div class="sech"><b>Drafts · 2</b></div>
    <div class="dest"><div class="mini grow"><img src="{P2}" alt=""><div class="grow"><div style="font-size:16px;line-height:1.35">Ferns along the reservoir path, after the rain.</div>
      <div class="meta num">Saved 20:41 · X, Bluesky · Write</div></div></div></div>
    <div class="dest"><div class="mini grow"><div class="aa">Aa</div><div class="grow"><div style="font-size:16px;line-height:1.35">Thinking about trying film again this spring.</div>
      <div class="meta">Saved yesterday · X · Choose</div></div></div></div>
    <p class="meta" style="margin-top:14px;max-width:30ch;font-size:15px;line-height:1.45">Drafts live on this device only. Uninstalling the app removes them.</p>
  </div>
  <span class="fab">{ic("plus")}New post</span>
</div>"""
    head = (f'<div class="appbar" style="padding:0 4px 0 16px;gap:10px">{icon(mark_b(), 32, "rect")}'
            f'<div class="title" style="padding-left:0">{NAME}</div><div class="iconbtn">{ic("person")}</div></div>')
    return phone("b", statusbar(), head, body, gesture())


def b_composer():
    body = f"""
<div class="body">
  <div class="stage">
    <div class="hd"><b>Photos · 2</b><span class="tbtn">{ic("plus","s20")}Add photos</span></div>
    <div class="frames">
      <div class="frame"><img src="{P1}" alt=""><span class="n">1</span></div>
      <div class="frame"><img src="{P2}" alt=""><span class="n">2</span></div>
    </div>
    <div class="lbl"><span>Shared caption</span><span>{ic("check","s18")}Saved on this device</span></div>
    <div class="field"><span class="cap">{CAPTION}</span><i class="caret"></i></div>
  </div>
  <div class="sec">
    <div class="sech"><b>Destinations</b><span class="tbtn">Change</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">X</span><span class="acct">@alexdemo</span></div>
      <div class="sample"><span class="t cap">A little color from today's walk.</span><span class="src">Shared</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Bluesky</span><span class="acct">@alex.example</span></div>
      <div class="sample"><span class="t cap own">{BSKY}</span><span class="src">Own caption</span></div></div><span class="chev">{ic("chev")}</span></div>
  </div>
</div>"""
    bottom = f'<div class="bottom"><div class="btn primary">Review post {ic("arrow","s20")}</div></div>'
    return phone("b", statusbar(), appbar("New post"), tabs(2), body, bottom, gesture())


def b_results():
    body = f"""
<div class="body">
  <div class="hero"><img src="{P1}" alt="">
    <div class="subs"><span class="cap">X published.</span><br><span class="cap">Bluesky didn't send.</span><br><span class="cap">Instagram is ready for you.</span></div></div>
  <div class="heroline num">Reviewed 21:13 · each result is kept on this device.</div>
  <div class="res">
    <div class="top"><div><span class="nm">X</span><span class="acct">@alexdemo</span></div></div><div class="mark">{B_PUB()}</div>
    <p>Confirmed by X. <u style="color:var(--text);font-weight:700">View post</u></p>
  </div>
  <div class="res focus">
    <div class="top"><div><span class="nm">Bluesky</span></div></div><div class="mark">{B_NOT()}</div>
    <p>Couldn't connect. Nothing was posted.</p>
    <div class="acts"><span class="btn sm outline">{ic("retry","s20")}Retry Bluesky</span><span>X won't post again.</span></div>
  </div>
  <div class="res">
    <div class="top"><div><span class="nm">Instagram</span></div></div><div class="mark">{B_READY()}</div>
    <p>Photos and caption are prepared. You publish it in Instagram.</p>
  </div>
</div>"""
    bottom = f'<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>'
    return phone("b", statusbar(), appbar("Results"), body, bottom, gesture())


def b_brand():
    chips = [("#000000", "Stage", "frame, captions"), ("#131517", "Ground", "working area"), ("#1D2023", "Raised", "fields"),
             ("#F2F2EE", "White", "shared caption, action"), ("#B6BBC0", "Grey", "secondary text"),
             ("#7DD7E9", "Cyan", "own caption, mark"), ("#8CD9A4", "Green", "published"), ("#FF9F9F", "Red", "not published")]
    chip_html = "".join(f'<div><i style="background:{c}"></i><span>{n} <em>{h}</em></span></div>'
                        for c, n, h in chips)
    return f"""<div class="phone b brand" style="border-radius:20px;background:#000">
  <div class="lockup">{icon(mark_b(), 64, "rect")}<span class="wm">{NAME}</span></div>
  <div class="tag"><span class="cap" style="background:#1D2023">Write once.</span><br><span class="cap" style="background:#1D2023">Share <span style="color:var(--own)">your way.</span></span></div>
  <div class="bh">Launcher icon (adaptive: rounded, circle, small)</div>
  <div class="icons home">{icon(mark_b(), 88, "rect")}{icon(mark_b(), 64)}{icon(mark_b(), 44)}</div>
  <div class="bh">Palette</div>
  <div class="chips">{chip_html}</div>
  <div class="bh">Type</div>
  <div class="spec"><span style="font-weight:800;font-size:22px">Atkinson Hyperlegible Next</span>
    <span style="font-size:17px">One family, four steps: 26 / 21 / 16 / 14 sp</span></div>
  <div class="bh">States are broadcast bugs: box, icon, word, time</div>
  <div class="imps">{B_PUB()}{B_NOT()}{B_UNK()}{B_READY()}{B_HAND()}{B_YOU()}</div>
</div>"""


# ----------------------------------------------------------------- pages
def page(css, inner, single=True):
    links = "".join(f'<link rel="stylesheet" href="../{c}">' for c in ["base.css", "board.css", *css])
    cls = "single" if single else "boardpage"
    return f'<!doctype html><html><head><meta charset="utf-8">{links}</head><body class="{cls}">{inner}</body></html>'


DIRS = {
    "a-impression": dict(
        css=["a-impression.css"], screens=[a_brand, a_library, a_composer, a_results],
        title="A · Impression",
        idea=("Every destination receives an impression of the same post, and each result is a dated mark you can trust. "
              "Light card stock, ink type and one ultramarine reserved for “your own version”. The post sits on one white "
              "sheet that keeps the same composition from Write to Results."),
        notes=[("What changes", "<ul><li>Light, calm ground; photos read true on white.</li><li>Rubik for names, titles and states; Atkinson stays for your words and controls.</li><li>States become impressions: a filled mark for confirmed, an outline for waiting on you, a dashed mark for unknown. Every mark has an icon, a word and a time.</li><li>The ditto mark (〃) labels a shared caption and anchors the icon.</li></ul>"),
               ("What it keeps", "<ul><li>The Choose → Write → Review flow, labels and actions.</li><li>One dominant action per screen, now ink black.</li><li>“Own caption” always labelled; ultramarine replaces cyan for that one job.</li><li>No new components: standard buttons, tabs, fields and rows.</li></ul>"),
               ("Main risk", "It's a light theme. Using it at night is brighter than today's app, and a matching dark scheme isn't drawn here: it would be added work to design and verify. A second face (Rubik) adds about 360 KB and an OFL notice.")],
        caps=["Brand: mark, palette, type, states", "Library", "Composer", "Results"]),
    "b-caption": dict(
        css=["b-caption.css"], screens=[b_brand, b_library, b_composer, b_results],
        title="B · Caption, evolved",
        idea=("The app you have now, given a brand. The post is a caption: white subtitle boxes for the shared caption and cyan for a "
              "destination's own. The new mark is two subtitle lines, one white and one cyan, which is the app's core idea in a 48 dp tile."),
        notes=[("What changes", "<ul><li>A launcher mark and wordmark lockup that state the shared/own idea.</li><li>The library header carries the lockup; what needs you is subtitled at the top.</li><li>States become broadcast bugs: a black box with a coloured icon, a word and a time.</li><li>“Write once. Share your way.” set as subtitles on first run.</li></ul>"),
               ("What it keeps", "<ul><li>The current tokens, Atkinson Hyperlegible Next, the true-black stage and the letterboxing.</li><li>Cyan for own captions, white for shared captions and the main action.</li><li>Every native screen, the evidence and the tests largely as they are.</li></ul>"),
               ("Main risk", "It's the smallest change and may still read as “Caption”. True black brings OLED smear when scrolling. Subtitles over bright photos still rely on their boxes.")],
        caps=["Brand: mark, palette, type, states", "Library", "Composer", "Results"]),
}

for key, d in DIRS.items():
    names = ["brand", "library", "composer", "results"]
    figs = []
    for n, fn, cap in zip(names, d["screens"], d["caps"]):
        html = fn()
        (OUT / f"{key}-{n}.html").write_text(page(d["css"], html), encoding="utf-8")
        figs.append(f'<figure>{html}<figcaption><b>{cap}</b></figcaption></figure>')
    notes = "".join(f"<div><h2>{h}</h2>{t}</div>" for h, t in d["notes"])
    board = (f'<div class="board"><header><h1>{d["title"]}</h1><p class="idea">{d["idea"]}</p></header>'
             f'<div class="phones">{"".join(figs)}</div><div class="notes">{notes}</div>'
             f'<footer>Concept · static drawing · illustrative accounts, photos and times · not an app screenshot · '
             f'“{NAME}” is a temporary working name</footer></div>')
    (OUT / f"{key}-board.html").write_text(page(d["css"], board, single=False), encoding="utf-8")
print("built", sorted(p.name for p in OUT.glob("*.html")))
