#import "tkf.typ": *
#kt-note(id: "notes/typst-machinery.typ", title: "Typst Machinery", tags: ("typst", "rendering"), author: "cj", date: "2026-02-03", api => [
#let transclude = api.transclude

Typst notes can link to each other with #notelink("notes/backlinks.typ").

#transclude("notes/backlinks.typ", mode: "open")
])
