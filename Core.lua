-- Forever Controller Rings: Core. Saved settings, login hooks, slash commands.
-- The secure ring design follows patterns proven in ImprovedForever (MIT,
-- github.com/markgravity/ImprovedForever): a secure handler frame, secure
-- buttons wrapped with restricted snippets, stick directions delivered as
-- keys while the ring is up.
local ADDON, FR = ...
_G.ForeverControllerRings = FR

FR.RINGS = { "consumables", "quest" }
FR.LABELS = { consumables = "Consumables", quest = "Quest Items" }

local DEFAULTS = {
    release = true, -- use the picked slot when the right stick is let go
}

local loginHooks = {}
function FR.OnLogin(fn) loginHooks[#loginHooks + 1] = fn end

function FR.Print(...)
    print("|cff66ccffForever Controller Rings|r:", ...)
end

function FR.InCombat()
    return InCombatLockdown() or false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    ForeverControllerRingsDB = ForeverControllerRingsDB or {}
    FR.db = ForeverControllerRingsDB
    for key, value in pairs(DEFAULTS) do
        if FR.db[key] == nil then FR.db[key] = value end
    end
    for _, fn in ipairs(loginHooks) do fn() end
end)

---------------------------------------------------------------------------
-- /fcr
---------------------------------------------------------------------------
local BARS = { top = 0, left = 1, right = 2, both = 3 }
-- D-pad left / up / right / down, then the face buttons (left, top, right, bottom)
local BUTTONS = { left = 1, up = 2, right = 3, down = 4, west = 5, north = 6, east = 7, south = 8 }

local function Help()
    FR.Print("/fcr                        open the mapping window (the normal way)")
    FR.Print("Advanced / debugging:")
    FR.Print("/fcr macros                 create the two ring macros (account-wide)")
    FR.Print("/fcr place <ring> <bar> <button>   put a ring on the gamepad bar")
    FR.Print("   ring: consumables | quest")
    FR.Print("   bar: top | left | right | both  (left/right = the modifier held)")
    FR.Print("   button: left up right down west north east south")
    FR.Print("/fcr place <ring> <slot 1-32>      same, by slot number")
    FR.Print("/fcr release on|off         use a slot when the stick is let go")
    FR.Print("/fcr rebuild                refill the rings from your bags")
    FR.Print("/fcr probe                  check which APIs this client has")
    FR.Print("/fcr debug [off]             print every stick key event of an open ring")
end

SLASH_FCR1 = "/fcr"
SlashCmdList["FCR"] = function(msg)
    local args = {}
    for word in tostring(msg or ""):lower():gmatch("%S+") do args[#args + 1] = word end
    local cmd = args[1]
    if cmd == "macros" then
        FR.EnsureAllMacros(true)
    elseif cmd == "place" then
        local ring = args[2]
        if not FR.LABELS[ring or ""] then return Help() end -- (advanced: the window does this)
        local slot
        if BARS[args[3] or ""] and BUTTONS[args[4] or ""] then
            slot = BARS[args[3]] * 8 + BUTTONS[args[4]]
        else
            slot = tonumber(args[3])
        end
        if not slot then return Help() end
        local ok, why = FR.Place(ring, slot)
        FR.Print(ok and ("placed " .. FR.LABELS[ring] .. " on slot " .. slot) or ("could not place: " .. tostring(why)))
    elseif cmd == "release" then
        FR.db.release = (args[2] ~= "off")
        FR.ApplySettings()
        FR.Print("use on stick release: " .. (FR.db.release and "on" or "off"))
    elseif cmd == "rebuild" then
        FR.Rebuild()
        FR.Print("rings rebuilt")
    elseif cmd == "probe" then
        FR.Probe()
    elseif cmd == "debug" then
        FR.debug = (args[2] ~= "off")
        FR.Print("debug " .. (FR.debug and "on: every stick key event is printed" or "off"))
    elseif cmd == "help" then
        Help()
    else
        FR.ToggleWindow() -- the normal way: map the rings in the window
    end
end

function FR.Probe()
    local function yes(v) return v and "yes" or "NO" end
    local P = FR.Print
    local _, _, _, toc = GetBuildInfo()
    P("interface", tostring(toc), "project", tostring(WOW_PROJECT_ID))
    P("GamepadActionBarBindingUtil:", yes(_G.GamepadActionBarBindingUtil),
        " GamepadMainActionBarFrame:", yes(_G.GamepadMainActionBarFrame),
        " PageUnit:", yes(_G.GamepadMainActionBarFrame and _G.GamepadMainActionBarFrame.PageUnit))
    P("C_GamePad.GetDeviceMappedState:", yes(C_GamePad and C_GamePad.GetDeviceMappedState),
        " StickConfigNameToIndex:", yes(C_GamePad and C_GamePad.StickConfigNameToIndex),
        " ButtonBindingToIndex:", yes(C_GamePad and C_GamePad.ButtonBindingToIndex))
    P("C_Container.GetContainerItemQuestInfo:", yes(C_Container and C_Container.GetContainerItemQuestInfo),
        " C_Item.GetItemInfoInstant:", yes(C_Item and C_Item.GetItemInfoInstant),
        " C_Item.GetItemSpell:", yes(C_Item and C_Item.GetItemSpell))
    P("GamePadStickAxisButtons =", tostring(GetCVar("GamePadStickAxisButtons")),
        " ActionButtonUseKeyDown =", tostring(GetCVar("ActionButtonUseKeyDown")))
    P("right stick index:", tostring(FR.StickIndex and FR.StickIndex("Right")),
        " macros:", yes(GetMacroIndexByName(FR.MACRO_NAMES and FR.MACRO_NAMES.consumables or "") > 0))
end
