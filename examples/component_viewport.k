// viewport — Charm-class scrollable content window (COMPONENT_CHALLENGE).
//
// PUBLIC SURFACE (the catalog tag):
//   <viewport content={{ content:s }} offset={{ y:d }}/>
//   koru/vaxis:viewport { win, content: string, offset: i64 }
//
// Craft: bubbles/viewport's job — content taller than the window, the widget
// paints ONLY the visible slice starting at the host-owned scroll offset.
// Long lines hard-clip at the right edge (bubbles' no-soft-wrap default);
// the widget is chromeless like bubbles' — pager chrome (title, position,
// keys) is host markup around the tag. The store owns the offset; the
// widget owns the paint of the visible lines — keys mutate state, NOT pixels.
//
// Holes: host cannot see the window height, so max scroll is last-line-at-top
// (count-1) instead of bubbles' count-height clamp — clamping paint tighter
// than the host guard would dead-zone the keys. Arrow keys can never reach
// `! key`: run's dispatcher drops codepoint > 0x3000 and kitty arrows are PUA
// (floated, not routed around) — j/k + d/u it is. Soft-wrap deferred (honest
// hard-clip). Real []string payload deferred (same hole as list).
//
//   koruc run examples/component_viewport.k   (j/k line  d/u half-page  g/G ends  q quit)

import std/io
import std/fmt
import std/store
import koru/vaxis

// Host state — scroll offset lives here; the viewport only paints from it.
// count mirrors the number of content lines (41) so guards clamp honestly.
std/store:new(scroll) {
    y:     0[i64],
    count: 41[i64]
}

koru/vaxis:component(title) {
    <text>── Mr. Pager ──────────────────────────────</text>
}

koru/vaxis:component(status) {
    <text>line {{ line:d }} of {{ count:d }}   j/k scroll  d/u half-page  g/G ends  q quit</text>
}

// Thin host chrome around the catalog tag — the widget is viewport. It needs
// a tall window (it fills whatever it is handed), so `<dock>`'s fill slot
// carries it; title and status pin to the edges (the bubbletea pager shape).
koru/vaxis:component(app) {
    <dock>
        <title dock="top" h="2"/>
        <viewport dock="fill" content={{ content:s }} offset={{ y:d }}/>
        <status dock="bottom" h="1" line={{ line:d }} count={{ count:d }}/>
    </dock>
}

koru/vaxis:run(title: "viewport")
! draw w |> app(win: w,
    content: "The Viewport\n============\n\nA viewport is the simplest honest widget: a window onto\ncontent that does not fit. Everything else in a pager —\nthe title, the scroll position, the key hints — is chrome\naround this one idea: paint the slice, skip the rest.\n\n 1. The store owns the offset.\n 2. The widget owns the paint.\n 3. The keys mutate state, never pixels.\n\nThat separation is the whole design. When j bumps the\noffset, the next draw hands the viewport a new number and\nthe visible slice moves down one line. Nothing scrolls;\nthe world is repainted from state, every frame, and it is\nfast because the widget touches only the rows it shows.\n\nScrolling\n---------\n\nj or k moves one line. d and u jump half a page. g goes\nhome; G rides to the end — the last line parked at the\ntop of the window, the way less and vim leave it.\n\nLines longer than the window clip at the right edge rather than wrapping, which keeps columns honest and scanning calm — this line is deliberately long to prove it.\n\nClipping is not a compromise. Hard edges are what make a\nterminal feel solid: text never re-flows under your eyes,\nnever shifts a column while you read. Soft-wrap is a real\nfeature and it is deferred, not faked.\n\nThe End of the Content\n----------------------\n\nYou are near the bottom now. Past this point the window\nsimply runs out of lines to show, and the empty rows stay\nempty — no tildes, no filler, just the quiet edge of the\ncontent, which is the terminal's version of a margin.\n\n            · fin ·",
    scroll.y, line: scroll.y + 1, scroll.count)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'j' and scroll.y < scroll.count - 1 |> std/store:stored { scroll.y: scroll.y + 1 }
! key k when k.ch == 'k' and scroll.y > 0 |> std/store:stored { scroll.y: scroll.y - 1 }
! key k when k.ch == 'd' and scroll.y < scroll.count - 12 |> std/store:stored { scroll.y: scroll.y + 12 }
! key k when k.ch == 'd' and scroll.y >= scroll.count - 12 and scroll.y < scroll.count - 1 |> std/store:stored { scroll.y: scroll.count - 1 }
! key k when k.ch == 'u' and scroll.y >= 12 |> std/store:stored { scroll.y: scroll.y - 12 }
! key k when k.ch == 'u' and scroll.y > 0 and scroll.y < 12 |> std/store:stored { scroll.y: 0 }
! key k when k.ch == 'g' and scroll.y > 0 |> std/store:stored { scroll.y: 0 }
! key k when k.ch == 'G' and scroll.y < scroll.count - 1 |> std/store:stored { scroll.y: scroll.count - 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
