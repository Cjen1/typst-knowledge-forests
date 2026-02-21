#import "../site.typ": *
#kt-note(id: "architecture", title: "Architecture Index", tags: ("planning", "architecture"), transclude => [

This is the architecture subindex.

- #notelink("constraints")
- #notelink("design-choices")
- #notelink("project-todos")

#transclude("constraints", mode: "title-open")
#transclude("design-choices", mode: "title-open")
#transclude("project-todos", mode: "title-open")
])
