# @koru/bridge

Persistent session management for Koru execution.

## Overview

A **bridge** holds state across interpreter invocations:

- **Session ID** - Unique identifier for the session
- **Handle pool** - Tracks undischarged resources (open files, connections, etc.)

Budget/rate limiting is the **host application's concern**, not the bridge's job.

## Use Cases

- **Multi-tenant services** (Orisha) - Isolate sessions per user
- **Interactive shells/REPLs** - Maintain state across commands
- **LLM tool-calling** - Persistent context for AI agents
- **Any long-running process** - Session isolation with resource tracking

## Usage

```koru
~import "@koru/bridge"
```

In your host application's Zig code:

```zig
const bridge = @import("bridge");

// Create a manager (one per application)
var manager = bridge.BridgeManager.init(allocator);
defer manager.deinit();

// Get or create a session
var session = try manager.getOrCreate("user-123");

// Run interpreter with session's handle pool
var ctx = interpreter.InterpreterContext{
    // ... other fields ...
    .handle_pool = &session.handle_pool,
};

const result = try interpreter.executeFlow(flow, &ctx);
```

## Session Lifecycle

```
1. getOrCreate("session-id")  → Creates or retrieves session
2. [run interpreter]          → Pass session.handle_pool
3. end("session-id")          → Cleanup, returns undischarged handles
```

## Automatic Resource Cleanup

When a session ends, the bridge returns all undischarged handles so the host can call cleanup events:

```zig
// End session - get handles that need cleanup
if (manager.end("session-id")) |handles| {
    for (handles) |h| {
        // Call the discharge event for each handle
        // e.g., fs:close for file handles
        std.debug.print("Auto-closing: {s} (obligation: {s})\n", .{
            h.binding,
            h.obligation,
        });
    }
}
```

## Re-exported Types

For convenience, the bridge module re-exports commonly used interpreter types:

- `HandlePool` - Pool of tracked resource handles
- `Handle` - A single tracked resource
- `Value` - Interpreter result value
- `InterpreterContext` - Full interpreter context

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Your Application               │
│  (Orisha, Shell, REPL, LLM Tool Server, etc.)  │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│              BridgeManager                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │Bridge A │  │Bridge B │  │Bridge C │  ...   │
│  │user-123 │  │user-456 │  │user-789 │        │
│  └─────────┘  └─────────┘  └─────────┘        │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│              Koru Interpreter                   │
│  - Handle tracking                              │
│  - Obligation discharge                         │
└─────────────────────────────────────────────────┘
```
