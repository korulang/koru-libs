import koru/regressions

koru/regressions:compile-fail(stage: backend)
koru/regressions:error(id: "KORU030", msg: "Phantom state mismatch")

// NEGATIVE (must FAIL to compile): use-after-free of a finished stream.
//
// `deflate.finish` transitions the Deflater from <fed!> to <done!>. Pushing
// to it afterwards (deflate.push requires <!open|!fed>) is a use-after-free:
// the zlib z_stream has already had deflateEnd() called on it. The phantom
// checker rejects this at compile time — the declared expectations above are
// the machine-checked contract (they replaced the old prose EXPECTED: note,
// which could drift into a doc-lie).
//
// Note we push a real chunk BEFORE finishing — that is what reaches the <fed!>
// state finish now demands (see deflate_finish_without_push.kz for the
// unfed case). This test isolates the use-after-free specifically.
//
// This is the proof that the streaming obligations actually bite. If this file
// ever compiles, the resource-safety pillar has regressed.
//
// The chain is POINT-FREE — one dedented `| err` arm claims the error branch at
// every stage. It used to be a five-handler pyramid; it collapsed once gzip's
// stages carried the handle as their lone survivor (finish -> *Deflater<done!>)
// and release reported `| bytes | err` instead of a bare return.

import libs/gzip
import std/io

pub tor use-after-finish { }
| bytes string
| err string

use-after-finish = libs/gzip:deflate.init(level: .fast)
  |> libs/gzip:deflate.push(chunk: "real chunk")
  |> libs/gzip:deflate.finish
  |> libs/gzip:deflate.push(chunk: "use after free")
  |> libs/gzip:deflate.finish
  |> libs/gzip:deflate.release
| err e => err e
