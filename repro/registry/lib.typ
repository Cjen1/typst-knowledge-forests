// Registry: maps note ID -> body function(transclude-fn)
#let kt-registry = state("kt-registry", (:))
#let kt-max-depth = 5

// Called by each note file to register its content
#let kt-note(id, body) = {
  kt-registry.update(r => {
    r.insert(id, body)
    r
  })
}

// Paste registered content by ID, with depth limiting
#let transclude(id, depth: kt-max-depth) = {
  if depth <= 0 {
    [→ #id]
  } else {
    context {
      let reg = kt-registry.get()
      if id in reg {
        let body-fn = reg.at(id)
        body-fn(target => transclude(target, depth: depth - 1))
      } else {
        [Missing: #id]
      }
    }
  }
}
