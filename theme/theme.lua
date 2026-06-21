-- SciteMe base16 theming (programmatic Scintilla styling via SciTE's Lua)
--
-- Loaded via ext.lua.startup.script (see theme.properties). Applies a base16
-- palette to the editor pane using the STYLE_DEFAULT + StyleClearAll idiom:
-- set one base fg/bg, propagate to all styles, then re-color semantic tokens.
-- OnOpen/OnSwitchFile run after SciTE's property styling, so this hook wins.
--
-- Palettes are read at runtime from palettes/*.yaml (single source of truth;
-- no generator/build step). A bottom strip provides a picker with live preview,
-- and the active theme is persisted to the user profile across sessions.
--
-- Scope: the two Scintilla panes only. The Win32 chrome (title bar, menus,
-- toolbar, status bar) is OS-drawn and intentionally left untouched.

-- Scintilla predefined style numbers (Scintilla.h)
local STYLE_DEFAULT     = 32
local STYLE_LINENUMBER  = 33
local STYLE_BRACELIGHT  = 34
local STYLE_BRACEBAD    = 35
local STYLE_INDENTGUIDE = 37

-- Palette files shipped under palettes/ (sorted; matches the repo set).
local themeNames = {
  "catppuccin-latte", "catppuccin-macchiato", "catppuccin-mocha", "dracula",
  "everforest-dark-hard", "gruvbox-dark-hard", "gruvbox-light-hard", "monokai",
  "nord", "one-light", "onedark", "rose-pine", "rose-pine-dawn",
  "solarized-dark", "solarized-light", "tokyo-night-dark", "tomorrow",
  "tomorrow-night", "tomorrow-night-blue", "tomorrow-night-eighties",
}

-- Embedded fallback so the editor still themes if palettes/ is unavailable
-- (e.g. `just run` from bin\ rather than the staged payload).
local fallback = {
  base00="#1a1b26", base01="#16161e", base02="#2f3549", base03="#444b6a",
  base04="#787c99", base05="#a9b1d6", base06="#cbccd1", base07="#d5d6db",
  base08="#c0caf5", base09="#a9b1d6", base0A="#0db9d7", base0B="#9ece6a",
  base0C="#b4f9f8", base0D="#2ac3de", base0E="#bb9af7", base0F="#f7768e",
}

-- Standard base16 syntax mapping: semantic role -> palette slot.
local roleSlot = {
  comment="base03", string="base0B", number="base09", keyword="base0E",
  keyword2="base0C", operator="base05", preproc="base0F", type="base0A",
  ["function"]="base0D", error="base08",
}

-- Per-lexer style-number -> role tables (Lexilla SCE_* values).
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

local palettes = {}              -- name -> { base00=.., .. }
local current = "tokyo-night-dark"

-- Sentinel "theme" meaning: disable our styling and let SciTE's own
-- property-file styles show through (scite.ReloadProperties()).
local FACTORY = "(factory defaults)"

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

-- Parse a flat base16 YAML (lines like: base0A: "#rrggbb").
local function loadPalette(name)
  local dir = props["SciteDefaultHome"]
  if not dir or dir == "" then return nil end
  local f = io.open(dir .. "/palettes/" .. name .. ".yaml", "r")
  if not f then return nil end
  local p = {}
  for line in f:lines() do
    local slot, hex = line:match('(base0[0-9A-Fa-f])%s*:%s*"?(#%x%x%x%x%x%x)"?')
    if slot then p[slot] = hex end
  end
  f:close()
  if p.base00 and p.base05 then return p end
  return nil
end

local function loadAllPalettes()
  for _, name in ipairs(themeNames) do
    local p = loadPalette(name)
    if p then palettes[name] = p end
  end
  if not next(palettes) then palettes["tokyo-night-dark"] = fallback end
end

local function sortedNames()
  local t = {}
  for n in pairs(palettes) do t[#t + 1] = n end
  table.sort(t)
  return t
end

-- ---- persistence: remember the active theme in the user profile ----
local function statePath()
  local home = props["SciteUserHome"]
  if not home or home == "" then home = props["SciteDefaultHome"] end
  if not home or home == "" then return nil end
  return home .. "/sciteme-theme.txt"
end

local function loadState()
  local path = statePath(); if not path then return end
  local f = io.open(path, "r"); if not f then return end
  local name = (f:read("*l") or ""):gsub("%s+$", "")
  f:close()
  if name == FACTORY or palettes[name] then current = name end
end

local function saveState()
  local path = statePath(); if not path then return end
  local f = io.open(path, "w"); if not f then return end
  f:write(current .. "\n"); f:close()
end

-- ---------------------------------------------------------------------------
-- styling
-- ---------------------------------------------------------------------------
local function applyTheme(name)
  local p = palettes[name]; if not p then return end
  local bg, fg = bgr(p.base00), bgr(p.base05)

  editor.StyleBack[STYLE_DEFAULT] = bg
  editor.StyleFore[STYLE_DEFAULT] = fg
  editor:StyleClearAll()

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

-- Commit a user choice: apply it live AND persist it. (Persisting here, rather
-- than behind a separate Apply button, is what lets the picker drop Apply --
-- every change sticks immediately.)
local function setTheme(name)
  if name == FACTORY then
    current = FACTORY
    scite.ReloadProperties()   -- restore SciTE's own property-file styling
    editor:Colourise(0, -1)
  elseif palettes[name] then
    current = name
    applyTheme(current)
    editor:Colourise(0, -1)
  else
    return
  end
  saveState()
end

-- ---------------------------------------------------------------------------
-- picker: an autocompletion-style list (UserListShow).
--   A SciTE user-strip combo does NOT report dropdown selections to Lua
--   (Strips.cxx ignores CBN_SELCHANGE; only typing fires a change), so a list
--   is the reliable click-to-apply control. OnUserListSelection fires on click
--   or Enter; typing filters. The list is led by FACTORY.
-- ---------------------------------------------------------------------------
local LIST_TYPE = 17   -- tag to identify our list in OnUserListSelection

function choose_theme()
  local names = sortedNames()
  table.insert(names, 1, FACTORY)
  -- Names sort with "(" before letters, so FACTORY-first matches the presorted
  -- order autocomplete expects. Use "|" since FACTORY contains a space.
  editor.AutoCSeparator = string.byte("|")
  editor:UserListShow(LIST_TYPE, table.concat(names, "|"))
end

function OnUserListSelection(listType, selection)
  if listType == LIST_TYPE then
    setTheme(selection)   -- applies + persists; no-ops on unknown text
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- hooks + commands
-- ---------------------------------------------------------------------------
-- On a fresh file open, SciTE's async completion calls ReadProperties (which
-- re-applies the light property-file styles) *after* OnOpen, with no trailing
-- hook -- so styling here alone gets clobbered. We also flag a deferred
-- re-style that runs on the next OnUpdateUI, which fires after that final
-- ReadProperties, so our theme wins regardless of open/switch path.
local needsRestyle = false

function OnOpen(path)       applyTheme(current) needsRestyle = true return false end
function OnSwitchFile(path) applyTheme(current) needsRestyle = true return false end

function OnUpdateUI()
  if needsRestyle then
    needsRestyle = false
    applyTheme(current)
  end
  return false
end

-- ---- startup ----
-- The editor pane is not accessible while the startup script runs, so don't
-- style here. Flag a re-style instead: the first OnUpdateUI (or OnOpen for a
-- file passed on the command line) applies the theme once the pane exists.
loadAllPalettes()
loadState()
if current ~= FACTORY and not palettes[current] then current = sortedNames()[1] end
-- In factory mode we never style, so SciTE's own property styling stands as-is.
needsRestyle = true
