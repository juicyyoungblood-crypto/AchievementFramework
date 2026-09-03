--[[ AF_Net — shared module id + claim request helpers (SP dual-path) ]]
AF = AF or {}
AF.Net = AF.Net or {}
local Net = AF.Net

Net.MODULE = "AchievementFramework"
Net.CMD_CLAIM = "Claim"
Net.CMD_CLAIM_RESULT = "ClaimResult"

function Net.isPureClient()
    -- MP client process that is not the listen-server authority side
    local ic, isv = false, false
    pcall(function()
        if isClient then ic = isClient() and true or false end
        if isServer then isv = isServer() and true or false end
    end)
    return ic and not isv
end

function Net.isAuthority()
    -- SP, dedicated server, or listen-host server side
    local ic, isv = false, false
    pcall(function()
        if isClient then ic = isClient() and true or false end
        if isServer then isv = isServer() and true or false end
    end)
    if isv then return true end
    if not ic and not isv then return true end -- SP
    return false
end

function Net.shouldSendClientCommand()
    -- Any client bridge (pure client or listen-host client UI)
    local ic = false
    pcall(function()
        if isClient then ic = isClient() and true or false end
    end)
    return ic
end

--- Run claim on this machine (SP or server authority).
function Net.claimLocal(player, signature)
    if not AF.Progress or not AF.Progress.claim then
        return false, "no_progress"
    end
    return AF.Progress.claim(player, signature)
end

--- UI / client entry: MP sends command; SP claims locally.
--- Returns: "pending" | true | false, msg
function Net.requestClaim(player, signature)
    signature = tostring(signature or "")
    if signature == "" then return false, "bad_args" end

    if Net.shouldSendClientCommand() then
        pcall(function()
            sendClientCommand(Net.MODULE, Net.CMD_CLAIM, { signature = signature })
        end)
        print("[AF] Net.requestClaim pending sig=" .. signature)
        return "pending", "sent"
    end

    local ok, msg = Net.claimLocal(player, signature)
    return ok, msg
end

--- Apply server ClaimResult on client UI / local progress mirror.
function Net.applyClaimResult(args)
    args = args or {}
    local signature = tostring(args.signature or "")
    local ok = args.ok and true or false
    local msg = tostring(args.msg or "")
    local name = tostring(args.name or signature)

    local p = nil
    pcall(function() p = getSpecificPlayer(0) end)
    if not p then pcall(function() p = getPlayer() end) end

    if p and signature ~= "" and AF.Progress and AF.Progress.getEntry then
        local e = AF.Progress.getEntry(p, signature)
        if e then
            e.deliverOk = ok
            e.deliverMsg = msg
            if ok then
                e.state = "complete"
                e.claimed = true
            else
                -- keep retryable unless already complete
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

print("[AF] AF_Net loaded module=" .. tostring(Net.MODULE))
