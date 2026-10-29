# @korulang/needle

On-device speech transcription for Koru via Cactus-Compute's `libneedle`
engine — no Python, no sidecar, a plain C ABI wrapped in phantom obligation
types.

```koru
import libs/needle

libs/needle:load(path: "whistle.cact")
| ready eng |> libs/needle:transcribe(eng, pcm, language: "en")
    | ok json |> std/io:free(content: json) |> libs/needle:unload(eng)
    | err e |> ... |> libs/needle:unload(eng)
| err e |> ...
```

- `load` reads a `.cact` weights archive and mints `*Engine<ready!>`; every
  verb borrows it, `unload` discharges it. Transcribing with no engine
  loaded is a compile error.
- `transcribe` is one-shot; `stream.process` + `stream.stop` are the chunked
  live path (committed text + unconfirmed tail per call).
- `pcm` is raw 16kHz mono little-endian f32 bytes (`string<*>` — any
  qualified buffer feeds it directly).
- Results are the engine's JSON verbatim: `{"text","language","ttft_ms",
  "decode_tps"}` (+ `"words"` with timestamps). Parse with `koru/yyjson`.

## Native library

`vendor/libneedle.dylib` (~1.1MB). Link search comes from `../vendor`
relative to the build dir; point `NEEDLE_LIB_DIR` elsewhere when a consumer
needs a different layout. Whistle weights (~17MB) are fetched separately —
`Cactus-Compute/whistle` on Hugging Face, cached under
`~/.cache/cactus-needle/`.
