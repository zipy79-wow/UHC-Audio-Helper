local addonName, addonTable = ...

-- Default Settings
local defaults = {
    enabled = true,
    inCombat = false,       -- play even in combat
    outOfCombat = true,     -- play when out of combat
    onlyResting = false,    -- play ONLY when resting (overrides above if true)
    soundType = "builtin",  -- "builtin" or "custom"
    builtinSound = "QuestCompleted", -- Just an example sound
    customSoundPath = "Interface\\AddOns\\UHCSoundBites\\Sounds\\custom.ogg",
    fishingEnabled = true,   -- Enable volume boosting while fishing
    fishingVolumeBoost = true -- Maximize SFX volume and mute other sounds while fishing
}

-- Create the Options Panel
local optionsPanel = CreateFrame("Frame", "UHCSoundBitesOptionsPanel")
optionsPanel.name = "UHC Sound Bites"

-- Register options panel using the old InterfaceOptions_AddCategory API which is still present in Classic Era
-- Register options panel using the new Settings API
local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
    Settings.RegisterAddOnCategory(category)
else
    -- Fallback for extremely old clients
    InterfaceOptions_AddCategory(optionsPanel)
end

-- Function to setup the UI elements in the panel
optionsPanel:SetScript("OnShow", function(self)
    -- Prevent setting up multiple times
    if self.setup then return end
    self.setup = true

    local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("UHC Sound Bites - Settings")

    local function createCheckbutton(parent, name, label, tooltip, dbKey, yOffset)
        local cb = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, yOffset)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb.tooltipText = tooltip

        cb:SetChecked(UHCSoundBitesDB[dbKey])
        cb:SetScript("OnClick", function(self)
            UHCSoundBitesDB[dbKey] = self:GetChecked()
        end)

        return cb
    end

    local enabledCb = createCheckbutton(self, "UHCSBEnalbedCB", "Enable Addon", "Toggle the addon on or off.", "enabled", -50)
    local outOfCombatCb = createCheckbutton(self, "UHCSBOutOfCombatCB", "Play Out of Combat", "Play sound when you reach full HP out of combat.", "outOfCombat", -80)
    local inCombatCb = createCheckbutton(self, "UHCSBInCombatCB", "Play In Combat", "Play sound when you reach full HP during combat.", "inCombat", -110)
    local onlyRestingCb = createCheckbutton(self, "UHCSBOnlyRestingCB", "Play ONLY while Resting", "If checked, the sound will ONLY play if you are in a rested state.", "onlyResting", -140)

    local fishingEnabledCb = createCheckbutton(self, "UHCSBFishingEnabledCB", "Enable Fishing Alerts", "Enable features for fishing.", "fishingEnabled", -170)
    local fishingVolumeBoostCb = createCheckbutton(self, "UHCSBFishingVolumeBoostCB", "Boost Fishing Volume", "Maximize SFX volume and mute music/ambience/dialog while fishing.", "fishingVolumeBoost", -200)

    local fishingLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fishingLabel:SetPoint("TOPLEFT", 16, -230)
    fishingLabel:SetWidth(400)
    fishingLabel:SetJustifyH("LEFT")
    fishingLabel:SetText("Note: To replace the bobber splash sound, place a file named 'FishingBobber_ver2_1.ogg' (and versions 2 and 3) in your 'World of Warcraft\\_classic_\\Sound\\Spells\\' directory and restart the game.")

    -- Sound Type Dropdown / Radio Buttons
    local soundTypeLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundTypeLabel:SetPoint("TOPLEFT", 16, -280)
    soundTypeLabel:SetText("Sound Source:")

    local builtinCb = CreateFrame("CheckButton", "UHCSBBuiltinCB", self, "UIRadioButtonTemplate")
    builtinCb:SetPoint("TOPLEFT", 120, -275)
    _G[builtinCb:GetName() .. "Text"]:SetText("Built-in")

    local customCb = CreateFrame("CheckButton", "UHCSBCustomCB", self, "UIRadioButtonTemplate")
    customCb:SetPoint("TOPLEFT", 220, -275)
    _G[customCb:GetName() .. "Text"]:SetText("Custom File")

    builtinCb:SetChecked(UHCSoundBitesDB.soundType == "builtin")
    customCb:SetChecked(UHCSoundBitesDB.soundType == "custom")

    builtinCb:SetScript("OnClick", function(self)
        UHCSoundBitesDB.soundType = "builtin"
        self:SetChecked(true)
        customCb:SetChecked(false)
    end)
    customCb:SetScript("OnClick", function(self)
        UHCSoundBitesDB.soundType = "custom"
        self:SetChecked(true)
        builtinCb:SetChecked(false)
    end)

    -- Custom Sound EditBox
    local customSoundEditBox = CreateFrame("EditBox", "UHCSBCustomEditBox", self, "InputBoxTemplate")
    customSoundEditBox:SetSize(300, 20)
    customSoundEditBox:SetPoint("TOPLEFT", 16, -320)
    customSoundEditBox:SetAutoFocus(false)
    customSoundEditBox:SetText(UHCSoundBitesDB.customSoundPath)

    local customSoundLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    customSoundLabel:SetPoint("BOTTOMLEFT", customSoundEditBox, "TOPLEFT", 0, 2)
    customSoundLabel:SetText("Custom Sound File Path (e.g. Interface\\AddOns\\UHCSoundBites\\Sounds\\custom.ogg):")

    customSoundEditBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            UHCSoundBitesDB.customSoundPath = self:GetText()
        end
    end)

    -- Test Button
    local testButton = CreateFrame("Button", "UHCSBTestButton", self, "UIPanelButtonTemplate")
    testButton:SetSize(100, 22)
    testButton:SetPoint("TOPLEFT", 16, -360)
    testButton:SetText("Test Sound")
    testButton:SetScript("OnClick", function()
        if UHCSoundBitesDB.soundType == "builtin" then
            PlaySound(618) -- Quest completed
        else
            PlaySoundFile(UHCSoundBitesDB.customSoundPath)
        end
    end)
end)

-- Initialize Settings on Load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not UHCSoundBitesDB then
            UHCSoundBitesDB = defaults
        else
            -- Ensure all default keys exist (in case of updates)
            for k, v in pairs(defaults) do
                if UHCSoundBitesDB[k] == nil then
                    UHCSoundBitesDB[k] = v
                end
            end
        end
        addonTable.db = UHCSoundBitesDB
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash Command
SLASH_UHCSOUNDBITES1 = "/uhc"
SlashCmdList["UHCSOUNDBITES"] = function(msg)
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel) -- Calling it twice forces it to expand correctly
    end
end
