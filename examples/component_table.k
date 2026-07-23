// table — Charm-class data table (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <table headers={{ headers:s }} widths={{ widths:s }} rows={{ rows:s }} selected={{ selected:d }}/>
//   koru/vaxis:table { win, headers: string, widths: string, rows: string, selected: i64 }
//
// Charm's job (bubbles/table): columns with fixed widths, a bold header row
// over a dim underline (Header BorderBottom), data rows below, and a SELECTED
// row painted bold + Charm pink #EE6FF8 (bubbles DefaultStyles Selected =
// bold + lipgloss "212"). Cell text wider than its column truncates with a
// trailing "…" (ansi.Truncate) — the Country column at width 8 shows it.
// Cells pad one column on each side (Padding(0,1)).
//
// The cursor index lives in the HOST store and arrives as a prop; j/k move
// it, g/G jump to the ends — the widget OWNS the paint, NOT the `! key`
// pipeline. More rows than the fill band holds, so moving the cursor past
// the last visible row flips to the next page (page-aligned scroll keeps the
// selection on screen — the same stateless shape as list; bubbles' smooth
// offset viewport needs widget-owned scroll state, an honest deferred hole).
//
// Payload is host-owned strings (bubbles FromValues): headers and widths are
// `|`-separated; rows are one line each, fields `|`-separated. A real typed
// []Column / []Row payload is the deferred hole (same upgrade list/help
// flagged for their flat string payloads).
//
//   koruc run examples/component_table.k       (j/k move  g/G ends  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — only the cursor lives here; the widget paints the rest.
std/store:new(table) {
    selected: 0[i64],
    count:    20[i64]
}

koru/vaxis:component(heading) {
    <text>  Charm table — most populous cities</text>
    <text>  j/k move   g/G ends   q quit</text>
}

// Thin host chrome — the widget is table. It takes the fill band (header +
// underline + as many data rows as fit); the heading is pinned on top.
koru/vaxis:component(app) {
    <dock>
        <heading dock="top" h="3"/>
        <table dock="fill" headers={{ headers:s }} widths={{ widths:s }} rows={{ rows:s }} selected={{ selected:d }}/>
    </dock>
}

koru/vaxis:run(title: "table")
! draw w |> app(win: w,
    headers: "Rank|City|Country|Population",
    widths:  "4|16|8|10",
    rows:    "1|Tokyo|Japan|37,274,000\n2|Delhi|India|32,065,760\n3|Shanghai|China|28,516,904\n4|Dhaka|Bangladesh|22,478,116\n5|São Paulo|Brazil|22,429,800\n6|Mexico City|Mexico|22,085,140\n7|Cairo|Egypt|21,750,020\n8|Beijing|China|21,333,332\n9|Mumbai|India|20,961,472\n10|Osaka|Japan|19,059,856\n11|Chongqing|China|16,874,740\n12|Karachi|Pakistan|16,839,950\n13|Istanbul|Turkey|15,636,243\n14|Kinshasa|DR Congo|15,628,085\n15|Lagos|Nigeria|15,387,639\n16|Buenos Aires|Argentina|15,369,919\n17|Kolkata|India|15,133,888\n18|Manila|Philippines|14,406,059\n19|Tianjin|China|13,589,078\n20|Guangzhou|China|13,301,532",
    table.selected)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'j' and table.selected < table.count - 1 |> std/store:stored { table.selected: table.selected + 1 }
! key k when k.ch == 'k' and table.selected > 0 |> std/store:stored { table.selected: table.selected - 1 }
! key k when k.ch == 'g' and table.selected > 0 |> std/store:stored { table.selected: 0 }
! key k when k.ch == 'G' and table.selected < table.count - 1 |> std/store:stored { table.selected: table.count - 1 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
