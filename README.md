# Cat Cursor for macOS

>

> b站上刷到这个光标发现没有mac的安装渠道，一怒之下搞了个mac版的（
>
> 由于MAC本身的限制，切换app的时候有概率会显示原版光标，但是延迟实测不影响使用。
>
> Windows 原版光标由 b 站 [HappyCadogt](https://space.bilibili.com/406949928) 制作，
> 本项目基于其 V1.5 移植。Windows 原版下载：
> https://happycadogt.lanzoul.com/b01881lrdg 密码：`1145`
> 顺便这个链接里的文档我发现也有linux版本的
>
> 顺便这个的美术严格来讲属于b站的 [EverydayOneCat](https://b23.tv/36WQ9xd)。
> 大家也多多支持cat老师，ta有很多可爱猫动画🥺

An animated cat pointer for macOS — an unofficial port of the Windows cursor
pack **《普通的鼠标指针》V1.5** by **HappyCadogt**.

The pointer plays a looping idle animation, reacts to clicks with a paw, and
follows the system cursor's shape: text fields, window edges, split-view
dividers, crosshairs and more.

---

## Credits

None of the art here is mine. This is a macOS port and nothing more — two other
people made everything you can actually see.

- **The cursor pack** — [HappyCadogt](https://space.bilibili.com/406949928) (bilibili)
  built the Windows pack this is ported from.
  Original download: https://happycadogt.lanzoul.com/b01881lrdg — password `1145`.
  Ported from **V1.5**.
- **The cat** — the character itself is
  [EverydayOneCat](https://b23.tv/36WQ9xd)'s (bilibili).

The pack is **free**. If someone charged you for it, ask for a refund.

Per the author's terms: free to use, study and remix, **non-commercial only**,
and please credit the author when redistributing. Those terms apply to this
repository too — the artwork here is derived from theirs.

If you like the cursors, go follow the author. That is the point of this being
free.

---

## Why this is an app and not a "cursor theme"

Windows installs cursor packs through the registry. **macOS has no equivalent** —
system pointers are baked into the OS and there is no supported way to replace
them.

So this app does the only thing that works without weakening system security: it
hides the real pointer and draws its own in a transparent, click-through window
floating above everything else, glued to the mouse every display refresh.

To know *which* cursor to draw, it reads the cursor the system is currently
showing and matches it against a table of known cursors. That is the answer the
frontmost app already gave the window server, so it works everywhere — including
web pages and Electron apps — and needs **no permissions at all**: no
Accessibility, no Input Monitoring, no Screen Recording, and no SIP changes.

---

## Install

There is no prebuilt download yet. Building takes about a minute and needs
macOS 14+ with Xcode command line tools.

```bash
git clone <this repo>
cd CatCursorV1.5
./Scripts/build_app.sh
open build/CatCursor.app
```

A cat icon appears in the menu bar — that menu is the whole interface:

| Menu item | |
|---|---|
| **Cat Cursor Enabled** | turn the custom pointer on or off without quitting |
| **Size** | Small / Medium / Large |
| **Follow Cursor Shape** | switch artwork with the system cursor, or keep the idle cat everywhere |
| **Paw Animation on Click** | the mouse-down reaction |
| **Launch at Login** | |
| **Quit Cat Cursor** | restores the normal pointer |

The build is ad-hoc signed, which is fine on the machine that built it. Moving
the `.app` to another Mac would need a Developer ID and notarisation.

**If anything ever goes wrong, quit the app and your normal pointer comes back.**
If it crashes or is force-quit, macOS restores the pointer by itself within about
a second — you cannot end up stuck without a cursor.

---

## What replaces what

| System cursor | Shown instead |
|---|---|
| normal arrow | idle cat |
| text / vertical text | text cat |
| link (pointing hand) | link cat |
| crosshair | precision cat |
| not-allowed | unavailable cat |
| horizontal resize — window edges *and* split dividers | left-right cat |
| vertical resize — window edges *and* split dividers | up-down cat |
| diagonal corner resize | diagonal cats |
| open hand / closed hand (grab) | move cat |
| **drag-copy, drag-link, contextual menu, "poof"** | **the real cursor, unchanged** |
| anything unrecognised | **the real cursor, unchanged** |

The last two rows are deliberate. Those cursors carry meaning in their badge — a
green plus means *copy*, a grey cross means *this disappears if you let go* —
and swapping in a cat would throw that information away. **Showing the wrong
cursor is worse than showing no cursor**, so anything the app is not sure about
is left alone.

Seven cursors from the original pack are unused (help, handwriting,
alternate-select, person, pin, busy, app-starting): macOS has no state that would
ever show them.

---

## Known limits

- **Slight lag.** The real pointer is composited by the window server with
  near-zero latency; a drawn one is a frame behind (~16ms). You will not notice
  it normally, but you may on a fast flick of the mouse.
- **The real pointer can flash back when you switch apps.** macOS sometimes
  re-shows its own cursor across an app or Space change; the app notices and
  hides it again, but there is a brief window where you see the original. In
  practice this does not get in the way.
- **Not everywhere.** The login window, lock screen and system password prompts
  draw above every third-party window, so the normal pointer is used there. This
  is an OS limit, not a bug.
- **Changing the system pointer size breaks shape switching.** Cursor
  recognition compares against reference images captured at the default pointer
  size, so resizing every system cursor makes them all unrecognisable. It fails
  safely — everything falls back to the real cursor rather than showing
  something wrong — but the cat will only appear as the idle pointer until the
  size is set back. Open an issue if you need this; regenerating the reference
  data is possible, the tool for it just is not in this repository yet.
- **The five static cursors are a little soft.** They only exist at 32×32 in the
  original pack and are scaled up to match the animated ones. A pointer that
  changes *size* every time it changes shape is more distracting than slightly
  soft edges, so this was the deliberate trade.

---

## Building on this

The artwork is regenerated from the original Windows pack rather than committed
by hand:

```bash
python3 Scripts/prepare_assets.py --source /path/to/安装文件
```

`Sources/MacCursor/` is a small AppKit app: an overlay window, a CALayer that
plays PNG frame sequences, display-link pointer tracking, and the cursor
recognition described above. `Resources/cursor_table.json` holds the reference
images that recognition matches against.

Three self-checks are built into the binary:

```bash
# draw any cursor offscreen with a crosshair on its hotspot
build/CatCursor.app/Contents/MacOS/MacCursor --render-test /tmp/out.png vertical medium

# run the overlay briefly and report what is actually on screen
build/CatCursor.app/Contents/MacOS/MacCursor --diagnose

# log every shape change as it happens
build/CatCursor.app/Contents/MacOS/MacCursor --verbose
```

### Found a cursor that does not turn into a cat?

Most likely macOS is using a cursor that is not in the reference data yet —
there are considerably more of them than the public `NSCursor` API suggests, and
several are private. Window-edge resizing, for instance, uses entirely different
artwork from the split-view dividers.

Open an issue describing **exactly what you were doing** — which app, and what
you hovered over or dragged. That is enough to reproduce it, capture the cursor
and add it.

---

## Licence

The **artwork** is not mine to license — it belongs to HappyCadogt, and the cat
character to EverydayOneCat. It is included here under HappyCadogt's terms:
free, non-commercial, credit the author. The **code** in this repository is free
to use under the same spirit — non-commercial, keep the attribution.
