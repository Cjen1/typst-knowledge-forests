#import "tkf.typ": *
#kt-note(id: "notes/index.typ", title: "Knowledge Tree Index", tags: ("root", "overview"), author: "cj", date: "2026-01-10", api => [
#let transclude = api.transclude

This is the root note for the Typst knowledge tree scaffold.

- #notelink("notes/typst-machinery.typ")
- #notelink("notes/backlinks.typ")
- #notelink("notes/project-status.typ")
- #notelink("notes/getting-started.typ")

#transclude("notes/typst-machinery.typ", mode: "title-link")
])
