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

// Declare image at compile time
~docker:image {
    FROM: "scratch",
    COPY: ["./zig-out/bin/server", "/server"],
    ENTRYPOINT: ["/server"]
}
```

### Container Lifecycle

```koru
~docker:run(image: "myapp:latest", name: "myapp")
| started c |>   // c.container has [running!] obligation
    do_work()
    |> docker:stop(container: c.container)
        | stopped |> done()
        | failed e |> handle_error(e.msg)
| failed e |> handle_error(e.msg)
```

The `[running!]` obligation ensures you can't forget to stop the container. The compiler will reject code paths that don't discharge the obligation.

### Build and Push

```koru
~docker:build(tag: "myapp:latest", context: ".")
| built img |> docker:push(image: img.image.tag)
    | pushed |> success()
    | failed e |> handle_error(e.msg)
| failed e |> handle_error(e.msg)
```

## Events

| Event | Obligation | Description |
|-------|------------|-------------|
| `image` | - | Compile-time image declaration |
| `build` | - | Build image from context |
| `run` | `[running!]` | Start container (must stop) |
| `stop` | `[!running]` | Stop container gracefully |
| `kill` | `[!running]` | Stop container forcefully |
| `push` | - | Push image to registry |
| `pull` | - | Pull image from registry |

## Philosophy

Containers are resources. Resources have lifecycles. Koru's phantom obligations make the lifecycle explicit and compiler-checked.

You cannot:
- Forget to stop a running container
- Stop a container twice
- Use a stopped container

The compiler enforces this. Not tests. Not discipline. The compiler.
