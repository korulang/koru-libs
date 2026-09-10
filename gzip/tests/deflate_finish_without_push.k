import libs/gzip
import std/io

// NEGATIVE: an unfed stream cannot be finished. `finish` accepts ONLY <!fed>,
// which is reachable only through `push`; `init -> finish` is a compile error.
pub tor unfed { }
| bytes string
| err string

unfed = libs/gzip:deflate.init(level: .fast)
  |> libs/gzip:deflate.finish
  |> libs/gzip:deflate.release
| err e => err e
