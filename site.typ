#import "generated/manifest.typ": notes
#import "generated/transclusions.typ": transclusion-content

#let note-meta(id: "", title: "", tags: ()) = none

#let note-record(id) = if id in notes { notes.at(id) } else { none }

#let note-title(id) = {
  let entry = note-record(id)
  if entry == none { id } else { entry.title }
}

#let note-url(id) = id + ".html"

#let notelink(id, text: none) = {
  let label = if text == none { note-title(id) } else { text }
  link(note-url(id))[#label]
}

#let transclude(id, mode: "inline") = {
  let title = note-title(id)
  if mode == "inline" {
    transclusion-content(id)
  } else if mode == "open" {
    notelink(id, text: "Open: " + title)
  } else if mode == "title-open" {
    notelink(id, text: title)
  } else if mode == "title-inline" {
    [
      *#title*
      #transclusion-content(id)
    ]
  } else {
    [Unknown transclusion mode '#mode' for #id]
  }
}

#let render-page(id, body) = {
  let entry = note-record(id)
  if entry == none {
    panic("Unknown note id: " + id)
  }

  set page(width: auto, height: auto, margin: (x: 24pt, y: 24pt))

  [
    = #entry.title
    #body

    #if entry.backlinks.len() > 0 [
      == Backlinks
      #for source in entry.backlinks [
        - #notelink(source)
      ]
    ]
  ]
}
