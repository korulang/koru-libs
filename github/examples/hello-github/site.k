// The whole release surface: pure Koru. Importing koru/github floats the
// release/publish-npm commands onto the compiler — no sidecar CLI.
import github

github:repo {
    owner: "korulang",
    repo: "korulang_org",
    tag_prefix: "v",
}
