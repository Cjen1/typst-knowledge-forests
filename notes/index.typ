#import "tkf.typ": *
#tkf-note(id: "index.typ", title: "typst-knowledge-forests", tags: ("root", "overview"), author: "cj", date: "2026-03-02", api => [
#let transclude = api.transclude

#link("https://github.com/cjen1/typst-knowledge-forests")[typst-knowledge-forests] (TKF) aims to replicate the experience of #link("https://sr.ht/~jonsterling/forester/")[Jon Sterling's forester] using typst as the host language.

#transclude("knowledge-forests.typ", mode: "inline")
#transclude("getting-started.typ", mode: "title-link")
#transclude("two-pass-system.typ", mode: "title-link")
#transclude("lazy-evaluation.typ", mode: "title-link")
#transclude("backlinks.typ", mode: "title-link")
#transclude("metadata-demo.typ", mode: "title-link")
])
