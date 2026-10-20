// Window twin of offscreen_scene.k — identical draws, identical clear
// color, 640x400 through the real frames pump. Snap at frame 3 (matching
// the offscreen file's third and last committed frame), quit at 5.
import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64] }

libs/metal:window.open(width: 640, height: 400, title: "omni offscreen twin")
| win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
        |> libs/metal:frames(win: w, count: 9999)
    ! frame f
        |> std/store:stored { world.frame: world.frame + 1 }
        |> libs/metal:draw.rect(f, x: 80.0, y: 150.0, w: 140.0, h: 90.0, r: 0.9, g: 0.4, b: 0.4, a: 1.0)
        |> libs/metal:draw.roundrect(f, x: 240.0, y: 150.0, w: 140.0, h: 90.0, radius: 12.0, r: 0.4, g: 0.8, b: 0.45, a: 1.0)
        |> libs/metal:draw.shadow(f, x: 420.0, y: 150.0, w: 140.0, h: 90.0, radius: 8.0, blur: 4.0, r: 0.0, g: 0.0, b: 0.0, a: 0.5)
        |> libs/metal:draw.panel(f, x: 80.0, y: 270.0, w: 200.0, h: 80.0, radius: 6.0, r: 0.2, g: 0.25, b: 0.35, a: 1.0, bw: 2.0, br: 0.9, bg: 0.9, bb: 0.95, ba: 1.0)
        |> libs/metal:draw.text(f, x: 90.0, y: 295.0, size: 14.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0, text: "Offscreen 123")
        |> if (world.frame == 3)
            | then |> libs/metal:window.snap(path: "/tmp/omni_offscreen_twin.bmp")
        |> if (world.frame == 5)
            | then |> libs/metal:quit()
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("twin: snapped + closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
