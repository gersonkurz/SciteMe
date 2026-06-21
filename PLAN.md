# SciteMe Implementation Plan

SciteMe will provide modern Windows build and installer infrastructure around the upstream SciTE, Scintilla, and Lexilla source dumps. The core rule is that upstream folders stay as close to pristine source archives as possible; our work lives around them.

## Goals

- Build SciTE for Windows x64 and Windows ARM64 with Visual Studio 18.
- Use `.slnx` and MSBuild project files, not CMake.
- Provide Debug and Release configurations that work from Visual Studio and from the command line.
- Stage clean install payloads outside the upstream folders.
- Build MSI installers with MSIS, including Explorer integration.
- Keep the upstream upgrade path small and reviewable.

## Non-Goals

- No macOS target, branding, or packaging.
- No CMake.
- No PowerShell scripts.
- No source rewrite of SciTE, Scintilla, or Lexilla.
- No default x86 commitment until there is a real user need.

## Proposed Repository Layout

```text
SciteMe.slnx
SciteMe.props
Lexilla.vcxproj
Scintilla.vcxproj
SciTE.vcxproj
Package.vcxproj
justfile
README.md
PLAN.md
AGENTS.md
setup/
  sciteme-x64.msis
  sciteme-arm64.msis
  sciteme-bundle.msis
  registry/
bin/
temp/
dist/
scite563/
wscite563/
```

`scite563/` contains the upstream source dump. `wscite563/` is useful as a reference for the official Windows package contents, but our build should generate its own staged payload.

## Phase 1: Repository Baseline

Status: complete.

1. Initialize Git in the final repository folder.
2. Add `.gitignore` for `bin/`, `temp/`, `dist/`, Visual Studio state, generated MSI/WXS/WIXPDB files, and local tool caches.
3. Commit the upstream source dump and initial documentation separately from build infrastructure.
4. Keep `AGENTS.md`, `README.md`, and `PLAN.md` current as decisions change.

## Phase 2: Visual Studio 18 Build Wrapper

Status: complete for the initial build wrapper. The `.slnx`, wrapper projects, shared props, and Visual Studio filters exist for x64 and ARM64 builds; staging and installer behavior remain later phases.

Create `SciteMe.slnx` with projects for `Lexilla`, `Scintilla`, `SciTE`, and packaging. Use `v145`, Unicode, and Windows desktop targets.

Initial configurations:

```text
Debug|x64
Release|x64
Debug|ARM64
Release|ARM64
```

Output conventions:

```text
bin\<Platform>\<Configuration>\
temp\<Platform>\<Configuration>\<ProjectName>\
```

Project responsibilities:

- `Lexilla.vcxproj`: build `Lexilla.dll` from `scite563/lexilla`.
- `Scintilla.vcxproj`: build `Scintilla.dll` from `scite563/scintilla`.
- `SciTE.vcxproj`: build `SciTE.exe` from `scite563/scite` and depend on the two DLL projects.
- `Package.vcxproj`: utility target for staging and invoking MSIS, if useful from the IDE.

The wrapper projects may point directly into upstream source files. They should not emit intermediates into upstream directories.

## Phase 3: Just-Based Automation

Status: in progress. Build automation exists for native, x64, ARM64, and full-matrix MSBuild invocations. Staging should be added next; package and bundle recipes are deferred until the staged payload and MSIS manifests are defined.

Add a `justfile` modeled after the `environ` pattern.

Candidate recipes:

```text
just build          # Debug, native platform
just release        # Release, native platform
just build-all      # Debug/Release for x64 and ARM64
just stage          # copy release payload into dist/stage/<platform>
just clean
```

Use plain command-line tools inside recipes: `msbuild` and `xcopy`/`robocopy` if needed. Add `msis.exe` recipes only after the payload and installer manifests exist. If logic outgrows `just`, add a Python 3.14+ script run through `uv`; do not add PowerShell.

## Phase 4: Payload Staging

Status: next.

Stage the installed application folder from two sources:

- built binaries from `bin\<Platform>\Release\`;
- non-binary payload files and folders from `wscite563/wscite`.

Default staged binaries:

- `SciTE.exe`
- `Scintilla.dll`
- `Lexilla.dll`

The `wscite563/wscite` tree is the layout template for properties, documentation, images, and other runtime support files. Do not copy upstream binaries from it into the final payload; overlay the three binaries produced by the current build instead. Add an optional debug-symbol payload, likely as a separate staging or installer feature, that includes matching `.pdb` files.

Candidate output layout:

```text
dist/stage/x64/
dist/stage/ARM64/
```

## Phase 5: Installer With MSIS

Status: deferred until Phase 4 produces a stable staged payload.

Create one `.msis` per platform and one optional bundle manifest:

- `setup/sciteme-x64.msis`
- `setup/sciteme-arm64.msis`
- `setup/sciteme-bundle.msis`

Installer behavior:

- Install to a clear product folder such as `SciteMe` or `SciTE Windows Community Build`.
- Add a Start menu shortcut.
- Optionally add Explorer context menu entries such as `Edit with SciTE`.
- Avoid taking ownership of common source file extensions by default.
- Provide clean uninstall.

If the MSVC runtime is required dynamically, use MSIS `<requires type="vcredist" version="2022"/>` and bundle support. If static runtime is chosen, document that choice and keep the payload smaller.

MSIS can consume both individual built files and staged folders. Prefer pointing platform MSIs at the staged payload once Phase 4 is stable. The multi-architecture bundle should remain deferred until the x64 and ARM64 MSI package manifests are working.

## Phase 6: Verification

For each release candidate:

1. Build `Release|x64` and `Release|ARM64`.
2. Confirm file architecture for each binary.
3. Launch SciTE from the staged folder.
4. Run available unit or lexer tests where affected.
5. Build MSI packages.
6. Test install and uninstall on clean Windows x64 and Windows ARM64 environments.
7. Check Explorer integration behavior.

## Phase 7: Signing and Release Provenance

Start unsigned if necessary, but publish SHA256 hashes and build instructions. Keep signing as a documented release enhancement.

Options:

- No signing: cheapest, but SmartScreen warnings are expected.
- SignPath Foundation: likely best open-source-compatible option if the project qualifies.
- Microsoft Artifact Signing: managed signing with Azure infrastructure, but likely not free.
- Commercial OV/EV certificate: conventional, costly, and operationally heavier.
- Sigstore/cosign: useful for provenance, but not a substitute for Windows Authenticode trust.

## Phase 8: Upstream Upgrade Process

For a new SciTE/Scintilla/Lexilla release:

1. Import the new upstream source dump into `scite563/`.
2. Do not mix wrapper changes with the source import commit.
3. Re-run build-all and installer verification.
4. Update source file lists in wrapper projects only where necessary.
5. Document any unavoidable local patch under a clear patch section.

## Open Questions

- Final install display name: `SciteMe` vs `SciTE Windows Community Build`.
- Runtime strategy: dynamic MSVC runtime plus prerequisite bundle vs static runtime.
- Whether to ship documentation exactly like upstream Windows package or a trimmed payload.
- Whether Explorer integration is enabled by default or exposed as an optional feature.
- Whether x86 is intentionally unsupported or postponed.
