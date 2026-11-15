-- Forever Controller Rings: UI. One small window: each ring, where it is mapped, and
-- Map / Clear. Opened from the Addons list (the minimap-style addon
-- compartment), Options > AddOns > Forever Controller Rings, or "/fcr".
local _, FR = ...

local WIDTH, ROW_H = 470, 94
local win, rows, releaseBox, rumbleBox = nil, {}, nil, nil

local function RefreshRow(row)
    local slot = FR.FindPlacement(row.ring)
    if not FR.BarAvailable() then
        row.status:SetText("|cffff6666Gamepad bar not available in this client|r")
        row.map:Disable()
        row.clear:Disable()
    elseif slot then
        row.status:SetText("|cff66ff66Mapped:|r " .. FR.SlotName(slot))
        row.map:SetText("Remap")
        row.map:Enable()
        row.clear:Enable()
    else
        row.status:SetText("|cffaaaaaaNot mapped|r")
        row.map:SetText("Map")
        row.map:Enable()
        row.clear:Disable()
    end
end

function FR.RefreshWindow()
    if not (win and win:IsShown()) then return end
    for _, row in ipairs(rows) do RefreshRow(row) end
    releaseBox:SetChecked(FR.db and FR.db.release or false)
    rumbleBox:SetChecked(FR.db and FR.db.rumble or false)
end

local function Build()
    if win then return win end
    win = CreateFrame("Frame", "ForeverControllerRingsWindow", UIParent, "BackdropTemplate")
    win:SetSize(WIDTH, 70 + #FR.RINGS * ROW_H + 78)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    win:Hide()
    tinsert(UISpecialFrames, "ForeverControllerRingsWindow")

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Forever Controller Rings")
    local sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetText("Map a ring to your gamepad bar like a spell")
    local closeButton = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)

    for index, ringKey in ipairs(FR.RINGS) do
        local row = CreateFrame("Frame", nil, win)
        row.ring = ringKey
        row:SetSize(WIDTH - 50, ROW_H)
        row:SetPoint("TOPLEFT", 25, -62 - (index - 1) * ROW_H)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(44, 44)
        row.icon:SetPoint("LEFT", 0, 0)
        row.icon:SetTexture("Interface\\Icons\\" .. FR.ICONS[ringKey])
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -2)
        row.name:SetText(FR.LABELS[ringKey])
        row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.status:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -6)
        row.status:SetWidth(210)
        row.status:SetJustifyH("LEFT")
        row.kinds = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.kinds:SetSize(120, 20)
        row.kinds:SetPoint("TOPLEFT", row.status, "BOTTOMLEFT", 0, -6) -- under the status, whatever its length
        row.kinds:SetText("Kinds and order")
        row.kinds:SetScript("OnClick", function() FR.OpenKinds(ringKey) end)
        row.clear = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.clear:SetSize(64, 24)
        row.clear:SetPoint("RIGHT", 0, 0)
        row.clear:SetText("Clear")
        row.map = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.map:SetSize(72, 24)
        row.map:SetPoint("RIGHT", row.clear, "LEFT", -6, 0)
        row.map:SetText("Map")
        row.map:SetScript("OnClick", function()
            if FR.InCombat() then return FR.Print("not in combat") end
            win:Hide() -- the pad presses must reach the mapping panel, not this window
            FR.BeginMap(ringKey, function() FR.OpenWindow() end)
        end)
        row.clear:SetScript("OnClick", function()
            local ok, why = FR.Unplace(ringKey)
            if not ok then FR.Print("could not clear: " .. tostring(why)) end
            FR.RefreshWindow()
        end)
        rows[index] = row
    end

    releaseBox = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    releaseBox:SetPoint("BOTTOMLEFT", 22, 16)
    releaseBox:SetScript("OnClick", function(self)
        FR.db.release = self:GetChecked() and true or false
        FR.ApplySettings()
    end)
    local label = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", releaseBox, "RIGHT", 4, 1)
    label:SetText("Use the slot when I let go of the stick")

    rumbleBox = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    rumbleBox:SetPoint("BOTTOMLEFT", 22, 44)
    rumbleBox:SetScript("OnClick", function(self)
        FR.db.rumble = self:GetChecked() and true or false
        if FR.db.rumble then FR.Buzz("open") end
    end)
    local rumbleLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rumbleLabel:SetPoint("LEFT", rumbleBox, "RIGHT", 4, 1)
    rumbleLabel:SetText("Vibrate the controller")

    win:SetScript("OnShow", FR.RefreshWindow)
    local events = CreateFrame("Frame", nil, win)
    events:RegisterEvent("UPDATE_MACROS")
    events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    events:SetScript("OnEvent", function() FR.RefreshWindow() end)
    return win
end

function FR.OpenWindow()
    Build():Show()
end

function FR.ToggleWindow()
    Build()
    if win:IsShown() then win:Hide() else win:Show() end
end

-- Addon list entry (the TOC names this function)
function ForeverControllerRings_OnCompartmentClick()
    FR.ToggleWindow()
end

-- Options > AddOns > Forever Controller Rings: a page with a button that opens the window
FR.OnLogin(function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    pcall(function()
        local canvas = CreateFrame("Frame")
        local text = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 16, -16)
        text:SetText("Two rings for your gamepad bar: consumables and quest items.")
        local button = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
        button:SetSize(220, 26)
        button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
        button:SetText("Open the mapping window")
        button:SetScript("OnClick", function() FR.OpenWindow() end)
        local category = Settings.RegisterCanvasLayoutCategory(canvas, "Forever Controller Rings")
        Settings.RegisterAddOnCategory(category)
    end)
end)
