#let manifest = json("generated/manifest.json")
#let kt-root-id = sys.inputs.at("kt-note-id", default: none)

// --- Registry ---
#let kt-registry = state("kt-registry", (:))
// Forward links: id -> (target1, target2, ...)
#let kt-links = state("kt-links", (:))
#let kt-max-depth = 5

#let note-url(id) = id + ".html"

#let notelink(id, text: none) = {
  let label = if text == none { id } else { text }
  link(note-url(id))[#label]
}

// Paste registered content by ID, with depth limiting
#let transclude(id, mode: "inline", depth: kt-max-depth) = {
  if mode == "open" {
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
          #{ let body-fn = reg.at(id); body-fn((target, ..args) => transclude(target, depth: depth - 1, ..args)) }
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
          #{ let body-fn = reg.at(id); body-fn((target, ..args) => transclude(target, depth: depth - 1, ..args)) }
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
  context {
    let links = kt-links.get()
    // Invert: find all source ids whose link list contains id
    let bl = links.pairs().filter(pair => id in pair.last()).map(pair => pair.first())
    if bl.len() > 0 {
      html.elem("kt-backlinks")[
        #html.elem("kt-backlinks-header")[Backlinks]
        #html.elem("kt-backlinks-list")[
          #for source in bl {
            html.elem("kt-backlink-item")[
              #notelink(source)
            ]
          }
        ]
      ]
    }
  }
}

// Register a note's body closure and scan for links
#let kt-note(id: "", title: "", tags: (), body) = {
  kt-registry.update(r => {
    r.insert(id, body)
    r
  })
  // Scan body for outgoing links
  {
    let scan-transclude = (target, ..args) => {
      kt-links.update(m => {
        let existing = m.at(id, default: ())
        if target not in existing { existing.push(target) }
        m.insert(id, existing)
        m
      })
    }
    html.elem("template", attrs: (data-kt-scan: "true"))[
      #body(scan-transclude)
    ]
  }
  // If this note is the root (being compiled directly), render it
  if id == kt-root-id {
    // Include all other notes to populate registry
    for entry in manifest {
      if entry.id != id {
        include entry.source
      }
    }
    // Render page
    html.elem("link", attrs: (rel: "stylesheet", href: "site.css"))
    html.elem("kt-page", attrs: (data-note-id: id))[
      #html.elem("kt-article-header")[
        #html.elem("kt-article-title")[#title]
      ]
      #{ body((target, ..args) => transclude(target, ..args)) }
      #kt-backlinks(id)
    ]
  }
}
