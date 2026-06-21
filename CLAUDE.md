# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SciteMe is an unofficial Windows build and packaging layer for SciTE (a lightweight code editor built on Scintilla and Lexilla). It provides Visual Studio integration, multi-architecture builds (x64/ARM64), and MSIS-based MSI installers while keeping upstream source dumps untouched.

## Build Commands

Requires: `just` command runner, Visual Studio 2022 with MSBuild, and MSIS 3.x at `C:\NGBT\MSIS\msis-3.x` (for packaging only).

```
just                    # List all recipes
just build              # Debug build for native platform
just build-x64          # Debug build for x64
just build-arm64        # Debug build for ARM64
just release-x64        # Release build for x64
just release-arm64      # Release build for ARM64
just build-all          # Debug+Release for both platforms
just run                # Build Debug and launch SciTE.exe
just stage-all          # Stage release payloads for both platforms
just package-all        # Build MSI packages for both platforms
just bundle             # Build multi-arch bundle executable
just release            # package-all + bundle (full release)
just clean              # Remove bin/, temp/, dist/
```

IDE workflow: open `SciteMe.slnx` in Visual Studio 18, select platform (x64/ARM64) and configuration (Debug/Release).

## Testing

No automated test suite. Verification is manual: build both platforms, launch SciTE.exe, inspect staged payloads in `dist/stage/{Platform}/`, test MSI install/uninstall. When modifying Lexilla lexer behavior, run relevant lexer tests under `scite563/lexilla/test/` and preserve `.styled`/`.folded` expectation files.

## Architecture

### Source Layout

- `scite563/` - **Upstream source dump** (SciTE, Scintilla, Lexilla v5.6.3). Treat as read-only unless an explicit patch is approved.
- `wscite563/` - **Upstream Windows package reference**. Read-only. Files are copied into staged payloads.
- Root `*.vcxproj` files - **Wrapper projects** that compile upstream sources without modifying them.
- `setup/` - MSIS installer manifests (`.msis`), registry integration, optional preference files.
- `dist/stage/{Platform}/` - Staged release payloads (upstream files + locally-built binaries).
- `bin/{Platform}/{Configuration}/` - Compiled binaries (SciTE.exe, Scintilla.dll, Lexilla.dll).
- `temp/` - Intermediate object files.

### Build Outputs

SciTE.exe links against Scintilla.dll and Lexilla.dll. The staging process copies everything from `wscite563/wscite/` then overwrites the three binaries with locally-built versions from `bin/`.

### Key Files

| File | Purpose |
|------|---------|
| `SciteMe.slnx` | VS18 solution (x64 + ARM64) |
| `SciteMe.props` | Shared MSBuild properties (output paths, compiler flags) |
| `SciTE.vcxproj` | Main app (C++20, links Scintilla/Lexilla) |
| `Scintilla.vcxproj` | Editor engine DLL (C++17) |
| `Lexilla.vcxproj` | Lexer DLL (C++17, 100+ language lexers) |
| `Package.vcxproj` | Utility project for packaging orchestration |
| `justfile` | All build/stage/package automation |

## Repository Rules

These constraints come from AGENTS.md and must be followed:

- **Do not introduce CMake or PowerShell scripts.** Use MSBuild projects and `justfile` only. If scripting is needed, use Python 3.14+ via `uv`.
- **Do not edit files under `scite563/` or `wscite563/`** unless the user explicitly approves. These are upstream source dumps.
- **Do not use wildcard items in `.vcxproj` files.** Keep explicit file lists for diffability during upstream upgrades.
- **Do not rename upstream products.** Use installer/display text to clarify this is an unofficial build.
- **Commit messages**: concise imperative form with prefix (`build:`, `setup:`, `docs:`, `test:`). No co-author trailers, no generated-by text, no agent advertising.

## Upstream Upgrade Process

When upgrading to a new SciTE/Scintilla/Lexilla version (detailed in PLAN.md):

1. Replace upstream dump contents in a dedicated commit (no wrapper changes mixed in).
2. Update folder references in wrapper files: `*.vcxproj`, `SciteMe.props`, `justfile`, `setup/*.msis`.
3. Adjust explicit file lists in `.vcxproj` for any added/removed source files.
4. Update version metadata in MSIS manifests.
5. Build, stage, and test both x64 and ARM64.
