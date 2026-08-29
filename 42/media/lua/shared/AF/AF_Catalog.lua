--[[ AF_Catalog
  Action + modifier dropdowns that map ONLY to live AF_Track keys.
  signature = action|modifier|amount
]]
AF = AF or {}
AF.Catalog = AF.Catalog or {}
local C = AF.Catalog

-- action id -> { label, layer, totalKey or scalar }
C.ACTIONS = {
    { id = "kill",          label = "Kill (zombies)",     layer = "killed",  total = "total" },
    { id = "damage",        label = "Damage (to zombies)", layer = "damage",  total = "total" },
    { id = "eat",           label = "Eat / drink",        layer = "eaten",   total = "total" },
    { id = "fish",          label = "Fish (catch)",       layer = "fished",  total = "total" },
    { id = "made",          label = "Craft / build",      layer = "made",    total = "total" },
    { id = "read",          label = "Read",               layer = "read",    total = "total" },
    { id = "daysSurvived",  label = "Days survived",      layer = nil,      scalar = "daysSurvived" },
}

-- Weapon families (killed.type.* / damage.type.*)
local WEAPON_TYPES = {
    { id = "type.axe",        label = "Axe" },
    { id = "type.longblunt",  label = "Long blunt" },
    { id = "type.shortblunt", label = "Short blunt" },
    { id = "type.longblade",  label = "Long blade" },
    { id = "type.shortblade", label = "Short blade" },
    { id = "type.spear",      label = "Spear" },
    { id = "type.firearm",    label = "Firearm" },
    { id = "type.barehands",  label = "Bare hands" },
    { id = "type.blunt",      label = "Blunt (any)" },
    { id = "type.bladed",     label = "Bladed (any)" },
    { id = "type.other",      label = "Other" },
}

-- Common specific weapons (killed.base.* ) — curated, expandable
local WEAPON_ITEMS = {
    { id = "base.axe",           label = "Axe (Base.Axe)" },
    { id = "base.woodaxe",       label = "Wood Axe" },
    { id = "base.handaxe",       label = "Hand Axe" },
    { id = "base.pickaxe",       label = "Pick Axe" },
    { id = "base.crowbar",       label = "Crowbar" },
    { id = "base.baseballbat",   label = "Baseball Bat" },
    { id = "base.baseballbatnails", label = "Baseball Bat (Nails)" },
    { id = "base.nightstick",    label = "Nightstick" },
    { id = "base.katana",        label = "Katana" },
    { id = "base.machete",       label = "Machete" },
    { id = "base.kitchenknife",  label = "Kitchen Knife" },
    { id = "base.huntingknife",  label = "Hunting Knife" },
    { id = "base.spearcrafted",  label = "Crafted Spear" },
    { id = "barehands",          label = "BareHands (exact)" },
}

local FOOD_ITEMS = {
    { id = "base.egg",                  label = "Egg" },
    { id = "base.apple",                label = "Apple" },
    { id = "base.banana",               label = "Banana" },
    { id = "base.orange",               label = "Orange" },
    { id = "base.chips",                label = "Chips" },
    { id = "base.crisps",               label = "Crisps" },
    { id = "base.cannedbeans",          label = "Canned Beans" },
    { id = "base.cannedchili",          label = "Canned Chili" },
    { id = "base.cannedcorn",           label = "Canned Corn" },
    { id = "base.cannedtuna",           label = "Canned Tuna" },
    { id = "base.tinnedsoup",           label = "Tinned Soup" },
    { id = "base.panfriedvegetables2",  label = "Pan Fried Vegetables" },
    { id = "base.bacon",                label = "Bacon" },
    { id = "base.steak",                label = "Steak" },
    { id = "base.chicken",              label = "Chicken" },
    { id = "base.bread",                label = "Bread" },
    { id = "base.butter",               label = "Butter" },
    { id = "base.waterbottle",          label = "Water Bottle" },
    { id = "base.pop",                  label = "Pop" },
    { id = "base.whiskeyfull",          label = "Whiskey" },
}

local FISH_ITEMS = {
    { id = "base.bass",           label = "Bass" },
    { id = "base.catfish",        label = "Catfish" },
    { id = "base.perch",          label = "Perch" },
    { id = "base.pike",           label = "Pike" },
    { id = "base.trout",          label = "Trout" },
    { id = "base.whitecrappie",   label = "White Crappie" },
    { id = "base.blackcrappie",   label = "Black Crappie" },
    { id = "base.redear",         label = "Redear" },
    { id = "base.sunfish",        label = "Sunfish" },
    { id = "base.fishfillet",     label = "Fish Fillet" },
}

local READ_BUCKETS = {
    { id = "magazinecomic", label = "Magazine / comic / newspaper" },
    { id = "recipe",        label = "Recipe / schematic" },
    { id = "book",          label = "Book (leisure)" },
    { id = "skillbook",     label = "Skill book" },
}

local function noneFirst(list)
    local out = { { id = "none", label = "(none — total)" } }
    for i = 1, #list do out[#out + 1] = list[i] end
    return out
end

function C.getActions()
    return C.ACTIONS
end

function C.getModifiersForAction(actionId)
    if actionId == "kill" or actionId == "damage" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_family", label = "— Weapon family —", header = true }
        for _, r in ipairs(WEAPON_TYPES) do out[#out + 1] = r end
        out[#out + 1] = { id = "_hdr_item", label = "— Specific weapon —", header = true }
        for _, r in ipairs(WEAPON_ITEMS) do out[#out + 1] = r end
        return out
    end
    if actionId == "eat" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_food", label = "— Food / drink —", header = true }
        for _, r in ipairs(FOOD_ITEMS) do out[#out + 1] = r end
        return out
    end
    if actionId == "fish" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_fish", label = "— Fish —", header = true }
        for _, r in ipairs(FISH_ITEMS) do out[#out + 1] = r end
        return out
    end
    if actionId == "read" then
        return noneFirst(READ_BUCKETS)
    end
    if actionId == "made" or actionId == "daysSurvived" then
        return noneFirst({})
    end
    return noneFirst({})
end

function C.isModifierHeader(modId)
    return type(modId) == "string" and modId:sub(1, 5) == "_hdr_"
end

--- Map action+modifier -> AF_Track path pieces for reading progress
--- returns { kind="layer", layer="killed", path={"type","axe"} } or { kind="scalar", key="daysSurvived" }
--- path empty means .total
function C.mapToTrack(actionId, modifierId)
    modifierId = modifierId or "none"
    if C.isModifierHeader(modifierId) then return nil end

    local act
    for _, a in ipairs(C.ACTIONS) do
        if a.id == actionId then act = a; break end
    end
    if not act then return nil end

    if act.scalar then
        if modifierId ~= "none" then return nil end
        return { kind = "scalar", key = act.scalar }
    end

    local layer = act.layer
    if not layer then return nil end

    if modifierId == "none" then
        return { kind = "layer", layer = layer, path = {}, label = layer .. ".total" }
    end

    if modifierId == "barehands" then
        return { kind = "layer", layer = layer, path = { "BareHands" }, label = layer .. ".BareHands" }
    end

    -- type.axe -> path type, axe
    if modifierId:sub(1, 5) == "type." then
        local fam = modifierId:sub(6)
        return { kind = "layer", layer = layer, path = { "type", fam }, label = layer .. ".type." .. fam }
    end

    -- base.egg -> path base, egg  (or multi-dot)
    if modifierId:find("%.", 1, true) then
        local parts = {}
        for p in string.gmatch(modifierId, "[^%.]+") do parts[#parts + 1] = p end
        if #parts >= 2 then
            return { kind = "layer", layer = layer, path = parts, label = layer .. "." .. table.concat(parts, ".") }
        end
    end

    -- read buckets sit on read.magazinecomic etc
    if layer == "read" then
        return { kind = "layer", layer = "read", path = { modifierId }, label = "read." .. modifierId }
    end

    return nil
end

function C.signature(actionId, modifierId, amount)
    return tostring(actionId) .. "|" .. tostring(modifierId or "none") .. "|" .. tostring(amount)
end

function C.parseSignature(sig)
    if type(sig) ~= "string" then return nil end
    local a, m, n = sig:match("^([^|]+)|([^|]+)|([^|]+)$")
    if not a then return nil end
    return a, m, tonumber(n)
end

function C.goalLabel(actionId, modifierId, amount)
    local actLabel = actionId
    for _, a in ipairs(C.ACTIONS) do
        if a.id == actionId then actLabel = a.label; break end
    end
    amount = tonumber(amount) or 0
    modifierId = modifierId or "none"

    local withPart
    if modifierId == "none" then
        if actionId == "kill" or actionId == "damage" then
            withPart = "with any weapon"
        elseif actionId == "eat" then
            withPart = "any food/drink"
        elseif actionId == "fish" then
            withPart = "any catch"
        elseif actionId == "made" then
            withPart = "any craft/build"
        elseif actionId == "read" then
            withPart = "any reading"
        elseif actionId == "daysSurvived" then
            withPart = nil
        else
            withPart = "any"
        end
    else
        local modLabel = modifierId
        for _, m in ipairs(C.getModifiersForAction(actionId) or {}) do
            if m.id == modifierId and not m.header then
                modLabel = m.label
                break
            end
        end
        -- strip trailing " (Base.Axe)" style ids for cleaner rows if present
        modLabel = tostring(modLabel):gsub("%s+%[.-%]$", "")
        if actionId == "kill" or actionId == "damage" then
            -- "Axe" family vs specific weapon
            if modifierId:sub(1, 5) == "type." then
                withPart = "with any " .. modLabel
            else
                withPart = "with " .. modLabel
            end
        elseif actionId == "eat" then
            withPart = "only " .. modLabel
        elseif actionId == "fish" then
            withPart = "only " .. modLabel
        elseif actionId == "read" then
            withPart = "only " .. modLabel
        else
            withPart = modLabel
        end
    end

    if actionId == "daysSurvived" then
        return string.format("%s, %s day(s)", actLabel, tostring(amount))
    end
    if withPart then
        return string.format("%s, %s, %s", actLabel, tostring(amount), withPart)
    end
    return string.format("%s, %s", actLabel, tostring(amount))
end

function C.rewardLabel(rewardType, reward, rewardAmount)
    rewardType = tostring(rewardType or "item")
    reward = tostring(reward or "")
    rewardAmount = tonumber(rewardAmount) or 1
    if reward == "" then return "no reward" end
    if rewardType == "trait" then
        return "trait " .. reward
    end
    if rewardType == "skill_xp" then
        local skillName = reward
        if AF.Rewards and AF.Rewards.perkDisplayName then
            skillName = AF.Rewards.perkDisplayName(reward)
        end
        return tostring(rewardAmount) .. " " .. skillName .. " XP"
    end
    -- item: prefer display name if getItemNameFromFullType exists
    local itemName = reward
    pcall(function()
        if getItemNameFromFullType then
            local n = getItemNameFromFullType(reward)
            if n and n ~= "" then itemName = n end
        end
    end)
    if rewardAmount ~= 1 then
        return "x" .. tostring(rewardAmount) .. " " .. itemName
    end
    return itemName
end

--- Full list row: Name | goal | reward
function C.rowLabel(def)
    if type(def) ~= "table" then return tostring(def) end
    local name = tostring(def.name or "?")
    -- always rebuild so UI text stays current (no cached unicode junk)
    local goal = C.goalLabel(def.action, def.modifier, def.amount)
    local rew = C.rewardLabel(def.rewardType, def.reward, def.rewardAmount)
    return name .. " | " .. goal .. " | " .. rew
end

--- Read current progress number from player track data
function C.readProgress(player, actionId, modifierId)
    if not player or not AF.Track or not AF.Track.getData then return 0 end
    local d = AF.Track.getData(player)
    if not d then return 0 end
    local map = C.mapToTrack(actionId, modifierId)
    if not map then return 0 end
    if map.kind == "scalar" then
        return tonumber(d[map.key]) or 0
    end
    local node = d[map.layer]
    if type(node) ~= "table" then return 0 end
    if not map.path or #map.path == 0 then
        return tonumber(node.total) or 0
    end
    for i = 1, #map.path do
        local k = map.path[i]
        if type(node) ~= "table" then return 0 end
        node = node[k]
    end
    if type(node) == "number" then return node end
    if type(node) == "table" and type(node.total) == "number" then return node.total end
    if type(node) == "table" and type(node._n) == "number" then return node._n end
    return tonumber(node) or 0
end

print("[AF] AF_Catalog loaded")
