--[[ AF_Defs — pack load + player-authored world defs ]]
AF = AF or {}
AF.Defs = AF.Defs or {}
local D = AF.Defs

D.pack = {}           -- array of def tables (source=pack)
D.player = {}         -- array (source=player)
D.bySignature = {}    -- sig -> def (first wins)

local function dbg(msg)
    print("[AF] " .. tostring(msg))
end

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local n = {}
    for k, v in pairs(t) do n[k] = deepcopy(v) end
    return n
end

function D.normalize(raw, source, packName)
    if type(raw) ~= "table" then return nil end
    local name = tostring(raw.name or "")
    local action = tostring(raw.action or "")
    local modifier = tostring(raw.modifier or "none")
    if modifier == "" then modifier = "none" end
    local amount = tonumber(raw.amount)
    local reward = tostring(raw.reward or "")
    local rewardAmount = tonumber(raw.rewardAmount) or 1
    local rewardType = tostring(raw.rewardType or "item")
    if name == "" or action == "" or not amount or amount < 1 or reward == "" then
        return nil
    end
    if not AF.Catalog or not AF.Catalog.mapToTrack(action, modifier) then
        dbg("skip unmapped " .. name .. " " .. action .. "/" .. modifier)
        return nil
    end
    local sig = AF.Catalog.signature(action, modifier, amount)
    return {
        name = name,
        action = action,
        modifier = modifier,
        amount = amount,
        reward = reward,
        rewardAmount = rewardAmount,
        rewardType = rewardType,
        source = source or "pack",
        packName = packName,
        signature = sig,
        goalLabel = AF.Catalog.goalLabel(action, modifier, amount),
    }
end

function D.clearIndex()
    D.bySignature = {}
    D.pack = {}
    D.player = {}
end

function D.register(def, list)
    if not def or not def.signature then return false end
    if D.bySignature[def.signature] then
        dbg("dedupe skip " .. def.signature)
        return false
    end
    D.bySignature[def.signature] = def
    list[#list + 1] = def
    return true
end

local function parseJsonArray(text)
    if not text or text == "" then return nil end
    -- Prefer engine JSON if present
    if type(JSON) == "table" and type(JSON.parse) == "function" then
        local ok, data = pcall(JSON.parse, text)
        if ok and type(data) == "table" then return data end
    end
    -- Minimal fallback: load as Lua table by transforming JSON - fragile; try loadstring with json-to-lua
    -- Use simple pattern for our packs only via load with cjson-like - skip
    local fn, err = loadstring and loadstring("return " .. text:gsub("%[", "{"):gsub("%]", "}"):gsub("(\"[^\"]+\"%s*):", "[%1]="):gsub("null", "nil"))
    -- Too fragile. Prefer getJson or similar.
    return nil
end

--- Read file from a mod folder (default AchievementFramework)
function D.readModText(relPath, modId)
    modId = modId or "AchievementFramework"
    local text
    local paths = {
        relPath,
        relPath:gsub("^media/", ""),
        "media/" .. relPath:gsub("^media/", ""),
    }
    for _, p in ipairs(paths) do
        pcall(function()
            if text then return end
            if getModFileReader then
                local r = getModFileReader(modId, p, true)
                if r then
                    local chunks = {}
                    local line = r:readLine()
                    while line ~= nil do
                        chunks[#chunks + 1] = line
                        line = r:readLine()
                    end
                    r:close()
                    if #chunks > 0 then
                        text = table.concat(chunks, "\n")
                        dbg("readModText ok mod=" .. tostring(modId) .. " path=" .. p .. " lines=" .. tostring(#chunks))
                    end
                end
            end
        end)
        if text and text ~= "" then break end
    end
    return text
end

-- Built-in fallback if no pack files load
D.EMBEDDED_SAMPLE = {
    { name = "Prepper", action = "daysSurvived", modifier = "none", amount = 1, rewardType = "item", reward = "Base.HandAxe", rewardAmount = 1 },
}

function D.loadJsonArrayText(text, source, packName)
    if not text then
        dbg("loadJson empty text " .. tostring(packName))
        return 0
    end
    -- strip BOM / leading junk
    text = tostring(text):gsub("^\239\187\191", ""):gsub("^%s+", "")
    local data, err
    local ok, res = pcall(function()
        return D._jsonDecode(text)
    end)
    if ok then
        data = res
    else
        err = res
    end
    if type(data) ~= "table" then
        dbg("json decode fail " .. tostring(packName) .. " err=" .. tostring(err) .. " head=" .. tostring(text):sub(1, 40))
        return 0
    end
    local n = 0
    local list = source == "player" and D.player or D.pack
    local arr = data
    if data[1] == nil and data.name then arr = { data } end
    local count = #arr
    if count == 0 and type(data) == "table" then
        -- pairs-style array?
        for k, v in pairs(data) do
            if type(k) == "number" and type(v) == "table" then
                local def = D.normalize(v, source, packName)
                if def and D.register(def, list) then n = n + 1 end
            end
        end
        dbg("pack " .. tostring(packName) .. " pairs-load +" .. tostring(n))
        return n
    end
    for i = 1, count do
        local def = D.normalize(arr[i], source, packName)
        if def and D.register(def, list) then
            n = n + 1
        elseif arr[i] then
            dbg("normalize fail i=" .. tostring(i) .. " name=" .. tostring(arr[i].name))
        end
    end
    return n
end

-- Minimal JSON decode (arrays/objects/strings/numbers/bool/null)
function D._jsonDecode(str)
    if type(str) ~= "string" then return nil end
    str = str:gsub("^\239\187\191", "")
    local pos = 1
    local len = #str
    local function peek()
        if pos > len then return "" end
        return str:sub(pos, pos)
    end
    local function consume(n)
        pos = pos + (n or 1)
    end
    local function skip()
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end
    local parseValue
    local function parseString()
        consume() -- "
        local t = {}
        while pos <= len do
            local c = peek()
            if c == "\"" then
                consume()
                break
            end
            if c == "\\" then
                consume()
                local e = peek()
                consume()
                if e == "n" then t[#t + 1] = "\n"
                elseif e == "t" then t[#t + 1] = "\t"
                elseif e == "r" then t[#t + 1] = "\r"
                elseif e == "\"" then t[#t + 1] = "\""
                elseif e == "\\" then t[#t + 1] = "\\"
                elseif e == "/" then t[#t + 1] = "/"
                else t[#t + 1] = e end
            else
                t[#t + 1] = c
                consume()
            end
        end
        return table.concat(t)
    end
    local function parseNumber()
        local s = pos
        local c = peek()
        if c == "-" then consume(); c = peek() end
        while c >= "0" and c <= "9" do
            consume()
            c = peek()
        end
        if c == "." then
            consume()
            c = peek()
            while c >= "0" and c <= "9" do
                consume()
                c = peek()
            end
        end
        local num = tonumber(str:sub(s, pos - 1))
        if not num then error("bad number at " .. tostring(s)) end
        return num
    end
    local function parseArray()
        consume() -- [
        skip()
        local a = {}
        if peek() == "]" then
            consume()
            return a
        end
        while true do
            a[#a + 1] = parseValue()
            skip()
            local c = peek()
            if c == "]" then
                consume()
                break
            end
            if c == "," then
                consume()
                skip()
            else
                error("array at " .. tostring(pos) .. " got " .. tostring(c))
            end
        end
        return a
    end
    local function parseObject()
        consume() -- {
        skip()
        local o = {}
        if peek() == "}" then
            consume()
            return o
        end
        while true do
            skip()
            if peek() ~= "\"" then error("obj key at " .. tostring(pos)) end
            local k = parseString()
            skip()
            if peek() ~= ":" then error("colon at " .. tostring(pos)) end
            consume()
            skip()
            o[k] = parseValue()
            skip()
            local c = peek()
            if c == "}" then
                consume()
                break
            end
            if c == "," then
                consume()
                skip()
            else
                error("obj at " .. tostring(pos))
            end
        end
        return o
    end
    parseValue = function()
        skip()
        local c = peek()
        if c == "\"" then return parseString() end
        if c == "{" then return parseObject() end
        if c == "[" then return parseArray() end
        if str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end
        if str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        if str:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        if c == "-" or (c >= "0" and c <= "9") then return parseNumber() end
        error("value at " .. tostring(pos) .. " c=" .. tostring(c))
    end
    return parseValue()
end

function D.reloadPacks()
    D.pack = {}
    local keptPlayer = D.player
    D.bySignature = {}
    D.player = {}

    -- Conventional pack file names (any activated mod may ship these)
    local packFiles = {
        "media/data/achievements/pack.json",
        "media/data/achievements.json",
        "media/data/achievements/sample.json",
        "data/achievements/pack.json",
        "data/achievements.json",
        "data/achievements/sample.json",
    }

    local mods = { "AchievementFramework" }
    pcall(function()
        if getActivatedMods then
            local list = getActivatedMods()
            if list then
                if list.size then
                    for i = 0, list:size() - 1 do
                        local id = tostring(list:get(i) or "")
                        if id ~= "" and id ~= "AchievementFramework" then
                            mods[#mods + 1] = id
                        end
                    end
                end
            end
        end
    end)

    local loadedKey = {}
    for _, modId in ipairs(mods) do
        for _, f in ipairs(packFiles) do
            local key = modId .. "::" .. f
            if not loadedKey[key] then
                loadedKey[key] = true
                local text = D.readModText(f, modId)
                if text and text ~= "" then
                    local n = D.loadJsonArrayText(text, "pack", modId .. "/" .. f)
                    dbg("pack " .. modId .. " " .. f .. " +" .. tostring(n))
                end
            end
        end
    end

    for i = 1, #keptPlayer do
        local def = keptPlayer[i]
        if def then D.register(def, D.player) end
    end

    if #D.pack == 0 then
        dbg("no pack files loaded — using embedded fallback")
        for i = 1, #D.EMBEDDED_SAMPLE do
            local def = D.normalize(D.EMBEDDED_SAMPLE[i], "pack", "embedded_sample")
            if def and D.register(def, D.pack) then end
        end
    end
    dbg("defs pack=" .. tostring(#D.pack) .. " player=" .. tostring(#D.player))
end

function D.getPackList() return D.pack end
function D.getPlayerList() return D.player end

function D.addPlayer(raw, serverAuth)
    -- MP client/listen UI: server owns player defs
    if not serverAuth and AF.Net and AF.Net.shouldSendClientCommand and AF.Net.shouldSendClientCommand() then
        local st, msg = AF.Net.requestDefsAdd(raw)
        if st == "pending" then
            return { name = tostring(raw and raw.name or ""), signature = "pending", _pending = true }, nil
        end
        if st == true then
            -- SP path fell through somehow
        elseif st == false then
            return nil, msg
        end
    end
    local def = D.normalize(raw, "player", "player")
    if not def then return nil, "invalid_or_unmapped" end
    if D.bySignature[def.signature] then return nil, "duplicate_signature" end
    D.register(def, D.player)
    D.savePlayer()
    return def
end

function D.removePlayer(signature, serverAuth)
    if not serverAuth and AF.Net and AF.Net.shouldSendClientCommand and AF.Net.shouldSendClientCommand() then
        local st, msg = AF.Net.requestDefsRemove(signature)
        if st == "pending" then
            return
        end
    end
    local out = {}
    for i = 1, #D.player do
        if D.player[i].signature ~= signature then out[#out+1] = D.player[i] end
    end
    D.player = out
    -- rebuild index
    D.bySignature = {}
    for i = 1, #D.pack do D.bySignature[D.pack[i].signature] = D.pack[i] end
    for i = 1, #D.player do D.bySignature[D.player[i].signature] = D.player[i] end
    D.savePlayer()
end

function D.savePlayer()
    pcall(function()
        local md = ModData.getOrCreate("AF_World")
        md.playerAchievements = D.player
        if ModData.transmit then ModData.transmit("AF_World") end
    end)
    -- File backup so main-menu / pre-world authoring survives
    pcall(function()
        if not getFileWriter then return end
        local lines = { "[" }
        for i = 1, #D.player do
            local d = D.player[i]
            local comma = (i < #D.player) and "," or ""
            lines[#lines + 1] = string.format(
                '  {"name":%s,"action":%s,"modifier":%s,"amount":%s,"rewardType":%s,"reward":%s,"rewardAmount":%s}%s',
                D._jsonStr(d.name), D._jsonStr(d.action), D._jsonStr(d.modifier or "none"),
                tostring(d.amount), D._jsonStr(d.rewardType or "item"), D._jsonStr(d.reward),
                tostring(d.rewardAmount or 1), comma)
        end
        lines[#lines + 1] = "]"
        local w = getFileWriter("AF_player_defs.json", true, false)
        if w then
            w:write(table.concat(lines, "\n"))
            w:close()
        end
    end)
end

function D._jsonStr(s)
    s = tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. s .. '"'
end

function D.loadPlayer()
    -- file first (works at main menu)
    pcall(function()
        if not getFileReader then return end
        local r = getFileReader("AF_player_defs.json", true)
        if not r then return end
        local chunks = {}
        local line = r:readLine()
        while line do
            chunks[#chunks + 1] = line
            line = r:readLine()
        end
        r:close()
        local text = table.concat(chunks, "\n")
        if text and text ~= "" then
            D.loadJsonArrayText(text, "player", "AF_player_defs.json")
        end
    end)
    pcall(function()
        local md = ModData.getOrCreate("AF_World")
        if type(md.playerAchievements) == "table" then
            for i = 1, #md.playerAchievements do
                local def = D.normalize(md.playerAchievements[i], "player", "player")
                if def then D.register(def, D.player) end
            end
        end
    end)
end

print("[AF] AF_Defs loaded")
