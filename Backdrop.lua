-- Backdrops: one dark panel per bar with the same soft black border as norabu_frames. The panel
-- is a non-interactive child of the bar at BACKGROUND strata, so it follows the bar's Edit Mode
-- position / visibility / opacity, and it is sized to the bar's allotted box (the shown buttons'
-- frames). Buttons are never moved or reparented.
--
-- The classic slot art (a piece of Blizzard's main-bar strip, from the client) is drawn per button
-- by Buttons.lua, anchored straight to each icon so it cannot drift. This file owns the strip's
-- geometry and tint (Backdrop.Piece, Backdrop.Color) so both sides agree.
local ADDON, NB = ...

local Backdrop = {}
NB.Backdrop = Backdrop

-- The strip is 256x43 and holds one framed slot every 42 pixels. Measured from screenshots of
-- the client's art: the frame is about 1.8px thick and the dark interior about 38.4 px, and the
-- slot separators (the frame's ornaments) sit at x = 5 + 42k, so a 42px window starting on one of
-- them is exactly one slot with a symmetric frame. A piece is that window over the strip's full height.
local STRIP_W = 256
local PIECE_INDEX = 2           -- which slot of the strip is the picture (0 = first)
Backdrop.Piece = {
  path = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf",
  u0 = (5 + 42 * PIECE_INDEX) / STRIP_W,
  u1 = (5 + 42 * PIECE_INDEX + 42) / STRIP_W,
  v0 = .83203125,               -- the 256x43 strip's top and bottom inside the client texture
  v1 = 1,
}

-- Strip colour after the user's darkness and tint settings.
function Backdrop.Color()
  local db = NB.db
  local shade = 1 - math.min(100, math.max(0, db.darkness)) / 100
  local t = db.tint
  return t.r * shade, t.g * shade, t.b * shade
end

local BORDER = 3                -- visible thickness of the soft border
local BORDER_INSET = 1          -- border's inner edge overlaps the art (no seam)
local MIN_SIZE = 8              -- smaller than this and the border would be a blob: hide it

local panels = setmetatable({}, { __mode = "k" })
local panelList = {}

-- Soft black border ---------------------------------------------------------
-- Nine-slice built from media/border.tga (64x64: 16-texel corners, 32-texel straight edges, a
-- ring 8 texels thick starting 3 texels in). Same texture and maths as norabu_frames.

local function CreateBorder(parent, target, T, inset)
  local path = NB.media .. "border.tga"
  local off = T * 11 / 8 - (inset or 0)
  local corner = T * 2
  local q, h = 16 / 64, 48 / 64
  local pieces = {}
  local function piece(l, r, t, b)
    local tex = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    tex:SetTexture(path)
    tex:SetTexCoord(l, r, t, b)
    pieces[#pieces + 1] = tex
    return tex
  end
  local tl = piece(0, q, 0, q)
  tl:SetSize(corner, corner)
  tl:SetPoint("TOPLEFT", target, "TOPLEFT", -off, off)
  local tr = piece(h, 1, 0, q)
  tr:SetSize(corner, corner)
  tr:SetPoint("TOPRIGHT", target, "TOPRIGHT", off, off)
  local bl = piece(0, q, h, 1)
  bl:SetSize(corner, corner)
  bl:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -off, -off)
  local br = piece(h, 1, h, 1)
  br:SetSize(corner, corner)
  br:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", off, -off)

  local top = piece(q, h, 0, q)
  top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
  top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
  local bottom = piece(q, h, h, 1)
  bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
  bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
  local left = piece(0, q, q, h)
  left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
  left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
  local right = piece(h, 1, q, h)
  right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
  right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
  return pieces
end
Backdrop.CreateBorder = CreateBorder

-- Measuring -------------------------------------------------------------------

-- Left, right, bottom, top in UIParent units, plus the region's scale relative to UIParent.
local function Rect(region)
  local ok, l, r, b, t, s = pcall(function()
    local scale
    if region.GetEffectiveScale then
      scale = region:GetEffectiveScale()
    else
      local parent = region:GetParent()
      scale = parent and parent:GetEffectiveScale()
    end
    return region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop(), scale
  end)
  if not ok then return end
  local ui = UIParent:GetEffectiveScale()
  if not (NB.Readable(l) and NB.Readable(r) and NB.Readable(b) and NB.Readable(t) and NB.Readable(s)) then return end
  if not (l and r and b and t and s and ui and ui > 0 and s > 0) then return end
  local f = s / ui
  return l * f, r * f, b * f, t * f, f
end

local function IconOf(button)
  local icon = button.icon or button.Icon
  if not icon and button.GetName and button:GetName() then icon = _G[button:GetName() .. "Icon"] end
  return icon
end

local function Inside(button, frame)
  local f = button:GetParent()
  for _ = 1, 8 do
    if not f then return false end
    if f == frame then return true end
    f = f.GetParent and f:GetParent()
  end
  return false
end

-- Panel ---------------------------------------------------------------------

local function Create(frame, el)
  local p = CreateFrame("Frame", nil, frame)
  p.frame, p.el = frame, el
  panelList[#panelList + 1] = p
  p:SetFrameStrata("BACKGROUND")
  p:SetFrameLevel(0)
  p:EnableMouse(false)

  -- plain dark fill: shows between the slots and is the whole look without the slot art
  p.base = p:CreateTexture(nil, "BACKGROUND", nil, -8)
  p.base:SetAllPoints()
  p.base:SetColorTexture(.1, .1, .1, 1)

  CreateBorder(p, p, BORDER, BORDER_INSET)

  -- a parent that gets a new strata / level drags its children with it: put the panel back
  local function restore()
    p:SetFrameStrata("BACKGROUND")
    p:SetFrameLevel(0)
  end
  for _, method in ipairs({ "SetFrameStrata", "SetFrameLevel" }) do
    if type(frame[method]) == "function" then hooksecurefunc(frame, method, restore) end
  end
  return p
end

local function Style(p)
  local r, g, b = Backdrop.Color()
  p.base:SetColorTexture(r * .5, g * .5, b * .5, 1)
end

-- Fitting ---------------------------------------------------------------------
-- The bar frame's own size is not trusted. The panel is sized from the buttons that are shown
-- inside the frame; only bars without buttons (or nothing measurable yet) use the frame's edges.

local Fit

local function QueueFit(p, tries)
  if p.fitQueued then return end
  p.fitQueued = true
  C_Timer.After(tries and .2 or 0, function()
    p.fitQueued = false
    Fit(p, tries)
  end)
end

Fit = function(p, tries)
  if not p.active then return end
  if InCombatLockdown() then return end -- measured again when combat ends
  local frame, def = p.frame, p.el.buttons
  local margin = NB.db.margin

  -- the allotted box is the union of the shown button frames (what Edit Mode lays out)
  local shown, measured = 0, 0
  local boxL, boxR, boxB, boxT
  if def then
    for i = 1, def.count do
      local button = _G[def.prefix .. i]
      if button and button:IsShown() and Inside(button, frame) then
        shown = shown + 1
        local bl, br, bb, bt = Rect(button)
        if bl then
          measured = measured + 1
          boxL = boxL and math.min(boxL, bl) or bl
          boxR = boxR and math.max(boxR, br) or br
          boxB = boxB and math.min(boxB, bb) or bb
          boxT = boxT and math.max(boxT, bt) or bt
        end
      end
    end
  end

  local fl, fr, fb, ft, fs = Rect(frame)
  p:ClearAllPoints()
  if measured > 0 and fl then
    local L, R, B, T = boxL - margin, boxR + margin, boxB - margin, boxT + margin
    p.boxRect = { L, R, B, T }
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", (L - fl) / fs, (T - ft) / fs)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", (R - fr) / fs, (B - fb) / fs)
    p:SetAlpha((R - L < MIN_SIZE or T - B < MIN_SIZE) and 0 or 1)
  else
    p.boxRect = nil
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", -margin, margin)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", margin, -margin)
    p:SetAlpha(1)
    -- shown buttons whose position is not resolved yet: look again shortly
    if shown > 0 and (tries or 0) < 5 then QueueFit(p, (tries or 0) + 1) end
  end
  p.shownButtons = shown
  p:Show()
end

-- Anything that moves, shows or hides the buttons re-fits the panel (coalesced to one pass).
local function Watch(p)
  local frame, def = p.frame, p.el.buttons
  local function queue() QueueFit(p) end
  for _, method in ipairs({ "Layout", "UpdateGridLayout", "UpdateShownButtons", "SetSize", "SetScale" }) do
    if type(frame[method]) == "function" then hooksecurefunc(frame, method, queue) end
  end
  frame:HookScript("OnShow", queue)
  if def then
    for i = 1, def.count do
      local button = _G[def.prefix .. i]
      if button then
        button:HookScript("OnShow", queue)
        button:HookScript("OnHide", queue)
        hooksecurefunc(button, "SetPoint", queue)
        hooksecurefunc(button, "SetScale", queue)
      end
    end
  end
end

function Backdrop.PanelOf(frame)
  return panels[frame]
end

function Backdrop.Refit()
  for _, p in ipairs(panelList) do Fit(p) end
end

-- Native art ----------------------------------------------------------------

local ART_FIELDS = { "Background", "BorderArt", "EndCaps", "LeftEndCap", "RightEndCap" }
local ART_GLOBALS = {
  "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
  "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
}

local function HideArt(el, frame, on)
  for _, field in ipairs(ART_FIELDS) do
    local region = frame[field]
    if type(region) == "table" then NB.Pin(region, on) end
  end
  if el.key == "main" then
    for _, name in ipairs(ART_GLOBALS) do NB.Pin(_G[name], on) end
  end
end

-- Opacity ---------------------------------------------------------------------
-- The whole bar (backdrop child, buttons, icons) fades through the bar frame's own alpha.
-- Only touched when below 100%; Blizzard resetting the alpha is undone while it is.

local alphaState = setmetatable({}, { __mode = "k" })

local function SetOpacity(frame, value)
  local state = alphaState[frame]
  if not state then
    if value >= 1 then return end
    state = {}
    alphaState[frame] = state
    hooksecurefunc(frame, "SetAlpha", function(self)
      if state.want and not state.guard then
        state.guard = true
        self:SetAlpha(state.want)
        state.guard = false
      end
    end)
  end
  state.want = value < 1 and value or nil
  state.guard = true
  frame:SetAlpha(value)
  state.guard = false
end

local function ApplyElementOpacity(el)
  local value = NB.El(el.key).opacity / 100
  for _, frame in ipairs(NB.Frames(el)) do SetOpacity(frame, value) end
end

function Backdrop.ApplyOpacity()
  for _, el in ipairs(NB.ELEMENTS) do ApplyElementOpacity(el) end
end

-- Used by the Edit Mode row and the options panel.
function Backdrop.SetOpacity(key, percent)
  percent = math.min(100, math.max(10, math.floor(percent + .5)))
  NB.El(key).opacity = percent
  for _, el in ipairs(NB.ELEMENTS) do
    if el.key == key then ApplyElementOpacity(el) end
  end
end

-- Applying ----------------------------------------------------------------------

function Backdrop.Apply()
  for _, el in ipairs(NB.ELEMENTS) do
    local themed = NB.El(el.key).enabled and not el.noBackdrop
    for _, frame in ipairs(NB.Frames(el)) do
      local p = panels[frame]
      if themed then
        if not p and not InCombatLockdown() then
          p = Create(frame, el)
          panels[frame] = p
          Watch(p)
        end
        if p then
          p.active = true
          Style(p)
          Fit(p)
        end
        if el.art then HideArt(el, frame, true) end
      else
        if p then
          p.active = false
          p:Hide()
        end
        if el.art then HideArt(el, frame, false) end
      end
    end
  end
  Backdrop.ApplyOpacity()
end

-- `/nb debug`: what each backdrop is wrapped around.
function Backdrop.Debug()
  local function size(region)
    local w, h = region:GetSize()
    return NB.Readable(w) and NB.Readable(h) and string.format("%.0fx%.0f", w, h) or "?"
  end
  print("|cffffd200norabu_bars|r backdrops:")
  for _, p in ipairs(panelList) do
    local shown, total = 0, 0
    local def = p.el.buttons
    if def then
      for i = 1, def.count do
        local button = _G[def.prefix .. i]
        if button and Inside(button, p.frame) then
          total = total + 1
          if button:IsShown() then shown = shown + 1 end
        end
      end
    end
    local name = p.frame.GetName and p.frame:GetName() or "?"
    -- first shown button: frame size vs icon size, in UIParent units
    local detail = ""
    if def then
      for i = 1, def.count do
        local button = _G[def.prefix .. i]
        if button and button:IsShown() and Inside(button, p.frame) then
          local bl, br, bb, bt = Rect(button)
          local icon = IconOf(button)
          local il, ir, ib, it = Rect(icon or button)
          local nl, nr = Rect(_G[def.prefix .. (i + 1)] or button)
          if bl and il then
            detail = string.format(", button %.0fx%.0f, icon %.0fx%.0f", br - bl, bt - bb, ir - il, it - ib)
            if nl and nl ~= bl then detail = detail .. string.format(", spacing %.1f", math.abs(nl - bl)) end
          end
          break
        end
      end
    end
    print(string.format("  %s (%s): bar %s, backdrop %s%s, buttons shown %d of %d%s",
      p.el.key, name, size(p.frame), size(p), p:IsVisible() and "" or " [hidden]", shown, total, detail))
  end
end

-- Alignment overlay (`/nb align`) ---------------------------------------------------
-- Thin outlines drawn over the bars so a screenshot shows how the pieces relate:
--   green  the button's icon (the classic slot art is drawn exactly on it)
--   red    the button frame           cyan    the allotted box (the backdrop)

local COLORS = { icon = { 0, 1, 0 }, button = { 1, 0, 0 }, box = { 0, 1, 1 } }
local overlay

local function Box(o, l, r, b, t, color)
  local w, h, th = r - l, t - b, 1
  local function line(x, y, lw, lh)
    o.used = o.used + 1
    local tex = o.pool[o.used]
    if not tex then
      tex = o:CreateTexture(nil, "OVERLAY")
      o.pool[o.used] = tex
    end
    tex:ClearAllPoints()
    tex:SetColorTexture(color[1], color[2], color[3], 1)
    tex:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", x, y)
    tex:SetSize(lw, lh)
    tex:Show()
  end
  line(l, b, w, th)
  line(l, t - th, w, th)
  line(l, b, th, h)
  line(r - th, b, th, h)
end

local function DrawAlign()
  local o = overlay
  o.used = 0
  for _, p in ipairs(panelList) do
    if p.active and p:IsVisible() then
      local def = p.el.buttons
      if p.boxRect then Box(o, p.boxRect[1], p.boxRect[2], p.boxRect[3], p.boxRect[4], COLORS.box) end
      if def then
        for i = 1, def.count do
          local button = _G[def.prefix .. i]
          if button and button:IsShown() and Inside(button, p.frame) then
            local bl, br, bb, bt = Rect(button)
            if bl then Box(o, bl, br, bb, bt, COLORS.button) end
            local icon = IconOf(button)
            local il, ir, ib, it = Rect(icon or button)
            if il then Box(o, il, ir, ib, it, COLORS.icon) end
          end
        end
      end
    end
  end
  for i = o.used + 1, #o.pool do o.pool[i]:Hide() end
end

function Backdrop.Align(on)
  if not overlay then
    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetAllPoints(UIParent)
    overlay:EnableMouse(false)
    overlay.pool, overlay.used = {}, 0
    local waited = 0
    overlay:SetScript("OnUpdate", function(_, dt)
      waited = waited + dt
      if waited < .25 then return end
      waited = 0
      DrawAlign()
    end)
    overlay:Hide()
  end
  if on == nil then on = not overlay:IsShown() end
  overlay:SetShown(on)
  if on then DrawAlign() end
  return on
end
