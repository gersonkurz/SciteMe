# SciteMe Upgrade Plan

This file tracks the one process that still matters after the initial build and installer infrastructure: moving SciteMe to a newer upstream SciTE, Scintilla, and Lexilla release while keeping the local wrapper layer reviewable.

## Upgrade Rule

Keep upstream imports and SciteMe infrastructure changes separate. The source dumps under `scite563/` and `wscite563/` are treated as upstream-owned content; avoid local edits there unless there is an explicit, documented patch.

## Upgrade Checklist

1. Download the matching upstream SciTE/Scintilla/Lexilla source archive and Windows package archive.
2. Replace the upstream dump contents in a dedicated commit, with no wrapper or installer changes mixed in.
3. If the folder names change, update references to `scite563/` and `wscite563/` in wrapper-owned files only:
   - `*.vcxproj`
   - `*.vcxproj.filters`
   - `SciteMe.props`
   - `justfile`
   - `setup/*.msis`
   - `README.md` and `AGENTS.md` where relevant
4. Review upstream file additions/removals and adjust explicit Visual Studio item lists. Do not reintroduce wildcard project items.
5. Update product/version metadata in the MSIS manifests and bundle manifest.
6. Rebuild and stage both supported platforms:

```cmd
just build-x64
just build-arm64
just stage-x64
just stage-arm64
```

7. Build release installers:

```cmd
just release
```

8. Install-test the generated x64 and ARM64 packages. Confirm:
   - `SciTE.exe`, `Scintilla.dll`, and `Lexilla.dll` come from `bin\<Platform>\Release\`;
   - non-binary runtime files come from `wscite563/wscite`;
   - optional features still work, including Explorer integration, debug symbols, and `Gerson Preferences`;
   - uninstall removes installed files and registry entries.

## Local Patches

If an upstream source change becomes unavoidable, keep it small and document it in the commit message. Prefer wrapper-side fixes in project files, MSIS manifests, staging rules, or documentation.

## Release Notes

For each upgrade, record the upstream version, supported platforms, installer filenames, and SHA-256 hashes. Code signing remains optional and is currently deferred.
