// Server-side TLS: load a cert/key, accept one connection, ping/pong over TLS 1.3.

import koru/openssl
import std/io

koru/openssl:server.roundtrip(cert_path: "fixtures/server.crt", key_path: "fixtures/server.key")
| ok msg |> std/io:print.ln("{{ msg:s }}")
| err e |> std/io:print.ln("server roundtrip failed: {{ e.msg:s }}")
