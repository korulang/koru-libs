# koru - The Koru Interpreter

A sandboxed interpreter for Koru scripts with capability-based security.

## Security Model

Scripts can ONLY call events registered in the interpreter's scope. This is enforced at **compile time** - unregistered events literally don't exist in the binary.

```koru
// This works - println is registered
~println(text: "Hello!")

// This fails with EventDenied - exec is not registered
~exec(cmd: "rm -rf /")
```

## Usage

```bash
# Run a script file
koru script.kz

# Run from stdin
echo '~println(text: "Hello!")' | koru

# Show help
koru --help
```

## Building

```bash
# From the koru-libs/koru directory
koruc koru.kz
cd output && zig build
cp zig-out/bin/output /usr/local/bin/koru
```

## Available Events

The default `koru` interpreter provides:

| Event | Description |
|-------|-------------|
| `print` | Print text (no newline) |
| `println` | Print text with newline |

## Control Flow

The interpreter handles control flow constructs specially:

### Conditionals

```koru
~if(x > 5)
| then |> println(text: "big")
| else |> println(text: "small")
```

### For Loops

```koru
~for(0..5)
| each i |> println(text: i)
| done |> println(text: "finished")
```

### While Loops (with state)

```koru
~while(x < 5 in { x: 0 })
| continue c |>
    println(text: c.x)
    | done |> continued { x: c.x + 1 }
| done c |>
    println(text: "finished")
```

The while loop:
- Takes an initial state `{ x: 0 }`
- Binds current state to `c` in the `| continue |` branch
- Updates state via `continued { x: c.x + 1 }` branch constructor
- Exits to `| done |` when condition becomes false

## Creating Custom Interpreters

The power of Koru's interpreter model is that you can create **bespoke interpreters** with different capability levels:

```koru
// koru-admin.kz - Full power interpreter
~std.runtime:register(scope: "admin") {
    print
    println
    fs.read_file
    fs.write_file
    http.get
    http.post
    shell.exec  // Danger zone!
}
```

```koru
// koru-sandbox.kz - Safe for untrusted input
~std.runtime:register(scope: "sandbox") {
    print
    println
    // That's it. No fs, no http, no exec.
}
```

The security boundary is the **compilation step itself**. The binary cannot call events that weren't registered.

## Use Cases

- **Scripting**: Run Koru scripts without compiling them
- **HTTP APIs**: Accept Koru flows over HTTP, execute atomically
- **MCP Replacement**: One flow instead of multiple tool calls
- **Edge Computing**: Ship logic to where the data is
- **Sandboxed Execution**: Run untrusted code safely

## Event Continuations Kill Chatty Interfaces

Instead of:
```
POST /get_user       → { user }
POST /get_perms      → { perms }
POST /check_active   → { active }
```

Send ONE flow:
```koru
~get_user(id: 4)
| ok u |>
    get_permissions(user: u)
    | ok p |>
        check_active(user: u)
        | active |> result { user: u, perms: p }
```

ONE request, ONE response. The continuation semantics mean the client describes the WHOLE computation.

## Budgeted Execution

Events have costs. Execution has limits. Like Ethereum gas, but for your API.

### Scope Registration with Costs

```koru
~std.runtime:register(scope: "api") {
    fs:open(10)      // costs 10
    fs:read(5)       // costs 5
    fs:close(1)      // costs 1
    db:query(50)     // costs 50
}
```

### Running with a Budget

```koru
~std.interpreter:run(
    source: user_code,
    dispatcher: d,
    cost_fn: get_event_cost_api,
    budget: 100
)
| result r   |> // completed: r.value, r.used (budget consumed)
| exhausted e |> // ran out: e.used, e.last_event
```

### What This Enables

- **Rate limiting**: Map budget to token bucket per user
- **Cost transparency**: Users see exactly what operations cost
- **Resource protection**: Prevent runaway scripts from exhausting resources
- **Tier differentiation**: Free users get 1000 budget, premium gets 50000

## Handle Pool & Obligations

Resources that need cleanup (files, connections, locks) are tracked via phantom types.

### Obligation Syntax (in Event Signatures)

```koru
// Creates obligation - the [allocated!] phantom type
~pub event open { path: []const u8 }
| ok { file: File[opened!] }

// Discharges obligation - the [!allocated] phantom type
~pub event close { file: File[!opened] }
| ok |>
```

Obligations are NOT specified in scope registration - they come from the event signatures themselves.

### Auto-Discharge

At scope exit, undischarged obligations trigger automatic cleanup. See `tests/regression/400_RUNTIME_FEATURES/400_061_phantom_autodispose/` for examples.

## Bridges: Persistent Sessions

For multi-turn interactions (REPL, chat, long-running sessions), use the Bridge library.

### What Bridges Provide

| Feature | Description |
|---------|-------------|
| **Session persistence** | Handle pool survives across requests |
| **Token bucket** | Budget refills over time based on user tier |
| **User tiers** | free (1k/10s), basic (5k/50s), premium (50k/1000s), unlimited |

### Bridge Usage Pattern

```zig
const bridge_lib = @import("bridge");
var manager = bridge_lib.BridgeManager.init(allocator);

// Get/create session
var bridge = try manager.getOrCreate("session-123", .premium);
bridge.refillBudget();  // Token bucket refill

// Run with bridge's persistent handle pool
const result = interpreter.run(
    source, dispatcher, cost_fn, ...,
    bridge.availableBudget(),
    &bridge.handle_pool,  // Handles persist!
);

// Update bridge state
bridge.consumeBudget(result.used);

// End session - get handles for cleanup
if (manager.end("session-123")) |handles| {
    for (handles) |h| { /* call discharge event */ }
}
```

### Use Cases

- **Orisha**: Web server with per-user sessions and rate limiting
- **Shell/REPL**: Interactive sessions with persistent state
- **CLI tools**: Long-running daemons with stateful bridges
- **LLM tool calling**: Track resources across multi-turn conversations
