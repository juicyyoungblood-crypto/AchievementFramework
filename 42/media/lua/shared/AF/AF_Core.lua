--[[ AF_Core — shared version + debug level ]]
AF = AF or {}
AF.VERSION = "0.15.5"

-- Debug levels: 0=off, 1=errors, 2=info, 3=verbose
-- Sandbox AchievementFramework.DebugLog=true forces at least 2.
AF.DEBUG_LEVEL = 0
AF._dbgBuf = {}
AF._dbgLastFlush = 0

local function sandboxDebugOn()
    local on = false
    pcall(function()
        if not getSandboxOptions then return end
        local o = getSandboxOptions()
        if not o or not o.getOptionByName then return end
        local opt = o:getOptionByName("AchievementFramework.DebugLog")
        if opt and opt.getValue then on = opt:getValue() and true or false end
    end)
    return on
end

function AF.debugLevel()
    local lvl = tonumber(AF.DEBUG_LEVEL) or 0
    if sandboxDebugOn() and lvl < 2 then return 2 end
    return lvl
end

function AF.setDebugLevel(n)
    AF.DEBUG_LEVEL = tonumber(n) or 0
end

--- level: 1 error, 2 info, 3 verbose
function AF.dbg(level, msg)
    level = tonumber(level) or 2
    if level > AF.debugLevel() then return end
    local line = "[AF] " .. tostring(msg)
    if level <= 1 or AF.debugLevel() >= 2 then
        print(line)
    end
    if AF.debugLevel() < 2 then return end
    -- buffer file writes; flush periodically
    local buf = AF._dbgBuf
    buf[#buf + 1] = line
    if #buf >= 40 then
        AF.flushDebugLog(true)
    end
end

function AF.flushDebugLog(force)
    if AF.debugLevel() < 2 then
        AF._dbgBuf = {}
        return
    end
    local buf = AF._dbgBuf
    if not buf or #buf == 0 then return end
    local t = 0
    pcall(function() if getTimestampMs then t = getTimestampMs() end end)
    if not force and t > 0 and (t - (AF._dbgLastFlush or 0)) < 2000 and #buf < 80 then
        return
    end
    AF._dbgLastFlush = t
    pcall(function()
        if not getFileWriter then return end
        local w = getFileWriter("AF_debug.log", true, true)
        if not w then return end
        for i = 1, #buf do
            w:write(buf[i] .. "\n")
        end
        w:close()
    end)
    AF._dbgBuf = {}
end

print("[AF] shared AF_Core " .. tostring(AF.VERSION))
