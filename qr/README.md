# @korulang/qr

QR Code generation for Koru — byte-mode encoder rendered as an SVG string.

- EC level L, versions 1–9 (up to 232 data bytes), mask pattern 0
- Matrix assembly follows ISO/IEC 18004 (finder / timing / alignment / dark
  modules, format + version info BCH, zigzag data placement)
- Output is a crisp-edges SVG (`viewBox`, white `<rect>`, one black `<path>`)
  with a 4-module quiet zone — the shape a browser or `img` tag takes directly

## Usage

```koru
import qr
import std/io

qr:svg(text: "https://example.com/invite/abc123"): svg
  |> std/io:print.ln("{{ svg:s }}")
  |> std/io:free(content: svg)
```

`qr:svg` answers `string<std/io:allocated!>` — the caller settles the
`allocated!` obligation with `std/io:free`, or hands the string to a consumer
of `<std/io:!allocated>` (for example an orisha `Response` body, where the
runtime's `body_allocated` release settles it). Empty or over-long input
answers a minimal well-formed `<svg/>` sentinel — still allocated, so the
contract never borrows.

## Layout

- `index.k` — the public contract (pure Koru declarations)
- `index.kz` — the encoder (Zig `~proc` implementation)
- `tests/` — smoke tests registered in the repo-root `suite.k`
