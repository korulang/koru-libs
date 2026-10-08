---
type: belief
id: frag-openssl-3-cannot-hand-you-a-ktls-socket
provenance: HttpArena TLS work, 2026-10 — strace-verified on OpenSSL 3.0.13 / kernel 6.12
ts: 2026-10-07
---

# OpenSSL 3.0 cannot hand you a kTLS socket after the handshake — you install it yourself (belief)

The obvious design — let OpenSSL drive the TLS 1.3 handshake and then ask it
to move the session into the kernel — does not exist in 3.0.x, no matter which
lever you pull.

## Why the levers all fail

`ktls_configure_crypto` runs only inside `change_cipher_state`, and the
handshake is the only caller left standing. The tempting post-handshake
trigger, `SSL_key_update`, routes through `tls13_update_key`, which calls
`derive_secret_key_and_iv` directly — it never reaches
`change_cipher_state`, so a KeyUpdate rotates the userspace cipher and
leaves the kernel uninvolved. `TCP_ULP` attaching during `SSL_set_fd` proves
nothing: `BIO_new_socket` calls `ktls_enable` unconditionally, so "the ULP
attached" is a statement about BIO construction, not about crypto.

The remaining path — do the handshake on a socket BIO so the mid-handshake
cipher install can offload — is worse than useless for a completion pump:
`ssl3_get_record` reads whole record batches off the fd during
`SSL_accept`, and application data bundled with the client's Finished is
consumed as post-handshake material and never yielded to `SSL_read`. Real
clients bundle exactly that. Measured: the GET's ciphertext was read off the
socket inside `SSL_accept` and `SSL_read` then returned WANT_READ forever.

## What works instead

Keep the SSL on memory BIOs for its whole life. Capture
`CLIENT_TRAFFIC_SECRET_0` / `SERVER_TRAFFIC_SECRET_0` through
`SSL_CTX_set_keylog_callback` into per-SSL ex_data, derive key+iv with
HKDF-Expand-Label (`"key"`, `"iv"` labels), count app-epoch records in each
direction, and `setsockopt(SOL_TLS, TLS_RX|TLS_TX)` the crypto state in
yourself — then `SSL_free` without `SSL_shutdown` and let the kernel own the
record layer. Verified end-to-end on Linux 6.12: `TlsTxSw`/`TlsRxSw` both
engage, post-install traffic flows, `TlsDecryptError` stays 0.

## Open questions

- OpenSSL 3.5+ claims a KeyUpdate-triggered ktls path via `SSL_OP_ENABLE_KTLS`
  semantics — unmeasured; this frag is scoped to 3.0.x.
- Peer-initiated KeyUpdate *after* offload is a kernel matter, not ours;
  before install it is guarded by `SSL_get_key_update_type`.
