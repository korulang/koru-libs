// needle3 probe — MEASURED 2026-11: needle_complete is an extraction
// engine, not a rewriter. Two framings ("corrected" field, then "copy
// the ENTIRE corrected transcript") both returned suppressed_calls of
// FRAGMENTS at confidence ~0.005-0.01 — the model pulls field values,
// it cannot emit a corrected sentence. Verdict: no rewrite pass on
// Needle 3; keyword biasing (load keywords:) is the error-class fix.
// Kept as the receipt + ABI exercise for prime/complete.
//
//   koruc run needle/tests/prime_probe.k   (from the koru-libs repo root)

import libs/needle
import std/io

libs/needle:load(path: "/Users/larsde/.cache/cactus-needle/v3/3.3.3/needle3.cact", keywords: "")
| ready eng |> libs/needle:prime(eng,
        system: "You are a transcript editor. Fix speech-recognition errors: restore punctuation, casing, and domain terms. Copy the ENTIRE corrected transcript into the text field of emit_text.",
        tools: "[{\"name\":\"emit_text\",\"description\":\"Emit the corrected transcript text\",\"parameters\":{\"text\":{\"type\":\"string\",\"required\":true,\"description\":\"The full corrected transcript\"}}}]")
    | ok prefix |> std/io:print.ln("prefix tokens: {{ prefix:d }}")
        |> libs/needle:complete(eng, text: "um so i was thinking we could like totally use koru and oshun to rewrite this passage and see if needle three fixes the mistakes better than whistle does", max_tokens: 256)
            | ok json |> std/io:print.ln("complete: {{ json:s }}") |> std/io:free(content: json) |> libs/needle:unload(eng)
            | err e |> std/io:print.ln("complete err: {{ e:s }}") |> libs/needle:unload(eng)
    | err e |> std/io:print.ln("prime err: {{ e:s }}") |> libs/needle:unload(eng)
| err e |> std/io:print.ln("load err: {{ e:s }}")
