#import "tkf.typ": *
#kt-note(id: "two-pass-system.typ", title: "The Two Pass System", tags: ("docs", "implementation"), author: "cj", date: "2026-03-02", api => [
#let notelink = api.notelink

TKF uses two passes for every file.

The first pass scans all notes and runs `typst query` to extract metadata.
This produces `generated/manifest.json` (a mapping from note id to file path) and `generated/metadata.json` (edges, titles, tags, and other metadata emitted via `#metadata`).

The second pass takes a single `note.typ` file together with the manifest and metadata, and uses the manifest to look up the bodies of files to transclude, while the metadata is used to construct #notelink("backlinks.typ", text: "backlinks").
])
