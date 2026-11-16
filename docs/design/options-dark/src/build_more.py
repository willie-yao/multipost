"""Caption v2 — remaining screens (static concept drawings, design only).

Run after build.py's helpers exist:  python build_more.py
Produces html/caption-*.html; render with render_more.sh.
"""
import build as B
from build import ic, statusbar, tabs, gesture, phone, CAPTION, BSKY, P1, P2, write, LABEL, a2_composer

B.ICONS.update({
    "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5M12 7.6v.01"/>',
    "warn": '<path d="M12 4l9 16H3z"/><path d="M12 10v4.5M12 17.4v.01"/>',
    "unk": '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.4a2.5 2.5 0 1 1 3.6 2.3c-.8.4-1.2 1-1.2 1.8v.4M12 16.8v.01"/>',
    "wifioff": '<path d="M3 3l18 18M8.5 16.4a5 5 0 0 1 7 0M5 12.9a10 10 0 0 1 4.4-2.4M14.6 10.5A10 10 0 0 1 19 12.9M2 9.3a15 15 0 0 1 4.3-2.6M11 5.1a15 15 0 0 1 11 4.2M12 20v.01"/>',
    "user": '<circle cx="12" cy="8" r="4"/><path d="M4 20a8 8 0 0 1 16 0"/>',
    "close": '<path d="M6 6l12 12M18 6L6 18"/>',
    "send": '<path d="M4 12l16-8-6 16-2.5-6.5z"/>',
    "hand": '<path d="M7 11V6.5a1.5 1.5 0 0 1 3 0V11M10 10V5a1.5 1.5 0 0 1 3 0v5M13 10V6a1.5 1.5 0 0 1 3 0v6M16 9.5a1.5 1.5 0 0 1 3 0V14a7 7 0 0 1-7 7h-1a6 6 0 0 1-5-2.7L3.5 14.6a1.6 1.6 0 0 1 2.6-1.8L7 14"/>',
    "posted": '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>',
})


def bar(title, back=True, actions=("more",)):
    lead = f'<div class="iconbtn">{ic("back")}</div>' if back else '<div style="width:12px"></div>'
    acts = "".join(f'<div class="iconbtn">{ic(a)}</div>' for a in actions)
    return f'<div class="appbar">{lead}<div class="title">{title}</div><div class="acts2">{acts}</div></div>'


def v2(*parts):
    return phone("dA v2", *parts)


def caps(*lines, cls=""):
    return "<br>".join(f'<span class="cap {cls}">{l}</span>' for l in lines)


THUMBS = f'<span class="th"><img src="{P1}" alt=""><img src="{P2}" alt=""></span>'


# ---------------------------------------------------------------- flow
def choose():
    def row(nm, acct, line, icon, on=True):
        return (f'<div class="pick"><span class="cbwrap"><span class="cb{" on" if on else ""}">{ic("check","s18") if on else ""}</span></span>'
                f'<div class="grow"><div><span class="nm">{nm}</span> <span class="acct">{acct}</span></div>'
                f'<div class="cap-line">{ic(icon,"s18")}{line}</div></div></div>')
    body = f"""
<div class="body"><div class="sec" style="padding-top:18px">
  <div class="h2">Where should this go?</div>
  <div class="lead" style="margin-bottom:14px">Nothing is sent until you review it.</div>
  {row("X", "@alexdemo", "Publishes from this app · connected", "send")}
  {row("Bluesky", "@alex.example", "Publishes from this app · connected", "send")}
  {row("Instagram", "", "You finish it in Instagram · choose the account there", "hand")}
  <div class="capsum">{caps("3 destinations. 2 publish from here.", "Instagram you finish yourself.")}</div>
  <span class="textbtn" style="margin-top:10px">{ic("user","s20")}Manage accounts</span>
</div></div>
<div class="bottom"><div class="btn primary">Continue to writing {ic("arrow","s20")}</div></div>"""
    return v2(statusbar(), bar("New post"), tabs(1), body, gesture())


def version():
    body = f"""
<div class="body">
  <div class="stage" style="padding-top:6px">
    <div class="note">@alex.example · publishes from this app</div>
    <div class="seg"><span>Shared caption</span><span class="on">{ic("check","s18")}Own caption</span></div>
    <div class="lbl"><span>Bluesky's caption</span><span class="saved">{ic("check","s18")}Saved on this device</span></div>
    <div class="subfield own"><span class="cap">{BSKY}<i class="caret"></i></span></div>
    <div class="counter"><span>84 characters</span><span>Bluesky's limit is checked at review</span></div>
  </div>
  <div class="sec" style="padding-top:14px">
    <div class="notice">{ic("info","s20")}<div>The shared caption changed after you wrote this one. Bluesky keeps its own.<br><span class="textbtn">Compare captions</span></div></div>
    <div class="acc" style="border-top:0;padding-top:14px"><div class="swrow"><div><div>Use shared photos 1–2</div><div class="acct" style="font-weight:400;font-size:14px">Turn off to choose different photos for Bluesky</div></div><span class="sw"></span></div></div>
    <span class="textbtn">Use the shared caption instead</span>
  </div>
</div>
<div class="bottom"><div class="btn primary">Done</div></div>"""
    return v2(statusbar(), bar("Bluesky version", actions=()), body, gesture())


def preview(nm, acct, text, own=False, issue=""):
    return (f'<div class="pv"><div class="top"><span class="nm">{nm}</span><span class="acct">{acct}</span>{THUMBS}</div>'
            f'<div class="txt"><span class="cap{" own" if own else ""}">{text}</span></div>{issue}</div>')


def review(variant="ready"):
    banner = ""
    if variant == "offline":
        banner = f'<div class="banner">{ic("wifioff","s20")}You\'re offline. Your draft is saved on this device.</div>'
    issue = ""
    if variant == "blocked":
        issue = (f'<div class="notice issue warn">{ic("warn","s20")}<div><b>Connection expired.</b> <span style="color:var(--text)">Reconnect Bluesky to publish this version.</span>'
                 f'<div class="row" style="gap:6px;margin:8px 0 8px"><span class="btn sm outlined" style="height:44px">Reconnect</span><span class="textbtn" style="padding:0 10px">Leave Bluesky out</span></div></div></div>')
    if variant == "ready":
        foot = f'<div class="note">Publishes to X and Bluesky. Prepares Instagram for you to finish.</div><div class="btn primary">Publish &amp; prepare {ic("send","s20")}</div>'
    elif variant == "offline":
        foot = '<div class="note">Needs a connection. Nothing sends by itself when you\'re back online.</div><div class="btn disabled">Publish &amp; prepare</div>'
    else:
        foot = '<div class="note">Reconnect Bluesky or leave it out to continue.</div><div class="btn disabled">Publish &amp; prepare</div>'
    body = f"""
<div class="body">{banner}
  <div class="grp"><div class="hdr"><span class="h3">Publish now</span><span class="note">Approximate previews</span></div>
    {preview("X", "@alexdemo", "A little color from today's walk. The city always leaves something worth noticing.")}
    {preview("Bluesky", "@alex.example", BSKY, own=True, issue=issue)}
  </div>
  <div class="grp" style="padding-top:6px"><div class="hdr"><span class="h3">Prepare only</span><span class="note">You post it</span></div>
    {preview("Instagram", "photos 1–2", "A little color from today's walk. The city always leaves something worth noticing.")}
  </div>
</div>
<div class="bottom">{foot}</div>"""
    return v2(statusbar(), bar("New post"), tabs(3), body, gesture())


# ---------------------------------------------------------------- library
def first_run():
    body = f"""
<div class="body">
  <div class="welcome"><div class="subs">{'<span class="cap">Write once.</span><br><span class="cap c2">Review each destination.</span><br><span class="cap">Finish Instagram yourself.</span>'}</div></div>
  <div class="sec" style="padding-top:22px">
    <div class="h2">Your next post starts here.</div>
    <div class="lead" style="font-size:16px;margin-top:8px">Drafts are saved on this device. You can write before connecting any account.</div>
    <div class="btn primary" style="margin-top:22px">{ic("plus","s20")}Create a draft</div>
    <div class="btn outlined" style="margin-top:12px">{ic("user","s20")}Set up accounts</div>
    <div class="note" style="margin-top:18px">X and Bluesky publish from this app once connected. Instagram never needs a sign-in here; you finish posts in Instagram.</div>
  </div>
</div>"""
    return v2(statusbar(), bar("Your posts", back=False, actions=("user",)), body, gesture())


def library():
    t = '<div class="tabs"><div class="tab on">Drafts · 2</div><div class="tab">Results · 1</div></div>'
    body = f"""
<div class="body">
  <div class="needs">
    <div class="subs"><span class="cap">Instagram is ready to share.</span><br><span class="cap">Bluesky didn't send.</span></div>
    <div class="note">From “A little color from today's walk” · 21:14</div>
    <div class="btn sm tonal">Open results {ic("arrow","s20")}</div>
  </div>
  <div class="sec" style="padding-top:8px">
    <div class="draft" style="border-top:0"><div class="th"><img src="{P2}" alt=""></div><div class="grow"><div class="tx">Ferns along the reservoir path, after the rain.</div><div class="meta">Saved 20:41 · X, Bluesky · Write</div></div></div>
    <div class="draft"><div class="th aa">Aa</div><div class="grow"><div class="tx">Thinking about trying film again this spring.</div><div class="meta">Saved yesterday · X · Choose</div></div></div>
    <div class="note" style="margin-top:14px;max-width:270px">Drafts live on this device only. Uninstalling the app removes them.</div>
  </div>
</div>
<div class="fab">{ic("plus")}New post</div>"""
    return v2(statusbar(), bar("Your posts", back=False, actions=("user", "more")), t, body, gesture())


def accounts():
    body = f"""
<div class="body"><div class="sec" style="padding-top:8px">
  <div class="lead" style="margin:0 0 14px">Connect only where you publish. Writing drafts never needs an account.</div>
  <div class="acc"><div class="top"><span class="nm">X</span><span class="acct">@alexdemo</span></div>
    <div class="st ok state">{ic("okc","s20")}Connected</div><div class="det">Publishes from this app.</div>
    <div class="acts"><span class="textbtn">Disconnect</span></div></div>
  <div class="acc"><div class="top"><span class="nm">Bluesky</span><span class="acct">@alex.example</span></div>
    <div class="st warn state">{ic("warn","s20")}Connection expired</div><div class="det">Reconnect to publish. Your drafts and results are safe.</div>
    <div class="acts"><span class="btn sm outlined">Reconnect Bluesky</span></div></div>
  <div class="acc"><div class="top"><span class="nm">Instagram</span><span class="acct">no sign-in</span></div>
    <div class="det">This app prepares photos and the caption on this phone. You choose the account and publish in Instagram.</div>
    <div class="swrow"><span>Assisted sharing</span><span class="sw"></span></div></div>
  <div class="note" style="margin-top:6px;border-top:1px solid var(--hair);padding-top:14px">Sign-in uses each service's own official flow. Services can change what they allow, so each publish is checked first.</div>
</div></div>"""
    return v2(statusbar(), bar("Accounts", actions=()), body, gesture())


# ---------------------------------------------------------------- publishing states
def unknown():
    body = f"""
<div class="body">
  <div class="hero" style="height:168px"><img src="{P1}" alt=""><span class="count cap">1 / 2</span>
    <div class="subs"><span class="cap">X published.</span><br><span class="cap">Bluesky is unconfirmed.</span></div></div>
  <div class="heronote">Sent 21:14 · each result is kept on this device.</div>
  <div class="res"><div class="top"><span class="nm">X</span><span class="acct">@alexdemo</span><span class="st ok state">{ic("okc","s20")}Published</span></div>
    <div class="det">Confirmed by X at 21:14</div></div>
  <div class="res focus"><div class="top"><span class="nm">Bluesky</span><span class="acct">@alex.example</span><span class="st warn state">{ic("unk","s20")}Unknown</span></div>
    <div class="det" style="color:var(--text)">The connection dropped after sending. Bluesky may have published it.</div>
    <div class="det">Check your Bluesky profile before sending again.</div>
    <div class="acts"><span class="btn sm outlined">{ic("open","s20")}Check Bluesky</span></div>
    <div class="row" style="gap:18px;margin-top:2px"><span class="textbtn">I found the post</span><span class="textbtn">Send again…</span></div></div>
  <div class="res"><div class="top"><span class="nm">Instagram</span><span class="st state">{ic("ready","s20")}Ready to share</span></div></div>
</div>
<div class="bottom"><div class="btn primary">Finish in Instagram {ic("arrow","s20")}</div></div>"""
    return v2(statusbar(), bar("Posting results"), body, gesture())


# ---------------------------------------------------------------- instagram finish states
def returned(dim=False):
    body = f"""
<div class="body">
  <div class="back">
    <div class="subs"><span class="cap">Back from Instagram.</span><br><span class="cap">Did you finish posting?</span></div>
    <div class="note">This app can't see Instagram, so your answer is the record. Nothing changes until you choose.</div>
    <div class="btns"><div class="btn primary">I've posted it</div><div class="btn outlined">Not yet</div></div>
  </div>
  <div class="log">
    <div class="ln" style="padding-top:14px"><span class="h3" style="font-size:16px">What happened on this phone</span></div>
    <div class="ln">{ic("check","s20")}Caption copied<span class="tm">21:20</span></div>
    <div class="ln">{ic("check","s20")}Photos 1–2 saved to your gallery<span class="tm">21:20</span></div>
    <div class="ln">{ic("open","s20")}Instagram opened · completion unknown<span class="tm">21:21</span></div>
    <div class="ln">{ic("ready","s20")}Status: still Ready to share<span class="tm"></span></div>
  </div>
</div>"""
    extra = ""
    if dim:
        extra = """<div class="scrim"></div><div class="dialog" role="dialog">
  <div class="dt">Mark Instagram as posted?</div>
  <div class="db">This records your confirmation on this phone. The app can't verify that the post is live.</div>
  <div class="da"><span class="textbtn">Cancel</span><span class="textbtn">Mark as posted</span></div></div>"""
    return v2(statusbar(), bar("Finish in Instagram"), body, gesture(), extra)


def marked():
    body = f"""
<div class="body">
  <div class="hero" style="height:168px"><img src="{P1}" alt=""><span class="count cap">1 / 2</span>
    <div class="subs"><span class="cap">X published. Instagram posted by you.</span><br><span class="cap">Bluesky still needs a retry.</span></div></div>
  <div class="heronote">Sent 21:14 · each result is kept on this device.</div>
  <div class="res"><div class="top"><span class="nm">X</span><span class="acct">@alexdemo</span><span class="st ok state">{ic("okc","s20")}Published</span></div>
    <div class="det">Confirmed by X at 21:14</div></div>
  <div class="res focus"><div class="top"><span class="nm">Bluesky</span><span class="acct">@alex.example</span><span class="st err state">{ic("errc","s20")}Not published</span></div>
    <div class="det">Couldn't connect at 21:14. Nothing was posted.</div>
    <div class="acts"><span class="btn sm outlined">{ic("retry","s20")}Retry Bluesky</span><span class="note">X won't post again.</span></div></div>
  <div class="res"><div class="top"><span class="nm">Instagram</span><span class="st state">{ic("posted","s20")}Marked posted</span></div>
    <div class="det">Your confirmation at 21:32. Not verified by the app.</div></div>
</div>"""
    snack = f'<div class="snack">Instagram marked as posted.<span class="textbtn">Undo</span></div>'
    return v2(statusbar(), bar("Posting results"), body, gesture(), snack)


SCREENS = {
    "caption-choose": choose, "caption-version": version, "caption-review": review,
    "caption-first-run": first_run, "caption-library": library, "caption-accounts": accounts,
    "caption-review-blocked": lambda: review("blocked"), "caption-review-offline": lambda: review("offline"),
    "caption-unknown": unknown, "caption-returned": returned,
    "caption-confirm": lambda: returned(dim=True), "caption-marked": marked,
}

BOARDS = [
    ("caption-flow-board", "wide", "Caption · the posting flow",
     "Choose, write, review: the stage indicator, one white action per screen, and every destination showing the exact words it will use. Cyan is always a destination's own caption.",
     [("Choose", "Destinations first; direct and assisted are named, not implied.", choose),
      ("Write", "The approved composer (Caption v2), for continuity.", a2_composer),
      ("Bluesky version", "Own caption in cyan; a notice when the shared post changed; shared photos kept.", version),
      ("Review", "Publish now and Prepare only are separate; the button says both.", review)]),
    ("caption-library-board", "", "Caption · library and accounts",
     "The home screen is a small local library, not a dashboard. Unfinished results stay on top until resolved.",
     [("First run", "The promise as subtitles; write before connecting anything.", first_run),
      ("Your posts", "What needs you first, then drafts; one New post action.", library),
      ("Accounts", "Connected, expired and assisted are stated plainly; no Instagram sign-in.", accounts)]),
    ("caption-states-publishing-board", "", "Caption · publishing states",
     "Blocking issues, offline and lost confirmation each name the destination, what happened and the only safe next step.",
     [("Connection needed", "Reconnect or explicitly leave Bluesky out; nothing is silently dropped.", lambda: review("blocked")),
      ("Offline", "Draft is safe; publishing waits for you, with no automatic resend.", lambda: review("offline")),
      ("Publication unknown", "No ordinary Retry. Check first; sending again is a deliberate choice.", unknown)]),
    ("caption-states-instagram-board", "", "Caption · finishing Instagram",
     "Returning from Instagram changes nothing by itself. The user's answer is recorded as theirs, and can be undone.",
     [("Back from Instagram", "Asks once, on screen; the log shows only what this phone did.", returned),
      ("Confirm", "A Material dialog: the record is a personal confirmation, not verification.", lambda: returned(dim=True)),
      ("Marked posted", "Shown as the user's report with a time; Undo in the snackbar; Bluesky still open.", marked)]),
]


def main():
    for name, fn in SCREENS.items():
        write(f"{name}.html", name, "single", fn())
    for name, wide, title, idea, items in BOARDS:
        cols = "".join(f'<figure>{fn()}<figcaption><b>{t}</b><span>{d}</span></figcaption></figure>' for t, d, fn in items)
        html = f"""<main class="board"><header><h1>{title}</h1><p class="idea">{idea}</p></header>
<section class="phones">{cols}</section><footer>{LABEL}</footer></main>"""
        write(f"{name}.html", title, f"boardpage {wide}".strip(), html)


if __name__ == "__main__":
    main()
