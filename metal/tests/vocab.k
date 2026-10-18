// Vocabulary probe — exercises the instanced-primitive port end to end:
// draw.shadow, draw.panel (fill+border+radius), draw.roundrect,
// draw.clip.push/pop, and draw.image interleaved between instanced draws.
// The image lands BETWEEN the two rects it overlaps only if instFlush
// preserves draw ordering. Snapshot at frame 30, quit at 40.
import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64], tex: 0[i64] }

libs/metal:window.open(width: 640, height: 400, title: "vocab probe")
| win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
        |> libs/metal:image.load(win: w, path: "../../clay/tests/test.png")
            | img t |> std/store:stored { world.tex: t }
            | err e |> std/io:print.ln("img failed: {{ e:s }}")
        |> libs/metal:frames(win: w, count: 9999)
            ! frame f
                |> std/store:stored { world.frame: world.frame + 1 }
                // Shadow + panel: soft drop shadow under a bordered rounded panel.
                |> libs/metal:draw.shadow(f, x: 60.0, y: 60.0, w: 200.0, h: 120.0, radius: 16.0, blur: 12.0, r: 0.0, g: 0.0, b: 0.0, a: 0.55)
                |> libs/metal:draw.panel(f, x: 60.0, y: 60.0, w: 200.0, h: 120.0, radius: 16.0, r: 0.18, g: 0.20, b: 0.28, a: 1.0, bw: 2.0, br: 0.5, bg: 0.7, bb: 1.0, ba: 1.0)
                // A plain rounded fill.
                |> libs/metal:draw.roundrect(f, x: 60.0, y: 220.0, w: 200.0, h: 80.0, radius: 20.0, r: 0.9, g: 0.5, b: 0.3, a: 1.0)
                // Clip: a tall rect pushed inside a 60px-high clip band —
                // only the banded slice may draw.
                |> libs/metal:draw.clip.push(f, x: 320.0, y: 60.0, w: 200.0, h: 60.0)
                |> libs/metal:draw.rect(f, x: 320.0, y: 40.0, w: 200.0, h: 140.0, r: 0.5, g: 0.9, b: 0.3, a: 1.0)
                |> libs/metal:draw.clip.pop(f)
                // Ordering: green rect, image overlapping its right edge,
                // red rect overlapping the image. Correct: green < image < red.
                |> libs/metal:draw.roundrect(f, x: 320.0, y: 220.0, w: 160.0, h: 80.0, radius: 10.0, r: 0.3, g: 0.8, b: 0.4, a: 1.0)
                |> if (world.tex > 0)
                    | then |> libs/metal:draw.image(f, world.tex, x: 400.0, y: 230.0, w: 120.0, h: 60.0)
                |> libs/metal:draw.roundrect(f, x: 490.0, y: 220.0, w: 80.0, h: 80.0, radius: 10.0, r: 0.9, g: 0.3, b: 0.3, a: 1.0)
                |> if (world.frame == 30)
                    | then |> libs/metal:window.snap(path: "/tmp/vocab_snap.bmp")
                |> if (world.frame == 40)
                    | then |> libs/metal:quit()
            ! key-down k when k.code == 53 |> libs/metal:quit()
            ! close |> libs/metal:quit()
            | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("vocab: closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
