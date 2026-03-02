#import "tkf.typ": *
#kt-note(id: "metadata-demo.typ", title: "Metadata Demo", tags: ("demo", "metadata"), author: "cj", date: "2026-02-25", api => [
  #let notelink = api.notelink

  This page demonstrates userspace queries over `api.metadata` and `api.manifest`.

  #let note-meta = (
    api.metadata
      .filter(entry => entry.func == "metadata" and entry.value.schema == "kt-meta-v1" and entry.value.kind == "note")
      .map(entry => entry.value.data)
  )

  #let tag = "planning"
  #let tagged = (
    note-meta
      .filter(note => tag in note.at("tags", default: ()))
      .sorted(key: note => note.at("title", default: note.at("id", default: "")))
  )

  == Notes tagged "#tag"
  #if tagged.len() == 0 {
    [_No notes with this tag._]
  } else {
    [#for note in tagged {
      [- #notelink(note.at("id", default: ""), text: note.at("title", default: note.at("id", default: "")))]
    }]
  }

  #let author = "cj"
  #let authored = (
    note-meta
      .filter(note => note.at("author", default: "") == author and note.at("date", default: "") != "")
      .sorted(key: note => note.at("date", default: ""))
      .rev()
  )
  #let latest = if authored.len() <= 3 { authored } else { authored.slice(0, 3) }

  == 3 latest by #author
  #if latest.len() == 0 {
    [_No notes by this author._]
  } else {
    [#for note in latest {
      [- #notelink(
        note.at("id", default: ""),
        text: note.at("date", default: "") + " — " + note.at("title", default: note.at("id", default: ""))
      )]
    }]
  }

  == Corpus size from api.manifest
  #api.manifest.len() notes
])
