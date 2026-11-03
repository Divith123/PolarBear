// Copyright (c) 2026 Divith123. Licensed under the MIT License.
//
// PolarBear's own typesetting engine: the seam the macOS app talks to. All
// code in this crate is written for PolarBear — no upstream TeX tree is
// vendored (the plan lives in `ROADMAP.md`).

//! PolarBear's compile-engine seam: a safe Rust API and a C ABI for the
//! embedded XeLaTeX pipeline.
//!
//! # Layout
//!
//! * [`CompileRequest`] — one compile job: source bytes, job/output
//!   locations, optional bundle/cache/format/working-dir overrides and
//!   feature flags. Requests are built with [`CompileRequest::new`] and the
//!   chainable setters, then executed with [`CompileRequest::compile`].
//! * [`StatusBackend`] — the host's receive side for engine chatter
//!   ([`StatusBackend::report`], [`StatusBackend::dump_error_logs`]), with
//!   the [`MessageKind`] severity levels.
//! * The C ABI (module `c_api`, re-exported here) — `xelatex_compile` /
//!   `xelatex_string_free`, the `XE_COMPILE_EXIT_*` result codes, the
//!   `XE_FLAG_*` option bits and the `XE_STATUS_*` callback kinds, for the
//!   Swift/static-lib embedding.
//!
//! # Concurrency
//!
//! The typesetting engines hold process-global state, so a process runs at
//! most one compile at a time: [`CompileRequest::compile`] acquires a
//! process-wide gate for the whole pass, whichever thread makes the
//! request, and hosts that want parallelism should host one engine process
//! per lane.
//!
//! # Honesty about state
//!
//! The seam is final and compiles clean, but the typesetting core
//! (TeX/XeTeX behavior in Rust) is not implemented yet — it is the
//! ownership ladder's rung 5. Compiles therefore run the full seam
//! (validation, gate, status traffic) and fail with
//! [`CompileError::CorePending`]. No upstream TeX code is vendored here.

mod c_api;

pub use c_api::{
    StatusKind, XeStatusCallback, XE_COMPILE_EXIT_BAD_ARGS, XE_COMPILE_EXIT_ENGINE,
    XE_COMPILE_EXIT_OK, XE_COMPILE_EXIT_PANIC, XE_FLAG_CONTINUE_ON_ERRORS,
    XE_FLAG_KEEP_ARTIFACTS, XE_FLAG_ONLY_CACHED, XE_FLAG_SHELL_ESCAPE, XE_FLAG_SYNCTEX,
    XE_FLAG_UNTRUSTED, XE_STATUS_ERROR, XE_STATUS_LOG, XE_STATUS_NOTE, XE_STATUS_WARNING,
};

pub mod tex;

use std::{
    fmt::{self, Arguments},
    path::PathBuf,
    sync::{Mutex, MutexGuard, OnceLock},
};

/// Process-wide compile gate: the engines hold process-global state, so at
/// most one compile may be in flight per process.
static ENGINE_GATE: OnceLock<Mutex<()>> = OnceLock::new();

/// Acquire the process-wide compile gate; the guard releases it on drop.
///
/// A poisoned lock is recovered from on purpose: the gate guards
/// concurrency only, so a panic inside one pass leaves nothing inconsistent
/// behind that the next pass could not simply overwrite.
fn acquire_engine_gate() -> MutexGuard<'static, ()> {
    ENGINE_GATE
        .get_or_init(|| Mutex::new(()))
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Severity of a [`StatusBackend::report`] message.
#[derive(Clone, Copy, Debug)]
pub enum MessageKind {
    /// Informational chatter (progress notes).
    Note,
    /// A recoverable problem the host should surface.
    Warning,
    /// A hard problem; failing compiles are reported as errors.
    Error,
}

/// The host's receive side for engine chatter.
pub trait StatusBackend {
    /// Report one message: `args` is the formatted text, `err` the
    /// underlying error when the report originates from one.
    fn report(&mut self, kind: MessageKind, args: Arguments, err: Option<&CompileError>);

    /// Dump a raw console/log chunk. The default implementation ignores the
    /// chunk; backends that mirror a TeX console should present it verbatim.
    fn dump_error_logs(&mut self, output: &[u8]) {
        let _ = output;
    }
}

/// Errors the engine reports to its caller.
#[derive(Debug)]
#[non_exhaustive]
pub enum CompileError {
    /// The typesetting core is not implemented yet (ownership-ladder rung
    /// 5): the seam is live, but it does not typeset documents yet. The
    /// payload is a human-readable explanation.
    CorePending(String),
}

impl fmt::Display for CompileError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            CompileError::CorePending(why) => write!(f, "typesetting core pending: {why}"),
        }
    }
}

impl std::error::Error for CompileError {}

/// The engine's `Result` type: everything fails with a [`CompileError`].
pub type Result<T> = std::result::Result<T, CompileError>;

/// One compile job, and every option the seam supports.
///
/// Build with [`CompileRequest::new`] plus the chainable, `#[must_use]`
/// setters, then run [`CompileRequest::compile`] with a [`StatusBackend`].
#[derive(Debug)]
pub struct CompileRequest {
    input: Vec<u8>,
    job_name: String,
    output_dir: PathBuf,
    cache_dir: Option<PathBuf>,
    bundle: Option<String>,
    format: Option<String>,
    working_dir: Option<PathBuf>,
    synctex: bool,
    keep_artifacts: bool,
    only_cached: bool,
    shell_escape: bool,
    continue_on_errors: bool,
    untrusted: bool,
}

impl CompileRequest {
    /// Create a request for `input` (the main document's source bytes),
    /// writing `<job_name>.pdf` and companions into `output_dir`.
    #[must_use]
    pub fn new<I, J, O>(input: I, job_name: J, output_dir: O) -> Self
    where
        I: Into<Vec<u8>>,
        J: Into<String>,
        O: Into<PathBuf>,
    {
        Self {
            input: input.into(),
            job_name: job_name.into(),
            output_dir: output_dir.into(),
            cache_dir: None,
            bundle: None,
            format: None,
            working_dir: None,
            synctex: false,
            keep_artifacts: false,
            only_cached: false,
            shell_escape: false,
            continue_on_errors: false,
            untrusted: false,
        }
    }

    /// Use `bundle` — a `https://…` `.tar`/`.ttb` specifier, a local file or
    /// a directory — instead of the default relay bundle.
    #[must_use]
    pub fn with_bundle(mut self, bundle: impl Into<String>) -> Self {
        self.bundle = Some(bundle.into());
        self
    }

    /// Use `cache_dir` as the cache root (bundle blobs + formats) instead
    /// of the per-user default location.
    #[must_use]
    pub fn with_cache_dir(mut self, cache_dir: impl Into<PathBuf>) -> Self {
        self.cache_dir = Some(cache_dir.into());
        self
    }

    /// Run the TeX format named `format` instead of the default `"latex"`.
    #[must_use]
    pub fn with_format(mut self, format: impl Into<String>) -> Self {
        self.format = Some(format.into());
        self
    }

    /// Use `working_dir` as the search root for file I/O instead of the
    /// engine default.
    #[must_use]
    pub fn with_working_dir(mut self, working_dir: impl Into<PathBuf>) -> Self {
        self.working_dir = Some(working_dir.into());
        self
    }

    /// Also write SyncTeX data (for click-to-source mapping).
    #[must_use]
    pub fn with_synctex(mut self, synctex: bool) -> Self {
        self.synctex = synctex;
        self
    }

    /// Write `job.log` and intermediates alongside the final artifacts.
    #[must_use]
    pub fn with_artifacts(mut self, keep_artifacts: bool) -> Self {
        self.keep_artifacts = keep_artifacts;
        self
    }

    /// Use only bundle data already in the cache (offline mode).
    #[must_use]
    pub fn only_cached(mut self, only_cached: bool) -> Self {
        self.only_cached = only_cached;
        self
    }

    /// Allow `\write18` shell escape (trusted input only).
    #[must_use]
    pub fn shell_escape(mut self, shell_escape: bool) -> Self {
        self.shell_escape = shell_escape;
        self
    }

    /// Continue past severe errors (best-effort diagnostic builds).
    #[must_use]
    pub fn continue_on_errors(mut self, continue_on_errors: bool) -> Self {
        self.continue_on_errors = continue_on_errors;
        self
    }

    /// Treat the input as untrusted (disables every known-insecure feature).
    #[must_use]
    pub fn untrusted(mut self, untrusted: bool) -> Self {
        self.untrusted = untrusted;
        self
    }

    /// Run the compile, reporting chatter through `status`.
    ///
    /// Acquires the process-wide engine gate for the whole pass (one
    /// compile per process; see the crate docs).
    ///
    /// # State
    ///
    /// The typesetting core is not implemented yet (ownership-ladder rung
    /// 5), so this announces the job through `status` and then fails with
    /// [`CompileError::CorePending`] — the honest seam before the core
    /// lands, not a silent fake success.
    pub fn compile(&self, status: &mut dyn StatusBackend) -> Result<()> {
        let _gate = acquire_engine_gate();

        let mut flags: Vec<&'static str> = Vec::new();
        if self.synctex {
            flags.push("synctex");
        }
        if self.keep_artifacts {
            flags.push("keep-artifacts");
        }
        if self.only_cached {
            flags.push("only-cached");
        }
        if self.shell_escape {
            flags.push("shell-escape");
        }
        if self.continue_on_errors {
            flags.push("continue-on-errors");
        }
        if self.untrusted {
            flags.push("untrusted");
        }

        let format_label = self.format.as_deref().unwrap_or("latex");
        let bundle_label = self.bundle.as_deref().unwrap_or("default relay");
        let cache_label = match self.cache_dir.as_deref() {
            Some(_) => "explicit",
            None => "default",
        };
        let working_label = match self.working_dir.as_deref() {
            Some(_) => "explicit",
            None => "default",
        };
        let flags_display = if flags.is_empty() {
            String::from("none")
        } else {
            flags.join(", ")
        };

        status.report(
            MessageKind::Note,
            format_args!(
                "engine: preparing job \"{job}\" (input: {bytes} B, out: {out}, format: {format}, bundle: {bundle}, cache: {cache}, working dir: {working}, flags: {flags})",
                job = self.job_name,
                bytes = self.input.len(),
                out = self.output_dir.display(),
                format = format_label,
                bundle = bundle_label,
                cache = cache_label,
                working = working_label,
                flags = flags_display,
            ),
            None,
        );

        Err(CompileError::CorePending(String::from(
            "the typesetting core (TeX-in-Rust, ownership-ladder rung 5) is not implemented yet; the seam is live and the core lands in a later rung",
        )))
    }
}
