// The native (zig) lowering of `koru/dom:component`: one declaration, two
// target-specific artifacts. Under `--lang=js` the transform emits the
// paint/repaint tor pair (two_components.k); under the native backend it
// synthesizes a sibling render tor `Name-render(props) -> string` whose
// |zig body builds the markup into an ArrayList and returns it as
// `string<std.io:allocated!>` — the label that makes the caller's
// `std/io:free` auto-discharge settle the ownership.
//
// Pinned shape:
//   - static markup passes through verbatim
//   - `attr={{ x:t }}` placeholders render quoted, escaped for attribute
//     context (& < > plus " and ')
//   - text placeholders escape & < > only (quotes stay raw)
//   - `d`/`f`/`b` props format via bufPrint / "true"/"false"
//   - a capital tag at markup top level calls the child's render tor and
//     splices its bytes (deferred free on the child's owned slice)
//   - the paint tor does NOT exist under zig — `two_components.k` compiled
//     natively refuses KORU040 'unknown tor', which is the correct loud
//     failure: there is no DOM to paint.
//
// Expected output:
//   <tr data-id="42" data-label="a&quot;b&#39;c &lt;d&gt; &amp; e" data-n="3.5" hidden="true"><td>a"b'c &lt;d&gt; &amp; e</td></tr>
//   <header>t</header><tr data-id="7" data-label="ok&#39;net" data-n="1.25" hidden="false"><td>ok'net</td></tr>

import koru/dom
import std/io

koru/dom:component(Row) {
    <tr data-id={{ id:d }} data-label={{ label:s }} data-n={{ n:f }} hidden={{ on:b }}><td>{{ label:s }}</td></tr>
}

koru/dom:component(Page) {
    <header>{{ title:s }}</header>
    <Row id={{ id:d }} label={{ label:s }} n={{ n:f }} on={{ on:b }}/>
}

Row-render(id: 42, label: "a\"b'c <d> & e", n: 3.5, on: true): r |> std/io:print.ln("{{ r:s }}")
Page-render(title: "t", id: 7, label: "ok'net", n: 1.25, on: false): p |> std/io:print.ln("{{ p:s }}")
