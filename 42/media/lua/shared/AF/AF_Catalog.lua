--[[ AF_Catalog
  Action + modifier dropdowns that map ONLY to live AF_Track keys.
  signature = action|modifier|amount
]]
AF = AF or {}
AF.Catalog = AF.Catalog or {}
local C = AF.Catalog

C.ACTIONS = {
    { id = "kill",          label = "Kill (zombies)",      layer = "killed", total = "total" },
    { id = "damage",        label = "Damage (to zombies)", layer = "damage", total = "total" },
    { id = "eat",           label = "Eat / drink",         layer = "eaten",  total = "total" },
    { id = "fish",          label = "Fish (catch)",        layer = "fished", total = "total" },
    { id = "made",          label = "Craft / build",       layer = "made",   total = "total" },
    { id = "read",          label = "Read",                layer = "read",   total = "total" },
    { id = "daysSurvived",  label = "Days survived",       layer = nil,     scalar = "daysSurvived" },
    { id = "distance",      label = "Distance traveled",   layer = "distance", total = "total" },
}

-- Weapon families (killed.type.* / damage.type.*)
local WEAPON_TYPES = {
    { id = "type.axe",        label = "Axe (weapon family)" },
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

-- Specific weapons — id = track path; fullType for display-name lookup
-- Base.Axe display name in B42 is "Firefighter Axe"
local WEAPON_ITEMS = {
    { id = "base.axe",              fullType = "Base.Axe",              label = "Firefighter Axe" },
    { id = "base.woodaxe",          fullType = "Base.WoodAxe",          label = "Wood Axe" },
    { id = "base.handaxe",          fullType = "Base.HandAxe",          label = "Hatchet" },
    { id = "base.pickaxe",          fullType = "Base.PickAxe",          label = "Pick Axe" },
    { id = "base.crowbar",          fullType = "Base.Crowbar",          label = "Crowbar" },
    { id = "base.baseballbat",      fullType = "Base.BaseballBat",      label = "Baseball Bat" },
    { id = "base.baseballbatnails", fullType = "Base.BaseballBatNails", label = "Baseball Bat w/Nails" },
    { id = "base.nightstick",       fullType = "Base.Nightstick",       label = "Nightstick" },
    { id = "base.katana",           fullType = "Base.Katana",           label = "Katana" },
    { id = "base.machete",          fullType = "Base.Machete",          label = "Machete" },
    { id = "base.kitchenknife",     fullType = "Base.KitchenKnife",     label = "Kitchen Knife" },
    { id = "base.huntingknife",     fullType = "Base.HuntingKnife",     label = "Hunting Knife" },
    { id = "base.spearcrafted",     fullType = "Base.SpearCrafted",     label = "Crafted Spear" },
    { id = "base.assaultrifle",     fullType = "Base.AssaultRifle",     label = "M16 Assault Rifle" },
    { id = "barehands",             fullType = nil,                     label = "BareHands (exact)" },
}

local FOOD_ITEMS = {
    { id = "base.egg",                  label = "Egg" },
    { id = "base.apple",                label = "Apple" },
    { id = "base.banana",               label = "Banana" },
    { id = "base.orange",               label = "Orange" },
    { id = "base.chips",                label = "Chips" },
    { id = "base.crisps",               label = "Crisps" },
    { id = "base.crisps2",              label = "Crisps 2" },
    { id = "base.cannedbeans",          label = "Canned Beans" },
    { id = "base.cannedchili",          label = "Canned Chili" },
    { id = "base.cannedcorn",           label = "Canned Corn" },
    { id = "base.cannedtuna",           label = "Canned Tuna" },
    { id = "base.tinnedsoup",           label = "Tinned Soup" },
    { id = "base.tinnedbeans",          label = "Tinned Beans" },
    { id = "base.panfriedvegetables2",  label = "Pan Fried Vegetables" },
    { id = "base.bacon",                label = "Bacon" },
    { id = "base.steak",                label = "Steak" },
    { id = "base.chicken",              label = "Chicken" },
    { id = "base.bread",                label = "Bread" },
    { id = "base.butter",               label = "Butter" },
    { id = "base.cheese",               label = "Cheese" },
    { id = "base.beefjerky",            label = "Beef Jerky" },
    { id = "base.salami",               label = "Salami" },
    { id = "base.icecream",             label = "Ice Cream" },
    { id = "base.icecreamsandwich",     label = "Ice Cream Sandwich" },
    { id = "base.doughnutjelly",        label = "Doughnut (Jelly)" },
    { id = "base.pieapple",             label = "Apple Pie" },
    { id = "base.chocolate_smirkers",   label = "Chocolate" },
    { id = "base.fudgeepop",            label = "Fudgesicle" },
    { id = "base.hihis",                label = "Hi-His" },
    { id = "base.milk",                 label = "Milk" },
    { id = "base.waterbottle",          label = "Water Bottle" },
    { id = "base.pop",                  label = "Pop" },
    { id = "base.whiskey",              label = "Whiskey" },
}

local FISH_ITEMS = {
    { id = "base.bass",              label = "Bass" },
    { id = "base.smallmouthbass",    label = "Smallmouth Bass" },
    { id = "base.largemouthbass",    label = "Largemouth Bass" },
    { id = "base.catfish",           label = "Catfish" },
    { id = "base.perch",             label = "Perch" },
    { id = "base.yellowperch",       label = "Yellow Perch" },
    { id = "base.pike",              label = "Pike" },
    { id = "base.trout",             label = "Trout" },
    { id = "base.whitecrappie",      label = "White Crappie" },
    { id = "base.blackcrappie",      label = "Black Crappie" },
    { id = "base.redear",            label = "Redear" },
    { id = "base.sunfish",           label = "Sunfish" },
    { id = "base.fishfillet",        label = "Fish Fillet" },
}

-- Curated craft keys matching Track.addMade / AF_check paths
local MADE_CURATED = {
    { id = "recipe.carvesmallhandle",      label = "Recipe: Carve small handle" },
    { id = "recipe.collectseeds",          label = "Recipe: Collect seeds" },
    { id = "recipe.fillsaw",               label = "Recipe: Fill saw" },
    { id = "recipe.fixwithglue",         label = "Recipe: Fix with glue" },
    { id = "recipe.maketinfoilhat",        label = "Recipe: Make tinfoil hat" },
    { id = "recipe.makewoodenshinglemold", label = "Recipe: Wooden shingle mold" },
    { id = "recipe.openeggcarton",         label = "Recipe: Open egg carton" },
    { id = "recipe.placeinbox",            label = "Recipe: Place in box" },
    { id = "recipe.ripdenimclothing",      label = "Recipe: Rip denim clothing" },
    { id = "recipe.sharpenblade",          label = "Recipe: Sharpen blade" },
    { id = "recipe.slicefillet",           label = "Recipe: Slice fillet" },
    { id = "base.barbedwire",              label = "Result: Barbed wire" },
    { id = "base.holstershoulder",         label = "Result: Shoulder holster" },
    { id = "craft.isadditeminrecipe",      label = "Craft step: add item in recipe" },
    { id = "build.isbuildaction",          label = "Build: timed build action" },
}

local DISTANCE_MODS = {
    { id = "combat",          label = "Combat stance" },
    { id = "walking",         label = "Walking" },
    { id = "running",         label = "Running" },
    { id = "sprinting",       label = "Sprinting" },
    { id = "sneaking",        label = "Any sneaking" },
    { id = "sneak_walking",   label = "Sneak walking" },
    { id = "sneak_running",   label = "Sneak running" },
    { id = "sneak_sprinting", label = "Sneak sprinting" },
    { id = "sneak_combat",    label = "Sneak combat stance" },
    { id = "vehicle",         label = "By car / vehicle" },
    { id = "day",             label = "During day" },
    { id = "night",           label = "During night" },
}

local READ_BUCKETS = {
    { id = "magazinecomic", label = "Magazine / comic / newspaper" },
    { id = "recipe",        label = "Recipe / schematic" },
    { id = "book",          label = "Book (leisure)" },
    { id = "skillbook",     label = "Skill book" },
}

local function noneFirst(list, noneLabel)
    noneLabel = noneLabel or "(Total)"
    local out = { { id = "none", label = noneLabel } }
    for i = 1, #list do out[#out + 1] = list[i] end
    return out
end

local function displayItemName(fullType, fallback)
    local name = fallback or fullType or "?"
    if not fullType or fullType == "" then return name end
    pcall(function()
        if getItemNameFromFullType then
            local n = getItemNameFromFullType(fullType)
            if n and n ~= "" then name = n end
        end
    end)
    return name
end

local function prettyWeaponItem(row)
    local lab = row.label or row.id
    if row.fullType then
        lab = displayItemName(row.fullType, lab)
    end
    -- Force B42 Firefighter Axe naming for Base.Axe track key
    if row.id == "base.axe" then
        lab = displayItemName("Base.Axe", "Firefighter Axe")
        if lab == "Axe" or lab == "Base.Axe" then
            lab = "Firefighter Axe"
        end
    end
    return { id = row.id, label = lab, fullType = row.fullType }
end

--- Walk made/eaten/etc tree into modifier ids (dot path under layer)
local function collectTrackMods(node, prefix, out, seen)
    if type(node) ~= "table" then return end
    for k, v in pairs(node) do
        if k ~= "total" and k ~= "type" then
            local path = (prefix == "" and tostring(k)) or (prefix .. "." .. tostring(k))
            if type(v) == "number" then
                if not seen[path] then
                    seen[path] = true
                    local lab = path
                    -- nicer labels for known prefixes
                    if path:sub(1, 7) == "recipe." then
                        lab = "Recipe: " .. path:sub(8)
                    elseif path:sub(1, 6) == "craft." then
                        lab = "Craft step: " .. path:sub(7)
                    elseif path:sub(1, 6) == "build." then
                        lab = "Build: " .. path:sub(7)
                    elseif path:sub(1, 5) == "base." then
                        local ft = "Base." .. path:sub(6)
                        -- camel-ish: barbedwire stays; try Base.BarbedWire via script manager is hard
                        lab = "Result: " .. displayItemName(ft, path:sub(6))
                    end
                    out[#out + 1] = { id = path, label = lab .. "  [" .. tostring(v) .. "]" }
                end
            elseif type(v) == "table" then
                collectTrackMods(v, path, out, seen)
            end
        end
    end
end

local function liveMadeModifiers()
    local out = {}
    local seen = {}
    pcall(function()
        local p = getSpecificPlayer and getSpecificPlayer(0) or getPlayer and getPlayer()
        if not p or not AF.Track or not AF.Track.getData then return end
        local d = AF.Track.getData(p)
        if d and type(d.made) == "table" then
            collectTrackMods(d.made, "", out, seen)
        end
    end)
    table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return out, seen
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
        for _, r in ipairs(WEAPON_ITEMS) do
            out[#out + 1] = prettyWeaponItem(r)
        end
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
    if actionId == "distance" then
        return noneFirst(DISTANCE_MODS, "(All Non-Vehicle)")
    end
    if actionId == "made" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_made_curated", label = "— Common crafts —", header = true }
        local seen = {}
        for _, r in ipairs(MADE_CURATED) do
            out[#out + 1] = r
            seen[r.id] = true
        end
        -- live keys from this character's made counters
        local live, liveSeen = liveMadeModifiers()
        local anyLive = false
        for i = 1, #live do
            if not seen[live[i].id] then
                if not anyLive then
                    out[#out + 1] = { id = "_hdr_made_live", label = "— Seen on this character —", header = true }
                    anyLive = true
                end
                out[#out + 1] = live[i]
                seen[live[i].id] = true
            end
        end
        return out
    end
    if actionId == "daysSurvived" then
        return noneFirst({})
    end
    return noneFirst({})
end

function C.isModifierHeader(modId)
    return type(modId) == "string" and modId:sub(1, 5) == "_hdr_"
end

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

    -- base.egg / recipe.foo / craft.x / build.y
    if modifierId:find(".", 1, true) then
        local parts = {}
        for p in string.gmatch(modifierId, "[^%.]+") do parts[#parts + 1] = p end
        if #parts >= 2 then
            return { kind = "layer", layer = layer, path = parts, label = layer .. "." .. table.concat(parts, ".") }
        end
    end

    if layer == "read" then
        return { kind = "layer", layer = "read", path = { modifierId }, label = "read." .. modifierId }
    end
    if layer == "distance" then
        return { kind = "layer", layer = "distance", path = { modifierId }, label = "distance." .. modifierId }
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
        elseif actionId == "distance" then
            withPart = "all non-vehicle"
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
        modLabel = tostring(modLabel):gsub("%s+%[.-%]$", "")
        if actionId == "kill" or actionId == "damage" then
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
        elseif actionId == "distance" then
            withPart = modLabel
        elseif actionId == "made" then
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
    local itemName = displayItemName(reward, reward)
    if rewardAmount ~= 1 then
        return "x" .. tostring(rewardAmount) .. " " .. itemName
    end
    return itemName
end

function C.rowLabel(def)
    if type(def) ~= "table" then return tostring(def) end
    local name = tostring(def.name or "?")
    local goal = C.goalLabel(def.action, def.modifier, def.amount)
    local rew = C.rewardLabel(def.rewardType, def.reward, def.rewardAmount)
    return name .. " | " .. goal .. " | " .. rew
end

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
