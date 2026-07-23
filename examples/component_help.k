// help — Charm-class keybinding help (COMPONENT_CHALLENGE Bridge).
//
// PUBLIC SURFACE (the catalog tag):
//   <help bindings={{ bindings:s }} mode={{ show:d }}/>
//   koru/vaxis:help { win, bindings: string, mode: i64 }
//
// Charm's job (bubbles/help): render keybinding help.
//   SHORT (mode=0, default) — one line "key desc • key desc • …", muted keys
//     (#626262), softer descs (#4A4A4A), dim " • " separators (#3C3C3C),
//     truncated with a trailing "…" when wider than the window (ansi.Truncate).
//   FULL  (mode=1) — one "key  desc" row per binding, keys padded into an
//     aligned column (bubbles' single-column FullHelpView). Grows upward from
//     the bottom edge.
// Both modes hug the BOTTOM of the widget's window — help sits at the screen
// bottom like a real TUI. Toggle short↔full with `?` (Charm-typical); the host
// store owns the `show` flag, the widget owns the paint (NOT the `! key`
// pipeline). Resize the terminal narrower than the short line to watch the
// width-aware "…" truncation.
//
// Bindings arrive as a host-owned "key:desc" payload, one per line (the same
// `string` path list/viewport use). A real structured []Binding with separate
// short/full lists — and multi-column full help — is the honest deferred hole:
// the flat newline payload can't express column groups, so full help is one
// column. Keys carry arrow glyphs (↑/k) — they are PAINTED, so the run-loop
// 0x3000 key filter (floated by viewport/paginator) never touches them.
//
//   koruc run examples/component_help.k       (? toggle  q quit)

import std/io
import std/store
import koru/vaxis

// Host state — only the short/full toggle lives here; the widget paints the
// rest from the (constant) bindings payload. show: 0 = short, 1 = full.
std/store:new(help) {
    show: 0[i64]
}

koru/vaxis:component(heading) {
    <text>  Charm help — keybinding hints</text>
    <text>  press ? to toggle short / full,  q to quit</text>
}

// Thin host chrome — the widget is help. It takes the fill band and anchors to
// the bottom of it, so short help is one line on the last row and full help
// stacks upward. `bindings` is a constant payload (the list `items` precedent);
// `mode` is fed reactively from the store so `?` flips short↔full live.
koru/vaxis:component(app) {
    <dock>
        <heading dock="top" h="2"/>
        <help dock="fill" bindings={{ bindings:s }} mode={{ show:d }}/>
    </dock>
}

koru/vaxis:run(title: "help")
! draw w |> app(win: w,
    bindings: "↑/k:up\n↓/j:down\n←/h:prev page\n→/l:next page\ng:go to start\nG:go to end\n/:filter\n?:toggle help\nq:quit",
    help.show)
! key k when k.ch == 'q' |> koru/vaxis:quit()
! key k when k.ch == '?' and help.show == 0 |> std/store:stored { help.show: 1 }
! key k when k.ch == '?' and help.show == 1 |> std/store:stored { help.show: 0 }
| err e |> std/io:print.ln("vaxis failed: {{ e:s }}")
