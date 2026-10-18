// Automation scenario — no hands required. Proves the three automation
// verbs end-to-end: input.key injects a synthesized right-arrow at frame
// 10 (the same mailbox the ObjC IMPs write), window.snap captures the
// presented drawable at frame 30 into a BMP, and the run quits itself.
// The artifact is the point: a harness run produces pixels an agent can
// inspect — sips -s format png /tmp/omni_snap.bmp --out /tmp/omni_snap.png.
import libs/metal
import std/store
import std/io

std/store:new(world) { frame: 0[i64], focus: 0[i64] }

libs/metal:window.open(width: 640, height: 400, title: "omni snap — automation scenario")
| win w |> libs/metal:window.clear.color(win: w, r: 0.10, g: 0.10, b: 0.15)
        |> libs/metal:frames(win: w, count: 9999)
    ! frame f
        |> std/store:stored { world.frame: world.frame + 1 }
        |> libs/metal:draw.rect(f, x: 80.0, y: 150.0, w: 140.0, h: 90.0, r: 0.9, g: 0.4, b: 0.4, a: 1.0)
        |> libs/metal:draw.rect(f, x: 300.0, y: 150.0, w: 140.0, h: 90.0, r: 0.4, g: 0.8, b: 0.45, a: 1.0)
        |> libs/metal:draw.rect(f, x: 300.0 + 150.0 * @as(f64, @floatFromInt(world.focus)), y: 120.0, w: 20.0, h: 20.0, r: 1.0, g: 1.0, b: 1.0, a: 1.0)
        |> if (world.frame == 10)
            | then |> libs/metal:input.key(code: 124)
        |> if (world.frame == 30)
            | then |> libs/metal:window.snap(path: "/tmp/omni_snap.bmp")
        |> if (world.frame == 40)
            | then |> libs/metal:quit()
    ! key-down k when k.code == 124
        |> std/store:stored { world.focus: if (world.focus + 1 >= 2) 0 else world.focus + 1 }
    ! key-down k when k.code == 53 |> libs/metal:quit()
    ! close |> libs/metal:quit()
    | done w2 |> libs/metal:window.close(win: w2) |> std/io:print.ln("snap: closed")
| err e |> std/io:print.ln("metal init failed: {{ e:s }}")
