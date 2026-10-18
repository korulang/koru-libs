//~ run
//~ expect: <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 29 29"
//~ expect: </svg>
import libs/qr
import std/io

// Positive: a ≤17-byte input renders a version-1 (21×21 + 8 quiet = 29)
// SVG, then the allocated! obligation settles through std/io:free.
libs/qr:svg(text: "https://x.co/i"): svg
  |> std/io:print.ln("{{ svg:s }}")
  |> std/io:free(content: svg)
