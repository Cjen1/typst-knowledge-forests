#import "tkf.typ": *
#kt-note(id: "notes/index.typ", title: "typst-knowledge-forests", tags: ("root", "overview"), author: "cj", date: "2026-03-02", api => [
#let transclude = api.transclude

#link("https://github.com/cjen1/typst-knowledge-forests")[typst-knowledge-forests] (TKF) aims to replicate the experience of #link("https://sr.ht/~jonsterling/forester/")[Jon Sterling's forester] using typst as the host language.

#transclude("notes/knowledge-forests.typ", mode: "inline")
#transclude("notes/getting-started.typ", mode: "title-link")
#transclude("notes/two-pass-system.typ", mode: "title-link")
#transclude("notes/lazy-evaluation.typ", mode: "title-link")
#transclude("notes/backlinks.typ", mode: "title-link")
#transclude("notes/metadata-demo.typ", mode: "title-link")
])
