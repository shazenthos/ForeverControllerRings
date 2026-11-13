-- Forever Controller Rings: Macros. What makes a ring mappable like a spell: one
-- account-wide macro per ring ("/click ForeverControllerRingsOpen_<ring> Macro"),
-- which the gamepad bar holds in a slot like any macro. FR.Place writes it
-- into a slot (the call Forever's own gamepad bar editor uses); the UI
-- (UI.lua, Bind.lua) is what the player uses.
--
-- Gamepad bar slots (page unit slots): top bar 1-8, left bar 9-16 (left
-- modifier held), right bar 17-24, bottom bar 25-32 (both held). In each:
-- 1-4 the D-pad (left, up, right, down), 5-8 the face buttons (left, top,
-- right, bottom). The top bar's face buttons are the game's own.
local _, FR = ...

FR.MACRO_NAMES = { consumables = "Ring Consumables", quest = "Ring Quest Items" } -- 16 letters at most
FR.ICONS = { consumables = "INV_Potion_54", quest = "INV_Misc_Note_01" }
local QUESTION_MARK = 134400

local function IconID(ringKey)
    local path = "Interface\\Icons\\" .. FR.ICONS[ringKey]
    if GetFileIDFromPath then
        for _, ext in ipairs({ "", ".blp", ".tga" }) do
            local id = GetFileIDFromPath(path .. ext)
            if type(id) == "number" and id > 0 then return id end
        end
    end
    return QUESTION_MARK
end

local function Body(ringKey)
    return "/click ForeverControllerRingsOpen_" .. ringKey .. " Macro"
end

-- The macro's name, made or repaired as needed (nil, why: it could not be)
function FR.EnsureMacro(ringKey)
    if FR.InCombat() then return nil, "in combat" end
    local name = FR.MACRO_NAMES[ringKey]
    if GetMacroIndexByName(name) > 0 then
        local _, icon, body = GetMacroInfo(name)
        if body ~= Body(ringKey) then EditMacro(name, name, icon, Body(ringKey)) end
        return name
    end
    local account = GetNumMacros()
    if account >= (MAX_ACCOUNT_MACROS or 120) then return nil, "no room for another macro" end
    if not CreateMacro(name, IconID(ringKey), Body(ringKey), false) then return nil, "CreateMacro failed" end
    return name
end

function FR.EnsureAllMacros(verbose)
    for _, ringKey in ipairs(FR.RINGS) do
        local name, why = FR.EnsureMacro(ringKey)
        if verbose then
            FR.Print(name and ("macro ready: " .. name) or ("macro " .. ringKey .. ": " .. tostring(why)))
        end
    end
end

---------------------------------------------------------------------------
-- Forever's gamepad bar
---------------------------------------------------------------------------
local function Bar()
    local util = _G.GamepadActionBarBindingUtil
    local frame = _G.GamepadMainActionBarFrame
    local unit = frame and frame.PageUnit
    if util and unit and unit.GetCurrentPage and util.IsBindablePageUnitSlotID then return util, unit end
end

function FR.BarAvailable()
    return Bar() ~= nil
end

-- The action slot (GetActionInfo / PickupMacro) behind a bar slot, on the page shown
local function Storage(util, unit, slot)
    return util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID(unit:GetCurrentPage(), slot)
end

local BAR_NAMES = { [0] = "top bar", "left bar (left modifier)", "right bar (right modifier)", "bottom bar (both modifiers)" }
local BUTTON_NAMES = { "D-pad left", "D-pad up", "D-pad right", "D-pad down",
    "left face button", "top face button", "right face button", "bottom face button" }

function FR.SlotName(slot)
    return BUTTON_NAMES[(slot - 1) % 8 + 1] .. ", " .. BAR_NAMES[math.floor((slot - 1) / 8)]
end

-- Where a ring's macro sits on the page shown (a slot 1-32), or nil
function FR.FindPlacement(ringKey)
    local util, unit = Bar()
    if not util then return nil end
    local name = FR.MACRO_NAMES[ringKey]
    for slot = 1, 32 do
        if util.IsBindablePageUnitSlotID(slot) then
            local ok, kind, id = pcall(function() return GetActionInfo(Storage(util, unit, slot)) end)
            if ok and kind == "macro" and id and (GetMacroInfo(id)) == name then return slot end
        end
    end
end

-- Puts a ring's macro on a bar slot. true, or false and why.
function FR.Place(ringKey, slot)
    local util, unit = Bar()
    if not util then return false, "this client's gamepad bar API was not found" end
    if FR.InCombat() then return false, "in combat" end
    if not util.IsBindablePageUnitSlotID(slot) then
        return false, "that button is the game's own (the top bar's face buttons)"
    end
    local name, why = FR.EnsureMacro(ringKey)
    if not name then return false, why end
    local ok, result = pcall(function()
        return util.AssignActionToGamepadStandardSlot(Storage(util, unit, slot), PickupMacro, name)
    end)
    if not ok then return false, tostring(result) end
    if result then return true end
    return false, "the game refused the slot"
end

-- Empties the slot a ring sits on. true, or false and why.
function FR.Unplace(ringKey)
    local util, unit = Bar()
    if not util then return false, "this client's gamepad bar API was not found" end
    if FR.InCombat() then return false, "in combat" end
    local slot = FR.FindPlacement(ringKey)
    if not slot then return true end
    local ok, err = pcall(function() util.ClearActionFromGamepadSlot(Storage(util, unit, slot)) end)
    if not ok then return false, tostring(err) end
    return true
end

-- The macros exist from the first login on, so they can also be dragged anywhere
FR.OnLogin(function()
    C_Timer.After(2, function() if not FR.InCombat() then FR.EnsureAllMacros(false) end end)
end)
