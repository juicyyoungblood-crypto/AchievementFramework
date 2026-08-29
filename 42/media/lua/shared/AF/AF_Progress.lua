--[[ AF_Progress — per-character qualify/complete state + scan ]]
AF = AF or {}
AF.Progress = AF.Progress or {}
local P = AF.Progress

P.KEY = "AF_Progress"
P._lastScan = 0
P._noticed = {} -- signature -> true for this session halo

local function dbg(msg)
    if AF and AF.dbg then AF.dbg(2, msg) else print("[AF] " .. tostring(msg)) end
end

local function getStore(player)
    if not player then return nil end
    local md
    if not pcall(function() md = player:getModData() end) or type(md) ~= "table" then
        return nil
    end
    if type(md[P.KEY]) ~= "table" then
        md[P.KEY] = {}
    end
    return md[P.KEY]
end

function P.getEntry(player, signature)
    local st = getStore(player)
    if not st or not signature then return nil end
    local e = st[signature]
    if type(e) ~= "table" then
        e = { state = "incomplete", progress = 0 }
        st[signature] = e
    end
    if not e.state then e.state = "incomplete" end
    return e
end

function P.allDefs()
    local out = {}
    if not AF.Defs then return out end
    for _, d in ipairs(AF.Defs.getPackList() or {}) do out[#out + 1] = d end
    for _, d in ipairs(AF.Defs.getPlayerList() or {}) do out[#out + 1] = d end
    return out
end

function P.readProgress(player, def)
    if not def or not AF.Catalog then return 0 end
    return AF.Catalog.readProgress(player, def.action, def.modifier) or 0
end

function P.scanPlayer(player)
    if not player then return end
    local defs = P.allDefs()
    for i = 1, #defs do
        local def = defs[i]
        if def and def.signature then
            local e = P.getEntry(player, def.signature)
            if e.state ~= "complete" then
                local prog = P.readProgress(player, def)
                e.progress = prog
                local need = tonumber(def.amount) or 1
                if prog >= need then
                    if e.state ~= "qualified" then
                        e.state = "qualified"
                        P.notifyQualify(player, def)
                        dbg("QUALIFIED " .. def.signature .. " " .. tostring(def.name))
                    else
                        e.state = "qualified"
                    end
                else
                    e.state = "incomplete"
                end
            else
                -- still refresh progress for UI
                e.progress = P.readProgress(player, def)
            end
        end
    end
end

function P.notifyQualify(player, def)
    if not def or not def.signature then return end
    if P._noticed[def.signature] then return end
    P._noticed[def.signature] = true
    local msg = "Achieved " .. tostring(def.name) .. "! Claim it on the Achievements tab."
    pcall(function()
        if player.setHaloNote then
            player:setHaloNote(msg, 80, 200, 255, 200)
        end
    end)
    pcall(function()
        if HaloTextHelper and HaloTextHelper.addTextWithArrow then
            HaloTextHelper.addTextWithArrow(player, msg, true, HaloTextHelper.getColorGreen())
        end
    end)
    if AF and AF.dbg then AF.dbg(2, msg) else print("[AF] " .. msg) end
end

function P.claim(player, signature)
    if not player or not signature then return false, "bad_args" end
    local def = AF.Defs and AF.Defs.bySignature and AF.Defs.bySignature[signature]
    if not def then
        -- search lists
        for _, d in ipairs(P.allDefs()) do
            if d.signature == signature then def = d; break end
        end
    end
    if not def then return false, "no_def" end
    local e = P.getEntry(player, signature)
    if e.state == "complete" then return false, "already_complete" end
    local prog = P.readProgress(player, def)
    e.progress = prog
    if prog < (tonumber(def.amount) or 1) then
        return false, "not_qualified"
    end
    -- Deliver first; only mark complete if reward succeeded (retry stays Ready).
    local okDeliver, dmsg = true, "ok"
    if AF.Rewards and AF.Rewards.deliver then
        okDeliver, dmsg = AF.Rewards.deliver(player, def)
    end
    e.deliverOk = okDeliver and true or false
    e.deliverMsg = tostring(dmsg)
    if not okDeliver then
        e.state = "qualified"
        e.claimed = false
        dbg("CLAIM_FAIL " .. signature .. " " .. tostring(dmsg))
        pcall(function()
            if player.setHaloNote then
                player:setHaloNote("Reward failed — still Ready to retry", 255, 180, 80, 200)
            end
        end)
        return false, dmsg
    end
    e.state = "complete"
    e.claimed = true
    dbg("CLAIMED " .. signature .. " deliver=" .. tostring(okDeliver) .. " " .. tostring(dmsg))
    pcall(function()
        if player.setHaloNote then
            player:setHaloNote("Claimed: " .. tostring(def.name), 100, 255, 100, 180)
        end
    end)
    return true, dmsg
end

function P.rowsForUI(player)
    local rows = {}
    for _, def in ipairs(P.allDefs()) do
        local e = P.getEntry(player, def.signature)
        local prog = P.readProgress(player, def)
        e.progress = prog
        local need = tonumber(def.amount) or 1
        local state = e.state or "incomplete"
        if state ~= "complete" then
            if prog >= need then state = "qualified" else state = "incomplete" end
            e.state = state
        end
        rows[#rows + 1] = {
            def = def,
            entry = e,
            progress = prog,
            need = need,
            state = state,
            line = AF.Catalog and AF.Catalog.rowLabel(def) or def.name,
        }
    end
    table.sort(rows, function(a, b)
        local order = { complete = 1, qualified = 2, incomplete = 3 }
        local oa, ob = order[a.state] or 9, order[b.state] or 9
        if oa ~= ob then return oa < ob end
        local ra = (a.need > 0) and (a.progress / a.need) or 0
        local rb = (b.need > 0) and (b.progress / b.need) or 0
        if ra ~= rb then return ra > rb end
        return tostring(a.def.name) < tostring(b.def.name)
    end)
    return rows
end

--- Tick: scan about every 5s real-time
function P.onTick()
    local t = 0
    pcall(function() if getTimestampMs then t = getTimestampMs() end end)
    if t > 0 and (t - (P._lastScan or 0)) < 5000 then return end
    P._lastScan = t
    local p
    pcall(function() p = getSpecificPlayer(0) end)
    if not p then pcall(function() p = getPlayer() end) end
    if p then P.scanPlayer(p) end
end

function P.onEveryOneMinute()
    local p
    pcall(function() p = getSpecificPlayer(0) end)
    if not p then pcall(function() p = getPlayer() end) end
    if p then P.scanPlayer(p) end
end

print("[AF] AF_Progress loaded")
