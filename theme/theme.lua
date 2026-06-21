-- SciteMe base16 theming -- Tier 1 spike (programmatic Scintilla styling)
--
-- Loaded via ext.lua.startup.script (see theme.properties). It applies a
-- base16 palette to the editor pane through SciTE's Lua interface, using the
-- STYLE_DEFAULT + StyleClearAll idiom proven in ptraced-qt: set one base
-- foreground/background, propagate it to all 256 styles, then re-color the
-- semantic tokens on top. Because OnOpen/OnSwitchFile run *after* SciTE has
-- applied the property-file styles, this hook always wins.
--
-- This spike embeds three palettes and maps the cpp/python lexers. The Tier 2
-- generator (Python via uv) will emit the full palette set from the repo's
-- theme/palettes/*.yaml plus per-lexer mapping tables for the common languages.

-- Scintilla predefined style numbers (Scintilla.h)
local STYLE_DEFAULT     = 32
local STYLE_LINENUMBER  = 33
local STYLE_BRACELIGHT  = 34
local STYLE_BRACEBAD    = 35
local STYLE_INDENTGUIDE = 37

-- ---------------------------------------------------------------------------
-- base16 palettes (verbatim from theme/palettes/*.yaml in this repo)
-- ---------------------------------------------------------------------------
local palettes = {
  ["tokyo-night-dark"] = {
    base00="#1a1b26", base01="#16161e", base02="#2f3549", base03="#444b6a",
    base04="#787c99", base05="#a9b1d6", base06="#cbccd1", base07="#d5d6db",
    base08="#c0caf5", base09="#a9b1d6", base0A="#0db9d7", base0B="#9ece6a",
    base0C="#b4f9f8", base0D="#2ac3de", base0E="#bb9af7", base0F="#f7768e",
  },
  ["gruvbox-dark-hard"] = {
    base00="#1d2021", base01="#3c3836", base02="#504945", base03="#665c54",
    base04="#bdae93", base05="#d5c4a1", base06="#ebdbb2", base07="#fbf1c7",
    base08="#fb4934", base09="#fe8019", base0A="#fabd2f", base0B="#b8bb26",
    base0C="#8ec07c", base0D="#83a598", base0E="#d3869b", base0F="#d65d0e",
  },
  ["solarized-light"] = {
    base00="#fdf6e3", base01="#eee8d5", base02="#93a1a1", base03="#839496",
    base04="#657b83", base05="#586e75", base06="#073642", base07="#002b36",
    base08="#dc322f", base09="#cb4b16", base0A="#b58900", base0B="#859900",
    base0C="#2aa198", base0D="#268bd2", base0E="#6c71c4", base0F="#d33682",
  },
}

-- Cycle order for the Tools > Cycle Colour Theme command.
local order = { "tokyo-night-dark", "gruvbox-dark-hard", "solarized-light" }
local current = "tokyo-night-dark"

-- ---------------------------------------------------------------------------
-- Semantic role -> base16 slot (the standard base16 syntax mapping)
-- ---------------------------------------------------------------------------
local roleSlot = {
  comment   = "base03",
  string    = "base0B",
  number    = "base09",
  keyword   = "base0E",
  keyword2  = "base0C",
  operator  = "base05",
  preproc   = "base0F",
  type      = "base0A",
  ["function"] = "base0D",
  error     = "base08",
}

-- Per-lexer style-number -> role tables.
-- Style numbers are Lexilla's SCE_* values for each lexer (stable across builds).
local maps = {
  cpp = {
    [1]="comment", [2]="comment", [3]="comment", [4]="number", [5]="keyword",
    [6]="string",  [7]="string",  [9]="preproc", [10]="operator",
    [12]="string", [15]="comment", [16]="keyword2", [17]="comment",
    [19]="type",   [20]="type",
  },
  python = {
    [1]="comment", [2]="number", [3]="string", [4]="string", [5]="keyword",
    [6]="string",  [7]="string", [8]="type",   [9]="function", [10]="operator",
    [12]="comment", [13]="string", [14]="keyword2", [15]="function",
  },
}

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

-- "#rrggbb" -> Scintilla colour integer 0xBBGGRR
local function bgr(hex)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  return r + g * 256 + b * 65536
end

local function applyTheme(name)
  local p = palettes[name]
  if not p then return end

  local bg = bgr(p.base00)
  local fg = bgr(p.base05)

  -- Uniform base everywhere, then propagate. This wipes the light-mode
  -- hardcoded colours that lexer .properties files would otherwise leave.
  editor.StyleBack[STYLE_DEFAULT] = bg
  editor.StyleFore[STYLE_DEFAULT] = fg
  editor:StyleClearAll()

  -- Editor chrome that lives inside the Scintilla pane.
  editor.CaretFore = fg
  editor.CaretLineBack = bgr(p.base01)
  editor:SetSelBack(true, bgr(p.base02))
  editor:SetSelFore(false, 0)
  editor:SetWhitespaceFore(true, bgr(p.base03))
  editor.StyleBack[STYLE_LINENUMBER] = bgr(p.base01)
  editor.StyleFore[STYLE_LINENUMBER] = bgr(p.base04)
  editor:SetFoldMarginColour(true, bgr(p.base01))
  editor:SetFoldMarginHiColour(true, bgr(p.base01))
  editor.StyleFore[STYLE_INDENTGUIDE] = bgr(p.base03)
  editor.StyleFore[STYLE_BRACELIGHT] = bgr(p.base0A)
  editor.StyleBold[STYLE_BRACELIGHT] = true
  editor.StyleFore[STYLE_BRACEBAD] = bgr(p.base08)

  -- Per-lexer semantic colours (Tier 1: cpp + python; rest stays monochrome).
  local m = maps[editor.LexerLanguage]
  if m then
    for styleNum, role in pairs(m) do
      local slot = roleSlot[role]
      if slot then
        editor.StyleFore[styleNum] = bgr(p[slot])
        if role == "keyword" then editor.StyleBold[styleNum] = true end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- SciTE extension hooks + Tools command
-- ---------------------------------------------------------------------------

-- Re-apply after SciTE has set up the lexer for the (new) buffer.
function OnOpen(path)        applyTheme(current) return false end
function OnSwitchFile(path)  applyTheme(current) return false end

-- Bound to Tools > Cycle Colour Theme (see theme.properties).
function cycle_theme()
  for i, name in ipairs(order) do
    if name == current then
      current = order[(i % #order) + 1]
      break
    end
  end
  applyTheme(current)
  editor:Colourise(0, -1)
  print("SciteMe theme: " .. current)
end

-- Apply once at startup for the initial buffer.
applyTheme(current)
