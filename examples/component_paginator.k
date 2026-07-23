// paginator — Charm-class pagination status chrome (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <paginator kind="dots"|"arabic" page={{ page:d }} total={{ total:d }}/>
//   koru/vaxis:paginator { win, page: i64, total: i64, kind: string }
//
// Charm's own note: bubbles/paginator does NOT render page *content* — it paints
// the page indicator and does the page math. This is the standalone reusable leaf
// (list already embeds an equivalent footer). Two display modes match bubbles/
// paginator's Type:
//   Dots   (default) — one ● per page, current page's dot pink #EE6FF8 + bold
//                      (Charm ActiveDot), the rest dim ○; spaced + centered.
//   Arabic ("arabic") — "N/M" (1-based current / total), current number pink +
//                      bold, "/M" dim (Charm defaults to "%d/%d").
//
// Page state (current page + total pages) lives in the HOST store and arrives as
// props; the widget OWNS the paint, NOT the `! key` pipeline. Host keys mutate
// `page` (Charm's h/l — arrows can't reach `! key` past run's 0x3000 codepoint
// filter, floated by viewport/list, so h/l it is). Both paginator tags below are
// driven by the SAME store — press h/l and the ActiveDot AND the Arabic count
// move together, proving one reusable widget in two modes.
//
// Holes: `kind` is a string literal prop (no bool/enum prop yet); real per-page
// content is out of scope by Charm's own design (paginator is chrome only).
//
//   koruc run examples/component_paginator.k   (h prev  l next  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — the page cursor lives here; the paginator only paints from it.
// total > 1 so the ActiveDot has room to move across the row.
std/store:new(pager) {
    page:  0[i64],
    total: 7[i64]
}

koru/vaxis:component(heading) {
    <text>  Charm paginator — pagination status chrome</text>
}

koru/vaxis:component(dots-cap) {
    <text>  Dots</text>
}

koru/vaxis:component(num-cap) {
    <text>  Arabic</text>
}

koru/vaxis:component(hint) {
    <text>  h prev   l next   q quit</text>
}

// Thin host chrome — the widget is paginator. Two instances (Dots + Arabic)
// stacked as status rows, both bound to the same page store. Labels pin above
// each; the hint sits on the bottom edge.
koru/vaxis:component(app) {
    <dock>
        <heading dock="top" h="2"/>
        <dots-cap dock="top" h="1"/>
        <paginator dock="top" h="1" kind="dots" page={{ page:d }} total={{ total:d }}/>
        <num-cap dock="top" h="2"/>
        <paginator dock="top" h="1" kind="arabic" page={{ page:d }} total={{ total:d }}/>
        <hint dock="bottom" h="1"/>
    </dock>
}

koru/vaxis:run(title: "paginator")
! draw w |> app(win: w, pager.page, pager.total)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'l' and pager.page < pager.total - 1 |> std/store:stored { pager.page: pager.page + 1 }
! key k when k.ch == 'h' and pager.page > 0 |> std/store:stored { pager.page: pager.page - 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
