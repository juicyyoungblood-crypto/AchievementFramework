--[[ AF_TrackStore — shared read/ensure + POD export/import for MP TrackSync
  Client AF_Main bumps counters; server Claim/TrackSync imports POD.
]]
AF = AF or {}
AF.Track = AF.Track or {}
AF.MODDATA_KEY = AF.MODDATA_KEY or "AF_Track"
AF.BARE_HANDS = AF.BARE_HANDS or "BareHands"

local Track = AF.Track

local function ensure(d, n)
    if type(d[n]) ~= "table" then d[n] = { total = 0 } end
    if d[n].total == nil then d[n].total = 0 end
end

local function copyPOD(v, depth)
    depth = (depth or 0) + 1
    if depth > 12 then return nil end
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then
        return v
    end
    if t ~= "table" then
        return nil
    end
    local out = {}
    for k, val in pairs(v) do
        local tk = type(k)
        if tk == "string" or tk == "number" then
            local cv = copyPOD(val, depth)
            if cv ~= nil then
                out[k] = cv
            end
        end
    end
    return out
end

--- Read or create AF_Track on the player. Safe on client and server.
function Track.getData(player)
    if not player then return nil end
    local md
    if not pcall(function() md = player:getModData() end) or type(md) ~= "table" then
        return nil
    end
    local key = AF.MODDATA_KEY or "AF_Track"
    if type(md[key]) ~= "table" then
        md[key] = {
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
    local d = md[key]
    for _, n in ipairs({ "killed", "damage", "made", "repaired", "eaten", "read", "fished", "distance" }) do
        ensure(d, n)
    end
    if type(d.killed.type) ~= "table" then d.killed.type = {} end
    if type(d.damage.type) ~= "table" then d.damage.type = {} end
    if type(d.distance) ~= "table" then d.distance = {} end
    for _, k in ipairs({
        "total", "combat", "walking", "running", "sprinting", "sneaking",
        "sneak_walking", "sneak_running", "sneak_sprinting", "sneak_combat",
        "vehicle", "day", "night",
    }) do
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

--- POD snapshot for commands (nested number/string/bool/tables only).
function Track.exportPOD(player)
    local d = Track.getData(player)
    if not d then return nil end
    -- refresh engine days before export
    pcall(function()
        if player and player.getHoursSurvived then
            local h = tonumber(player:getHoursSurvived()) or 0
            d.daysSurvived = math.floor(h / 24)
        end
    end)
    return copyPOD(d)
end

local function mergeMaxNumeric(dst, src, depth)
    depth = (depth or 0) + 1
    if depth > 12 or type(src) ~= "table" then return end
    if type(dst) ~= "table" then return end
    for k, sv in pairs(src) do
        local dv = dst[k]
        if type(sv) == "number" then
            local dn = tonumber(dv) or 0
            -- Prefer higher progress (client played more); never shrink totals
            if sv > dn then
                dst[k] = sv
            elseif dv == nil then
                dst[k] = sv
            end
        elseif type(sv) == "boolean" or type(sv) == "string" then
            dst[k] = sv
        elseif type(sv) == "table" then
            if type(dv) ~= "table" then
                dst[k] = copyPOD(sv) or {}
            else
                mergeMaxNumeric(dv, sv, depth)
            end
        end
    end
end

--- Import POD into player track. mode="replace" or "merge_max" (default merge_max).
function Track.importPOD(player, pod, mode)
    if not player or type(pod) ~= "table" then return false end
    local d = Track.getData(player)
    if not d then return false end
    mode = tostring(mode or "merge_max")
    local clean = copyPOD(pod)
    if not clean then return false end
    if mode == "replace" then
        -- keep table identity on moddata
        for k in pairs(d) do
            d[k] = nil
        end
        for k, v in pairs(clean) do
            d[k] = v
        end
        -- re-ensure structure
        Track.getData(player)
    else
        mergeMaxNumeric(d, clean)
    end
    return true
end

print("[AF] AF_TrackStore loaded")
