# @korulang/commander

Command-line argument parsing for Koru with declarative flags and subcommands.

## Philosophy

Like `commander.js` but for Koru - declarative CLI definition with compile-time validation.

## Usage

```koru
~import "$koru/commander"
~import "$std/args"
~import "$std/io"

// Define CLI structure at compile time
~koru.commander:program {
  "name": "my-app",
  "description": "My CLI tool",
  "version": "1.0.0"
}
| program p

// Declare flags (like compiler.flag.declare)
~p:flag.declare {
  "name": "verbose",
  "short": "v",
  "description": "Enable verbose output",
  "type": "boolean",
  "default": false
}

~p:flag.declare {
  "name": "output",
  "short": "o",
  "description": "Output file path",
  "type": "string",
  "required": true
}

// Parse command line arguments
~p:parse(args: ~std.args:rest())
| parsed result |>
    // Access parsed values
    ~result:get { "flag": "verbose" }
    | value v |> std.io:print.ln("Verbose: {b}", args: [v])
    
    ~result:get { "flag": "output" }
    | value path |> std.io:print.ln("Output: {s}", args: [path])
| help h |> std.io:print.ln("{s}", args: [h.text])
| error e |> std.io:print.ln("Error: {s}", args: [e.msg])
```

## Features

- **Declarative flag definition** - Define flags with JSON-like syntax
- **Type-safe parsing** - Boolean, string, integer, and array types
- **Automatic help generation** - `--help` and `-h` handled automatically
- **Required vs optional flags** - Compile-time validation of required flags
- **Short and long options** - `-v` and `--verbose` both work
- **Positional arguments** - Support for `my-app <file>` style args
- **Subcommands** - Git-style `my-app subcmd <args>` support

## API Reference

### program
Creates a new CLI program definition.

### flag.declare
Declares a flag with name, short option, description, type, and default.

### parse
Parses the given arguments against the declared structure.

## License

MIT
