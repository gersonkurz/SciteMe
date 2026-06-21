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

# Color Theming (base16)

Goal: give SciteMe selectable base16 color themes, reusing the palette set and
semantic-mapping design already proven in `environ` and `ptraced-qt`, without
patching the upstream source dumps.

## Key constraints discovered

- **No C++ changes needed for the content area.** Lua is compiled into this
  build (`LuaExtension.cxx`, full `lua/src`), so the editor pane can be styled
  programmatically via `editor.StyleFore[n]`, `editor:StyleClearAll()`, etc.
- **The two Scintilla panes (editor + output) are fully themeable; the Win32
  chrome is not.** Title bar, menu bar, toolbar, tab bar, status-bar background,
  and scrollbars are OS/Win32-drawn. SciTE 5.6.3 has no dark-chrome code
  (`CheckAppearanceChanged()` only calls `ReloadProperties()`). Theming them
  means patching upstream C++ and is explicitly out of scope unless approved.
- **`import *` in the upstream `SciTEGlobal.properties` auto-loads any
  `*.properties` dropped next to `SciTE.exe`**, so theme wiring requires no edit
  to the upstream dump.
- **Per-lexer color mapping is the real cost, independent of delivery
  mechanism.** Lexer `.properties` files inline hex per style rather than using
  the ~15 central `colour.*` variables (e.g. python/json/markdown use the
  central palette zero times), so a per-lexer style-number -> base16-slot table
  is required regardless of whether colors are delivered as properties or Lua.

## Architecture (all in Lua; no generator, no upstream edits)

- **Palettes**: `theme/palettes/*.yaml` -- the 20 base16 YAML files, copied into
  this repo (no external dependency on `environ`). They are the single source of
  truth and are parsed at runtime by `theme.lua` (flat `base0X: "#hex"`, ~10
  lines of Lua) -- no build step and no transcription.
- **Styling + switching**: `theme/theme.lua` uses the `STYLE_DEFAULT` +
  `StyleClearAll()` idiom, hooked on `OnOpen`/`OnSwitchFile` (which run after
  SciTE's property styling, so the hook wins). Per-lexer semantic colors are
  hand-authored Lua `maps` tables (style number -> base16 role).
- **Picker**: an autocompletion-style list (`editor:UserListShow`), led by a
  "(factory defaults)" entry. Clicking or Entering an item applies *and persists*
  it immediately (`setTheme` folds in `saveState`); typing filters. A SciTE
  user-strip combo was tried first but abandoned: `Strips.cxx`'s
  `NotificationToStripCommand` ignores `CBN_SELCHANGE`, so dropdown selections
  are never reported to Lua (only typing fires `change`). `UserListShow`'s
  `OnUserListSelection` fires reliably on click.
- **Factory defaults**: selecting "(factory defaults)" calls
  `scite.ReloadProperties()` to restore SciTE's own property-file styling and
  sets `current` to a sentinel so the hooks stop re-theming (`applyTheme`
  no-ops on any non-palette name). Persisted like any other choice.
- **Persistence**: the active theme name (or the factory sentinel) is written to
  `$(SciteUserHome)/sciteme-theme.txt` and restored at startup.
- **Chrome (title bar, menus, toolbar, status bar)**: out of scope -- decided
  panes-only to keep zero upstream edits. The Win32 frame stays OS-drawn. (If
  revisited, the cheap high-value piece is a `DwmSetWindowAttribute(
  DWMWA_USE_IMMERSIVE_DARK_MODE)` patch: link `dwmapi.lib` in the wrapper
  `SciTE.vcxproj` + ~10 lines in `scite563` `SciTEWin.cxx` -- an upstream edit
  needing explicit sign-off.)

## Why no Python/uv generator

The generator's only job was emitting `.properties`. Styling is done
programmatically in Lua instead, so that output is unnecessary: palettes are
read straight from the YAML at runtime, and per-lexer maps are hand-authored
knowledge a generator cannot synthesize anyway.

## Status

- **Done**: `theme/theme.lua` + `theme/theme.properties`, staged via `justfile`
  `_stage` (`just run-staged` stages + launches). Loads all 20 palettes from
  `theme/palettes/`, maps the cpp + python lexers (uniform base for the rest),
  Tools > Choose Colour Theme... (Ctrl+Shift+Y, UserListShow list incl. factory
  defaults; click/Enter applies), persists the active theme.
- **Next**: extend `maps` to the ~25 commonly used lexers (bash, sql, lua, json,
  css/html, yaml, rust, go, markdown, ...). Optional: follow OS light/dark via
  the existing `CheckAppearanceChanged()` reload; chain a pre-existing user
  startup script rather than overriding `ext.lua.startup.script`.

## Testing

`just run-staged` (stages Release payload incl. theme files + palettes and
launches the staged `SciTE.exe`). Open a `.cpp` and a `.py`, confirm base16
styling; Ctrl+Shift+Y opens the list (click/Enter applies, incl. factory
defaults). Re-launch to confirm the last theme persisted.
`just run` (bin\ Debug)
omits the staged theme files, so use `run-staged` for verification.
