local ADDON, NB = ...

NB.name = ADDON
NB.media = "Interface\\AddOns\\" .. ADDON .. "\\media\\"

-- Elements ------------------------------------------------------------------
-- One element = one thing you can theme and fade (a bar, the bag bar, the micro menu ...).
--   frames  candidate frames, native first. Every one that exists gets a backdrop and the
--           opacity, so a third-party bar addon that replaces a native bar is covered too
--           (a native bar that gets hidden takes its backdrop with it).
--   alias   extra frames that map to this element when Edit Mode selects them
--   art     the native bar art (gryphons, background strip) is hidden when the theme is on
--   noBackdrop  opacity only: no dark theme for this element (micro menu, bag bar, status bars)
--   buttons prefix/count of the buttons, `base` = action slot offset of a fixed bar,
--           `main` = paged main bar, `noAction` = stance / pet (no range or mana state)
NB.ELEMENTS = {
  { key = "main", label = "Main action bar", art = true,
    frames = { "MainActionBar", "MainMenuBar", "EABBar_MainBar" },
    buttons = { prefix = "ActionButton", count = 12, main = true } },
  { key = "bl", label = "Bottom left bar", art = true,
    frames = { "MultiBarBottomLeft", "EABBar_Bar2" },
    buttons = { prefix = "MultiBarBottomLeftButton", count = 12, base = 60 } },
  { key = "br", label = "Bottom right bar", art = true,
    frames = { "MultiBarBottomRight", "EABBar_Bar3" },
    buttons = { prefix = "MultiBarBottomRightButton", count = 12, base = 48 } },
  { key = "right", label = "Right bar", art = true,
    frames = { "MultiBarRight", "EABBar_Bar4" },
    buttons = { prefix = "MultiBarRightButton", count = 12, base = 24 } },
  { key = "left", label = "Left bar", art = true,
    frames = { "MultiBarLeft", "EABBar_Bar5" },
    buttons = { prefix = "MultiBarLeftButton", count = 12, base = 36 } },
  { key = "bar5", label = "Action bar 5", art = true,
    frames = { "MultiBar5", "EABBar_Bar6" },
    buttons = { prefix = "MultiBar5Button", count = 12, base = 144 } },
  { key = "bar6", label = "Action bar 6", art = true,
    frames = { "MultiBar6", "EABBar_Bar7" },
    buttons = { prefix = "MultiBar6Button", count = 12, base = 156 } },
  { key = "bar7", label = "Action bar 7", art = true,
    frames = { "MultiBar7", "EABBar_Bar8" },
    buttons = { prefix = "MultiBar7Button", count = 12, base = 168 } },
  { key = "stance", label = "Stance bar", art = true,
    frames = { "StanceBar", "EABBar_StanceBar" },
    buttons = { prefix = "StanceButton", count = 10, noAction = true } },
  { key = "pet", label = "Pet bar", art = true,
    frames = { "PetActionBar", "EABBar_PetBar" },
    buttons = { prefix = "PetActionButton", count = 10, noAction = true } },
  { key = "micro", label = "Micro menu", frames = { "MicroMenu" }, alias = { "MicroMenuContainer" }, noBackdrop = true },
  { key = "bags", label = "Bag bar", frames = { "BagsBar" }, noBackdrop = true },
  { key = "status1", label = "Experience / reputation bar", frames = { "MainStatusTrackingBarContainer" }, noBackdrop = true },
  { key = "status2", label = "Second status bar", frames = { "SecondaryStatusTrackingBarContainer" }, noBackdrop = true },
}

-- Third-party bars that are not stand-ins for a native bar get an element of their own, but
-- only if the addon is there. Bartender4 names its bars BT4Bar<id>; the Dominos names are a
-- best guess and do nothing if they do not exist. Only backdrop and opacity apply to these.
local EXTRA_SOURCES = {
  { prefix = "BT4Bar", label = "Bartender4: ", ids = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, "StanceBar", "PetBar", "MicroMenu", "BagBar" } },
  { prefix = "DominosFrame", label = "Dominos: ", ids = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, "pet", "class", "menu", "bags" } },
}

local extras = {}
function NB.DiscoverExtras()
  for _, source in ipairs(EXTRA_SOURCES) do
    for _, id in ipairs(source.ids) do
      local name = source.prefix .. id
      local frame = _G[name]
      if not extras[name] and type(frame) == "table" and frame.GetObjectType then
        local label = type(id) == "number" and ("Bar " .. id) or tostring(id)
        extras[name] = { key = "ext:" .. name, label = source.label .. label, frames = { name }, extra = true }
        table.insert(NB.ELEMENTS, extras[name])
      end
    end
  end
end

-- Saved variables -----------------------------------------------------------

local DEFAULTS = {
  darkness = 55,            -- 0 = the art as Blizzard draws it, 100 = black
  margin = 0,               -- extra dark margin around the allotted box
  tint = { r = 1, g = 1, b = 1 },
  elements = {},            -- [key] = { enabled = true, opacity = 100 }
  buttons = {
    hideCastAnim = true,    -- hide the native cast / interrupt animation on buttons
    outline = true,         -- classic framed slots instead of Blizzard's button frame art
    slots = false,          -- extra dark square behind every button (the art already has a dark slot)
    slotAlpha = 40,
    rangeMana = true,       -- icon tinted red out of range, blue without enough resource
    flash = true,           -- star-burst when a button is pressed
    flashColor = { r = 1, g = 1, b = 1 },
  },
}
NB.DEFAULTS = DEFAULTS

local function Merge(db, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(db[key]) ~= "table" then db[key] = {} end
      Merge(db[key], value)
    elseif db[key] == nil then
      db[key] = value
    end
  end
end

function NB.ResetDB()
  for key in pairs(NB.db) do NB.db[key] = nil end
  Merge(NB.db, DEFAULTS)
end

-- Per-element settings, filled in on first use.
function NB.El(key)
  local list = NB.db.elements
  local e = list[key]
  if type(e) ~= "table" then
    e = {}
    list[key] = e
  end
  if e.enabled == nil then e.enabled = true end
  if type(e.opacity) ~= "number" then e.opacity = 100 end
  return e
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  NorabuBarsDB = NorabuBarsDB or {}
  local fresh = next(NorabuBarsDB) == nil
  local version = NorabuBarsDB.dbVersion or 1
  Merge(NorabuBarsDB, DEFAULTS)
  NorabuBarsDB.padding = nil -- replaced by `margin`
  if not fresh and version < 2 then
    -- the framed slot art made the extra dark square redundant: off unless switched on again
    NorabuBarsDB.buttons.slots = false
    NorabuBarsDB.buttons.slotAlpha = 40
  end
  NorabuBarsDB.dbVersion = 2
  NB.db = NorabuBarsDB
  self:UnregisterEvent("ADDON_LOADED")
end)

-- Protected ("secret") values ----------------------------------------------

local issecret = issecretvalue or function() return false end
local canaccess = canaccessvalue or function() return true end

function NB.Readable(value)
  return not issecret(value) and canaccess(value)
end

-- Frames ---------------------------------------------------------------------

-- Every existing, distinct frame of an element.
function NB.Frames(el)
  local list, seen = {}, {}
  for _, name in ipairs(el.frames) do
    local frame = _G[name]
    if type(frame) == "table" and frame.GetObjectType and not seen[frame]
        and not (frame.IsForbidden and frame:IsForbidden()) then
      seen[frame] = true
      list[#list + 1] = frame
    end
  end
  return list
end

-- The element a frame belongs to (Edit Mode hands us the native system frame).
function NB.ElementForFrame(frame)
  for _, el in ipairs(NB.ELEMENTS) do
    for _, name in ipairs(el.frames) do
      if _G[name] == frame then return el end
    end
    if el.alias then
      for _, name in ipairs(el.alias) do
        if _G[name] == frame then return el end
      end
    end
  end
end

-- Hiding native art ----------------------------------------------------------
-- Reversible alpha pin: while pinned the region snaps back to 0 whenever Blizzard changes its
-- alpha; unpinning puts back the alpha it had. Show / Hide calls do not matter for alpha.

local pinned = setmetatable({}, { __mode = "k" })

function NB.Pin(region, on)
  if not region or not region.SetAlpha then return end
  local state = pinned[region]
  if not state then
    if not on then return end
    local alpha = region:GetAlpha()
    state = { alpha = NB.Readable(alpha) and alpha or 1 }
    pinned[region] = state
    hooksecurefunc(region, "SetAlpha", function(self)
      if state.on and not state.guard then
        state.guard = true
        self:SetAlpha(0)
        state.guard = false
      end
    end)
  end
  state.on = on and true or false
  state.guard = true
  region:SetAlpha(state.on and 0 or state.alpha)
  state.guard = false
end

-- Applying -----------------------------------------------------------------

function NB.ApplyAll()
  if not NB.db then return end
  if NB.Backdrop then NB.Backdrop.Apply() end
  if NB.Buttons then NB.Buttons.Apply() end
end

local queued = false
function NB.Queue()
  if queued then return end
  queued = true
  C_Timer.After(0, function()
    queued = false
    NB.ApplyAll()
  end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED",
    "UPDATE_BONUS_ACTIONBAR", "ADDON_LOADED" }) do
  events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
  if not NB.db then return end
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
    NB.DiscoverExtras()
  end
  NB.Queue()
end)

if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("EditMode.Enter", NB.Queue, NB)
  EventRegistry:RegisterCallback("EditMode.Exit", NB.Queue, NB)
end
