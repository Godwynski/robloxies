return function(Core, loadModuleFunc)
    local PlaceId = game.PlaceId
    
    local Games = {
        [126042865144779] = "Rivals",
        [71874690745115] = "Rivals",
        [17621415041] = "Rivals",
        [17373859664] = "Rivals",
    }
    
    local PresetName = Games[PlaceId] or "General"
    print("[GameIdentifier] Identified preset for PlaceId " .. tostring(PlaceId) .. ": " .. PresetName)
    
    local function loadPreset(name)
        local success, presetPlugin = pcall(function()
            return loadModuleFunc("Presets/" .. name .. ".lua")
        end)
        
        if success and type(presetPlugin) == "function" then
            local Plugin = presetPlugin(Core)
            
            -- Merge Configurations
            if Plugin.ConfigOverrides then
                Core.Config:Merge(Plugin.ConfigOverrides)
            end
            
            -- Inject Custom UI
            if Plugin.BuildUITab and Core.UI and Core.UI.Window then
                Plugin.BuildUITab(Core.UI.Window)
            end
            
            -- Initialize Custom Logic / Event Hooks
            if Plugin.Init then
                Plugin.Init()
            end
            
            return Plugin
        end
        return nil
    end

    local Plugin = loadPreset(PresetName)
    if not Plugin then
        warn("[GameIdentifier] Failed to load preset:", PresetName)
        if PresetName ~= "General" then
            Plugin = loadPreset("General")
            if not Plugin then
                warn("[GameIdentifier] General preset fallback also failed.")
            end
        end
    end
    
    return Plugin
end
