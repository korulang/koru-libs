# Koru Libraries

**WARNING: This is a work in progress and is not yet ready for production use.**

**KORU IS CURRENTLY A TODDLER AND IS NOT READY FOR PRODUCTION USE.**

Implementation Status: [Koru Status](https://www.korulang.org/status).

Official ecosystem packages for the [Koru programming language](https://github.com/korulang/koru).

## Tools

| Tool | Description |
|------|-------------|
| [koru](./koru) | Sandboxed interpreter with capability-based security |

## Packages

| Package | npm | Description |
|---------|-----|-------------|
| [sqlite3](./sqlite3) | `@korulang/sqlite3` | SQLite bindings with phantom obligations |
| docker | `@korulang/docker` | Docker DSL for images and containers (planned) |
| [gzip](./gzip) | `@korulang/gzip` | Gzip compression for Koru - compile-time or runtime |

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
~import "$koru/gzip"
```

## Publishing

Each package publishes independently to npm under the `@korulang` scope:

```bash
cd sqlite3
npm publish --access public
```
