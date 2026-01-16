# Koru Ecosystem Roadmap

> Mapping the JavaScript/Python ecosystem to Koru, with a focus on wrapping proven C/Zig libraries.

This document outlines foundational infrastructure packages needed to make Koru a productive, general-purpose language. Each entry maps to mature JS/Python equivalents and identifies proven C/Zig libraries we can wrap.

**Philosophy: Don't reinvent. Wrap excellent libraries and expose them through Koru's type system.**

---

## Priority Legend

- 🔥 **Critical Path** - Blocking major use cases, high urgency
- 🚧 **In Progress** - Currently being implemented
- ✅ **Available** - Package exists in koru-libs
- 📋 **Planned** - Design complete, awaiting implementation
- 💭 **Future** - Idea stage, lower priority

---

## 1. Data Formats

### CSV/TSV Processing
**Ecosystem counterparts:** pandas (Python), csv-parse (Node), csvlib (Go)
**Use case:** Data import/export, ETL, log processing, data analysis
**C/Zig libraries:**
- Zig std: `std.csv` (built-in parser)
- libcsv (C) - Fast, RFC 4180 compliant
- RapidCSV (C++) - Header-only, minimal dependencies

**Koru advantage:** Compile-time schema validation with phantom types - never forget to handle missing columns

**Priority:** 🔥 Critical
**Status:** 📋 Planned

---

### JSON5 / JSONC (with comments)
**Ecosystem counterparts:** json5 (Node), jsonc-parser (TypeScript)
**Use case:** Configuration files that need comments (package.json, VS Code configs)
**C/Zig libraries:**
- json5 (C) - Reference implementation
- zig-std/json - Has C support, need to add comments

**Koru advantage:** Compile-time config validation

**Priority:** 🚧 In Progress
**Status:** 📋 Planned

---

### TOML Configuration
**Ecosystem counterparts:** toml (Python), @iarna/toml (Node)
**Use case:** Configuration files (Cargo, Python Poetry, many modern tools)
**C/Zig libraries:**
- Zig std: `std.toml` (built-in parser, excellent!)
- toml11 (C++) - Header-only, feature-complete

**Koru advantage:** Type-safe config deserialization, compile-time validation of required fields

**Priority:** 🔥 Critical
**Status:** ✅ Available (Zig std wrapper) or wrap toml11 for features

---

### YAML Configuration
**Ecosystem counterparts:** PyYAML (Python), js-yaml (Node)
**Use case:** Kubernetes configs, CI/CD pipelines, complex configuration
**C/Zig libraries:**
- libyaml (C) - Reference implementation, YAML 1.2
- yaml-cpp (C++) - Feature-rich, good error messages

**Koru advantage:** Schema validation at compile-time, prevent config errors before runtime

**Priority:** 🔥 Critical
**Status:** 📋 Planned

---

## 2. CLI & Terminal

### Command-Line Argument Parsing
**Ecosystem counterparts:** argparse (Python), commander (Node), clap (Rust)
**Use case:** Building CLI tools (essential for developer tooling)
**C/Zig libraries:**
- zig-std/c/args - Built-in, minimal
- clap (C++) - Modern, comptime-style parsing
- getopt (C) - POSIX standard

**Koru advantage:** Compile-time argument validation, subcommand type checking

**Priority:** 🔥 Critical
**Status:** 📋 Planned

---

### Terminal Output Formatting
**Ecosystem counterparts:** rich (Python), chalk (Node), tabulate (Python)
**Use case:** Pretty tables, progress bars, colored output
**C/Zig libraries:**
- Zig std: `std.io.tty` (colors), `std.Progress` (progress bars)
- termbox (C) - Terminal UI
- nana (C++) - Modern terminal widgets

**Koru advantage:** Type-safe formatting, compile-time layout validation

**Priority:** 🚧 High
**Status:** 📋 Planned

---

### Interactive Prompting
**Ecosystem counterparts:** inquirer (Node), questionary (Python)
**Use case:** Interactive CLI wizards, user input collection
**C/Zig libraries:**
- linenoise (C) - Readline replacement
- rustyline (C++) - Readline fork, more features
- prompt_toolkit (Python, could wrap?)

**Koru advantage:** Type-safe prompt responses, validation at compile-time

**Priority:** 💭 Low
**Status:** 📋 Planned

---

## 3. Date & Time

### Date/Time Operations
**Ecosystem counterparts:** moment.js (Node), date-fns (Node), python-dateutil (Python)
**Use case:** Timezone handling, parsing, formatting, arithmetic
**C/Zig libraries:**
- Zig std: `std.time` (good basics, limited timezones)
- tz.h (C) - IANA timezone database
- cctz (C++) - Google's time library, excellent

**Koru advantage:** Timezone-aware phantom types, never pass UTC where local expected

**Priority:** 🔥 Critical
**Status:** 📋 Planned (use cctz or tz.h)

---

### CRON Scheduling
**Ecosystem counterparts:** node-cron (Node), schedule (Python)
**Use case:** Scheduled tasks, job runners, automation
**C/Zig libraries:**
- libcron (C++) - Header-only, CRON expression parsing
- cronexpr (C) - Minimal, RFC 5545 compliant

**Koru advantage:** Compile-time CRON expression validation, type-safe job handlers

**Priority:** 🚧 High
**Status:** 📋 Planned

---

## 4. HTTP & Networking

### curl (HTTP Client)
**Ecosystem counterparts:** requests (Python), axios (Node)
**Use case:** API calls, webhooks, microservices communication
**C/Zig libraries:**
- libcurl (C) - Industry standard, feature-complete
- cpr (C++) - Modern C++ wrapper around libcurl

**Koru advantage:** Phantom obligation types (never forget to close connection), type-safe request/response

**Priority:** 🔥 Critical
**Status:** 🚧 In Progress (currently implementing)

---

### WebSocket Client
**Ecosystem counterparts:** socket.io-client (Node), websockets (Python)
**Use case:** Real-time communication, browser-server events
**C/Zig libraries:**
- libwebsockets (C) - Full WebSocket implementation
- uWebSockets (C++) - Ultra-fast, HTTP/WebSocket server/client

**Koru advantage:** Connection state obligations, type-safe message handling

**Priority:** 🚧 High
**Status:** 📋 Planned

---

### gRPC
**Ecosystem counterparts:** grpc-node (Node), grpcio (Python)
**Use case:** Microservices, high-performance RPC
**C/Zig libraries:**
- grpc (C++) - Reference implementation
- grpc++ (C++) - C++ bindings

**Koru advantage:** Compile-time proto validation, service contract obligations

**Priority:** 💭 Future
**Status:** 📋 Planned

---

## 5. Cryptography

### Hashing (SHA, MD5, etc.)
**Ecosystem counterparts:** crypto (Node), hashlib (Python)
**Use case:** Checksums, data integrity, password hashing
**C/Zig libraries:**
- Zig std: `std.crypto` - Excellent, built-in
- OpenSSL (C) - Industry standard
- libsodium (C) - Modern, secure by default

**Priority:** ✅ Available (Zig std.crypto)
**Status:** Ready to use

---

### Password Hashing (bcrypt, argon2)
**Ecosystem counterparts:** bcrypt (Node), passlib (Python)
**Use case:** Secure password storage
**C/Zig libraries:**
- bcrypt (C) - Reference implementation
- libargon2 (C) - Argon2 algorithm, winner of PHC

**Koru advantage:** Phantom type for "hashed password" vs "plain text password", never mix up

**Priority:** 🔥 Critical (security)
**Status:** 📋 Planned (wrap bcrypt or argon2)

---

### JWT (JSON Web Tokens)
**Ecosystem counterparts:** jsonwebtoken (Node), PyJWT (Python)
**Use case:** Authentication tokens, OAuth flows
**C/Zig libraries:**
- libjwt (C) - JWT implementation
- jwt-cpp (C++) - Modern, header-only

**Koru advantage:** Token state obligations (signed/unsigned/verified), type-safe claims

**Priority:** 🔥 Critical (auth)
**Status:** 📋 Planned

---

## 6. Logging

### Structured Logging
**Ecosystem counterparts:** winston (Node), structlog (Python), logrus (Go)
**Use case:** Application logging, debugging, observability
**C/Zig libraries:**
- spdlog (C++) - Fast, header-only, structured logging
- glog (C++) - Google's logging library
- Zig std: `std.log` - Basic, no structured support

**Koru advantage:** Compile-time log level filtering, type-safe context fields

**Priority:** 🔥 Critical
**Status:** 📋 Planned (wrap spdlog)

---

### Distributed Tracing (OpenTelemetry)
**Ecosystem counterparts:** opentelemetry-js (Node), opentelemetry-python (Python)
**Use case:** Microservices tracing, distributed systems debugging
**C/Zig libraries:**
- opentelemetry-cpp (C++) - Official implementation
- libopentelemetry (C) - C SDK

**Koru advantage:** Span context obligations, automatic instrumentation

**Priority:** 💭 Future
**Status:** 📋 Planned

---

## 7. Testing

### Test Framework
**Ecosystem counterparts:** pytest (Python), jest (Node), go test (Go)
**Use case:** Unit testing, integration testing
**C/Zig libraries:**
- Zig std: `std.testing` - Built-in, good enough for now
- googletest (C++) - Feature-rich test framework

**Priority:** ✅ Available (Zig std.testing)
**Status:** Ready to use

---

### Test Doubles (Mocking, Fakes)
**Ecosystem counterparts:** unittest.mock (Python), sinon (Node)
**Use case:** Mocking external dependencies in tests
**C/Zig libraries:**
- trompeloeil (C++) - Mocking framework
- fakeit (C++) - Header-only mocking

**Koru advantage:** Phantom type "Mock[T]" vs "Real[T]" prevents mixing at compile-time

**Priority:** 🚧 High
**Status:** 📋 Planned

---

### Property-Based Testing
**Ecosystem counterparts:** QuickCheck (Haskell), hypothesis (Python), fast-check (Node)
**Use case:** Finding edge cases through random testing
**C/Zig libraries:**
- RapidCheck (C++) - QuickCheck for C++
- Criterion (C) - Property-based testing

**Koru advantage:** Type-safe property definitions, comptime shrinks

**Priority:** 💭 Future
**Status:** 📋 Planned

---

## 8. System Utilities

### File System Watching
**Ecosystem counterparts:** chokidar (Node), watchdog (Python)
**Use case:** Hot reload, build tools, dev servers
**C/Zig libraries:**
- inotify (C) - Linux file system events
- kqueue (C) - macOS/BSD file system events
- ReadDirectoryChangesW (Win32 API) - Windows

**Koru advantage:** Watcher state obligations, never forget to cleanup

**Priority:** 🚧 High
**Status:** 📋 Planned (cross-platform wrapper)

---

### Process Management
**Ecosystem counterparts:** PM2 (Node), supervisor (Python)
**Use case:** Running subprocesses, process spawning
**C/Zig libraries:**
- Zig std: `std.process.Child` - Built-in, good
- libuv (C) - Cross-platform async I/O, process management

**Priority:** ✅ Available (Zig std.process)
**Status:** Ready to use

---

### Environment Variables
**Ecosystem counterparts:** dotenv (Node), python-dotenv (Python)
**Use case:** Loading .env files, configuration via environment
**C/Zig libraries:**
- dotenv (C) - Reference implementation
- Zig std: `std.os.getenv` - Built-in

**Koru advantage:** Type-safe env vars, compile-time validation

**Priority:** 🚧 High
**Status:** 📋 Planned

---

## 9. Compression

### Gzip Compression
**Ecosystem counterparts:** zlib (Node), gzip (Python)
**Use case:** HTTP compression, file storage
**C/Zig libraries:**
- zlib (C) - Industry standard
- ✅ **Already done!** @korulang/gzip

**Priority:** ✅ Available
**Status:** ✅ Complete

---

### Zstd Compression
**Ecosystem counterparts:** node-zstd (Node), zstandard (Python)
**Use case:** Faster compression than gzip, better ratios
**C/Zig libraries:**
- zstd (C) - Facebook's compression library
- libzstd (C++) - C++ bindings

**Koru advantage:** Compression level obligations, type-safe streams

**Priority:** 🚧 High
**Status:** 📋 Planned

---

### LZ4 Compression
**Ecosystem counterparts:** lz4 (Node), lz4-block (Python)
**Use case:** Ultra-fast compression (real-time, logs)
**C/Zig libraries:**
- lz4 (C) - Reference implementation
- xxHash (C) - Hashing, often used with LZ4

**Priority:** 💭 Future
**Status:** 📋 Planned

---

## 10. Database Clients

### PostgreSQL
**Ecosystem counterparts:** pg (Node), psycopg2 (Python)
**Use case:** Relational database
**C/Zig libraries:**
- libpq (C) - PostgreSQL client library
- Zig std: Has some PG protocol support

**Priority:** 🚧 High
**Status:** 📋 Planned (wrap libpq)

---

### MySQL
**Ecosystem counterparts:** mysql2 (Node), mysql-connector (Python)
**Use case:** Relational database
**C/Zig libraries:**
- libmysqlclient (C) - MySQL client library

**Priority:** 💭 Future
**Status:** 📋 Planned

---

### Redis
**Ecosystem counterparts:** redis (Node), redis-py (Python)
**Use case:** Caching, pub/sub, rate limiting
**C/Zig libraries:**
- hiredis (C) - Minimal Redis client

**Priority:** 🚧 High
**Status:** 📋 Planned

---

### SQLite
**Ecosystem counterparts:** sqlite3 (Node), sqlite3 (Python)
**Use case:** Embedded database, mobile apps
**C/Zig libraries:**
- sqlite3 (C) - Industry standard
- ✅ **Already done!** @korulang/sqlite3

**Priority:** ✅ Available
**Status:** ✅ Complete

---

## 11. Data Structures

### Priority Queues / Heaps
**Ecosystem counterparts:** heapq (Python), priority-queue (Node)
**Use case:** Task scheduling, Dijkstra's algorithm
**C/Zig libraries:**
- Zig std: `std.PriorityQueue` - Built-in, excellent

**Priority:** ✅ Available
**Status:** Ready to use

---

### Bloom Filters
**Ecosystem counterparts:** pybloom-live (Python), bloom-filters (Node)
**Use case:** Set membership, cache deduplication, spell check
**C/Zig libraries:**
- libbf (C) - Bloom filter library
- cbloomfilter (C++) - C++ implementation

**Koru advantage:** Type-safe filter keys, compile-time size validation

**Priority:** 💭 Future
**Status:** 📋 Planned

---

### LRU Cache
**Ecosystem counterparts:** lru-cache (Python), lru-cache (Node)
**Use case:** Caching with eviction policy
**C/Zig libraries:**
- lrucache (C) - Header-only LRU cache
- Boost Cache (C++) - Generic cache implementations

**Priority:** 💭 Future
**Status:** 📋 Planned

---

## 12. Concurrency

### Async Primitives
**Ecosystem counterparts:** asyncio (Python), async/await (Node)
**Use case:** Non-blocking I/O, concurrent operations
**C/Zig libraries:**
- libuv (C) - Cross-platform async I/O
- Zig std: `std.event` - Built-in event loop

**Priority:** ✅ Available (Zig std.event)
**Status:** Ready to use

---

### Thread Pools
**Ecosystem counterparts:** concurrent.futures (Python), worker_threads (Node)
**Use case:** CPU-bound parallelism
**C/Zig libraries:**
- Zig std: `std.Thread.Pool` - Built-in
- Boost.ThreadPool (C++) - Feature-rich

**Priority:** ✅ Available (Zig std.Thread)
**Status:** Ready to use

---

### Message Queues (IPC)
**Ecosystem counterparts:** multiprocessing.Queue (Python), worker-threads (Node)
**Use case:** Inter-process communication
**C/Zig libraries:**
- ZeroMQ (C) - Fast async messaging
- nanomsg (C) - Scalable communication

**Priority:** 💭 Future
**Status:** 📋 Planned

---

## Implementation Proposal

### First Package: curl (HTTP Client)

**Why curl?**
1. **High impact:** Every application needs HTTP calls (APIs, webhooks, microservices)
2. **Perfect for phantom types:** Linear state machine (request → response → close) with clear obligations
3. **Battle-tested:** libcurl is used everywhere, production-hardened
4. **Teaches patterns:** Obligation system, FFI wrapping, resource lifecycle tracking
5. **Manageable scope:** libcurl C API is well-documented, clear progression

**C library:** `libcurl` - Industry standard HTTP client, supports all protocols

**API design:**
```koru
~import "$koru/curl"

// Simple GET request
~koru.curl:get(url: "https://api.example.com", allocator: alloc)
| response r |> // r is Response[!not_closed] - MUST close!
| error e |> ...

// POST with headers
~koru.curl:post(url: "https://api.example.com", body: data, headers: headers, allocator: alloc)
| response r |> // r: Response[!not_closed]
| error e |> ...

// You MUST fulfill the obligation
~koru.curl:close(resp: response)
| closed {}

// Full example
~koru.curl:get(url: "https://api.example.com/users/123", allocator: alloc)
| resp r |>
    ~koru.curl:read.body(resp: r, allocator: alloc)
    | body b |>
        std.io:print("Got response: {s}", args: [b])
        ~koru.curl:close(resp: r)
        | closed c |>
            std.io:print("Connection closed\n")
| error e |>
    std.io:print.ln("Request failed: {s}", args: [e.msg])
```

**Phantom type state machine:**
1. `Request[not_sent]` - Initial state
2. `Response[!not_closed]` - After send, obligation to close
3. `closed` - Final state, obligation fulfilled

**The compiler enforces cleanup!**
```koru
// This won't compile - forgot to close:
~koru.curl:get(url: "https://...", allocator: alloc)
| resp r |>
    std.io:print("Got {s}", args: [r.body])  // ERROR: r is !not_closed
    // Missing: ~koru.curl:close(resp: r)  // Won't compile
```

**Implementation tasks:**
1. Wrap libcurl easy handle (FFI bindings)
2. Define phantom types: `Request`, `Response`, `closed`
3. Implement GET, POST, PUT, DELETE methods
4. Add obligation system for connection cleanup
5. Type-safe headers and query parameters
6. Response body reading (stream or all-at-once)
7. Error handling (curl error codes → Koru errors)
8. Write tests and examples
9. Document and publish to npm

**Estimated effort:** 2-3 weeks

---

## Next Steps

1. **Finish curl package** - libcurl wrapper with phantom obligations (in progress)
2. **Implement YAML package** - libyaml wrapper with schema validation
3. **Add TOML wrapper** (if Zig std isn't enough)
4. **Build CLI args parser** - Essential for tooling
5. **Structured logging** - spdlog wrapper

Each package follows the pattern:
- Find proven C/Zig library
- Wrap with clean Koru API
- Add phantom type safety
- Write comprehensive tests
- Publish to npm as @korulang/*

---

## Contributing

Want to help build the ecosystem? Great! Here's how:

1. Pick a package from this roadmap (check with maintainers first)
2. Research the C/Zig library (read docs, check license)
3. Design the Koru API (focus on type safety and ergonomics)
4. Implement (start small, iterate)
5. Test thoroughly (unit tests, examples)
6. Document (README, API docs)
7. Submit PR

**Guidelines:**
- Prefer wrapping over reinventing
- Leverage Koru's phantom types for safety
- Follow existing package structure (sqlite3, gzip)
- Use @korulang/* npm package naming
- Include clear error messages

---

## License

All packages in koru-libs are MIT licensed (same as Koru).

C libraries we wrap may have their own licenses - always check compatibility.

---

**Last updated:** 2025-01-16
