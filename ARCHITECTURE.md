# Architecture

This is a map of how PolarBear is put together, for people who want to read or change the code. For the user's
view of the app, see the [README](README.md).

## At a glance

```
                ┌────────────────────────── ProjectLibrary (app-wide) ──────────────────────────┐
                │ recent projects · open projects · TeX toolchain · agent catalog · profile      │
                └───────────────────────────────────┬────────────────────────────────────────────┘
                                                    │ one Project per folder, shared by its windows
        ┌───────────────────────────────────────────▼───────────────────────────────────────────┐
        │ Project   files · assets · settings · autosave · folder watcher                        │
        │   ├─ BuildModel    compile one document at a time, publish the PDF, keep the log     │
        │   ├─ HistoryModel  content-addressed versions, diffs, restore                         │
        │   ├─ AgentModel    conversations, runs in a staged copy, hunk-by-hunk review          │
        │   └─ SyncTeXService  source ⇄ PDF positions                                           │
        └───────────────────────────────────────────┬───────────────────────────────────────────┘
                                                    │ one WorkspaceModel per window
                       WorkspaceModel  tabs · sidebar · drawer · outline · layout
                       WindowState     which project, sheets, alerts, full screen
```

* **`Project`** (`Project/`) is the model of one folder. It is shared by every window that shows the folder.
* **`WorkspaceModel`** and **`WindowState`** (`Workspace/`) hold what belongs to a single window. Per-window UI state
  never goes into `Project`.
* **`ProjectLibrary`** (`Library/`) is the app-wide object: recents, the TeX toolchain, the agent catalog, the profile.

The project builds with Swift 5 language mode and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Code that must not run
on the main actor (file I/O, processes, parsing, diffing, layout) is `nonisolated` or `@concurrent`.

## The folder is the source of truth

* Files are read into `ProjectFile` objects; edits mark them dirty and an atomic write follows ~600 ms after typing
  stops (`FileIO.write`).
* `FolderWatcher` (FSEvents — the one place that uses a dispatch queue) reports changes made by other programs;
  `Project.reconcileWithDisk()` merges them. An unsaved edit that also changed on disk becomes a visible *conflict*,
  never a silent overwrite.
* The app's own data lives in `<project>/.PolarBear/` with its own `.gitignore`:
  `project.json` (settings), `build/` (engine output), `published/` (the last good PDF), `history/` (versions),
  `chats/` (agent conversations), `cache/images/` (downloaded web images).

## Building a document

```
Project.makeBuildRequest()  ──►  BuildModel  ──►  BuildRunner.run
                                   (one at a time,      │
                                    debounced rebuild)  ├─ TeX project:      PolarBear Engine │ Tectonic │ latexmk │ direct engine
                                                        └─ Markdown project: MarkdownBuild
                                                                             │
                              LogParser ─► [Diagnostic] ─► Problems list, gutter markers, "Fix with AI"
                              BuildPublisher ─► published/<job>.pdf ─► PDFKit preview (+ SyncTeX)
```

* `TeXToolchain` finds the programs (a GUI app does not inherit the shell's `PATH`, so known folders are probed).
* `BuildRunner` always launches programs with an **argument array**, never a shell string (`Support/ProcessRunner`).
* A failed build keeps the last good PDF on screen (`BuildModel.isStale`).
* `PolarBearEngine` locates `polarbear-engine` (inside the app at `Contents/Helpers/`, or the Cargo output while
  developing) and asks it for its `status`. "Automatic" only picks it once it reports `typesetting: ready`.

### Markdown projects

```
source ─► MarkdownParser ─► MarkdownDocument (blocks, inlines, footnotes)
                              ├─ MarkdownHTMLWriter ─► HTML page  ─► WebKit print ─► paginated PDF (MarkdownPDF)
                              │     ├─ CodeHighlighter     coloured code blocks
                              │     ├─ LatexMath           $…$ → MathML
                              │     ├─ MermaidRenderer     ```mermaid → SVG  (Diagrams/)
                              │     └─ MarkdownImageStore  https images → cache (the page itself never uses the network)
                              ├─ MarkdownPlainTextWriter ─► "Copy as Plain Text"
                              └─ MarkdownClipboard       ─► rich text / HTML / plain text
```

There is no JavaScript anywhere in this path: maths is MathML, diagrams are SVG drawn by `Diagrams/`, and the
web view runs with scripts disabled.

## Tools PolarBear can install

```
ManagedTool         Tectonic and OpenCode: repository, asset name for this Mac, which tags are releases
ToolReleaseFinder   GitHub API → newest stable release with a file for this Mac and its SHA-256 digest
ToolDownloader      URLSession download with progress; streaming SHA-256
ToolInstallation    find → download → verify → unpack → run `--version` → put in place
ToolStore           ~/Library/Application Support/PolarBear/Tools/{bin, <tool>/<version>}; ToolLocator searches bin first
ToolInstaller       @Observable state per tool for the install buttons (ToolInstallControl)
```

Nothing runs until the user presses an install button. A file whose checksum does not match is deleted, never installed.

## Agents

```
AgentCatalog   finds claude / codex / opencode / gemini, stores model and effort per agent
AgentAdapter   one per CLI: builds the argument array, parses the output into AgentEvents
AgentStaging   temporary copy of the sources (no secrets) + polarbear-report/{problems.txt,compile.log}
AgentRunner    runs the CLI in that copy, streams events, can be cancelled
AgentModel     conversation + the AgentReview: changes as hunks, kept or undone one by one
```

Nothing an agent does touches the real files until the user keeps a hunk; a version is recorded before and after.
Every prompt carries the latest `BuildReport`, because the agent works in a copy and cannot compile.

## The editor

`Editor/CodeEditor` wraps an AppKit `NSTextView` (TextKit 1) for SwiftUI. Highlighting is incremental: only the
edited lines and the lines whose state (math, code fence) changed are re-coloured. Languages live in `Editor/Syntax`.
At most six live editors are kept (`EditorContainerView`); caret and scroll are restored when one is recreated.

## Look and feel

* Colours, spacing, radii, sizes and timings come from `DesignSystem/AppTheme`; every colour is a light/dark pair.
* The UI is solid — no glass or material — with continuous corners everywhere.
* The window has no title bar: `Window/WindowChromeController` centres the window buttons on the first row.

`Scripts/lint.sh` enforces most of these conventions.

## The PolarBear Engine

`engine/polarbear` is a separate Rust crate with no dependencies. The app talks to it through the command-line
program `polarbear-engine` (`compile`, `status`); the crate also exports a C ABI for a possible in-process future.
Its typesetting core is under construction — see [`engine/polarbear/ROADMAP.md`](engine/polarbear/ROADMAP.md).
