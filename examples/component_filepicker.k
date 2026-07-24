// filepicker — Charm-class directory browser (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <filepicker path={{ path:s }} entries={{ entries:s }} selected={{ selected:d }}/>
//   koru/vaxis:filepicker { win, path: string, entries: string, selected: i64 }
//
// Craft: bubbles/filepicker's job — a current-path header over a listing, a
// ">" cursor in Charm pink #EE6FF8 on the selected row, DIRECTORIES in Charm
// purple #5A56E0, files in soft contrast; the selected row wins with bold pink
// + cursor. Directories carry a trailing "/" (ls -F taste). Page-aligned scroll
// keeps the cursor visible. The widget OWNS the paint/chrome — NOT the `! key`
// pipeline; the host store owns only the cursor index + the current dir index.
//
// Navigation without a mutable-string store: the host keeps N fixed entry
// strings (root + documents) and flips an i64 `dir` index — `l`/enter descends
// into a directory row, `h` (and ".." + `l`/enter) climbs back. Paint always
// flows through the same `<filepicker entries=… selected=…/>` tag (the Bridge
// the challenge sanctions). Entries are the newline `string` payload the
// list/table widgets use; kind is encoded "<D|F>\t<name>" per line.
//
// Holes: a real ReadDir over a mutable-string store (live filesystem) is the
// stretch hole — this Bridge switches between two fixed listings. Per-directory
// cursor memory (bubbles restores the cursor on climb-back) is deferred; the
// cursor resets to the directory row we descended from, which stays valid.
// Permissions/size columns deferred (stretch holes, per the brief).
//
//   koruc run examples/component_filepicker.k
//     (j/k move   g/G ends   l/enter open   h back   q quit)

import std/io
import std/store
import koru/vaxis

// Host state — only the cursor index and the current directory index live
// here; the widget paints the rest. dir 0 = root, dir 1 = documents.
std/store:new(fp) {
    selected: 0[i64],
    dir:      0[i64]
}

koru/vaxis:component(hint) {
    <text>j/k move   g/G ends   l/enter open   h back   q quit</text>
}

// Thin host chrome around the catalog tag — the widget is filepicker. It takes
// the fill band (path header + listing); the hint pins to the bottom edge.
koru/vaxis:component(app) {
    <dock>
        <filepicker dock="fill" path={{ path:s }} entries={{ entries:s }} selected={{ selected:d }}/>
        <hint dock="bottom" h="1"/>
    </dock>
}

// Two fixed listings; `dir` picks which one paints — koru `if` composes the
// widget with zero extra machinery (component_flow.k's shape). Root's entry 0
// is the "documents" directory; documents' entry 0 is ".." (climb back).
koru/vaxis:run(title: "filepicker")
! draw w |> if(fp.dir == 0)
    | then |> app(win: w,
        path:    "~/charm",
        entries: "D\tdocuments\nF\tREADME.md\nF\tgo.mod\nF\tgo.sum\nF\tLICENSE\nF\t.gitignore",
        fp.selected)
    | else |> app(win: w,
        path:    "~/charm/documents",
        entries: "D\t..\nF\tresume.pdf\nF\tbudget.xlsx\nF\tnotes.md\nF\tcover-letter.md",
        fp.selected)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == 'j' and fp.dir == 0 and fp.selected < 5 |> std/store:stored { fp.selected: fp.selected + 1 }
! key k when k.ch == 'j' and fp.dir == 1 and fp.selected < 4 |> std/store:stored { fp.selected: fp.selected + 1 }
! key k when k.ch == 'k' and fp.selected > 0 |> std/store:stored { fp.selected: fp.selected - 1 }
! key k when k.ch == 'g' and fp.selected > 0 |> std/store:stored { fp.selected: 0 }
! key k when k.ch == 'G' and fp.dir == 0 and fp.selected < 5 |> std/store:stored { fp.selected: 5 }
! key k when k.ch == 'G' and fp.dir == 1 and fp.selected < 4 |> std/store:stored { fp.selected: 4 }
! key k when k.ch == 'l' and fp.dir == 0 and fp.selected == 0 |> std/store:stored { fp.dir: 1 }
! key k when k.ch == 13 and fp.dir == 0 and fp.selected == 0 |> std/store:stored { fp.dir: 1 }
! key k when k.ch == 'l' and fp.dir == 1 and fp.selected == 0 |> std/store:stored { fp.dir: 0 }
! key k when k.ch == 13 and fp.dir == 1 and fp.selected == 0 |> std/store:stored { fp.dir: 0 }
! key k when k.ch == 'h' and fp.dir == 1 |> std/store:stored { fp.dir: 0 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
