return function(Core, loadModuleFunc)
    local PlaceId = game.PlaceId
    
    -- Mapping of game/place IDs to preset names
    local Games = {
        [126042865144779] = "Rivals", -- From diagnostics
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
        -- Fallback to General
        return loadModuleFunc("Presets/General.lua")(Core)
    end
end
