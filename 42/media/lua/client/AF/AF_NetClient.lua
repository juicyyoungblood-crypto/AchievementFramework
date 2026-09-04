--[[ AF_NetClient — ClaimResult / DefsPush / DefsResult ]]
print("[AF] AF_NetClient loading")

pcall(function() require "AF/AF_Net" end)

local MODULE = (AF and AF.Net and AF.Net.MODULE) or "AchievementFramework"

local function onServerCommand(module, command, args)
    if module ~= MODULE then return end
    command = tostring(command or "")
    if command == "ClaimResult" or command == (AF.Net and AF.Net.CMD_CLAIM_RESULT) then
        if AF and AF.Net and AF.Net.applyClaimResult then
            AF.Net.applyClaimResult(args)
        end
    elseif command == "DefsPush" or command == (AF.Net and AF.Net.CMD_DEFS_PUSH) then
        if AF and AF.Net and AF.Net.applyDefsPush then
            AF.Net.applyDefsPush(args)
        end
    elseif command == "DefsResult" or command == (AF.Net and AF.Net.CMD_DEFS_RESULT) then
        if AF and AF.Net and AF.Net.applyDefsResult then
            AF.Net.applyDefsResult(args)
        end
    end
end

if Events and Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
    print("[AF] AF_NetClient OnServerCommand hooked")
end

print("[AF] AF_NetClient ready")
