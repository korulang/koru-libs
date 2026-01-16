# API Design from Examples

## What Examples Expect

Based on realistic use cases, the API should provide:

### 1. Response Object with Data

```koru
~koru.curl:get(url: "https://...", allocator: alloc)
| response r |>
    // r.status - HTTP status code (200, 404, etc.)
    std.io:print.ln("Status: {d}", args: [r.status])
    // r.body - Response body content
    std.io:print.ln("Body: {s}", args: [r.body])
    ~koru.curl:close(resp: r)
    | closed _ |>
```

### 2. Error Information

```koru
| error e |>
    // e.msg - Human-readable error message
    std.io:print.ln("Error: {s}", args: [e.msg])
    // e.code - libcurl error code
    std.io:print.ln("Code: {d}", args: [e.code])
```

### 3. Natural Koru Flow

```koru
// Get response -> do work -> close
~koru.curl:get(...)
| response r |>
    // Use r.status, r.body
    process(response: r)
    ~koru.curl:close(resp: r)
    | closed _ |>
        // Now obligation is discharged
        do_next_thing()
```

## Required API Changes

### Response Struct

**Current:**
```zig
const Response = struct {
    handle: ?*c.CURL,
};
```

**Needs:**
```zig
const Response = struct {
    handle: ?*c.CURL,
    status: i32,           // HTTP status code (200, 404, etc.)
    body: []const u8,     // Response body content
};
```

### Implementation Required

1. **Store body during request**
   - Write callback in `get()` and `post()` captures response data
   - Store it in Response struct
   - Pass ownership to Response (allocated with user's allocator)

2. **Get status code**
   - Use `curl_easy_getinfo(CURLINFO_RESPONSE_CODE)` after perform
   - Store in Response struct

3. **Body lifecycle**
   - Allocated during request
   - Deallocated when Response goes out of scope
   - Or add explicit `read.body()` event if we want streaming

## Koru-ness of the Design

### ✅ Good

- **Explicit flow:** Get → Use → Close (clear lifecycle)
- **Phantom obligations:** Enforce cleanup at compile-time
- **Error handling:** Separated success/error continuations
- **Type safety:** Can't use closed response

### ⚠️ Concerns

- **Body ownership:** Who allocates? Who frees?
  - If Response allocates, who frees?
  - If caller allocates, how do we get it in there?

### Option A: Response Allocates Body

```zig
const Response = struct {
    handle: ?*c.CURL,
    status: i32,
    body: []const u8,  // Response owns this memory!
};

// User must free before close()
~koru.curl:close { resp: Response[!opened] }
| closed {}

~proc close {
    // Free body first!
    if (resp.body.len > 0) {
        // TODO: Need allocator to free!
    }
    _ = c.curl_easy_cleanup(resp.handle);
    return .closed;
}
```

**Problem:** Close needs allocator to free body!

### Option B: Caller Provides Allocator

```zig
~pub event get {
    url: []const u8,
    allocator: std.mem.Allocator
}
| response Response[opened!]
| error Error

// Response uses this allocator for body
~proc get {
    var response_data = std.ArrayList(u8).init(allocator);
    // ... collect body ...
    return .{
        .response = .{
            .handle = handle,
            .status = status,
            .body = response_data.toOwnedSlice(),  // Allocated with user's allocator!
        }
    };
}
```

**Problem:** Response doesn't have allocator to free with in close!

### Option C: Add Allocator to Response

```zig
const Response = struct {
    handle: ?*c.CURL,
    allocator: std.mem.Allocator,  // Remember which allocator we used
    status: i32,
    body: []const u8,
};

~proc close {
    // Free body using Response's allocator
    if (resp.body.len > 0) {
        resp.allocator.free(resp.body);
    }
    _ = c.curl_easy_cleanup(resp.handle);
    return .closed;
}
```

**This works!** Response remembers its own allocator.

## Recommendation: Option C

```zig
const Response = struct {
    handle: ?*c.CURL,
    allocator: std.mem.Allocator,
    status: i32,
    body: []const u8,
};
```

**Why:**
1. User doesn't have to think about body ownership
2. `close()` automatically frees body
3. Follows Koru's "discharge all obligations" philosophy
4. Simple to use: Get → Use → Close (everything cleaned up)

## Implementation Plan

1. Add `allocator` field to Response struct
2. Store body in Response during `get()` / `post()`
3. Get status code using `curl_easy_getinfo`
4. Free body in `close()` using stored allocator
5. Test with examples

## Next Step

Implement Option C and test examples!
