// theme_preview_live — the interactive twin of theme_preview.k (same
// mechanism, scripted input and snaps removed). Two mini-app
// instances (shell, preview) seed under different std/ctx scopes; each
// scope root carries `th` — a themes-row handle — and every descendant
// resolves `eff` per frame: own th else parent.eff else world.dft.
// Because eff is derived every frame, ONE stored write to a scope
// root's th re-themes its whole subtree next frame — the store write
// IS the repaint trigger.
//
//   swatch click  → stored { spec[pvroot].th: swatch.th }
//   apply click   → stored { spec[shroot].th: spec[pvroot].th }
//
// The commit point is the button: hover/candidate changes touch only
// the preview subtree; apply copies preview's handle into shell's.
// Scripted: frame 10 clicks swatch 1, frame 40 clicks apply; snaps at
// 30 and 60 pin that the preview moved first and the shell followed
// only on commit.
//
// ctx's honest role: seed-time injection. `th` never appears at the
// call site — `self` arrives ambiently from ctx(themes[t]) because
// each theme row stamps its own handle into `self` at seed. Live
// re-theme is the handle's job, not ctx's.
import libs/metal
import libs/clay
import libs/ui
import libs/oshun
import std/store
import std/io
import std/fmt
import std/string
import std/ctx

std/store:new(world) { frame: 0[i64], drew: 0[i64], sel: -1[i64], dft: 0[i64] }

// A theme = four role colors + a font size. r0 bg / r1 panel / r2
// accent / r3 ink; `self` is the row's own handle, stamped at seed so
// ctx can inject it as the `self:` prop on scope roots.
std/store:new(themes, capacity: 8) {
    r0: f64, g0: f64, b0: f64, r1: f64, g1: f64, b1: f64,
    r2: f64, g2: f64, b2: f64, r3: f64, g3: f64, b3: f64,
    fs: f64, self: i64,
}

// spec gains five columns over the spec_snap shape:
//   th     bound theme handle — 0 = inherit from parent scope
//   eff    resolved theme for THIS frame (derived, never seeded)
//   scope  1 = shell root, 2 = preview root (dispatch targets)
//   act    click action — 1 swatch (preview := row's th), 2 apply
//   role   0 = row's own r/g/b, else theme channel r{role-1}
[tree]std/store:new(spec, capacity: 64) {
    d: i64, kind: char[8], dock: char[8],
    ws: char[8], w: f64, hs: char[8], h: f64,
    dir: char[8], gap: i64, pad: i64, ax: char[8], ay: char[8],
    r: f64, g: f64, b: f64, a: f64,
    fl: i64, fx: f64, fy: f64,
    id: i64, pid: i64, gc: i64, gr: i64,
    mw: f64, mh: f64, cw: f64, ch: f64, cc: i64,
    tx: char[40], fs: f64,
    th: i64, eff: i64, scope: i64, act: i64, role: i64,
}

// Hit map — one row per drained command, spec ordinal via ud - 1.
std/store:new(hit, capacity: 64) { seq: i64, tool: i64, x: f64, y: f64, w: f64, h: f64 }

// The themed mini-app — invoked twice under different ctx scopes.
// `self:` is ctx-injected (never spelled at the call site); the root's
// th gets it ambiently. fs also rides ctx — seed-time only, so a live
// theme swap changes colors but keeps the seeded font size; that
// asymmetry is the honest ctx-vs-handle line, printed in the docs.
libs/oshun:component(mini, spec) {
    <dock ws="fix" w="240" hs="fix" h="150" dir="ttb" gap="4" pad="8" ax="start" ay="start" role="2" fl="1" fx={{ fx:f }} fy={{ fy:f }} th={{ self:d }} scope={{ scope:d }}>
        <leaf dock="top" hs="fix" h="26" role="3" tx="{{ title:s }} theme" fs={{ fs:f }}/>
        <stack dock="fill" dir="ttb" gap="4" pad="6" role="1">
            <leaf ws="star" hs="fix" h="10" role="4"/>
            <leaf ws="star" hs="fix" h="10" role="4"/>
            <leaf ws="fix" w="0" hs="fix" h="18" role="3" tx="body copy" fs="12"/>
        </stack>
    </dock>
}

// The picker chrome — three swatches (each IS its theme: own th →
// accent via role 3, act 1 makes a click retarget the preview) and an
// apply leaf (act 2 → shell := preview). The strip floats under the
// two minis and binds t0 itself so nothing ambient leaks in.
libs/oshun:component(chrome, spec) {
    <stack ws="fix" w="280" hs="fix" h="44" dir="ltr" gap="8" pad="8" ax="start" ay="center" role="2" fl="1" fx="30" fy="300" th={{ t0:d }}>
        <leaf ws="fix" w="28" hs="fix" h="28" role="3" th={{ t0:d }} act="1"/>
        <leaf ws="fix" w="28" hs="fix" h="28" role="3" th={{ t1:d }} act="1"/>
        <leaf ws="fix" w="28" hs="fix" h="28" role="3" th={{ t2:d }} act="1"/>
        <leaf ws="fix" w="0" hs="fix" h="28" role="3" act="2" tx="apply" fs="12"/>
    </stack>
}

libs/clay:init(width: 640, height: 400)
| cl h |> libs/metal:window.open(width: 640, height: 400, title: "theme preview — scoped ctx + live handles")
    | win w |> libs/metal:window.clear.color(win: w, r: 0.08, g: 0.08, b: 0.11)
            |> libs/metal:frames(win: w, count: 9999)
        ! frame f
            |> std/store:stored { world.frame: world.frame + 1 }
            |> std/store:clear(hit)
            |> libs/metal:window.size(win: w): wh
            |> libs/clay:dims(cl: h, width: wh.w, height: wh.h)
            |> if (world.frame == 1)
                | then |> std/store:insert(themes) { r0: 22.0, g0: 24.0, b0: 32.0, r1: 30.0, g1: 33.0, b1: 44.0, r2: 62.0, g2: 120.0, b2: 190.0, r3: 222.0, g3: 226.0, b3: 238.0, fs: 13.0, self: 0 }
                    | row t0 |> std/store:insert(themes) { r0: 34.0, g0: 22.0, b0: 20.0, r1: 44.0, g1: 29.0, b1: 26.0, r2: 210.0, g2: 110.0, b2: 50.0, r3: 240.0, g3: 226.0, b3: 210.0, fs: 15.0, self: 0 }
                        | row t1 |> std/store:insert(themes) { r0: 20.0, g0: 28.0, b0: 20.0, r1: 27.0, g1: 38.0, b1: 27.0, r2: 90.0, g2: 180.0, b2: 90.0, r3: 214.0, g3: 230.0, b3: 214.0, fs: 17.0, self: 0 }
                            | row t2 |> std/store:stored { themes[t0].self: t0 }
                                |> std/store:stored { themes[t1].self: t1 }
                                |> std/store:stored { themes[t2].self: t2 }
                                |> std/store:stored { world.dft: t0 }
                                |> std/io:print.ln("themes: slate {{ t0:d }} ember {{ t1:d }} moss {{ t2:d }}")
                                |> std/ctx(themes[t0]) |> mini(fx: 30.0, fy: 50.0, scope: 1, title: "shell")
                                |> std/ctx(themes[t0]) |> mini(fx: 330.0, fy: 50.0, scope: 2, title: "preview")
                                |> chrome(t0, t1, t2)
            // live twin — no scripted input: click a swatch to retarget
            // the preview subtree, click apply to commit it to the shell.
            // Escape or the close button quits.
            // eff: doc-order sweep — parents precede children in
            // insertion order, so spec[s.parent].eff is already live.
            // th != 0 wins; else inherit; roots fall back to dft.
            |> std/store:query(spec)
                ! query { [row]s }
                    |> std/store:stored { s.eff: if (s.th != 0) s.th else if (s.parent != -1) spec[s.parent].eff else world.dft }
            // tx rows bake measured size like the spec family does
            |> std/store:query(spec)
                ! query { [row]s } when s.tx != ""
                    |> libs/clay:measure.text(s.tx, s.fs): dims
                    |> std/store:stored { s.w: dims.w, s.mw: dims.w, s.mh: dims.h }
            |> libs/clay:layout(cl: h)
                ! tree t
                    |> std/store:query(spec)
                        ! query { [row]s, [ordinal]o }
                            |> if (s.kind != "grid" and s.kind != "cell" and s.kind != "col" and s.kind != "row" and s.kind != "img")
                                | then |> libs/clay:el.close-to(t, s.d)
                                    |> libs/ui:panelx(t, s.dock, s.ws, s.w, s.hs, s.h, s.dir, s.gap, s.pad, s.ax, s.ay,
                                        r: if (s.role == 1) themes[s.eff].r0 else if (s.role == 2) themes[s.eff].r1 else if (s.role == 3) themes[s.eff].r2 else if (s.role == 4) themes[s.eff].r3 else s.r,
                                        g: if (s.role == 1) themes[s.eff].g0 else if (s.role == 2) themes[s.eff].g1 else if (s.role == 3) themes[s.eff].g2 else if (s.role == 4) themes[s.eff].g3 else s.g,
                                        b: if (s.role == 1) themes[s.eff].b0 else if (s.role == 2) themes[s.eff].b1 else if (s.role == 3) themes[s.eff].b2 else if (s.role == 4) themes[s.eff].b3 else s.b,
                                        a: if (s.role == 0) s.a else 255.0,
                                        s.fl, s.fx, s.fy, eid: o + 1)
                            |> if (s.tx != "")
                                | then |> libs/ui:text(t, s.tx, s.fs, r: themes[s.eff].r3, g: themes[s.eff].g3, b: themes[s.eff].b3, a: 255.0, eid: o + 1)
                | solved cls |> libs/clay:each(cl: cls)
                    ! cmd rc |> if (rc.kind == 1)
                        | then |> std/store:insert(hit) { seq: rc.ud - 1, tool: if (rc.ud == 0) 1 else 0, rc.x, rc.y, rc.w, rc.h }
                            |> libs/metal:draw.rect(f, x: @round(rc.x), y: @round(rc.y), w: @round(rc.x + rc.w) - @round(rc.x), h: @round(rc.y + rc.h) - @round(rc.y), rc.r, rc.g, rc.b, rc.a)
                    ! cmd rc |> if (rc.kind == 3)
                        | then |> std/store:insert(hit) { seq: rc.ud - 1, tool: if (rc.ud == 0) 1 else 0, rc.x, rc.y, rc.w, rc.h }
                            |> libs/metal:draw.text(f, x: @round(rc.x), y: @round(rc.y), size: rc.fs, rc.r, rc.g, rc.b, rc.a, text: rc.tx)
                    | drained |> std/store:stored { world.drew: 1 }
        ! mouse-down e
            |> std/store:stored { world.sel: -1 }
            |> std/store:query(hit)
                ! query hi when e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                    |> std/store:stored { world.sel: hi.seq }
            // act 1 (swatch): preview root takes the swatch's own theme
            |> std/store:query(spec)
                ! query { [row]s, [ordinal]o } when o == world.sel and s.act == 1
                    |> std/store:query(spec)
                        ! query { [row]p } when p.scope == 2
                            |> std/store:stored { p.th: s.th }
            // act 2 (apply): shell root takes preview's theme — commit
            |> std/store:query(spec)
                ! query { [row]s, [ordinal]o } when o == world.sel and s.act == 2
                    |> std/store:query(spec)
                        ! query { [row]p } when p.scope == 2
                            |> std/store:query(spec)
                                ! query { [row]sh } when sh.scope == 1
                                    |> std/store:stored { sh.th: p.th }
        ! mouse-move e  // hover-candidacy — cursor over a swatch retargets
                        // the preview with no click; the candidate is STICKY:
                        // leaving the swatch keeps it (reverting on leave broke
                        // apply — the crossing-to-the-button pixels reverted the
                        // preview before the click landed). p.th != s.th keeps
                        // the write once-per-change, not once-per-pixel.
            |> std/store:query(hit)
                ! query hi when e.x >= hi.x and e.x < hi.x + hi.w and e.y >= hi.y and e.y < hi.y + hi.h
                    |> std/store:query(spec)
                        ! query { [row]s, [ordinal]o } when o == hi.seq and s.act == 1
                            |> std/store:query(spec)
                                ! query { [row]p } when p.scope == 2 and p.th != s.th
                                    |> std/store:stored { p.th: s.th }
        ! key-down k when k.code == 53 |> libs/metal:quit()
        ! close |> libs/metal:quit()
        | done w2 |> libs/clay:drop(cl: h) |> libs/metal:window.close(win: w2) |> std/io:print.ln("theme_preview: closed")
    | err e |> std/io:print.ln("metal init failed: {{ e:s }}")
| err e2 |> std/io:print.ln("clay init failed: {{ e2:s }}")
