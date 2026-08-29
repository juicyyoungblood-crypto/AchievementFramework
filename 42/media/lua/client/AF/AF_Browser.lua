--[[ AF_Browser — dual-list window + Add form
  Long dropdowns use vanilla ISComboBox:setEditable(true): open the combo and
  type to filter the popup (same pattern as admin trait picker / vehicle spawn).
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
    local y = self:titleBarHeight() + 4
    local w = self:getWidth()
    local h = self:getHeight() - self:titleBarHeight() - pad
    local colW = math.floor((w - pad * 3) / 2)
    local listH = math.floor(h * 0.40)

    -- List search (pack + player scrolling lists — not combos)
    self.lblListFilter = ISLabel:new(pad, y, FONT_HGT_SMALL, "List search", 0.75, 0.85, 1, 1, UIFont.Small, true)
    self.lblListFilter:initialise()
    self:addChild(self.lblListFilter)
    self.entryListFilter = ISTextEntryBox:new("", pad + 80, y - 2, w - pad * 2 - 80, 22)
    self.entryListFilter:initialise()
    self.entryListFilter:instantiate()
    self.entryListFilter.onTextChange = function()
        self:reloadLists()
    end
    self:addChild(self.entryListFilter)
    y = y + 26

    self.lblPack = ISLabel:new(pad, y, FONT_HGT_SMALL, "Pack achievements (read-only)", 1, 1, 1, 1, UIFont.Small, true)
    self.lblPack:initialise(); self:addChild(self.lblPack)
    self.lblPlayer = ISLabel:new(pad * 2 + colW, y, FONT_HGT_SMALL, "Player-authored (this world)", 1, 1, 1, 1, UIFont.Small, true)
    self.lblPlayer:initialise(); self:addChild(self.lblPlayer)
    y = y + FONT_HGT_SMALL + 4

    self.listPack = ISScrollingListBox:new(pad, y, colW, listH)
    self.listPack:initialise(); self.listPack:instantiate()
    self.listPack.itemheight = FONT_HGT_SMALL + 4
    self.listPack.selected = 0
    self.listPack.joypadParent = self
    self.listPack.font = UIFont.Small
    self.listPack.drawBorder = true
    self:addChild(self.listPack)

    self.listPlayer = ISScrollingListBox:new(pad * 2 + colW, y, colW, listH)
    self.listPlayer:initialise(); self.listPlayer:instantiate()
    self.listPlayer.itemheight = FONT_HGT_SMALL + 4
    self.listPlayer.selected = 0
    self.listPlayer.font = UIFont.Small
    self.listPlayer.drawBorder = true
    self:addChild(self.listPlayer)

    y = y + listH + 6
    self.btnDelete = ISButton:new(pad * 2 + colW, y, 120, 22, "Delete selected", self, AF_BrowserUI.onDelete)
    self.btnDelete:initialise()
    self.btnDelete:instantiate()
    self:addChild(self.btnDelete)
    self.btnRefresh = ISButton:new(pad * 2 + colW + 130, y, 90, 22, "Refresh", self, AF_BrowserUI.onRefresh)
    self.btnRefresh:initialise()
    self.btnRefresh:instantiate()
    self:addChild(self.btnRefresh)

    y = y + 28
    self.lblAdd = ISLabel:new(pad, y, FONT_HGT_MED, "Add achievement", 0.6, 0.85, 1, 1, UIFont.Medium, true)
    self.lblAdd:initialise(); self:addChild(self.lblAdd)
    y = y + FONT_HGT_MED + 6

    local lw = 90
    local function row(label, widget, editable)
        local lab = ISLabel:new(pad, y, FONT_HGT_SMALL, label, 1, 1, 1, 1, UIFont.Small, true)
        lab:initialise()
        self:addChild(lab)
        widget:setX(pad + lw)
        widget:setY(y - 2)
        widget:setWidth(w - pad * 2 - lw)
        widget:setHeight(22)
        widget:initialise()
        widget:instantiate()
        if editable and widget.setEditable then
            pcall(function() widget:setEditable(true) end)
        end
        self:addChild(widget)
        y = y + 26
        return widget
    end

    self.entryName = ISTextEntryBox:new("", 0, 0, 100, 22)
    row("Name", self.entryName)

    self.comboAction = ISComboBox:new(0, 0, 100, 22, self, AF_BrowserUI.onActionChanged)
    row("Action", self.comboAction, false)

    -- Editable combo: click open, type in the box to filter the popup (vanilla web-like filter)
    self.comboMod = ISComboBox:new(0, 0, 100, 22, self, nil)
    row("Modifier", self.comboMod, true)

    self.entryAmount = ISTextEntryBox:new("1", 0, 0, 100, 22)
    row("Amount", self.entryAmount)
    pcall(function() self.entryAmount:setOnlyNumbers(true) end)

    self.comboRType = ISComboBox:new(0, 0, 100, 22, self, AF_BrowserUI.onRTypeChanged)
    row("Reward type", self.comboRType, false)

    self.comboReward = ISComboBox:new(0, 0, 100, 22, self, nil)
    row("Reward", self.comboReward, true)

    self.entryRAmt = ISTextEntryBox:new("1", 0, 0, 100, 22)
    row("Reward #", self.entryRAmt)
    pcall(function() self.entryRAmt:setOnlyNumbers(true) end)

    self.btnAdd = ISButton:new(pad, y, 140, 24, "Add to player list", self, AF_BrowserUI.onAdd)
    self.btnAdd:initialise()
    self.btnAdd:instantiate()
    self:addChild(self.btnAdd)

    self.lblStatus = ISLabel:new(pad + 150, y + 4, FONT_HGT_SMALL, "", 1, 0.8, 0.4, 1, UIFont.Small, true)
    self.lblStatus:initialise()
    self:addChild(self.lblStatus)

    self.lblFilterHint = ISLabel:new(pad, y + 28, FONT_HGT_SMALL,
        "Tip: open Modifier/Reward dropdown and type to filter (built-in). List search filters pack/player rows.",
        0.65, 0.65, 0.7, 1, UIFont.Small, true)
    self.lblFilterHint:initialise()
    self:addChild(self.lblFilterHint)

    self:populateCombos()
    self:reloadLists()
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
        -- Prefer option+data so id tracks selection even if labels collide
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
    -- Items are huge; still load a large set so in-dropdown filter is useful
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
    self.listPack:clear()
    self.listPlayer:clear()
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
        self.lblStatus:setName("Deleted.")
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
    self.lblStatus:setName("Added: " .. def.signature)
    self.entryName:setText("")
end

function AF_BrowserUI:prerender()
    ISCollapsableWindow.prerender(self)
end

function AF_BrowserUI:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "Achievement Framework — Browser"
    o.pin = true
    o:setResizable(true)
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

print("[AF] AF_Browser loaded")
