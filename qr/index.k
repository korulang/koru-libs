// @korulang/qr — QR Code generation rendered as SVG.
//
// Byte-mode encoder: EC level L, versions 1–9 (up to 232 data bytes),
// mask pattern 0. Matrix assembly follows ISO/IEC 18004 (finder/timing/
// alignment/dark modules, format info BCH, version info for v≥7, zigzag
// data placement). Rendered as a crisp-edges SVG with a 4-module quiet
// zone — one <path> of dark modules on a white <rect>.
//
//   import qr
//   qr:svg(text: "https://example.com/invite/abc"): svg
//     |> …
//     |> std/io:free(content: svg)
//
// The SVG string arrives allocated — the caller settles the `allocated!`
// obligation via std/io:free, or hands it to a consumer of
// <std/io:!allocated> (e.g. an orisha Response body). An empty or
// over-long input answers a minimal well-formed <svg/> sentinel that is
// still allocated — the contract never borrows.
pub tor svg { text: string } -> string<std/io:allocated!>
