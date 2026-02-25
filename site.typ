#let manifest = json("generated/manifest.json")
#let kt-mode = sys.inputs.at("kt-mode", default: "render")
#let kt-query-mode = kt-mode == "query"
#let kt-root-id = sys.inputs.at("kt-note-id", default: none)

// --- Runtime state ---
#let kt-registry = state("kt-registry", (:))
#let kt-current-source = state("kt-current-source", "")
#let kt-max-depth = 5

// Query output from `typst query generated/query.typ "<kt-meta>"`
#let kt-metadata = if kt-query-mode { () } else { json("generated/metadata.json") }
#let kt-manifest = if kt-query-mode { () } else { manifest }

#let note-url(id) = id + ".html"

// Generic metadata marker for future extensibility.
#let kt-meta(kind, data) = [#metadata((schema: "kt-meta-v1", kind: kind, data: data))<kt-meta>]

#let kt-edge(from, to, relation, mode: none) = {
  kt-meta("edge", (from: from, to: to, relation: relation, mode: mode))
}

#let notelink(id, text: none) = {
  let label = if text == none { id } else { text }
  if kt-query-mode {
    context {
      let source = kt-current-source.get()
      if source == "" { [] } else { kt-edge(source, id, "notelink") }
    }
  } else {
    link(note-url(id))[#label]
  }
}

// Paste registered content by ID, with depth limiting.
#let transclude(id, mode: "inline", depth: kt-max-depth) = {
  if kt-query-mode {
    context {
      let source = kt-current-source.get()
      if source == "" { [] } else { kt-edge(source, id, "transclude", mode: mode) }
    }
  } else if mode == "open" {
    html.elem("kt-transclusion-open")[
      #notelink(id, text: "Open: " + id)
    ]
  } else if mode == "title-open" {
    html.elem("kt-transclusion-title-open")[
      #notelink(id)
    ]
  } else if depth <= 0 {
    notelink(id)
  } else if mode == "inline" {
    context {
      let reg = kt-registry.get()
      if id in reg {
        html.elem("kt-transclusion-inline")[
          #{
            let body-fn = reg.at(id)
            body-fn((
              transclude: (target, ..args) => transclude(target, depth: depth - 1, ..args),
              metadata: kt-metadata,
              manifest: kt-manifest,
            ))
          }
        ]
      } else {
        notelink(id)
      }
    }
  } else if mode == "title-inline" {
    context {
      let reg = kt-registry.get()
      if id in reg {
        html.elem("kt-transclusion-title-inline")[
          #{
            let body-fn = reg.at(id)
            body-fn((
              transclude: (target, ..args) => transclude(target, depth: depth - 1, ..args),
              metadata: kt-metadata,
              manifest: kt-manifest,
            ))
          }
        ]
      } else {
        notelink(id)
      }
    }
  } else {
    [Unknown transclusion mode '#mode' for #id]
  }
}

#let kt-backlinks(id) = {
  if kt-query-mode {
    []
  } else {
    let edges = kt-metadata.filter(entry =>
      entry.func == "metadata" and
      entry.value.schema == "kt-meta-v1" and
      entry.value.kind == "edge" and
      entry.value.data.to == id
    )
    let backlink-map = edges.fold((:), (acc, entry) => {
      let source = entry.value.data.from
      acc.insert(source, true)
      acc
    })
    let backlinks = backlink-map.pairs().map(pair => pair.first())
    if backlinks.len() > 0 {
      html.elem("kt-backlinks")[
        #html.elem("kt-backlinks-header")[Backlinks]
        #html.elem("kt-backlinks-list")[
          #for source in backlinks {
            html.elem("kt-backlink-item")[
              #notelink(source)
            ]
          }
        ]
      ]
    }
  }
}

// Register a note's body closure into the runtime registry.
#let kt-note(id: "", title: "", tags: (), author: "", date: "", body) = {
  kt-registry.update(r => {
    r.insert(id, body)
    r
  })

  if kt-query-mode {
    kt-meta("note", (id: id, title: title, tags: tags, author: author, date: date))
    for tag in tags {
      kt-meta("tag", (id: id, title: title, tag: tag, author: author, date: date))
    }
    // Emit metadata markers from this note body for `typst query`.
    kt-current-source.update(_ => id)
    body((
      transclude: (target, ..args) => transclude(target, ..args),
      metadata: kt-metadata,
      manifest: kt-manifest,
    ))
    kt-current-source.update(_ => "")
  } else if id == kt-root-id {
    // Include all other notes to populate registry before rendering this root.
    for entry in manifest {
      if entry.id != id {
        include entry.source
      }
    }
    html.elem("link", attrs: (rel: "stylesheet", href: "site.css"))
    html.elem("kt-page", attrs: (data-note-id: id))[
      #html.elem("kt-article-header")[
        #html.elem("kt-article-title")[#title]
      ]
      #{
        body((
          transclude: (target, ..args) => transclude(target, ..args),
          metadata: kt-metadata,
          manifest: kt-manifest,
        ))
      }
      #kt-backlinks(id)
    ]
  }
}
