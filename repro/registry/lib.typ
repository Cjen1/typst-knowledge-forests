// Registry: maps note ID -> body content (as a function taking depth)
#let kt-registry = state("kt-registry", (:))
#let kt-max-depth = 5

// Called by each note file to register its content as a closure
#let kt-note(id, body) = {
  kt-registry.update(r => {
    r.insert(id, body)
    r
  })
}

// Paste registered content by ID, with depth limiting
// depth is a plain int, not state — no context needed for the guard
#let transclude(id, depth: kt-max-depth) = {
  if depth <= 0 {
    [→ #id]
  } else {
    context {
      let reg = kt-registry.get()
      if id in reg {
        // reg.at(id) is content that may contain #transclude calls
        // but those calls have the default depth — we need to pass depth-1
        // Content is already constructed with default depth...
        // We need the body to be a function(depth) instead
        let body-fn = reg.at(id)
        body-fn(depth - 1)
      } else {
        [Missing: #id]
      }
    }
  }
}
