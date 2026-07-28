# Cat Cursor for macOS

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

An animated cat pointer for macOS, ported (without asking, but with love) from
the Windows cursor pack **《普通的鼠标指针》V1.5** by **HappyCadogt**.

It idles with a little animation loop, waves a paw when you click, and
changes shape along with whatever your cursor is doing — typing, resizing a
window, dragging a divider, and so on.

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

## Why not just a cursor theme?

macOS doesn't let you replace the system pointers the way Windows does. So
this app fakes it — it hides your real cursor and draws a cat on top, chasing
your mouse everywhere, in every app, no special permissions needed.

---

## Install

There's no download yet — you'll have to build it yourself. Takes about a
minute, needs macOS 14+ and Xcode command line tools.

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

**If anything ever goes wrong, quit the app and your normal pointer comes back.**
Even if it crashes, macOS puts your real cursor back on its own within about a
second — you can't get stuck without one.

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

The last two rows are on purpose — those cursors carry a meaning in their
little badge (a green plus means *copy*, a fading cross means *this
disappears if you let go*), and turning them into a cat would throw that
information away. Better to leave a cursor alone than show the wrong thing.

A handful of cursors from the original pack just never come up on macOS, so
they're not used.

---

## Known limits

- **A tiny bit of lag.** The cat trails your actual mouse position by a
  fraction of a second. Usually invisible, but you might catch it on a fast
  flick of the mouse.
- **The real cursor can flash briefly when you switch apps.** It shows up for
  an instant and then disappears again — not much to be done about it.
- **Not on the login screen or password prompts.** Those sit above everything
  else, so the system cursor is all you get there.
- **Resizing your system pointer stops shape-matching from working.** The cat
  will just idle instead of guessing wrong. Open an issue if this bites you.
- **The five static cursors look a little soft.** They only existed small in
  the original pack and got scaled up. A pointer that changes size every time
  it changes shape would be more distracting than a little softness, so that
  was the trade.

---

## Found a cursor that doesn't turn into a cat?

Probably macOS is using one that isn't recognized yet — there are more
cursor shapes floating around than you'd expect. Open an issue describing
**exactly what you were doing** — which app, and what you were hovering over
or dragging — and that's usually enough to track it down and add it.

---

## Licence

The **artwork** is not mine to license — it belongs to HappyCadogt, and the cat
character to EverydayOneCat. It is included here under HappyCadogt's terms:
free, non-commercial, credit the author. The **code** in this repository is free
to use under the same spirit — non-commercial, keep the attribution.
