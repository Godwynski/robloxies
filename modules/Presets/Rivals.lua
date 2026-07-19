return function(Core)
    local Preset = {}

    -- Provide configurations specific to this game
    Preset.ConfigOverrides = {
        AutoAimEnabled = true,
        FocusPoint = "Head",
        Prediction = true,
        PredictionScale = 0.135,
        WalkSpeedEnabled = false,
        TeamCheck = false,          -- Rivals doesn't use standard Roblox Teams
        TrackingMethod = "Mouse",   -- Fixes camera fighting custom FPS mechanics
    }

    -- Optional: Build game-specific UI tabs
    function Preset.BuildUITab(Window)
        local RivalsTab = Window:AddTab("Rivals")
        RivalsTab:AddSection("RIVALS SPECIFIC")
        
        RivalsTab:AddButton("Hello from Rivals Plugin!", function()
            print("Rivals plugin button clicked")
        end)
    end

    -- Optional: Set up custom event hooks or other logic
    function Preset.Init()
        print("[Rivals Plugin] Initialized!")
        -- Custom remote intercepting or ESP overrides would go here
    end

    return Preset
end
