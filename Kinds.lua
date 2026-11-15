-- Forever Controller Rings: Kinds. A small panel to turn the kinds of a ring
-- on or off and put them in the order you like (the order of the pages).
-- Opened from "Kinds and order" in the main window.
local _, FR = ...

local ROW_H, PANEL_W = 30, 340
local panel, rowFrames, current = nil, {}, nil

local Refresh

local function MakeRow(index)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(PANEL_W - 44, ROW_H)
    row:SetPoint("TOPLEFT", 22, -64 - (index - 1) * ROW_H)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(26, 26)
    row.check:SetPoint("LEFT", 0, 0)
    row.check:SetScript("OnClick", function(self)
        FR.SetGroupEnabled(current, row.key, self:GetChecked() and true or false)
        Refresh()
    end)
    row.swatch = row:CreateTexture(nil, "ARTWORK")
    row.swatch:SetSize(14, 14)
    row.swatch:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.swatch, "RIGHT", 8, 0)
    row.down = CreateFrame("Button", nil, row, "UIPanelScrollDownButtonTemplate")
    row.down:SetSize(24, 24)
    row.down:SetPoint("RIGHT", 0, 0)
    row.down:SetScript("OnClick", function()
        FR.MoveGroup(current, row.key, 1)
        Refresh()
    end)
    row.up = CreateFrame("Button", nil, row, "UIPanelScrollUpButtonTemplate")
    row.up:SetSize(24, 24)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    row.up:SetScript("OnClick", function()
        FR.MoveGroup(current, row.key, -1)
        Refresh()
    end)
    rowFrames[index] = row
    return row
end

function Refresh()
    if not (panel and panel:IsShown() and current) then return end
    local list = FR.GroupList(current)
    panel.title:SetText((FR.LABELS[current] or current) .. ": kinds and order")
    for _, row in ipairs(rowFrames) do row:Hide() end
    for index, group in ipairs(list) do
        local row = rowFrames[index] or MakeRow(index)
        row.key = group.key
        row.check:SetChecked(group.enabled)
        row.swatch:SetColorTexture(group.color[1], group.color[2], group.color[3], 1)
        row.label:SetText(group.label)
        if group.enabled then
            row.label:SetTextColor(1, 1, 1)
        else
            row.label:SetTextColor(0.5, 0.5, 0.5)
        end
        row.swatch:SetAlpha(group.enabled and 1 or 0.35)
        if index > 1 then row.up:Enable() else row.up:Disable() end
        if index < #list then row.down:Enable() else row.down:Disable() end
        row:Show()
    end
    panel:SetHeight(92 + #list * ROW_H)
end

local function Build()
    if panel then return panel end
    panel = CreateFrame("Frame", "ForeverControllerRingsKinds", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, 200)
    panel:SetPoint("CENTER", UIParent, "CENTER", 300, 60)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:Hide()
    tinsert(UISpecialFrames, "ForeverControllerRingsKinds")
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOP", 0, -20)
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", panel.title, "BOTTOM", 0, -4)
    sub:SetText("Untick a kind to hide it. The order is the order of the pages.")
    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    panel:SetScript("OnShow", Refresh)
    return panel
end

function FR.OpenKinds(ringKey)
    Build()
    current = ringKey
    if panel:IsShown() then Refresh() else panel:Show() end
end
