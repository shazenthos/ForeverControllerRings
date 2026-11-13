-- Forever Controller Rings: Builders. What goes on each ring, read from the bags.
-- Every builder returns a list of entries:
--   { itemID, label, icon, type = "item", value = "item:<id>" }
-- Out of combat only: the ring's secure data cannot change in combat.
local _, FR = ...

local MAX_ENTRIES = 24
local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local ITEM_CLASS = Enum and Enum.ItemClass or {}
local CLASS_CONSUMABLE = ITEM_CLASS.Consumable or 0
local CLASS_QUESTITEM = ITEM_CLASS.Questitem or 12

-- Consumable subclasses in display order: food & drink, potions, bandages,
-- scrolls, elixirs, flasks; anything else (Forever's draughts, devices...) last.
local SUBCLASS_ORDER = { [5] = 1, [1] = 2, [7] = 3, [4] = 4, [2] = 5, [3] = 6 }

local function EachBagItem(fn)
    local seen = {}
    for bag = 0, NUM_BAGS do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and not seen[itemID] then
                seen[itemID] = true
                fn(itemID, bag, slot)
            end
        end
    end
end

-- icon, classID, subclassID (no server query needed)
local function Instant(itemID)
    local _, _, _, _, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return icon, classID, subclassID
end

local function MakeEntry(itemID, icon)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID) -- GET_ITEM_INFO_RECEIVED rebuilds
    end
    return {
        itemID = itemID,
        label = name or ("item:" .. itemID),
        icon = icon,
        type = "item",
        value = "item:" .. itemID,
    }
end

local function ByLabel(a, b) return a.label < b.label end

local function Cap(list)
    for i = #list, MAX_ENTRIES + 1, -1 do list[i] = nil end
    return list
end

---------------------------------------------------------------------------
-- Consumables: everything in your bags of item class Consumable
---------------------------------------------------------------------------
local function BuildConsumables()
    local items = {}
    EachBagItem(function(itemID)
        local icon, classID, subclassID = Instant(itemID)
        if classID == CLASS_CONSUMABLE then
            local entry = MakeEntry(itemID, icon)
            entry.order = SUBCLASS_ORDER[subclassID] or 99
            items[#items + 1] = entry
        end
    end)
    table.sort(items, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)
    Cap(items).empty = "No consumables in your bags"
    return items
end

---------------------------------------------------------------------------
-- Quest items: ones you use for a quest, then ones that start a quest.
-- The game marks them in the bags (GetContainerItemQuestInfo); a quest item
-- you can use has an on-use spell. Items a quest only asks you to COLLECT
-- (cloth, ore...) are not usable, so they never belong here.
---------------------------------------------------------------------------
local function QuestDone(questID)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

local function BuildQuestItems()
    local use, starts = {}, {}
    EachBagItem(function(itemID, bag, slot)
        local icon, classID = Instant(itemID)
        local info = C_Container.GetContainerItemQuestInfo
            and C_Container.GetContainerItemQuestInfo(bag, slot)
        local hasSpell = C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
        if hasSpell and (classID == CLASS_QUESTITEM or (info and (info.isQuestItem or info.questID))) then
            use[#use + 1] = MakeEntry(itemID, icon)
        elseif info and info.questID and not info.isActive and not QuestDone(info.questID) then
            starts[#starts + 1] = MakeEntry(itemID, icon)
        end
    end)
    table.sort(use, ByLabel)
    table.sort(starts, ByLabel)
    for _, entry in ipairs(starts) do use[#use + 1] = entry end
    Cap(use).empty = "No quest items in your bags"
    return use
end

FR.Builders = {
    consumables = BuildConsumables,
    quest = BuildQuestItems,
}

-- Rings can change when the bags, the quest log or the item cache change
FR.REBUILD_EVENTS = {
    "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}
