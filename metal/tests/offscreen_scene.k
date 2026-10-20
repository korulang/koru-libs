// Offscreen twin of the window scene — same draws, same clear color, same
// 640x400 at 2x scale, no window. Gates the headless surface pixel-for-pixel
// against the windowed path: /tmp/omni_offscreen.bmp must equal
// /tmp/omni_offscreen_twin.bmp byte for byte.
import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64] }

libs/metal:offscreen.open(width: 640, height: 400, scale: 2.0)
| surf s |> libs/metal:offscreen.clear.color(s, r: 0.10, g: 0.10, b: 0.15)
         |> for(0..3)
             ! each _ |> libs/metal:offscreen.frame(s)
                 ! frame f
                     |> std/store:stored { world.frame: world.frame + 1 }
                     |> libs/metal:draw.rect(f, x: 80.0, y: 150.0, w: 140.0, h: 90.0, r: 0.9, g: 0.4, b: 0.4, a: 1.0)
                     |> libs/metal:draw.roundrect(f, x: 240.0, y: 150.0, w: 140.0, h: 90.0, radius: 12.0, r: 0.4, g: 0.8, b: 0.45, a: 1.0)
                     |> libs/metal:draw.shadow(f, x: 420.0, y: 150.0, w: 140.0, h: 90.0, radius: 8.0, blur: 4.0, r: 0.0, g: 0.0, b: 0.0, a: 0.5)
                     |> libs/metal:draw.panel(f, x: 80.0, y: 270.0, w: 200.0, h: 80.0, radius: 6.0, r: 0.2, g: 0.25, b: 0.35, a: 1.0, bw: 2.0, br: 0.9, bg: 0.9, bb: 0.95, ba: 1.0)
                     |> libs/metal:draw.text(f, x: 90.0, y: 295.0, size: 14.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0, text: "Offscreen 123")
                 | done _
         |> libs/metal:offscreen.snap(s, path: "/tmp/omni_offscreen.bmp")
         |> libs/metal:offscreen.close(s)
         |> std/io:print.ln("offscreen: snapped + closed")
| err e |> std/io:print.ln("metal offscreen init failed: {{ e:s }}")
