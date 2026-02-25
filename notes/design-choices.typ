#import "tkf.typ": *
#kt-note(id: "design-choices", title: "Design Choices", tags: ("planning", "design"), author: "cj", date: "2026-01-22", _ => [

- Rust CLI orchestrates graph + render steps.
- Notes are authored in Typst with `#kt-note`, `#notelink`, and `#transclude`.
- Graph data is generated into `generated/manifest.typ`.
- Notes are self-contained and import shared runtime from `tkf.typ`.
- Render phase compiles `notes/*.typ` directly to semantic custom elements:
  - `kt-page`, `kt-article-header`, `kt-article-title`
  - `kt-transclusion-inline`, `kt-transclusion-open`, `kt-transclusion-title-open`, `kt-transclusion-title-inline`
  - `kt-backlinks`, `kt-backlinks-header`, `kt-backlinks-list`, `kt-backlink-item`
])
