// Copyright (c) 2026 Divith123. Licensed under the MIT License.
//
// PolarBear's C ABI over the engine seam (all code ours): the entry points,
// exit codes, flag bits and status kinds the macOS app relies on.

//! C ABI for the Swift/static-lib embedding: `xelatex_compile` and
//! `xelatex_string_free`, plus the `XE_*` constants describing their
//! contract. Re-exported from the crate root for Rust hosts.

use std::{
    any::Any,
    ffi::{c_char, c_int, CStr, CString},
    fmt::Arguments,
    panic::{catch_unwind, AssertUnwindSafe},
    slice,
};

use crate::{CompileError, CompileRequest, MessageKind, StatusBackend};

/// Status callback message kind: an informational note.
pub const XE_STATUS_NOTE: StatusKind = 0;
/// Status callback message kind: a warning.
pub const XE_STATUS_WARNING: StatusKind = 1;
/// Status callback message kind: an error.
pub const XE_STATUS_ERROR: StatusKind = 2;
/// Status callback message kind: a raw console/log chunk (`dump_error_logs`).
pub const XE_STATUS_LOG: StatusKind = 3;

/// The C type of the status-callback `kind` parameter (a C `int`).
pub type StatusKind = c_int;

/// Exit code: the compile completed (TeX-level errors, if any, are in the logs).
pub const XE_COMPILE_EXIT_OK: c_int = 0;
/// Exit code: the compile failed (details arrive via the status callback).
pub const XE_COMPILE_EXIT_ENGINE: c_int = 1;
/// Exit code: a call argument was null, non-UTF-8, or otherwise invalid.
pub const XE_COMPILE_EXIT_BAD_ARGS: c_int = 2;
/// Exit code: the engine panicked; the text is handed out via `panic_msg_out`.
pub const XE_COMPILE_EXIT_PANIC: c_int = 3;

/// Flag bit: also write SyncTeX data (for click-to-source mapping).
pub const XE_FLAG_SYNCTEX: c_int = 1 << 0;
/// Flag bit: write `job.log` and intermediates into the output directory.
pub const XE_FLAG_KEEP_ARTIFACTS: c_int = 1 << 1;
/// Flag bit: use only bundle data already in the cache (offline mode).
pub const XE_FLAG_ONLY_CACHED: c_int = 1 << 2;
/// Flag bit: allow `\write18` shell escape (trusted input only).
pub const XE_FLAG_SHELL_ESCAPE: c_int = 1 << 3;
/// Flag bit: continue past severe errors (best-effort diagnostic builds).
pub const XE_FLAG_CONTINUE_ON_ERRORS: c_int = 1 << 4;
/// Flag bit: treat the input as untrusted (disables every known-insecure feature).
pub const XE_FLAG_UNTRUSTED: c_int = 1 << 5;

/// Host-provided status callback.
///
/// `kind` is one of the `XE_STATUS_*` kinds; `message` is a NUL-terminated
/// UTF-8 buffer valid for the duration of the call. Hosts that do not want
/// status output pass `NULL` for the whole callback.
pub type XeStatusCallback = extern "C" fn(kind: StatusKind, message: *const c_char);

/// Bridges engine status traffic to the host's C callback.
struct StatusBridge {
    cb: Option<XeStatusCallback>,
}

/// Map a [`MessageKind`] to its C kind constant.
fn c_kind(kind: MessageKind) -> StatusKind {
    match kind {
        MessageKind::Note => XE_STATUS_NOTE,
        MessageKind::Warning => XE_STATUS_WARNING,
        MessageKind::Error => XE_STATUS_ERROR,
    }
}

/// Encode `text` as a `CString`, mapping interior NUL bytes to an empty
/// string so that no host call can ever panic.
fn cstring(text: &str) -> CString {
    CString::new(text.as_bytes()).unwrap_or_default()
}

impl StatusBackend for StatusBridge {
    fn report(&mut self, kind: MessageKind, args: Arguments, err: Option<&CompileError>) {
        let Some(cb) = self.cb else {
            return;
        };

        let tail = err.map(|error| format!(" ({error})")).unwrap_or_default();
        let message = cstring(&format!("{args}{tail}"));

        // Calling a non-null `extern "C" fn` value is safe: the `None` case
        // was excluded above, and `message` outlives the call.
        cb(c_kind(kind), message.as_ptr());
    }

    fn dump_error_logs(&mut self, output: &[u8]) {
        let Some(cb) = self.cb else {
            return;
        };

        // The TeX console stream is not guaranteed UTF-8; a lossy mapping
        // cannot panic and keeps the host's log view readable.
        let message = cstring(&String::from_utf8_lossy(output));

        // Same rationale as in `report`.
        cb(XE_STATUS_LOG, message.as_ptr());
    }
}

/// Read one `char*` argument that may be `NULL` (meaning "not provided").
///
/// `Err(name)` carries the argument's name when its bytes are not valid
/// UTF-8, so the call can return `XE_COMPILE_EXIT_BAD_ARGS`.
///
/// # Safety
///
/// `p` must be either null, or a pointer to a valid NUL-terminated C string
/// (readable for the duration of the call).
unsafe fn cstr_opt<'a>(p: *const c_char, name: &'static str) -> Result<Option<&'a str>, &'static str> {
    if p.is_null() {
        return Ok(None);
    }

    // SAFETY: upheld by the caller of the C ABI, per this function's
    // `# Safety` contract.
    match unsafe { CStr::from_ptr(p) }.to_str() {
        Ok(text) => Ok(Some(text)),
        Err(_) => Err(name),
    }
}

/// Extract a printable message from a caught panic payload.
fn panic_text(payload: &Box<dyn Any + Send>) -> String {
    if let Some(text) = payload.downcast_ref::<&'static str>() {
        (*text).to_owned()
    } else if let Some(text) = payload.downcast_ref::<String>() {
        text.clone()
    } else {
        String::from("the engine panicked (non-string payload)")
    }
}

/// Run one embedded compile of `input` and write artifacts into `output_dir`.
///
/// This is PolarBear's C entry point into the engine seam. Arguments:
///
/// * `input`/`input_len`: the main document's TeX source bytes.
/// * `job_name`: output stem without extension (e.g. `"chapters/03"`).
/// * `output_dir`: where `<job>.pdf` and companions are written.
/// * `cache_dir`: optional cache root; `NULL` uses the per-user default.
/// * `bundle`: optional bundle specifier (`https://…` `.tar`/`.ttb`, a local
///   file, or a directory); `NULL` uses the default relay bundle.
/// * `format`: optional format name; `NULL` means `"latex"`.
/// * `working_dir`: optional search root for file I/O; `NULL` uses the default.
/// * `flags`: bitmask of `XE_FLAG_*`.
/// * `status_cb`: optional host callback receiving engine chatter.
/// * `panic_msg_out`: optional `char*` out-parameter; on a panic exit it
///   receives a NUL-terminated message the host must release with
///   [`xelatex_string_free`].
///
/// Returns one of the `XE_COMPILE_EXIT_*` codes.
///
/// # State
///
/// The typesetting core is not implemented yet (ownership-ladder rung 5):
/// calls run the full seam (argument validation, engine gate, status
/// traffic) and return `XE_COMPILE_EXIT_ENGINE`, with the pending-core
/// explanation reported through `status_cb`.
///
/// # Safety
///
/// Every non-null `char*`/buffer argument must be valid for the duration of
/// the call; strings must be NUL-terminated; `input` must be readable for
/// `input_len` bytes. All strings are copied, so hosts may free them as
/// soon as this function returns.
#[no_mangle]
pub unsafe extern "C" fn xelatex_compile(
    input: *const u8,
    input_len: usize,
    job_name: *const c_char,
    output_dir: *const c_char,
    cache_dir: *const c_char,
    bundle: *const c_char,
    format: *const c_char,
    working_dir: *const c_char,
    flags: c_int,
    status_cb: Option<XeStatusCallback>,
    panic_msg_out: *mut *mut c_char,
) -> c_int {
    if input.is_null() || job_name.is_null() || output_dir.is_null() {
        return XE_COMPILE_EXIT_BAD_ARGS;
    }

    // SAFETY: every pointer argument is either null or points to a valid
    // NUL-terminated C string for the duration of this call, per the
    // `# Safety` contract above.
    let parsed = unsafe {
        [
            cstr_opt(job_name, "job_name"),
            cstr_opt(output_dir, "output_dir"),
            cstr_opt(cache_dir, "cache_dir"),
            cstr_opt(bundle, "bundle"),
            cstr_opt(format, "format"),
            cstr_opt(working_dir, "working_dir"),
        ]
    };

    let first_bad = parsed.iter().find_map(|result| match result {
        Err(name) => Some(*name),
        Ok(_) => None,
    });
    if let Some(name) = first_bad {
        if let Some(cb) = status_cb {
            let note = cstring(&format!("argument `{name}` is not valid UTF-8"));

            // Calling a non-null `extern "C" fn` value is safe (see
            // `StatusBridge::report`).
            cb(XE_STATUS_ERROR, note.as_ptr());
        }
        return XE_COMPILE_EXIT_BAD_ARGS;
    }

    let [job_name, output_dir, cache_dir, bundle, format, working_dir] =
        parsed.map(|value| value.unwrap_or(None));

    // SAFETY: `input` is readable for `input_len` bytes per the `# Safety`
    // contract above.
    let source = unsafe { slice::from_raw_parts(input, input_len) };

    let mut request = CompileRequest::new(
        source,
        job_name.unwrap_or_default(),
        output_dir.unwrap_or_default(),
    );
    if let Some(dir) = cache_dir {
        request = request.with_cache_dir(dir);
    }
    if let Some(spec) = bundle {
        request = request.with_bundle(spec);
    }
    if let Some(name) = format {
        request = request.with_format(name);
    }
    if let Some(dir) = working_dir {
        request = request.with_working_dir(dir);
    }
    request = request
        .with_synctex(flags & XE_FLAG_SYNCTEX != 0)
        .with_artifacts(flags & XE_FLAG_KEEP_ARTIFACTS != 0)
        .only_cached(flags & XE_FLAG_ONLY_CACHED != 0)
        .shell_escape(flags & XE_FLAG_SHELL_ESCAPE != 0)
        .continue_on_errors(flags & XE_FLAG_CONTINUE_ON_ERRORS != 0)
        .untrusted(flags & XE_FLAG_UNTRUSTED != 0);

    let mut bridge = StatusBridge { cb: status_cb };

    // A panic unwinding across the C boundary is undefined behavior, so the
    // whole pass is caught here and translated to `XE_COMPILE_EXIT_PANIC`
    // (the payload, if any, is handed to the host below).
    let outcome = catch_unwind(AssertUnwindSafe(|| request.compile(&mut bridge)));

    match outcome {
        Ok(Ok(())) => XE_COMPILE_EXIT_OK,
        Ok(Err(error)) => {
            // The backend appends the underlying error itself, so the
            // message is only the prefix.
            bridge.report(MessageKind::Error, format_args!("compile failed"), Some(&error));
            XE_COMPILE_EXIT_ENGINE
        }
        Err(payload) => {
            if !panic_msg_out.is_null() {
                let text = cstring(&panic_text(&payload));

                // SAFETY: `panic_msg_out` is a valid `char**` out-parameter
                // per the `# Safety` contract; ownership of the allocation
                // moves to the host (released via `xelatex_string_free`).
                unsafe { *panic_msg_out = text.into_raw() };
            }
            XE_COMPILE_EXIT_PANIC
        }
    }
}

/// Release a string handed out by this ABI (currently the `xelatex_compile`
/// panic-text out-parameter).
///
/// # Safety
///
/// `s` must be null or a pointer previously returned by this library's
/// out-parameters; anything else is undefined behavior.
#[no_mangle]
pub unsafe extern "C" fn xelatex_string_free(s: *mut c_char) {
    if s.is_null() {
        return;
    }

    // SAFETY: `s` provably originated from `CString::into_raw` in this
    // crate, per the `# Safety` contract above.
    unsafe {
        drop(CString::from_raw(s));
    }
}
