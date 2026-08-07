// P7 — the vaxis `component` transform under --lang=js.
// The gauntlet claim (DOM_GAUNTLET.md): component runs at Stage C with no
// runtime existence and no target; only its GENERATED call to write-at is
// TUI-bound. If that holds, this program's Stage C succeeds (the markup is
// consumed, greet is synthesized) and emission refuses exactly at write-at's
// missing |js body — nothing else.
import koru/vaxis

koru/vaxis:component(greet) {
    <text>{{ name:s }}</text>
}

greet(win: 0, name: "world")
