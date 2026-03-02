#import "tkf.typ": *
#kt-note(id: "notes/project-status.typ", title: "Architecture Index", tags: ("planning", "architecture"), author: "cj", date: "2026-02-05", api => [
#let transclude = api.transclude

This is the architecture subindex.

- #notelink("notes/constraints.typ")
- #notelink("notes/design-choices.typ")
- #notelink("notes/project-todos.typ")

#transclude("notes/constraints.typ", mode: "title-link")
#transclude("notes/design-choices.typ", mode: "title-link")
#transclude("notes/project-todos.typ", mode: "title-link")
])
