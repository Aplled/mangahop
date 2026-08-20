# MangaHop

<img src="assets/icon.png" width="96" align="right">

Small macOS menu bar app for reading manga on aggregator sites without ever
touching their next/prev buttons, which are usually ad traps or straight up
redirect scams. Press a hotkey and it bumps the chapter number in the current
tab's URL instead.

So if you're on

    https://w6.dandadan.net/manga/dandadan-chapter-104/

and hit ctrl+cmd+right, the tab goes to chapter 105. That's the whole app.

Works with Chrome, Brave, Edge, Arc, Vivaldi and Safari. It's a single Swift
file, no dependencies, no Electron.

## Install

You need the Xcode command line tools (`xcode-select --install` if you don't
have them), then:

    ./build.sh
    open MangaHop.app

A book icon shows up in the menu bar. The first time you press a hotkey macOS
will ask if MangaHop can control your browser — say yes, that's how it reads
and sets the tab URL. If you want it always running, add it to
Settings > Login Items.

## Hotkeys

ctrl+cmd+right for next, ctrl+cmd+left for previous. To change them open
Settings from the menu bar icon, click the hotkey button and press the new
combo.

## Ad zapping

On by default, toggle it from the menu bar icon ("Zap ads after hopping").
After each hop it injects a small script into the tab that disables
window.open (that's what popunders use), removes cross-origin ad iframes and
deletes full-screen overlays. To be clear: this is cosmetic cleanup on the
page, not a real network-level ad blocker — for that use an actual content
blocker extension.

Browsers don't let apps run javascript in tabs by default, so flip one
setting once (MangaHop will pop up and tell you this if it's missing):

    chrome / brave / edge:  View > Developer > Allow JavaScript from Apple Events
    safari:                 Settings > Advanced > Show Develop menu,
                            then Develop > Allow JavaScript from Apple Events

## Popup closing

Also on by default ("Close popup tabs" in the menu): while you're on a manga
chapter page, any new tab that opens onto a domain none of your other tabs
use gets closed within about a second. That's the popunder trick these sites
pull when you click anywhere on the page. Popunders that open on the manga
site itself and then bounce to the scam domain a moment later get caught
too — new tabs are watched for about 20 seconds and closed if they leave.

It's careful about what counts as unwanted. Tabs you open yourself are fine —
the new tab page, cmd+clicking a chapter link (same site, so it's kept),
switching tabs. It only guards at all while the tab you were on looks like a
manga chapter, so a random tab opening while you're elsewhere is none of its
business. One thing it can't catch: a site redirecting the tab you're
currently reading, since that looks identical to you clicking a link — but if
you hop with the hotkey you never click anything, so those don't happen.

Chromium browsers only (Chrome, Brave, Edge, Arc, Vivaldi) — Safari doesn't
expose what's needed.

## How it finds the chapter

Most of these sites run the same handful of stacks, so the URLs are
predictable:

    .../dandadan-chapter-104/          most wordpress (madara) sites
    .../chapter-104-5/                 how those sites write chapter 104.5
    .../chapter_1044.5                 mangakakalot style
    .../title/12345-dandadan/c104      mangapark style
    ...viewer?episode_no=104           webtoons
    .../capitulo-104, chapitre-104     spanish/french sites

It also understands ch, chap, ep, episode, and zero-padded numbers like 007.
If nothing matches it falls back to the last number in the path (never the
domain, so the w6 in w6.dandadan.net is safe).

If a site still isn't detected right: open Settings, paste any chapter URL
from it, and pick which number is the chapter from the dropdown. It shows you
a preview of what the next-chapter URL would look like, and remembers the
choice for that site.

Doesn't work on MangaDex — their chapter URLs are random ids, nothing to
increment.

A chapter that doesn't exist just 404s, hop again to skip past it. You can
also sanity check the parsing from the terminal:

    ./MangaHop --shift "https://w6.dandadan.net/manga/dandadan-chapter-104/" next

Config lives in ~/.mangahop.json if you'd rather edit it by hand.
