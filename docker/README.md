# @korulang/docker

Docker DSL for Koru - declarative images, typed container lifecycle.

## Installation

```koru
~import "$std/package"
~std.package:requires.npm { "@korulang/docker": "^0.0.1" }
```

Then: `koruc app.kz i`

## Usage

### Declarative Image Definition

```koru
~import "$koru/docker"

// Declare image at compile time — the block is a raw Dockerfile Source,
// collected during AST walking by `koruc <file>.kz docker build`.
~koru/docker:image(tag: "myapp:latest") {
    FROM scratch
    COPY ./zig-out/bin/server /server
    ENTRYPOINT ["/server"]
}
```

### Container Lifecycle

```koru
~docker:run(image: "myapp:latest", name: "myapp")
| started c |>   // c carries the <running!> obligation
    do_work()
    |> docker:stop(container: c)
        | stopped |> done()
        | failed e |> handle_error(e.msg)
| failed e |> handle_error(e.msg)
```

The `<running!>` obligation ensures you can't forget to stop the container. The compiler will reject code paths that don't discharge the obligation.

### Build and Push

```koru
~docker:build(tag: "myapp:latest", context: ".")
| built img |> docker:push(image: img.tag)
    | pushed |> success()
    | failed e |> handle_error(e.msg)
| failed e |> handle_error(e.msg)
```

## Events

| Event | Obligation | Description |
|-------|------------|-------------|
| `image` | - | Compile-time image declaration |
| `build` | - | Build image from context |
| `run` | `<running!>` | Start container (must stop) |
| `stop` | `<!running>` | Stop container gracefully |
| `kill` | `<!running>` | Stop container forcefully |
| `push` | - | Push image to registry |
| `pull` | - | Pull image from registry |

## Tests

`docker/tests/` — compiles via `koruc --check`, exercised as real call sites:

- `build_run_stop.kz` — full lifecycle: build → run → stop, discharging `running!`.
- `pull_image.kz` — registry read, no obligation.
- `forgot_stop.kz` — negative test: starts a container and never stops it;
  MUST fail to compile (`KORU030`, obligation not discharged).

See `LIFT_NOTES.md` for the quality-pass writeup: what was migrated, the
quadrifecta self-audit, and a toolchain bug pinned along the way.

## Philosophy

Containers are resources. Resources have lifecycles. Koru's phantom obligations make the lifecycle explicit and compiler-checked.

You cannot:
- Forget to stop a running container
- Stop a container twice
- Use a stopped container

The compiler enforces this. Not tests. Not discipline. The compiler.
