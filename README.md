# SciteMe

SciteMe is an unofficial Windows x64 and ARM64 build and installer project for SciTE, the lightweight editor built on Scintilla and Lexilla.

The purpose is narrow: provide modern Windows build infrastructure, clean Visual Studio integration, and proper installers while keeping the upstream SciTE, Scintilla, and Lexilla source dumps as untouched as possible.

## What This Project Provides

- Visual Studio 18 `.slnx` based builds.
- MSBuild projects for x64 and ARM64.
- Debug and Release configurations.
- A reproducible staged application payload.
- MSI installers generated through MSIS.
- Optional Explorer integration such as an `Edit with SciTE` context menu.

## What This Project Is Not

SciteMe is not an official SciTE distribution. It is not a macOS port, and it does not try to replace upstream SciTE development. The upstream author’s source remains the foundation; this project focuses on Windows build and packaging infrastructure around it.

## Current Status

This repository is in early build-and-package infrastructure mode. The source dumps are present under:

```text
scite563/
wscite563/
```

The Visual Studio 18 `.slnx` wrapper exists for `x64` and `ARM64` Debug/Release builds. The `justfile` can build, stage, and invoke MSIS for per-platform MSI packages. CMake and PowerShell scripts are intentionally out of scope.

## Target Platforms

Initial platform support:

```text
Windows x64
Windows ARM64
```

x86 may be added later if there is enough practical demand.

## Installer Direction

Installers are generated with MSIS, which produces WiX-based MSI packages from concise `.msis` manifests. The current outputs are standalone x64 and ARM64 MSI packages with a VC++ runtime launch condition; prerequisite bootstrapper and multi-architecture bundles are deferred.

Installer goals include:

- clean install and uninstall;
- Start menu shortcut;
- optional Explorer context menu integration;
- no aggressive file association takeover by default.

## Code Signing

The first usable builds may be unsigned. If so, releases should publish SHA256 hashes and exact build instructions. Longer term, the project will evaluate OSS-friendly signing options such as SignPath Foundation, Microsoft Artifact Signing, or conventional Authenticode certificates.

## Relationship To Upstream

SciTE, Scintilla, and Lexilla are upstream projects by Neil Hodgson and contributors. SciteMe should clearly identify itself as an unofficial Windows community build and packaging layer. Upstream source changes should be avoided unless they are small, necessary, and documented.

## Planned Build Experience

The current command-line workflow is:

```text
just build
just release
just build-all
just stage
just stage-all
just package
just package-all
```

The intended IDE workflow is opening `SciteMe.slnx` in Visual Studio 18, selecting `x64` or `ARM64`, and building or debugging `SciTE.exe` directly.
