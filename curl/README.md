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
~import "$koru/curl"

// Simple GET request
~koru.curl:get(url: "https://api.example.com/users/123", allocator: alloc)
| response r |>
    // Read response body, check status code, etc. (before closing)
    std.io:print.ln("Got response: {s}", args: [r.status])
    // Now close the connection (discharge obligation)
    ~koru.curl:close(resp: r)
    | closed _ |>
        std.io:print.ln("Connection closed")
| error e |>
    std.io:print.ln("Request failed: {s}", args: [e.msg])
```

### POST with JSON

```koru
~import "$koru/curl"
~import "$std/io"

const data = "{ \"name\": \"Koru\" }"
const headers = [ .{
    .key = "Content-Type",
    .val = "application/json",
} ]

~koru.curl:post(url: "https://api.example.com/users", body: data, headers: headers, allocator: alloc)
| response r |>
    std.io:print.ln("Got response, now closing...")
    ~koru.curl:close(resp: r)
    | closed _ |>
        std.io:print.ln("Done")
| error e |>
    std.io:print.ln("Error: {s}", args: [e.msg])
```

---

## Phantom Type Obligations

The compiler ensures you never forget to close connections:

### State Machine

1. **Request[not_sent]** - Initial request state
2. **Response[opened!]** - After request succeeds, obligation to close
3. **closed** - Final state, obligation fulfilled

### Example: Compiler Prevents Leaks

```koru
// ❌ This WON'T compile - forgot to close response:
~koru.curl:get(url: "https://api.example.com", allocator: alloc)
| response r |>
    std.io:print.ln("Body: {s}", args: [r.body])
    // ERROR: r is Response[!not_closed] - MUST close first!
```

```koru
// ✅ Correct - fulfill obligation:
~koru.curl:get(url: "https://api.example.com", allocator: alloc)
| response r |>
    std.io:print.ln("Body: {s}", args: [r.body])
    ~koru.curl:close(resp: r)  // Obligation fulfilled
    | closed _ |>
        std.io:print.ln("Done")
| error e |>
    std.io:print.ln("Error: {s}", args: [e.msg])
```

**The phantom type tracks resource lifecycle at compile-time. No more connection leaks!**

---

## API Reference

### GET Request

```koru
~koru.curl:get(url: []const u8, allocator: std.mem.Allocator)
| response Response[!not_closed]
| error Error
```

**Parameters:**
- `url` - Full HTTP URL
- `allocator` - Memory allocator for response data

### POST Request

```koru
~koru.curl:post(
    url: []const u8,
    body: []const u8,
    headers: []const Header,
    allocator: std.mem.Allocator
)
| response Response[!not_closed]
| error Error
```

### Close Connection

```koru
~koru.curl:close(resp: Response[!not_closed])
| closed {}
```

**Required:** You MUST call this before the response value goes out of scope, or the code won't compile.

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
~koru.curl:get(url: url, allocator: alloc)
| resp r |>
    // COMPILER ERROR if you forget to close!
    ~koru.curl:close(resp: r)
    | closed _ |>
        // Now you can use the data
```

**The compiler won't let you forget.**

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

🚧 **In Development**

- [x] Package structure
- [ ] FFI bindings to libcurl
- [ ] Phantom type definitions
- [ ] GET implementation
- [ ] POST/PUT/DELETE implementation
- [ ] Header support
- [ ] Response body reading
- [ ] Error handling
- [ ] Tests
- [ ] Examples
- [ ] Documentation

---

## Future Enhancements

- [ ] Streaming responses (don't load entire body into memory)
- [ ] Query parameter building
- [ ] OAuth support
- [ ] Multipart file uploads
- [ ] Progress callbacks
- [ ] Timeout handling
- [ ] Proxy configuration

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
