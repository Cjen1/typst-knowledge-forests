#import "tkf.typ": *
#kt-note(id: "inf-a.typ", title: "Inf-a", tags: (), author: "demo", date: "2026-01-05", api => [
#let transclude = api.transclude

Some text

#transclude("inf-b.typ", mode:"inline")
])
