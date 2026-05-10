-- Mocks for WoW API
_G = _G or {}
local mockFrames = {}

function CreateFrame(frameType, name, parent, template)
    local frame = {
        type = frameType,
        name = name,
        parent = parent,
        template = template,
        scripts = {},
        fontStrings = {},
        points = {},
        shown = false,
        size = {},
        value = 0,
        checked = false,
        text = ""
    }

    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        table.insert(self.points, {point=point, relativeTo=relativeTo, relativePoint=relativePoint, x=x, y=y})
    end

    function frame:SetScript(handler, func)
        self.scripts[handler] = func
    end

    function frame:RegisterEvent(event)
        self.registeredEvent = event
    end

    function frame:UnregisterEvent(event)
        self.unregisteredEvent = event
    end

    function frame:CreateFontString(name, layer, template)
        local fs = {
            name = name,
            layer = layer,
            template = template,
            text = "",
            points = {},
            SetPoint = function(fsSelf, point, rel, relPoint, x, y) table.insert(fsSelf.points, {point=point, rel=rel, relPoint=relPoint, x=x, y=y}) end,
            SetText = function(fsSelf, t) fsSelf.text = t end,
            SetWidth = function(fsSelf, w) fsSelf.width = w end,
            SetJustifyH = function(fsSelf, j) fsSelf.justifyH = j end
        }
        table.insert(self.fontStrings, fs)
        return fs
    end

    function frame:GetName()
        return self.name or "UnnamedFrame"
    end

    function frame:SetChecked(checked)
        self.checked = checked
    end

    function frame:GetChecked()
        return self.checked
    end

    function frame:SetMinMaxValues(min, max)
        self.min = min
        self.max = max
    end

    function frame:SetValueStep(step)
        self.step = step
    end

    function frame:SetObeyStepOnDrag(obey)
        self.obeyStep = obey
    end

    function frame:SetValue(val)
        self.value = val
    end

    function frame:GetValue()
        return self.value
    end

    function frame:SetSize(w, h)
        self.size = {w=w, h=h}
    end

    function frame:SetAutoFocus(af)
        self.autoFocus = af
    end

    function frame:SetText(txt)
        self.text = txt
    end

    function frame:GetText()
        return self.text
    end

    if name then
        _G[name] = frame
        _G[name.."Text"] = { SetText = function(self, t) self.text = t end }
        _G[name.."Low"] = { SetText = function(self, t) self.text = t end }
        _G[name.."High"] = { SetText = function(self, t) self.text = t end }
    end

    table.insert(mockFrames, frame)
    return frame
end

Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        frame.categoryRegistered = true
        frame.categoryName = name
        return { GetID = function() return 123 end }
    end,
    RegisterAddOnCategory = function(category)
        Settings.addonCategoryRegistered = true
    end,
    OpenToCategory = function(id)
        Settings.openedCategory = id
    end
}

InterfaceOptions_AddCategory = function(frame)
    frame.interfaceOptionsRegistered = true
end

InterfaceOptionsFrame_OpenToCategory = function(frame)
    frame.opened = true
end

PlaySound = function(id)
    _G.lastSoundPlayed = id
end

PlaySoundFile = function(path)
    _G.lastSoundFilePlayed = path
end

SlashCmdList = {}

-- Reset globals between tests
local function resetMocks()
    UHCSoundBitesDB = nil
    mockFrames = {}
    _G.lastSoundPlayed = nil
    _G.lastSoundFilePlayed = nil
    Settings.addonCategoryRegistered = false
    Settings.openedCategory = nil
end

-- Test Runner
local passed = 0
local failed = 0

local function runTest(name, testFunc)
    resetMocks()

    -- Load the file to test
    -- Lua 5.1/5.3 compatible loadfile
    local f, err = loadfile("Options.lua")
    if not f then
        print("❌ [" .. name .. "] Failed to load Options.lua: " .. err)
        failed = failed + 1
        return
    end

    -- Execute to setup the environment
    local success, err = pcall(f, "UHCSoundBites", {})
    if not success then
        print("❌ [" .. name .. "] Error executing Options.lua: " .. err)
        failed = failed + 1
        return
    end

    local ok, errorMsg = pcall(testFunc)
    if ok then
        print("✅ [" .. name .. "] Passed")
        passed = passed + 1
    else
        print("❌ [" .. name .. "] Failed: " .. tostring(errorMsg))
        failed = failed + 1
    end
end

-- Test Cases

runTest("Registers options panel", function()
    local panel = _G["UHCSoundBitesOptionsPanel"]
    assert(panel ~= nil, "Options panel frame should be created")
    assert(panel.categoryRegistered == true, "Should register using Settings API")
end)

runTest("Initializes Default Settings on ADDON_LOADED", function()
    -- Find the event frame
    local eventFrame
    for _, frame in ipairs(mockFrames) do
        if frame.registeredEvent == "ADDON_LOADED" then
            eventFrame = frame
            break
        end
    end

    assert(eventFrame ~= nil, "Should create a frame to listen to ADDON_LOADED")
    assert(eventFrame.scripts["OnEvent"] ~= nil, "Should have OnEvent script")

    -- Trigger event
    eventFrame.scripts["OnEvent"](eventFrame, "ADDON_LOADED", "UHCSoundBites")

    assert(UHCSoundBitesDB ~= nil, "UHCSoundBitesDB should be initialized")
    assert(UHCSoundBitesDB.enabled == true, "Default 'enabled' should be true")
    assert(UHCSoundBitesDB.soundType == "builtin", "Default 'soundType' should be builtin")
end)








runTest("Creates UI Elements on Show", function()
    local panel = _G["UHCSoundBitesOptionsPanel"]
    assert(panel.scripts["OnShow"] ~= nil, "Panel should have OnShow script")

    -- Initialize DB for UI creation
    UHCSoundBitesDB = {
        enabled = true,
        outOfCombat = true,
        inCombat = false,
        onlyResting = false,
        fishingEnabled = true,
        fishingSFXVolume = 1.0,
        fishingBackgroundVolume = 0.1,
        soundType = "builtin",
        customSoundPath = ""
    }

    -- Trigger OnShow to build UI
    panel.scripts["OnShow"](panel)

    -- Verify check buttons were created
    assert(_G["UHCSBEnalbedCB"] ~= nil, "Enable CheckButton should be created")
    assert(_G["UHCSBOutOfCombatCB"] ~= nil, "OutOfCombat CheckButton should be created")

    -- Verify sliders
    assert(_G["UHCSBFishingSFXSlider"] ~= nil, "Fishing SFX Slider should be created")
end)

runTest("Interacting with CheckButtons updates DB", function()
    local panel = _G["UHCSoundBitesOptionsPanel"]

    -- Initialize DB
    UHCSoundBitesDB = {
        enabled = true,
        outOfCombat = true,
        inCombat = false,
        onlyResting = false,
        fishingEnabled = true,
        fishingSFXVolume = 1.0,
        fishingBackgroundVolume = 0.1,
        soundType = "builtin",
        customSoundPath = ""
    }

    panel.scripts["OnShow"](panel)

    local cb = _G["UHCSBEnalbedCB"]
    assert(cb.scripts["OnClick"] ~= nil, "CheckButton should have OnClick script")

    -- Simulate unchecking
    cb:SetChecked(false)
    cb.scripts["OnClick"](cb)

    assert(UHCSoundBitesDB.enabled == false, "DB should update when CheckButton is clicked")
end)

runTest("Test Sound Button Plays Correct Sound", function()
    local panel = _G["UHCSoundBitesOptionsPanel"]
    UHCSoundBitesDB = {
        enabled = true,
        outOfCombat = true,
        inCombat = false,
        onlyResting = false,
        fishingEnabled = true,
        fishingSFXVolume = 1.0,
        fishingBackgroundVolume = 0.1,
        soundType = "builtin",
        customSoundPath = "custom.ogg"
    }
    panel.scripts["OnShow"](panel)

    local testBtn = _G["UHCSBTestButton"]

    -- Test builtin
    testBtn.scripts["OnClick"](testBtn)
    assert(_G.lastSoundPlayed == 618, "Should play sound 618")
    assert(_G.lastSoundFilePlayed == nil, "Should not play sound file")

    _G.lastSoundPlayed = nil

    -- Test custom
    UHCSoundBitesDB.soundType = "custom"
    testBtn.scripts["OnClick"](testBtn)
    assert(_G.lastSoundFilePlayed == "custom.ogg", "Should play custom sound file")
end)

runTest("Slash Command opens options", function()
    assert(SLASH_UHCSOUNDBITES1 == "/uhc", "Should register slash command")
    assert(SlashCmdList["UHCSOUNDBITES"] ~= nil, "Should register handler")

    SlashCmdList["UHCSOUNDBITES"]()

    assert(Settings.openedCategory == 123, "Should open using Settings API")
end)





print(string.format("\nTests completed: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
