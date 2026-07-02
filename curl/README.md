# @korulang/curl - HTTP Client for Koru

> Type-safe libcurl wrapper with phantom obligation types

Wrap around industry-standard [libcurl](https://curl.se/) that enforces connection cleanup through Koru's phantom type system.

---

## Features

- ✅ **Obligation types** - Compiler enforces connection cleanup
- ✅ **Type-safe requests** - No more magic strings
- ✅ **Error handling** - Clear, typed error messages
- ✅ **Full libcurl** - All protocols, auth, proxies supported
- ✅ **Battle-tested** - Same library used by curl CLI, wget, etc.

---

## Quick Start

### Basic GET Request

```koru
~import koru/curl
~import std/io

~koru/curl:get(url: "https://httpbin.org/get")
| ok r |> std/io:print.blk {
    === HTTP Response ===
    Status: {{ r.status:d }}
    Body length: {{ r.body.len:d }}
    }
| err e |> std/io:print.ln("Error: {{ e.msg:s }}")
```

Note there is no explicit `close` call here — the compiler's **auto-discharge**
pass traces the single legal disposer for `r`'s `open!` obligation and inserts
the `close` call for you. See `examples/01_simple_get.kz`.

### POST with headers

```koru
~import koru/curl
~import std/io

const data = "{ \"name\": \"Koru\" }";

~koru/curl:post.with-headers(url: "https://httpbin.org/post", body: data, headers: &.{ .{ .name = "Content-Type", .value = "application/json" } })
| ok r |> std/io:print.blk {
    === POST Response ===
    Status: {{ r.status:d }}
    } |> koru/curl:close(resp: r)
| err e |> std/io:print.ln("Error: {{ e.msg:s }}")
```

Here `close` is called explicitly (inside the `ok` branch, chained after the
print) rather than relying on auto-discharge — both styles are legal; explicit
`close` is clearer when you need to do work with the response first. See
`examples/02_post_json.kz`.

---

## Phantom Type Obligations

The compiler ensures you never forget to close connections:

### State Machine

1. **`*Response<open!>`** - After a request succeeds, obligation to close
2. Fulfilled by `koru/curl:close`, which consumes `*Response<!open>` and
   discharges the obligation

### Example: Compiler Prevents Leaks

If you discard a response without ever routing it through `close` (and the
compiler's default auto-discharge convenience can't find a disposer to trace
— e.g. the binding is thrown away with `_`), the build fails loudly instead
of leaking the connection and its body buffer. See
`tests/negative/forgotten_close.kz` for a pinned, runnable repro (it needs
`--auto-discharge=disable` to force the failure, since auto-discharge quietly
saves the naive case by default — see that file's header comment for why).

**The phantom type tracks resource lifecycle at compile-time. No more connection leaks!**

---

## API Reference

### GET Request

```koru
~koru/curl:get(url: []const u8, allocator: ?std.mem.Allocator)
| ok *Response<open!>
| err Error
```

**Parameters:**
- `url` - Full HTTP URL
- `allocator` - Optional memory allocator for response data (defaults to `std.heap.page_allocator`)

### POST Request

```koru
~koru/curl:post(url: []const u8, body: []const u8, allocator: ?std.mem.Allocator)
| ok *Response<open!>
| err Error
```

### POST with Headers

```koru
~koru/curl:post.with-headers(
    url: []const u8,
    body: []const u8,
    headers: []const Header,
    allocator: ?std.mem.Allocator
)
| ok *Response<open!>
| err Error
```

### Close Connection

```koru
~koru/curl:close(resp: *Response<!open>)
```

**Required:** the `open!` obligation on every `Response` must be discharged
via `close` — either explicitly, or by relying on auto-discharge when the
compiler can trace a single legal disposer for the binding.

---

## Why Phantom Types?

Without Koru's obligation system, you'd have to remember to close connections:

**Go:**
```go
resp, err := http.Get(url)
if err != nil { ... }
defer resp.Body.Close()  // Easy to forget!
```

**Python:**
```python
with requests.get(url) as resp:
    # Must remember to close (context manager helps)
    pass
# Easy to forget without `with`
```

**Koru:**
```koru
~koru/curl:get(url: url)
| ok r |> koru/curl:close(resp: r)
| err e |> std/io:print.ln("Error: {{ e.msg:s }}")
```

**The compiler won't let you forget** — and with auto-discharge, in the common
case you don't even have to write the `close` call yourself.

---

## Under the Hood

This package wraps [libcurl](https://curl.se/libcurl/) using FFI bindings:

- Uses `curl_easy_init()` / `curl_easy_perform()` / `curl_easy_cleanup()`
- Wraps response data in Koru's phantom type system
- Translates curl error codes to Koru error types
- Manages memory allocation through Zig's allocator system

**libcurl is battle-tested:** Used by curl CLI, wget, git, Python requests, Node's request library, and thousands of tools.

---

## Current Status

✅ **Working — compiles and runs against the current Koru compiler** (see
`LIFT_NOTES.md` for the 2026-07-02 migration writeup)

- [x] Package structure
- [x] FFI bindings to libcurl
- [x] Phantom type definitions (`open!` obligation on `Response`)
- [x] GET implementation
- [x] POST implementation (plain + with-headers)
- [x] Header support
- [x] Response body reading (buffered, all-at-once)
- [x] Error handling (transport-level errors only — HTTP status codes are
      not errors, see `examples/03_error_handling.kz`)
- [x] Negative test proving the obligation actually bites
- [x] Examples (all three run end-to-end against httpbin.org)
- [x] Documentation
- [ ] PUT/DELETE/PATCH
- [ ] Streaming response bodies

---

## Future Enhancements

- [ ] Streaming responses (don't load entire body into memory)
- [ ] Query parameter building
- [ ] OAuth support
- [ ] Multipart file uploads
- [ ] Progress callbacks
- [ ] Timeout handling
- [ ] Proxy configuration
- [ ] PUT / DELETE / PATCH methods

---

## License

MIT License - Same as Koru.

libcurl has its own license (Curl License) - see https://curl.se/docs/copyright.html

---

## Contributing

Want to help? Great! Areas to contribute:

1. Implement more HTTP methods (PUT, PATCH, DELETE)
2. Add header/query parameter helpers
3. Improve error messages
4. Add more examples
5. Write tests

See [koru-libs README](../README.md) for contribution guidelines.

---

**Built with ❤️ and type safety**
