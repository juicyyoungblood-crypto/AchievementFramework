--[[ AF_SandboxUI
  Inject Open Achievement Browser onto the Achievement Framework sandbox page.
  Hooks new-game SandboxOptionsScreen + in-game ISServerSandboxOptionsUI (debug).
]]
require "ISUI/ISButton"
require "ISUI/ISLabel"

print("[AF] AF_SandboxUI loading")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MED = getTextManager():getFontHeight(UIFont.Medium)

local function isAFPage(page)
    if not page then return false end
    local name = tostring(page.name or "")
    local lname = string.lower(name)
    if lname:find("achievement", 1, true) then return true end
    if page.settings then
        for _, s in ipairs(page.settings) do
            if type(s) == "table" and type(s.name) == "string" then
                if s.name:find("AchievementFramework", 1, true) then return true end
            end
        end
    end
    return false
end

local function openBrowser()
    pcall(function()
        pcall(function() require "AF/AF_Browser" end)
        if AF and AF.Browser and AF.Browser.open then
            AF.Browser.open()
        end
    end)
end

local function injectButton(panel, page)
    if not panel or panel._AF_browserBtn then return end
    if not isAFPage(page) then return end

    local y = 8
    pcall(function()
        if panel.settingNames and panel.controls then
            local maxB = 0
            for _, name in ipairs(panel.settingNames) do
                local c = panel.controls[name]
                if c then
                    local bottom = 0
                    pcall(function()
                        if c.getBottom then bottom = c:getBottom()
                        elseif c.y and c.height then bottom = c.y + c.height
                        end
                    end)
                    if bottom > maxB then maxB = bottom end
                end
            end
            if maxB > 0 then y = maxB + 16 end
        end
    end)

    local help = ISLabel:new(10, y, FONT_HGT_SMALL,
        "Authoring only here. In-game hotkey (default J) opens the character Achievements tab to claim.",
        0.85, 0.85, 0.85, 1, UIFont.Small, true)
    help:initialise()
    panel:addChild(help)
    y = y + FONT_HGT_SMALL + 10

    local btn = ISButton:new(10, y, 280, FONT_HGT_MED + 10, "Open Achievement Browser", panel, function()
        openBrowser()
    end)
    btn:initialise()
    btn:instantiate()
    btn.backgroundColor = { r = 0.15, g = 0.35, b = 0.55, a = 1 }
    btn.borderColor = { r = 0.4, g = 0.7, b = 1, a = 1 }
    panel:addChild(btn)
    panel._AF_browserBtn = btn

    y = y + FONT_HGT_MED + 16
    local tip = ISLabel:new(10, y, FONT_HGT_SMALL,
        "Left = pack JSON (read-only). Right = this world + Add form.",
        0.75, 0.9, 0.75, 1, UIFont.Small, true)
    tip:initialise()
    panel:addChild(tip)

    print("[AF] injected Open Browser button on sandbox page: " .. tostring(page and page.name))
end

local function hookCreatePanel(cls, tag)
    if not cls or type(cls.createPanel) ~= "function" then return end
    local flag = "_AF_hooked_" .. tostring(tag)
    if cls[flag] then return end
    local orig = cls.createPanel
    cls.createPanel = function(self, page)
        local panel = orig(self, page)
        pcall(function() injectButton(panel, page) end)
        return panel
    end
    cls[flag] = true
    print("[AF] hooked " .. tostring(tag) .. ".createPanel")
end

local function hookListSelect(cls, tag)
    if not cls or type(cls.onMouseDownListbox) ~= "function" then return end
    local flag = "_AF_hookedList_" .. tostring(tag)
    if cls[flag] then return end
    local orig = cls.onMouseDownListbox
    cls.onMouseDownListbox = function(self, item)
        orig(self, item)
        pcall(function()
            if item and item.panel and item.page then
                injectButton(item.panel, item.page)
            end
        end)
    end
    cls[flag] = true
    print("[AF] hooked " .. tostring(tag) .. ".onMouseDownListbox")
end

local function tryHook()
    pcall(function()
        if SandboxOptionsScreen then
            hookCreatePanel(SandboxOptionsScreen, "SandboxOptionsScreen")
            hookListSelect(SandboxOptionsScreen, "SandboxOptionsScreen")
        end
    end)
    pcall(function()
        if not ISServerSandboxOptionsUI then
            pcall(function() require "ISUI/AdminPanel/ISServerSandboxOptionsUI" end)
        end
        if ISServerSandboxOptionsUI then
            hookCreatePanel(ISServerSandboxOptionsUI, "ISServerSandboxOptionsUI")
            if type(ISServerSandboxOptionsUI.onMouseDownListbox) == "function" then
                hookListSelect(ISServerSandboxOptionsUI, "ISServerSandboxOptionsUI")
            end
        end
    end)
end

Events.OnGameBoot.Add(tryHook)
Events.OnMainMenuEnter.Add(tryHook)
Events.OnGameStart.Add(tryHook)
if Events.OnCreateUI then Events.OnCreateUI.Add(tryHook) end
tryHook()

print("[AF] AF_SandboxUI ready")
