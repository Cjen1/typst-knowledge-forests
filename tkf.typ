// tkf.typ — Typst Knowledge Forests runtime library.
// Copy this file into your notes directory and #import "tkf.typ": *
//
// Public API:
//   #tkf-note(id, title, tags, author, date, body)    — Define a note (id auto-set by CLI)
//   #notelink("../foo.typ", text: none)               — Link to another note (relative path)
//   #transclude("../foo.typ", mode: "inline")         — Embed another note's content (relative path)
//     modes:
//       "inline"       — Expand the note body in place (recursive, depth-limited)
//       "title-link"   — Only writes the title of the linked article
//   #tkf-backlinks(id)                                 — Render backlinks for a note (auto-called)
//
// The CLI (tkf) handles build orchestration; this file is the Typst-side runtime.
// Paths in transclude/notelink are relative to the calling note's directory.

#let manifest = json("../generated/manifest.json")
#let tkf-mode = sys.inputs.at("tkf-mode", default: "render")
#let tkf-query-mode = tkf-mode == "query"
#let tkf-root-id = sys.inputs.at("tkf-note-id", default: none)

// --- Runtime state ---
#let tkf-registry = state("tkf-registry", (:))
#let tkf-current-source = state("tkf-current-source", "")
#let tkf-max-depth = 5

#let tkf-metadata = if tkf-query-mode { () } else { json("../generated/metadata.json") }
#let tkf-manifest = if tkf-query-mode { () } else { manifest }

// Resolve a relative path against a base directory.
// base-dir: "sub/" or "" (for root-level notes)
// relative: "../foo.typ" or "bar.typ" or "sub/baz.typ"
// Returns canonical ID: "foo.typ", "sub/baz.typ", etc.
#let resolve-path(base-dir, relative) = {
  let parts = if base-dir == "" { () } else {
    base-dir.trim("/", at: end).split("/")
  }
  let rel-parts = relative.split("/")
  let result = parts
  for seg in rel-parts {
    if seg == ".." {
      if result.len() > 0 {
        result = result.slice(0, -1)
      }
    } else if seg != "." and seg != "" {
      result = (..result, seg)
    }
  }
  result.join("/")
}

// Extract directory from a note ID: "sub/foo.typ" → "sub/", "foo.typ" → ""
#let note-dir(id) = {
  let parts = id.split("/")
  if parts.len() <= 1 { "" } else { parts.slice(0, -1).join("/") + "/" }
}

#let note-url(id) = {
  let without-ext = id.trim(".typ", at: end)
  "/" + without-ext + ".html"
}

#let tkf-meta(kind, data) = [#metadata((schema: "tkf-meta-v1", kind: kind, data: data))<tkf-meta>]

#let tkf-edge(from, to, relation, mode: none) = {
  tkf-meta("edge", (from: from, to: to, relation: relation, mode: mode))
}

// Internal notelink that takes a canonical (resolved) ID.
#let tkf-notelink-canonical(id, text: none) = {
  let label = if text == none { id } else { text }
  if tkf-query-mode {
    context {
      let source = tkf-current-source.get()
      if source == "" { [] } else { tkf-edge(source, id, "notelink") }
    }
  } else {
    link(note-url(id))[#label]
  }
}

// Internal transclude that takes a canonical (resolved) ID.
#let tkf-transclude-canonical(id, mode: "inline", depth: tkf-max-depth) = {
  if tkf-query-mode {
    context {
      let source = tkf-current-source.get()
      if source == "" { [] } else { tkf-edge(source, id, "transclude", mode: mode) }
    }
  } else {
    html.elem("tkf-transclusion")[
      #html.elem("tkf-transclusion-title-div")[
        #html.elem("tkf-transclusion-title")[
          #{
            let notes = tkf-metadata.filter(entry =>
              entry.func == "metadata" and
              entry.value.schema == "tkf-meta-v1" and
              entry.value.kind == "note" and
              entry.value.data.id == id
            )
            if notes.len() > 0 { notes.first().value.data.title } else { id }
          }
        ]
        #html.elem("tkf-transclusion-link")[#tkf-notelink-canonical(id)]
      ]
      #{
        if depth > 0 {
          if mode == "inline" {
            context {
              let reg = tkf-registry.get()
              if id in reg {
                html.elem("tkf-transclusion-inline")[
                  #{
                    let body-fn = reg.at(id)
                    let target-dir = note-dir(id)
                    body-fn((
                      transclude: (target, ..args) => tkf-transclude-canonical(resolve-path(target-dir, target), depth: depth - 1, ..args),
                      notelink: (target, ..args) => tkf-notelink-canonical(resolve-path(target-dir, target), ..args),
                      metadata: tkf-metadata,
                      manifest: tkf-manifest,
                    ))
                  }
                ]
              } else {
                [Unknown transclusion target: #id]
              }
            }
          }
        } else {
          tkf-notelink-canonical(id)
        }
      }
    ]
  }
}

#let tkf-backlinks(id) = {
  if tkf-query-mode {
    []
  } else {
    let edges = tkf-metadata.filter(entry =>
      entry.func == "metadata" and
      entry.value.schema == "tkf-meta-v1" and
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
      html.elem("tkf-backlinks")[
        #html.elem("tkf-backlinks-header")[Backlinks]
        #html.elem("tkf-backlinks-list")[
          #for source in backlinks {
            html.elem("tkf-backlink-item")[
              #tkf-notelink-canonical(source)
            ]
          }
        ]
      ]
    }
  }
}

// Register a note's body closure into the runtime registry.
// Paths in transclude/notelink are resolved relative to this note's directory.
#let tkf-note(id: "", title: "", tags: (), author: "", date: "", body) = {
  let dir = note-dir(id)

  tkf-registry.update(r => {
    r.insert(id, body)
    r
  })

  if tkf-query-mode {
    tkf-meta("note", (id: id, title: title, tags: tags, author: author, date: date))
    tkf-current-source.update(_ => id)
    body((
      transclude: (target, ..args) => tkf-transclude-canonical(resolve-path(dir, target), ..args),
      notelink: (target, ..args) => tkf-notelink-canonical(resolve-path(dir, target), ..args),
      metadata: tkf-metadata,
      manifest: tkf-manifest,
    ))
    tkf-current-source.update(_ => "")
  } else if id == tkf-root-id {
    for entry in manifest {
      if entry.id != id {
        include entry.source
      }
    }
    html.elem("link", attrs: (rel: "stylesheet", href: "/site.css"))
    html.elem("tkf-page", attrs: (data-note-id: id))[
      #html.elem("tkf-title-div")[
        #html.elem("tkf-note-title")[
          #title
        ]
        #html.elem("tkf-transclusion-link")[#tkf-notelink-canonical(id)]
      ]
      #{
        body((
          transclude: (target, ..args) => tkf-transclude-canonical(resolve-path(dir, target), ..args),
          notelink: (target, ..args) => tkf-notelink-canonical(resolve-path(dir, target), ..args),
          metadata: tkf-metadata,
          manifest: tkf-manifest,
        ))
      }
      #tkf-backlinks(id)
    ]
  }
}
