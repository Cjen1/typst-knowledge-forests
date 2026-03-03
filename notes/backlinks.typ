#import "tkf.typ": *
#tkf-note(id: "backlinks.typ", title: "Backlinks", tags: ("docs", "features"), author: "cj", date: "2026-02-01", _ => [

Each note automatically displays backlinks: a list of every other note that links to or transcludes it.

During the first pass, outgoing `#notelink` and `#transclude` references are extracted as graph edges into `generated/metadata.json`.
At render time, `#tkf-backlinks(id)` filters these edges for incoming references and renders them as a list of links at the bottom of each note.

This means backlinks are always up to date and require no manual maintenance.
])
