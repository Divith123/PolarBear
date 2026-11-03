# PolarBear Engine — roadmap

The goal is a TeX engine of PolarBear's own: small, dependency-free, safe to run next to the app, and able to
replace Tectonic one day for the documents people actually write. It is built **clean-room**: behaviour comes from
the TeXbook, the published specifications and the observable output of a reference engine — never from copying
another engine's source.

The app already talks to it (`polarbear-engine compile` / `status`, shipped inside the app). While `status` says
`typesetting: pending`, the app compiles with Tectonic or a TeX distribution; the day the core says `ready`,
"Automatic" starts using it with no app change.

## Where the code is

| Layer | Status |
| --- | --- |
| **Seam** — `CompileRequest`, engine gate, status backend, C ABI, the command-line program | Done. A compile validates its input, reports the job, then stops with *typesetting core pending*. |
| **L1 · Tokens** — category codes, tokens, the line scanner | Done. |
| **L2 · Expansion** — macros, conditionals, number and dimension scanning | In progress. |
| **L3 · Boxes and the main loop** — the node graph, packing, horizontal and vertical mode | In progress. |
| **L4 · Fonts and PDF** — TFM / OpenType metrics, line breaking, the page builder, a PDF writer | Not started. |
| **L5 · The format** — running a LaTeX format on our own engine | Not started. |
| **L6 · Parity** — logs and `.aux` files byte-identical and PDFs identical (modulo creation date) for a recorded set of documents | The bar for replacing Tectonic. |

## How progress is checked

* The reference is the installed `tectonic` 0.17.0 (outside this repository): for a document, our log and `.aux`
  must match its, and the PDF must match modulo the creation date.
* Each milestone is checked before the next one starts, with throw-away drivers; they are not committed.
* The crate keeps `missing_docs`, `unsafe_op_in_unsafe_fn` and `undocumented_unsafe_blocks` denied, and every file
  carries the copyright header.

## Not goals

* Being a drop-in for every package on CTAN on day one.
* Shell escape, or anything that runs other programs, on by default.
