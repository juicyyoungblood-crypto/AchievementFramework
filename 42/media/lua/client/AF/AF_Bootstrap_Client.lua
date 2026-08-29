--[[ AF_Bootstrap_Client — defs, browser, progress scan, sheet tab ]]
print("[AF] AF_Bootstrap_Client loading")

pcall(function() require "AF/AF_Core" end)
pcall(function() require "AF/AF_Catalog" end)
pcall(function() require "AF/AF_Defs" end)
pcall(function() require "AF/AF_Rewards" end)
pcall(function() require "AF/AF_Progress" end)
pcall(function() require "AF/AF_Browser" end)
pcall(function() require "AF/AF_SandboxUI" end)
pcall(function() require "AF/AF_CharWindowLock" end)
pcall(function() require "AF/AF_AchievementsTab" end)

local function dbg(msg) print("[AF] " .. tostring(msg)) end

--- Default J = LWJGL Keyboard.KEY_J (36)
local function defaultJ()
    local j = 36
    pcall(function()
        if Keyboard and Keyboard.KEY_J then j = Keyboard.KEY_J end
    end)
    return j
end

local function sandboxKey()
    local k = nil
    pcall(function()
        if getSandboxOptions then
            local o = getSandboxOptions()
            if o and o.getOptionByName then
                local opt = o:getOptionByName("AchievementFramework.BrowserHotkey")
                if opt and opt.getValue then k = opt:getValue() end
            end
        end
    end)
    if k and tonumber(k) and tonumber(k) > 0 then return tonumber(k) end
    return defaultJ()
end

local function onKey(key)
    local want = sandboxKey()
    if key ~= want then return end
    -- J / hotkey → character Achievements tab (claim), NOT the authoring Browser
    if AF and AF.Sheet and AF.Sheet.openTab then
        AF.Sheet.openTab()
    end
end

local function onGameStart()
    dbg("Bootstrap OnGameStart " .. tostring(AF and AF.VERSION))
    pcall(function()
        if AF.Rewards then AF.Rewards.rebuildAll() end
        if AF.Defs then
            AF.Defs.reloadPacks()
            AF.Defs.loadPlayer()
        end
        if AF.CharLock and AF.CharLock.boot then AF.CharLock.boot() end
        if AF.Sheet and AF.Sheet.boot then AF.Sheet.boot() end
        local p = getPlayer and getPlayer() or nil
        if p and AF.Progress then AF.Progress.scanPlayer(p) end
    end)
    dbg("Hotkey=" .. tostring(sandboxKey()) .. " opens Achievements tab | Browser = debug sandbox button only | DebugLog sandbox option")
end

local function onInitModData()
    pcall(function() ModData.getOrCreate("AF_World") end)
end

Events.OnKeyPressed.Add(onKey)
Events.OnGameStart.Add(onGameStart)
if Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(onInitModData)
end
if Events.OnTick and AF and AF.Progress then
    Events.OnTick.Add(function()
        pcall(function() AF.Progress.onTick() end)
    end)
end
if Events.EveryOneMinute and AF and AF.Progress then
    Events.EveryOneMinute.Add(function()
        pcall(function() AF.Progress.onEveryOneMinute() end)
        pcall(function()
            if AF.Sheet and AF.Sheet.refreshTab then
                AF.Sheet.refreshTab()
            end
        end)
    end)
end

dbg("AF_Bootstrap_Client ready")
