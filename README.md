# Koru Libraries

Official ecosystem packages for the [Koru programming language](https://github.com/korulang/koru).

## Packages

| Package | npm | Description |
|---------|-----|-------------|
| [sqlite3](./sqlite3) | `@korulang/sqlite3` | SQLite bindings with phantom obligations |
| docker | `@korulang/docker` | Docker DSL for images and containers (planned) |
| orisha | `@korulang/orisha` | Web framework (planned) |

## Development

Point your `koru.json` paths here:

```json
{
  "paths": {
    "koru": "/path/to/koru_libs"
  }
}
```

Then import:

```koru
~import "$koru/sqlite3"
~import "$koru/docker"
~import "$koru/orisha"
```

## Publishing

Each package publishes independently to npm under the `@korulang` scope:

```bash
cd sqlite3
npm publish --access public
```
