-- Options panel (Esc > Options > AddOns > norabu_bars). Opened with /nb or /norabubars.
-- Plain widgets on a scrolling canvas; every change is saved and applied live.
local ADDON, NB = ...

local Options = {}
NB.Options = Options

local widgets = {}
local function RefreshAll()
  for _, w in ipairs(widgets) do w.Refresh() end
end
Options.RefreshAll = RefreshAll

-- Small widget kit --------------------------------------------------------

local function Label(parent, x, y, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function Header(parent, y, text)
  local fs = Label(parent, 10, y, text, "GameFontNormalLarge")
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(.5, .5, .5, .5)
  line:SetPoint("TOPLEFT", 10, y - 24)
  line:SetSize(570, 1)
  return fs
end

local function Button(parent, x, y, width, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT", x, y)
  b:SetSize(width, 24)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function Checkbox(parent, x, y, text, get, set)
  local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  b:SetPoint("TOPLEFT", x, y)
  b:SetSize(26, 26)
  if text ~= "" then
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 4, 0)
    fs:SetText(text)
  end
  b:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  widgets[#widgets + 1] = { Refresh = function() b:SetChecked(get()) end }
  return b
end

-- `label` may be nil (table rows draw their own caption).
local function Slider(parent, x, y, label, min, max, step, suffix, width, get, set)
  local top = y
  if label then
    Label(parent, x, y, label, "GameFontNormalSmall")
    top = y - 22
  end
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", x, top)
  s:SetWidth(width)
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  if s.Low then s.Low:SetText("") end
  if s.High then s.High:SetText("") end
  if s.Text then s.Text:SetText("") end
  local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  value:SetPoint("LEFT", s, "RIGHT", 10, 0)
  local refreshing = false
  s:SetScript("OnValueChanged", function(_, v)
    if refreshing then return end
    v = math.floor(v / step + .5) * step
    value:SetText(v .. suffix)
    set(v)
  end)
  widgets[#widgets + 1] = {
    Refresh = function()
      refreshing = true
      local v = get()
      s:SetValue(v)
      value:SetText(v .. suffix)
      refreshing = false
    end,
  }
  return s
end

-- Colour swatch that opens Blizzard's colour picker. `get` returns {r, g, b}; `set(r, g, b)` saves.
local function Swatch(parent, x, y, label, get, set)
  Label(parent, x, y, label, "GameFontNormalSmall")
  local b = CreateFrame("Button", nil, parent)
  b:SetPoint("TOPLEFT", x, y - 20)
  b:SetSize(48, 20)
  local border = b:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()
  border:SetColorTexture(.55, .55, .55, 1)
  local fill = b:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  local function paint()
    local c = get()
    fill:SetColorTexture(c.r, c.g, c.b, 1)
  end
  b:SetScript("OnClick", function()
    local c = get()
    local old = { r = c.r, g = c.g, b = c.b }
    local function accept()
      local r, g, bl = ColorPickerFrame:GetColorRGB()
      set(r, g, bl)
      paint()
    end
    local function cancel()
      set(old.r, old.g, old.b)
      paint()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        r = old.r, g = old.g, b = old.b, hasOpacity = false, swatchFunc = accept, cancelFunc = cancel,
      })
    else
      ColorPickerFrame.hasOpacity = false
      ColorPickerFrame.previousValues = { old.r, old.g, old.b }
      ColorPickerFrame.func = accept
      ColorPickerFrame.cancelFunc = cancel
      ColorPickerFrame:SetColorRGB(old.r, old.g, old.b)
      ColorPickerFrame:Hide()
      ColorPickerFrame:Show()
    end
  end)
  widgets[#widgets + 1] = { Refresh = paint }
  return b
end

-- Panel content ------------------------------------------------------------

local function Build(content)
  local db = function() return NB.db end

  Header(content, -10, "General")
  Button(content, 10, -42, 150, "Reset to defaults", function()
    NB.ResetDB()
    NB.ApplyAll()
    RefreshAll()
    if NB.EditMode then NB.EditMode.Refresh() end
  end)
  Button(content, 170, -42, 110, "Reload UI", function() ReloadUI() end)

  Header(content, -82, "Backdrop")
  Slider(content, 10, -116, "Darkness", 0, 100, 5, "%", 200,
    function() return db().darkness end,
    function(v)
      db().darkness = v
      NB.ApplyAll()
    end)
  Slider(content, 300, -116, "Extra margin around the slots", 0, 16, 1, " px", 200,
    function() return db().margin end,
    function(v)
      db().margin = v
      NB.ApplyAll()
    end)
  Swatch(content, 10, -172, "Tint colour",
    function() return db().tint end,
    function(r, g, b)
      db().tint.r, db().tint.g, db().tint.b = r, g, b
      NB.ApplyAll()
    end)

  Header(content, -214, "Bars")
  Label(content, 10, -246, "Bar", "GameFontNormalSmall")
  Label(content, 230, -246, "Dark theme", "GameFontNormalSmall")
  Label(content, 330, -246, "Opacity", "GameFontNormalSmall")
  local y = -266
  for _, el in ipairs(NB.ELEMENTS) do
    local key = el.key
    Label(content, 10, y - 5, el.label, "GameFontHighlight")
    if not el.noBackdrop then
      Checkbox(content, 246, y, "",
        function() return NB.El(key).enabled end,
        function(v)
          NB.El(key).enabled = v
          NB.ApplyAll()
        end)
    end
    Slider(content, 330, y - 6, nil, 10, 100, 5, "%", 190,
      function() return NB.El(key).opacity end,
      function(v)
        NB.Backdrop.SetOpacity(key, v)
        if NB.EditMode then NB.EditMode.Refresh() end
      end)
    y = y - 28
  end

  y = y - 14
  Header(content, y, "Buttons")
  y = y - 36
  Checkbox(content, 10, y, "Hide the native cast / interrupt animation",
    function() return db().buttons.hideCastAnim end,
    function(v)
      db().buttons.hideCastAnim = v
      NB.Buttons.Apply()
    end)
  y = y - 30
  Checkbox(content, 10, y, "Classic framed slots instead of Blizzard's button frame art",
    function() return db().buttons.outline end,
    function(v)
      db().buttons.outline = v
      NB.Buttons.Apply()
    end)
  y = y - 30
  Checkbox(content, 10, y, "Dark square behind every button",
    function() return db().buttons.slots end,
    function(v)
      db().buttons.slots = v
      NB.Buttons.Apply()
    end)
  y = y - 30
  Slider(content, 36, y, "Square darkness", 0, 100, 5, "%", 200,
    function() return db().buttons.slotAlpha end,
    function(v)
      db().buttons.slotAlpha = v
      NB.Buttons.Apply()
    end)
  y = y - 58
  Checkbox(content, 10, y, "Tint the icon red out of range, blue without enough mana / energy",
    function() return db().buttons.rangeMana end,
    function(v)
      db().buttons.rangeMana = v
      NB.Buttons.Apply()
    end)
  y = y - 30
  Checkbox(content, 10, y, "Press flash (star burst when a button is pressed)",
    function() return db().buttons.flash end,
    function(v) db().buttons.flash = v end)
  y = y - 34
  Swatch(content, 36, y, "Flash colour",
    function() return db().buttons.flashColor end,
    function(r, g, b)
      local c = db().buttons.flashColor
      c.r, c.g, c.b = r, g, b
    end)
  y = y - 54

  local note = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", 10, y)
  note:SetWidth(560)
  note:SetJustifyH("LEFT")
  note:SetText("Opacity can also be set in Edit Mode: select a bar, the bag bar or the micro menu and use the Opacity row. "
    .. "Buttons that hold nothing are hidden by Blizzard, so they get no square: turn on \"Always Show Buttons\" for the bar in Edit Mode to see a square on every slot. "
    .. "Open this panel any time with /nb or /norabubars.")
  content:SetHeight(-y + note:GetStringHeight() + 30)
end

-- Registration -------------------------------------------------------------

function Options.Init()
  if Options.category or not NB.db then return end
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local panel = CreateFrame("Frame")
  panel.name = "norabu_bars"
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -30, 8)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(600, 900)
  scroll:SetScrollChild(content)

  -- built on first show so bars added by other addons (Bartender4 ...) are already known
  local built = false
  local function Show()
    if not built then
      built = true
      Build(content)
    end
    RefreshAll()
  end
  panel:SetScript("OnShow", Show)
  content:SetScript("OnShow", Show)
  panel.OnRefresh = RefreshAll
  panel.OnCommit = function() end
  panel.OnDefault = function() end

  local category = Settings.RegisterCanvasLayoutCategory(panel, "norabu_bars")
  Settings.RegisterAddOnCategory(category)
  Options.category = category
end

function Options.Open()
  Options.Init()
  if Options.category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(Options.category:GetID())
    RefreshAll()
  else
    print("|cffffd200norabu_bars:|r the Settings panel is not available on this client.")
  end
end

SLASH_NORABUBARS1 = "/nb"
SLASH_NORABUBARS2 = "/norabubars"
SlashCmdList.NORABUBARS = function(msg)
  msg = msg and msg:lower() or ""
  if msg:match("^%s*debug") then
    NB.Backdrop.Debug()
  elseif msg:match("^%s*align") then
    local on = NB.Backdrop.Align()
    if on then
      print("|cffffd200norabu_bars:|r alignment overlay on: |cff00ff00green|r = icon, |cffff0000red|r = button frame, |cff00ffffcyan|r = allotted box. /nb align again to turn it off.")
    else
      print("|cffffd200norabu_bars:|r alignment overlay off.")
    end
  else
    Options.Open()
  end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() Options.Init() end)
