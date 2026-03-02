use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use indicatif::{ProgressBar, ProgressStyle};
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

#[derive(Subcommand, Debug, Clone)]
enum StepCommand {
    /// Run manifest generation + rendering.
    Build,
    /// Only generate manifest.
    Graph,
    /// Only render HTML from existing manifest.
    Render,
    /// Create a new note file.
    New {
        /// Title for the new note.
        title: String,
        /// Directory to create the note in (defaults to --input-dir).
        #[arg(long)]
        dir: Option<PathBuf>,
        /// Don't open $EDITOR after creating the note.
        #[arg(long)]
        no_edit: bool,
    },
}

#[derive(Debug, Clone)]
struct NoteEntry {
    id: String,
    file_name: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let command = cli.command.clone().unwrap_or(StepCommand::Build);

    match command {
        StepCommand::New { title, dir, no_edit } => {
            let target_dir = dir.unwrap_or_else(|| cli.input_dir.clone());
            run_new(&title, &target_dir, &cli.input_dir, no_edit)?;
        }
        _ => {
            let tkf_path = cli.input_dir.join("tkf.typ");
            if !tkf_path.exists() {
                bail!(
                    "missing tkf.typ in {} — copy it from the typst-knowledge-forests repo",
                    cli.input_dir.display()
                );
            }

            match command {
                StepCommand::Build => {
                    run_graph(&cli)?;
                    run_render(&cli)?;
                }
                StepCommand::Graph => run_graph(&cli)?,
                StepCommand::Render => run_render(&cli)?,
                StepCommand::New { .. } => unreachable!(),
            }
        }
    }

    Ok(())
}

fn run_new(title: &str, dir: &Path, input_dir: &Path, no_edit: bool) -> Result<()> {
    fs::create_dir_all(dir)
        .with_context(|| format!("creating {}", dir.display()))?;

    let tkf_import = find_tkf_import(dir, input_dir)?;

    let today = {
        use std::time::{SystemTime, UNIX_EPOCH};
        let secs = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let days = secs / 86400;
        // Convert days since epoch to yyyy-mm-dd
        let mut y = 1970i32;
        let mut rem = days as i32;
        loop {
            let year_days = if y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) { 366 } else { 365 };
            if rem < year_days { break; }
            rem -= year_days;
            y += 1;
        }
        let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
        let month_days = [31, if leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        let mut m = 0usize;
        while m < 12 && rem >= month_days[m] {
            rem -= month_days[m];
            m += 1;
        }
        format!("{:04}-{:02}-{:02}", y, m + 1, rem + 1)
    };

    let slug: String = title
        .to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-");

    let id = format!("{today}-{slug}");
    let file_name = format!("{id}.typ");
    let file_path = dir.join(&file_name);

    if file_path.exists() {
        bail!("{} already exists", file_path.display());
    }

    let note_id = file_path
        .strip_prefix(input_dir)
        .unwrap_or(&file_path)
        .to_str()
        .context("invalid UTF-8 path")?
        .to_string();

    let content = format!(
        "#import \"{tkf_import}\": *\n#kt-note(id: \"{id}\", title: \"{title}\", tags: (), author: \"\", date: \"{today}\", api => [\n#let transclude = api.transclude\n#let notelink = api.notelink\n\n])\n",
        tkf_import = tkf_import,
        id = note_id,
        title = title,
        today = today,
    );

    fs::write(&file_path, content)
        .with_context(|| format!("writing {}", file_path.display()))?;

    println!("Created {}", file_path.display());

    if !no_edit {
        if let Ok(editor) = std::env::var("EDITOR") {
            Command::new(&editor)
                .arg(&file_path)
                .status()
                .with_context(|| format!("failed to open {} with {}", file_path.display(), editor))?;
        }
    }

    Ok(())
}

/// Walk upward from `target_dir` to `root` looking for `tkf.typ`.
/// Returns the relative import path (e.g. "../../tkf.typ" or "tkf.typ").
fn find_tkf_import(target_dir: &Path, root: &Path) -> Result<String> {
    let target_abs = fs::canonicalize(target_dir)
        .with_context(|| format!("canonicalizing {}", target_dir.display()))?;
    let root_abs = fs::canonicalize(root)
        .with_context(|| format!("canonicalizing {}", root.display()))?;

    let mut cur = target_abs.as_path();
    loop {
        let candidate = cur.join("tkf.typ");
        if candidate.exists() {
            let depth = target_abs
                .strip_prefix(cur)
                .context("target not under tkf.typ directory")?
                .components()
                .count();
            if depth == 0 {
                return Ok("tkf.typ".to_string());
            }
            let prefix: String = std::iter::repeat_n("..", depth).collect::<Vec<_>>().join("/");
            return Ok(format!("{prefix}/tkf.typ"));
        }
        if cur == root_abs {
            break;
        }
        cur = cur
            .parent()
            .context("reached filesystem root without finding tkf.typ")?;
    }

    bail!(
        "tkf.typ not found between {} and {}",
        target_dir.display(),
        root.display()
    );
}

fn run_graph(cli: &Cli) -> Result<()> {
    fs::create_dir_all(&cli.generated_dir)
        .with_context(|| format!("creating {}", cli.generated_dir.display()))?;

    let scan_spinner = spinner("Scanning notes");
    let notes = discover_notes(&cli.input_dir)?;
    scan_spinner.finish_with_message(format!("Found {} notes", notes.len()));

    let artifact_spinner = spinner("Writing manifest and query input");
    write_manifest_json(&cli.generated_dir, &cli.input_dir, &notes)?;
    write_query_typ(&cli.generated_dir, &cli.input_dir, &notes)?;
    artifact_spinner.finish_with_message("Generated manifest.json and query.typ");

    let query_spinner = spinner("Extracting metadata");
    write_metadata_json(cli, &cli.generated_dir)?;
    query_spinner.finish_with_message("Generated metadata.json");

    Ok(())
}

fn run_render(cli: &Cli) -> Result<()> {
    if !cli.generated_dir.join("manifest.json").exists() {
        bail!(
            "missing manifest.json in {} (run graph step first)",
            cli.generated_dir.display()
        );
    }
    if !cli.generated_dir.join("metadata.json").exists() {
        bail!(
            "missing metadata.json in {} (run graph step first)",
            cli.generated_dir.display()
        );
    }

    fs::create_dir_all(&cli.output_dir)
        .with_context(|| format!("creating {}", cli.output_dir.display()))?;

    let notes = discover_notes(&cli.input_dir)?;
    let progress = ProgressBar::new(notes.len() as u64);
    progress.set_style(progress_style(
        "[{elapsed_precise}] {bar:40.cyan/blue} {pos}/{len} {msg}",
    ));

    for note in &notes {
        let source = cli.input_dir.join(&note.file_name);
        // Derive output path: notes/foo.typ -> foo.html
        let html_name = note.file_name.strip_suffix(".typ").unwrap_or(&note.file_name);
        let output = cli.output_dir.join(format!("{}.html", html_name));
        if let Some(parent) = output.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("creating {}", parent.display()))?;
        }

        let status = Command::new(&cli.typst_bin)
            .arg("compile")
            .arg("--root")
            .arg(".")
            .arg("--features")
            .arg("html")
            .arg("--format")
            .arg("html")
            .arg("--input")
            .arg("kt-mode=render")
            .arg("--input")
            .arg(format!("kt-note-id={}", note.id))
            .arg(&source)
            .arg(&output)
            .status()
            .with_context(|| format!("failed to run {}", cli.typst_bin))?;

        if !status.success() {
            bail!("typst compile failed for {}", source.display());
        }
        progress.set_message(note.id.clone());
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

fn discover_notes(input_dir: &Path) -> Result<Vec<NoteEntry>> {
    if !input_dir.exists() {
        bail!("input directory {} does not exist", input_dir.display());
    }

    let mut notes = Vec::new();
    for entry in WalkDir::new(input_dir)
        .min_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("typ") {
            continue;
        }
        if path.file_name().and_then(|s| s.to_str()) == Some("tkf.typ") {
            continue;
        }

        let file_name = path
            .strip_prefix(input_dir)
            .context("path not under input dir")?
            .to_str()
            .context("invalid UTF-8 path")?
            .to_string();

        let id = file_name.clone();

        notes.push(NoteEntry { id, file_name });
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

fn write_manifest_json(
    generated_dir: &Path,
    _input_dir: &Path,
    notes: &[NoteEntry],
) -> Result<()> {
    let entries: Vec<String> = notes
        .iter()
        .map(|n| {
            format!(
                "  {{\"id\": {}, \"source\": {}}}",
                json_string(&n.id),
                json_string(&n.file_name)
            )
        })
        .collect();
    let out = format!("[\n{}\n]\n", entries.join(",\n"));
    fs::write(generated_dir.join("manifest.json"), out)
        .with_context(|| format!("writing manifest.json"))?;
    Ok(())
}

fn write_query_typ(generated_dir: &Path, input_dir: &Path, notes: &[NoteEntry]) -> Result<()> {
    let mut out = String::new();
    for note in notes {
        let source = input_dir.join(&note.file_name);
        out.push_str(&format!("#include \"../{}\"\n", source.display()));
    }
    fs::write(generated_dir.join("query.typ"), out).with_context(|| format!("writing query.typ"))?;
    Ok(())
}

fn write_metadata_json(cli: &Cli, generated_dir: &Path) -> Result<()> {
    let query_file = generated_dir.join("query.typ");
    let output = Command::new(&cli.typst_bin)
        .arg("query")
        .arg("--features")
        .arg("html")
        .arg("--root")
        .arg(".")
        .arg("--target")
        .arg("html")
        .arg("--format")
        .arg("json")
        .arg("--pretty")
        .arg("--input")
        .arg("kt-mode=query")
        .arg(&query_file)
        .arg("<kt-meta>")
        .output()
        .with_context(|| format!("failed to run {}", cli.typst_bin))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("typst query failed for {}: {stderr}", query_file.display());
    }

    fs::write(generated_dir.join("metadata.json"), output.stdout)
        .with_context(|| format!("writing metadata.json"))?;
    Ok(())
}

fn json_string(value: &str) -> String {
    let escaped = value.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
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
