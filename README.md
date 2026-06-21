# SciteMe

SciteMe is an unofficial Windows x64 and ARM64 build and installer project for SciTE, the lightweight editor built on Scintilla and Lexilla.

The purpose is narrow: provide modern Windows build infrastructure, clean Visual Studio integration, and proper installers while keeping the upstream SciTE, Scintilla, and Lexilla source dumps as untouched as possible.

## What This Project Provides

- Visual Studio 2026 (VS18) `.slnx` based builds.
- MSBuild projects for x64 and ARM64.
- Debug and Release configurations.
- A reproducible staged application payload.
- MSI installers generated through MSIS, plus a multi-architecture bundle installer.
- base16 colour themes for the editor (20 palettes, selectable at runtime).
- Optional Explorer integration such as an `Edit with SciTE` context menu.

## What This Project Is Not

SciteMe is not an official SciTE distribution. It is not a macOS port, and it does not try to replace upstream SciTE development. The upstream author’s source remains the foundation; this project focuses on Windows build and packaging infrastructure around it.

## Color Themes

SciteMe ships 20 [base16](https://github.com/chriskempson/base16) colour palettes (Tokyo Night, Gruvbox, Nord, Solarized, Catppuccin, Dracula, and more) under `theme/palettes/`.

- Open the picker with **Tools → Choose Colour Theme...** (`Ctrl+Shift+Y`). Click or press Enter on an entry to apply it; start typing to filter the list.
- A **(factory defaults)** entry restores SciTE's stock styling at any time.
- The chosen theme is remembered across sessions.

Themes are applied programmatically through SciTE's built-in Lua extension (`theme/theme.lua`, wired in via `theme/theme.properties`), so the upstream source dumps stay untouched. Theming covers the editor and output panes; the Windows window chrome (title bar, menus) is left to the OS.

## Current Status

This repository is in early build-and-package infrastructure mode. The source dumps are present under:

```text
scite563/
wscite563/
```

The Visual Studio 2026 (VS18) `.slnx` wrapper exists for `x64` and `ARM64` Debug/Release builds. The `justfile` can build and run locally, and cut a full release (both-architecture MSIs plus the multi-architecture bundle). CMake and PowerShell scripts are intentionally out of scope.

## Target Platforms

Initial platform support:

```text
Windows x64
Windows ARM64
```

x86 may be added later if there is enough practical demand.

## Installer Direction

Installers are generated with MSIS, which produces WiX-based MSI packages from concise `.msis` manifests. The current outputs are standalone x64 and ARM64 MSI packages (each with a VC++ runtime launch condition) plus a multi-architecture bundle `.exe` that selects the correct package for the target machine.

Installer goals include:

- clean install and uninstall;
- Start menu shortcut;
- an optional "Launch SciTE" button on the bundle's final page;
- optional Explorer context menu integration;
- no aggressive file association takeover by default.

## Code Signing

The first usable builds may be unsigned. If so, releases should publish SHA256 hashes and exact build instructions. Longer term, the project will evaluate OSS-friendly signing options such as SignPath Foundation, Microsoft Artifact Signing, or conventional Authenticode certificates.

## Relationship To Upstream

SciTE, Scintilla, and Lexilla are upstream projects by Neil Hodgson and contributors. SciteMe should clearly identify itself as an unofficial Windows community build and packaging layer. Upstream source changes should be avoided unless they are small, necessary, and documented.

## Build Experience

Build recipes require a **Visual Studio 2026 Developer Command Prompt / Developer PowerShell** (so `msbuild` is on `PATH`); `release` also needs MSIS 3.x. The `justfile` exposes two workflows — build for this machine, or cut a full release:

```text
# Develop on this machine
just run          # build Debug and launch (fast; no staged themes)
just run-staged   # stage the Release payload (incl. themes) and launch it
just build        # build Debug only
just rebuild      # clean, then build Debug

# Cut a release (always both architectures)
just release      # x64 + ARM64 MSIs and the multi-arch bundle, into setup\

just clean        # remove bin\, temp\, dist\
```

Per-architecture sub-steps are internal helpers, kept out of `just --list` on purpose: building selectively for an architecture you are not on is not a workflow.

The intended IDE workflow is opening `SciteMe.slnx` in Visual Studio 2026 (VS18), selecting `x64` or `ARM64`, and building or debugging `SciTE.exe` directly.
