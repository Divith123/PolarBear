# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

First public version.

### Added
- Native macOS editor for LaTeX and Markdown projects stored as ordinary folders.
- Compiling with Tectonic, latexmk or a TeX distribution; Problems list, SyncTeX in both directions, last good PDF kept on failure.
- Markdown projects rendered natively to PDF: tables, footnotes, alerts, maths (MathML), Mermaid diagrams (SVG), coloured code, web images; download as Markdown/PDF and copy as rich text, HTML or plain text.
- Version history with diffs and restore.
- **Install buttons** for Tectonic and OpenCode: when one is missing, PolarBear offers to download it from its official GitHub release, verify the SHA-256, test it and keep it in `~/Library/Application Support/PolarBear/Tools` (removable from Settings). Nothing is downloaded until the button is pressed.
- `Scripts/get-polarbear.sh`: installs a release from Terminal, checksum-verified, without the "unidentified developer" prompt.
- A disk image with only the app and the Applications link visible: system folders (`.fseventsd`, `.Spotlight-V100`, …) are removed and the layout files are hidden.
- Optional AI agents (Claude Code, Codex, OpenCode, Gemini) working in a staged copy, with per-hunk review and *Fix with AI* for build problems.
- Light and dark themes, first-run profile, launch window.
- The PolarBear Engine (Rust), shipped inside the app; its typesetting core is not finished yet.
