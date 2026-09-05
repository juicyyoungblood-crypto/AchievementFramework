--[[ AF_AchievementsTab — character sheet tab: progress + Claim

  Sizing (Knox-style, no global window lock):
  - Do NOT hook ISUIElement.setWidthAndParentWidth / lock all tabs.
  - When Achievements tab is active, auto-size the character window to a
    fixed preferred width + height from content (clamped to screen).
  - Other tabs keep their normal / other-mod sizing.
  - List scrolls inside the tab client area only.
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

-- Preferred outer width when Achievements is showing (same idea as Knox System tab)
local ACH_FIXED_W = 460
local ACH_CONTENT_H = 480
local OUTER_TITLE_H = 48
local OUTER_PAD = 8

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

    -- Preferred content height for auto-size (list + chrome)
    self._contentH = ACH_CONTENT_H

    self:reload()
end

--- Reflow children to OUR current bounds only (no parent resize here).
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
            if self.list.vscroll then
                pcall(function()
                    self.list.vscroll:setHeight(listH)
                    if self.list.updateScrollbars then self.list:updateScrollbars() end
                end)
            end
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

    pcall(function()
        if self.list.clear then self.list:clear() end
        self.list.scrollHeight = 0
        if self.list.yScroll ~= nil then self.list.yScroll = 0 end
    end)

    local p = self:getPlayer()
    if not p or not AF.Progress or not AF.Progress.rowsForUI then return end

    local rows = AF.Progress.rowsForUI(p) or {}
    for i = 1, #rows do
        local r = rows[i]
        local state = tostring(r.state or "?")
        local tag = ""
        if state == "qualified" then tag = "[READY] "
        elseif state == "complete" then tag = "[DONE] "
        else tag = "[....] " end
        local name = r.def and r.def.name or "?"
        local prog = tostring(math.floor(tonumber(r.progress) or 0))
        local need = tostring(math.floor(tonumber(r.need) or 0))
        local line = tag .. name .. "  " .. prog .. "/" .. need
        pcall(function()
            self.list:addItem(line, r)
        end)
    end

    -- Grow preferred content a bit with more rows (still scrolls if taller than client)
    local n = #rows
    local rowH = (self.list and self.list.itemheight) or (FONT_HGT_SMALL + 6)
    local listNeed = math.min(420, math.max(160, n * rowH + 24))
    self._contentH = PAD + FONT_HGT_MED + 6 + listNeed + 24 + PAD * 2
    if self._contentH < ACH_CONTENT_H then self._contentH = ACH_CONTENT_H end
    if self._contentH > 720 then self._contentH = 720 end

    pcall(function()
        if savedSig and self.list.items then
            for i = 1, #self.list.items do
                local it = self.list.items[i]
                if it and it.item and it.item.def and it.item.def.signature == savedSig then
                    self.list.selected = i
                    break
                end
            end
        end
        if savedScroll and self.list.setYScroll then
            self.list:setYScroll(savedScroll)
        end
        if self.list.updateScrollbars then self.list:updateScrollbars() end
    end)
end

function AF_AchievementsView:onClaim()
    local p = self:getPlayer()
    if not p then return end
    if not self.list or not self.list.items then return end
    local idx = self.list.selected
    if not idx or idx < 1 or not self.list.items[idx] then
        if self.lblStatus then self.lblStatus:setName("Select an achievement.") end
        return
    end
    local r = self.list.items[idx].item
    if not r or not r.def or not r.def.signature then return end
    if r.state == "complete" then
        if self.lblStatus then self.lblStatus:setName("Already claimed.") end
        return
    end
    if r.state ~= "qualified" then
        if self.lblStatus then self.lblStatus:setName("Not qualified yet.") end
        return
    end

    local sig = r.def.signature
    local view = self
    if AF.Net and AF.Net.setClaimStatusCallback then
        AF.Net.setClaimStatusCallback(function(ok, msg, signature, name)
            if view.lblStatus then
                if ok then
                    view.lblStatus:setName("Claimed! " .. tostring(msg))
                else
                    view.lblStatus:setName("Reward failed (still Ready): " .. tostring(msg))
                end
            end
            pcall(function() view:reload() end)
        end)
    end

    if AF.Net and AF.Net.requestClaim then
        local ok, msg = AF.Net.requestClaim(p, sig)
        if ok == "pending" then
            if self.lblStatus then self.lblStatus:setName("Claiming…") end
            return
        end
        if self.lblStatus then
            if ok then
                self.lblStatus:setName("Claimed! " .. tostring(msg))
            else
                self.lblStatus:setName("Reward failed (still Ready): " .. tostring(msg))
            end
        end
        self:reload()
        return
    end

    local ok, msg = AF.Progress.claim(p, sig)
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
    -- Fill parent tab client area only (do not grow the window from here)
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
    o._contentH = ACH_CONTENT_H
    return o
end

-- ---- Character window inject + Knox-style auto-size when tab active ----

local function measurePanelClient(panel)
    local pw = ACH_FIXED_W
    local ph = ACH_CONTENT_H
    pcall(function()
        pw = panel:getWidth() or panel.width or pw
        local th = panel.tabHeight or 22
        local fullH = panel:getHeight() or panel.height or (ph + th)
        ph = fullH - th
        if ph < 100 then ph = ACH_CONTENT_H end
        if pw < 200 then pw = ACH_FIXED_W end
    end)
    return pw, ph
end

local function isAchievementsTabActive(window)
    if not window then return false end
    local view = window._AF_achView
    if not view then return false end
    local vis = false
    pcall(function()
        if view.getIsVisible then vis = view:getIsVisible() and true or false end
    end)
    if vis then return true end
    -- fallback: active view name
    pcall(function()
        local panel = window.panel
        if not panel then return end
        local name = nil
        if panel.activeView and panel.activeView.name then
            name = panel.activeView.name
        elseif panel.getActiveView and panel:getActiveView() then
            local av = panel:getActiveView()
            if type(av) == "table" and av.name then name = av.name end
        end
        if name and tostring(name) == TAB_TITLE then vis = true end
    end)
    return vis
end

--- Fit window when Achievements is showing (fixed preferred W, H from content).
--- Never use max(currentWidth, …) — that expands to fullscreen.
local function fitWindowToAchievements(window)
    if not window or not window._AF_achView then return end
    local view = window._AF_achView
    local tabPanel = window.panel
    local contentH = tonumber(view._contentH) or ACH_CONTENT_H
    if contentH < 200 then contentH = ACH_CONTENT_H end

    pcall(function()
        local tabH = (tabPanel and tabPanel.tabHeight) or 22
        local needW = ACH_FIXED_W
        local needH = contentH + tabH + OUTER_TITLE_H + OUTER_PAD

        local screenH, screenW = 900, 1600
        pcall(function()
            screenW = getCore():getScreenWidth() or screenW
            screenH = getCore():getScreenHeight() or screenH
        end)

        local maxH = math.min(needH, screenH - 48)
        if maxH < 360 then maxH = math.min(360, screenH - 48) end
        local maxW = math.min(needW, screenW - 48)
        if maxW < 360 then maxW = math.min(360, screenW - 20) end

        local curW = window.width or 0
        local curH = window.height or 0
        pcall(function()
            if window.getWidth then curW = window:getWidth() or curW end
            if window.getHeight then curH = window:getHeight() or curH end
        end)
        local wOk = math.abs((curW or 0) - maxW) <= 2
        local hOk = math.abs((curH or 0) - maxH) <= 2
        if not wOk or not hOk then
            if window.setWidth then window:setWidth(maxW) end
            if window.setHeight then window:setHeight(maxH) end
            window.width = maxW
            window.height = maxH
        end

        local pw = maxW - 8
        local ph = maxH - OUTER_TITLE_H
        if ph < 200 then ph = maxH - 16 end

        if tabPanel then
            local tpW = tabPanel.width or 0
            local tpH = tabPanel.height or 0
            if math.abs(tpW - pw) > 2 or math.abs(tpH - ph) > 2 then
                if tabPanel.setWidth then tabPanel:setWidth(pw) end
                if tabPanel.setHeight then tabPanel:setHeight(ph) end
                tabPanel.width = pw
                tabPanel.height = ph
            end
        end

        local clientH = ph - tabH
        if clientH < 160 then clientH = math.max(160, ph - 20) end

        if view.setWidth then view:setWidth(pw) end
        view.width = pw
        if view.setHeight then view:setHeight(clientH) end
        view.height = clientH
        pcall(function() view:layoutChildren() end)
    end)
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
    -- Start at preferred size (auto-fit adjusts when tab is opened)
    if pw < ACH_FIXED_W then pw = ACH_FIXED_W end
    if ph < 300 then ph = ACH_CONTENT_H end

    local view = AF_AchievementsView:new(0, 0, pw, ph)
    view._AF_achievements = true
    view:initialise()
    view:instantiate()
    local ok, err = pcall(function()
        panel:addView(TAB_TITLE, view)
    end)
    if ok then
        window._AF_achTab = true
        window._AF_achView = view
        print(string.format("[AF] Achievements tab added (auto-size when active; no global lock)"))
    else
        print("[AF] addView failed: " .. tostring(err))
    end
end

local function hookActivateView(window)
    if not window or not window.panel then return end
    local panel = window.panel
    if panel._AF_actHook then return end
    if type(panel.activateView) ~= "function" then return end
    panel._AF_actHook = true
    local oldAct = panel.activateView
    panel.activateView = function(pself, name)
        local result = oldAct(pself, name)
        pcall(function()
            if tostring(name or "") == TAB_TITLE then
                if window._AF_achView and window._AF_achView.reload then
                    window._AF_achView:reload()
                end
                fitWindowToAchievements(window)
            end
        end)
        return result
    end
end

local function patchCharacterWindow()
    pcall(function() require "ISUI/ISCharacterInfoWindow" end)
    if not ISCharacterInfoWindow then
        print("[AF] ISCharacterInfoWindow not ready")
        return
    end
    if ISCharacterInfoWindow._AF_patchVer == "0.15.11" then
        pcall(function()
            if ISCharacterInfoWindow.instance then
                ensureTab(ISCharacterInfoWindow.instance)
                hookActivateView(ISCharacterInfoWindow.instance)
            end
        end)
        return
    end
    ISCharacterInfoWindow._AF_patchVer = "0.15.11"
    ISCharacterInfoWindow._AF_patch = true

    local oldCreate = ISCharacterInfoWindow.createChildren
    ISCharacterInfoWindow.createChildren = function(self)
        if oldCreate then oldCreate(self) end
        pcall(function()
            ensureTab(self)
            hookActivateView(self)
        end)
    end

    local oldUpdate = ISCharacterInfoWindow.update
    if oldUpdate then
        ISCharacterInfoWindow.update = function(self)
            oldUpdate(self)
            pcall(function()
                if not self._AF_achTab then
                    ensureTab(self)
                    hookActivateView(self)
                end
                if isAchievementsTabActive(self) then
                    self._AF_fitTick = (self._AF_fitTick or 0) + 1
                    if self._AF_fitTick >= 30 then
                        self._AF_fitTick = 0
                        fitWindowToAchievements(self)
                    end
                end
            end)
        end
    end

    pcall(function()
        if ISCharacterInfoWindow.instance then
            ensureTab(ISCharacterInfoWindow.instance)
            hookActivateView(ISCharacterInfoWindow.instance)
        end
    end)
    print("[AF] Character info patched: Achievements tab + auto-size when active (no global lock)")
end

function AF.Sheet.boot()
    patchCharacterWindow()
end

function AF.Sheet.fitIfActive()
    local win = ISCharacterInfoWindow and ISCharacterInfoWindow.instance
    if win and isAchievementsTabActive(win) then
        fitWindowToAchievements(win)
    end
end

Events.OnGameStart.Add(function() AF.Sheet.boot() end)
Events.OnCreatePlayer.Add(function() AF.Sheet.boot() end)
pcall(AF.Sheet.boot)

print("[AF] AF_AchievementsTab loaded")
