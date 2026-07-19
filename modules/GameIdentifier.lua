return function(Core, loadModuleFunc)
    local PlaceId = game.PlaceId
    
    -- Mapping of game/place IDs to preset names
    local Games = {
        [126042865144779] = "Rivals", -- From diagnostics
        [71874690745115] = "Rivals",  -- Real Rivals PlaceID from updated scan
        [17621415041] = "Rivals",     -- Known Rivals place ID
        [17373859664] = "Rivals",     -- Another known Rivals place ID
    }
    
    local PresetName = Games[PlaceId] or "General"
    print("[GameIdentifier] Identified preset for PlaceId " .. tostring(PlaceId) .. ": " .. PresetName)
    
    local success, presetFn = pcall(function()
        return loadModuleFunc("Presets/" .. PresetName .. ".lua")
    end)
    
    if success and type(presetFn) == "function" then
        return presetFn(Core)
    else
        warn("[GameIdentifier] Failed to load preset:", PresetName, "| Error:", tostring(presetFn))

        -- Fix #18: wrap the General fallback in its own pcall so a network failure
        -- doesn't leave the user with no UI at all
        if PresetName ~= "General" then
            local fbSuccess, fbResult = pcall(function()
                return loadModuleFunc("Presets/General.lua")
            end)
            if fbSuccess and type(fbResult) == "function" then
                return fbResult(Core)
            else
                warn("[GameIdentifier] General preset fallback also failed:", tostring(fbResult))
            end
        end

        -- Last resort: return a minimal no-op preset so the rest of init can continue
        return { Init = function() warn("[GameIdentifier] Running with no preset.") end }
    end
end
