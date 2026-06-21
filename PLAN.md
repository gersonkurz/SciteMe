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

## Architecture (hybrid, split by layer)

- **Palettes**: `theme/palettes/*.yaml` -- the 20 base16 YAML files, copied into
  this repo (no external dependency on `environ`). Format: `palette.base00..0F`.
- **Global default/background/UI + live switching**: a Lua applier
  (`theme/theme.lua`) using the `STYLE_DEFAULT` + `StyleClearAll()` idiom, hooked
  on `OnOpen`/`OnSwitchFile` (which run after SciTE's property styling, so the
  hook wins). A Tools command cycles palettes.
- **Per-lexer token colors**: generated `.properties` (Tier 2), produced by a
  Python 3.14 / `uv` generator that reads `theme/palettes/*.yaml` and per-lexer
  mapping tables. (Properties is the native multi-lexer format.)
- **Chrome (title bar etc.)**: deferred, optional, upstream patch only with
  explicit sign-off. A single `DwmSetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE)`
  call is the cheap high-value piece; dark menus/toolbar are deep diminishing
  returns.

## Status / tiers

- **Tier 1 (done, spike)**: `theme/theme.lua` + `theme/theme.properties`, wired
  into staging (`justfile` `_stage` copies them; `just run-staged` stages and
  launches). Embeds 3 palettes, maps the cpp + python lexers, uniform base for
  everything else, Tools > Cycle Colour Theme (Ctrl+Shift+T). Proves the
  mechanism end to end.
- **Tier 2 (next)**: Python/`uv` generator -> all 20 palettes + per-lexer tables
  for the ~25 commonly used languages; Lua menu lists palettes by name; persist
  the active theme. Optional: follow OS light/dark via the existing
  `CheckAppearanceChanged()` reload.
- **Tier 3 (optional)**: remaining lexers, polish, and (only if approved) the
  title-bar dark-mode patch.

## Testing

`just run-staged` (stages Release payload incl. theme files and launches the
staged `SciTE.exe`). Open a `.cpp` and a `.py` file, confirm dark base16
styling; press Ctrl+Shift+T to cycle tokyo-night-dark -> gruvbox-dark-hard ->
solarized-light. `just run` (bin\ Debug) does not include the staged
`.properties`/theme files, so use `run-staged` for theme verification.
