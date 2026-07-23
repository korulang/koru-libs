// list — Charm-class simple list (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <list title={{ title:s }} items={{ items:s }} selected={{ selected:d }}/>
//   koru/vaxis:list { win, title: string, items: string, selected: i64 }
//
// Craft: bubbles/list simple delegate — bold purple title (marginLeft 2),
// "<N>. <title>" rows with paddingLeft 4, the selected row swaps to
// paddingLeft 2 + "> " prefix (label still starts at column 4). Selected
// row in Charm pink + bold; unselected in soft contrast. Pagination footer
// at the bottom: one ● per page (current filled), dim ○ otherwise, capped
// to a 20-wide window. Page-aligned scroll keeps the selection visible.
//
// Items arrive as a single newline-delimited string (the same `string`
// payload path text-input uses); the host store owns only the selected
// index + count — the widget OWNS the paint/chrome, NOT the `! key`
// pipeline. Constant title/items are passed straight through `app` props
// (the progress-bar `max: 100` precedent); a store column can't hold a
// bare `string` literal (690_052/690_053 — needs `*std/string:String<…>`).
//
// Holes: a real `[]string` payload would beat the newline encoding (same
// payload-shape upgrade text-input flagged). Per-dot pink paginator color
// deferred (one printSegment per footer). The store-reject diagnostic
// embeds a user string literal UNESCAPED inside a Zig @compileError
// string literal → "expected ',' after argument" instead of the koru
// message (witnessed 2026-07-23, replay 07; not blocking — only fires
// under that misuse).
//
//   koruc run examples/component_list.k       (j/k navigate  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — selection lives here; the list only paints from it.
std/store:new(list) {
    selected: 0[i64],
    count:    15[i64]
}

koru/vaxis:component(hint) {
    <text>j/k navigate  |  q quit</text>
}

// Thin host chrome around the catalog tag — the widget is list.
koru/vaxis:component(app) {
    <stack-panel>
        <list title={{ title:s }} items={{ items:s }} selected={{ selected:d }}/>
        <hint/>
    </stack-panel>
}

koru/vaxis:run(title: "list")
! draw w |> app(win: w,
    title:    "What do you want for dinner?",
    items:    "Ramen\nTomato Soup\nHamburgers\nCheeseburgers\nCurrywurst\nOkonomiyaki\nPasta\nFillet Mignon\nCaviar\nJust Wine\nTacos\nSushi\nPizza\nPho\nBibimbap",
    list.selected)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'j' and list.selected < list.count - 1 |> std/store:stored { list.selected: list.selected + 1 }
! key k when k.ch == 'k' and list.selected > 0 |> std/store:stored { list.selected: list.selected - 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")