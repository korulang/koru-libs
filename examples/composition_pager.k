// composition_pager — Charm-class pager assembled from catalog leaves (COMPOSITION_CHALLENGE).
//
// THESIS: Charm split the pager deliberately — viewport = content slice,
// paginator = status chrome — and a real pager WIRES them: one host store
// owns page/total/offset, `<viewport/>` paints the page's 12-line slice and
// TWO `<paginator/>` rows (Dots + Arabic) paint chrome from the SAME fields,
// so one h/l mutation moves content and both chrome rows in lockstep.
//
// The named composition is `pager` below — a dock nesting the catalog
// viewport + paginator tags. Leaves own their paint; no leaf job is
// reimplemented in `! draw`.
//
// Holes: hit no new wall. Host still can't see win height (viewport's floated
// hole) — pages are fixed 12-line slices, offset stepped ±12 with the page in
// one stored mutation; on a tall terminal the next page's header may peek
// below the slice (honest page-aligned clamp, per the brief). Arrows
// unreachable (0x3000 wall) — h/l.
//
//   koruc run examples/composition_pager.k   (h prev page  l next page  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — the page cursor and its derived line offset live here; every
// leaf paints from these fields. offset = page * 12, maintained by the keys.
std/store:new(book) {
    page:   0[i64],
    total:  3[i64],
    offset: 0[i64]
}

koru/vaxis:component(top) {
    <text>── Koru Pager ──────────────────────────────</text>
}

koru/vaxis:component(hint) {
    <text>  h prev page   l next page   q quit</text>
}

// THE NAMED COMPOSITION — viewport + two paginators nested in one dock.
// The viewport fills the middle band and paints the current page's slice;
// the Dots and Arabic paginator rows pin to the bottom band, both bound to
// the same page/total props. Point here and say: this is the assembly.
koru/vaxis:component(pager) {
    <dock>
        <top dock="top" h="2"/>
        <viewport dock="fill" content={{ content:s }} offset={{ offset:d }}/>
        <hint dock="bottom" h="1"/>
        <paginator dock="bottom" h="1" kind="arabic" page={{ page:d }} total={{ total:d }}/>
        <paginator dock="bottom" h="1" kind="dots" page={{ page:d }} total={{ total:d }}/>
    </dock>
}

koru/vaxis:run(title: "pager")
! draw w |> pager(win: w, book.offset, book.page, book.total,
    content: "PAGE ONE\n========\n\nA pager is two halves wired together.\nThe viewport shows one screen of a long\ndocument; the rows beneath are paginator\nchrome — Charm's status-only marker, in\nboth Dots and Arabic modes at once.\nOne store owns the page number. Press l:\nthis header, the visible lines, and both\nfooters jump in lockstep — shared state\ndriving two catalog leaves at once.\nPAGE TWO\n========\n\nThe viewport is honest about height. It\npaints only the rows its window holds and\nhard-clips long lines at the right edge\ninstead of re-flowing them, so columns\nstay still while you read. The host sees\nthe page index, not the window height, so\neach flip moves the offset by exactly\ntwelve lines — one fixed slice per page,\nclamped at both ends by the key guards.\nPAGE THREE\n==========\n\nTwo paginator modes, one source of truth.\nDots light the current page pink; Arabic\nprints N/M from the same store field, so\nthey can never disagree. That is the\ncomposition claim: leaves keep their own\npaint and chrome; the host keeps only\nthe numbers. This is the last page —\npress h to climb back through the deck\nand watch all three rows move together.")
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'l' and book.page < book.total - 1 |> std/store:stored { book.page: book.page + 1, book.offset: book.offset + 12 }
! key k when k.ch == 'h' and book.page > 0 |> std/store:stored { book.page: book.page - 1, book.offset: book.offset - 12 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
