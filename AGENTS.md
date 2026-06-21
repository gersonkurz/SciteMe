# Repository Guidelines

## Project Purpose

SciteMe is intended to be an unofficial Windows build, packaging, and installer layer for SciTE, Scintilla, and Lexilla. The goal is to make modern Windows x64 and ARM64 builds easy to produce and install while leaving upstream source dumps intact. This project is not a macOS port and should not be framed as competing with upstream commercial macOS work.

## Source Layout

Treat `scite563/` as the upstream source bundle and `wscite563/` as the upstream Windows binary/package reference. Avoid editing files under these directories unless the user explicitly approves an upstream patch. Wrapper project files, packaging manifests, release metadata, and automation belong at the repository root or in project-owned folders such as `setup/`, `dist/`, `bin/`, and `temp/`.

Expected future layout:

```text
SciteMe.slnx
*.vcxproj
justfile
setup/
bin/
temp/
dist/
scite563/
wscite563/
```

## Build System Rules

Do not introduce CMake. Use Visual Studio 18 `.slnx` and MSBuild project files. Target `Debug|x64`, `Release|x64`, `Debug|ARM64`, and `Release|ARM64` first; defer x86 unless there is a specific need. Follow the `environ` repository pattern: `bin\$(Platform)\$(Configuration)\` for outputs and `temp\$(Platform)\$(Configuration)\$(ProjectName)\` for intermediates.

Use a `justfile` for routine automation. Do not create PowerShell scripts. If scripting becomes necessary beyond `just`, use Python 3.14 or newer via `uv`.

## Packaging

Use MSIS for installer generation, not hand-authored WiX as the primary interface. The local reference implementation is at `C:\NGBT\MSIS\msis-3.x`. Produce separate x64 and ARM64 MSI packages, then optionally a multi-architecture bundle EXE. Explorer integration should be registry-driven through MSIS inputs and should avoid aggressive file association takeover.

## Coding Style

Wrapper project files should be explicit, stable, and easy to diff during upstream upgrades. Prefer ASCII text files. Keep naming consistent with Visual Studio/MSBuild conventions and use `SciteMe` for this project name. Do not rename upstream products inside their source; use installer/display text to clarify that this is an unofficial Windows community build.

## Testing & Verification

At minimum, verify x64 and ARM64 Release builds, launch `SciTE.exe`, and inspect the staged payload before building installers. When changing Lexilla behavior, run the relevant lexer tests and preserve `.styled`/`.folded` expectations. Record exact `just`, `msbuild`, and `msis` commands in release notes.

## Commit & PR Guidance

Use concise imperative commits such as `build: add VS18 solution wrapper` or `setup: add arm64 installer manifest`. Keep commit messages short and specific to the change. Do not include agent advertising, co-author trailers, generated-by text, or similar promotional metadata in commit messages. PRs should describe platform coverage, installer behavior, upstream version, and any files intentionally changed under `scite563/`.
