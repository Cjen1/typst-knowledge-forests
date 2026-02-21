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

#[derive(Subcommand, Debug, Clone, Copy)]
enum StepCommand {
    /// Run manifest generation + rendering.
    Build,
    /// Only generate manifest.
    Graph,
    /// Only render HTML from existing manifest.
    Render,
}

#[derive(Debug, Clone)]
struct NoteEntry {
    id: String,
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

    let scan_spinner = spinner("Scanning notes");
    let notes = discover_notes(&cli.input_dir)?;
    scan_spinner.finish_with_message(format!("Found {} notes", notes.len()));

    let artifact_spinner = spinner("Writing manifest");
    write_manifest_json(&cli.generated_dir, &cli.input_dir, &notes)?;
    artifact_spinner.finish_with_message("Generated manifest.json");

    Ok(())
}

fn run_render(cli: &Cli) -> Result<()> {
    if !cli.generated_dir.join("manifest.json").exists() {
        bail!(
            "missing manifest.json in {} (run graph step first)",
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
        let output = cli.output_dir.join(format!("{}.html", note.id));

        let status = Command::new(&cli.typst_bin)
            .arg("compile")
            .arg("--root")
            .arg(".")
            .arg("--features")
            .arg("html")
            .arg("--format")
            .arg("html")
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
        .max_depth(1)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("typ") {
            continue;
        }

        let file_name = path
            .file_name()
            .and_then(|s| s.to_str())
            .context("invalid UTF-8 file name")?
            .to_string();

        let id = path
            .file_stem()
            .and_then(|s| s.to_str())
            .context("invalid UTF-8 file stem")?
            .to_string();

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
    input_dir: &Path,
    notes: &[NoteEntry],
) -> Result<()> {
    let entries: Vec<String> = notes
        .iter()
        .map(|n| {
            let source = input_dir.join(&n.file_name);
            format!(
                "  {{\"id\": {}, \"source\": {}}}",
                json_string(&n.id),
                json_string(&source.display().to_string())
            )
        })
        .collect();
    let out = format!("[\n{}\n]\n", entries.join(",\n"));
    fs::write(generated_dir.join("manifest.json"), out)
        .with_context(|| format!("writing manifest.json"))?;
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
