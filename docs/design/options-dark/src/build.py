"""Generate the dark-mode concept drawings (static HTML) for options-dark.

Design-only artifact. Run:  python build.py   then  render.sh  to produce PNGs.
Nothing here is app code; every screen is an illustrative static drawing.
"""
from pathlib import Path

OUT = Path(__file__).parent / "html"
OUT.mkdir(exist_ok=True)

CAPTION = "A little color from today's walk. The city always leaves something worth noticing."
BSKY = "Poppies along the reservoir path. The city always leaves something worth noticing."
P1, P2 = "../../assets/flowers.jpg", "../../assets/leaves.jpg"

ICONS = {
    "back": '<path d="M20 12H5M11 5l-7 7 7 7"/>',
    "more": '<circle cx="12" cy="5" r="1.7" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.7" fill="currentColor" stroke="none"/><circle cx="12" cy="19" r="1.7" fill="currentColor" stroke="none"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "chev": '<path d="M9 5l7 7-7 7"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "copy": '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M15 5H6a2 2 0 0 0-2 2v9"/>',
    "save": '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    "open": '<path d="M14 4h6v6M20 4l-9 9M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4"/>',
    "retry": '<path d="M20 12a8 8 0 1 1-2.6-5.9M20 4v5h-5"/>',
    "okc": '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>',
    "errc": '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.6v.01"/>',
    "ready": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3.2" fill="currentColor" stroke="none"/>',
    "arrow": '<path d="M5 12h13M13 6l6 6-6 6"/>',
    "ring": '<circle cx="12" cy="12" r="8"/>',
    "edit": '<path d="M4 20h4L19 9l-4-4L4 16v4z"/>',
}


def ic(name, cls=""):
    return f'<svg class="i {cls}" viewBox="0 0 24 24" aria-hidden="true">{ICONS[name]}</svg>'


def statusbar():
    return '<div class="sb"><span>9:41</span><span class="sys"><i class="sig"></i><i class="bat"></i></span></div>'


def appbar(title):
    return (f'<div class="appbar"><div class="iconbtn">{ic("back")}</div>'
            f'<div class="title">{title}</div><div class="iconbtn">{ic("more")}</div></div>')


def tabs(cur=2):
    names = ["Choose", "Write", "Review"]
    out = "".join(f'<div class="tab{" on" if i + 1 == cur else ""}">{i + 1}&nbsp;&nbsp;{n}</div>' for i, n in enumerate(names))
    return f'<div class="tabs">{out}</div>'


def gesture():
    return '<div class="gesture"><i></i></div>'


def phone(cls, *parts):
    return f'<div class="phone {cls}">{"".join(parts)}</div>'


# ---------------------------------------------------------------- A · Caption
def a_composer():
    body = f"""
<div class="body">
  <div class="stage">
    <div class="hd"><b>Photos · 2</b><span class="tbtn">{ic("plus","s20")}Add photos</span></div>
    <div class="frames">
      <div class="frame"><img src="{P1}" alt=""><span class="n cap">1</span></div>
      <div class="frame"><img src="{P2}" alt=""><span class="n cap">2</span></div>
    </div>
  </div>
  <div class="sec">
    <div class="lbl"><span>Shared caption</span><span class="saved">{ic("check","s18")}Saved on this device</span></div>
    <div class="field">{CAPTION}<i class="caret"></i></div>
    <div class="dhd"><b>Destinations</b><span class="tbtn">Change</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">X</span><span class="acct">@alexdemo</span></div>
      <div class="sample"><span class="cap">A little color from today's…</span><span class="src">Shared</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Bluesky</span><span class="acct">@alex.example</span></div>
      <div class="sample"><span class="cap own">Poppies along the reservo…</span><span class="src">Own caption</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Instagram</span><span class="acct">You finish it there</span></div>
      <div class="sample"><span class="cap">A little color from today's…</span><span class="src">Shared</span></div></div><span class="chev">{ic("chev")}</span></div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Review post {ic("arrow","s20")}</div></div>"""
    return phone("dA", statusbar(), appbar("New post"), tabs(2), body, gesture())


def a_results():
    body = f"""
<div class="body">
  <div class="summary">
    <div class="line"><span class="cap">X published. Bluesky didn't send.</span></div>
    <div class="line"><span class="cap">Instagram is ready for you.</span></div>
    <div class="note">Sent from this phone at 21:14. Each result is kept on this device.</div>
  </div>
  <div class="res">
    <div class="top"><span class="nm">X</span><span class="acct">@alexdemo</span><span class="st ok state">{ic("okc","s20")}Published</span></div>
    <div class="det">Confirmed by X at <span class="time">21:14</span></div>
    <div class="acts"><span class="textbtn">View post {ic("open","s18")}</span></div>
  </div>
  <div class="res focus">
    <div class="top"><span class="nm">Bluesky</span><span class="acct">@alex.example</span><span class="st err state">{ic("errc","s20")}Not published</span></div>
    <div class="det">Couldn't connect at <span class="time">21:14</span>. Nothing was posted.</div>
    <div class="acts"><span class="btn sm outlined">{ic("retry","s20")}Retry Bluesky</span></div>
    <div class="note" style="margin-top:8px">Sends to Bluesky only. X won't post again.</div>
  </div>
  <div class="res">
    <div class="top"><span class="nm">Instagram</span><span class="st state">{ic("ready","s20")}Ready to share</span></div>
    <div class="det">2 photos and caption prepared. Not posted yet; you publish it in Instagram.</div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>"""
    return phone("dA", statusbar(), appbar("Posting results"), body, gesture())


def a_instagram():
    body = f"""
<div class="body">
  <div class="ladder"><span class="cur cap">Ready to share</span>{ic("chev","s18")}<span>Handed off</span>{ic("chev","s18")}<span>Marked posted</span></div>
  <div class="sec note" style="margin-top:10px">Nothing is on Instagram until you publish it there. This app can't see Instagram.</div>
  <div class="step">
    <div class="sh"><span class="cap">1</span>Copy the caption</div>
    <div class="capbox"><span class="cap">{CAPTION}</span></div>
    <div class="acts"><span class="btn sm tonal">{ic("copy","s20")}Copy caption</span></div>
  </div>
  <div class="step">
    <div class="sh"><span class="cap">2</span>Save the photos, in order</div>
    <div class="thumbs"><div class="frame"><img src="{P1}" alt=""><span class="n cap">1</span></div><div class="frame"><img src="{P2}" alt=""><span class="n cap">2</span></div>
      <span class="btn sm tonal" style="margin-left:auto;align-self:center">{ic("save","s20")}Save 2 photos</span></div>
  </div>
  <div class="step">
    <div class="sh"><span class="cap">3</span>Post it in Instagram</div>
    <div class="note" style="font-size:15px;margin-top:4px;color:var(--text)">Start a feed post, pick photos 1 and 2 in that order, paste the caption, check the account, then publish.</div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Open Instagram {ic("open","s20")}</div>
  <div class="row" style="justify-content:space-between;margin-top:4px"><span class="note">Opening it doesn't post anything.</span><span class="textbtn">I've posted it</span></div></div>"""
    return phone("dA", statusbar(), appbar("Finish in Instagram"), body, gesture())


# ------------------------------------------------- A · Caption v2 (more flair)
def a2_composer():
    body = f"""
<div class="body">
  <div class="stage">
    <div class="hd"><b>Photos · 2</b><span class="tbtn">{ic("plus","s20")}Add photos</span></div>
    <div class="frames">
      <div class="frame"><img src="{P1}" alt=""><span class="n cap">1</span></div>
      <div class="frame"><img src="{P2}" alt=""><span class="n cap">2</span></div>
    </div>
    <div class="lbl"><span>Shared caption</span><span class="saved">{ic("check","s18")}Saved on this device</span></div>
    <div class="subfield"><span class="cap">{CAPTION}<i class="caret"></i></span></div>
  </div>
  <div class="sec">
    <div class="dhd"><b>Destinations</b><span class="tbtn">Change</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">X</span><span class="acct">@alexdemo</span></div>
      <div class="sample"><span class="cap">A little color from today's…</span><span class="src">Shared</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Bluesky</span><span class="acct">@alex.example</span></div>
      <div class="sample"><span class="cap own">Poppies along the reserv…</span><span class="src">Own caption</span></div></div><span class="chev">{ic("chev")}</span></div>
    <div class="dest"><div class="grow"><div><span class="nm">Instagram</span><span class="acct">You finish it there</span></div>
      <div class="sample"><span class="cap">A little color from today's…</span><span class="src">Shared</span></div></div><span class="chev">{ic("chev")}</span></div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Review post {ic("arrow","s20")}</div></div>"""
    return phone("dA v2", statusbar(), appbar("New post"), tabs(2), body, gesture())


def a2_results():
    body = f"""
<div class="body">
  <div class="hero"><img src="{P1}" alt="">
    <span class="count cap">1 / 2</span>
    <div class="subs"><span class="cap">X published. Bluesky didn't send.</span><br><span class="cap">Instagram is ready for you.</span></div></div>
  <div class="heronote">Sent 21:14 · each result is kept on this device.</div>
  <div class="res">
    <div class="top"><span class="nm">X</span><span class="acct">@alexdemo</span><span class="st ok state">{ic("okc","s20")}Published</span></div>
    <div class="det">Confirmed by X at <span class="time">21:14</span></div>
    <div class="acts"><span class="textbtn">View post {ic("open","s18")}</span></div>
  </div>
  <div class="res focus">
    <div class="top"><span class="nm">Bluesky</span><span class="acct">@alex.example</span><span class="st err state">{ic("errc","s20")}Not published</span></div>
    <div class="det">Couldn't connect at <span class="time">21:14</span>. Nothing was posted.</div>
    <div class="acts"><span class="btn sm outlined">{ic("retry","s20")}Retry Bluesky</span><span class="note">X won't post again.</span></div>
  </div>
  <div class="res">
    <div class="top"><span class="nm">Instagram</span><span class="st state">{ic("ready","s20")}Ready to share</span></div>
    <div class="det">Photos and caption prepared. You publish it in Instagram.</div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>"""
    return phone("dA v2", statusbar(), appbar("Posting results"), body, gesture())


def a2_instagram():
    body = f"""
<div class="body">
  <div class="igstage">
    <div class="frames"><div class="frame"><img src="{P1}" alt=""><span class="n cap">1</span></div><div class="frame"><img src="{P2}" alt=""><span class="n cap">2</span></div></div>
    <div class="ladder"><span class="cur">{ic("ready","s18")}Ready to share</span>{ic("chev","s18")}<span>Handed off</span>{ic("chev","s18")}<span>Marked posted</span></div>
    <div class="note">Nothing is on Instagram until you publish it there.</div>
  </div>
  <div class="step">
    <div class="sh"><span class="cap">1</span>Copy the caption</div>
    <div class="capbox"><span class="cap">{CAPTION}</span></div>
    <div class="acts"><span class="btn sm tonal">{ic("copy","s20")}Copy caption</span></div>
  </div>
  <div class="step">
    <div class="sh"><span class="cap">2</span>Save photos 1–2, in order</div>
    <div class="acts"><span class="btn sm tonal">{ic("save","s20")}Save 2 photos</span></div>
  </div>
  <div class="step">
    <div class="sh"><span class="cap">3</span>Post it in Instagram</div>
    <div style="font-size:15px;margin-top:4px">New feed post, photos 1 then 2, paste the caption, check the account, publish.</div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Open Instagram {ic("open","s20")}</div>
  <div class="row" style="justify-content:space-between;margin-top:4px"><span class="note">Opening it doesn't post anything.</span><span class="textbtn">I've posted it</span></div></div>"""
    return phone("dA v2", statusbar(), appbar("Finish in Instagram"), body, gesture())


# ----------------------------------------------------------- B · Contact Sheet
def b_composer():
    body = f"""
<div class="body">
  <div class="strip">
    <div class="nums"><span style="width:136px">1</span><span style="width:136px">2</span></div>
    <div class="frames">
      <div class="fr" style="width:128px;height:96px"><img src="{P1}" alt=""></div>
      <div class="fr" style="width:128px;height:96px"><img src="{P2}" alt=""></div>
      <div class="slot" style="width:86px;height:96px">{ic("plus")}Add</div>
    </div>
    <div class="hint">Tap a frame to describe, reorder or remove it.</div>
  </div>
  <div class="sec">
    <div class="lbl"><span>Shared caption</span><span class="saved">{ic("check","s18")}Saved on this device</span></div>
    <div class="field">{CAPTION}<i class="caret"></i></div>
    <div class="dhd"><b>Destinations</b><span class="tbtn">Change</span></div>
    <div class="proof"><div class="grow"><div class="nm">X</div><div class="sub">Shared caption · photos 1–2</div></div>
      <div class="mini"><img src="{P1}" alt=""><img src="{P2}" alt=""></div><span class="chev">{ic("chev")}</span></div>
    <div class="proof"><div class="grow"><div class="nm">Bluesky</div><div class="sub"><span class="own">Own caption</span> · photos 1–2</div></div>
      <div class="mini"><img src="{P1}" alt=""><img src="{P2}" alt=""></div><span class="chev">{ic("chev")}</span></div>
    <div class="proof"><div class="grow"><div class="nm">Instagram</div><div class="sub">Shared caption · you finish it there</div></div>
      <div class="mini"><img src="{P1}" alt=""><img src="{P2}" alt=""></div><span class="chev">{ic("chev")}</span></div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Review post {ic("arrow","s20")}</div></div>"""
    return phone("dB", statusbar(), appbar("New post"), tabs(2), body, gesture())


def b_results():
    body = f"""
<div class="body">
  <div class="attempt"><div class="mini" style="padding:0;background:none"><img src="{P1}" alt="" style="width:56px;height:42px"><img src="{P2}" alt="" style="width:56px;height:42px"></div>
    <div class="t">A little color from today's walk…<div class="note">Sent 21:14 · kept on this device</div></div></div>
  <div class="res">
    <div class="top"><span class="nm">X</span><span class="st ok state">{ic("okc","s20")}Published</span></div>
    <div class="acct">@alexdemo · confirmed by X at 21:14</div>
    <div class="acts"><span class="textbtn">View post {ic("open","s18")}</span></div>
  </div>
  <div class="res">
    <div class="top"><span class="nm">Bluesky</span><span class="st err state">{ic("errc","s20")}Not published</span></div>
    <div class="acct">@alex.example · 21:14</div>
    <div class="det">Couldn't connect before sending. Nothing was posted.</div>
    <div class="acts"><span class="btn sm outlined">{ic("retry","s20")}Retry Bluesky</span><span class="note">X won't post again.</span></div>
  </div>
  <div class="res">
    <div class="top"><span class="nm">Instagram</span><span class="st state">{ic("ready","s20")}Ready to share</span></div>
    <div class="det">Photos 1–2 and the caption are prepared. Not posted yet; you publish it in Instagram.</div>
  </div>
</div>
<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>"""
    return phone("dB", statusbar(), appbar("Posting results"), body, gesture())


def b_instagram():
    body = f"""
<div class="body">
  <div class="bigstrip">
    <div class="nums"><span>1</span><span>2</span></div>
    <div class="frames"><div class="fr"><img src="{P1}" alt=""></div><div class="fr"><img src="{P2}" alt=""></div></div>
    <div class="hint">Pick them in this order in Instagram.</div>
  </div>
  <div class="ladder"><span class="cur">{ic("ready","s18")}Ready to share</span><span class="sep"></span><span>{ic("ring","s18")}Handed off</span><span class="sep"></span><span>{ic("ring","s18")}Marked posted</span></div>
  <div class="step"><span class="k">1</span><div class="grow"><div class="sh">Copy the caption</div>
    <div class="capbox">{CAPTION}</div>
    <div class="acts"><span class="btn sm tonal">{ic("copy","s20")}Copy caption</span></div></div></div>
  <div class="step"><span class="k">2</span><div class="grow"><div class="sh">Save photos 1–2</div>
    <div class="acts"><span class="btn sm tonal">{ic("save","s20")}Save 2 photos</span></div></div></div>
  <div class="step"><span class="k">3</span><div class="grow"><div class="sh">Post it in Instagram</div>
    <div style="font-size:15px;line-height:22px;margin-top:2px">New feed post, photos 1 then 2, paste the caption, check the account, publish.</div></div></div>
</div>
<div class="bottom"><div class="btn primary">Open Instagram {ic("open","s20")}</div>
  <div class="row" style="justify-content:space-between;margin-top:4px"><span class="note">Opening it doesn't post anything.</span><span class="textbtn">I've posted it</span></div></div>"""
    return phone("dB", statusbar(), appbar("Finish in Instagram"), body, gesture())


# ----------------------------------------------------------- C · Margin Night
def c_composer():
    body = f"""
<div class="body">
  <div class="g blk"><div class="gl">Post</div><div class="gc">
    <div class="post serif">{CAPTION}<i class="caret"></i></div>
    <div class="saved">{ic("check","s18")}Saved on this device</div></div></div>
  <div class="g blk"><div class="gl">Photos</div><div class="gc">
    <div class="ph"><div class="fr"><img src="{P1}" alt=""><span class="n">1</span></div><div class="fr"><img src="{P2}" alt=""><span class="n">2</span></div></div>
    <span class="tbtn">{ic("plus","s20")}Add photos</span></div></div>
  <div class="g" style="padding-top:6px"><div class="gl">Versions</div><div class="gc">
    <div class="ver"><div class="grow"><div class="nm">X</div><div class="sub">Uses the shared post</div></div><span class="chev">{ic("chev")}</span></div>
    <div class="ver"><div class="grow"><div class="nm">Bluesky</div><div class="sub">Own caption</div><div class="ex">“Poppies along the reservoir path…”</div></div><span class="chev">{ic("chev")}</span></div>
    <div class="ver"><div class="grow"><div class="nm">Instagram</div><div class="sub">Uses the shared post · you finish it there</div></div><span class="chev">{ic("chev")}</span></div>
  </div></div>
</div>
<div class="bottom"><div class="btn primary">Review post {ic("arrow","s20")}</div></div>"""
    return phone("dC", statusbar(), appbar("New post"), tabs(2), body, gesture())


def c_results():
    body = f"""
<div class="body">
  <div class="attempt"><img src="{P1}" alt=""><div><div class="ex serif">A little color from today's walk.</div><div class="note">2 photos · the version you reviewed</div></div></div>
  <div class="res g"><div class="gl"><span class="ok">{ic("okc","s20")}</span>21:14</div><div class="gc">
    <div class="nm">X</div><div class="st ok">Published</div><div class="det">@alexdemo · confirmed by X</div>
    <div class="acts"><span class="textbtn">View post {ic("open","s18")}</span></div></div></div>
  <div class="res g"><div class="gl"><span class="err">{ic("errc","s20")}</span>21:14</div><div class="gc">
    <div class="nm">Bluesky</div><div class="st err">Not published</div><div class="det">Couldn't connect before sending. Nothing was posted.</div>
    <div class="acts"><span class="btn sm outlined">{ic("retry","s20")}Retry Bluesky</span></div>
    <div class="note" style="margin-top:8px">Sends to Bluesky only. X won't post again.</div></div></div>
  <div class="res g"><div class="gl">{ic("ready","s20")}Next</div><div class="gc">
    <div class="nm">Instagram</div><div class="st">Ready to share</div><div class="det">Photos and caption prepared. You publish it in Instagram.</div></div></div>
</div>
<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>"""
    return phone("dC", statusbar(), appbar("Posting results"), body, gesture())


def c_instagram():
    body = f"""
<div class="body">
  <div class="status"><span class="chip">{ic("ready","s18")}Ready to share</span><span class="note">then Handed off, then Marked posted</span></div>
  <div class="note" style="margin:6px 18px 0">Nothing is on Instagram until you publish it there.</div>
  <div class="g step"><div class="gl stepnum">1</div><div class="gc"><div class="sh">Copy the caption</div>
    <div class="ex serif">{CAPTION}</div>
    <div class="acts"><span class="btn sm tonal">{ic("copy","s20")}Copy caption</span></div></div></div>
  <div class="g step"><div class="gl stepnum">2</div><div class="gc"><div class="sh">Save the photos, in order</div>
    <div class="thumbs"><div class="fr"><img src="{P1}" alt=""><span class="n">1</span></div><div class="fr"><img src="{P2}" alt=""><span class="n">2</span></div></div>
    <div class="acts"><span class="btn sm tonal">{ic("save","s20")}Save 2 photos</span></div></div></div>
  <div class="g step"><div class="gl stepnum">3</div><div class="gc"><div class="sh">Post it in Instagram</div>
    <div class="note" style="font-size:15px;color:var(--text);margin-top:2px">New feed post, photos 1 then 2, paste the caption, check the account, publish.</div></div></div>
</div>
<div class="bottom"><div class="btn primary">Open Instagram {ic("open","s20")}</div>
  <div class="row" style="justify-content:space-between;margin-top:4px"><span class="note">Opening it doesn't post anything.</span><span class="textbtn">I've posted it</span></div></div>"""
    return phone("dC", statusbar(), appbar("Finish in Instagram"), body, gesture())


DIRS = {
    "a-caption": dict(
        letter="A", name="Caption", css="a-caption.css",
        screens=[a_composer, a_results, a_instagram],
        idea="The post is a caption. Each destination row shows the actual words it will publish, set like a closed caption: white for the shared caption, cyan for its own.",
        fit="True black stage for photos, Atkinson Hyperlegible Next throughout, white primary action. Legibility is the identity.",
        trade="Plainest of the three; distinctiveness rests on the caption samples and type, not ornament. True black needs care with long scrolling (OLED smear) and with photos that have black edges.",
        chips=[("#000000", "Stage"), ("#131517", "Ground"), ("#F2F2EE", "Text / primary"), ("#7DD7E9", "Own caption")],
    ),
    "b-contact": dict(
        letter="B", name="Contact Sheet", css="b-contact.css",
        screens=[b_composer, b_results, b_instagram],
        idea="Photos lead as a strip of numbered frames on a dark film-base band. The frame numbers are the order Instagram needs, so the same numbers carry from composer to the Instagram finish.",
        fit="Warm film-base ground, celluloid text and primary, condensed Archivo for frame numbers and destination names.",
        trade="Best for photo posts; text-only posts lose the strip and look plainer. Warm dark plus cream is the nearest of the three to Dispatch's warmth, though without its amber or rail.",
        chips=[("#0A0806", "Rebate"), ("#17120E", "Ground"), ("#F2E9DB", "Celluloid / primary"), ("#C6B9A6", "Edge print")],
    ),
    "c-margin-night": dict(
        letter="C", name="Margin Night", css="c-margin-night.css",
        screens=[c_composer, c_results, c_instagram],
        idea="Margin, evolved for dark: serif post text, and an annotation gutter that labels sections, holds result times and states, and numbers the Instagram steps.",
        fit="Indigo night ground, warm paper text in Literata, periwinkle annotations and primary, Barlow for controls.",
        trade="Writing feels most personal here, but the gutter costs about 90dp of width. It must fold into inline labels at large font sizes and narrow screens. Indigo with periwinkle edges toward the rejected plum family.",
        chips=[("#13131C", "Ground"), ("#1D1D29", "Raised"), ("#EEEAE0", "Text"), ("#B5B2FF", "Annotation / primary")],
    ),
}
SCREEN_NAMES = ["composer", "results", "instagram"]
SCREEN_CAPS = [("Composer", "Shared caption, photos and each destination's version."),
               ("Posting results", "Published, failed and Instagram stay separate. Retry touches Bluesky only."),
               ("Assisted Instagram", "Copy, save, post it yourself. Opening Instagram is not proof of posting.")]

V2_CAPS = [("Composer", "Photos and the shared caption share one black stage: picture above, subtitles below."),
           ("Posting results", "The post's first frame, subtitled with what happened. Rows below stay separate."),
           ("Assisted Instagram", "Photos in order on the stage; steps as numbered caption cues.")]

HEAD ='<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{t}</title>' \
       '<link rel="stylesheet" href="../base.css"><link rel="stylesheet" href="../a-caption.css"><link rel="stylesheet" href="../a-caption-v2.css"><link rel="stylesheet" href="../a-caption-more.css">' \
       '<link rel="stylesheet" href="../b-contact.css"><link rel="stylesheet" href="../c-margin-night.css">' \
       '<link rel="stylesheet" href="../board.css"></head><body class="{b}">'
LABEL = "Unapproved design concept · static drawing · illustrative content and accounts · not an app screenshot"


def write(name, title, body_cls, html):
    (OUT / name).write_text(HEAD.format(t=title, b=body_cls) + html + "</body></html>", encoding="utf-8")


def main():
    for key, d in DIRS.items():
        phones = [fn() for fn in d["screens"]]
        for sn, ph in zip(SCREEN_NAMES, phones):
            write(f"{key}-{sn}.html", f'{d["name"]} {sn}', "single", ph)
        cols = "".join(
            f'<figure>{ph}<figcaption><b>{c[0]}</b><span>{c[1]}</span></figcaption></figure>'
            for ph, c in zip(phones, SCREEN_CAPS))
        chips = "".join(f'<span class="chip"><i style="background:{h}"></i>{lbl}<em>{h}</em></span>' for h, lbl in d["chips"])
        html = f"""<main class="board">
<header><h1>{d['letter']} · {d['name']}</h1><p class="idea">{d['idea']}</p></header>
<section class="phones">{cols}</section>
<section class="notes"><div><h2>Look</h2><p>{d['fit']}</p><div class="chips">{chips}</div></div>
<div><h2>Tradeoffs</h2><p>{d['trade']}</p></div></section>
<footer>{LABEL}</footer></main>"""
        write(f"{key}-board.html", f'{d["name"]} board', "boardpage", html)

    # Caption v2: refinement with more flair (v1 files stay untouched)
    v2 = [a2_composer(), a2_results(), a2_instagram()]
    for sn, ph in zip(SCREEN_NAMES, v2):
        write(f"a-caption-v2-{sn}.html", f"Caption v2 {sn}", "single", ph)
    cols = "".join(f'<figure>{ph}<figcaption><b>{c[0]}</b><span>{c[1]}</span></figcaption></figure>' for ph, c in zip(v2, V2_CAPS))
    html = f"""<main class="board">
<header><h1>A · Caption, with more flair</h1><p class="idea">Same tokens, same faces, same flow. The caption signature is turned up: letterboxed screens, the shared caption set as real subtitles under the photos, and results subtitled over the post's first frame.</p></header>
<section class="phones">{cols}</section>
<section class="notes"><div><h2>What changed from the first Caption</h2><p>Top and bottom bars move to the true-black stage, so each screen reads as a framed picture. The caption editor sits on the stage, each line in its own caption box. Titles step up to 26sp extra-bold. Instagram's steps become numbered caption cues. No new colours, fonts or components.</p></div>
<div><h2>Tradeoffs</h2><p>More black means more OLED smear when scrolling. Subtitles over the results photo need a scrim fallback for very bright or busy images. Line-boxed editing text must still behave as one ordinary text field: selection, cursor and TalkBack reading as continuous text are untested.</p></div></section>
<footer>{LABEL}</footer></main>"""
    write("a-caption-v2-board.html", "Caption v2 board", "boardpage", html)
    rows = "".join(
        f'<h2 class="rowh">{lbl}</h2><section class="phones">' +
        "".join(f'<figure>{fn()}</figure>' for fn in fns) + '</section>'
        for lbl, fns in [("First Caption", DIRS["a-caption"]["screens"]), ("Caption with more flair", [a2_composer, a2_results, a2_instagram])])
    html = f"""<main class="board"><header><h1>Caption: first version and more flair</h1>
<p class="idea">Same content and flow. Top row: the version you reviewed. Bottom row: the refinement.</p></header>{rows}<footer>{LABEL}</footer></main>"""
    write("compare-caption-v1-v2.html", "Caption v1 v2", "boardpage", html)

    # side-by-side comparisons, same sample content
    for idx, sn in enumerate(SCREEN_NAMES):
        cols = "".join(
            f'<figure>{d["screens"][idx]()}<figcaption><b>{d["letter"]} · {d["name"]}</b><span>{d["fit"]}</span></figcaption></figure>'
            for d in DIRS.values())
        html = f"""<main class="board"><header><h1>Three dark directions · {SCREEN_CAPS[idx][0].lower()}</h1>
<p class="idea">Same post, same destinations, same flow: choose, write, review. Only the visual system changes.</p></header>
<section class="phones">{cols}</section><footer>{LABEL}</footer></main>"""
        write(f"compare-{sn}.html", f"Compare {sn}", "boardpage", html)


if __name__ == "__main__":
    main()
