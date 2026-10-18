// @korulang/rails — ActiveSupport-compatible message signing.
//
// The wire protocols a Rails twin speaks — ActiveRecord::SignedId, Turbo
// signed stream names, ActionDispatch signed cookies, masked CSRF
// tokens — parameterized over the application's purposes and names.
// The salts, envelope shapes, and digest choices are Rails's protocol;
// what gets signed is yours.
//
//   import koru/rails
//   rails:id.sign(data: 42, purpose: "user/avatar", ttl-secs: 0)
//   rails:id.verify(raw: tok, purpose: "user/avatar")
//
// SECRET_KEY_BASE is the secret source, as upstream; keys derive by
// PBKDF2-HMAC-SHA256 (1000 iterations) under each protocol's fixed salt
// and cache per thread. An unset secret renders an empty signature / a
// failed verify — a visibly broken URL, never a silent substitute.
//
// `ttl-secs: 0` means no expiry; a negative ttl signs an
// already-expired token (a refusal you can test). Verifiers answer "no" —
// 0, null, or false — never an error; the caller decides what a failure
// becomes.
//
// Depends on koru/yyjson for envelope parsing. A module's Zig lands in
// the emitted root only when one of its tors is invoked — emission
// follows invocation, not import — so a consumer of the verify tors must
// also invoke at least one koru/yyjson tor itself to wire the module.
// That is a toolchain gap (a package cannot declare a Zig-internal dep
// on a sibling package), surfaced here rather than routed around.

// ── ActiveRecord::SignedId ──────────────────────────────────────────
// `<b64url-nopad envelope>--<hmac-sha256 hex>`; the envelope is
// {"_rails":{"data":N,"pur":P}} plus "exp" when ttl-secs ≠ 0.
pub tor id.sign { data: i64, purpose: string, ttl-secs: i64 } -> string
pub tor id.verify { raw: string, purpose: string } -> i64

// ── Turbo::StreamsChannel signed stream names ───────────────────────
// JSON-dump the name, strict-base64 (padded), "--", hex HMAC-SHA256
// under the turbo verifier salt.
pub tor stream.sign { name: string } -> string
pub tor stream.verify { signed: string } -> ?string

// ── ActionDispatch signed cookies (legacy NullSerializer envelope) ──
// cookie.sign answers the raw signed value; cookie.header the whole
// Set-Cookie value (`<name>=<escaped>; path=/; [expires=…;] httponly;
// samesite=lax` — ttl-secs 0 omits expires, a session cookie).
pub tor cookie.sign { name: string, value: string, ttl-secs: i64 } -> string
pub tor cookie.header { name: string, value: string, ttl-secs: i64 } -> string
pub tor cookie.clear { name: string } -> string
pub tor cookie.verify { name: string, raw: ?string } -> ?string

// ── masked CSRF tokens ──────────────────────────────────────────────
// Rails's one-time-pad masking: real is a 32-byte secret (derive one
// with keyed-hmac if you bind it to something else); mask emits the
// 86-char presented token, check accepts the masked form or the raw
// real secret, constant-time.
pub tor csrf.mask { real: string } -> string
pub tor csrf.check { real: string, presented: string } -> bool

// ── primitives ──────────────────────────────────────────────────────
// PBKDF2(SECRET_KEY_BASE, salt, 1000) then HMAC-SHA256(data) — the
// 32 raw bytes, for callers binding a key to app state.
pub tor keyed-hmac { salt: string, data: string } -> string

// GlobalID.to_param: urlsafe-b64-nopad of gid://<app>/<rtype>/<rid>.
pub tor gid-param { app: string, rtype: string, rid: string } -> string
