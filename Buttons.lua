-- Button features, all optional:
--   outline      the classic framed slot instead of Blizzard's button frame art. A piece of the
--                client's classic bar strip (see Backdrop.Piece) is anchored straight to each icon,
--                so it cannot drift: the whole slot sits on the backdrop panel behind the icon (the
--                dark recess shows on empty slots), and the frame ring alone (the same piece, cut
--                with media/slot_ring_mask.tga) is drawn over the icon's edge. Icons become square
--                with a trimmed edge so they sit cleanly inside the ring.
--   slots        extra dark square behind each icon
--   rangeMana    the icon itself is tinted red out of range, blue without enough resource
--   flash        star-burst on press
--   hideCastAnim hide the native cast / interrupt animation on the buttons
-- Hotkey text is always forced to white, whatever Blizzard tries to do with it.
local ADDON, NB = ...

local Buttons = {}
NB.Buttons = Buttons

local TINT = { range = { 1, .25, .25 }, mana = { .35, .45, 1 } }
local POLL = .1
local RING_MASK = NB.media .. "slot_ring_mask.tga"
local NATIVE_ART = { "NormalTexture", "SlotArt", "SlotBackground" }

local recs = {}   -- [button] = record
local list = {}   -- records, in install order

local IsInRange = (C_ActionBar and C_ActionBar.IsActionInRange) or IsActionInRange
local IsUsable = (C_ActionBar and C_ActionBar.IsUsableAction) or IsUsableAction

-- Native cast animation -------------------------------------------------------
-- Hide the animated frame the moment it shows (a hidden frame plays no animation). The flag lets
-- it come back if the option is switched off.

local function HideCast(frame)
  if NB.db.buttons.hideCastAnim then
    frame.nbHidden = true
    frame:SetAlpha(0)
    if not frame:IsForbidden() then frame:Hide() end
  elseif frame.nbHidden then
    frame.nbHidden = nil
    frame:SetAlpha(1)
  end
end

-- Hotkey text -------------------------------------------------------------------
-- Blizzard turns the hotkey red when the target is out of range (and greys it in other states).
-- Any colour it sets is put back to white straight away.

local function ForceWhite(fs)
  local guard = false
  local function white()
    if guard then return end
    guard = true
    fs:SetTextColor(1, 1, 1, 1)
    if fs.SetVertexColor then fs:SetVertexColor(1, 1, 1, 1) end
    guard = false
  end
  hooksecurefunc(fs, "SetTextColor", white)
  if type(fs.SetVertexColor) == "function" then hooksecurefunc(fs, "SetVertexColor", white) end
  white()
end

-- Icon tint (range / mana) ---------------------------------------------------------
-- The icon texture's own vertex colour is changed, so only the icon (in its rounded shape) is
-- coloured. Blizzard's last colour is remembered and restored when the tint ends, and a Blizzard
-- colour update while tinted is overridden straight away.

local function Paint(r)
  local c = r.tint and TINT[r.tint]
  r.guard = true
  if c then
    r.icon:SetVertexColor(c[1], c[2], c[3])
  else
    r.icon:SetVertexColor(r.nr, r.ng, r.nb, r.na)
  end
  r.guard = false
end

local function SetTint(r, kind)
  if r.tint == kind then return end
  r.tint = kind
  if r.icon.SetVertexColor then Paint(r) end
end

local manaColor
local function SecretTint(r, noMana)
  manaColor = manaColor or CreateColor(TINT.mana[1], TINT.mana[2], TINT.mana[3], 1)
  r.guard = true
  r.icon:SetVertexColorFromBoolean(noMana, manaColor, CreateColor(r.nr, r.ng, r.nb, r.na))
  r.guard = false
end

local function MainPage()
  for _, name in ipairs({ "EABBar_MainBar", "MainActionBar", "MainMenuBar" }) do
    local frame = _G[name]
    if frame and frame.GetAttribute then
      local ok, value = pcall(frame.GetAttribute, frame, "actionpage")
      if ok and NB.Readable(value) then
        value = tonumber(value)
        if value then return value end
      end
    end
  end
  if C_ActionBar and C_ActionBar.GetActionBarPage then
    local ok, value = pcall(C_ActionBar.GetActionBarPage)
    if ok and NB.Readable(value) and tonumber(value) then return tonumber(value) end
  end
  return 1
end

local function UpdateWash(r, page)
  local def = r.def
  if def.noAction then return end
  local slot = def.main and ((page - 1) * 12 + r.index) or (def.base + r.index)

  local has = true
  local okHas, hasValue = pcall(HasAction, slot)
  if okHas and NB.Readable(hasValue) then has = hasValue and true or false end
  if not has then
    SetTint(r, nil)
    return
  end

  local outOfRange = false
  local okRange, inRange = pcall(IsInRange, slot)
  if okRange and NB.Readable(inRange) then outOfRange = (inRange == false) end
  if outOfRange then
    SetTint(r, "range")
    return
  end

  local okUse, _, noMana = pcall(IsUsable, slot)
  if okUse and NB.Readable(noMana) then
    SetTint(r, noMana and "mana" or nil)
  elseif okUse and r.icon.SetVertexColorFromBoolean then
    -- the client hid the flag: hand it straight to the texture
    SetTint(r, nil)
    SecretTint(r, noMana)
  else
    SetTint(r, nil)
  end
end

local dirty = true
local elapsed = 0
local poller = CreateFrame("Frame")

poller:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if not dirty and elapsed < POLL then return end
  elapsed, dirty = 0, false
  if not NB.db or not NB.db.buttons.rangeMana then return end
  local page = MainPage()
  for _, r in ipairs(list) do
    if not r.def.noAction and r.button:IsVisible() then UpdateWash(r, page) end
  end
end)

for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
    "ACTION_USABLE_CHANGED", "ACTION_RANGE_CHECK_UPDATE", "SPELL_UPDATE_USABLE", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM" }) do
  pcall(poller.RegisterEvent, poller, event)
end
pcall(poller.RegisterUnitEvent, poller, "UNIT_POWER_UPDATE", "player")
poller:SetScript("OnEvent", function() dirty = true end)

-- Press flash -----------------------------------------------------------------

local function BuildFlash(r)
  local button, icon = r.button, r.icon
  local overlay = CreateFrame("Frame", nil, button)
  overlay:EnableMouse(false)
  overlay:SetAllPoints(icon)
  overlay:SetFrameLevel(button:GetFrameLevel() + 20)
  local star = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
  star:SetTexture("Interface\\Cooldown\\star4")
  star:SetBlendMode("ADD")
  star:SetPoint("TOPLEFT", overlay, "TOPLEFT", -3, 3)
  star:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 3, -3)
  star:SetAlpha(0)
  star:Hide()

  local group = star:CreateAnimationGroup()
  local appear = group:CreateAnimation("Alpha")
  appear:SetFromAlpha(0)
  appear:SetToAlpha(1)
  appear:SetDuration(0)
  appear:SetOrder(1)
  local grow = group:CreateAnimation("Scale")
  grow:SetScale(1.5, 1.5)
  grow:SetDuration(0)
  grow:SetOrder(1)
  local shrink = group:CreateAnimation("Scale")
  shrink:SetScale(0, 0)
  shrink:SetDuration(.3)
  shrink:SetOrder(2)
  local turn = group:CreateAnimation("Rotation")
  turn:SetDegrees(90)
  turn:SetDuration(.3)
  turn:SetOrder(2)
  group:SetScript("OnFinished", function() star:Hide() end)

  r.star, r.anim = star, group
end

local function Flash(r)
  local b = NB.db.buttons
  if not b.flash or not r.star or not r.button:IsVisible() then return end
  local now = GetTime()
  if r.lastFlash and now - r.lastFlash < .02 then return end
  r.lastFlash = now
  local c = b.flashColor
  r.star:SetVertexColor(c.r, c.g, c.b)
  r.anim:Stop()
  r.star:Show()
  r.anim:Play()
end

-- Layers drawn on the backdrop panel ---------------------------------------------------
-- The dark square and the slot art are textures on the bar's backdrop panel, anchored to the
-- button's icon. The panel sits behind the buttons, so the icon covers them; they follow the
-- button's own shown state (unused buttons get nothing) and fade / hide with the bar.

local function PanelFor(button)
  local frame = button:GetParent()
  for _ = 1, 6 do
    if not frame then return end
    local panel = NB.Backdrop.PanelOf(frame)
    if panel then return panel end
    frame = frame.GetParent and frame:GetParent()
  end
end

local function Themed(r)
  return NB.El(r.el.key).enabled and not r.el.noBackdrop
end

local function Sync(r)
  local shown = r.button:IsShown()
  if r.slotTex then r.slotTex:SetShown(shown and r.slotOn and true or false) end
  local on = shown and r.skinOn and true or false
  if r.cell then r.cell:SetShown(on) end
  if r.ring then r.ring:SetShown(on) end
end

-- extra dark square
local function UpdateSlot(r)
  local b = NB.db.buttons
  local panel = b.slots and Themed(r) and PanelFor(r.button)
  if not panel then
    r.slotOn = false
    Sync(r)
    return
  end
  if not r.slotTex or r.slotTex:GetParent() ~= panel then
    if r.slotTex then r.slotTex:Hide() end
    r.slotTex = panel:CreateTexture(nil, "BACKGROUND", nil, -3)
    r.slotTex:SetAllPoints(r.icon)
  end
  r.slotTex:SetColorTexture(0, 0, 0, b.slotAlpha / 100)
  r.slotOn = true
  Sync(r)
end

-- classic framed slot
local function BuildSkin(r, panel)
  local piece = NB.Backdrop.Piece
  r.skinPanel = panel
  if r.cell then r.cell:Hide() end
  if r.ring then r.ring:Hide() end

  -- behind the icon: the whole slot, frame and dark recess (the recess shows on empty slots)
  r.cell = panel:CreateTexture(nil, "BACKGROUND", nil, -5)
  r.cell:SetTexture(piece.path)
  r.cell:SetTexCoord(piece.u0, piece.u1, piece.v0, piece.v1)
  r.cell:SetAllPoints(r.icon)

  -- over the icon's edge: the same piece with its interior cut out by a ring-shaped mask
  r.ring = r.button:CreateTexture(nil, "OVERLAY", nil, -8)
  r.ring:SetTexture(piece.path)
  r.ring:SetTexCoord(piece.u0, piece.u1, piece.v0, piece.v1)
  r.ring:SetAllPoints(r.icon)
  local mask = r.button:CreateMaskTexture()
  mask:SetTexture(RING_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(r.ring)
  r.ring:AddMaskTexture(mask)
end

local function PinNative(r, on)
  for _, field in ipairs(NATIVE_ART) do NB.Pin(r.button[field], on) end
  local normal = r.button.GetNormalTexture and r.button:GetNormalTexture()
  if normal then NB.Pin(normal, on) end
end

-- square icon: no rounded mask, edge trimmed so it sits cleanly inside the frame ring.
-- Safe to repeat: Blizzard puts the mask back whenever it redraws the button art.
local function ApplySquare(r)
  r.cropped = true
  r.icon:SetTexCoord(.07, .93, .07, .93)
  local mask = r.button.IconMask
  if mask and r.icon.RemoveMaskTexture then r.icon:RemoveMaskTexture(mask) end
end

local function ClearSquare(r)
  if not r.cropped then return end
  r.cropped = false
  r.icon:SetTexCoord(0, 1, 0, 1)
  local mask = r.button.IconMask
  if mask and r.icon.AddMaskTexture then r.icon:AddMaskTexture(mask) end
end

-- Cooldown swipe: spans exactly the icon (the whole slot), as a plain square, instead of the
-- rounded shape Blizzard sized it to. The original anchors are kept so it can be put back.
local function FitCooldown(r, on)
  local cd = r.button.cooldown
  if not cd or (cd.IsForbidden and cd:IsForbidden()) then return end
  if on then
    if not r.cdPoints then
      r.cdPoints = {}
      for i = 1, cd:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = cd:GetPoint(i)
        r.cdPoints[i] = { point, relativeTo, relativePoint, x, y }
      end
    end
    cd:ClearAllPoints()
    cd:SetAllPoints(r.icon)
    if cd.SetUseCircularEdge then pcall(cd.SetUseCircularEdge, cd, false) end
    if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, "") end
    local mask = r.button.IconMask
    if mask and cd.RemoveMaskTexture then pcall(cd.RemoveMaskTexture, cd, mask) end
  elseif r.cdPoints then
    cd:ClearAllPoints()
    for _, p in ipairs(r.cdPoints) do cd:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    r.cdPoints = nil
  end
end

local function UpdateSkin(r)
  local panel = NB.db.buttons.outline and Themed(r) and PanelFor(r.button)
  if not panel then
    if r.skinOn then
      r.skinOn = false
      PinNative(r, false)
      ClearSquare(r)
      FitCooldown(r, false)
      Sync(r)
    end
    return
  end
  if r.skinPanel ~= panel then BuildSkin(r, panel) end
  local cr, cg, cb = NB.Backdrop.Color()
  r.cell:SetVertexColor(cr, cg, cb)
  r.ring:SetVertexColor(cr, cg, cb)
  r.skinOn = true
  PinNative(r, true)
  ApplySquare(r)
  FitCooldown(r, true)
  Sync(r)
end

-- Blizzard redraws the button art on page changes, form changes and combat transitions, which
-- puts its mask, frame art and cooldown size back: redo the skin straight after (coalesced).
local function WatchArt(r)
  local button = r.button
  if type(button.UpdateButtonArt) ~= "function" then return end
  local pending = false
  hooksecurefunc(button, "UpdateButtonArt", function()
    if not r.skinOn or pending then return end
    pending = true
    C_Timer.After(0, function()
      pending = false
      if not r.skinOn then return end
      PinNative(r, true)
      ApplySquare(r)
      FitCooldown(r, true)
    end)
  end)
end

-- Install ---------------------------------------------------------------------------

local function Install(button, el, index)
  local icon = button.icon or button.Icon
  if not icon and button.GetName and button:GetName() then icon = _G[button:GetName() .. "Icon"] end
  icon = icon or button
  local r = { button = button, el = el, def = el.buttons, index = index, icon = icon }
  r.nr, r.ng, r.nb, r.na = 1, 1, 1, 1
  recs[button] = r
  list[#list + 1] = r

  -- icon colour: remember Blizzard's, and keep a range / mana tint on top of it
  if icon ~= button and type(icon.SetVertexColor) == "function" then
    local ok, cr, cg, cb, ca = pcall(icon.GetVertexColor, icon)
    if ok and NB.Readable(cr) and type(cr) == "number" then r.nr, r.ng, r.nb, r.na = cr, cg, cb, ca or 1 end
    hooksecurefunc(icon, "SetVertexColor", function(_, vr, vg, vb, va)
      if r.guard then return end
      if NB.Readable(vr) and type(vr) == "number" then r.nr, r.ng, r.nb, r.na = vr, vg, vb, va or 1 end
      if r.tint then Paint(r) end
    end)
  else
    r.def = { noAction = true }
  end
  if icon ~= button and type(icon.SetTexture) == "function" then
    hooksecurefunc(icon, "SetTexture", function()
      if r.cropped then icon:SetTexCoord(.07, .93, .07, .93) end
    end)
  end

  local hotkey = button.HotKey
  if not hotkey and button.GetName and button:GetName() then hotkey = _G[button:GetName() .. "HotKey"] end
  if hotkey and hotkey.SetTextColor then ForceWhite(hotkey) end

  BuildFlash(r)
  WatchArt(r)
  if button.SetButtonState then
    hooksecurefunc(button, "SetButtonState", function(_, state)
      if NB.Readable(state) and state == "PUSHED" then Flash(r) end
    end)
  end
  if button.HookScript then
    button:HookScript("OnMouseDown", function() Flash(r) end)
    button:HookScript("OnHide", function()
      r.anim:Stop()
      r.star:Hide()
      Sync(r)
    end)
    button:HookScript("OnShow", function()
      Sync(r)
      dirty = true
    end)
  end

  for _, key in ipairs({ "SpellCastAnimFrame", "InterruptDisplay" }) do
    local frame = button[key]
    if type(frame) == "table" and frame.HookScript then
      frame:HookScript("OnShow", HideCast)
      if frame:IsShown() then HideCast(frame) end
    end
  end
end

function Buttons.Apply()
  if not NB.db then return end
  if not InCombatLockdown() then
    for _, el in ipairs(NB.ELEMENTS) do
      local def = el.buttons
      if def then
        for i = 1, def.count do
          local button = _G[def.prefix .. i]
          if button and not recs[button] and not (button.IsForbidden and button:IsForbidden()) then
            Install(button, el, i)
          end
        end
      end
    end
  end

  local b = NB.db.buttons
  for _, r in ipairs(list) do
    UpdateSlot(r)
    UpdateSkin(r)
    if not b.rangeMana then SetTint(r, nil) end
    for _, key in ipairs({ "SpellCastAnimFrame", "InterruptDisplay" }) do
      local frame = r.button[key]
      if type(frame) == "table" and frame.nbHidden and not b.hideCastAnim then HideCast(frame) end
    end
  end
  dirty = true
end
