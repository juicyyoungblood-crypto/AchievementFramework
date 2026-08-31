--[[ AF_CharWindowLock
  Fixed WIDTH for the whole character info window; HEIGHT stays free (tabs may
  grow/scroll vertically).

  Idea from: lock width to a reference tab, force window+panel+views, override
  setWidth so Info/etc. cannot shrink or grow the frame.

  Fixes vs naive snippet:
  - getPlayerInfoPanel(0) is valid (vanilla uses it), but also fall back to
    ISCharacterInfoWindow.instance.
  - OnCreateUI is often too early; also hook createChildren + periodic enforce.
  - Reference width = max(Protection, ClothingIns, tab strip, floor) — not only
    Temperature (may be missing / named clothing insulation).
  - Clamp setWidthAndParentWidth under this window so Protection cannot widen.
  - Never touch height locks.
]]

AF = AF or {}
AF.CharLock = AF.CharLock or {}
local L = AF.CharLock

L.FLOOR_W = 420
L.CEIL_W = 700
L._lockW = nil
L._hookedUI = false
L._hookedWindow = false

local function dbg(msg)
    print("[AF] CharLock " .. tostring(msg))
end

local function getWin(playerNum)
    playerNum = playerNum or 0
    local w
    pcall(function()
        if getPlayerInfoPanel then
            w = getPlayerInfoPanel(playerNum)
        end
    end)
    if not w then
        pcall(function()
            w = ISCharacterInfoWindow and ISCharacterInfoWindow.instance
        end)
    end
    return w
end

--- Pick a stable width once: widest "reasonable" vanilla tab, clamped.
function L.computeLockW(win)
    if not win or not win.panel then return L.FLOOR_W end
    local candidates = { L.FLOOR_W }

    local function addW(v)
        if not v then return end
        local w
        pcall(function()
            w = v.width or (v.getWidth and v:getWidth())
        end)
        if w and tonumber(w) and tonumber(w) >= 200 and tonumber(w) <= L.CEIL_W then
            candidates[#candidates + 1] = tonumber(w)
        end
    end

    -- Named vanilla tabs
    pcall(function()
        addW(win.protectionView)
        addW(win.clothingView)
        addW(win.healthView)
        addW(win.characterView)
        addW(win.charScreen)
    end)

    -- Any view currently on the panel (Protection often sizes itself once)
    pcall(function()
        for _, item in ipairs(win.panel.viewList or {}) do
            if item and item.view then addW(item.view) end
        end
    end)

    -- Tab strip minimum
    pcall(function()
        local pw = win.panel.width or (win.panel.getWidth and win.panel:getWidth())
        if pw then candidates[#candidates + 1] = tonumber(pw) end
    end)

    local lock = L.FLOOR_W
    for i = 1, #candidates do
        if candidates[i] > lock then lock = candidates[i] end
    end
    if lock > L.CEIL_W then lock = L.CEIL_W end
    return math.floor(lock)
end

function L.getLockWFor(element)
    local p = element
    local depth = 0
    while p and depth < 12 do
        if p._AF_charLockW then return p._AF_charLockW end
        if p.Type == "ISCharacterInfoWindow" and L._lockW then return L._lockW end
        p = p.parent
        depth = depth + 1
    end
    return nil
end

function L.applyToWindow(win, lockW)
    if not win then return end
    lockW = lockW or L._lockW or L.FLOOR_W
    L._lockW = lockW
    win._AF_charLockW = lockW

    -- Raw width set avoiding our override recursion
    local function rawSetWidth(obj, w)
        if not obj then return end
        if obj._AF_rawSetWidth then
            obj:_AF_rawSetWidth(w)
        elseif obj.setWidth then
            -- temporarily unhook
            local ov = obj.setWidth
            if obj._AF_origSetWidth then
                obj._AF_origSetWidth(obj, w)
            else
                -- javaObject path
                pcall(function()
                    if obj.javaObject and obj.javaObject.setWidth then
                        obj.javaObject:setWidth(w)
                    end
                    obj.width = w
                end)
            end
        end
        pcall(function() obj.width = w end)
    end

    if not win._AF_origSetWidth then
        win._AF_origSetWidth = win.setWidth
        win.setWidth = function(self, newWidth)
            local lw = self._AF_charLockW or L._lockW or newWidth
            if self._AF_origSetWidth then
                self:_AF_origSetWidth(lw)
            end
            self.width = lw
        end
    end

    pcall(function()
        if win._AF_origSetWidth then
            win:_AF_origSetWidth(lockW)
        else
            win:setWidth(lockW)
        end
        win.width = lockW
    end)

    if win.panel then
        win.panel._AF_charLockW = lockW
        if not win.panel._AF_origSetWidth then
            win.panel._AF_origSetWidth = win.panel.setWidth
            win.panel.setWidth = function(self, newWidth)
                local lw = self._AF_charLockW or L._lockW or newWidth
                if self._AF_origSetWidth then
                    self:_AF_origSetWidth(lw)
                end
                self.width = lw
            end
        end
        pcall(function()
            if win.panel._AF_origSetWidth then
                win.panel:_AF_origSetWidth(lockW)
            else
                win.panel:setWidth(lockW)
            end
            win.panel.width = lockW
        end)

        pcall(function()
            for _, item in ipairs(win.panel.viewList or {}) do
                if item and item.view then
                    local v = item.view
                    v._AF_charLockW = lockW
                    pcall(function()
                        if v.setWidth then v:setWidth(lockW) end
                        v.width = lockW
                    end)
                end
            end
        end)
    end
end

--- Hook setWidthAndParentWidth so Protection/Skills cannot widen the sheet.
function L.hookUIElement()
    if L._hookedUI then return end
    pcall(function() require "ISUI/ISUIElement" end)
    if not ISUIElement then
        dbg("ISUIElement missing — skip parent-width hook")
        return
    end
    if ISUIElement._AF_charLockHook then
        L._hookedUI = true
        return
    end
    local oldW = ISUIElement.setWidthAndParentWidth
    local oldH = ISUIElement.setHeightAndParentHeight
    if type(oldW) == "function" then
        ISUIElement.setWidthAndParentWidth = function(self, w)
            local lock = L.getLockWFor(self)
            if lock then
                -- width locked: set only this element; parent stays lockW
                pcall(function()
                    if self.setWidth then self:setWidth(lock) end
                    self.width = lock
                end)
                local p = self.parent
                local depth = 0
                while p and depth < 8 do
                    if p._AF_charLockW or p.Type == "ISCharacterInfoWindow" then
                        pcall(function()
                            local lw = p._AF_charLockW or lock
                            if p.setWidth then p:setWidth(lw) end
                            p.width = lw
                        end)
                        break
                    end
                    p = p.parent
                    depth = depth + 1
                end
                return
            end
            return oldW(self, w)
        end
    end
    -- Height: allow normal parent height updates (length can change)
    -- keep oldH as-is
    ISUIElement._AF_charLockHook = true
    L._hookedUI = true
    dbg("hooked setWidthAndParentWidth (height free)")
end

function L.enforce()
    L.hookUIElement()
    local win = getWin(0)
    if not win or not win.panel then return end
    if not L._lockW then
        L._lockW = L.computeLockW(win)
        dbg("lockW=" .. tostring(L._lockW))
    end
    L.applyToWindow(win, L._lockW)
end

function L.hookCharacterWindow()
    pcall(function() require "ISUI/ISCharacterInfoWindow" end)
    if not ISCharacterInfoWindow then return end
    if ISCharacterInfoWindow._AF_charLockPatch == "1" then return end
    ISCharacterInfoWindow._AF_charLockPatch = "1"

    local oldCreate = ISCharacterInfoWindow.createChildren
    ISCharacterInfoWindow.createChildren = function(self)
        if oldCreate then oldCreate(self) end
        pcall(function()
            L.hookUIElement()
            -- delay one tick so Protection/etc. finish first layout
            L._lockW = nil
            L.enforce()
        end)
    end

    local oldUpdate = ISCharacterInfoWindow.update
    if type(oldUpdate) == "function" then
        ISCharacterInfoWindow.update = function(self)
            oldUpdate(self)
            -- light enforce: if something widened us, snap back
            pcall(function()
                if not self._AF_charLockW then
                    L.enforce()
                    return
                end
                local w = self.width or (self.getWidth and self:getWidth())
                if w and math.abs(w - self._AF_charLockW) > 1 then
                    L.applyToWindow(self, self._AF_charLockW)
                end
            end)
        end
    end

    dbg("ISCharacterInfoWindow patched for fixed width")
end

function L.boot()
    L.hookUIElement()
    L.hookCharacterWindow()
    L.enforce()
end

Events.OnGameStart.Add(function()
    L.boot()
end)
Events.OnCreatePlayer.Add(function()
    L.boot()
end)
if Events.OnCreateUI then
    Events.OnCreateUI.Add(function()
        L.boot()
    end)
end

-- early
pcall(L.boot)

print("[AF] AF_CharWindowLock loaded")
