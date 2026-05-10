local assert = require("luassert")

describe("Core.lua Testing", function()
    local mockFrame
    local eventHandler
    local cvarHistory
    local setCVarCalls

    before_each(function()
        -- Reset state
        cvarHistory = {
            Sound_MasterVolume = "0.5",
            Sound_SFXVolume = "0.5",
            Sound_MusicVolume = "0.5",
            Sound_AmbienceVolume = "0.5",
            Sound_DialogVolume = "0.5",
        }
        setCVarCalls = {}

        -- Mock WoW Global DB
        _G.UHCSoundBitesDB = {
            enabled = true,
            fishingEnabled = true,
            fishingSFXVolume = "1.0",
            fishingBackgroundVolume = "0.1"
        }

        -- Mock Frame API
        mockFrame = {
            RegisterEvent = function(self, event) end,
            SetScript = function(self, scriptType, handler)
                if scriptType == "OnEvent" then
                    eventHandler = handler
                end
            end
        }
        _G.CreateFrame = function() return mockFrame end

        -- Mock GetCVar and SetCVar
        _G.GetCVar = function(cvar)
            return cvarHistory[cvar]
        end
        _G.SetCVar = function(cvar, value)
            cvarHistory[cvar] = value
            table.insert(setCVarCalls, {cvar = cvar, value = value})
        end

        -- Mock other WoW globals
        _G.InCombatLockdown = function() return false end
        _G.IsResting = function() return false end
        _G.GetSpellInfo = function(id) return "Fishing" end
        _G.C_Spell = { GetSpellName = function(id) return "Fishing" end }

        -- Need to simulate `...` (addonName, addonTable) for loading the file
        local function loadAddon()
            local chunk = assert(loadfile("Core.lua"))
            -- Lua 5.1/5.2 setfenv trick or pass args if chunk takes them.
            -- In Lua 5.3+ (which we installed), loadfile doesn't use setfenv
            -- Core.lua expects `...` to have addonName, addonTable
            chunk("UHCSoundBites", {})
        end
        loadAddon()
    end)

    it("should capture the event handler", function()
        assert.is_not_nil(eventHandler)
        assert.is_function(eventHandler)
    end)

    it("RestoreVolumes should correctly restore saved volumes after fishing stops", function()
        -- 1. Simulate starting to fish to save the original volumes
        -- When this happens, MaximizeFishingVolumes is called.
        eventHandler(mockFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "some_guid", 7620)

        -- Verify SetCVar was called to change the volumes to fishing volumes
        assert.is_true(#setCVarCalls > 0)

        -- Reset calls to cleanly track RestoreVolumes behavior
        setCVarCalls = {}

        -- 2. Simulate stopping fishing
        -- This triggers RestoreVolumes
        eventHandler(mockFrame, "UNIT_SPELLCAST_CHANNEL_STOP", "player")

        -- 3. Verify RestoreVolumes behavior
        -- Should have called SetCVar 5 times
        assert.are.equal(5, #setCVarCalls)

        -- We'll check that the values restored match the original values returned by GetCVar
        -- which we set up in our before_each to be "0.5" for all
        local restoredVolumes = {}
        for _, call in ipairs(setCVarCalls) do
            restoredVolumes[call.cvar] = call.value
        end

        assert.are.equal("0.5", restoredVolumes["Sound_MasterVolume"])
        assert.are.equal("0.5", restoredVolumes["Sound_SFXVolume"])
        assert.are.equal("0.5", restoredVolumes["Sound_MusicVolume"])
        assert.are.equal("0.5", restoredVolumes["Sound_AmbienceVolume"])
        assert.are.equal("0.5", restoredVolumes["Sound_DialogVolume"])
    end)
end)