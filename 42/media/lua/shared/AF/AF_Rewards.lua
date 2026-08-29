--[[ AF_Rewards — dropdown catalogs for Browser ]]
AF = AF or {}
AF.Rewards = AF.Rewards or {}
local R = AF.Rewards

R._traits = nil
R._skills = nil
R._items = nil

local function dbg(msg) print("[AF] " .. tostring(msg)) end

function R.getRewardTypes()
    return {
        { id = "item", label = "Item" },
        { id = "skill_xp", label = "Skill XP" },
        { id = "trait", label = "Trait (positive)" },
    }
end

function R.defaultAmount(rewardType)
    if rewardType == "trait" then return 1 end
    if rewardType == "skill_xp" then return 150 end
    return 1
end

function R.buildTraits()
    local list = {}
    -- Reverse map CharacterTrait enum object -> field name (GRACEFUL, ATHLETIC, ...)
    local traitKeyByObj = {}
    pcall(function()
        if not CharacterTrait then return end
        for k, v in pairs(CharacterTrait) do
            if type(k) == "string" and type(v) == "userdata" then
                traitKeyByObj[v] = k
            elseif type(k) == "string" and type(v) == "table" then
                traitKeyByObj[v] = k
            end
        end
    end)

    local function stableId(def, traitObj)
        -- Prefer CharacterTrait enum constant name (works with CharacterTrait.X and hasTrait)
        if traitObj and traitKeyByObj[traitObj] then
            return traitKeyByObj[traitObj]
        end
        local id = ""
        pcall(function()
            if traitObj and traitObj.getName then id = tostring(traitObj:getName() or "") end
        end)
        if id == "" then
            pcall(function()
                if traitObj then id = tostring(traitObj) end
            end)
        end
        -- ResourceLocation style base:foo or path
        if id:find(":", 1, true) then
            id = id:match("([^:]+)$") or id
        end
        if id:find(".", 1, true) then
            id = id:match("([^%.]+)$") or id
        end
        -- Normalize to ENUM_STYLE if looks like words
        if id ~= "" and not id:find("_", 1, true) and id:match("%u") then
            -- already Camel or ENUM
        end
        return id
    end

    -- B42: TraitFactory is gone. Vanilla admin UI uses CharacterTraitDefinition.getTraits().
    pcall(function()
        if not CharacterTraitDefinition or not CharacterTraitDefinition.getTraits then return end
        local traits = CharacterTraitDefinition.getTraits()
        if not traits or not traits.size then return end
        for i = 0, traits:size() - 1 do
            local def = traits:get(i)
            if def then
                local cost = 0
                pcall(function() if def.getCost then cost = def:getCost() or 0 end end)
                -- Match vanilla "Good Trait" list: cost >= 0
                if cost >= 0 then
                    local traitObj = nil
                    pcall(function() traitObj = def:getType() end)
                    local id = stableId(def, traitObj)
                    local label = id
                    pcall(function() if def.getLabel then label = def:getLabel() or label end end)
                    local prof = false
                    pcall(function() if def.isProfessionTrait then prof = def:isProfessionTrait() end end)
                    if id ~= "" and id ~= "nil" then
                        list[#list + 1] = {
                            id = id,
                            label = tostring(label) .. " (" .. tostring(id) .. ")",
                            cost = cost,
                            profession = prof and true or false,
                        }
                    end
                end
            end
        end
    end)
    -- Legacy fallback (B41 / older)
    if #list == 0 then
        pcall(function()
            if not TraitFactory or not TraitFactory.getTraits then return end
            local traits = TraitFactory.getTraits()
            if not traits or not traits.size then return end
            for i = 0, traits:size() - 1 do
                local t = traits:get(i)
                if t then
                    local cost = 0
                    pcall(function() if t.getCost then cost = t:getCost() end end)
                    local id = ""
                    pcall(function() id = t:getType() end)
                    local label = id
                    pcall(function() if t.getLabel then label = t:getLabel() end end)
                    if id ~= "" and cost >= 0 then
                        list[#list + 1] = { id = id, label = tostring(label) .. " (" .. tostring(id) .. ")", cost = cost }
                    end
                end
            end
        end)
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    R._traits = list
    dbg("traits positive=" .. tostring(#list))
    return list
end

local function normTraitKey(s)
    s = tostring(s or ""):gsub("^base:", ""):gsub("^Base.", "")
    s = s:gsub("%s+", "_")
    return string.upper(s)
end

--- Resolve reward string to CharacterTrait userdata (B42). Never pass a bare string into
--- getCharacterTraitDefinition — it requires CharacterTrait and hard-errors otherwise.
function R.resolveTrait(reward)
    reward = tostring(reward or "")
    if reward == "" then return nil, "empty" end

    local found = nil
    local how = nil

    -- 1) Direct CharacterTrait.FIELD (GRACEFUL, ATHLETIC, ...)
    pcall(function()
        if not CharacterTrait then return end
        if CharacterTrait[reward] ~= nil then
            found = CharacterTrait[reward]
            how = "field"
            return
        end
        local upper = normTraitKey(reward)
        if CharacterTrait[upper] ~= nil then
            found = CharacterTrait[upper]
            how = "field_upper"
            return
        end
        -- CamelCase -> SNAKE
        local snake = reward:gsub("(%l)(%u)", "%1_%2")
        snake = normTraitKey(snake)
        if CharacterTrait[snake] ~= nil then
            found = CharacterTrait[snake]
            how = "field_snake"
        end
    end)
    if found ~= nil then return found, how end

    -- 2) Scan definitions; match label / type name / enum field (safe — no String overload)
    pcall(function()
        if not CharacterTraitDefinition or not CharacterTraitDefinition.getTraits then return end
        local traits = CharacterTraitDefinition.getTraits()
        if not traits or not traits.size then return end
        local want = normTraitKey(reward)
        local wantLower = string.lower(reward)
        for i = 0, traits:size() - 1 do
            local def = traits:get(i)
            if def then
                local t = nil
                pcall(function() t = def:getType() end)
                if t then
                    local candidates = {}
                    pcall(function()
                        if t.getName then candidates[#candidates + 1] = tostring(t:getName() or "") end
                    end)
                    pcall(function() candidates[#candidates + 1] = tostring(t) end)
                    pcall(function() if def.getLabel then candidates[#candidates + 1] = tostring(def:getLabel() or "") end end)
                    -- reverse field name if CharacterTrait table holds this object
                    pcall(function()
                        for k, v in pairs(CharacterTrait) do
                            if v == t and type(k) == "string" then
                                candidates[#candidates + 1] = k
                            end
                        end
                    end)
                    for _, c in ipairs(candidates) do
                        local cn = tostring(c)
                        if cn == reward or string.lower(cn) == wantLower or normTraitKey(cn) == want then
                            found = t
                            how = "scan_def"
                            return
                        end
                        -- last segment match (base:foo / pkg.Foo)
                        local seg = cn:match("([^:%.]+)$") or cn
                        if string.lower(seg) == wantLower or normTraitKey(seg) == want then
                            found = t
                            how = "scan_seg"
                            return
                        end
                    end
                end
            end
        end
    end)
    if found ~= nil then return found, how end

    -- 3) Do NOT call getCharacterTraitDefinition(string) or valueOf(bad) — throws type/enum errors
    return nil, "unresolved:" .. reward
end

function R.perkDisplayName(id)
    id = tostring(id or "")
    if id == "" then return id end
    -- Skills tab uses IGUI_perks_<PerksField>
    local keys = {
        "IGUI_perks_" .. id,
    }
    -- Common id vs translation key mismatches
    local keyAlias = {
        Lightfoot = "Lightfooted",
        Sneak = "Sneaking",
        PlantScavenging = "Foraging",
    }
    if keyAlias[id] then
        keys[#keys + 1] = "IGUI_perks_" .. keyAlias[id]
    end
    for i = 1, #keys do
        local t
        pcall(function()
            if getText then t = getText(keys[i]) end
        end)
        if t and t ~= "" and t ~= keys[i] then
            return t
        end
    end
    return id
end

function R.buildSkills()
    local list = {}
    local seen = {}
    -- Categories / non-trainable — hide from reward picker
    local skip = {
        MAX = true, None = true, Passiv = true, Passive = true,
        Combat = true, CombatMelee = true, CombatFirearms = true,
        Agility = true, Crafting = true, Firearm = true,
        Survivalist = true, FarmingCategory = true, PhysicalCategory = true,
        Accuracy = true, Guard = true,
    }
    local function add(id)
        if not id or seen[id] or skip[id] then return end
        if tonumber(id) then return end
        seen[id] = true
        local label = R.perkDisplayName(id)
        -- "Carpentry (Woodwork)" only if display differs — keeps resolve clear
        if label ~= id then
            list[#list + 1] = { id = id, label = label }
        else
            list[#list + 1] = { id = id, label = label }
        end
    end

    pcall(function()
        if not Perks then return end
        for k, v in pairs(Perks) do
            if type(k) == "string" and type(v) ~= "function" then
                add(k)
            end
        end
    end)

    if #list == 0 then
        local fixed = {
            "Fitness", "Strength", "Sprinting", "Lightfoot", "Lightfooted", "Nimble", "Sneak", "Sneaking",
            "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear",
            "Maintenance", "Aiming", "Reloading", "Farming", "Fishing", "Trapping",
            "PlantScavenging", "Cooking", "Tailoring", "Woodwork", "Electricity",
            "MetalWelding", "Mechanics", "Doctor", "Blacksmith", "Pottery", "Masonry",
            "Glassmaking", "Carving", "Butchering", "Husbandry", "Tracking", "FlintKnapping",
        }
        for _, n in ipairs(fixed) do add(n) end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    R._skills = list
    dbg("skills=" .. tostring(#list))
    return list
end

function R.buildItems()
    local list = {}
    local seen = {}
    pcall(function()
        if not getAllItems then return end
        local all = getAllItems()
        if not all or not all.size then return end
        for i = 0, all:size() - 1 do
            local si = all:get(i)
            if si then
                local full = ""
                pcall(function()
                    if si.getFullName then full = si:getFullName() end
                end)
                if full == "" then
                    pcall(function()
                        local mod = si:getModuleName() or "Base"
                        local t = si:getName() or ""
                        full = tostring(mod) .. "." .. tostring(t)
                    end)
                end
                local disp = full
                pcall(function()
                    if si.getDisplayName then disp = si:getDisplayName() end
                end)
                if full ~= "" and not seen[full] then
                    seen[full] = true
                    -- skip hidden/obsolete when possible
                    local skip = false
                    pcall(function() if si.isHidden and si:isHidden() then skip = true end end)
                    if not skip then
                        list[#list + 1] = { id = full, label = tostring(disp) .. "  [" .. full .. "]" }
                    end
                end
            end
        end
    end)
    table.sort(list, function(a, b) return a.label < b.label end)
    R._items = list
    dbg("items=" .. tostring(#list))
    return list
end

function R.getTraits()
    if R._traits then return R._traits end
    return R.buildTraits()
end

function R.getSkills()
    if R._skills then return R._skills end
    return R.buildSkills()
end

function R.getItems()
    if R._items then return R._items end
    return R.buildItems()
end

function R.getForType(rewardType)
    if rewardType == "trait" then return R.getTraits() end
    if rewardType == "skill_xp" then return R.getSkills() end
    return R.getItems()
end

function R.rebuildAll()
    R._traits = nil; R._skills = nil; R._items = nil
    R.buildTraits(); R.buildSkills(); R.buildItems()
end

--- Best-effort grant. Always returns ok,msg — caller marks Complete either way.
function R.resolveItemType(fullType)
    fullType = tostring(fullType or "")
    local aliases = {
        ["Base.WhiskeyFull"] = "Base.Whiskey",
        ["Base.WhiskeyEmpty"] = "Base.Whiskey",
        ["Base.CannedBeans"] = "Base.TinnedBeans",
        ["Base.CannedChili"] = "Base.TinnedChili",
        ["WhiskeyFull"] = "Base.Whiskey",
        ["CannedBeans"] = "Base.TinnedBeans",
    }
    if aliases[fullType] then return aliases[fullType] end
    while fullType:sub(1, 10) == "Base.Base." do
        fullType = "Base." .. fullType:sub(11)
    end
    -- plain '.' search (NOT "%.")
    if fullType ~= "" and fullType:find(".", 1, true) == nil then
        return "Base." .. fullType
    end
    return fullType
end

local PERK_ALIASES = {
    Carpentry = "Woodwork",
    Agility = "Nimble",
    Sneaking = "Sneak",
    Lightfooted = "Lightfoot",
    Foraging = "PlantScavenging",
    Electrical = "Electricity",
    Metalworking = "MetalWelding",
    FirstAid = "Doctor",
}

function R.resolvePerk(name)
    name = tostring(name or "")
    if name == "" then return nil, "empty" end
    if PERK_ALIASES[name] then name = PERK_ALIASES[name] end
    -- Snippet: Perks.Woodwork
    if Perks and Perks[name] ~= nil then
        return Perks[name], "Perks." .. name
    end
    if Perks and Perks.FromString then
        local ok, p = pcall(function() return Perks.FromString(name) end)
        if ok and p ~= nil then return p, "FromString:" .. name end
    end
    if Perks then
        local lower = string.lower(name)
        for k, v in pairs(Perks) do
            if type(k) == "string" and string.lower(k) == lower and type(v) ~= "function" then
                return v, "pairs:" .. k
            end
        end
    end
    return nil, "unknown:" .. name
end

local function readPerkXp(player, perk)
    local n = 0
    pcall(function()
        local xp = player:getXp()
        if xp and xp.getXP then n = xp:getXP(perk) or 0 end
    end)
    return tonumber(n) or 0
end

local function tryAddXP(player, perk, amount)
    local xp = player:getXp()
    if not xp then return false, "no_xp_obj" end
    amount = tonumber(amount) or 0
    if amount <= 0 then return false, "bad_amount" end

    local before = readPerkXp(player, perk)
    local tried = {}

    local function delta()
        return readPerkXp(player, perk) - before
    end

    local function attempt(label, fn)
        local okc, err = pcall(fn)
        tried[#tried + 1] = label .. (okc and "=call_ok" or ("=err:" .. tostring(err)))
        return okc
    end

    -- Achievement rewards are FLAT: "150 XP" means +150 on the bar, not after
    -- sandbox/trait/level multipliers. B42: AddXPNoMultiplier(Perk, float).
    -- Plain AddXP(perk, 150) applied ~0.25x here → 37.5 (user report).
    if xp.AddXPNoMultiplier then
        attempt("AddXPNoMultiplier", function()
            xp:AddXPNoMultiplier(perk, amount)
        end)
    end

    local gained = delta()
    -- If no-multiplier missing or short, try AddXP overloads that disable mult
    -- Signatures from IsoGameCharacter$XP:
    --   AddXP(Perk, F)
    --   AddXP(Perk, F, Z, Z)     -- often noMultiplier path
    --   AddXP(Perk, F, Z, Z, Z)
    --   AddXP(Perk, F, Z, Z, Z, Z)
    if gained < amount * 0.9 then
        -- remaining target
        local need = amount - gained
        if need > 0.01 then
            attempt("AddXP(perk,need,true) noMult-ish", function()
                -- some builds: (perk, amt, local, noMultiplier) or similar
                xp:AddXP(perk, need, false, true)
            end)
            gained = delta()
        end
    end
    if gained < amount * 0.9 then
        local need = amount - gained
        if need > 0.01 then
            attempt("AddXP(perk,need,false,false,false)", function()
                xp:AddXP(perk, need, false, false, false)
            end)
            gained = delta()
        end
    end
    if gained < amount * 0.9 and xp.AddXPNoMultiplier then
        local need = amount - gained
        if need > 0.01 then
            attempt("AddXPNoMultiplier top-up", function()
                xp:AddXPNoMultiplier(perk, need)
            end)
            gained = delta()
        end
    end
    -- Last resort: plain AddXP (WILL apply multipliers — avoid if possible)
    if gained < 0.01 then
        attempt("AddXP(perk,amt) FALLBACK_MULT", function()
            xp:AddXP(perk, amount)
        end)
        gained = delta()
    end

    if gained >= amount * 0.9 then
        return true, string.format("xp_ok +%.1f (want %.1f) via no-mult path; %s", gained, amount, table.concat(tried, ";"))
    end
    if gained > 0.01 then
        return true, string.format("xp_partial +%.1f (want %.1f) tried=%s", gained, amount, table.concat(tried, ";"))
    end
    return false, "xp_no_gain before=" .. tostring(before) .. " tried=" .. table.concat(tried, ";")
end

local function countType(inv, fullType)
    local n = 0
    pcall(function()
        if inv.getCountTypeRecurse then
            n = inv:getCountTypeRecurse(fullType) or 0
        elseif inv.getItemCount then
            n = inv:getItemCount(fullType) or 0
        end
    end)
    return tonumber(n) or 0
end

local function makeItem(fullType)
    local item = nil
    pcall(function()
        if instanceItem then item = instanceItem(fullType) end
    end)
    if not item then
        pcall(function()
            if InventoryItemFactory and InventoryItemFactory.CreateItem then
                item = InventoryItemFactory.CreateItem(fullType)
            end
        end)
    end
    return item
end

function R.deliver(player, def)
    if not player or not def then return false, "no_player_or_def" end
    local rtype = tostring(def.rewardType or "item")
    local reward = tostring(def.reward or "")
    local amount = tonumber(def.rewardAmount) or 1
    if amount < 1 then amount = 1 end
    if reward == "" then return false, "empty_reward" end

    if rtype == "trait" then
        local ok = false
        local msg = "trait"
        local traitObj, how = R.resolveTrait(reward)
        if traitObj == nil or how == nil or tostring(how):find("unresolved", 1, true) then
            print("[AF] deliver trait FAIL resolve " .. tostring(reward) .. " " .. tostring(how))
            return false, tostring(how or "resolve_fail")
        end
        -- Must be a real CharacterTrait for B42 add/hasTrait — never pass the raw string through
        if type(traitObj) == "string" then
            print("[AF] deliver trait FAIL string_not_trait " .. tostring(reward))
            return false, "string_not_trait"
        end
        pcall(function()
            if player.getCharacterTraits then
                local ct = player:getCharacterTraits()
                if not ct then msg = "no_character_traits"; return end
                if player.hasTrait and player:hasTrait(traitObj) then
                    msg = "already_has_trait"
                    ok = true
                    return
                end
                if ct.add then
                    ct:add(traitObj)
                    pcall(function()
                        if player.modifyTraitXPBoost then
                            player:modifyTraitXPBoost(traitObj, false)
                        end
                    end)
                    pcall(function() if SyncXp then SyncXp(player) end end)
                    ok = true
                    msg = "trait_added:" .. tostring(how)
                    return
                end
            end
            msg = "no_b42_traits_api"
        end)
        print("[AF] deliver trait " .. tostring(reward) .. " " .. tostring(msg))
        return ok, msg
    end

    if rtype == "skill_xp" then
        local perk, how = R.resolvePerk(reward)
        if not perk then
            print("[AF] deliver xp FAIL " .. tostring(reward) .. " " .. tostring(how))
            return false, tostring(how)
        end
        local ok, msg = tryAddXP(player, perk, amount)
        print("[AF] deliver xp " .. tostring(reward) .. " resolved=" .. tostring(how) .. " x" .. tostring(amount) .. " " .. tostring(msg))
        return ok, msg
    end

    -- item
    local ok = false
    local msg = "item"
    local fullType = R.resolveItemType(reward)
    pcall(function()
        local inv = player:getInventory()
        if not inv then msg = "no_inv"; return end
        local before = countType(inv, fullType)
        local added = 0
        for i = 1, amount do
            local item = makeItem(fullType)
            if item then
                local put = false
                pcall(function()
                    inv:AddItem(item)
                    put = true
                end)
                if put then
                    added = added + 1
                else
                    -- try ground with real item object
                    pcall(function()
                        local sq = player:getCurrentSquare()
                        if sq and sq.AddWorldInventoryItem then
                            sq:AddWorldInventoryItem(item, 0.5, 0.5, 0)
                            added = added + 1
                        end
                    end)
                end
            end
        end
        local after = countType(inv, fullType)
        local gained = after - before
        if gained > 0 then
            ok = true
            msg = "item_inv_+" .. tostring(gained) .. " type=" .. fullType
        elseif added > 0 then
            -- might be ground
            ok = true
            msg = "item_placed_" .. tostring(added) .. " type=" .. fullType
        else
            msg = "item_fail type=" .. fullType .. " (from " .. reward .. ")"
        end
    end)
    print("[AF] deliver item " .. tostring(reward) .. " -> " .. tostring(fullType) .. " x" .. tostring(amount) .. " " .. msg)
    return ok, msg
end

print("[AF] AF_Rewards loaded")
