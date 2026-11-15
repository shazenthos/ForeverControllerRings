-- Forever Controller Rings: Ring. One secure ring that shows either ring's pages.
--
-- It is opened by a click of "ForeverControllerRingsOpen_<ring>", which is what the
-- macro on the gamepad bar sends ("/click ForeverControllerRingsOpen_consumables
-- Macro"), so the ring is mapped like a spell: no R3, no combos.
--
-- While it is up: the right stick aims (its directions arrive as keys, the
-- pick is read from the pad state), A uses the picked slot, B closes, the
-- D-pad steps (up/down) and turns pages (left/right). With "use on release"
-- (default) the slot is also used when the stick is let go. It works in
-- combat: every button is a secure button and the slot data lives in
-- secure attributes, which are rewritten out of combat only.
local _, FR = ...

local PER_PAGE, MAX_PAGES = 8, 3
local SIZE, RADIUS, ICON = 400, 135, 46
local NAME_W = 84 -- width of an item name under its icon
local PICK_SQ = 0.25 -- the stick must be at least half way out (for visuals)
local AXIS_CVAR = "GamePadStickAxisButtons"
local MODS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
-- keys the ring takes (once let go, if held when it opens): key, button, click
local TAKEN = {
    { "PAD1", "ForeverControllerRingsUse", "LeftButton" },
    { "PAD2", "ForeverControllerRingsClose", "LeftButton" },
    { "PADDUP", "ForeverControllerRingsStep", "PADDUP" },
    { "PADDDOWN", "ForeverControllerRingsStep", "PADDDOWN" },
    { "PADDLEFT", "ForeverControllerRingsPage", "PADDLEFT" },
    { "PADDRIGHT", "ForeverControllerRingsPage", "PADDRIGHT" },
}

local function Quoted(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = ("%q"):format(v) end
    return "newtable(" .. table.concat(out, ", ") .. ")"
end
local MODS_EXPR = Quoted(MODS)

local function Fill(snippet, values)
    return (snippet:gsub("@(%u+)@", values))
end

---------------------------------------------------------------------------
-- Secure frames
---------------------------------------------------------------------------
local ring = CreateFrame("Frame", "ForeverControllerRingsFrame", UIParent, "SecureHandlerBaseTemplate")
ring:SetSize(SIZE, SIZE)
ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
ring:SetFrameStrata("DIALOG")
ring:Hide()
FR.ring = ring

local function SecureButton(name)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    button:SetSize(1, 1)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
    SecureHandlerSetFrameRef(button, "ring", ring)
    return button
end

-- While the ring is up this child takes the sticks, so aiming does not turn
-- the camera. It takes both sticks, so the left one walks through bindings
-- (below). It shows and hides with the ring, even in combat.
local capture = CreateFrame("Frame", nil, ring)
capture:SetAllPoints(ring)
if capture.EnableGamePadStick then
    capture:EnableGamePadStick(true)
    capture:SetScript("OnGamePadStick", function() end)
end

-- After the ring closes the stick is often still pushed: keep the sticks
-- taken a moment so the camera does not swing round as the ring goes.
local RELEASE_SQ, RELEASE_MAX = 0.2 * 0.2, 0.5
local after = CreateFrame("Frame", nil, UIParent)
after:SetAllPoints(UIParent)
after:SetFrameStrata("DIALOG")
after:Hide()
if after.EnableGamePadStick then
    after:EnableGamePadStick(true)
    after:SetScript("OnGamePadStick", function() end)
end

local function Sticks()
    if not (C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetActiveDeviceID) then return nil end
    local device = C_GamePad.GetActiveDeviceID()
    local state = device and C_GamePad.GetDeviceMappedState(device)
    return state and state.sticks
end

local function AimPushed()
    local sticks = Sticks()
    local stick = sticks and sticks[ring:GetAttribute("fr-stick") or 0]
    return stick and stick.x and stick.y and (stick.x * stick.x + stick.y * stick.y) > RELEASE_SQ or false
end

after:SetScript("OnUpdate", function(self, elapsed)
    self.held = (self.held or 0) + elapsed
    if self.held >= RELEASE_MAX or not AimPushed() then self:Hide() end
end)
ring:HookScript("OnHide", function()
    if AimPushed() then
        after.held = 0
        after:Show()
    end
end)
ring:HookScript("OnShow", function() after:Hide() end)

---------------------------------------------------------------------------
-- Restricted snippets
---------------------------------------------------------------------------
-- The slot the right stick points at (nil: not pushed past `needed`, a
-- squared length), from the slot directions stored as attributes.
ring:SetAttribute("fr-pickslot", [=[
    local needed = ...
    local state = GetGamePadState()
    local sticks = state and state.sticks
    local stick = sticks and sticks[self:GetAttribute("fr-stick") or 0]
    if not (stick and stick.x and stick.y) then return nil end
    local x, y = stick.x, stick.y
    if x * x + y * y < needed then return nil end
    local key = self:GetAttribute("fr-active")
    local best, bestDot
    for index = 1, self:GetAttribute(key .. "-count") or 0 do
        local dot = x * self:GetAttribute(key .. "-dx-" .. index) + y * self:GetAttribute(key .. "-dy-" .. index)
        if not bestDot or dot > bestDot then best, bestDot = index, dot end
    end
    return best
]=])

-- Take the ring's keys. One still held (the button that opened the ring,
-- say) is taken only once let go: its release must reach the binding it
-- was pressed on, or the game's own binding stays down.
ring:SetAttribute("fr-take", Fill([=[
    local state = GetGamePadState()
    local buttons = state and state.buttons
    local waiting = false
    local taken = newtable(@TAKEN@)
    for _, item in ipairs(taken) do
        local key = item[1]
        if not self:GetAttribute("fr-claimed-" .. key) then
            local index = self:GetAttribute("fr-btn-" .. key)
            if buttons and index and buttons[index] then
                waiting = true
            else
                self:SetAttribute("fr-claimed-" .. key, true)
                for _, modifier in ipairs(@MODS@) do
                    self:SetBindingClick(true, modifier .. key, item[2], item[3])
                end
            end
        end
    end
    self:SetAttribute("fr-waiting", waiting or nil)
]=], {
    MODS = MODS_EXPR,
    TAKEN = (function()
        local rows = {}
        for i, t in ipairs(TAKEN) do
            rows[i] = ("newtable(%q, %q, %q)"):format(t[1], t[2], t[3])
        end
        return table.concat(rows, ", ")
    end)(),
}))

-- Copies the picked slot's action onto the clicked button (self), so the
-- click that is running does it: item="item:<id>", type="item".
local FILL = [=[
    local key = ring:GetAttribute("fr-active")
    local actionType = ring:GetAttribute(key .. "-type-" .. pick)
    local value = ring:GetAttribute(key .. "-value-" .. pick)
    ring:Hide()
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("macrotext", nil)
    if actionType then
        self:SetAttribute(actionType == "macro" and "macrotext" or actionType, value)
        self:SetAttribute("type", actionType)
    end
]=]

-- Opens a ring: a click of any kind ("Macro" from a gamepad bar slot, or a
-- key press). Clicking again closes it.
for _, ringKey in ipairs(FR.RINGS) do
    local open = SecureButton("ForeverControllerRingsOpen_" .. ringKey)
    open:RegisterForClicks("AnyDown", "AnyUp")
    open:SetAttribute("fr-ring", ringKey)
    SecureHandlerWrapScript(open, "OnClick", open, [=[
        if button ~= "Macro" and not down then return false end
        local ring = self:GetFrameRef("ring")
        if ring:IsShown() then
            ring:Hide()
            return false
        end
        local first = ring:GetAttribute("fr-first-" .. self:GetAttribute("fr-ring"))
        if not first then return false end
        ring:SetAttribute("fr-sticky", nil)
        ring:SetAttribute("fr-active", first)
        ring:Show()
        return false
    ]=])
end

-- Right stick directions (as keys): move the pick. A key going down means
-- the stick just left the middle; coming up, it is springing back, so only
-- a firm reading counts then. "Use on release": with no direction held
-- any more, the slot it pointed at is used.
local aim = SecureButton("ForeverControllerRingsAim")
aim:RegisterForClicks("AnyDown", "AnyUp")
aim:SetAttribute("useOnKeyDown", false) -- its action, if any, runs on the release
SecureHandlerWrapScript(aim, "OnClick", aim, Fill([=[
    self:SetAttribute("type", nil)
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("fr-waiting") then ring:RunAttribute("fr-take") end
    if ring:IsShown() then
        local pick = ring:RunAttribute("fr-pickslot", down and 0.12 or 0.5)
        if pick then ring:SetAttribute("fr-sticky", pick) end
        if not down and not pick and (ring:GetAttribute("fr-release") or 0) == 1 then
            pick = ring:GetAttribute("fr-sticky")
            if pick then
                @FILL@
                return
            end
        end
    end
    return false
]=], { FILL = FILL }))

-- A: use the slot the stick points at, else the sticky pick.
local use = SecureButton("ForeverControllerRingsUse")
use:RegisterForClicks("AnyDown")
use:SetAttribute("useOnKeyDown", true) -- its action runs on the press, whatever the game's setting
SecureHandlerWrapScript(use, "OnClick", use, Fill([=[
    self:SetAttribute("type", nil)
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("fr-waiting") then ring:RunAttribute("fr-take") end
    if not down or not ring:IsShown() then return false end
    local pick = ring:RunAttribute("fr-pickslot", 0.25) or ring:GetAttribute("fr-sticky")
    if not pick then return false end
    @FILL@
]=], { FILL = FILL }))

-- D-pad up / down: step the pick round the ring.
local step = SecureButton("ForeverControllerRingsStep")
step:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(step, "OnClick", step, [=[
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("fr-waiting") then ring:RunAttribute("fr-take") end
    local count = ring:GetAttribute((ring:GetAttribute("fr-active") or "") .. "-count") or 0
    if not ring:IsShown() or count < 1 then return false end
    local current = ring:GetAttribute("fr-sticky")
    local forward = button == "PADDDOWN"
    if not current then
        current = forward and 1 or count
    elseif forward then
        current = current % count + 1
    else
        current = (current - 2) % count + 1
    end
    ring:SetAttribute("fr-sticky", current)
    return false
]=])

-- D-pad left / right: previous / next page.
local page = SecureButton("ForeverControllerRingsPage")
page:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(page, "OnClick", page, [=[
    local ring = self:GetFrameRef("ring")
    if ring:GetAttribute("fr-waiting") then ring:RunAttribute("fr-take") end
    local active = ring:GetAttribute("fr-active")
    if not ring:IsShown() or not active then return false end
    local number, of = ring:GetAttribute(active .. "-number") or 1, ring:GetAttribute(active .. "-of") or 1
    if of < 2 then return false end
    local step = (button == "PADDLEFT") and -1 or 1
    ring:SetAttribute("fr-sticky", nil)
    ring:SetAttribute("fr-active", ring:GetAttribute(active .. "-ring") .. ((number - 1 + step) % of + 1))
    return false
]=])

-- B: close.
local close = SecureButton("ForeverControllerRingsClose")
close:RegisterForClicks("AnyDown")
SecureHandlerWrapScript(close, "OnClick", close, [=[
    self:GetFrameRef("ring"):Hide()
    return false
]=])

-- While the ring is up it owns A, B, the D-pad and the sticks' directions
-- (the left one walks), whatever they do otherwise.
SecureHandlerWrapScript(ring, "OnShow", ring, Fill([=[
    local taken = newtable(@TAKENKEYS@)
    for _, key in ipairs(taken) do self:SetAttribute("fr-claimed-" .. key, nil) end
    self:RunAttribute("fr-take")
    for _, modifier in ipairs(@MODS@) do
        for _, key in ipairs(newtable("PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT")) do
            self:SetBindingClick(true, modifier .. key, "ForeverControllerRingsAim", key)
        end
        self:SetBinding(true, modifier .. "PADLSTICKUP", "MOVEFORWARD")
        self:SetBinding(true, modifier .. "PADLSTICKDOWN", "MOVEBACKWARD")
        self:SetBinding(true, modifier .. "PADLSTICKLEFT", "STRAFELEFT")
        self:SetBinding(true, modifier .. "PADLSTICKRIGHT", "STRAFERIGHT")
    end
]=], {
    MODS = MODS_EXPR,
    TAKENKEYS = (function()
        local keys = {}
        for i, t in ipairs(TAKEN) do keys[i] = ("%q"):format(t[1]) end
        return table.concat(keys, ", ")
    end)(),
}))
SecureHandlerWrapScript(ring, "OnHide", ring, [=[
    self:ClearBindings()
    self:SetAttribute("fr-waiting", nil)
]=])

-- Out of combat a held key is taken as soon as it is let go, not only at the
-- next stick or button press (in combat only those can).
local watch = CreateFrame("Frame", nil, ring)
watch:SetScript("OnUpdate", function()
    if ring:GetAttribute("fr-waiting") and not InCombatLockdown() then
        SecureHandlerExecute(ring, [=[ self:RunAttribute("fr-take") ]=])
    end
end)

---------------------------------------------------------------------------
-- Stick directions as keys: the game only sends them with
-- GamePadStickAxisButtons on. On while the ring is up, put back after; the
-- old value is saved so a /reload mid-ring still restores it.
---------------------------------------------------------------------------
local function SetCVarSafe(name, value)
    local ok, result = pcall(C_CVar and C_CVar.SetCVar or SetCVar, name, value)
    return ok and result ~= false
end

local function GetCVarSafe(name)
    local ok, value = pcall(C_CVar and C_CVar.GetCVar or GetCVar, name)
    return ok and value or nil
end

local function RestoreAxis()
    if ring:IsShown() or not FR.db then return end
    if FR.db.axisSaved ~= nil and SetCVarSafe(AXIS_CVAR, FR.db.axisSaved) then
        FR.db.axisSaved = nil
    end
end

ring:HookScript("OnShow", function()
    local current = GetCVarSafe(AXIS_CVAR)
    if current and current ~= "1" then
        if FR.db.axisSaved == nil then FR.db.axisSaved = current end
        SetCVarSafe(AXIS_CVAR, "1")
    end
end)
ring:HookScript("OnHide", RestoreAxis)

---------------------------------------------------------------------------
-- Stuck walking. While the ring is up the left stick's directions are bound
-- to the movement commands (the ring holds the sticks, so the game's own
-- movement does not see them). If the ring closes while one is still held,
-- the binding goes away before its release arrives and the character keeps
-- walking. So on close, stop every movement the left stick may have
-- started (and once more a moment later, in case a late press got through).
---------------------------------------------------------------------------
local STOPS = { "MoveForwardStop", "MoveBackwardStop", "StrafeLeftStop", "StrafeRightStop" }
local function StopWalking()
    for _, name in ipairs(STOPS) do
        local fn = _G[name]
        if fn then pcall(fn) end
    end
end
ring:HookScript("OnHide", function()
    StopWalking()
    C_Timer.After(0.15, function()
        if not ring:IsShown() then StopWalking() end
    end)
end)

---------------------------------------------------------------------------
-- Settings and pad indexes (out of combat)
---------------------------------------------------------------------------
local function StickIndex(name)
    if C_GamePad and C_GamePad.StickConfigNameToIndex then
        local index = C_GamePad.StickConfigNameToIndex(name)
        if index and index >= 0 then return index + 1 end
    end
end
FR.StickIndex = StickIndex

local function ButtonIndex(binding)
    if C_GamePad and C_GamePad.ButtonBindingToIndex then
        local index = C_GamePad.ButtonBindingToIndex(binding)
        if index then return index + 1 end -- GetGamePadState().buttons is 1-based
    end
end

local settingsPending = false
function FR.ApplySettings()
    if FR.InCombat() then
        settingsPending = true
        return
    end
    settingsPending = false
    ring:SetAttribute("fr-stick", StickIndex("Right") or 2)
    ring:SetAttribute("fr-release", FR.db and FR.db.release and 1 or 0)
    for _, item in ipairs(TAKEN) do
        ring:SetAttribute("fr-btn-" .. item[1], ButtonIndex(item[1]))
    end
end

---------------------------------------------------------------------------
-- Ring contents -> secure attributes, and what is drawn
---------------------------------------------------------------------------
local pageEntries = {} -- page key ("consumables1") -> entries
local pending, queued = false, false

local function SlotAngle(index)
    return math.pi / 2 - (index - 1) * 2 * math.pi / PER_PAGE
end

function FR.Rebuild()
    if FR.InCombat() then
        pending = true
        return
    end
    pending = false
    wipe(pageEntries)
    for _, ringKey in ipairs(FR.RINGS) do
        local entries = FR.Builders[ringKey]()
        local pages = math.max(1, math.min(MAX_PAGES, math.ceil(#entries / PER_PAGE)))
        for number = 1, pages do
            local key = ringKey .. number
            local list = {}
            for index = 1, PER_PAGE do
                local entry = entries[(number - 1) * PER_PAGE + index]
                if not entry then break end
                list[index] = entry
                local angle = SlotAngle(index)
                ring:SetAttribute(key .. "-dx-" .. index, math.cos(angle))
                ring:SetAttribute(key .. "-dy-" .. index, math.sin(angle))
                ring:SetAttribute(key .. "-type-" .. index, entry.type)
                ring:SetAttribute(key .. "-value-" .. index, entry.value)
            end
            -- (a stale slot past the end keeps its attributes, but -count stops the pick)
            ring:SetAttribute(key .. "-count", #list)
            ring:SetAttribute(key .. "-ring", ringKey)
            ring:SetAttribute(key .. "-number", number)
            ring:SetAttribute(key .. "-of", pages)
            list.empty = entries.empty
            pageEntries[key] = list
        end
        ring:SetAttribute("fr-first-" .. ringKey, ringKey .. 1)
    end
end

local function QueueRebuild()
    if queued then return end
    queued = true
    C_Timer.After(0.3, function()
        queued = false
        FR.Rebuild()
    end)
end

---------------------------------------------------------------------------
-- Drawing (insecure: icons, counts, cooldowns, the pick)
---------------------------------------------------------------------------
local MASK_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local TEAL = { 0.25, 0.72, 0.79 }
local GOLD = { 0.96, 0.78, 0.29 }
local STEEL = { 0.45, 0.55, 0.62 }

-- A round, flat-coloured disc (a colour texture under a circular mask).
-- Layers inside one frame draw back to front by sublevel.
local function Disc(parent, layer, sublevel, size, color, alpha, blend)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    tex:SetSize(size, size)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK_TEX, "CLAMPTOBLACKANDWHITE", "CLAMPTOBLACKANDWHITE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    if blend then tex:SetBlendMode(blend) end
    return tex
end

-- Wheel body: a teal rim, a deep navy face, and a small inner hub.
local rim = Disc(ring, "BACKGROUND", 0, SIZE, TEAL, 0.9)
rim:SetPoint("CENTER")
local face = Disc(ring, "BACKGROUND", 1, SIZE - 6, { 0.04, 0.06, 0.11 }, 0.88)
face:SetPoint("CENTER")
local hubRim = Disc(ring, "BACKGROUND", 2, 168, TEAL, 0.45)
hubRim:SetPoint("CENTER")
local hub = Disc(ring, "BACKGROUND", 3, 164, { 0.02, 0.03, 0.07 }, 0.9)
hub:SetPoint("CENTER")

-- Thin dividers between the eight slots.
for index = 1, PER_PAGE do
    local angle = SlotAngle(index) - math.pi / PER_PAGE
    local line = ring.CreateLine and ring:CreateLine(nil, "BACKGROUND", nil, 4)
    if line then
        line:SetThickness(2)
        line:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.28)
        line:SetStartPoint("CENTER", ring, math.cos(angle) * 84, math.sin(angle) * 84)
        line:SetEndPoint("CENTER", ring, math.cos(angle) * 190, math.sin(angle) * 190)
    end
end

local FONT = GameFontHighlightSmall and GameFontHighlightSmall:GetFont() or "Fonts\\FRIZQT__.TTF"

local title = ring:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("CENTER", ring, "CENTER", 0, 26)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetShadowOffset(1, -1)
local selected = ring:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
selected:SetPoint("CENTER", ring, "CENTER", 0, -6)
selected:SetWidth(150)
selected:SetMaxLines(2)
selected:SetShadowOffset(1, -1)
local hint = ring:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("CENTER", ring, "CENTER", 0, -40)
hint:SetText("A use   B close   D-pad pages")

local slots = {}
for index = 1, PER_PAGE do
    local angle = SlotAngle(index)
    local slot = CreateFrame("Frame", nil, ring)
    slot:SetSize(ICON, ICON)
    slot:SetPoint("CENTER", ring, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
    slot.dx, slot.dy = math.cos(angle), math.sin(angle)
    -- a round rim (tinted by the item's quality) behind a round icon
    slot.rim = Disc(slot, "BACKGROUND", 0, ICON + 6, STEEL, 1)
    slot.rim:SetPoint("CENTER")
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints()
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local iconMask = slot:CreateMaskTexture()
    iconMask:SetTexture(MASK_TEX, "CLAMPTOBLACKANDWHITE", "CLAMPTOBLACKANDWHITE")
    iconMask:SetAllPoints(slot.icon)
    slot.icon:AddMaskTexture(iconMask)
    slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.count:SetPoint("BOTTOMRIGHT", 4, -2)
    -- the item's name, under its icon (two lines at most)
    slot.name = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slot.name:SetFont(FONT, 10, "OUTLINE")
    slot.name:SetPoint("TOP", slot, "BOTTOM", 0, -5)
    slot.name:SetWidth(NAME_W)
    slot.name:SetMaxLines(2)
    slot.name:SetJustifyH("CENTER")
    slot.name:SetJustifyV("TOP")
    slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    slot.cooldown:SetAllPoints()
    slot.cooldown:SetDrawEdge(false)
    pcall(function() -- round swipe to match the round icon
        slot.cooldown:SetSwipeTexture(MASK_TEX)
        slot.cooldown:SetUseCircularEdge(true)
    end)
    slots[index] = slot
end

-- A golden halo behind the picked slot (the slots, being child frames,
-- draw above it, so it shows as a glowing rim).
local highlight = Disc(ring, "BACKGROUND", 6, ICON + 18, GOLD, 0.95)
highlight:Hide()

-- Rim colour from the item's quality (steel for plain white and grey ones).
local function QualityColor(itemID)
    local ok, r, g, b = pcall(function()
        local quality = C_Item.GetItemQualityByID(itemID)
        if quality and quality >= 2 then
            return C_Item.GetItemQualityColor(quality)
        end
    end)
    if ok and r then return { r, g, b } end
    return STEEL
end

local drawn

-- (item counts and cooldowns may be secret values in combat: skip then)
local function UpdateSlot(slot, entry)
    local ok = pcall(function()
        local count = C_Item.GetItemCount(entry.itemID)
        if issecretvalue and issecretvalue(count) then
            slot.count:SetText("")
        else
            slot.count:SetText(count and count > 1 and count or "")
            slot.icon:SetDesaturated(not count or count < 1)
        end
        local start, duration = C_Container.GetItemCooldown(entry.itemID)
        if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then
            slot.cooldown:Clear()
        elseif start and duration and duration > 0 then
            slot.cooldown:SetCooldown(start, duration)
        else
            slot.cooldown:Clear()
        end
    end)
    if not ok then slot.cooldown:Clear() end
end

local function Draw(key)
    drawn = key
    local entries = key and pageEntries[key] or {}
    local ringKey = key and ring:GetAttribute(key .. "-ring")
    local number, of = key and ring:GetAttribute(key .. "-number") or 1, key and ring:GetAttribute(key .. "-of") or 1
    title:SetText((FR.LABELS[ringKey or ""] or "") .. (of > 1 and (" " .. number .. "/" .. of) or ""))
    for index, slot in ipairs(slots) do
        local entry = entries[index]
        if entry then
            slot.icon:SetTexture(entry.icon)
            slot.name:SetText(entry.label or "")
            local color = QualityColor(entry.itemID)
            slot.rim:SetVertexColor(color[1], color[2], color[3], 1)
            slot:Show()
            UpdateSlot(slot, entry)
        else
            slot:Hide()
        end
    end
    if #entries == 0 then selected:SetText(entries.empty or "") end
end

local function VisualPick(entries)
    local sticks = Sticks()
    local stick = sticks and sticks[ring:GetAttribute("fr-stick") or 0]
    if stick and stick.x and stick.y and (stick.x * stick.x + stick.y * stick.y) >= PICK_SQ then
        local best, bestDot
        for index in ipairs(entries) do
            local dot = stick.x * slots[index].dx + stick.y * slots[index].dy
            if not bestDot or dot > bestDot then best, bestDot = index, dot end
        end
        return best
    end
    return ring:GetAttribute("fr-sticky")
end

local driver = CreateFrame("Frame", nil, ring)
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    local key = ring:GetAttribute("fr-active")
    local entries = key and pageEntries[key] or {}
    if key ~= drawn then Draw(key) end
    local pick = #entries > 0 and VisualPick(entries)
    -- Out of combat, hand the slot you see lit straight to the secure side every
    -- frame, so letting go of the stick uses exactly that slot. (The stick's
    -- direction keys only fire when it crosses their threshold, so the pick they
    -- leave behind can lag what is on screen; in combat they are all there is.)
    if pick and not InCombatLockdown() and ring:GetAttribute("fr-sticky") ~= pick then
        pcall(ring.SetAttribute, ring, "fr-sticky", pick)
    end
    for index, slot in ipairs(slots) do -- the picked slot grows a little and its name lights up
        local on = (index == pick)
        slot:SetScale(on and 1.14 or 1)
        if on then
            slot.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            slot.name:SetTextColor(0.8, 0.84, 0.88)
        end
    end
    if pick and slots[pick] and entries[pick] then
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", slots[pick], "CENTER")
        highlight:Show()
        selected:SetText(entries[pick].label)
    else
        highlight:Hide()
        if #entries > 0 then selected:SetText("") end
    end
    acc = acc + elapsed
    if acc > 0.25 then
        acc = 0
        for index, entry in ipairs(entries) do UpdateSlot(slots[index], entry) end
    end
end)
ring:HookScript("OnShow", function() drawn = nil end)

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
FR.OnLogin(function()
    FR.Rebuild()
    FR.ApplySettings()
    RestoreAxis()
end)

local events = CreateFrame("Frame")
for _, event in ipairs(FR.REBUILD_EVENTS) do events:RegisterEvent(event) end
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(_, event)
    if not FR.db then return end
    if event == "PLAYER_REGEN_ENABLED" then
        RestoreAxis()
        if settingsPending then FR.ApplySettings() end
        if pending then FR.Rebuild() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        FR.Rebuild() -- last chance to pick up changes before the lockdown
    elseif event == "UPDATE_BINDINGS" then
        FR.ApplySettings()
    else
        QueueRebuild()
    end
end)
