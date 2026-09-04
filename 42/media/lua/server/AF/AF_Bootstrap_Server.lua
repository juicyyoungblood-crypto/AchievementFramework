--[[ AF_Bootstrap_Server — Claim + TrackSync + Defs authority (P0/P1 MP)
  Loads on SP + server. Skips pure MP clients.
]]
if isClient and isClient() and not (isServer and isServer()) then
    print("[AF] AF_Bootstrap_Server skip (pure client)")
    return
end

print("[AF] AF_Bootstrap_Server loading")

pcall(function() require "AF/AF_Core" end)
pcall(function() require "AF/AF_TrackStore" end)
pcall(function() require "AF/AF_Catalog" end)
pcall(function() require "AF/AF_Defs" end)
pcall(function() require "AF/AF_Rewards" end)
pcall(function() require "AF/AF_Progress" end)
pcall(function() require "AF/AF_Net" end)

local MODULE = (AF and AF.Net and AF.Net.MODULE) or "AchievementFramework"

local function dbg(msg)
    print("[AF][SRV] " .. tostring(msg))
end

local function ensureDefs()
    pcall(function()
        if AF.Rewards and AF.Rewards.rebuildAll then AF.Rewards.rebuildAll() end
        if AF.Defs then
            if AF.Defs.reloadPacks then AF.Defs.reloadPacks() end
            if AF.Defs.loadPlayer then AF.Defs.loadPlayer() end
        end
    end)
end

local function isAdminPlayer(player)
    -- SP: everyone is authority
    local ic, isv = false, false
    pcall(function()
        if isClient then ic = isClient() and true or false end
        if isServer then isv = isServer() and true or false end
    end)
    if not ic and not isv then return true end
    if not player then return false end
    local ok = false
    pcall(function()
        if player.getAccessLevel then
            local lvl = string.lower(tostring(player:getAccessLevel() or ""))
            if lvl == "admin" or lvl == "moderator" or lvl == "overseer" then
                ok = true
            end
        end
    end)
    -- Some builds use access level numbers / isAccessLevel
    if not ok then
        pcall(function()
            if isAdmin and isAdmin() and isServer and isServer() then
                -- only meaningful on listen host client; skip
            end
        end)
    end
    return ok
end

local function defToPOD(def)
    if type(def) ~= "table" then return nil end
    return {
        name = tostring(def.name or ""),
        action = tostring(def.action or ""),
        modifier = tostring(def.modifier or "none"),
        amount = tonumber(def.amount) or 1,
        rewardType = tostring(def.rewardType or "item"),
        reward = tostring(def.reward or ""),
        rewardAmount = tonumber(def.rewardAmount) or 1,
        signature = tostring(def.signature or ""),
        source = "player",
        packName = "player",
    }
end

local function playerListPOD()
    local out = {}
    if not AF.Defs or not AF.Defs.getPlayerList then return out end
    local list = AF.Defs.getPlayerList() or {}
    for i = 1, #list do
        local pod = defToPOD(list[i])
        if pod then out[#out + 1] = pod end
    end
    return out
end

local function pushDefsTo(playerOrNil)
    local args = { playerAchievements = playerListPOD() }
    pcall(function()
        if not sendServerCommand then return end
        if playerOrNil then
            sendServerCommand(playerOrNil, MODULE, "DefsPush", args)
        else
            sendServerCommand(MODULE, "DefsPush", args)
        end
    end)
end

local function sendTo(player, command, args)
    if not player then return end
    pcall(function()
        if sendServerCommand then
            sendServerCommand(player, MODULE, command, args or {})
        end
    end)
end

local function applyTrack(player, args)
    if not player or type(args) ~= "table" then return false end
    if type(args.track) ~= "table" then return false end
    if AF.Track and AF.Track.importPOD then
        return AF.Track.importPOD(player, args.track, "merge_max")
    end
    return false
end

local function handleTrackSync(player, args)
    local ok = applyTrack(player, args)
    dbg("TrackSync ok=" .. tostring(ok))
end

local function handleClaim(player, args)
    args = args or {}
    local signature = tostring(args.signature or "")
    if signature == "" then
        sendTo(player, "ClaimResult", { signature = "", ok = false, msg = "bad_args", name = "" })
        return
    end
    if not player then
        dbg("Claim no player")
        return
    end

    ensureDefs()
    applyTrack(player, args)

    local defName = signature
    pcall(function()
        if AF.Defs and AF.Defs.bySignature and AF.Defs.bySignature[signature] then
            defName = tostring(AF.Defs.bySignature[signature].name or signature)
        end
    end)

    local ok, msg = false, "no_progress"
    if AF and AF.Net and AF.Net.claimLocal then
        ok, msg = AF.Net.claimLocal(player, signature)
    elseif AF and AF.Progress and AF.Progress.claim then
        ok, msg = AF.Progress.claim(player, signature)
    end
    dbg("Claim sig=" .. signature .. " ok=" .. tostring(ok) .. " " .. tostring(msg))
    sendTo(player, "ClaimResult", {
        signature = signature,
        ok = ok and true or false,
        msg = tostring(msg or ""),
        name = defName,
    })
end

local function handleDefsAdd(player, args)
    args = args or {}
    if not isAdminPlayer(player) then
        sendTo(player, "DefsResult", { ok = false, msg = "not_admin" })
        return
    end
    ensureDefs()
    local def, err = nil, "no_defs"
    if AF.Defs and AF.Defs.addPlayer then
        -- Force server-side save without client command recursion: call core path
        def, err = AF.Defs.addPlayer({
            name = args.name,
            action = args.action,
            modifier = args.modifier,
            amount = args.amount,
            rewardType = args.rewardType,
            reward = args.reward,
            rewardAmount = args.rewardAmount,
        }, true) -- serverAuth flag
    end
    if def then
        sendTo(player, "DefsResult", { ok = true, msg = "added", signature = def.signature })
        pushDefsTo(nil)
        dbg("DefsAdd " .. tostring(def.signature))
    else
        sendTo(player, "DefsResult", { ok = false, msg = tostring(err or "fail") })
        dbg("DefsAdd fail " .. tostring(err))
    end
end

local function handleDefsRemove(player, args)
    args = args or {}
    local signature = tostring(args.signature or "")
    if not isAdminPlayer(player) then
        sendTo(player, "DefsResult", { ok = false, msg = "not_admin", signature = signature })
        return
    end
    ensureDefs()
    if AF.Defs and AF.Defs.removePlayer then
        AF.Defs.removePlayer(signature, true)
    end
    sendTo(player, "DefsResult", { ok = true, msg = "removed", signature = signature })
    pushDefsTo(nil)
    dbg("DefsRemove " .. signature)
end

local function handleDefsRequest(player, args)
    ensureDefs()
    pushDefsTo(player)
    dbg("DefsRequest -> push")
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then return end
    if isClient and isClient() and not (isServer and isServer()) then return end

    command = tostring(command or "")
    if command == "Claim" then
        handleClaim(player, args)
    elseif command == "TrackSync" then
        handleTrackSync(player, args)
    elseif command == "DefsAdd" then
        handleDefsAdd(player, args)
    elseif command == "DefsRemove" then
        handleDefsRemove(player, args)
    elseif command == "DefsRequest" then
        handleDefsRequest(player, args)
    end
end

local function onGameStart()
    dbg("OnGameStart ensure defs " .. tostring(AF and AF.VERSION))
    ensureDefs()
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(onClientCommand)
    dbg("OnClientCommand hooked module=" .. MODULE)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(onGameStart)
end
if Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(function()
        pcall(function()
            if ModData and ModData.getOrCreate then ModData.getOrCreate("AF_World") end
        end)
        ensureDefs()
    end)
end

ensureDefs()
dbg("ready VERSION=" .. tostring(AF and AF.VERSION))
