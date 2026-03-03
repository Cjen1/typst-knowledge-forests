#import "tkf.typ": *
#tkf-note(id: "lazy-evaluation.typ", title: "Lazy Evaluation and Infinite Inclusion", tags: ("docs", "implementation"), author: "cj", date: "2026-03-02", api => [
#let transclude = api.transclude

Using `#include` directly requires that the note forest is a DAG, which cannot be guaranteed.
Typst eagerly evaluates an included file and hence fails whenever it hits a cyclic include.

The solution is to make the body of a note lazily evaluated by wrapping it in a lambda:

```
tkf-note(..., api => [
  #let transclude = api.transclude
  #transclude("other.typ")
])
```

Rendering then becomes extracting and evaluating this lambda, which also allows for depth-limited evaluation.
When the depth limit is reached, a `#notelink` is rendered in place of the transclusion.

The following two notes transclude each other, demonstrating that mutual recursion is handled gracefully:

#transclude("inf-a.typ", mode: "inline")
#transclude("inf-b.typ", mode: "inline")
])
