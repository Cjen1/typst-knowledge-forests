#import "tkf.typ": *
#tkf-note(id: "inf-b.typ", title: "Inf-b", tags: (), author: "demo", date: "2026-01-06", api => [
#let transclude = api.transclude

Some more text

#transclude("inf-a.typ", mode:"inline")
])
