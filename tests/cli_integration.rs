use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

fn temp_test_dir(name: &str) -> PathBuf {
    let mut dir = std::env::temp_dir();
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time")
        .as_nanos();
    dir.push(format!("typst-knowledge-trees-{name}-{}-{nanos}", std::process::id()));
    fs::create_dir_all(&dir).expect("create temp dir");
    dir
}

fn write_file(path: &Path, contents: &str) {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("create parent dir");
    }
    fs::write(path, contents).expect("write file");
}

#[test]
fn graph_generates_manifest_and_pages() {
    let dir = temp_test_dir("graph");
    let notes_dir = dir.join("notes");
    let generated_dir = dir.join("generated");

    write_file(
        &notes_dir.join("alpha.typ"),
        "#note-meta(id: \"alpha\", title: \"Alpha\", tags: (\"a\",))\n#notelink(\"beta\")\nAlpha body.\n",
    );
    write_file(
        &notes_dir.join("beta.typ"),
        "#note-meta(id: \"beta\", title: \"Beta\", tags: (\"b\",))\nBeta body.\n",
    );

    let status = Command::new(env!("CARGO_BIN_EXE_typst-knowledge-trees"))
        .current_dir(&dir)
        .arg("--input-dir")
        .arg("notes")
        .arg("--generated-dir")
        .arg("generated")
        .arg("graph")
        .status()
        .expect("run graph");
    assert!(status.success());

    let manifest = fs::read_to_string(generated_dir.join("manifest.typ")).expect("read manifest");
    assert!(manifest.contains("alpha"));
    assert!(manifest.contains("beta"));
    assert!(manifest.contains("backlinks: (\"alpha\",)"));

    assert!(generated_dir.join("pages/alpha.typ").exists());
    assert!(generated_dir.join("pages/beta.typ").exists());

    fs::remove_dir_all(dir).expect("cleanup temp dir");
}

#[test]
fn build_uses_typst_binary_and_writes_output_html() {
    let dir = temp_test_dir("build");
    let notes_dir = dir.join("notes");
    let dist_dir = dir.join("dist");
    let generated_dir = dir.join("generated");
    let fake_typst = dir.join("fake-typst.sh");
    let log_path = dir.join("typst-invocations.log");

    write_file(
        &notes_dir.join("alpha.typ"),
        "#note-meta(id: \"alpha\", title: \"Alpha\", tags: (\"a\",))\nAlpha body.\n",
    );
    write_file(
        &dir.join("site.typ"),
        "#import \"generated/manifest.typ\": notes\n#import \"generated/transclusions.typ\": transclusion-content\n#let note-meta(id: \"\", title: \"\", tags: ()) = none\n#let render-page(id, body) = body\n#let notelink(id, text: none) = [#id]\n#let transclude(id, mode: \"inline\") = [#id]\n",
    );
    write_file(
        &fake_typst,
        &format!(
            "#!/usr/bin/env bash\nset -euo pipefail\necho \"$@\" >> \"{}\"\nout=\"${{@: -1}}\"\nmkdir -p \"$(dirname \"$out\")\"\nprintf '<html><head></head><body>ok</body></html>' > \"$out\"\n",
            log_path.display()
        ),
    );

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&fake_typst).expect("meta").permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&fake_typst, perms).expect("chmod");
    }

    let status = Command::new(env!("CARGO_BIN_EXE_typst-knowledge-trees"))
        .current_dir(&dir)
        .arg("--input-dir")
        .arg("notes")
        .arg("--output-dir")
        .arg("dist")
        .arg("--generated-dir")
        .arg("generated")
        .arg("--typst-bin")
        .arg(fake_typst.to_string_lossy().to_string())
        .arg("build")
        .status()
        .expect("run build");
    assert!(status.success());

    assert!(dist_dir.join("alpha.html").exists());

    let invocations = fs::read_to_string(log_path).expect("read typst invocation log");
    assert!(invocations.contains("--features html"));
    assert!(invocations.contains("--root ."));
    assert!(invocations.contains("--format html"));
    assert!(generated_dir.join("manifest.typ").exists());

    fs::remove_dir_all(dir).expect("cleanup temp dir");
}
