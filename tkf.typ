// tkf.typ — Typst Knowledge Forests runtime library.
// Copy this file into your notes directory and #import "tkf.typ": *
//
// Public API:
//   #kt-note(id, title, tags, author, date, body)    — Define a note (id auto-set by CLI)
//   #notelink("../foo.typ", text: none)               — Link to another note (relative path)
//   #transclude("../foo.typ", mode: "inline")         — Embed another note's content (relative path)
//     modes:
//       "inline"       — Expand the note body in place (recursive, depth-limited)
//       "title-link"   — Only writes the title of the linked article
//   #kt-backlinks(id)                                 — Render backlinks for a note (auto-called)
//
// The CLI (tkf) handles build orchestration; this file is the Typst-side runtime.
// Paths in transclude/notelink are relative to the calling note's directory.

#let manifest = json("../generated/manifest.json")
#let kt-mode = sys.inputs.at("kt-mode", default: "render")
#let kt-query-mode = kt-mode == "query"
#let kt-root-id = sys.inputs.at("kt-note-id", default: none)

// --- Runtime state ---
#let kt-registry = state("kt-registry", (:))
#let kt-current-source = state("kt-current-source", "")
#let kt-max-depth = 5

#let kt-metadata = if kt-query-mode { () } else { json("../generated/metadata.json") }
#let kt-manifest = if kt-query-mode { () } else { manifest }

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

#let kt-meta(kind, data) = [#metadata((schema: "kt-meta-v1", kind: kind, data: data))<kt-meta>]

#let kt-edge(from, to, relation, mode: none) = {
  kt-meta("edge", (from: from, to: to, relation: relation, mode: mode))
}

// Internal notelink that takes a canonical (resolved) ID.
#let kt-notelink-canonical(id, text: none) = {
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

// Internal transclude that takes a canonical (resolved) ID.
#let kt-transclude-canonical(id, mode: "inline", depth: kt-max-depth) = {
  if kt-query-mode {
    context {
      let source = kt-current-source.get()
      if source == "" { [] } else { kt-edge(source, id, "transclude", mode: mode) }
    }
  } else {
    html.elem("kt-transclusion")[
      #html.elem("kt-transclusion-title-div")[
        #html.elem("kt-transclusion-title")[
          #{
            let notes = kt-metadata.filter(entry =>
              entry.func == "metadata" and
              entry.value.schema == "kt-meta-v1" and
              entry.value.kind == "note" and
              entry.value.data.id == id
            )
            if notes.len() > 0 { notes.first().value.data.title } else { id }
          }
        ]
        #html.elem("kt-transclusion-link")[#kt-notelink-canonical(id)]
      ]
      #{
        if depth > 0 {
          if mode == "inline" {
            context {
              let reg = kt-registry.get()
              if id in reg {
                html.elem("kt-transclusion-inline")[
                  #{
                    let body-fn = reg.at(id)
                    let target-dir = note-dir(id)
                    body-fn((
                      transclude: (target, ..args) => kt-transclude-canonical(resolve-path(target-dir, target), depth: depth - 1, ..args),
                      notelink: (target, ..args) => kt-notelink-canonical(resolve-path(target-dir, target), ..args),
                      metadata: kt-metadata,
                      manifest: kt-manifest,
                    ))
                  }
                ]
              } else {
                [Unknown transclusion target: #id]
              }
            }
          }
        } else {
          kt-notelink-canonical(id)
        }
      }
    ]
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
              #kt-notelink-canonical(source)
            ]
          }
        ]
      ]
    }
  }
}

// Register a note's body closure into the runtime registry.
// Paths in transclude/notelink are resolved relative to this note's directory.
#let kt-note(id: "", title: "", tags: (), author: "", date: "", body) = {
  let dir = note-dir(id)

  kt-registry.update(r => {
    r.insert(id, body)
    r
  })

  if kt-query-mode {
    kt-meta("note", (id: id, title: title, tags: tags, author: author, date: date))
    kt-current-source.update(_ => id)
    body((
      transclude: (target, ..args) => kt-transclude-canonical(resolve-path(dir, target), ..args),
      notelink: (target, ..args) => kt-notelink-canonical(resolve-path(dir, target), ..args),
      metadata: kt-metadata,
      manifest: kt-manifest,
    ))
    kt-current-source.update(_ => "")
  } else if id == kt-root-id {
    for entry in manifest {
      if entry.id != id {
        include entry.source
      }
    }
    html.elem("link", attrs: (rel: "stylesheet", href: "/site.css"))
    html.elem("kt-page", attrs: (data-note-id: id))[
      #html.elem("kt-title-div")[
        #html.elem("kt-note-title")[
          #title
        ]
        #html.elem("kt-transclusion-link")[#kt-notelink-canonical(id)]
      ]
      #{
        body((
          transclude: (target, ..args) => kt-transclude-canonical(resolve-path(dir, target), ..args),
          notelink: (target, ..args) => kt-notelink-canonical(resolve-path(dir, target), ..args),
          metadata: kt-metadata,
          manifest: kt-manifest,
        ))
      }
      #kt-backlinks(id)
    ]
  }
}
