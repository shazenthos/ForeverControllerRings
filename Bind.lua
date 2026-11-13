-- Forever Controller Rings: Bind. "Press the button for this ring": the mapping step.
--
-- Forever's own "Bind to Action Bar" panel cannot be opened from addon code
-- without tainting the game's binding stack (found by ImprovedForever,
-- which does this the same way), so this is a panel of ours. While it is
-- up, the D-pad and face buttons (with the left / right modifier held for
-- those bars) are caught with override bindings of ours; the press picks
-- the gamepad bar slot and the ring's macro is written there. B alone
-- cancels. The modifiers themselves stay the game's, so its bars open as
-- they are held. Out of combat only.
local _, FR = ...

local MODIFIERS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "CTRL-ALT-", "CTRL-ALT-SHIFT-" }
local BACK = "PAD2"

local panel, catch
local current, onDone
local keyIndex = {} -- key -> its place in a bar (1-8)

local function Held(name)
    for _, key in ipairs({ GetBindingKey(name) }) do
        if IsKeyDown(key) then return true end
    end
    return false
end

-- The bar the modifiers held now pick: 0 none, 1 left, 2 right, 3 both
local function HeldBar()
    local left, right = Held("GAMEPADLEFTMOD"), Held("GAMEPADRIGHTMOD")
    if left and right then return 3 end
    return left and 1 or right and 2 or 0
end

local function Close(cancelled)
    if panel and panel:IsShown() then panel:Hide() end
    local done = onDone
    current, onDone = nil, nil
    if done then done(cancelled) end
end

local function Press(key)
    if not (panel and panel:IsShown() and current) or FR.InCombat() then return end
    local bar = HeldBar()
    if key == BACK and bar == 0 then return Close(true) end
    local index = keyIndex[key]
    if not index then return end
    local slot = bar * 8 + index
    local ok, why = FR.Place(current, slot)
    if ok and FR.FindPlacement(current) == slot then
        FR.Print(FR.LABELS[current] .. " mapped to the " .. FR.SlotName(slot) .. ".")
        return Close(false)
    end
    panel.problem:SetText("|cffff6666" .. (ok and "the game did not keep it" or tostring(why)) .. "|r")
end

local function Build()
    if panel then return panel end
    panel = CreateFrame("Frame", "ForeverControllerRingsBindPanel", UIParent, "BackdropTemplate")
    panel:SetSize(480, 190)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 75)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:Hide()

    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(48, 48)
    panel.icon:SetPoint("TOPLEFT", 24, -26)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    panel.title:SetPoint("LEFT", panel.icon, "RIGHT", 14, 0)
    panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.text:SetPoint("TOPLEFT", panel.icon, "BOTTOMLEFT", 0, -16)
    panel.text:SetWidth(430)
    panel.text:SetJustifyH("LEFT")
    panel.text:SetText("Press the D-pad or face button you want for this ring.\n"
        .. "Hold the left or right modifier first to use that bar, or both for the bottom bar.\n"
        .. "Press B alone to cancel.")
    panel.problem = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.problem:SetPoint("BOTTOMLEFT", 24, 22)
    panel.problem:SetWidth(430)
    panel.problem:SetJustifyH("LEFT")

    -- The presses: an override binding's click carries the key as the button
    catch = CreateFrame("Button", "ForeverControllerRingsBindCatch", UIParent)
    catch:RegisterForClicks("AnyDown")
    catch:SetScript("OnClick", function(_, key) Press(key) end)

    panel:SetScript("OnShow", function(self)
        if FR.InCombat() then return end
        wipe(keyIndex)
        for n = 1, 8 do
            for _, key in ipairs({ GetBindingKey("GAMEPADACTIONBUTTON" .. n) }) do keyIndex[key] = n end
        end
        local keys = { [BACK] = true }
        for key in pairs(keyIndex) do keys[key] = true end
        for key in pairs(keys) do
            for _, modifier in ipairs(MODIFIERS) do
                SetOverrideBindingClick(self, true, modifier .. key, catch:GetName(), key)
            end
        end
    end)
    panel:SetScript("OnHide", function(self)
        if not FR.InCombat() then ClearOverrideBindings(self) end
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function()
        if panel:IsShown() then Close(true) end
    end)
    return panel
end

-- Starts the mapping of a ring; done(cancelled) runs when it ends.
function FR.BeginMap(ringKey, done)
    if FR.InCombat() then return FR.Print("not in combat") end
    if not FR.BarAvailable() then
        return FR.Print("this client's gamepad bar API was not found (see /fcr probe)")
    end
    local name, why = FR.EnsureMacro(ringKey)
    if not name then return FR.Print("could not make the macro: " .. tostring(why)) end
    Build()
    current, onDone = ringKey, done
    panel.title:SetText("Map " .. FR.LABELS[ringKey])
    panel.icon:SetTexture("Interface\\Icons\\" .. FR.ICONS[ringKey])
    panel.problem:SetText("")
    panel:Show()
end
