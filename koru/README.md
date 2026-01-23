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
