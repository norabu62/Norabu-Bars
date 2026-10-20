-- Opacity row inside Blizzard's Edit Mode settings dialog. Selecting a bar, the bag bar or the
-- micro menu in Edit Mode shows an extra "Opacity" slider among its settings. The dialog is
-- only observed (AttachToSystemFrame is post-hooked) and the row is an ordinary child of its
-- Settings layout frame. If that layout does not take the row, it is docked below the dialog.
local ADDON, NB = ...

local EditMode = {}
NB.EditMode = EditMode

local row, slider, valueText
local hooked, docked = false, false
local currentKey
local refreshing = false

local function Build(dialog)
  local parent = dialog.Settings or dialog
  row = CreateFrame("Frame", nil, parent)
  row:SetSize(320, 32)
  row:Hide()

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.bg:Hide()

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", row, "LEFT", 12, 0)
  label:SetText("Opacity")

  slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
  slider:SetPoint("LEFT", row, "LEFT", 100, 0)
  slider:SetSize(150, 16)
  slider:SetMinMaxValues(10, 100)
  slider:SetValueStep(5)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  if slider.Low then slider.Low:SetText("") end
  if slider.High then slider.High:SetText("") end
  if slider.Text then slider.Text:SetText("") end

  valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)

  slider:SetScript("OnValueChanged", function(_, value)
    if refreshing or not currentKey then return end
    value = math.floor(value / 5 + .5) * 5
    valueText:SetText(value .. "%")
    NB.Backdrop.SetOpacity(currentKey, value)
    if NB.Options and NB.Options.RefreshAll then NB.Options.RefreshAll() end
  end)
end

local function Relayout(dialog)
  local settings = dialog.Settings
  if settings and settings.Layout then pcall(settings.Layout, settings) end
  if dialog.Layout then pcall(dialog.Layout, dialog) end
end

-- The layout frame did not place the row inside the dialog: put it under the dialog instead.
local function Dock(dialog)
  docked = true
  row:SetParent(dialog)
  row.layoutIndex = nil
  row:ClearAllPoints()
  row:SetPoint("TOP", dialog, "BOTTOM", 0, -6)
  row.bg:SetColorTexture(.05, .05, .05, .92)
  row.bg:Show()
  Relayout(dialog)
end

function EditMode.Refresh()
  if not (row and currentKey) then return end
  local value = NB.El(currentKey).opacity
  refreshing = true
  slider:SetValue(value)
  valueText:SetText(value .. "%")
  refreshing = false
end

local function OnAttach(dialog, systemFrame)
  local el = systemFrame and NB.ElementForFrame(systemFrame)
  if not el then
    currentKey = nil
    if row then
      row:Hide()
      Relayout(dialog)
    end
    return
  end
  if not row then Build(dialog) end
  currentKey = el.key
  EditMode.Refresh()
  if not docked then row.layoutIndex = 1000 end
  row:Show()
  Relayout(dialog)
  if not docked then
    -- once the layout has run, the row must sit inside the dialog
    C_Timer.After(.05, function()
      if not row:IsShown() or docked then return end
      local dialogBottom, rowBottom = dialog:GetBottom(), row:GetBottom()
      if not (dialogBottom and rowBottom and rowBottom >= dialogBottom - 1) then Dock(dialog) end
    end)
  end
end

local function TryHook()
  if hooked then return end
  local dialog = _G.EditModeSystemSettingsDialog
  if not (dialog and dialog.AttachToSystemFrame) then return end
  hooked = true
  hooksecurefunc(dialog, "AttachToSystemFrame", OnAttach)
  if dialog.attachedToSystem and dialog:IsShown() then OnAttach(dialog, dialog.attachedToSystem) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function() TryHook() end)
if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("EditMode.Enter", TryHook, EditMode)
end
