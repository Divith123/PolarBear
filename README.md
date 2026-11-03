<p align="center">
  <img src="Design/polarbear-original.png" alt="A polar bear in sunglasses holding an ice pop" width="720">
</p>

<h1 align="center">PolarBear</h1>

<p align="center">
  A native, local-first LaTeX and Markdown editor for the Mac.<br>
  Real folders on disk, a real PDF preview, your own TeX engine and your own AI agents — nothing leaves your Mac unless you say so.
</p>

---

## Why PolarBear

Online LaTeX editors are convenient, but your documents live on someone else's server. Desktop editors keep
your files, but often feel like they were built for another decade. PolarBear is an attempt at both:

- **Your files stay yours.** A project is an ordinary folder. Edit it with PolarBear, Git, Finder or any other
  program; PolarBear notices the change and never silently overwrites it.
- **Native and light.** SwiftUI, AppKit and PDFKit. No web view for the editor, no Electron, no account.
- **Bring your own tools.** Compile with Tectonic or a TeX distribution you already have, and use the AI agent CLI
  you already run (Claude Code, Codex, OpenCode or Gemini) — with every change shown as a diff you accept or undo.

## Features

**Writing**
- Code editor with LaTeX and Markdown highlighting, line numbers, tabs, auto-indent and an outline of the headings.
- Projects are folders: file tree, rename, duplicate, move to Trash, drag files in, and a watcher that picks up
  changes made by other programs (an unsaved edit that also changed on disk becomes a visible conflict).
- Atomic autosave, and a version history with per-version diffs and one-click restore.
- Light and dark themes, solid and flat by design.

**LaTeX**
- Compiles with **Tectonic**, **latexmk**, or pdfLaTeX / XeLaTeX / LuaLaTeX directly, chosen per project or by a
  `% !TEX program =` comment. Compiles automatically as you type, or on demand with ⌘R.
- Errors and warnings from the log appear in a **Problems** list; click one to jump to the line. A failed build keeps
  showing the last good PDF.
- **SyncTeX** in both directions: "Go to PDF" from the caret, ⌘-click in the PDF to land on the source line.
- Project info: word and element counts in the spirit of `texcount`.

**Markdown**
- Switch a project between **TeX** and **Markdown** with the dropdown at the top of the sidebar. In Markdown mode
  the whole project changes: editor, outline, preview and exports.
- Rendered by PolarBear itself into a paginated PDF: CommonMark plus tables, task lists, footnotes, definition
  lists, GitHub alerts, `==mark==`, emoji shortcodes, front matter, `<details>`, syntax-coloured code (about 25
  languages), **maths** (typeset natively as MathML) and **Mermaid diagrams** (flowchart, sequence, class, state,
  ER, pie, Gantt and git graph, drawn natively as SVG).
- Download as Markdown or PDF; copy as rich text, HTML or plain text.
- Web images (`https` only) are downloaded into a cache before rendering; turn it off in the project menu.

**AI agents (optional)**
- Works with the **Claude Code**, **Codex**, **OpenCode** and **Gemini** command-line agents. You install them and
  sign in yourself; PolarBear never sees your credentials.
- Pick the agent, model and effort level from the composer. Conversations are kept per project.
- An agent works in a **temporary copy** of your sources (secrets are never copied). Its edits come back as hunks
  you **keep or undo one by one**; a version is recorded before and after.
- **Fix with AI**: one click sends the build's errors and warnings to the conversation. Every prompt also carries
  the latest build report, and the raw log is available to the agent as a file.

**Moving in and out**
- Import a project from a `.zip` or `.tar.gz` (archive paths are validated), export a project as a zip.
- Open a folder, a file or a recent project; start from templates (article, report, presentation, example, blank).

## Requirements

| | |
| --- | --- |
| macOS | 27 or later (the project's deployment target is 27.2) |
| Xcode | The version that ships the macOS 27 SDK |
| TeX | Nothing to do up front: if no engine is found, PolarBear offers an **Install Tectonic** button. MacTeX / TeX Live also work. Not needed for Markdown projects. |
| Rust | Only to build the experimental PolarBear Engine (`rustup`, stable toolchain) |
| AI agent | Optional. PolarBear can install **OpenCode** with one click; Claude Code, Codex and Gemini work if you already have them. |

## Install

Download a build from the Releases page, or install it from Terminal (no "unidentified developer" prompt, and the
download is checked against its SHA-256 first):

```sh
curl -fsSL https://raw.githubusercontent.com/Divith123/PolarBear/main/Scripts/get-polarbear.sh | bash
```

Releases are signed with a development certificate and are **not notarised** (that needs a paid Developer ID).
macOS therefore blocks a copy downloaded with a browser until you allow it once in **System Settings → Privacy &
Security → Open Anyway**. `curl` downloads are not flagged, which is why the command above avoids the prompt.

## Build and run

```sh
git clone <repository-url> PolarBear
cd PolarBear
open PolarBear.xcodeproj
```

Press ⌘R in Xcode. The project is signed with the maintainer's development team; to run it yourself, open
**Signing & Capabilities** and choose your own Team (and, if you like, another bundle identifier).

To build a Release app with the PolarBear Engine inside it and install it in `/Applications`:

```sh
Scripts/install.sh
```

To build a disk image with the bear artwork as its backdrop (`dist/PolarBear.dmg`):

```sh
python3 Scripts/make_dmg.py
```

Those builds are signed with your development certificate, so they run on your Mac but macOS shows "unidentified
developer" when someone downloads them. To publish an installer that opens without warnings, sign it with a
*Developer ID Application* certificate and notarise it with Apple; `Scripts/release.sh` does all of that once you have
the certificate and notary credentials (the setup is described at the top of the script).

## The PolarBear Engine

`engine/polarbear` is PolarBear's own TeX engine, written from scratch in Rust with no dependencies. It runs as a
separate program (so a build can be cancelled and a crash cannot take the app down) and ships inside the app at
`Contents/Helpers/polarbear-engine`.

**It cannot typeset yet.** The input layer, macro expansion and the node graph exist; fonts, line breaking, the page
builder and the PDF writer do not. Until `polarbear-engine status` reports `typesetting: ready`, "Automatic" compiles
with Tectonic or your TeX distribution, and choosing the PolarBear Engine by hand fails with "typesetting core
pending". When the engine can typeset, the app switches to it by itself. See [`engine/polarbear/README.md`](engine/polarbear/README.md)
and [`engine/polarbear/ROADMAP.md`](engine/polarbear/ROADMAP.md).

## Privacy and security

- No account, no analytics, no telemetry. Your projects are folders on your Mac.
- PolarBear goes online only when you ask: the **Install** buttons for Tectonic and OpenCode (downloaded from their
  official GitHub releases, verified by SHA-256, kept in `~/Library/Application Support/PolarBear/Tools`) and optional
  Markdown web images. Tectonic fetches TeX packages on its first compile; OpenCode needs its own provider sign-in
  (**Settings → Agents → Sign In…**) for most models.
- The App Sandbox is **off**. A sandboxed app cannot see `/opt/homebrew/bin/tectonic` or start your agent CLIs, so
  PolarBear could neither compile with your TeX nor run your agents. The hardened runtime stays on. If you are not
  comfortable with that, build it yourself and read the code — that is what the repository is for.
- Agents run only after you allow them for a project, in a temporary copy of the sources, with credential-like files
  excluded. Their changes reach your files only when you keep them.
- Compiler and agent commands are always launched with an argument array, never through a shell.
- Markdown rendering runs no script. Web images are fetched over `https` only, without cookies, and only if the
  setting is on.

Found a vulnerability? Please read [`SECURITY.md`](SECURITY.md).

## Project structure

```
PolarBear/                 The app (a file-system-synchronized Xcode group; one type per file)
  App/                       Scenes and menu commands
  Agents/                    Agent adapters, staging, runner, conversations, diff review, build report
  Build/                     Engines, toolchain discovery, build runner and model, log parser
  Diagrams/                  Mermaid → SVG, and the layered graph layout they share
  DesignSystem/              Colours, spacing and shared styles (light and dark)
  Diff/ History/             Text diff, version store
  Editor/                    The code editor (AppKit text view), tabs, composer, syntax highlighting
  Import/                    Archive import and zip export
  Library/ Templates/        Recent projects, new-project templates
  Markdown/                  Parser, HTML / plain-text writers, maths, code colouring, PDF printing
  Onboarding/ Profile/ Splash/  First run, the user's name and picture, the launch window
  Preview/                   PDFKit preview, header, drawer (problems, log, info, versions)
  Project/                   The project model: files, autosave, watcher, settings
  Settings/ Sidebar/ Welcome/ Window/ Workspace/   The window, its panels and per-window state
  Stats/ Support/ SyncTeX/   Word counts, process running, SyncTeX parsing and lookup
  Tools/                     One-click install of Tectonic and OpenCode (release lookup, checksum, store)
engine/polarbear/          The PolarBear Engine (Rust crate, MIT)
Design/                    The original bear artwork and the script that derives icons from it
Scripts/                   lint.sh, build_release.sh, install.sh, make_dmg.py, release.sh, get-polarbear.sh
```

[`ARCHITECTURE.md`](ARCHITECTURE.md) explains how the pieces fit together.

## Contributing

Contributions are welcome — bug reports, ideas, and pull requests. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md)
first; it covers the conventions the code follows and how to check a change.

## Roadmap

- A PolarBear Engine that typesets (see its roadmap), then making it the default.
- A bundled TeX option so the app compiles out of the box.
- More of what Markdown users expect: a table-of-contents block, more diagram types, theming of the PDF.
- Localisation.

## Acknowledgements

PolarBear stands on the shoulders of [Tectonic](https://tectonic-typesetting.github.io), TeX itself, SyncTeX and
Apple's PDFKit and WebKit. The Mermaid and KaTeX projects defined the syntaxes PolarBear reads; PolarBear contains
none of their code.

## License

The code is released under the [MIT License](LICENSE). The bear artwork in `Design/` and the app icon derived from it
are the project's brand and are not covered by that license; please do not reuse them as your own logo.
