--[[ AF_Browser — dual-list window + Add form
  Long dropdowns use vanilla ISComboBox:setEditable(true): open the combo and
  type to filter the popup (same pattern as admin trait picker / vehicle spawn).
  onResize reflows pack/player lists and form fields when the window is stretched.
]]
require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISScrollingListBox"

AF = AF or {}
AF.Browser = AF.Browser or {}

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MED = getTextManager():getFontHeight(UIFont.Medium)

AF_BrowserUI = ISCollapsableWindow:derive("AF_BrowserUI")

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function matchesFilter(text, filter)
    filter = lower(filter):gsub("^%s+", ""):gsub("%s+$", "")
    if filter == "" then return true end
    text = lower(text)
    for token in string.gmatch(filter, "%S+") do
        if not text:find(token, 1, true) then
            return false
        end
    end
    return true
end

function AF_BrowserUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:setResizable(true)
end

function AF_BrowserUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    local pad = 8

    self.lblListFilter = ISLabel:new(pad, 0, FONT_HGT_SMALL, "List search", 0.75, 0.85, 1, 1, UIFont.Small, true)
    self.lblListFilter:initialise()
    self:addChild(self.lblListFilter)
    self.entryListFilter = ISTextEntryBox:new("", 0, 0, 100, 22)
    self.entryListFilter:initialise()
    self.entryListFilter:instantiate()
    self.entryListFilter.onTextChange = function()
        self:reloadLists()
    end
    self:addChild(self.entryListFilter)

    self.lblPack = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Pack achievements (read-only)", 1, 1, 1, 1, UIFont.Small, true)
    self.lblPack:initialise(); self:addChild(self.lblPack)
    self.lblPlayer = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Player-authored (this world)", 1, 1, 1, 1, UIFont.Small, true)
    self.lblPlayer:initialise(); self:addChild(self.lblPlayer)

    self.listPack = ISScrollingListBox:new(pad, 0, 100, 100)
    self.listPack:initialise(); self.listPack:instantiate()
    self.listPack.itemheight = FONT_HGT_SMALL + 4
    self.listPack.selected = 0
    self.listPack.joypadParent = self
    self.listPack.font = UIFont.Small
    self.listPack.drawBorder = true
    self:addChild(self.listPack)

    self.listPlayer = ISScrollingListBox:new(pad, 0, 100, 100)
    self.listPlayer:initialise(); self.listPlayer:instantiate()
    self.listPlayer.itemheight = FONT_HGT_SMALL + 4
    self.listPlayer.selected = 0
    self.listPlayer.font = UIFont.Small
    self.listPlayer.drawBorder = true
    self:addChild(self.listPlayer)

    self.btnDelete = ISButton:new(0, 0, 120, 22, "Delete selected", self, AF_BrowserUI.onDelete)
    self.btnDelete:initialise()
    self.btnDelete:instantiate()
    self:addChild(self.btnDelete)
    self.btnRefresh = ISButton:new(0, 0, 90, 22, "Refresh", self, AF_BrowserUI.onRefresh)
    self.btnRefresh:initialise()
    self.btnRefresh:instantiate()
    self:addChild(self.btnRefresh)

    self.lblAdd = ISLabel:new(pad, 0, FONT_HGT_MED, "Add achievement", 0.6, 0.85, 1, 1, UIFont.Medium, true)
    self.lblAdd:initialise(); self:addChild(self.lblAdd)

    self.lblName = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Name", 1, 1, 1, 1, UIFont.Small, true)
    self.lblName:initialise(); self:addChild(self.lblName)
    self.entryName = ISTextEntryBox:new("", 0, 0, 100, 22)
    self.entryName:initialise(); self.entryName:instantiate()
    self:addChild(self.entryName)

    self.lblAction = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Action", 1, 1, 1, 1, UIFont.Small, true)
    self.lblAction:initialise(); self:addChild(self.lblAction)
    self.comboAction = ISComboBox:new(0, 0, 100, 22, self, AF_BrowserUI.onActionChanged)
    self.comboAction:initialise(); self.comboAction:instantiate()
    self:addChild(self.comboAction)

    self.lblMod = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Modifier", 1, 1, 1, 1, UIFont.Small, true)
    self.lblMod:initialise(); self:addChild(self.lblMod)
    self.comboMod = ISComboBox:new(0, 0, 100, 22, self, nil)
    self.comboMod:initialise(); self.comboMod:instantiate()
    pcall(function() if self.comboMod.setEditable then self.comboMod:setEditable(true) end end)
    self:addChild(self.comboMod)

    self.lblAmount = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Amount", 1, 1, 1, 1, UIFont.Small, true)
    self.lblAmount:initialise(); self:addChild(self.lblAmount)
    self.entryAmount = ISTextEntryBox:new("1", 0, 0, 100, 22)
    self.entryAmount:initialise(); self.entryAmount:instantiate()
    pcall(function() self.entryAmount:setOnlyNumbers(true) end)
    self:addChild(self.entryAmount)

    self.lblRType = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Reward type", 1, 1, 1, 1, UIFont.Small, true)
    self.lblRType:initialise(); self:addChild(self.lblRType)
    self.comboRType = ISComboBox:new(0, 0, 100, 22, self, AF_BrowserUI.onRTypeChanged)
    self.comboRType:initialise(); self.comboRType:instantiate()
    self:addChild(self.comboRType)

    self.lblReward = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Reward", 1, 1, 1, 1, UIFont.Small, true)
    self.lblReward:initialise(); self:addChild(self.lblReward)
    self.comboReward = ISComboBox:new(0, 0, 100, 22, self, nil)
    self.comboReward:initialise(); self.comboReward:instantiate()
    pcall(function() if self.comboReward.setEditable then self.comboReward:setEditable(true) end end)
    self:addChild(self.comboReward)

    self.lblRAmt = ISLabel:new(pad, 0, FONT_HGT_SMALL, "Reward #", 1, 1, 1, 1, UIFont.Small, true)
    self.lblRAmt:initialise(); self:addChild(self.lblRAmt)
    self.entryRAmt = ISTextEntryBox:new("1", 0, 0, 100, 22)
    self.entryRAmt:initialise(); self.entryRAmt:instantiate()
    pcall(function() self.entryRAmt:setOnlyNumbers(true) end)
    self:addChild(self.entryRAmt)

    self.btnAdd = ISButton:new(0, 0, 140, 24, "Add to player list", self, AF_BrowserUI.onAdd)
    self.btnAdd:initialise()
    self.btnAdd:instantiate()
    self:addChild(self.btnAdd)

    self.lblStatus = ISLabel:new(0, 0, FONT_HGT_SMALL, "", 1, 0.8, 0.4, 1, UIFont.Small, true)
    self.lblStatus:initialise()
    self:addChild(self.lblStatus)

    self.lblFilterHint = ISLabel:new(pad, 0, FONT_HGT_SMALL,
        "Tip: open Modifier/Reward dropdown and type to filter (built-in). List search filters pack/player rows.",
        0.65, 0.65, 0.7, 1, UIFont.Small, true)
    self.lblFilterHint:initialise()
    self:addChild(self.lblFilterHint)

    self._layoutW = -1
    self._layoutH = -1
    self:layoutChildren()

    self:populateCombos()
    self:reloadLists()
end

local function syncListScroll(list)
    if not list then return end
    -- Keep scrollbar geometry matched after setWidth/setHeight
    pcall(function()
        if list.vscroll then
            local barW = list.vscroll:getWidth() or 13
            list.vscroll:setX(math.max(0, list:getWidth() - barW))
            list.vscroll:setY(0)
            list.vscroll:setHeight(list:getHeight())
            if list.vscroll.setScrollHeight then
                -- no-op for bar; list owns scroll height
            end
        end
    end)
end

--- Reflow lists + form when window size changes.
function AF_BrowserUI:layoutChildren()
    if not self.listPack then return end
    local pad = 8
    local lw = 90
    local rowH = 26
    local btnH = 24
    local rh = 0
    pcall(function()
        if self.resizable and self.resizeWidgetHeight then
            rh = self:resizeWidgetHeight() or 0
        end
    end)

    local w = self:getWidth()
    local h = self:getHeight()
    local yTop = self:titleBarHeight() + 4
    local colW = math.floor((w - pad * 3) / 2)
    if colW < 120 then colW = 120 end

    -- Everything below the dual lists (must always fit)
    local belowLists =
        6 + btnH + 6 -- gap + Delete/Refresh row + gap
        + FONT_HGT_MED + 6 -- "Add achievement"
        + rowH * 7 -- name/action/mod/amount/rtype/reward/ramt
        + btnH + 4 -- Add button
        + FONT_HGT_SMALL + 4 -- status on its own line
        + FONT_HGT_SMALL + 6 -- tip
        + rh + pad

    -- Everything above the lists
    local aboveLists = 26 + FONT_HGT_SMALL + 4 -- filter + column headers

    local listH = math.floor(h - yTop - aboveLists - belowLists)
    if listH < 90 then listH = 90 end

    local y = yTop

    -- List search
    self.lblListFilter:setX(pad)
    self.lblListFilter:setY(y)
    self.entryListFilter:setX(pad + 80)
    self.entryListFilter:setY(y - 2)
    self.entryListFilter:setWidth(math.max(80, w - pad * 2 - 80))
    self.entryListFilter:setHeight(22)
    y = y + 26

    self.lblPack:setX(pad)
    self.lblPack:setY(y)
    self.lblPlayer:setX(pad * 2 + colW)
    self.lblPlayer:setY(y)
    y = y + FONT_HGT_SMALL + 4

    self.listPack:setX(pad)
    self.listPack:setY(y)
    self.listPack:setWidth(colW)
    self.listPack:setHeight(listH)
    syncListScroll(self.listPack)

    self.listPlayer:setX(pad * 2 + colW)
    self.listPlayer:setY(y)
    self.listPlayer:setWidth(colW)
    self.listPlayer:setHeight(listH)
    syncListScroll(self.listPlayer)

    y = y + listH + 6
    self.btnDelete:setX(pad * 2 + colW)
    self.btnDelete:setY(y)
    self.btnDelete:setWidth(120)
    self.btnDelete:setHeight(btnH)
    self.btnRefresh:setX(pad * 2 + colW + 130)
    self.btnRefresh:setY(y)
    self.btnRefresh:setWidth(90)
    self.btnRefresh:setHeight(btnH)

    y = y + btnH + 6
    self.lblAdd:setX(pad)
    self.lblAdd:setY(y)
    y = y + FONT_HGT_MED + 6

    local fieldW = math.max(80, w - pad * 2 - lw)
    local function placeRow(lab, widget)
        lab:setX(pad)
        lab:setY(y)
        widget:setX(pad + lw)
        widget:setY(y - 2)
        widget:setWidth(fieldW)
        widget:setHeight(22)
        y = y + rowH
    end

    placeRow(self.lblName, self.entryName)
    placeRow(self.lblAction, self.comboAction)
    placeRow(self.lblMod, self.comboMod)
    placeRow(self.lblAmount, self.entryAmount)
    placeRow(self.lblRType, self.comboRType)
    placeRow(self.lblReward, self.comboReward)
    placeRow(self.lblRAmt, self.entryRAmt)

    -- Button alone on its row (status was overlapping it)
    self.btnAdd:setX(pad)
    self.btnAdd:setY(y)
    self.btnAdd:setWidth(140)
    self.btnAdd:setHeight(btnH)
    y = y + btnH + 4

    self.lblStatus:setX(pad)
    self.lblStatus:setY(y)
    self.lblStatus:setWidth(math.max(40, w - pad * 2))
    y = y + FONT_HGT_SMALL + 4

    self.lblFilterHint:setX(pad)
    self.lblFilterHint:setY(y)
    self.lblFilterHint:setWidth(math.max(40, w - pad * 2))

    self._layoutW = w
    self._layoutH = h
end

function AF_BrowserUI:onResize()
    ISCollapsableWindow.onResize(self)
    self:layoutChildren()
end

function AF_BrowserUI:prerender()
    ISCollapsableWindow.prerender(self)
    -- Fallback if onResize is not invoked on all platforms
    local w, h = self:getWidth(), self:getHeight()
    if w ~= self._layoutW or h ~= self._layoutH then
        self:layoutChildren()
    end
end

function AF_BrowserUI:getListFilter()
    if self.entryListFilter and self.entryListFilter.getText then
        return self.entryListFilter:getText() or ""
    end
    return ""
end

function AF_BrowserUI:populateCombos()
    self.comboAction:clear()
    self._actionIds = {}
    if AF.Catalog then
        for _, a in ipairs(AF.Catalog.getActions()) do
            self.comboAction:addOption(a.label)
            self._actionIds[#self._actionIds + 1] = a.id
        end
    end
    self.comboRType:clear()
    self._rtypeIds = {}
    if AF.Rewards then
        for _, t in ipairs(AF.Rewards.getRewardTypes()) do
            self.comboRType:addOption(t.label)
            self._rtypeIds[#self._rtypeIds + 1] = t.id
        end
    end
    self:refillModifiers()
    self:refillRewards()
end

function AF_BrowserUI:selectedActionId()
    local i = self.comboAction.selected
    if not i or i < 1 then return "kill" end
    return self._actionIds[i] or "kill"
end

function AF_BrowserUI:selectedRType()
    local i = self.comboRType.selected
    if not i or i < 1 then return "item" end
    return self._rtypeIds[i] or "item"
end

function AF_BrowserUI:refillModifiers()
    if not self.comboMod then return end
    self.comboMod:clear()
    self._modIds = {}
    local act = self:selectedActionId()
    if not AF.Catalog then return end
    for _, m in ipairs(AF.Catalog.getModifiersForAction(act)) do
        local lab = tostring(m.label or "")
        if self.comboMod.addOptionWithData then
            self.comboMod:addOptionWithData(lab, m.id)
        else
            self.comboMod:addOption(lab)
        end
        self._modIds[#self._modIds + 1] = m.id
    end
    pcall(function() if self.comboMod.setEditable then self.comboMod:setEditable(true) end end)
    if self.comboMod.options and #self.comboMod.options > 0 then
        self.comboMod.selected = 1
    end
end

function AF_BrowserUI:refillRewards()
    if not self.comboReward then return end
    self.comboReward:clear()
    self._rewardIds = {}
    local rt = self:selectedRType()
    local list = AF.Rewards and AF.Rewards.getForType(rt) or {}
    local max = #list
    if rt == "item" and max > 6000 then max = 6000 end
    for i = 1, max do
        local r = list[i]
        if r then
            local lab = tostring(r.label or "")
            if self.comboReward.addOptionWithData then
                self.comboReward:addOptionWithData(lab, r.id)
            else
                self.comboReward:addOption(lab)
            end
            self._rewardIds[#self._rewardIds + 1] = r.id
        end
    end
    pcall(function() if self.comboReward.setEditable then self.comboReward:setEditable(true) end end)
    local defAmt = AF.Rewards and AF.Rewards.defaultAmount(rt) or 1
    if self.entryRAmt then
        self.entryRAmt:setText(tostring(defAmt))
        if rt == "trait" then self.entryRAmt:setText("1") end
    end
    if self.comboReward.options and #self.comboReward.options > 0 then
        self.comboReward.selected = 1
    end
    if self.lblStatus and rt == "item" and #list > max then
        self.lblStatus:setName(string.format("Items loaded %d / %d — type in dropdown to filter", max, #list))
    end
end

function AF_BrowserUI:selectedModifierId()
    local i = self.comboMod.selected or 1
    if self.comboMod.getOptionData then
        local d = nil
        pcall(function() d = self.comboMod:getOptionData(i) end)
        if d ~= nil then return d end
    end
    return self._modIds[i] or "none"
end

function AF_BrowserUI:selectedRewardId()
    local i = self.comboReward.selected or 1
    if self.comboReward.getOptionData then
        local d = nil
        pcall(function() d = self.comboReward:getOptionData(i) end)
        if d ~= nil then return d end
    end
    return self._rewardIds[i] or ""
end

function AF_BrowserUI:onActionChanged()
    self:refillModifiers()
end

function AF_BrowserUI:onRTypeChanged()
    self:refillRewards()
end

function AF_BrowserUI:reloadLists()
    if not self.listPack or not self.listPlayer then return end
    -- clear() does not reset scrollHeight — without this, bars stick forever after reloads
    local function resetList(list)
        list:clear()
        pcall(function()
            list:setScrollHeight(0)
            list:setYScroll(0)
            if list.smoothScrollTargetY then list.smoothScrollTargetY = nil end
            if list.smoothScrollY then list.smoothScrollY = nil end
        end)
    end
    resetList(self.listPack)
    resetList(self.listPlayer)
    if not AF.Defs then return end
    local filt = self:getListFilter()
    local nPack, nPlay = 0, 0
    for _, d in ipairs(AF.Defs.getPackList() or {}) do
        local line = (AF.Catalog and AF.Catalog.rowLabel(d)) or (d.name .. " | " .. tostring(d.signature))
        local hay = line .. " " .. tostring(d.name) .. " " .. tostring(d.signature) .. " " .. tostring(d.reward or "")
        if matchesFilter(hay, filt) then
            self.listPack:addItem(line, d)
            nPack = nPack + 1
        end
    end
    for _, d in ipairs(AF.Defs.getPlayerList() or {}) do
        local line = (AF.Catalog and AF.Catalog.rowLabel(d)) or (d.name .. " | " .. tostring(d.signature))
        local hay = line .. " " .. tostring(d.name) .. " " .. tostring(d.signature) .. " " .. tostring(d.reward or "")
        if matchesFilter(hay, filt) then
            self.listPlayer:addItem(line, d)
            nPlay = nPlay + 1
        end
    end
    syncListScroll(self.listPack)
    syncListScroll(self.listPlayer)
    if filt ~= "" and self.lblStatus then
        self.lblStatus:setName(string.format("Lists: pack %d, player %d", nPack, nPlay))
    end
end

function AF_BrowserUI:onRefresh()
    if AF.Defs then
        AF.Defs.reloadPacks()
        AF.Defs.loadPlayer()
    end
    if AF.Rewards then AF.Rewards.rebuildAll() end
    self:populateCombos()
    self:reloadLists()
    self.lblStatus:setName("Refreshed.")
end

function AF_BrowserUI:onDelete()
    local sel = self.listPlayer.selected
    if not sel or sel < 1 or not self.listPlayer.items or not self.listPlayer.items[sel] then
        self.lblStatus:setName("Select a player achievement.")
        return
    end
    local def = self.listPlayer.items[sel].item
    if def and def.signature and AF.Defs then
        AF.Defs.removePlayer(def.signature)
        self:reloadLists()
        if AF.Net and AF.Net.shouldSendClientCommand and AF.Net.shouldSendClientCommand() then
            self.lblStatus:setName("Delete sent to server…")
        else
            self.lblStatus:setName("Deleted.")
        end
    end
end

function AF_BrowserUI:onAdd()
    local name = self.entryName:getText() or ""
    local action = self:selectedActionId()
    local modifier = self:selectedModifierId()
    if AF.Catalog and AF.Catalog.isModifierHeader(modifier) then
        self.lblStatus:setName("Pick a real modifier, not a header.")
        return
    end
    local amount = tonumber(self.entryAmount:getText() or "1") or 1
    if action == "skill_level" then
        -- Target perk level; recommend 5–10 (PZ cap 10)
        if amount < 1 then amount = 1 end
        if amount > 10 then amount = 10 end
        if amount < 5 then
            -- still allow, but nudge status
            if self.lblStatus then
                self.lblStatus:setName("Skill level goals usually use amount 5–10 (target level).")
            end
        end
    end
    local rtype = self:selectedRType()
    local reward = self:selectedRewardId()
    local ramt = tonumber(self.entryRAmt:getText() or "1") or 1
    if rtype == "trait" then ramt = 1 end
    if name == "" then
        self.lblStatus:setName("Name required.")
        return
    end
    if reward == "" then
        self.lblStatus:setName("Pick a reward.")
        return
    end
    local view = self
    if AF.Net and AF.Net.setDefsStatusCallback then
        AF.Net.setDefsStatusCallback(function(ok, msg, signature)
            if view.lblStatus then
                if ok then
                    view.lblStatus:setName("Server defs: " .. tostring(msg) .. " " .. tostring(signature or ""))
                else
                    view.lblStatus:setName("Server defs failed: " .. tostring(msg))
                end
            end
            pcall(function() view:reloadLists() end)
        end)
    end
    local def, err = AF.Defs.addPlayer({
        name = name,
        action = action,
        modifier = modifier,
        amount = amount,
        rewardType = rtype,
        reward = reward,
        rewardAmount = ramt,
    })
    if not def then
        self.lblStatus:setName("Add failed: " .. tostring(err))
        return
    end
    self:reloadLists()
    if def._pending then
        self.lblStatus:setName("Add sent to server…")
    else
        self.lblStatus:setName("Added: " .. def.signature)
    end
    self.entryName:setText("")
end

function AF_BrowserUI:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "Achievement Framework — Browser"
    o.pin = true
    o:setResizable(true)
    o.minimumWidth = 560
    o.minimumHeight = 520
    return o
end

local _win = nil

function AF.Browser.open()
    pcall(function() require "AF/AF_Core" end)
    pcall(function() require "AF/AF_Catalog" end)
    pcall(function() require "AF/AF_Defs" end)
    pcall(function() require "AF/AF_Rewards" end)
    if not AF.Catalog or not AF.Defs then
        print("[AF] Browser missing Catalog/Defs after require")
        return
    end
    pcall(function()
        if AF.Rewards then AF.Rewards.rebuildAll() end
        AF.Defs.reloadPacks()
        AF.Defs.loadPlayer()
    end)
    if _win then
        pcall(function()
            _win:setVisible(false)
            _win:removeFromUIManager()
        end)
        _win = nil
    end
    local w, h = 840, 660
    local sw, sh = 1920, 1080
    pcall(function()
        sw = getCore():getScreenWidth()
        sh = getCore():getScreenHeight()
    end)
    local x = (sw - w) / 2
    local y = (sh - h) / 2
    _win = AF_BrowserUI:new(x, y, w, h)
    _win:initialise()
    _win:addToUIManager()
    _win:setVisible(true)
    if _win.bringToTop then _win:bringToTop() end
    print("[AF] Browser opened")
end

function AF.Browser.close()
    if _win then
        _win:setVisible(false)
        _win:removeFromUIManager()
    end
end

function AF.Browser._reloadIfOpen()
    if _win and _win.reloadLists then
        pcall(function() _win:reloadLists() end)
    end
end

print("[AF] AF_Browser loaded")
