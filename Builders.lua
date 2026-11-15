-- Forever Controller Rings: Builders. What goes on each ring, read from the bags.
-- Every builder returns a list of entries:
--   { itemID, label, icon, type = "item", value = "item:<id>" }
-- Out of combat only: the ring's secure data cannot change in combat.
local _, FR = ...

local MAX_ENTRIES = 96 -- (12 pages of 8)
local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local ITEM_CLASS = Enum and Enum.ItemClass or {}
local CLASS_CONSUMABLE = ITEM_CLASS.Consumable or 0
local CLASS_QUESTITEM = ITEM_CLASS.Questitem or 12

-- Groups, in the order they sit round the ring, each with its colour (the
-- rim of its slots) and the name shown in the middle of the ring. Items are
-- gathered by group, the best first inside it.
local GROUPS = {
    food = { order = 1, label = "Food & drink", color = { 0.95, 0.60, 0.20 } },
    potion = { order = 3, label = "Potion", color = { 0.90, 0.30, 0.30 } },
    bandage = { order = 4, label = "Bandage", color = { 0.92, 0.88, 0.75 } },
    elixir = { order = 5, label = "Elixir / Flask", color = { 0.35, 0.80, 0.45 } },
    scroll = { order = 6, label = "Scroll", color = { 0.92, 0.76, 0.35 } },
    other = { order = 7, label = "Other", color = { 0.66, 0.52, 0.88 } },
    questuse = { order = 1, label = "Quest item", color = { 0.25, 0.72, 0.79 } },
    queststart = { order = 2, label = "Starts a quest", color = { 0.96, 0.78, 0.29 } },
}
-- consumable subclass -> group (5 is food & drink together)
local SUBCLASS_GROUP = { [5] = "food", [1] = "potion", [7] = "bandage", [4] = "scroll", [2] = "elixir", [3] = "elixir" }

-- The kinds each ring has, in their default order; the player can turn kinds
-- off and reorder them (the "Kinds and order" panel keeps that in FR.db.groups).
FR.GROUP_DEFAULTS = {
    consumables = { "food", "potion", "bandage", "elixir", "scroll", "other" },
    quest = { "questuse", "queststart" },
}

-- The kinds of a ring in the player's order: { key, label, color, enabled }.
function FR.GroupList(ringKey)
    local cfg = FR.db and FR.db.groups and FR.db.groups[ringKey] or {}
    local defaults = FR.GROUP_DEFAULTS[ringKey] or {}
    local valid = {}
    for _, key in ipairs(defaults) do valid[key] = true end
    local list, seen = {}, {}
    local function add(key)
        if valid[key] and not seen[key] then
            seen[key] = true
            local group = GROUPS[key]
            list[#list + 1] = {
                key = key, label = group.label, color = group.color,
                enabled = not (cfg.off and cfg.off[key]),
            }
        end
    end
    for _, key in ipairs(cfg.order or {}) do add(key) end
    for _, key in ipairs(defaults) do add(key) end
    return list
end

local function GroupConfig(ringKey)
    FR.db.groups = FR.db.groups or {}
    FR.db.groups[ringKey] = FR.db.groups[ringKey] or {}
    local cfg = FR.db.groups[ringKey]
    cfg.off = cfg.off or {}
    return cfg
end

function FR.SetGroupEnabled(ringKey, key, enabled)
    GroupConfig(ringKey).off[key] = (not enabled) or nil
    FR.Rebuild()
end

-- delta -1: one place earlier, +1: one later
function FR.MoveGroup(ringKey, key, delta)
    local keys = {}
    for i, group in ipairs(FR.GroupList(ringKey)) do keys[i] = group.key end
    for i, k in ipairs(keys) do
        local j = i + delta
        if k == key and keys[j] then
            keys[i], keys[j] = keys[j], keys[i]
            break
        end
    end
    GroupConfig(ringKey).order = keys
    FR.Rebuild()
end

-- (item level and required level, for "best first"; 0 until the item is cached)
local function Levels(itemID)
    local ok, _, _, _, itemLevel, minLevel = pcall(C_Item.GetItemInfo, itemID)
    if not ok then return 0, 0 end
    return tonumber(minLevel) or 0, tonumber(itemLevel) or 0
end

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

local function MakeEntry(itemID, icon, groupKey)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID) -- GET_ITEM_INFO_RECEIVED rebuilds
    end
    local group = GROUPS[groupKey or "other"]
    return {
        itemID = itemID,
        label = name or ("item:" .. itemID),
        icon = icon,
        type = "item",
        value = "item:" .. itemID,
        group = group.label,
        groupKey = groupKey or "other",
        color = group.color,
    }
end

local function ByLabel(a, b) return a.label < b.label end

local function Cap(list)
    for i = #list, MAX_ENTRIES + 1, -1 do list[i] = nil end
    return list
end

-- Keep the kinds that are on, in the player's order of kinds, `tie` inside a
-- kind. Returns the list and how many items there were before filtering.
local function Arrange(items, ringKey, tie)
    local rank, on = {}, {}
    for i, group in ipairs(FR.GroupList(ringKey)) do
        rank[group.key] = i
        on[group.key] = group.enabled
    end
    local kept = {}
    for _, entry in ipairs(items) do
        if on[entry.groupKey] ~= false then kept[#kept + 1] = entry end
    end
    table.sort(kept, function(a, b)
        local ra, rb = rank[a.groupKey] or 99, rank[b.groupKey] or 99
        if ra ~= rb then return ra < rb end
        return tie(a, b)
    end)
    return kept, #items
end

local function EmptyText(kept, total, none)
    if total > 0 and #kept == 0 then return "Every kind is turned off (Kinds and order)" end
    return none
end

---------------------------------------------------------------------------
-- Consumables: everything in your bags of item class Consumable
---------------------------------------------------------------------------
local function BuildConsumables()
    local items = {}
    EachBagItem(function(itemID)
        local icon, classID, subclassID = Instant(itemID)
        if classID == CLASS_CONSUMABLE then
            local key = SUBCLASS_GROUP[subclassID] or "other"
            local entry = MakeEntry(itemID, icon, key)
            entry.minLevel, entry.itemLevel = Levels(itemID)
            items[#items + 1] = entry
        end
    end)
    local kept, total = Arrange(items, "consumables", function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
        if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
        return a.label < b.label
    end)
    Cap(kept).empty = EmptyText(kept, total, "No consumables in your bags")
    return kept
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
            use[#use + 1] = MakeEntry(itemID, icon, "questuse")
        elseif info and info.questID and not info.isActive and not QuestDone(info.questID) then
            starts[#starts + 1] = MakeEntry(itemID, icon, "queststart")
        end
    end)
    for _, entry in ipairs(starts) do use[#use + 1] = entry end
    local kept, total = Arrange(use, "quest", ByLabel)
    Cap(kept).empty = EmptyText(kept, total, "No quest items in your bags")
    return kept
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
