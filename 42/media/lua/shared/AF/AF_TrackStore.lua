--[[ AF_TrackStore — shared read/ensure for player AF_Track moddata
  Client AF_Main bumps counters; server Claim reads the same key.
  Keep structure in sync with AF_Main expectations.
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
    for _, n in ipairs({ "killed", "damage", "made", "eaten", "read", "fished", "distance" }) do
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

print("[AF] AF_TrackStore loaded")
