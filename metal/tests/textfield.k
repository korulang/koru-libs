// Text-field probe — the first interactive surface. One editable line on a
// panel: a mouse-down places the caret via text.index over the SHAPED layout
// (glyph advances, midpoint rule), input.type injects typable characters like
// a real keypress carrying [NSEvent characters], backspace deletes before the
// caret, arrows walk it. The text buffer is one *String<instance> bound
// before the window so every custody path discharges; caret is a byte index
// (ASCII-exact — the str_idx UTF-16 contract). Scripted: frame 10 clicks
// mid-string, 12 types XYZ, 14 backspaces, 16 arrows right, 30 snaps,
// 45 quits.
import libs/metal
import std/store
import std/string
import std/io

std/store:new(world) { frame: 0[i64], caret: 0[i64] }

std/string:from-page(text: "edit me here")
| ok tv |> std/string:take(s: tv): txt
    |> libs/metal:window.open(width: 640, height: 400, title: "textfield")
        | win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
            |> libs/metal:frames(win: w, count: 9999)
                ! frame f
                    |> std/store:stored { world.frame: world.frame + 1 }
                    |> libs/metal:draw.panel(f, x: 60.0, y: 140.0, w: 520.0, h: 60.0, radius: 10.0, r: 0.16, g: 0.18, b: 0.25, a: 1.0, bw: 1.5, br: 0.5, bg: 0.7, bb: 1.0, ba: 1.0)
                    |> libs/metal:draw.text(f, x: 80.0, y: 156.0, size: 18.0, r: 0.92, g: 0.94, b: 0.98, a: 1.0, text: txt.data)
                    |> libs/metal:text.offset(win: w, text: txt.data, size: 18.0, index: world.caret) : cx
                    |> libs/metal:draw.rect(f, x: 80.0 + cx, y: 153.0, w: 1.5, h: 24.0, r: 0.95, g: 0.85, b: 0.4, a: 1.0)
                    |> if (world.frame == 10)
                        | then |> libs/metal:input.mouse(x: 120.0, y: 170.0)
                    |> if (world.frame == 12)
                        | then |> libs/metal:input.type(chars: "XYZ")
                    |> if (world.frame == 14)
                        | then |> libs/metal:input.key(code: 51)
                    |> if (world.frame == 16)
                        | then |> libs/metal:input.key(code: 124)
                    |> if (world.frame == 30)
                        | then |> libs/metal:window.snap(path: "/tmp/textfield_snap.bmp")
                    |> if (world.frame == 45)
                        | then |> libs/metal:quit()
                ! key-down k when k.chars.len > 0
                    |> std/string:len(s: txt) : n
                    |> std/string:substring(s: txt, start: 0, end: @as(usize, @intCast(world.caret)))
                        | ok left |> std/string:substring(s: txt, start: @as(usize, @intCast(world.caret)), end: n)
                            | ok right |> std/string:clear(s: txt) |> std/string:append(s: txt, text: left.data)
                                | ok |> std/string:append(s: txt, text: k.chars)
                                    | ok |> std/string:append(s: txt, text: right.data)
                                        | ok |> std/string:free(s: left) |> std/string:free(s: right)
                                            |> std/store:stored { world.caret: world.caret + @as(i64, @intCast(k.chars.len)) }
                                        | err _ |> std/string:free(s: left) |> std/string:free(s: right)
                                    | err _ |> std/string:free(s: left) |> std/string:free(s: right)
                                | err _ |> std/string:free(s: left) |> std/string:free(s: right)
                            | err _ |> std/string:free(s: left)
                        | err _ |> _
                ! key-down k when k.code == 51
                    |> if (world.caret > 0)
                        | then |> std/string:len(s: txt) : n
                            |> std/string:substring(s: txt, start: 0, end: @as(usize, @intCast(world.caret - 1)))
                                | ok left |> std/string:substring(s: txt, start: @as(usize, @intCast(world.caret)), end: n)
                                    | ok right |> std/string:clear(s: txt) |> std/string:append(s: txt, text: left.data)
                                        | ok |> std/string:append(s: txt, text: right.data)
                                            | ok |> std/string:free(s: left) |> std/string:free(s: right)
                                                |> std/store:stored { world.caret: world.caret - 1 }
                                            | err _ |> std/string:free(s: left) |> std/string:free(s: right)
                                        | err _ |> std/string:free(s: left) |> std/string:free(s: right)
                                    | err _ |> std/string:free(s: left)
                                | err _ |> _
                ! key-down k when k.code == 123
                    |> std/store:stored { world.caret: if (world.caret > 0) world.caret - 1 else 0 }
                ! key-down k when k.code == 124
                    |> std/string:len(s: txt) : n
                    |> std/store:stored { world.caret: if (world.caret < @as(i64, @intCast(n))) world.caret + 1 else @as(i64, @intCast(n)) }
                ! key-down k when k.code == 53 |> libs/metal:quit()
                ! mouse-down m
                    |> libs/metal:text.index(win: w, text: txt.data, size: 18.0, x: m.x - 80.0) : idx
                    |> std/store:stored { world.caret: idx }
                ! close |> libs/metal:quit()
                | done w2 |> libs/metal:window.close(win: w2) |> std/string:free(s: txt) |> std/io:print.ln("textfield: closed")
        | err e |> std/string:free(s: txt) |> std/io:print.ln("metal init failed: {{ e:s }}")
| err _ |> std/io:print.ln("string init failed")
