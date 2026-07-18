return function(Core)
    local Preset = {}

    function Preset.Init()
        print("[General Preset] Initializing default settings.")
        
        -- No specific overrides needed for General, 
        -- it just relies on the default Config.lua and base Hook.lua
    end

    return Preset
end
