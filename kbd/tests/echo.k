// kbd echo — press keys, see names. Arrows arrive as ESC [ A..D and decode
// to up/down/left/right; WASD, space, enter, tab decode as themselves; a
// lone Escape reports after two empty polls; anything else shows "byte".
// ~10s of polling at 16ms; ^C still kills (ISIG is kept on).
//
// Non-interactive proof: printf '\x1b[A\x1b[Dwq' | ./echo.bin — the pipe is
// not a tty so raw() is a no-op there and poll()+read() still never blocks.

import libs/kbd
import std/io
import std/time

std/io:print.ln("kbd echo — press keys (arrows, wasd, space, enter, esc)")
|> libs/kbd:raw(): rc
|> for(0..600)
    ! each _ |> libs/kbd:keys(max: 8)
        ! key k |> libs/kbd:key.name(k.code): n
            |> std/io:print.ln("key {{ n:s }}")
        | done |> std/time:sleep-ms(ms: 16)
    | done |> libs/kbd:restore(): _rc
        |> std/io:print.ln("done")
