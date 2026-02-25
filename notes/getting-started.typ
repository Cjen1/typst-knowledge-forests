#import "tkf.typ": *
#kt-note(id: "notes/getting-started.typ", title: "Getting Started", tags: ("docs", "usage"), author: "cj", date: "2026-02-25", _ => [

To use typst-knowledge-forests in your own project:

+ Copy `tkf.typ` from this repo into your notes directory (e.g. `notes/tkf.typ`).

+ Each note file should begin with `#import "tkf.typ": *` and define a single `#kt-note(...)`. The body receives `api`; start with `#let transclude = api.transclude` and then call `#transclude("notes/other.typ")`. Note IDs are derived automatically from the file path (e.g. `notes/my-note.typ`), and `#notelink("notes/other.typ")` still creates plain links.

+ Install the CLI (`tkf`) and ensure `typst` is on your PATH.

+ Run `tkf build` from your project root. The CLI will:
  - Scan `notes/` for `.typ` files (excluding `tkf.typ`)
  - Generate `generated/manifest.json`, `generated/query.typ`, and `generated/metadata.json`
  - Compile each note to HTML in `dist/`

+ If `tkf.typ` is missing from your notes directory, the CLI will error with a message telling you to copy it.

=== Nix flake integration

If the upstream repo exports a Nix package (via `packages.default`), you can reference it as a flake input:

```
inputs.typst-knowledge-forests.url = "github:Cjen1/typst-knowledge-forests";
```

Then add the package to your `devShell` `buildInputs` to get the CLI on your PATH. For local development against a checkout, use:

```
nix develop --override-input typst-knowledge-forests path:../typst-knowledge-forests
```
])
