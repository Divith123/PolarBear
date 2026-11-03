// Copyright (c) 2026 Divith123. Licensed under the MIT License.
//
// The command-line face of the engine seam. The macOS app runs this program
// as a child process (one engine process per compile), which gives it hard
// cancel and crash isolation without linking Rust into the app.

//! `polarbear-engine`: runs the PolarBear engine from the command line.
//!
//! ```text
//! polarbear-engine status
//! polarbear-engine compile --outdir DIR [--job NAME] [--workdir DIR]
//!                          [--cache DIR] [--bundle SPEC] [--format NAME]
//!                          [--synctex] [--keep-logs] [--only-cached]
//!                          [--shell-escape] [--continue-on-errors]
//!                          [--untrusted] MAIN.tex
//! ```
//!
//! `status` prints `version:` and `typesetting: ready|pending` — it really
//! runs a one-line compile, so the answer flips to `ready` by itself the day
//! the typesetting core lands. `compile` prints `note:`, `warning:` and
//! `error:` lines on standard error and exits 0 (compiled), 1 (the compile
//! failed) or 2 (bad command line).

use std::{
    env,
    fmt::Arguments,
    fs,
    path::{Path, PathBuf},
    process::ExitCode,
};

use polarbear_engine::{CompileError, CompileRequest, MessageKind, StatusBackend};

/// Prints engine chatter as `kind: message` lines on standard error.
struct Console;

impl StatusBackend for Console {
    fn report(&mut self, kind: MessageKind, args: Arguments, err: Option<&CompileError>) {
        let label = match kind {
            MessageKind::Note => "note",
            MessageKind::Warning => "warning",
            MessageKind::Error => "error",
        };
        let tail = err.map(|error| format!(" ({error})")).unwrap_or_default();
        eprintln!("{label}: {args}{tail}");
    }

    fn dump_error_logs(&mut self, output: &[u8]) {
        eprint!("{}", String::from_utf8_lossy(output));
    }
}

/// Swallows engine chatter (used by the `status` probe).
struct Silent;

impl StatusBackend for Silent {
    fn report(&mut self, _kind: MessageKind, _args: Arguments, _err: Option<&CompileError>) {}
}

/// What the command line asked for.
struct Options {
    outdir: PathBuf,
    job: Option<String>,
    workdir: Option<PathBuf>,
    cache: Option<PathBuf>,
    bundle: Option<String>,
    format: Option<String>,
    synctex: bool,
    keep_logs: bool,
    only_cached: bool,
    shell_escape: bool,
    continue_on_errors: bool,
    untrusted: bool,
    input: PathBuf,
}

/// Parse the arguments after `compile`; `Err` carries the message to print.
fn parse(args: &[String]) -> Result<Options, String> {
    let mut outdir = None;
    let mut options = Options {
        outdir: PathBuf::new(),
        job: None,
        workdir: None,
        cache: None,
        bundle: None,
        format: None,
        synctex: false,
        keep_logs: false,
        only_cached: false,
        shell_escape: false,
        continue_on_errors: false,
        untrusted: false,
        input: PathBuf::new(),
    };
    let mut input = None;
    let mut iter = args.iter();

    while let Some(arg) = iter.next() {
        let mut value = |name: &str| iter.next().cloned().ok_or(format!("{name} needs a value"));
        match arg.as_str() {
            "--outdir" => outdir = Some(PathBuf::from(value("--outdir")?)),
            "--job" => options.job = Some(value("--job")?),
            "--workdir" => options.workdir = Some(PathBuf::from(value("--workdir")?)),
            "--cache" => options.cache = Some(PathBuf::from(value("--cache")?)),
            "--bundle" => options.bundle = Some(value("--bundle")?),
            "--format" => options.format = Some(value("--format")?),
            "--synctex" => options.synctex = true,
            "--keep-logs" => options.keep_logs = true,
            "--only-cached" => options.only_cached = true,
            "--shell-escape" => options.shell_escape = true,
            "--continue-on-errors" => options.continue_on_errors = true,
            "--untrusted" => options.untrusted = true,
            flag if flag.starts_with("--") => return Err(format!("unknown option {flag}")),
            file => {
                if input.replace(PathBuf::from(file)).is_some() {
                    return Err(String::from("more than one input file"));
                }
            }
        }
    }

    options.outdir = outdir.ok_or("--outdir is required")?;
    options.input = input.ok_or("no input file")?;
    Ok(options)
}

/// The job name: `--job`, else the input's file stem.
fn job_name(options: &Options) -> String {
    options.job.clone().unwrap_or_else(|| {
        options
            .input
            .file_stem()
            .map(|stem| stem.to_string_lossy().into_owned())
            .unwrap_or_else(|| String::from("texput"))
    })
}

/// `polarbear-engine compile …`
fn compile(args: &[String]) -> ExitCode {
    let options = match parse(args) {
        Ok(options) => options,
        Err(message) => {
            eprintln!("error: {message}");
            return ExitCode::from(2);
        }
    };
    let source = match fs::read(&options.input) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("error: cannot read {}: {error}", options.input.display());
            return ExitCode::from(2);
        }
    };

    let mut request = CompileRequest::new(source, job_name(&options), options.outdir.clone())
        .with_synctex(options.synctex)
        .with_artifacts(options.keep_logs)
        .only_cached(options.only_cached)
        .shell_escape(options.shell_escape)
        .continue_on_errors(options.continue_on_errors)
        .untrusted(options.untrusted);
    if let Some(dir) = &options.workdir {
        request = request.with_working_dir(dir);
    }
    if let Some(dir) = &options.cache {
        request = request.with_cache_dir(dir);
    }
    if let Some(spec) = &options.bundle {
        request = request.with_bundle(spec.as_str());
    }
    if let Some(name) = &options.format {
        request = request.with_format(name.as_str());
    }

    let mut console = Console;
    match request.compile(&mut console) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            console.report(MessageKind::Error, format_args!("compile failed"), Some(&error));
            ExitCode::from(1)
        }
    }
}

/// `polarbear-engine status`: a real one-line compile into a scratch folder.
fn status() -> ExitCode {
    let scratch: &Path = &env::temp_dir();
    let outcome = CompileRequest::new(b"\\relax".to_vec(), "probe", scratch).compile(&mut Silent);
    println!("version: {}", env!("CARGO_PKG_VERSION"));
    println!("typesetting: {}", if outcome.is_ok() { "ready" } else { "pending" });
    ExitCode::SUCCESS
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("status") => status(),
        Some("compile") => compile(&args[1..]),
        _ => {
            eprintln!("usage: polarbear-engine status | compile --outdir DIR [options] MAIN.tex");
            ExitCode::from(2)
        }
    }
}
