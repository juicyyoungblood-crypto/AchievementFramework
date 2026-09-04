--[[ AF_Main — tracking + hooks
  0.13.0: quiet logging by default; prune kill tables; throttled check dumps.
]]
print("[AF] ===== AF_Main LOADED =====")

AF = AF or {}
pcall(function() require "AF/AF_Core" end)
pcall(function() require "AF/AF_TrackStore" end)
AF.VERSION = AF.VERSION or "0.15.9"
AF.MODDATA_KEY = AF.MODDATA_KEY or "AF_Track"
AF.BARE_HANDS = AF.BARE_HANDS or "BareHands"
AF.Track = AF.Track or {}
local Track = AF.Track

local S = {
    wrote = false,
    lastWrite = 0,
    pending = false,
    tick = 0,
    lastBeatTick = 0,
    lastAction = {},
    lastActionTyp = {},
    beforeInv = {},
    finished = {},
    seenType = {},
    queueHooked = false,
    wrapCount = 0,
    lastPlayer = nil,
    zedHit = {}, -- zombie -> { weapon, t }
    killedOnce = {}, -- zombie -> tick
    hitArgsOnce = false,
    installed = false,
    lastCheckWrite = 0,
    distX = nil,
    distY = nil,
    distInit = false,
}

local function dbg(msg)
    -- verbose tracking noise
    if AF and AF.dbg then
        AF.dbg(3, msg)
    end
end

local function dbgInfo(msg)
    if AF and AF.dbg then
        AF.dbg(2, msg)
    else
        print("[AF] " .. tostring(msg))
    end
end

local function openW(name, append)
    if not getFileWriter then return nil end
    local w
    pcall(function() w = getFileWriter(name, true, append and true or false) end)
    return w
end

local function nowMs()
    local n = 0
    pcall(function()
        if getTimestampMs then n = tonumber(getTimestampMs()) or 0 end
    end)
    return n
end

local function lower(s) return string.lower(tostring(s or "")) end

dbgInfo("boot " .. tostring(AF.VERSION))

-- ---------------- store ----------------
local function ensure(d, n)
    if type(d[n]) ~= "table" then d[n] = { total = 0 } end
    if d[n].total == nil then d[n].total = 0 end
end

-- Track.getData lives in shared AF_TrackStore (server Claim + client bumps).
if type(Track.getData) ~= "function" then
    function Track.getData(player)
        if not player then return nil end
        local md
        if not pcall(function() md = player:getModData() end) or type(md) ~= "table" then return nil end
        if type(md[AF.MODDATA_KEY]) ~= "table" then
            md[AF.MODDATA_KEY] = {
                killed = { total = 0, type = {} },
                damage = { total = 0, type = {} },
                made = { total = 0 },
                repaired = { total = 0 },
                eaten = { total = 0 },
                fished = { total = 0 },
                read = { total = 0, magazinecomic = 0, recipe = 0, book = 0, skillbook = 0 },
                distance = {
                    total = 0, combat = 0, walking = 0, running = 0, sprinting = 0,
                    sneaking = 0, sneak_walking = 0, sneak_running = 0, sneak_sprinting = 0, sneak_combat = 0,
                    vehicle = 0, day = 0, night = 0,
                },
                daysSurvived = 0,
            }
        end
        local d = md[AF.MODDATA_KEY]
        for _, n in ipairs({ "killed", "damage", "made", "repaired", "eaten", "read", "fished", "distance" }) do ensure(d, n) end
        if type(d.killed.type) ~= "table" then d.killed.type = {} end
        if type(d.damage.type) ~= "table" then d.damage.type = {} end
        if type(d.distance) ~= "table" then d.distance = {} end
        for _, k in ipairs({ "total", "combat", "walking", "running", "sprinting", "sneaking", "sneak_walking", "sneak_running", "sneak_sprinting", "sneak_combat", "vehicle", "day", "night" }) do
            if d.distance[k] == nil then d.distance[k] = 0 end
        end
        if not d.distance._nonVehicleTotalFixed then
            local veh = tonumber(d.distance.vehicle) or 0
            local tot = tonumber(d.distance.total) or 0
            if veh > 0 and tot >= veh then
                d.distance.total = tot - veh
            end
            d.distance._nonVehicleTotalFixed = true
        end
        return d
    end
end

local function norm(ft)
    if not ft or ft == "" then return { AF.BARE_HANDS } end
    if tostring(ft) == AF.BARE_HANDS then return { AF.BARE_HANDS } end
    local parts = {}
    for p in string.gmatch(string.lower(tostring(ft)), "[^%.]+") do parts[#parts + 1] = p end
    return #parts > 0 and parts or { AF.BARE_HANDS }
end

local function bump(layer, parts, amount)
    amount = amount or 1
    layer.total = (layer.total or 0) + amount
    local node = layer
    for i = 1, #parts do
        local k = parts[i]
        if i == #parts then
            if type(node[k]) == "table" then
                node[k .. "_n"] = (node[k .. "_n"] or 0) + amount
            else
                node[k] = (node[k] or 0) + amount
            end
        else
            if type(node[k]) ~= "table" then
                local prev = node[k]
                node[k] = {}
                if type(prev) == "number" then node[k]._n = prev end
            end
            node = node[k]
        end
    end
end

local function wparts(weapon)
    if not weapon then return norm(AF.BARE_HANDS) end
    local ok, f = pcall(function() return weapon:getFullType() end)
    return (ok and f and f ~= "") and norm(f) or norm(AF.BARE_HANDS)
end

local function wtypes(weapon, opts)
    opts = opts or {}
    -- Forced barehands (e.g. stomp kill) — ignore held weapon for type buckets
    if opts.forceBarehands then
        return { "barehands" }
    end
    if not weapon then return { "barehands" } end

    local ranged = false
    pcall(function() local ok, r = pcall(function() return weapon:isRanged() end); if ok and r then ranged = true end end)
    if ranged then return { "firearm" } end

    local has = {}
    local function mark(s)
        if s == nil then return end
        local t = string.lower(tostring(s))
        t = t:gsub("%s+", "")
        t = t:gsub("^base:", ""):gsub("^tag:", "")
        t = t:match("([^%.]+)$") or t
        if t == "" then return end
        has[t] = true
        if t == "longblade" or t == "long_blade" then has["longblade"] = true end
        if t == "smallblade" or t == "shortblade" then has["smallblade"] = true end
        if t == "smallblunt" or t == "shortblunt" then has["smallblunt"] = true end
        if t == "unarmed" or t == "barehands" or t == "barehand" then has["barehands"] = true end
    end

    pcall(function()
        if weapon.getCategories then
            local list = weapon:getCategories()
            if list then
                if list.size then
                    for i = 0, list:size() - 1 do
                        local c = list:get(i)
                        mark(c)
                        pcall(function() if c and c.getName then mark(c:getName()) end end)
                        pcall(function() if c and c.toString then mark(c:toString()) end end)
                    end
                elseif type(list) == "table" then
                    for _, s in pairs(list) do mark(s) end
                end
            end
        end
    end)
    pcall(function()
        if weapon.getScriptItem then
            local si = weapon:getScriptItem()
            if si and si.getCategories then
                local list = si:getCategories()
                if list and list.size then
                    for i = 0, list:size() - 1 do mark(list:get(i)) end
                end
            end
        end
    end)
    pcall(function()
        if weapon.getType then mark(weapon:getType()) end
    end)
    pcall(function()
        if weapon.getFullType then
            local ft = string.lower(tostring(weapon:getFullType() or ""))
            if ft:find("barehands", 1, true) or ft:find("unarmed", 1, true) then mark("barehands") end
            if ft:find("axe", 1, true) then mark("axe") end
            if ft:find("spear", 1, true) then mark("spear") end
            if ft:find("katana", 1, true) or ft:find("machete", 1, true) or ft:find("sword", 1, true) then
                mark("longblade")
            end
            if ft:find("knife", 1, true) then mark("smallblade") end
            if ft:find("bat", 1, true) or ft:find("club", 1, true) or ft:find("crowbar", 1, true) then
                mark("blunt")
            end
        end
    end)

    local keys, seen = {}, {}
    local function push(k) if k and not seen[k] then seen[k] = true; keys[#keys + 1] = k end end

    if has["barehands"] or has["unarmed"] then
        push("barehands")
        return keys
    end
    if has["axe"] then push("axe") end
    if has["spear"] then push("spear") end
    if has["longblunt"] then push("longblunt"); push("blunt") end
    if has["smallblunt"] or has["shortblunt"] then push("shortblunt"); push("blunt") end
    if has["blunt"] and not has["longblunt"] and not has["smallblunt"] and not has["shortblunt"] then
        push("shortblunt"); push("blunt")
    end
    if has["longblade"] then push("longblade"); push("bladed") end
    if has["smallblade"] or has["shortblade"] or has["knife"] then push("shortblade"); push("bladed") end
    if has["firearm"] or has["handgun"] then push("firearm") end
    if #keys == 0 then push("other") end
    return keys
end

local function bumpT(layer, weapon, amount, opts)
    if type(layer.type) ~= "table" then layer.type = {} end
    for _, k in ipairs(wtypes(weapon, opts)) do
        layer.type[k] = (layer.type[k] or 0) + (amount or 1)
    end
end

local function flat(prefix, node, out)
    if type(node) ~= "table" then out[#out + 1] = { prefix, node }; return end
    if node.total ~= nil and type(node.total) ~= "table" then
        out[#out + 1] = { prefix .. ".total", node.total }
    end
    local ks = {}
    for k, _ in pairs(node) do if k ~= "total" then ks[#ks + 1] = k end end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do
        local c = node[k]
        local path = prefix .. "." .. tostring(k)
        if type(c) == "table" then flat(path, c, out) else out[#out + 1] = { path, c } end
    end
end

function Track.refreshDays(player)
    local d = Track.getData(player)
    if not d then return end
    local h = 0
    pcall(function() h = tonumber(player:getHoursSurvived()) or 0 end)
    d.daysSurvived = math.floor(h / 24)
end

function Track.writeCheckLog(player, reason, force)
    if not player then return false end
    -- Throttle disk dumps unless forced (OnSave) or debug logging on
    local debugOn = false
    pcall(function()
        if AF and AF.debugLevel and AF.debugLevel() >= 2 then debugOn = true end
    end)
    local t = nowMs()
    reason = tostring(reason or "")
    local isSave = reason == "OnSave"
    if not force and not isSave and not debugOn then
        -- quiet play: at most one dump per 10 minutes unless save
        if t > 0 and (t - (S.lastCheckWrite or 0)) < 600000 then
            return false
        end
    elseif not force and not isSave and debugOn then
        -- debug: at most every 60s for spammy reasons
        if reason ~= "OnSave" and t > 0 and (t - (S.lastCheckWrite or 0)) < 60000 then
            return false
        end
    end
    Track.refreshDays(player)
    local d = Track.getData(player)
    local lines = {
        "# AF_check.log",
        "# version " .. tostring(AF.VERSION),
        "# reason " .. reason,
        "daysSurvived=" .. tostring(d and d.daysSurvived or 0),
    }
    local rows = {}
    if d then
        for _, L in ipairs({ "killed", "damage", "made", "eaten", "read", "fished", "distance" }) do
            if d[L] then flat(L, d[L], rows) end
        end
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    for _, r in ipairs(rows) do
        local v = r[2]
        if type(v) == "number" and v ~= math.floor(v) then
            lines[#lines + 1] = string.format("%s=%.4f", r[1], v)
        else
            lines[#lines + 1] = r[1] .. "=" .. tostring(v)
        end
    end
    local body = table.concat(lines, "\n") .. "\n"
    for _, name in ipairs({ "AF_check.log", "check.log" }) do
        local w = openW(name, false)
        if w then pcall(function() w:write(body); w:close() end) end
    end
    dbgInfo(string.format("WROTE check %s e=%s f=%s m=%s k=%s dmg=%s day=%s",
        reason,
        tostring(d and d.eaten.total or 0),
        tostring(d and d.fished.total or 0),
        tostring(d and d.made.total or 0),
        tostring(d and d.killed.total or 0),
        tostring(d and d.damage.total or 0),
        tostring(d and d.daysSurvived or 0)))
    S.wrote = true
    S.lastWrite = t
    S.lastCheckWrite = t
    return true
end

local function after(player, reason, forceWrite)
    if not player then return end
    -- forceWrite used to mean immediate check dump; now only marks pending unless save/debug
    if forceWrite then
        S.pending = true
    else
        S.pending = true
    end
    local t = nowMs()
    if t > 0 and (t - S.lastWrite) < 5000 then
        return
    end
    -- only write if debug or long gap (writeCheckLog applies its own throttle)
    Track.writeCheckLog(player, reason, false)
end


--- Day/night using climate dawn/dusk when available; else 22:00–06:00.
local function isNightNow()
    local night = nil
    pcall(function()
        local gt = getGameTime and getGameTime() or (GameTime and GameTime.getInstance and GameTime.getInstance())
        if not gt or not gt.getTimeOfDay then return end
        local tod = gt:getTimeOfDay()
        local dawn, dusk = nil, nil
        pcall(function()
            if getClimateManager then
                local s = getClimateManager():getSeason()
                if s and s.getDawn and s.getDusk then
                    dawn = s:getDawn()
                    dusk = s:getDusk()
                end
            end
        end)
        if dawn ~= nil and dusk ~= nil then
            night = (tod < dawn) or (tod > dusk)
        else
            night = (tod >= 22) or (tod < 6)
        end
    end)
    if night == nil then return false end
    return night and true or false
end

local function bumpDayNight(layer, amount)
    if type(layer) ~= "table" then return end
    amount = amount or 1
    local key = isNightNow() and "night" or "day"
    layer[key] = (tonumber(layer[key]) or 0) + amount
end

function Track.addDamage(p, w, a)
    local d = Track.getData(p)
    if not d then return end
    a = tonumber(a) or 0
    if a < 0 then a = 0 end
    if a == 0 then a = 1 end -- hit event without numeric dmg still counts contact
    bump(d.damage, wparts(w), a)
    bumpT(d.damage, w, a)
    bumpDayNight(d.damage, a)
    after(p, "damage", false)
end

function Track.addKill(p, w, opts)
    local d = Track.getData(p)
    if not d then return end
    opts = opts or {}
    if opts.forceBarehands then
        bump(d.killed, norm(AF.BARE_HANDS), 1)
    else
        bump(d.killed, wparts(w), 1)
    end
    bumpT(d.killed, w, 1, opts)
    bumpDayNight(d.killed, 1)
    after(p, "kill", true)
end

function Track.addMade(p, k, skills)
    local d = Track.getData(p)
    if not d then return end
    if k and k ~= "" then
        bump(d.made, norm(k), 1)
    else
        d.made.total = (d.made.total or 0) + 1
    end
    -- skills: list of normalized skill ids (knapping, carpentry, …)
    if type(skills) == "table" then
        if type(d.made.skill) ~= "table" then d.made.skill = {} end
        for i = 1, #skills do
            local sk = skills[i]
            if sk and sk ~= "" then
                bump(d.made, { "skill", sk }, 1)
            end
        end
    end
    after(p, "made", true)
end


function Track.addRepaired(p, k, kind)
    local d = Track.getData(p)
    if not d then return end
    if type(d.repaired) ~= "table" then d.repaired = { total = 0 } end
    -- NEVER touches made.total / craft counters
    if k and k ~= "" then
        bump(d.repaired, norm(k), 1)
    else
        d.repaired.total = (d.repaired.total or 0) + 1
    end
    kind = kind and tostring(kind) or nil
    if kind and kind ~= "" then
        if type(d.repaired.kind) ~= "table" then d.repaired.kind = {} end
        d.repaired.kind[kind] = (d.repaired.kind[kind] or 0) + 1
    end
    after(p, "repaired", true)
end

function Track.addEaten(p, k)
    local d = Track.getData(p)
    if not d then return end
    bump(d.eaten, norm(k), 1)
    after(p, "eaten", true)
end

function Track.addFished(p, k)
    local d = Track.getData(p)
    if not d then return end
    bump(d.fished, norm(k), 1)
    after(p, "fished", true)
end

function Track.addRead(p, bucket)
    local d = Track.getData(p)
    if not d then return end
    local b = bucket or "book"
    d.read.total = (d.read.total or 0) + 1
    d.read[b] = (d.read[b] or 0) + 1
    after(p, "read", true)
end


function Track.addDistance(p, dist, buckets)
    local d = Track.getData(p)
    if not d or not dist or dist <= 0 then return end
    if type(d.distance) ~= "table" then d.distance = { total = 0 } end
    -- total = all non-vehicle only (vehicle is much easier; keep separate)
    local isVeh = false
    if type(buckets) == "table" then
        for i = 1, #buckets do
            if buckets[i] == "vehicle" then isVeh = true; break end
        end
    end
    if not isVeh then
        d.distance.total = (d.distance.total or 0) + dist
    end
    if type(buckets) == "table" then
        for i = 1, #buckets do
            local k = buckets[i]
            if k and k ~= "total" then
                d.distance[k] = (d.distance[k] or 0) + dist
            end
        end
    end
    after(p, "distance", false)
end

local function pickPlayer(preferred)
    if preferred then
        local ok = false
        pcall(function()
            if instanceof and instanceof(preferred, "IsoPlayer") then ok = true end
        end)
        if ok then return preferred end
    end
    if S.lastPlayer then return S.lastPlayer end
    local p
    pcall(function() p = getSpecificPlayer(0) end)
    if p then return p end
    pcall(function() p = getPlayer() end)
    return p
end

local function pn(player)
    local n = 0
    pcall(function() if player.getPlayerNum then n = player:getPlayerNum() or 0 end end)
    return n
end

local function isLocalPlayer(obj)
    if not obj then return false end
    local ok = false
    pcall(function()
        if instanceof and instanceof(obj, "IsoPlayer") then
            if obj.isLocalPlayer then
                ok = obj:isLocalPlayer() and true or false
            else
                ok = true
            end
        end
    end)
    return ok
end

local function snapInv(player)
    local set = {}
    pcall(function()
        local list = player:getInventory():getItems()
        for i = 0, list:size() - 1 do
            set[list:get(i)] = true
        end
    end)
    return set
end

local function actionType(action)
    if not action then return "?" end
    local t
    pcall(function() t = action.Type end)
    if t and tostring(t) ~= "" then return tostring(t) end
    pcall(function() t = action.type end)
    if t and tostring(t) ~= "" then return tostring(t) end
    return "?"
end

local function noteType(typ)
    local t = tostring(typ or "?")
    if not S.seenType[t] then
        S.seenType[t] = true
        dbg("ACTIONTYPE " .. t)
    end
end

local function classifyLiterature(item)
    -- Buckets: skillbook | recipe | magazinecomic | book
    -- B42 literature uses DisplayCategory + LearnedRecipes (not B41 TeachedRecipes alone).
    if not item then return "book", "" end
    local bucket = "book"
    local detail = ""
    pcall(function()
        local cat = ""
        pcall(function()
            if item.getDisplayCategory then cat = tostring(item:getDisplayCategory() or "") end
        end)
        local typ, full = "", ""
        pcall(function() if item.getType then typ = tostring(item:getType() or "") end end)
        pcall(function() if item.getFullType then full = tostring(item:getFullType() or "") end end)
        local low = lower(typ .. " " .. full .. " " .. cat)
        detail = full ~= "" and full or typ

        -- 1) Skill books
        local skillKey = nil
        pcall(function() if item.getSkillTrained then skillKey = item:getSkillTrained() end end)
        if cat == "SkillBook" or (SkillBook and skillKey and SkillBook[skillKey]) then
            bucket = "skillbook"
            detail = tostring(skillKey or cat)
            return
        end
        if skillKey ~= nil and skillKey ~= "" and skillKey ~= false then
            local s = tostring(skillKey)
            if s ~= "" and s ~= "nil" and s ~= "none" and s ~= "None" and s ~= "0" then
                bucket = "skillbook"
                detail = s
                return
            end
        end

        -- 2) Recipe magazines (B42: DisplayCategory=RecipeResource, LearnedRecipes=...)
        if cat == "RecipeResource" then
            bucket = "recipe"
            return
        end
        local hasRecipes = false
        pcall(function()
            local recipes = nil
            if item.getTeachedRecipes then recipes = item:getTeachedRecipes() end
            if not recipes and item.getLearnedRecipes then recipes = item:getLearnedRecipes() end
            if not recipes and item.getRecipes then recipes = item:getRecipes() end
            if recipes then
                if recipes.isEmpty then hasRecipes = not recipes:isEmpty()
                elseif recipes.size then hasRecipes = recipes:size() > 0
                elseif recipes.getSize then hasRecipes = recipes:getSize() > 0
                elseif type(recipes) == "string" and recipes ~= "" then hasRecipes = true
                end
            end
            -- script ModData / extra fields sometimes expose as string list via getExtraInfo
            if not hasRecipes and item.getModData then
                local md = item:getModData()
                if type(md) == "table" and (md.LearnedRecipes or md.learnedRecipes) then
                    hasRecipes = true
                end
            end
        end)
        if hasRecipes then
            bucket = "recipe"
            return
        end
        -- name patterns: MechanicMag1, KeyMag1, HuntingMag4, EngineerMagazine1, *Mag#
        if low:find("engineermagazine", 1, true) or low:find("recipe", 1, true)
            or low:match("mag%d") or low:match("magazine%d")
            or low:find("schematic", 1, true) then
            -- avoid treating boredom Magazine_Horror as recipe via Mag — only Mag+digit or Mag1 style
            if low:match("mag%d") or low:find("engineermagazine", 1, true)
                or low:find("schematic", 1, true) or cat == "RecipeResource" then
                bucket = "recipe"
                return
            end
        end

        -- 3) Comics
        if cat == "Comic" or typ == "ComicBook" or typ == "ComicBook_Retail" or low:find("comic", 1, true) then
            bucket = "magazinecomic"
            return
        end

        -- 4) Magazines / newspapers (DisplayCategory Literature + magazine tag/type)
        local isArmorMag = low:find("greave", 1, true) or low:find("vambrace", 1, true)
            or low:find("thighmagazine", 1, true) or low:find("cuirass_magazine", 1, true)
        if not isArmorMag then
            local taggedMag = false
            pcall(function()
                -- Kahlua: never use obj:method and obj:method() (parse error near `and`)
                local ok1, has1 = pcall(function() return item:hasTag("base:magazine") end)
                if ok1 and has1 then taggedMag = true end
                local ok2, has2 = pcall(function() return item:hasTag("Magazine") end)
                if ok2 and has2 then taggedMag = true end
                local tags = nil
                local ok3, tgs = pcall(function() return item:getTags() end)
                if ok3 then tags = tgs end
                if tags then
                    local okc, c1 = pcall(function() return tags:contains("base:magazine") end)
                    if okc and c1 then taggedMag = true end
                    local okc2, c2 = pcall(function() return tags:contains("magazine") end)
                    if okc2 and c2 then taggedMag = true end
                end
            end)
            if taggedMag or typ == "Magazine" or typ == "Newspaper" or typ == "TVMagazine"
                or cat == "Literature" and (low:find("magazine", 1, true) or low:find("newspaper", 1, true))
                or low:find("magazine_", 1, true) or low:find("newspaper", 1, true)
                or low:find("tvmagazine", 1, true) then
                bucket = "magazinecomic"
                return
            end
        end

        if cat == "Literature" and not low:find("book", 1, true) then
            -- subject magazines often Literature without Magazine_ prefix in type... still tags
            -- leave as book if nothing else
        end
        if typ == "Book" or cat == "Literature" or low:find("book", 1, true) then
            bucket = "book"
        end
    end)
    return bucket, detail
end

--- Snapshot helpers for meaningful-read gate (B42 CharacterStat / pages / recipes)
local function moodSnap(player)
    local boredom, unhappiness, stress = nil, nil, nil
    pcall(function()
        local st = player:getStats()
        if st and st.get and CharacterStat then
            if CharacterStat.BOREDOM then boredom = st:get(CharacterStat.BOREDOM) end
            if CharacterStat.UNHAPPINESS then unhappiness = st:get(CharacterStat.UNHAPPINESS) end
            if CharacterStat.STRESS then stress = st:get(CharacterStat.STRESS) end
        end
    end)
    pcall(function()
        local bd = player:getBodyDamage()
        if bd then
            if boredom == nil and bd.getBoredomLevel then boredom = bd:getBoredomLevel() end
            if unhappiness == nil and bd.getUnhappynessLevel then unhappiness = bd:getUnhappynessLevel() end
            if unhappiness == nil and bd.getUnhappinessLevel then unhappiness = bd:getUnhappinessLevel() end
        end
    end)
    pcall(function()
        if stress == nil then
            local st = player:getStats()
            if st and st.getStress then stress = st:getStress() end
        end
    end)
    return boredom, unhappiness, stress
end

local function knownRecipeCount(player)
    local n = 0
    pcall(function()
        if player.getKnownRecipes then
            local k = player:getKnownRecipes()
            if k and k.size then n = k:size() end
        end
    end)
    return n or 0
end

local function alreadyReadBookHas(player, fullType)
    local has = false
    pcall(function()
        if player.getAlreadyReadBook then
            local list = player:getAlreadyReadBook()
            if list and list.contains then has = list:contains(fullType) end
        end
    end)
    return has
end

local function charReadPages(player, fullType)
    local n = 0
    pcall(function()
        if player.getAlreadyReadPages then
            n = player:getAlreadyReadPages(fullType) or 0
        end
    end)
    return tonumber(n) or 0
end

local function itemReadPages(item)
    local n = 0
    pcall(function()
        if item.getAlreadyReadPages then n = item:getAlreadyReadPages() or 0 end
    end)
    return tonumber(n) or 0
end

local function getItemRecipeList(item)
    local recipes = nil
    pcall(function()
        if item.getLearnedRecipes then recipes = item:getLearnedRecipes() end
        if (not recipes or (function() local ok,e=pcall(function() return recipes:isEmpty() end); return ok and e end)()) and item.getTeachedRecipes then
            recipes = item:getTeachedRecipes()
        end
    end)
    return recipes
end

local function itemIsRecipeMag(item)
    local yes = false
    pcall(function()
        if item.getDisplayCategory and tostring(item:getDisplayCategory() or "") == "RecipeResource" then
            yes = true
            return
        end
        local r = getItemRecipeList(item)
        if r then local ok, empty = pcall(function() return r:isEmpty() end); if ok and not empty then yes = true end end
        if r then local ok, n = pcall(function() return r:size() end); if ok and type(n)=="number" and n > 0 then yes = true end end
    end)
    return yes
end

--- Snippet-style: magazine teaches at least one recipe the player does not know yet.
local function willLearnNewRecipe(player, item)
    local will = false
    pcall(function()
        local teached = getItemRecipeList(item)
        if not teached then return end
        local empty = true
        local okEmpty, isEmpty = pcall(function() return teached:isEmpty() end)
        if okEmpty then
            empty = isEmpty and true or false
        elseif teached.size then
            empty = teached:size() == 0
        end
        if empty then return end

        local known = nil
        if player.getKnownRecipes then known = player:getKnownRecipes() end

        local n = 0
        pcall(function() if teached.size then n = teached:size() end end)
        for i = 0, math.max(n - 1, 0) do
            local recipeString = nil
            pcall(function() recipeString = teached:get(i) end)
            if recipeString ~= nil then
                local has = false
                pcall(function()
                    if known and known.contains then
                        has = known:contains(recipeString)
                        -- some lists store Recipe objects; try tostring name
                        if not has and type(recipeString) ~= "string" then
                            local name = tostring(recipeString)
                            has = known:contains(name)
                            if not has and recipeString.getName then
                                has = known:contains(recipeString:getName())
                            end
                        end
                    end
                end)
                if not has then
                    will = true
                    break
                end
            end
        end
    end)
    return will
end

--- True if this finished read did something (recipe / mood / skill pages).
local function readWasMeaningful(action, player, item)
    if not action or not player or not item then return false, "no_ctx" end

    local full = ""
    pcall(function() full = item:getFullType() end)
    local isRecipe = itemIsRecipeMag(item)

    -- RECIPE MAGS: only first-time learning (snippet ach_WillLearnRecipe).
    -- Do NOT use mood — B42 still calls ReadLiterature on recipe mags and mood
    -- improves on every reread (that was the spam path).
    if isRecipe then
        if action._AF_willLearnRecipe == true then
            -- confirm something actually landed if we can
            local startRecipes = action._AF_startRecipeCount
            if startRecipes ~= nil then
                local now = knownRecipeCount(player)
                if now > startRecipes then
                    return true, "new_recipe_count"
                end
            end
            if full ~= "" and action._AF_hadReadBook == false and alreadyReadBookHas(player, full) then
                return true, "alreadyReadBook_add"
            end
            -- start said they would learn; still count once even if APIs are fuzzy
            if action._AF_willLearnRecipe then
                return true, "will_learn_recipe"
            end
        end
        -- reread / already knew all recipes
        if action._AF_hadReadBook == true then
            return false, "recipe_already_read_book"
        end
        if action._AF_willLearnRecipe == false then
            return false, "recipe_already_known"
        end
        return false, "recipe_no_effect"
    end

    -- 1) Non-recipe: already-read book list (rare path)
    if full ~= "" and action._AF_hadReadBook == false and alreadyReadBookHas(player, full) then
        return true, "alreadyReadBook_add"
    end

    -- 2) Mood improvement (boredom / unhappiness / stress down) — comics / boredom mags
    if action._AF_startBoredom ~= nil or action._AF_startUnhappiness ~= nil or action._AF_startStress ~= nil then
        local b, u, s = moodSnap(player)
        local eps = 0.01
        if action._AF_startBoredom ~= nil and b ~= nil and b < action._AF_startBoredom - eps then
            return true, "boredom_down"
        end
        if action._AF_startUnhappiness ~= nil and u ~= nil and u < action._AF_startUnhappiness - eps then
            return true, "unhappiness_down"
        end
        if action._AF_startStress ~= nil and s ~= nil and s < action._AF_startStress - eps then
            return true, "stress_down"
        end
    end

    -- 3) Skill book pages
    if action._AF_startCharPages ~= nil and full ~= "" then
        local nowP = charReadPages(player, full)
        if nowP > action._AF_startCharPages then
            return true, "skill_pages_char"
        end
    end
    if action._AF_startItemPages ~= nil then
        local nowI = itemReadPages(item)
        local maxP = 0
        pcall(function() if item.getNumberOfPages then maxP = item:getNumberOfPages() or 0 end end)
        if nowI > action._AF_startItemPages then
            return true, "skill_pages_item"
        end
        if maxP > 0 and action._AF_startItemPages < maxP and nowI >= maxP then
            return true, "skill_pages_finish"
        end
    end

    -- 4) First-time literature title (comics/subject mags with literatureTitle)
    if action.isLiteratureRead == false then
        local title = nil
        pcall(function()
            if (function() local ok,h=pcall(function() return item:hasModData() end); if not (ok and h) then return false end; local ok2,md=pcall(function() return item:getModData() end); return ok2 and md and md.literatureTitle end)() then
                title = item:getModData().literatureTitle
            end
        end)
        if title then
            return true, "new_literature_title"
        end
    end

    return false, "no_effect"
end

local function captureReadStart(action)
    if not action then return end
    local player = pickPlayer(action.character)
    local item = action.item
    if not player or not item then return end
    local b, u, s = moodSnap(player)
    action._AF_startBoredom = b
    action._AF_startUnhappiness = u
    action._AF_startStress = s
    action._AF_startRecipeCount = knownRecipeCount(player)
    local full = ""
    pcall(function() full = item:getFullType() end)
    action._AF_hadReadBook = alreadyReadBookHas(player, full)
    action._AF_startCharPages = charReadPages(player, full)
    action._AF_startItemPages = itemReadPages(item)
    -- Snippet: will this recipe mag teach something new?
    action._AF_willLearnRecipe = false
    if itemIsRecipeMag(item) then
        if action._AF_hadReadBook then
            action._AF_willLearnRecipe = false
        else
            action._AF_willLearnRecipe = willLearnNewRecipe(player, item)
            -- if recipe list API fails but book never read, allow one shot
            if action._AF_willLearnRecipe == false then
                local r = getItemRecipeList(item)
                local hasList = false
                pcall(function()
                    if r then local ok, empty = pcall(function() return r:isEmpty() end); if ok and not empty then hasList = true end end
                end)
                if not hasList and not action._AF_hadReadBook then
                    -- DisplayCategory RecipeResource but empty API — first open only
                    action._AF_willLearnRecipe = not action._AF_hadReadBook
                end
            end
        end
    end
    action._AF_readSnap = true
    dbg("READ start snap recipes=" .. tostring(action._AF_startRecipeCount)
        .. " pagesChar=" .. tostring(action._AF_startCharPages)
        .. " pagesItem=" .. tostring(action._AF_startItemPages)
        .. " hadBook=" .. tostring(action._AF_hadReadBook)
        .. " willLearnRecipe=" .. tostring(action._AF_willLearnRecipe))
end



-- ---- craft / build skill tagging ----
local CRAFT_SKILL_ALIAS = {
    flintknapping = "knapping",
    knapping = "knapping",
    metalwelding = "metalworking",
    metalwork = "metalworking",
    metalworking = "metalworking",
    stonemasonry = "stonemasonry",
    stoneworking = "stonemasonry",
    blacksmithing = "blacksmithing",
    husbandry = "animal",
    animal = "animal",
    butchering = "butchering",
    butcher = "butchering",
    woodwork = "carpentry",
    carpentry = "carpentry",
    welding = "welding",
    maintenance = "maintenance",
    glassmaking = "glassmaking",
    carving = "carving",
    cooking = "cooking",
    tailoring = "tailoring",
    electrical = "electrical",
    farming = "farming",
    fishing = "fishing",
    pottery = "pottery",
    masonry = "masonry",
    medical = "medical",
    assembly = "assembly",
    packing = "packing",
    repair = "repair",
    survival = "survival",
    survivalist = "survival",
    outdoors = "outdoors",
    trapping = "trapping",
    weaponry = "weaponry",
    demo = "demo",
    miscellaneous = "miscellaneous",
}

local function normalizeCraftSkill(raw)
    if raw == nil then return nil end
    local s = nil
    -- CraftRecipeCategory / tags / perks may be objects
    pcall(function()
        if type(raw) == "string" then s = raw; return end
        if raw.getName then s = raw:getName(); return end
        if raw.toString then s = raw:toString(); return end
    end)
    if not s or s == "" then s = tostring(raw) end
    s = lower(tostring(s))
    -- strip java junk / enum noise
    s = s:gsub("^base:", "")
    s = s:match("([%w_]+)%s*$") or s
    s = s:gsub("%s+", ""):gsub("_", ""):gsub("%-", "")
    s = s:gsub("%d+$", "")
    if s == "" or s == "nil" or s == "userdata" then return nil end
    if CRAFT_SKILL_ALIAS[s] then return CRAFT_SKILL_ALIAS[s] end
    if #s >= 3 and #s <= 40 then return s end
    return nil
end

local function addSkillUnique(list, seen, raw)
    local sk = normalizeCraftSkill(raw)
    if not sk or seen[sk] then return end
    seen[sk] = true
    list[#list + 1] = sk
end

local function skillsFromCraftRecipe(cr, out, seen)
    if not cr then return end
    out = out or {}
    seen = seen or {}
    pcall(function()
        if cr.getCategory then addSkillUnique(out, seen, cr:getCategory()) end
    end)
    -- Do NOT call getHighestRelevantSkill() bare — needs player args (Break on Error).
    pcall(function()
        if cr.getXPAwardCount and cr.getXPAward then
            local n = cr:getXPAwardCount() or 0
            for i = 0, n - 1 do
                local aw = cr:getXPAward(i)
                if aw then
                    local nm = nil
                    pcall(function()
                        if aw.getPerk then
                            local perk = aw:getPerk()
                            if perk and perk.getName then nm = perk:getName() end
                        end
                    end)
                    addSkillUnique(out, seen, nm)
                end
            end
        end
    end)
    pcall(function()
        if cr.getTags then
            local tags = cr:getTags()
            if tags and tags.size then
                for i = 0, tags:size() - 1 do
                    addSkillUnique(out, seen, tags:get(i))
                end
            end
        end
    end)
    pcall(function()
        if cr.getRequiredSkillCount and cr.getRequiredSkill then
            local n = cr:getRequiredSkillCount() or 0
            for i = 0, n - 1 do
                local rs = cr:getRequiredSkill(i)
                local nm = nil
                pcall(function()
                    if rs and rs.getPerk then
                        local perk = rs:getPerk()
                        if perk and perk.getName then nm = perk:getName() end
                    end
                end)
                addSkillUnique(out, seen, nm)
            end
        end
    end)
    return out
end

local function extractMadeSkills(action, typ)
    local skills, seen = {}, {}
    if not action then return skills end
    pcall(function()
        if action.craftRecipe then skillsFromCraftRecipe(action.craftRecipe, skills, seen) end
    end)
    pcall(function()
        if action.recipe and action.recipe.getCategory then
            addSkillUnique(skills, seen, action.recipe:getCategory())
        end
    end)
    pcall(function()
        if action.item and action.item.getRecipe then
            local r = action.item:getRecipe()
            if r and r.getCraftRecipe then
                skillsFromCraftRecipe(r:getCraftRecipe(), skills, seen)
            end
        end
    end)
    pcall(function()
        if action.objectInfo and action.objectInfo.getRecipe then
            local r = action.objectInfo:getRecipe()
            if r and r.getCraftRecipe then
                skillsFromCraftRecipe(r:getCraftRecipe(), skills, seen)
            end
        end
    end)
    local lt = lower(typ or "")
    if lt:find("butcher", 1, true) then addSkillUnique(skills, seen, "butchering") end
    if lt:find("knap", 1, true) then addSkillUnique(skills, seen, "knapping") end
    return skills
end

--- True if this finish is a repair/fix (must NOT count as general craft/made).
local function isRepairActionType(typ)
    local lt = lower(typ or "")
    if lt:find("isfix", 1, true) then return true end
    if lt:find("fixaction", 1, true) then return true end
    if lt:find("fixvehicle", 1, true) then return true end
    if lt:find("isrepair", 1, true) then return true end
    if lt:find("repairengine", 1, true) then return true end
    if lt:find("repairlight", 1, true) then return true end
    return false
end

local function isRepairCraftId(id, skills)
    local s = lower(tostring(id or ""))
    if s:find("fix", 1, true) or s:find("repair", 1, true) then return true end
    if s:find("fixwith", 1, true) then return true end
    if type(skills) == "table" then
        for i = 1, #skills do
            local sk = lower(tostring(skills[i] or ""))
            if sk == "repair" then return true end
        end
    end
    return false
end

local function repairKeyFromAction(action, typ)
    local id
    pcall(function()
        if action.item and action.item.getFullType then
            id = action.item:getFullType()
        end
    end)
    pcall(function()
        if not id and action.part and action.part.getId then
            id = "vehicle." .. tostring(action.part:getId())
        end
    end)
    pcall(function()
        if not id and action.origSpriteName then
            id = "moveable." .. tostring(action.origSpriteName)
        end
    end)
    if not id then
        id = "action." .. tostring(typ or "repair")
    end
    return id
end

local function repairKindFromAction(action, typ)
    local lt = lower(typ or "")
    if lt:find("vehicle", 1, true) or lt:find("engine", 1, true) or lt:find("lightbar", 1, true) then
        return "vehicle"
    end
    if lt:find("moveable", 1, true) then
        return "furniture"
    end
    return "item"
end

local function handleFinished(player, action, beforeInv, src)
    if not player or not action then return end
    local key = tostring(action)
    if S.finished[key] then return end
    S.finished[key] = true

    local typ = actionType(action)
    noteType(typ)
    local lt = lower(typ)
    dbg("FINISH " .. tostring(src) .. " typ=" .. typ)

    if lt:find("eat", 1, true) or lt:find("food", 1, true) or lt:find("drink", 1, true) then
        local id
        pcall(function()
            if action.item and action.item.getFullType then id = action.item:getFullType() end
        end)
        if id then
            dbg("EAT " .. id)
            Track.addEaten(player, id)
        else
            dbg("EAT no-item")
        end
        return
    end

    if lt:find("fish", 1, true) or lt:find("pickupfish", 1, true) then
        local id
        pcall(function()
            if action.item and action.item.getFullType then id = action.item:getFullType() end
        end)
        if not id and beforeInv then
            pcall(function()
                local list = player:getInventory():getItems()
                for i = 0, list:size() - 1 do
                    local item = list:get(i)
                    if not beforeInv[item] then
                        local ft = ""
                        pcall(function() ft = lower(item:getFullType()) end)
                        if not (ft:find("lure", 1, true) or ft:find("line", 1, true) or ft:find("tackle", 1, true)) then
                            id = item:getFullType()
                            break
                        end
                    end
                end
            end)
        end
        if id then
            dbg("FISH " .. id)
            Track.addFished(player, id)
        else
            dbg("FISH no-item")
        end
        return
    end


    -- Furniture moveable repair (mode == repair)
    if lt:find("moveable", 1, true) then
        local mode = nil
        pcall(function() mode = action.mode end)
        if mode and lower(tostring(mode)):find("repair", 1, true) then
            local id = repairKeyFromAction(action, typ)
            dbg("REPAIR furniture " .. tostring(id))
            Track.addRepaired(player, id, "furniture")
            return
        end
    end

    if isRepairActionType(typ) or (lt:find("repair", 1, true) and not lt:find("craft", 1, true)) then
        local id = repairKeyFromAction(action, typ)
        local kind = repairKindFromAction(action, typ)
        dbg("REPAIR " .. tostring(kind) .. " " .. tostring(id))
        Track.addRepaired(player, id, kind)
        return
    end

    if lt:find("butcher", 1, true) then
        local skills = extractMadeSkills(action, typ)
        if #skills == 0 then skills = { "butchering" } end
        local id = "butcher." .. tostring(typ)
        dbg("BUTCHER " .. id .. " skills=" .. table.concat(skills, ","))
        Track.addMade(player, id, skills)
        return
    end

    if lt:find("craft", 1, true) or lt:find("handcraft", 1, true) or lt:find("recipe", 1, true) then
        local id
        pcall(function()
            if action.recipe and action.recipe.getResult then
                local r = action.recipe:getResult()
                if r and r.getFullType then id = r:getFullType() end
            end
        end)
        pcall(function()
            if not id and action.craftRecipe and action.craftRecipe.getName then
                id = "recipe." .. tostring(action.craftRecipe:getName())
            end
        end)
        pcall(function()
            if not id and action.craftRecipe and action.craftRecipe.getTranslationName then
                id = "recipe." .. tostring(action.craftRecipe:getTranslationName())
            end
        end)
        pcall(function()
            if not id and action.item and action.item.getFullType then id = action.item:getFullType() end
        end)
        id = id or ("craft." .. typ)
        local skills = extractMadeSkills(action, typ)
        -- Repair/fix recipes must NOT inflate made.total / general crafting
        if isRepairCraftId(id, skills) then
            -- strip only-repair skill tags for the repair counter key
            dbg("REPAIR craft-route " .. tostring(id) .. " skills=" .. table.concat(skills, ","))
            Track.addRepaired(player, id, "craft")
            return
        end
        -- Drop "repair" skill bumps on normal crafts that somehow tagged it
        if type(skills) == "table" then
            local filtered = {}
            for i = 1, #skills do
                local sk = skills[i]
                if sk and sk ~= "repair" then
                    filtered[#filtered + 1] = sk
                end
            end
            skills = filtered
        end
        dbg("CRAFT " .. tostring(id) .. " skills=" .. table.concat(skills, ","))
        Track.addMade(player, id, skills)
        return
    end

    if lt:find("build", 1, true) or lt:find("place", 1, true) then
        local bn
        pcall(function() if action.objectName then bn = action.objectName end end)
        pcall(function()
            if not bn and action.item and action.item.getName then bn = action.item:getName() end
        end)
        pcall(function()
            if not bn and action.spriteName then bn = action.spriteName end
        end)
        local id = "build." .. tostring(bn or typ):gsub("%s+", "_")
        local skills = extractMadeSkills(action, typ)
        dbg("BUILD " .. tostring(id) .. " skills=" .. table.concat(skills, ","))
        Track.addMade(player, id, skills)
        return
    end

    if lt:find("read", 1, true) or lt == "isreadabook" or lt:find("literature", 1, true) then
        local item = action.item or action.literature or action.book
        local bucket, detail = classifyLiterature(item)
        local full, cat = "", ""
        pcall(function() if item and item.getFullType then full = item:getFullType() end end)
        pcall(function() if item and item.getDisplayCategory then cat = tostring(item:getDisplayCategory() or "") end end)

        local ok, why = false, "no_start_snap"
        if action._AF_readSnap then
            ok, why = readWasMeaningful(action, player, item)
        else
            -- start wrap missed: still try end-state recipe/book flags only
            pcall(function()
                if full ~= "" and alreadyReadBookHas(player, full) then
                    -- can't know if newly added this finish without start; allow if recipes just known and recipe item
                    ok, why = true, "no_snap_allow_once"
                elseif bucket == "recipe" or bucket == "skillbook" or bucket == "magazinecomic" then
                    ok, why = true, "no_snap_allow_once"
                end
            end)
        end
        if not ok then
            dbg("READ skip (" .. tostring(why) .. ") item=" .. tostring(full) .. " cat=" .. tostring(cat))
            return
        end
        dbg("READ " .. tostring(bucket) .. " item=" .. tostring(full) .. " cat=" .. tostring(cat)
            .. " why=" .. tostring(why) .. " " .. tostring(detail))
        Track.addRead(player, bucket)
        return
    end

    if beforeInv then
        pcall(function()
            local list = player:getInventory():getItems()
            for i = 0, list:size() - 1 do
                local item = list:get(i)
                if not beforeInv[item] then
                    local id = ""
                    pcall(function() id = item:getFullType() end)
                    dbg("UNKNOWN_GAIN " .. tostring(id) .. " during " .. typ)
                end
            end
        end)
    end
end

local function markStart(player, action, src)
    if not player or not action then return end
    local id = pn(player)
    S.beforeInv[id] = snapInv(player)
    S.lastAction[id] = action
    S.lastActionTyp[id] = actionType(action)
    noteType(S.lastActionTyp[id])
    dbg("START " .. tostring(src) .. " " .. tostring(S.lastActionTyp[id]))
    -- early read baseline if ISReadABook:start wrap not hit yet
    pcall(function()
        local typ = lower(S.lastActionTyp[id] or "")
        if typ:find("read", 1, true) and not action._AF_readSnap then
            captureReadStart(action)
        end
    end)
end

-- STATIC add(action) — never treat first arg as self unless it looks like a queue
local function onQueued(action, via)
    if not action then return end
    local player
    pcall(function() player = action.character end)
    player = pickPlayer(player)
    dbg("QUEUE." .. tostring(via) .. " " .. actionType(action))
    if player then markStart(player, action, via) end
end

local function hookQueue()
    local Q = rawget(_G, "ISTimedActionQueue")
    if type(Q) ~= "table" then
        dbg("queue missing")
        return false
    end

    if not Q._AF80_add and type(Q.add) == "function" then
        local orig = Q.add
        Q.add = function(a1, a2)
            -- static: add(action)  OR mistaken method: add(self, action)
            local action = a1
            if type(a1) == "table" and a1.queue ~= nil and a2 ~= nil then
                action = a2
                onQueued(action, "add:m")
                return orig(a1, a2)
            end
            onQueued(action, "add")
            return orig(a1, a2)
        end
        Q._AF80_add = true
        dbg("hooked queue.add")
    end

    if not Q._AF80_addAfter and type(Q.addAfter) == "function" then
        local orig = Q.addAfter
        Q.addAfter = function(prev, action)
            onQueued(action, "addAfter")
            return orig(prev, action)
        end
        Q._AF80_addAfter = true
        dbg("hooked queue.addAfter")
    end

    if not Q._AF80_addToQueue and type(Q.addToQueue) == "function" then
        local orig = Q.addToQueue
        Q.addToQueue = function(self, action)
            onQueued(action, "addToQueue")
            return orig(self, action)
        end
        Q._AF80_addToQueue = true
        dbg("hooked queue.addToQueue")
    end

    if not Q._AF80_onCompleted and type(Q.onCompleted) == "function" then
        local orig = Q.onCompleted
        Q.onCompleted = function(self, action)
            local player = pickPlayer(self and self.character)
            local id = player and pn(player) or 0
            dbg("QUEUE.onCompleted " .. actionType(action))
            pcall(function()
                handleFinished(player, action, S.beforeInv[id], "onCompleted")
            end)
            local r = orig(self, action)
            S.lastAction[id] = nil
            S.lastActionTyp[id] = nil
            S.beforeInv[id] = nil
            return r
        end
        Q._AF80_onCompleted = true
        dbg("hooked queue.onCompleted")
    end

    S.queueHooked = Q._AF80_add and true or false
    return S.queueHooked
end

local function wrapMethod(tbl, className, methodName)
    if type(tbl) ~= "table" then return false end
    local flag = "_AF80_" .. methodName
    if tbl[flag] then return true end
    local orig = tbl[methodName]
    if type(orig) ~= "function" then return false end
    tbl[methodName] = function(self)
        local player = pickPlayer(self and self.character)
        local before = player and snapInv(player) or nil
        noteType(actionType(self))
        dbg("class." .. methodName .. " " .. className)
        local r = orig(self)
        pcall(function()
            handleFinished(player, self, before, "class:" .. className .. ":" .. methodName)
        end)
        return r
    end
    tbl[flag] = true
    return true
end

local function wrapReadABook()
    local tbl = rawget(_G, "ISReadABook")
    if type(tbl) ~= "table" or tbl._AF83_readGate then return end
    -- start: baseline
    if type(tbl.start) == "function" and not tbl._AF83_start then
        local origS = tbl.start
        tbl.start = function(self)
            local r = origS(self)
            pcall(function() captureReadStart(self) end)
            return r
        end
        tbl._AF83_start = true
    end
    -- still wrap perform/complete via generic, but gate is inside handleFinished
    wrapMethod(tbl, "ISReadABook", "perform")
    wrapMethod(tbl, "ISReadABook", "complete")
    tbl._AF83_readGate = true
    dbg("ISReadABook meaningful-read gate hooked")
end


local function wrapClass(name)
    local tbl = rawget(_G, name)
    if type(tbl) ~= "table" then return end
    if name == "ISReadABook" then
        wrapReadABook()
        return
    end
    local did = false
    if wrapMethod(tbl, name, "perform") then did = true end
    if wrapMethod(tbl, name, "complete") then did = true end
    if did and not tbl._AF80c then
        tbl._AF80c = true
        S.wrapCount = S.wrapCount + 1
        dbg("classwrap " .. name)
    end
end

local function scanClasses()
    local names = {
        "ISEatFoodAction", "ISDrinkFoodAction", "ISCraftAction", "ISHandcraftAction", "ISFixAction", "ISFixVehiclePartAction",
        "ISBuildAction", "ISPickupFishAction", "ISReadABook", "ISBaseTimedAction",
    }
    for i = 1, #names do wrapClass(names[i]) end
end

local function pollQueue(player)
    if not player then return end
    local id = pn(player)
    local cur = nil
    pcall(function()
        local Q = ISTimedActionQueue
        if not Q or not Q.getTimedActionQueue then return end
        local q = Q.getTimedActionQueue(player)
        if not q then return end
        cur = q.current
        if not cur and type(q.queue) == "table" then cur = q.queue[1] end
    end)
    local prev = S.lastAction[id]
    if cur and cur ~= prev then
        markStart(player, cur, "poll")
    elseif prev and not cur then
        dbg("END poll " .. tostring(S.lastActionTyp[id]))
        pcall(function()
            handleFinished(player, prev, S.beforeInv[id], "poll")
        end)
        S.lastAction[id] = nil
        S.lastActionTyp[id] = nil
        S.beforeInv[id] = nil
    end
end

local function bootPlayer(player, reason)
    player = pickPlayer(player)
    hookQueue()
    scanClasses()
    if not player then
        dbg(tostring(reason) .. " no-player")
        return
    end
    S.lastPlayer = player
    S.distInit = false
    Track.getData(player)
    Track.writeCheckLog(player, reason)
end

-- ---- combat: AU-proven + Knox-proven ----
-- Kill once per zombie; damage once per hit window (Char+Xp+OnHitZombie all fire).
local function isBareHandsWeapon(weapon)
    if not weapon then return true end
    local bare = false
    pcall(function()
        local ty = ""
        if weapon.getType then ty = tostring(weapon:getType() or "") end
        local ft = ""
        if weapon.getFullType then ft = tostring(weapon:getFullType() or "") end
        local s = string.lower(ty .. " " .. ft)
        if s:find("barehands", 1, true) or s:find("unarmed", 1, true) then bare = true end
    end)
    return bare
end

local function isZombieOnFloor(zombie)
    local floor = false
    pcall(function()
        if zombie then local ok, v = pcall(function() return zombie:isOnFloor() end); if ok and v then floor = true end end
    end)
    pcall(function()
        if not floor and zombie then local ok, v = pcall(function() return zombie:isKnockedDown() end); if ok and v then floor = true end end
    end)
    pcall(function()
        if not floor and zombie then local ok, v = pcall(function() return zombie:isCrawling() end); if ok and v then floor = true end end
    end)
    return floor
end

--- Stomp / ground finish with bare hands → barehands kill (PZ has no standing punch kills).
local function killOptsFor(player, zombie, weapon)
    local opts = {}
    local bare = isBareHandsWeapon(weapon)
    if not bare then
        pcall(function()
            local pri = player:getPrimaryHandItem()
            if weapon == nil and pri == nil then bare = true end
            if weapon == nil and pri ~= nil then
                weapon = pri
                bare = isBareHandsWeapon(pri)
            end
        end)
    end
    -- Any bare-hands kill (including stomps on downed zeds) counts as barehands
    if bare then
        opts.forceBarehands = true
    end
    return opts, weapon
end

local function markKill(player, zombie, weapon, src)
    if not player or not zombie then return false end
    if type(S.killedOnce) ~= "table" then S.killedOnce = {} end
    local prev = S.killedOnce[zombie]
    if prev then return false end
    S.killedOnce[zombie] = S.tick or 1
    local opts
    opts, weapon = killOptsFor(player, zombie, weapon)
    local tag = ""
    if opts.forceBarehands then
        tag = isZombieOnFloor(zombie) and " stomp/barehands" or " barehands"
    end
    dbg("KILL " .. tostring(src) .. tag)
    Track.addKill(player, weapon, opts)
    return true
end


local function markDamage(player, zombie, weapon, amount, src)
    if not player then return end
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    local t = nowMs()
    local key = tostring(zombie) .. "|" .. tostring(weapon)
    -- same swing often fires OnHitZombie (+1) + Char + Xp within one frame
    if S.dmgKey == key and t > 0 and (t - (S.dmgMs or 0)) < 80 then
        -- keep the larger amount if a later event has real dmg
        if amount > 0 and amount > (S.dmgLast or 0) and S.dmgLast <= 1 then
            local d = Track.getData(player)
            if d then
                local bumpAmt = amount - (S.dmgLast or 0)
                if bumpAmt > 0 then
                    bump(d.damage, wparts(weapon), bumpAmt)
                    bumpT(d.damage, weapon, bumpAmt)
                    bumpDayNight(d.damage, bumpAmt)
                    after(player, "damage", false)
                end
            end
            S.dmgLast = amount
        end
        return
    end
    S.dmgKey, S.dmgMs, S.dmgLast = key, t, amount
    if amount == 0 then amount = 1 end
    dbg("DMG " .. tostring(src) .. " a=" .. tostring(amount))
    Track.addDamage(player, weapon, amount)
end

local function onHitZombie(zombie, attacker, bodyPart, weapon)
    pcall(function()
        if not zombie then return end
        local player = pickPlayer(nil)
        if not player then return end
        if attacker and attacker ~= player then
            if not isLocalPlayer(attacker) then return end
        end
        local w = weapon
        if not w then
            pcall(function() w = player:getPrimaryHandItem() end)
        end
        local prev = S.zedHit[zombie]
        S.zedHit[zombie] = { weapon = w, t = S.tick, killed = prev and prev.killed }
        dbg("HITZED")
        -- attribution only; numeric dmg comes from Char/Xp when available
        markDamage(player, zombie, w, 1, "HitZombie")
    end)
end

local function onZombieDead(zombie)
    pcall(function()
        if not zombie then return end
        local player = pickPlayer(nil)
        if not player then return end
        local tr = S.zedHit[zombie]
        -- Only count if we previously attributed a hit to the local player (AU pattern)
        if not tr then return end
        local w = tr.weapon
        if not w then
            pcall(function() w = player:getPrimaryHandItem() end)
        end
        markKill(player, zombie, w, "ZedDead")
        S.zedHit[zombie] = nil
    end)
end

local function onWeaponHitXp(owner, weapon, hitObject, damage)
    pcall(function()
        if not S.hitArgsOnce then
            S.hitArgsOnce = true
            dbg("HITARGS Xp " .. type(owner) .. " " .. type(weapon) .. " " .. type(hitObject) .. " " .. tostring(damage))
        end
        if not isLocalPlayer(owner) then return end
        local isZ = false
        pcall(function()
            if hitObject and instanceof and instanceof(hitObject, "IsoZombie") then isZ = true end
        end)
        if not isZ then return end
        dbg("HIT Xp dmg=" .. tostring(damage))
        markDamage(owner, hitObject, weapon, damage, "Xp")
        local prev = S.zedHit[hitObject]
        S.zedHit[hitObject] = { weapon = weapon, t = S.tick, killed = prev and prev.killed }
        local dead = false
        pcall(function() local ok, v = pcall(function() return hitObject:isDead() end); if ok and v then dead = true end end)
        pcall(function() if not dead then local ok, h = pcall(function() return hitObject:getHealth() end); if ok and type(h)=="number" and h <= 0 then dead = true end end end)
        if dead then
            markKill(owner, hitObject, weapon, "Xp")
        end
    end)
end

local function onWeaponHitCharacter(attacker, target, weapon, damage)
    pcall(function()
        if not isLocalPlayer(attacker) then return end
        local isZ = false
        pcall(function()
            if target and instanceof and instanceof(target, "IsoZombie") then isZ = true end
        end)
        if not isZ then return end
        dbg("HIT Char dmg=" .. tostring(damage))
        markDamage(attacker, target, weapon, damage, "Char")
        local prev = S.zedHit[target]
        S.zedHit[target] = { weapon = weapon, t = S.tick, killed = prev and prev.killed }
    end)
end


-- ---- distance traveled (tiles) ----
-- Sample every 15 OnTicks. Clamp single samples to 1.5x theoretical max car travel
-- (fastest known vehicle maxSpeed + regulator headroom + Speed Demon).
S.distX, S.distY, S.distInit = nil, nil, false
S.maxVehicleKmh = 120 -- vanilla sports/racecar maxSpeed; raised if we see higher getMaxSpeed()
S.speedDemonMult = 1.25 -- conservative boost when CharacterTrait.SPEED_DEMON
S.vehicleRegulatorHeadroom = 20 -- ISVehicleRegulator allows maxSpeed+20

local function playerHasSpeedDemon(player)
    local yes = false
    -- B42 hasTrait expects CharacterTrait enum, NOT a string (string = critical type error).
    pcall(function()
        if not player or not player.hasTrait then return end
        if CharacterTrait and CharacterTrait.SPEED_DEMON then
            if player:hasTrait(CharacterTrait.SPEED_DEMON) then yes = true end
        end
    end)
    return yes
end

--- Max tiles one sample may count (1.5x theoretical car ceiling for this interval).
local function maxDistanceSample(player, elapsedSec)
    if not elapsedSec or elapsedSec <= 0 then elapsedSec = 0.25 end
    -- cap elapsed so a long pause after tab-out doesn't raise the ceiling forever
    if elapsedSec > 2.0 then elapsedSec = 2.0 end
    local maxKmh = S.maxVehicleKmh or 120
    pcall(function()
        local v = nil; if player then local ok, vv = pcall(function() return player:getVehicle() end); if ok then v = vv end end
        if v and v.getMaxSpeed then
            local ms = v:getMaxSpeed()
            if type(ms) == "number" and ms > maxKmh then
                maxKmh = ms
                S.maxVehicleKmh = ms
            end
        end
    end)
    local head = S.vehicleRegulatorHeadroom or 20
    local demon = 1.0
    if player and playerHasSpeedDemon(player) then
        demon = S.speedDemonMult or 1.25
    end
    local effectiveKmh = (maxKmh + head) * demon
    local tilesPerSec = effectiveKmh / 3.6
    local mult = 1
    pcall(function()
        local gt = getGameTime and getGameTime() or (GameTime and GameTime.getInstance and GameTime.getInstance())
        if gt and gt.getMultiplier then mult = gt:getMultiplier() or 1 end
    end)
    if type(mult) ~= "number" or mult < 0.1 then mult = 1 end
    local maxDist = tilesPerSec * elapsedSec * mult * 1.5
    if maxDist < 3 then maxDist = 3 end
    if maxDist > 120 then maxDist = 120 end
    return maxDist
end

local function sampleDistance(player)
    if not player then return end
    local x, y = nil, nil
    pcall(function() x = player:getX(); y = player:getY() end)
    if x == nil or y == nil then return end
    local tnow = nowMs()
    if not S.distInit then
        S.distX, S.distY, S.distInit = x, y, true
        S.distLastMs = tnow
        return
    end
    local dx = x - (S.distX or x)
    local dy = y - (S.distY or y)
    S.distX, S.distY = x, y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.01 then
        S.distLastMs = tnow
        return
    end

    local elapsed = 0.25
    if tnow and S.distLastMs and tnow > 0 and S.distLastMs > 0 and tnow > S.distLastMs then
        elapsed = (tnow - S.distLastMs) / 1000.0
    end
    S.distLastMs = tnow

    local maxDist = maxDistanceSample(player, elapsed)
    if dist > maxDist then
        return
    end

    local buckets = {}
    buckets[#buckets + 1] = isNightNow() and "night" or "day"

    local inVeh = false
    pcall(function()
        do local ok, v = pcall(function() return player:isSeatedInVehicle() end); if ok and v then inVeh = true end end
        if not inVeh then local ok, v = pcall(function() return player:getVehicle() end); if ok and v then inVeh = true end end
        if not inVeh then local ok, v = pcall(function() return player:isDriving() end); if ok and v then inVeh = true end end
    end)

    if inVeh then
        buckets[#buckets + 1] = "vehicle"
    else
        local aiming, sprint, running, sneaking = false, false, false, false
        pcall(function() local ok, v = pcall(function() return player:isAiming() end); if ok and v then aiming = true end end)
        pcall(function() local ok, v = pcall(function() return player:isSprinting() end); if ok and v then sprint = true end end)
        pcall(function()
            do local ok, v = pcall(function() return player:isRunning() end); if ok and v then running = true end end
            do local ok, v = pcall(function() return player:IsRunning() end); if ok and v then running = true end end
        end)
        pcall(function() local ok, v = pcall(function() return player:isSneaking() end); if ok and v then sneaking = true end end)

        if aiming then
            if sneaking then
                buckets[#buckets + 1] = "sneak_combat"
                buckets[#buckets + 1] = "sneaking"
            else
                buckets[#buckets + 1] = "combat"
            end
        elseif sneaking then
            buckets[#buckets + 1] = "sneaking"
            if sprint then
                buckets[#buckets + 1] = "sneak_sprinting"
            elseif running then
                buckets[#buckets + 1] = "sneak_running"
            else
                buckets[#buckets + 1] = "sneak_walking"
            end
        else
            if sprint then
                buckets[#buckets + 1] = "sprinting"
            elseif running then
                buckets[#buckets + 1] = "running"
            else
                buckets[#buckets + 1] = "walking"
            end
        end
    end
    Track.addDistance(player, dist, buckets)
end



local function onTick()
    S.tick = S.tick + 1
    pcall(function()
        local player = pickPlayer(nil)
        if player then S.lastPlayer = player end

        -- heartbeat every ~300 ticks (~5s at 60fps) regardless of timestamp
                        if (S.tick - S.lastBeatTick) >= 300 then
                            S.lastBeatTick = S.tick
                            -- Drop finish-dedupe keys; dual perform/onCompleted fires within ms, not across beats.
                            S.finished = {}
                            -- Prune kill attribution tables (avoid session-long growth / GC hold)
                            pcall(function()
                                local tick = S.tick or 0
                                local keepAfter = tick - 1800 -- ~30s at 60fps
                                if type(S.killedOnce) == "table" then
                                    local fresh = {}
                                    for z, tmark in pairs(S.killedOnce) do
                                        local keep = false
                                        if type(tmark) == "number" and tmark >= keepAfter then
                                            keep = true
                                        end
                                        -- drop if zombie clearly gone/dead
                                        pcall(function()
                                            if (function() if not z then return false end; local ok,v=pcall(function() return z:isDead() end); return ok and v end)() and (type(tmark) ~= "number" or tmark < tick - 300) then
                                                keep = false
                                            end
                                        end)
                                        if keep then fresh[z] = tmark end
                                    end
                                    S.killedOnce = fresh
                                end
                                if type(S.zedHit) == "table" then
                                    local freshH = {}
                                    for z, tr in pairs(S.zedHit) do
                                        local tmark = tr and tr.t or 0
                                        if type(tmark) == "number" and tmark >= keepAfter then
                                            freshH[z] = tr
                                        end
                                    end
                                    S.zedHit = freshH
                                end
                            end)
                            if AF and AF.flushDebugLog then AF.flushDebugLog(false) end
                            hookQueue()
                            if player then
                                pollQueue(player)
                                if S.pending then
                                    S.pending = false
                                    Track.writeCheckLog(player, "flush", false)
                                end
                            end
                            dbg(string.format("BEAT tick=%s player=%s queue=%s wraps=%s k=%s e=%s",
                                tostring(S.tick),
                                tostring(player ~= nil),
                                tostring(S.queueHooked),
                                tostring(S.wrapCount),
                                tostring(player and Track.getData(player) and Track.getData(player).killed.total or 0),
                                tostring(player and Track.getData(player) and Track.getData(player).eaten.total or 0)))
                        end

        -- lighter poll every 15 ticks while playing
        if player and (S.tick % 15) == 0 then
            pollQueue(player)
            sampleDistance(player)
        end
    end)
end

local function onPlayerUpdate(player)
    pcall(function()
        if not player then return end
        if not isLocalPlayer(player) then return end
        S.lastPlayer = player
        if not S.wrote then bootPlayer(player, "OnPlayerUpdate_first") end
        pollQueue(player)
        -- backup distance sample (OnTick can miss if player nil briefly)
        S.distUpdateN = (S.distUpdateN or 0) + 1
        if (S.distUpdateN % 15) == 0 then
            sampleDistance(player)
        end
    end)
end

local function safeAdd(eventName, fn)
    local ok, err = pcall(function()
        local ev = Events[eventName]
        if ev and ev.Add then
            ev.Add(fn)
            dbg("Events." .. eventName)
            return true
        end
        dbg("NO " .. eventName)
        return false
    end)
    if not ok then dbg("ADDFAIL " .. eventName .. " " .. tostring(err)) end
end

local function install()
    if S.installed then
        hookQueue()
        scanClasses()
        return
    end
    S.installed = true
    dbg("install handlers")

    safeAdd("OnTick", onTick)
    safeAdd("OnPlayerUpdate", onPlayerUpdate)
    safeAdd("OnGameStart", function()
        dbg("OnGameStart")
        hookQueue()
        scanClasses()
        bootPlayer(nil, "OnGameStart")
    end)
    safeAdd("OnCreatePlayer", function(playerIndex, player)
        dbg("OnCreatePlayer")
        local p = player
        if type(playerIndex) ~= "number" then p = playerIndex end
        bootPlayer(p, "OnCreatePlayer")
    end)
    -- Only dump check on living player characters (not every zombie)
    safeAdd("OnCreateLivingCharacter", function(a, b)
        local p = a
        if type(a) == "number" then p = b end
        if isLocalPlayer(p) then
            dbg("OnCreateLivingCharacter player")
            bootPlayer(p, "OnCreateLivingCharacter")
        end
    end)
    safeAdd("OnSave", function()
        dbgInfo("OnSave")
        local p = pickPlayer(nil)
        if p then Track.writeCheckLog(p, "OnSave", true) end
        if AF and AF.flushDebugLog then AF.flushDebugLog(true) end
    end)
    safeAdd("EveryOneMinute", function()
        local p = pickPlayer(nil)
        if p then Track.writeCheckLog(p, "EveryOneMinute", false) end
    end)
    safeAdd("OnMainMenuEnter", function() dbg("OnMainMenuEnter") end)

    -- kills / hits
    safeAdd("OnHitZombie", onHitZombie)
    safeAdd("OnZombieDead", onZombieDead)
    safeAdd("OnWeaponHitXp", onWeaponHitXp)
    safeAdd("OnWeaponHitCharacter", onWeaponHitCharacter)

    hookQueue()
    scanClasses()
    dbg("install done queue=" .. tostring(S.queueHooked) .. " wraps=" .. tostring(S.wrapCount))
end

install()
