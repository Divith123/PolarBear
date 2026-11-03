# polarbear_engine

PolarBear's own typesetting-engine crate (`engine/polarbear`). Everything
here is PolarBear's own code (© 2026 Divith123, MIT); no upstream TeX
tree is vendored — `engine/` contains only this crate.

## What's in it

- `src/lib.rs` — the safe seam: `CompileRequest` (source + job/output +
  bundle/cache/format/working-dir + feature flags, all via `#[must_use]`
  builders), the process-wide engine gate (one compile per process; the
  engines hold process-global state), the host-side
  `StatusBackend`/`MessageKind`, and the engine's own `Result`/`CompileError`.
- `src/c_api.rs` — the C ABI for the Swift/static-lib embedding:
  `xelatex_compile` and `xelatex_string_free`, with the `XE_COMPILE_EXIT_*`
  result codes, `XE_FLAG_*` option bits and `XE_STATUS_*` callback kinds.
  Panics are caught at the boundary and never unwind into the host.
- `src/tex/` — the clean-room typesetting core under construction (rung 5).
  Milestone 1, the input layer, is in: `catcode.rs` (the 16 category codes +
  `\catcode`-mutable table), `token.rs` (tokens) and `lexer.rs` (lines to
  tokens: `^^` notation, trailing-space stripping, blank-line `\par`,
  comment joining, the line/character state machine). The milestone ladder
  down to a complete engine is in [`ROADMAP.md`](ROADMAP.md).

## Honest state

The seam is final and compiles clean; the **typesetting core is not
implemented yet** (see [`ROADMAP.md`](ROADMAP.md)). A compile runs argument validation,
acquires the gate, reports the job through the status backend, and then
fails with `CompileError::CorePending` / `XE_COMPILE_EXIT_ENGINE` until the
core lands. Nothing typesets yet.

## Build

```sh
cargo build          # zero dependencies → no pkg-config, no PKG_CONFIG_PATH
nm -g target/debug/libpolarbear_engine.a | grep xelatex   # C symbols
```

Produces `libpolarbear_engine.{a,rlib,dylib}` and exports
`_xelatex_compile` + `_xelatex_string_free`. Lints are enforced
(`missing_docs`, `unsafe_op_in_unsafe_fn`, `undocumented_unsafe_blocks`).

Ground truth for the future core: the output of the `tectonic` 0.17.0 binary
(installed separately, never vendored here). Its logs and PDFs are compared with
ours; its source code is not copied.
