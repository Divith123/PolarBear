# Contributing to PolarBear

Thank you for helping. Bug reports, ideas and pull requests are all welcome.

## Before you start

* **Small fixes** (typos, a clear bug): open a pull request directly.
* **Anything bigger** (a feature, a refactor, a new dependency): open an issue first so we can agree on the approach
  before you spend time on it.
* **Security problems:** please do not open a public issue; see [`SECURITY.md`](SECURITY.md).

By contributing you agree that your work is released under the [MIT License](LICENSE).

## Setting up

You need a Mac with the Xcode version that ships the macOS 27 SDK, and optionally [Tectonic](https://tectonic-typesetting.github.io)
(the app can install it itself, or `brew install tectonic`) and a stable Rust toolchain for the engine.

```sh
git clone <repository-url> PolarBear
cd PolarBear
open PolarBear.xcodeproj      # choose your own Team under Signing & Capabilities, then ⌘R
```

The Xcode project uses a file-system-synchronized group: add a file to `PolarBear/` and it is part of the target.

Useful commands:

| Command | What it does |
| --- | --- |
| `bash Scripts/lint.sh` | Checks the source conventions below (also run by CI) |
| `Scripts/install.sh` | Builds a Release app with the engine inside and installs it in `/Applications` |
| `python3 Scripts/make_dmg.py` | Builds `dist/PolarBear.dmg` (development-signed) |
| `Scripts/release.sh [--no-notarize] [--publish]` | Maintainers: signs with Developer ID, notarises, staples, and optionally creates the GitHub release. `--no-notarize` builds a development-signed release for people without a Developer ID |
| `Scripts/get-polarbear.sh` | What users run to install a release from Terminal without the "unidentified developer" prompt |
| `cd engine/polarbear && cargo build --release` | Builds the PolarBear Engine |

Read [`ARCHITECTURE.md`](ARCHITECTURE.md) first if you are new to the code.

## How the code is written

Run `bash Scripts/lint.sh` before you push; it enforces most of this.

**Structure**
* One top-level type per file, grouped in feature folders. No Swift files loose in `PolarBear/`.
* Extract subviews as their own `View` structs rather than `some View` helper properties. Keep `body` short; logic lives
  in methods or models.
* Rows and subviews receive only the values they read, not a whole model.
* Window-specific state goes in `WorkspaceModel`, shared state in `Project`.

**Look and feel**
* The UI is solid: no `Material`, glass effects, `NSVisualEffectView`, or translucent windows.
* Take colours, spacing, radii, sizes and timings from `AppTheme` (add a token, with both light and dark values, rather
  than writing a hex value or `.white` / `.black` in a view). Text uses semantic styles, not fixed point sizes.
* Every window, sheet and popover applies the theme with `.appAppearance()`.
* Rounded rectangles use `style: .continuous`; AppKit layers set `cornerCurve = .continuous`.
* Icon-only controls have a text title (`Button("Title", systemImage:)` with `.labelStyle(.iconOnly)`), decorative symbols
  are hidden from accessibility, and animations respect *Reduce Motion*.

**Swift**
* Modern SwiftUI/Observation APIs: `@Observable` with `@State` / `@Bindable` / `@Environment`, `foregroundStyle`,
  `clipShape(.rect(cornerRadius:))`, two-parameter `onChange`, `Button` instead of `onTapGesture`.
* No `GeometryReader` (use `onGeometryChange`), `AnyView`, force `try!` / `as!`, or `Binding(get:set:)` in views.
* Concurrency: no `DispatchQueue` (the FSEvents folder watcher is the one exception), no `Task.sleep(nanoseconds:)`;
  use `.task(id:)` for debounced work and handle `CancellationError` on purpose. Work that must not run on the main actor is
  `nonisolated` / `@concurrent`.
* User-facing text goes straight into `Text` / `Button` / `Label` (or `String(localized:)`), so it can be localised.
* Log recoverable failures with `Logger` instead of swallowing them.

**Safety**
* Run programs with an argument array, never through a shell string.
* Anything that unpacks an archive or writes outside the project must validate its paths.
* Agents work in a staged copy and never write to the project directly.

**Dependencies**
* PolarBear has no third-party packages and aims to keep it that way. If you think one is needed, open an issue first.

## Checking your change

There is no automated test suite yet; changes are verified by building and using the app (and, for logic, by small
throw-away programs that are not committed). If you would like to add a test target, please open an issue first so
we can agree on the approach.

Before you open a pull request:

1. The app builds **without warnings**.
2. `bash Scripts/lint.sh` passes.
3. You ran the app and used what you changed. Say in the pull request what you tried and what you could not.

## The PolarBear Engine

`engine/polarbear` is a clean-room implementation. Please do not copy code from other TeX implementations (TeX,
XeTeX, LuaTeX, Tectonic, …) into it, and do not port from source you have read closely; build behaviour from the
specifications and from observing the reference output. Every file carries the project's copyright header. See
[`engine/polarbear/ROADMAP.md`](engine/polarbear/ROADMAP.md) for the plan.

## Commit messages and pull requests

* A short summary line in the imperative ("Fix SyncTeX offset on retina displays"), then a blank line and the reason
  for the change if it is not obvious.
* Keep pull requests focused; unrelated clean-ups belong in their own pull request.
