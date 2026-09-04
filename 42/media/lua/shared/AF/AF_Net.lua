--[[ AF_Net — module id + claim / track / defs helpers (SP dual-path) ]]
AF = AF or {}
AF.Net = AF.Net or {}
local Net = AF.Net

Net.MODULE = "AchievementFramework"
Net.CMD_CLAIM = "Claim"
Net.CMD_CLAIM_RESULT = "ClaimResult"
Net.CMD_TRACK_SYNC = "TrackSync"
Net.CMD_DEFS_ADD = "DefsAdd"
Net.CMD_DEFS_REMOVE = "DefsRemove"
Net.CMD_DEFS_REQUEST = "DefsRequest"
Net.CMD_DEFS_PUSH = "DefsPush"
Net.CMD_DEFS_RESULT = "DefsResult"

function Net.isPureClient()
    local ic, isv = false, false
    pcall(function()
        if isClient then ic = isClient() and true or false end
        if isServer then isv = isServer() and true or false end
    end)
    return ic and not isv
end

function Net.isAuthority()
    local ic, isv = false, false
    pcall(function()
        if isClient then ic = isClient() and true or false end
        if isServer then isv = isServer() and true or false end
    end)
    if isv then return true end
    if not ic and not isv then return true end
    return false
end

function Net.shouldSendClientCommand()
    local ic = false
    pcall(function()
        if isClient then ic = isClient() and true or false end
    end)
    return ic
end

function Net.claimLocal(player, signature)
    if not AF.Progress or not AF.Progress.claim then
        return false, "no_progress"
    end
    return AF.Progress.claim(player, signature)
end

local function localPlayer()
    local p = nil
    pcall(function() p = getSpecificPlayer(0) end)
    if not p then pcall(function() p = getPlayer() end) end
    return p
end

--- Attach track POD for server qualify (P1).
function Net.trackArgsFor(player)
    local args = {}
    pcall(function()
        if AF.Track and AF.Track.exportPOD then
            args.track = AF.Track.exportPOD(player)
        end
    end)
    return args
end

function Net.requestClaim(player, signature)
    signature = tostring(signature or "")
    if signature == "" then return false, "bad_args" end
    player = player or localPlayer()

    if Net.shouldSendClientCommand() then
        local args = Net.trackArgsFor(player)
        args.signature = signature
        pcall(function()
            sendClientCommand(Net.MODULE, Net.CMD_CLAIM, args)
        end)
        print("[AF] Net.requestClaim pending sig=" .. signature)
        return "pending", "sent"
    end

    local ok, msg = Net.claimLocal(player, signature)
    return ok, msg
end

function Net.requestTrackSync(player)
    player = player or localPlayer()
    if not Net.shouldSendClientCommand() then
        return false, "not_client"
    end
    if not player then return false, "no_player" end
    local args = Net.trackArgsFor(player)
    if not args.track then return false, "no_track" end
    pcall(function()
        sendClientCommand(Net.MODULE, Net.CMD_TRACK_SYNC, args)
    end)
    return true, "sent"
end

function Net.requestDefsAdd(raw)
    raw = raw or {}
    if Net.shouldSendClientCommand() then
        local args = {
            name = tostring(raw.name or ""),
            action = tostring(raw.action or ""),
            modifier = tostring(raw.modifier or "none"),
            amount = tonumber(raw.amount) or 1,
            rewardType = tostring(raw.rewardType or "item"),
            reward = tostring(raw.reward or ""),
            rewardAmount = tonumber(raw.rewardAmount) or 1,
        }
        pcall(function()
            sendClientCommand(Net.MODULE, Net.CMD_DEFS_ADD, args)
        end)
        return "pending", "sent"
    end
    if not AF.Defs or not AF.Defs.addPlayer then return false, "no_defs" end
    local def, err = AF.Defs.addPlayer(raw)
    if def then return true, def.signature end
    return false, err
end

function Net.requestDefsRemove(signature)
    signature = tostring(signature or "")
    if signature == "" then return false, "bad_args" end
    if Net.shouldSendClientCommand() then
        pcall(function()
            sendClientCommand(Net.MODULE, Net.CMD_DEFS_REMOVE, { signature = signature })
        end)
        return "pending", "sent"
    end
    if AF.Defs and AF.Defs.removePlayer then
        AF.Defs.removePlayer(signature)
        return true, "ok"
    end
    return false, "no_defs"
end

function Net.requestDefsSync()
    if not Net.shouldSendClientCommand() then return false, "not_client" end
    pcall(function()
        sendClientCommand(Net.MODULE, Net.CMD_DEFS_REQUEST, {})
    end)
    return true, "sent"
end

function Net.applyClaimResult(args)
    args = args or {}
    local signature = tostring(args.signature or "")
    local ok = args.ok and true or false
    local msg = tostring(args.msg or "")
    local name = tostring(args.name or signature)

    local p = localPlayer()

    if p and signature ~= "" and AF.Progress and AF.Progress.getEntry then
        local e = AF.Progress.getEntry(p, signature)
        if e then
            e.deliverOk = ok
            e.deliverMsg = msg
            if ok then
                e.state = "complete"
                e.claimed = true
            else
                if e.state ~= "complete" then
                    e.state = "qualified"
                    e.claimed = false
                end
            end
        end
    end

    pcall(function()
        if not p or not p.setHaloNote then return end
        if ok then
            p:setHaloNote("Claimed: " .. name, 100, 255, 100, 180)
        else
            p:setHaloNote("Reward failed — still Ready to retry", 255, 180, 80, 200)
        end
    end)

    pcall(function()
        if AF.Sheet and AF.Sheet.refreshTab then AF.Sheet.refreshTab() end
    end)

    if Net._claimStatusCb then
        pcall(function() Net._claimStatusCb(ok, msg, signature, name) end)
    end

    print("[AF] ClaimResult ok=" .. tostring(ok) .. " sig=" .. signature .. " " .. msg)
    return ok, msg
end

function Net.setClaimStatusCallback(fn)
    Net._claimStatusCb = fn
end

function Net.applyDefsPush(args)
    args = args or {}
    local list = args.playerAchievements
    if type(list) ~= "table" then list = args.list end
    if type(list) ~= "table" or not AF.Defs then return false end

    -- Rebuild player list from server SoT (keep packs)
    pcall(function()
        if AF.Defs.reloadPacks then AF.Defs.reloadPacks() end
    end)
    AF.Defs.player = {}
    -- reindex packs only then add player
    pcall(function()
        AF.Defs.bySignature = {}
        for i = 1, #(AF.Defs.pack or {}) do
            local d = AF.Defs.pack[i]
            if d and d.signature then AF.Defs.bySignature[d.signature] = d end
        end
    end)
    for i = 1, #list do
        local raw = list[i]
        if type(raw) == "table" then
            local def = AF.Defs.normalize and AF.Defs.normalize(raw, "player", "player")
            if def and AF.Defs.register then
                AF.Defs.register(def, AF.Defs.player)
            end
        end
    end
    print("[AF] DefsPush applied player=" .. tostring(#AF.Defs.player))
    pcall(function()
        if AF.Browser and AF.Browser._reloadIfOpen then AF.Browser._reloadIfOpen() end
    end)
    if Net._defsStatusCb then
        pcall(function() Net._defsStatusCb(true, "pushed", #AF.Defs.player) end)
    end
    return true
end

function Net.applyDefsResult(args)
    args = args or {}
    local ok = args.ok and true or false
    local msg = tostring(args.msg or "")
    if Net._defsStatusCb then
        pcall(function() Net._defsStatusCb(ok, msg, args.signature) end)
    end
    print("[AF] DefsResult ok=" .. tostring(ok) .. " " .. msg)
    return ok, msg
end

function Net.setDefsStatusCallback(fn)
    Net._defsStatusCb = fn
end

print("[AF] AF_Net loaded module=" .. tostring(Net.MODULE))
