// basic.k — the four v0 line ops, exercised end to end.
//
// EXPECTED:
//   head: first two
//   tail: last two (no phantom empty line off the trailing \n)
//   below: what is under the marker, header dropped
//   dedup: repeats collapse, first-occurrence order survives

import koru/winnow
import std/string
import std/io

// The regex ops branch on every step, so they live in a named flow —
// arm bodies nest there the same way they do in index.kz. Callers hand
// a BARE pattern; winnow owns the line-anchoring wrap, the compile,
// and the free.
tor regex-ops { }

regex-ops = koru/winnow:remove.lines(pattern: "FAIL|Error", text: "PASS 1\nFAIL a\nok\nError: b")
| ok r |> std/io:print.ln("remove => {{ r:S }}") |> std/string:free(s: r)
    |> koru/winnow:extract.lines(pattern: "FAIL|Error", text: "PASS 1\nFAIL a\nok\nError: b")
    | ok e |> std/io:print.ln("extract => {{ e:S }}") |> std/string:free(s: e)
        |> koru/winnow:grep(pattern: "FAIL", text: "all green")
        | yes |> std/io:print.ln("grep => yes")
        | no |> std/io:print.ln("grep => no")
        | err _ |> std/io:print.ln("grep err")
    | err e |> std/io:print.ln("extract err {{ e:s }}")
| err e |> std/io:print.ln("remove err {{ e:s }}")

koru/winnow:head(text: "a\nb\nc\nd", lines: 2): h
|> std/io:print.ln("head => {{ h:s }}")
|> koru/winnow:tail(text: "a\nb\nc\nd\n", lines: 2): t
|> std/io:print.ln("tail => {{ t:s }}")
|> koru/winnow:below(text: "PASS 12\nfailing tests:\nfoo.k:4 boom\nbar.k:9 boom", marker: "failing tests:"): b
|> std/io:print.ln("below => {{ b:s }}")
|> koru/winnow:dedup(text: "x\ny\nx\nz\ny"): d
|> std/io:print.ln("dedup => {{ d:s }}")
|> regex-ops()
