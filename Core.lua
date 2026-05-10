local addonName, addonTable = ...

function addonTable.SanitizePath(path)
    if not path or type(path) ~= "string" or path == "" then
        return "Interface\\AddOns\\UHCSoundBites\\Sounds\\custom.ogg"
    end

    -- Normalize slashes
    local sanitized = path:gsub("/", "\\")

    -- Remove any directory traversal sequences
    while sanitized:find("%.%.") do
        sanitized = sanitized:gsub("%.%.", "")
    end

    -- Ensure it starts with Interface\AddOns\ (case-insensitive)
    if not sanitized:lower():find("^interface\\addons\\") then
        return "Interface\\AddOns\\UHCSoundBites\\Sounds\\custom.ogg"
    end

    return sanitized
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

local wasFullHealth = true
local inCombat = false
local isResting = false

local isFishing = false
local savedVolumes = {}

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
        PlaySoundFile(addonTable.SanitizePath(UHCSoundBitesDB.customSoundPath))
    end
end

local function RestoreVolumes()
    if isFishing and savedVolumes.master then
        SetCVar("Sound_MasterVolume", savedVolumes.master)
        SetCVar("Sound_SFXVolume", savedVolumes.sfx)
        SetCVar("Sound_MusicVolume", savedVolumes.music)
        SetCVar("Sound_AmbienceVolume", savedVolumes.ambience)
        SetCVar("Sound_DialogVolume", savedVolumes.dialog)
        isFishing = false
    end
end

local function MaximizeFishingVolumes()
    if not isFishing then
        savedVolumes.master = GetCVar("Sound_MasterVolume")
        savedVolumes.sfx = GetCVar("Sound_SFXVolume")
        savedVolumes.music = GetCVar("Sound_MusicVolume")
        savedVolumes.ambience = GetCVar("Sound_AmbienceVolume")
        savedVolumes.dialog = GetCVar("Sound_DialogVolume")

        SetCVar("Sound_MasterVolume", UHCSoundBitesDB.fishingSFXVolume)
        SetCVar("Sound_SFXVolume", UHCSoundBitesDB.fishingSFXVolume)
        SetCVar("Sound_MusicVolume", UHCSoundBitesDB.fishingBackgroundVolume)
        SetCVar("Sound_AmbienceVolume", UHCSoundBitesDB.fishingBackgroundVolume)
        SetCVar("Sound_DialogVolume", UHCSoundBitesDB.fishingBackgroundVolume)
        isFishing = true
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
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, castGUID, spellID = ...
        if unit == "player" then
            -- Fishing spell IDs (Common is 7620, but can be others depending on skill/items)
            local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or GetSpellInfo(spellID)
            if spellName == "Fishing" then
                if UHCSoundBitesDB.fishingEnabled then
                    MaximizeFishingVolumes()
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if unit == "player" and isFishing then
            RestoreVolumes()
        end
    end
end)
