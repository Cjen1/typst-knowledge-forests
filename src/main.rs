use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use indicatif::{ProgressBar, ProgressStyle};
use regex::Regex;
use walkdir::WalkDir;

#[derive(Parser, Debug)]
#[command(author, version, about = "Build Forester-style Typst knowledge trees")]
struct Cli {
    /// Directory containing note .typ files.
    #[arg(long, default_value = "notes")]
    input_dir: PathBuf,
    /// Directory where compiled HTML files are written.
    #[arg(long, default_value = "dist")]
    output_dir: PathBuf,
    /// Directory for generated Typst artifacts.
    #[arg(long, default_value = "generated")]
    generated_dir: PathBuf,
    /// Typst executable to invoke.
    #[arg(long, default_value = "typst")]
    typst_bin: String,
    #[command(subcommand)]
    command: Option<StepCommand>,
}

#[derive(Subcommand, Debug, Clone, Copy)]
enum StepCommand {
    /// Run graph generation + rendering.
    Build,
    /// Only generate graph and Typst artifacts.
    Graph,
    /// Only render HTML from generated artifacts.
    Render,
}

#[derive(Debug, Clone)]
struct Note {
    id: String,
    title: String,
    tags: Vec<String>,
    links: Vec<String>,
    file_name: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let command = cli.command.unwrap_or(StepCommand::Build);

    match command {
        StepCommand::Build => {
            run_graph(&cli)?;
            run_render(&cli)?;
        }
        StepCommand::Graph => run_graph(&cli)?,
        StepCommand::Render => run_render(&cli)?,
    }

    Ok(())
}

fn run_graph(cli: &Cli) -> Result<()> {
    fs::create_dir_all(&cli.generated_dir)
        .with_context(|| format!("creating {}", cli.generated_dir.display()))?;
    fs::create_dir_all(cli.generated_dir.join("pages"))
        .with_context(|| format!("creating {}", cli.generated_dir.join("pages").display()))?;

    let parse_spinner = spinner("Parsing notes");
    let notes = load_notes(&cli.input_dir)?;
    parse_spinner.finish_with_message(format!("Parsed {} notes", notes.len()));

    let graph_spinner = spinner("Building backlink graph");
    let graph = build_graph(&notes)?;
    graph_spinner.finish_with_message("Backlink graph complete");

    let artifact_spinner = spinner("Generating Typst artifacts");
    write_manifest(&cli.generated_dir, &graph)?;
    write_transclusions(&cli.generated_dir, &cli.input_dir, &notes)?;
    write_page_entrypoints(&cli.generated_dir, &cli.input_dir, &notes)?;
    artifact_spinner.finish_with_message("Generated manifest + pages");

    Ok(())
}

fn run_render(cli: &Cli) -> Result<()> {
    let pages_dir = cli.generated_dir.join("pages");
    if !pages_dir.exists() {
        bail!(
            "missing generated pages at {} (run graph step first)",
            pages_dir.display()
        );
    }

    fs::create_dir_all(&cli.output_dir)
        .with_context(|| format!("creating {}", cli.output_dir.display()))?;

    let mut pages: Vec<PathBuf> = WalkDir::new(&pages_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
        .map(|e| e.into_path())
        .filter(|p| p.extension().and_then(|s| s.to_str()) == Some("typ"))
        .collect();
    pages.sort();

    if pages.is_empty() {
        bail!("no generated pages found in {}", pages_dir.display());
    }

    let progress = ProgressBar::new(pages.len() as u64);
    progress.set_style(progress_style(
        "[{elapsed_precise}] {bar:40.cyan/blue} {pos}/{len} {msg}",
    ));

    for page in pages {
        let stem = page
            .file_stem()
            .and_then(|s| s.to_str())
            .context("invalid UTF-8 page filename")?;
        let output = cli.output_dir.join(format!("{stem}.html"));

        let status = Command::new(&cli.typst_bin)
            .arg("compile")
            .arg("--root")
            .arg(".")
            .arg("--features")
            .arg("html")
            .arg("--format")
            .arg("html")
            .arg(&page)
            .arg(&output)
            .status()
            .with_context(|| format!("failed to run {}", cli.typst_bin))?;

        if !status.success() {
            bail!("typst compile failed for {}", page.display());
        }
        progress.set_message(stem.to_owned());
        progress.inc(1);
    }
    progress.finish_with_message("Rendered HTML pages");

    let css_source = Path::new("site.css");
    if css_source.exists() {
        fs::copy(css_source, cli.output_dir.join("site.css"))
            .with_context(|| format!("copying {}", css_source.display()))?;
    }

    Ok(())
}

fn load_notes(input_dir: &Path) -> Result<Vec<Note>> {
    if !input_dir.exists() {
        bail!("input directory {} does not exist", input_dir.display());
    }

    let meta_re = Regex::new(
        r#"(?s)#note-meta\(\s*id:\s*"([^"]+)"\s*,\s*title:\s*"([^"]+)"(?:\s*,\s*tags:\s*\((.*?)\))?\s*\)"#,
    )?;
    let link_re = Regex::new(r#"#(?:notelink|transclude)\(\s*"([^"]+)""#)?;
    let tag_re = Regex::new(r#""([^"]+)""#)?;

    let mut notes = Vec::new();
    for entry in WalkDir::new(input_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("typ") {
            continue;
        }

        let source =
            fs::read_to_string(path).with_context(|| format!("reading {}", path.display()))?;

        // Ensure the file parses as Typst syntax (Typst parser integration requirement).
        let _parsed = typst_syntax::parse(&source);

        let meta = meta_re
            .captures(&source)
            .with_context(|| format!("missing #note-meta(...) in {}", path.display()))?;

        let id = meta.get(1).map(|m| m.as_str()).unwrap_or_default().to_string();
        let title = meta
            .get(2)
            .map(|m| m.as_str())
            .unwrap_or_default()
            .to_string();
        let raw_tags = meta.get(3).map(|m| m.as_str()).unwrap_or("");
        let tags = tag_re
            .captures_iter(raw_tags)
            .filter_map(|c| c.get(1).map(|m| m.as_str().to_string()))
            .collect::<Vec<_>>();

        let mut links = BTreeSet::new();
        for captures in link_re.captures_iter(&source) {
            if let Some(target) = captures.get(1) {
                links.insert(target.as_str().to_string());
            }
        }

        let file_name = path
            .file_name()
            .and_then(|s| s.to_str())
            .context("invalid UTF-8 file name")?
            .to_string();

        notes.push(Note {
            id,
            title,
            tags,
            links: links.into_iter().collect(),
            file_name,
        });
    }

    notes.sort_by(|a, b| a.id.cmp(&b.id));
    if notes.is_empty() {
        bail!("no .typ notes found in {}", input_dir.display());
    }

    let mut seen = BTreeSet::new();
    for note in &notes {
        if !seen.insert(note.id.clone()) {
            bail!("duplicate note id {}", note.id);
        }
    }

    Ok(notes)
}

fn build_graph(notes: &[Note]) -> Result<BTreeMap<String, NoteRecord>> {
    let ids: BTreeSet<String> = notes.iter().map(|n| n.id.clone()).collect();
    let mut records = BTreeMap::new();

    for note in notes {
        records.insert(
            note.id.clone(),
            NoteRecord {
                id: note.id.clone(),
                title: note.title.clone(),
                tags: note.tags.clone(),
                links: note.links.clone(),
                backlinks: Vec::new(),
                source: format!("notes/{}", note.file_name),
                file_name: note.file_name.clone(),
            },
        );
    }

    for note in notes {
        for target in &note.links {
            if ids.contains(target) {
                if let Some(target_record) = records.get_mut(target) {
                    target_record.backlinks.push(note.id.clone());
                }
            } else {
                eprintln!("warning: '{}' links to missing note '{}'", note.id, target);
            }
        }
    }

    for record in records.values_mut() {
        record.backlinks.sort();
        record.backlinks.dedup();
    }

    Ok(records)
}

#[derive(Debug, Clone)]
struct NoteRecord {
    id: String,
    title: String,
    tags: Vec<String>,
    links: Vec<String>,
    backlinks: Vec<String>,
    source: String,
    file_name: String,
}

fn write_manifest(generated_dir: &Path, records: &BTreeMap<String, NoteRecord>) -> Result<()> {
    let mut out = String::from("#let notes = (\n");
    for (id, record) in records {
        out.push_str(&format!("  {}: (\n", typ_string(id)));
        out.push_str(&format!("    id: {},\n", typ_string(&record.id)));
        out.push_str(&format!("    title: {},\n", typ_string(&record.title)));
        out.push_str(&format!("    tags: {},\n", typ_tuple(&record.tags)));
        out.push_str(&format!("    links: {},\n", typ_tuple(&record.links)));
        out.push_str(&format!(
            "    backlinks: {},\n",
            typ_tuple(&record.backlinks)
        ));
        out.push_str(&format!("    source: {},\n", typ_string(&record.source)));
        out.push_str("  ),\n");
    }
    out.push_str(")\n");
    fs::write(generated_dir.join("manifest.typ"), out)
        .with_context(|| format!("writing {}", generated_dir.join("manifest.typ").display()))?;
    Ok(())
}

fn write_transclusions(generated_dir: &Path, input_dir: &Path, notes: &[Note]) -> Result<()> {
    let mut out = String::from(
        "#let notelink(id, text: none) = {\n  let label = if text == none { id } else { text }\n  link(id + \".html\")[#label]\n}\n#let transclude(id, mode: \"inline\") = notelink(id)\n#let transclusion-content(id) = {\n",
    );

    for (idx, note) in notes.iter().enumerate() {
        let keyword = if idx == 0 { "if" } else { "else if" };
        let source = fs::read_to_string(input_dir.join(&note.file_name))
            .with_context(|| format!("reading {}", input_dir.join(&note.file_name).display()))?;
        let source = strip_note_meta(&source);
        out.push_str(&format!("  {} id == {} {{\n", keyword, typ_string(&note.id)));
        out.push_str("    [\n");
        out.push_str(&source);
        if !source.ends_with('\n') {
            out.push('\n');
        }
        out.push_str("    ]\n");
        out.push_str("  }\n");
    }

    out.push_str("  else {\n");
    out.push_str("    [Unknown transclusion target: #id]\n");
    out.push_str("  }\n");
    out.push_str("}\n");

    fs::write(generated_dir.join("transclusions.typ"), out).with_context(|| {
        format!(
            "writing {}",
            generated_dir.join("transclusions.typ").display()
        )
    })?;
    Ok(())
}

fn write_page_entrypoints(generated_dir: &Path, input_dir: &Path, notes: &[Note]) -> Result<()> {
    let pages_dir = generated_dir.join("pages");
    for entry in WalkDir::new(&pages_dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        if entry.path().extension().and_then(|s| s.to_str()) == Some("typ") {
            fs::remove_file(entry.path())
                .with_context(|| format!("removing {}", entry.path().display()))?;
        }
    }

    for note in notes {
        let note_source = fs::read_to_string(input_dir.join(&note.file_name))
            .with_context(|| format!("reading {}", input_dir.join(&note.file_name).display()))?;
        let note_source = strip_note_meta(&note_source);
        let mut page = String::new();
        page.push_str("#import \"../../site.typ\": *\n");
        page.push_str(&format!("#render-page({})[\n", typ_string(&note.id)));
        page.push_str(&note_source);
        if !note_source.ends_with('\n') {
            page.push('\n');
        }
        page.push_str("]\n");

        fs::write(pages_dir.join(format!("{}.typ", note.id)), page).with_context(|| {
            format!(
                "writing {}",
                pages_dir.join(format!("{}.typ", note.id)).display()
            )
        })?;
    }
    Ok(())
}

fn typ_string(value: &str) -> String {
    let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

fn typ_tuple(values: &[String]) -> String {
    if values.is_empty() {
        return "()".to_string();
    }
    let items = values
        .iter()
        .map(|v| typ_string(v))
        .collect::<Vec<_>>()
        .join(", ");
    format!("({items},)")
}

fn strip_note_meta(source: &str) -> String {
    let mut lines = source.lines();
    match lines.next() {
        Some(first) if first.trim_start().starts_with("#note-meta(") => lines.collect::<Vec<_>>().join("\n"),
        Some(_) => source.to_string(),
        None => String::new(),
    }
}

fn spinner(message: &str) -> ProgressBar {
    let pb = ProgressBar::new_spinner();
    pb.set_style(progress_style("{spinner:.green} {msg}"));
    pb.set_message(message.to_string());
    pb.enable_steady_tick(std::time::Duration::from_millis(80));
    pb
}

fn progress_style(template: &str) -> ProgressStyle {
    ProgressStyle::with_template(template).unwrap_or_else(|_| ProgressStyle::default_bar())
}
