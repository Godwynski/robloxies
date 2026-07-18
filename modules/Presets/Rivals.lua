return function(Core)
    local Preset = {}

    function Preset.Init()
        print("[Rivals Preset] Initializing...")
        
        -- Override specific configs for Rivals
        Core.Config.AutoAimEnabled = true
        Core.Config.FocusPoint = "Head"
        Core.Config.Prediction = true
        Core.Config.PredictionScale = 0.135
        Core.Config.WalkSpeedEnabled = false
        
        -- Rivals specific fixes based on mechanics:
        Core.Config.TeamCheck = false -- Rivals doesn't use standard Roblox Teams
        Core.Config.TrackingMethod = "Mouse" -- Fixes camera fighting custom FPS mechanics
        
        -- You could also apply custom Rivals logic here
        -- e.g., overriding how the ESP reads names, or intercepting Rivals remotes.
        
        -- Example of injecting custom hook logic if needed in the future:
        --[[
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" and self.Name == "WeaponMessage" then
                -- Intercept and modify RemoteEvent for Rivals
            end
            
            return oldNamecall(self, ...)
        end)
        ]]--
    end

    return Preset
end
