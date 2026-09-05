--[[ AF_CharWindowLock — DISABLED
  Former fixed-width lock on ISCharacterInfoWindow conflicted with other mods
  (global setWidth / setWidthAndParentWidth hooks).

  Window sizing is now handled only while the Achievements tab is active
  (see AF_AchievementsTab fitWindowToAchievements — Knox-style).
]]
AF = AF or {}
AF.CharLock = AF.CharLock or {}
local L = AF.CharLock
L.DISABLED = true

function L.boot() end
function L.enforce() end
function L.hookUIElement() end
function L.hookCharacterWindow() end
function L.applyToWindow() end
function L.computeLockW() return nil end

print("[AF] AF_CharWindowLock disabled (no global char window lock)")
