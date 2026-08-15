// The whole site: pure Koru. Importing koru/vercel floats the build/dev/deploy
// commands onto the compiler — no sidecar CLI.
import vercel

vercel:site {
    name: "site",
    root: "public",
    fallback: null,
    routes: [],
    backend: null,
    dynamic: [],
    link: null,
    bake: [],
    bake_env: [],
    alias: null,
    verify: [],
}
