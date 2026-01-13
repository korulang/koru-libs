# @korulang/gzip

Gzip compression for [Koru](https://korulang.org) - works at both compile-time and runtime.

Wraps **zlib** - the industry standard, battle-tested for 30+ years.

## Installation

```bash
koruc app.kz i
```

In your `app.kz`:
```koru
~std.package:requires.npm { "@korulang/gzip": "^0.0.1" }
```

Requires zlib installed on your system (available by default on macOS/Linux).

## Usage

### Compression

```koru
~import "$koru/gzip"

~koru.gzip:compress(data: my_content, allocator: allocator)
| compressed c |>
    // c.data contains gzipped bytes
    // c.original_size for compression ratio stats
| error e |>
    // e.msg describes what went wrong
```

### With Compression Level

```koru
~koru.gzip:compress(data: content, level: .best, allocator: allocator)
| compressed c |> ...
```

Levels:
- `.fast` - Fastest (zlib level 1)
- `.default` - Balanced (zlib level 6)
- `.best` - Smallest output (zlib level 9)

### Decompression

```koru
~koru.gzip:decompress(data: gzipped_bytes, allocator: allocator)
| decompressed d |>
    // d.data is the original content
| error e |>
    // Invalid gzip, corrupted, etc.
```

### Compile-Time Compression (Orisha pattern)

```koru
// In your route collector or build script
~koru.gzip:compress_bytes(data: file_content, allocator: allocator)
| ok c |>
    // c.data is now gzipped, embed into binary
    // Add Content-Encoding: gzip header
| error |>
    // Fall back to uncompressed
```

## API

| Event | Input | Output |
|-------|-------|--------|
| `compress` | `data`, `level?`, `allocator` | `compressed { data, original_size }` or `error { msg }` |
| `compress_bytes` | `data`, `allocator` | `ok { data }` or `error { msg }` |
| `decompress` | `data`, `allocator` | `decompressed { data }` or `error { msg }` |

## The "Deleted Work" Pattern

This library is designed for Koru's compile-time philosophy:

```
Traditional:
  Request -> Read file -> Compress -> Send
  (Every. Single. Request.)

Koru + @korulang/gzip:
  Compile time: Read file -> Compress -> Embed
  Runtime: Request -> Send pre-compressed blob
  (Compression happened ONCE, during build)
```

## Used By

- [Orisha](https://github.com/korulang/orisha) - Compile-time HTTP server

## Implementation

Wraps system zlib via `@cImport`. Uses `deflateInit2` with `windowBits=31` for gzip format.

## License

MIT
