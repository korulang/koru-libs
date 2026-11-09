// needle probe — the falsifier for the whole no-python claim:
// load whistle.cact through the vendored libneedle.dylib, transcribe a real
// 16kHz f32le PCM file, print the engine's JSON verbatim.
//
//   koruc run needle/tests/probe.k      (from the koru-libs repo root)

import libs/needle
import std/io

libs/needle:load(path: "/Users/larsde/.cache/cactus-needle/whistle/2.0.0/whistle.cact", keywords: "")
| ready eng |> std/io:read-file(path: "/tmp/needle_probe.f32")
    | ok pcm |> libs/needle:transcribe(eng, pcm, language: "en")
        | ok json |> std/io:print.ln("transcribe: {{ json:s }}") |> std/io:free(content: json) |> libs/needle:unload(eng)
        | err e |> std/io:print.ln("transcribe err: {{ e:s }}") |> libs/needle:unload(eng)
    | not-found |> std/io:print.ln("probe pcm missing") |> libs/needle:unload(eng)
    | failed e |> std/io:print.ln("read failed: {{ e:s }}") |> libs/needle:unload(eng)
| err e |> std/io:print.ln("load err: {{ e:s }}")
