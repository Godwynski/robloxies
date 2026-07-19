return function(Core)
    local Preset = {}

    -- Provide configurations specific to this game
    Preset.ConfigOverrides = {}

    -- Optional: Set up custom event hooks or other logic
    function Preset.Init()
        print("[General Plugin] Initialized default settings.")
    end

    return Preset
end
