--[[ AF_AchievementsTab — character sheet tab: progress + Claim

  Sizing (Knox lesson):
  - NEVER call setWidth/HeightAndParent* every render using max(self.width, …)
    — that runaway-expands to fullscreen.
  - Fill the existing ISTabPanel client area only.
  - Scroll inside ISScrollingListBox only.
]]
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"

AF = AF or {}
AF.Sheet = AF.Sheet or {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MED = getTextManager():getFontHeight(UIFont.Medium)
local TAB_TITLE = "Achievements"
local PAD = 8

AF_AchievementsView = ISPanel:derive("AF_AchievementsView")

function AF_AchievementsView:initialise()
    ISPanel.initialise(self)
end

function AF_AchievementsView:createChildren()
    local y = PAD
    self.lbl = ISLabel:new(PAD, y, FONT_HGT_MED, "Achievements", 0.75, 0.9, 1, 1, UIFont.Medium, true)
    self.lbl:initialise()
    self.lbl:instantiate()
    self:addChild(self.lbl)
    y = y + FONT_HGT_MED + 6
    self._listTop = y

    local btnH = 24
    local w = self.width or 400
    local h = self.height or 400
    local listH = math.max(80, h - y - btnH - PAD * 2)
    local listW = math.max(100, w - PAD * 2)

    self.list = ISScrollingListBox:new(PAD, y, listW, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = FONT_HGT_SMALL + 6
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self:addChild(self.list)

    self.btnClaim = ISButton:new(PAD, h - btnH - PAD, 120, btnH, "Claim reward", self, AF_AchievementsView.onClaim)
    self.btnClaim:initialise()
    self.btnClaim:instantiate()
    self:addChild(self.btnClaim)

    self.lblStatus = ISLabel:new(PAD + 130, h - btnH - PAD + 4, FONT_HGT_SMALL, "", 1, 1, 0.6, 1, UIFont.Small, true)
    self.lblStatus:initialise()
    self:addChild(self.lblStatus)

    self:reload()
end

--- Reflow children to OUR current bounds only (no parent resize).
function AF_AchievementsView:layoutChildren()
    local w = self:getWidth() or self.width or 400
    local h = self:getHeight() or self.height or 400
    local btnH = 24
    local listTop = self._listTop or (PAD + FONT_HGT_MED + 6)
    local listH = math.max(60, h - listTop - btnH - PAD * 2)
    local listW = math.max(80, w - PAD * 2)

    if self.list then
        pcall(function()
            self.list:setX(PAD)
            self.list:setY(listTop)
            self.list:setWidth(listW)
            self.list:setHeight(listH)
        end)
    end
    local by = h - btnH - PAD
    if self.btnClaim then
        pcall(function() self.btnClaim:setX(PAD); self.btnClaim:setY(by) end)
    end
    if self.lblStatus then
        pcall(function() self.lblStatus:setX(PAD + 130); self.lblStatus:setY(by + 4) end)
    end
end

function AF_AchievementsView:onMouseWheel(del)
    if not self.list then return false end
    if self.list.onMouseWheel then
        return self.list:onMouseWheel(del)
    end
    return false
end

function AF_AchievementsView:getPlayer()
    local p
    pcall(function() p = getSpecificPlayer(0) end)
    if not p then pcall(function() p = getPlayer() end) end
    return p
end

function AF_AchievementsView:reload()
    if not self.list then return end

    -- 1. Remember selection + scroll (snippet pattern; id = Goal Signature)
    local savedSig = nil
    local savedScroll = nil
    pcall(function()
        local idx = self.list.selected
        if idx and idx > 0 and self.list.items and self.list.items[idx] then
            local row = self.list.items[idx].item
            if row and row.def and row.def.signature then
                savedSig = row.def.signature
            end
        end
        if self.list.getYScroll then
            savedScroll = self.list:getYScroll()
        elseif self.list.yScroll ~= nil then
            savedScroll = self.list.yScroll
        end
    end)

    -- 2. Clear and repopulate
    self.list:clear()
    local p = self:getPlayer()
    if not p or not AF.Progress then
        self.list:addItem("(no player / progress)", nil)
        return
    end
    pcall(function() AF.Progress.scanPlayer(p) end)
    local rows = AF.Progress.rowsForUI(p) or {}
    for i = 1, #rows do
        local r = rows[i]
        local tag = "[ ]"
        if r.state == "qualified" then tag = "[Ready]"
        elseif r.state == "complete" then tag = "[Claimed]" end
        local line = string.format("%s %s/%s  %s", tag, tostring(r.progress), tostring(r.need), r.line or "")
        self.list:addItem(line, r)
    end
    if #rows == 0 then
        self.list:addItem("(no achievements loaded)", nil)
    end

    -- 3. Restore selection by signature (for Claim), but do NOT force it on-screen.
    --    ensureVisible would yank scroll back to the highlight every auto-refresh.
    if savedSig and self.list.items then
        for i, listItem in ipairs(self.list.items) do
            local row = listItem and listItem.item
            if row and row.def and row.def.signature == savedSig then
                self.list.selected = i
                break
            end
        end
    end
    -- Keep the user's scroll position exactly (free browse while auto-refresh runs)
    if savedScroll ~= nil then
        pcall(function()
            if self.list.setYScroll then
                self.list:setYScroll(savedScroll)
            elseif self.list.yScroll ~= nil then
                self.list.yScroll = savedScroll
            end
        end)
    end
end

function AF_AchievementsView:onRefresh()
    self:reload()
    if self.lblStatus then self.lblStatus:setName("Refreshed.") end
end

--- Same as former Refresh button — used by EveryOneMinute auto-refresh.
function AF.Sheet.refreshTab()
    local win
    pcall(function()
        if getPlayerInfoPanel then win = getPlayerInfoPanel(0) end
    end)
    if not win then
        pcall(function()
            win = ISCharacterInfoWindow and ISCharacterInfoWindow.instance
        end)
    end
    local view = win and win._AF_achView
    if not view then
        pcall(function()
            if win and win.panel and win.panel.viewList then
                for _, entry in ipairs(win.panel.viewList) do
                    if entry and entry.view and entry.view._AF_achievements then
                        view = entry.view
                        break
                    end
                end
            end
        end)
    end
    if view and view.reload then
        view:reload()
        if view.lblStatus then
            view.lblStatus:setName("Auto-refreshed.")
        end
        return true
    end
    return false
end

--- Open character sheet on the Achievements tab (claim/progress). Not the Browser.
function AF.Sheet.openTab()
    local playerNum = 0
    pcall(function()
        local p = getSpecificPlayer(0) or getPlayer()
        if p and p.getPlayerNum then playerNum = p:getPlayerNum() end
    end)

    -- Ensure tab is injected
    pcall(function()
        if AF.Sheet.boot then AF.Sheet.boot() end
    end)

    local info
    pcall(function()
        if getPlayerInfoPanel then info = getPlayerInfoPanel(playerNum) end
    end)
    if not info then
        pcall(function()
            info = ISCharacterInfoWindow and ISCharacterInfoWindow.instance
        end)
    end
    if not info then
        print("[AF] openTab: no character info panel")
        return false
    end

    -- ensure our tab exists on this window
    pcall(function()
        if not info._AF_achTab and AF.Sheet.boot then AF.Sheet.boot() end
    end)

    local title = "Achievements"
    pcall(function()
        if info.toggleView then
            -- Same pattern as Health/Protection: toggleView(tabName)
            info:toggleView(title)
        elseif info.panel and info.panel.activateView then
            if not info:getIsVisible() then
                info:setVisible(true)
                info:addToUIManager()
            end
            info.panel:activateView(title)
        end
    end)

    pcall(function() AF.Sheet.refreshTab() end)
    print("[AF] openTab Achievements")
    return true
end

function AF_AchievementsView:onClaim()
    local p = self:getPlayer()
    if not p or not AF.Progress then
        if self.lblStatus then self.lblStatus:setName("No player.") end
        return
    end
    local sel = self.list.selected
    if not sel or sel < 1 or not self.list.items or not self.list.items[sel] then
        if self.lblStatus then self.lblStatus:setName("Select a row.") end
        return
    end
    local r = self.list.items[sel].item
    if not r or not r.def then
        if self.lblStatus then self.lblStatus:setName("Nothing to claim.") end
        return
    end
    if r.state == "complete" then
        if self.lblStatus then self.lblStatus:setName("Already complete.") end
        return
    end
    if r.state ~= "qualified" then
        if self.lblStatus then self.lblStatus:setName("Not qualified yet.") end
        return
    end
    local ok, msg = AF.Progress.claim(p, r.def.signature)
    if self.lblStatus then
        if ok then
            self.lblStatus:setName("Claimed! " .. tostring(msg))
        else
            self.lblStatus:setName("Reward failed (still Ready): " .. tostring(msg))
        end
    end
    self:reload()
end

function AF_AchievementsView:prerender()
    ISPanel.prerender(self)
    -- Sync to tab panel client size if parent resized US (not the other way around)
    local parent = self.parent
    if parent then
        local pw, ph
        pcall(function()
            pw = parent:getWidth() or parent.width
            local th = parent.tabHeight or 0
            ph = (parent:getHeight() or parent.height or 0) - th
        end)
        if pw and ph and pw > 50 and ph > 50 then
            if math.abs((self.width or 0) - pw) > 1 or math.abs((self.height or 0) - ph) > 1 then
                pcall(function()
                    self:setWidth(pw)
                    self:setHeight(ph)
                end)
                self.width = pw
                self.height = ph
            end
        end
    end
    self:layoutChildren()
    self:drawRect(0, 0, self.width or 0, self.height or 0, 0.9, 0.05, 0.08, 0.12)
end

function AF_AchievementsView:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0.05, g = 0.08, b = 0.12, a = 0.95 }
    o.borderColor = { r = 0.3, g = 0.5, b = 0.7, a = 1 }
    return o
end

-- ---- Character window inject ----
local function measurePanelClient(panel)
    local pw = 400
    local ph = 400
    pcall(function()
        pw = panel:getWidth() or panel.width or pw
        local th = panel.tabHeight or 22
        local fullH = panel:getHeight() or panel.height or (ph + th)
        ph = fullH - th
        if ph < 100 then ph = 400 end
        if pw < 200 then pw = 400 end
    end)
    return pw, ph
end

local function ensureTab(window)
    if not window or not window.panel then return end
    if window._AF_achTab then return end
    local panel = window.panel
    if type(panel.addView) ~= "function" then return end

    pcall(function()
        local list = panel.viewList or panel.views
        if not list then return end
        for _, entry in pairs(list) do
            if type(entry) == "table" then
                if entry.name == TAB_TITLE or (entry.view and entry.view._AF_achievements) then
                    window._AF_achTab = true
                    window._AF_achView = entry.view
                    return
                end
            end
        end
    end)
    if window._AF_achTab then return end

    local pw, ph = measurePanelClient(panel)
    -- Prefer size of an existing sibling view (Protection / Health) so we match
    pcall(function()
        local list = panel.viewList or panel.views
        for _, entry in pairs(list or {}) do
            if type(entry) == "table" and entry.view and not entry.view._AF_achievements then
                local vw = entry.view.width or (entry.view.getWidth and entry.view:getWidth())
                local vh = entry.view.height or (entry.view.getHeight and entry.view:getHeight())
                if vw and vh and vw >= 200 and vh >= 200 and vw < 900 and vh < 900 then
                    pw, ph = vw, vh
                    break
                end
            end
        end
    end)

    local view = AF_AchievementsView:new(0, 0, pw, ph)
    view._AF_achievements = true
    view:initialise()
    view:instantiate()
    -- Do NOT setAnchorRight/Bottom in a way that fights the tab panel; fill fixed client box
    local ok, err = pcall(function()
        panel:addView(TAB_TITLE, view)
    end)
    if ok then
        window._AF_achTab = true
        window._AF_achView = view
        print(string.format("[AF] Achievements tab added (fixed client %sx%s — no parent grow)", tostring(pw), tostring(ph)))
    else
        print("[AF] addView failed: " .. tostring(err))
    end
end

local function patchCharacterWindow()
    pcall(function() require "ISUI/ISCharacterInfoWindow" end)
    if not ISCharacterInfoWindow then
        print("[AF] ISCharacterInfoWindow not ready")
        return
    end
    if ISCharacterInfoWindow._AF_patchVer == "0.10.5" then return end
    ISCharacterInfoWindow._AF_patchVer = "0.10.5"
    ISCharacterInfoWindow._AF_patch = true

    local oldCreate = ISCharacterInfoWindow.createChildren
    ISCharacterInfoWindow.createChildren = function(self)
        if oldCreate then oldCreate(self) end
        pcall(function() ensureTab(self) end)
    end

    local oldUpdate = ISCharacterInfoWindow.update
    if oldUpdate then
        ISCharacterInfoWindow.update = function(self)
            oldUpdate(self)
            pcall(function()
                if not self._AF_achTab then ensureTab(self) end
            end)
        end
    end

    pcall(function()
        if ISCharacterInfoWindow.instance then
            ensureTab(ISCharacterInfoWindow.instance)
        end
    end)
    print("[AF] Character info patched for Achievements tab (no grow)")
end

function AF.Sheet.boot()
    patchCharacterWindow()
end

Events.OnGameStart.Add(function() AF.Sheet.boot() end)
Events.OnCreatePlayer.Add(function() AF.Sheet.boot() end)
pcall(AF.Sheet.boot)

print("[AF] AF_AchievementsTab loaded")
