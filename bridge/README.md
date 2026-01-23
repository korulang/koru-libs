# @koru/bridge

Persistent session management for metered Koru execution.

## Overview

A **bridge** holds state across interpreter invocations:

- **Handle pool** - Tracks undischarged resources (open files, connections, etc.)
- **Budget tracking** - Token bucket with automatic refill
- **User tier** - Determines capacity and refill rate

## Use Cases

- **Multi-tenant services** (Orisha) - Isolate sessions, enforce quotas
- **Interactive shells/REPLs** - Maintain state across commands
- **LLM tool-calling** - Persistent context for AI agents
- **Any long-running process** - Session isolation with resource tracking

## User Tiers

| Tier      | Capacity | Refill Rate |
|-----------|----------|-------------|
| free      | 1,000    | 10/sec      |
| basic     | 5,000    | 50/sec      |
| premium   | 50,000   | 1,000/sec   |
| unlimited | -        | -           |

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
var session = try manager.getOrCreate("user-123", .premium);

// Apply token bucket refill (call before each request)
session.refillBudget();

// Get available budget
const budget = session.availableBudget();  // null = unlimited

// Run interpreter with session's handle pool
var ctx = interpreter.InterpreterContext{
    // ... other fields ...
    .budget = budget,
    .handle_pool = &session.handle_pool,
};

const result = try interpreter.executeFlow(flow, &ctx);

// Update session state
session.consumeBudget(result.budget_used);
```

## Session Lifecycle

```
1. getOrCreate("session-id", tier)  → Creates or retrieves session
2. refillBudget()                   → Apply token bucket refill
3. availableBudget()                → Get tokens available
4. [run interpreter]               → Pass session.handle_pool
5. consumeBudget(used)              → Record consumption
6. end("session-id")                → Cleanup, returns undischarged handles
```

## Automatic Resource Cleanup

When a session ends (logout, timeout, budget exhaustion), the bridge returns all undischarged handles so the host can call cleanup events:

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
│  - Budget enforcement                           │
│  - Handle tracking                              │
│  - Obligation discharge                         │
└─────────────────────────────────────────────────┘
```
