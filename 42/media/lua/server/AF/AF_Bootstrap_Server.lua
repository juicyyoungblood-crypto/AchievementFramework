--[[ AF_Bootstrap_Server — pack load + Claim authority (P0 MP)
  Loads on SP + server. Skips pure MP clients (server folder still loads there).
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

local function sendClaimResult(player, signature, ok, msg, name)
    if not player then return end
    local args = {
        signature = tostring(signature or ""),
        ok = ok and true or false,
        msg = tostring(msg or ""),
        name = tostring(name or ""),
    }
    pcall(function()
        if sendServerCommand then
            sendServerCommand(player, MODULE, "ClaimResult", args)
        end
    end)
end

local function handleClaim(player, args)
    args = args or {}
    local signature = tostring(args.signature or "")
    if signature == "" then
        sendClaimResult(player, "", false, "bad_args", "")
        return
    end
    if not player then
        dbg("Claim no player")
        return
    end

    ensureDefs()

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
    sendClaimResult(player, signature, ok, msg, defName)
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then return end
    -- Belt: ignore if somehow pure-client
    if isClient and isClient() and not (isServer and isServer()) then return end

    command = tostring(command or "")
    if command == "Claim" then
        handleClaim(player, args)
        return
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
