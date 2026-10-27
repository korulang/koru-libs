# @korulang/rails

ActiveSupport-compatible message signing for Koru — the wire protocols a
Rails twin speaks, parameterized over your application's purposes and
names. The salts, envelope shapes, and digest choices are Rails's
protocol; what gets signed is yours.

`SECRET_KEY_BASE` is the secret source, as upstream. Keys derive by
PBKDF2-HMAC-SHA256 (1000 iterations) under each protocol's fixed salt and
cache per thread. An unset secret renders an empty signature / a failed
verify — a visibly broken URL, never a silent substitute.

`ttl-secs: 0` means no expiry; a negative ttl signs an
already-expired token (a refusal you can test). Verifiers answer "no" — `0`, `null`, or
`false` — never an error.

## Surface

```koru
import koru/rails

// ActiveRecord::SignedId — <b64url envelope>--<hmac-sha256 hex>
rails:id.sign(data: 42, purpose: "user/avatar", ttl-secs: 0)
rails:id.verify(raw: tok, purpose: "user/avatar")        // -> i64, 0 = no

// Turbo signed stream names — JSON-dump, strict-b64, HMAC-SHA256
rails:stream.sign(name: "rooms")
rails:stream.verify(signed: tok)                          // -> ?string

// ActionDispatch signed cookies (legacy envelope, HMAC-SHA1)
rails:cookie.sign(name: "session_token", value: t, ttl-secs: 630720000)
rails:cookie.header(name: "session_token", value: t, ttl-secs: 630720000)
rails:cookie.clear(name: "session_token")
rails:cookie.verify(name: "session_token", raw: wire)     // -> ?string

// Masked CSRF tokens — one-time-pad over a 32-byte real secret
rails:csrf.mask(real: r)
rails:csrf.check(real: r, presented: tok)                 // -> bool

// Primitives
rails:keyed-hmac(salt: "app/csrf_token", data: session)   // 32 raw bytes
rails:gid-param(app: "campfire", rtype: "Room", rid: "7") // gid.to_param
```

## Notes

- Depends on `koru/yyjson` for envelope parsing. Module emission follows
  invocation, not import — a consumer of the `*.verify` tors must invoke
  at least one `koru/yyjson` tor itself (e.g. a parse+close at startup)
  to wire the module into the emitted root. That is a surfaced toolchain
  gap: a package cannot declare a Zig-internal dep on a sibling package.
- Return values borrow thread-local scratch — valid until the next call
  on the same thread. Copy out (`std/string:from-page` + `take`) before
  producing or stashing one.
- `cookie.verify` accepts envelopes with no `pur` field, matching the
  upstream jar; an envelope naming another purpose refuses.

## Layout

- `index.k` — the public contract (pure Koru declarations)
- `index.kz` — the signing machinery (Zig `~proc` implementations)
- `tests/` — roundtrip + tamper cases, registered in the root `suite.k`
