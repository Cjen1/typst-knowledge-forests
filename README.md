# typst-knowledge-forests

A tool for managing a forest of evergreen notes, inspired by [Jon Sterling's forester](https://sr.ht/~jonsterling/forester/), using [Typst](https://typst.app/) as the authoring language.

## Quick start

```bash
# Install (requires Rust toolchain and typst on PATH)
cargo install --path .

# Create a new note
tkf new "My first note"

# Build the site
tkf build
```

Or `tkf` is exported as the default package from `flake.nix`, and so can be run with `nix run . -- build`

## Documentation

The documentation for this project is itself a knowledge forest, located in [`notes/`](notes/).
Build it with `tkf build` (or `make`) and open `dist/index.html`, or read the source files directly:

- [Getting Started](notes/getting-started.typ)
- [Knowledge Forests](notes/knowledge-forests.typ)
- [The Two Pass System](notes/two-pass-system.typ)
- [Lazy Evaluation and Infinite Inclusion](notes/lazy-evaluation.typ)
- [Backlinks](notes/backlinks.typ)
- [Metadata Demo](notes/metadata-demo.typ)
