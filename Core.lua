local addonName, addonTable = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")

local wasFullHealth = true
local inCombat = false
local isResting = false

local function PlayNotificationSound()
    if not UHCSoundBitesDB.enabled then return end

    -- Check resting condition
    if UHCSoundBitesDB.onlyResting and not isResting then return end

    -- Check combat conditions (only evaluated if onlyResting is false, or if we are resting)
    if not UHCSoundBitesDB.onlyResting then
        if inCombat and not UHCSoundBitesDB.inCombat then return end
        if not inCombat and not UHCSoundBitesDB.outOfCombat then return end
    end

    -- Play sound
    if UHCSoundBitesDB.soundType == "builtin" then
        PlaySound(618) -- Quest Complete
    else
        PlaySoundFile(UHCSoundBitesDB.customSoundPath)
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        inCombat = InCombatLockdown()
        isResting = IsResting()
    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit == "player" then
            local currentHealth = UnitHealth("player")
            local maxHealth = UnitHealthMax("player")

            local isFullHealth = currentHealth >= maxHealth

            -- Only trigger when we transition from NOT full health to FULL health
            if isFullHealth and not wasFullHealth then
                PlayNotificationSound()
            end

            wasFullHealth = isFullHealth
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "PLAYER_UPDATE_RESTING" then
        isResting = IsResting()
    end
end)
