#note-meta(id: "design-choices", title: "Design Choices", tags: ("planning", "design"))

- Rust CLI orchestrates graph + render steps.
- Notes are authored in Typst with `#note-meta`, `#notelink`, and `#transclude`.
- Graph data is generated into `generated/manifest.typ`.
- Per-note entrypoint files are generated in `generated/pages/`.
- Render phase compiles HTML with Typst and post-processes output to semantic custom elements:
  - `kt-page`, `kt-article-header`, `kt-article-title`
  - `kt-transclusion-inline`, `kt-transclusion-open`, `kt-transclusion-title-open`, `kt-transclusion-title-inline`
  - `kt-backlinks`, `kt-backlinks-header`, `kt-backlinks-list`, `kt-backlink-item`
