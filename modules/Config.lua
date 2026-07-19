return function(Core)
    local Config = {
        -- Aim Core
        AutoAimEnabled = false,
        ViewAngle = 100,
        Smoothing = 0.01,
        FocusPoint = "HumanoidRootPart",
        TrackingMethod = "Camera", -- "Mouse" or "Camera"
        TargetMode = "Both",       -- "Players", "NPCs", "Both"
        TeamCheck = true,
        WallCheck = true,
        -- Aim Advanced
        StickyTarget = true,         -- Lock target until dead/gone
        Prediction = false,          -- Lead moving targets
        PredictionScale = 0.08,      -- Velocity multiplier for lead
        PriorityMode = "Distance",   -- "Distance" | "LowHP" | "Closest3D"
        -- Features
        DiagnosticsEnabled = false,
        AutoRespawn = false,
        KillFeedEnabled = true,
        MaxKillFeed = 6,
        TargetInfoEnabled = true,
        RemoteLogEnabled = false,
        -- ESP
        ESPEnabled = false,
        ESPBoxes = true,
        ESPNames = true,
        ESPHealth = true,
        ESPDistance = true,
        ESPTracers = false,
        ESPMaxDist = 1000,         -- Max render distance in studs
        ESPTeamColor = true,       -- Color by team (green=ally, red=enemy)
        -- Target Nearest
        NearestTargetKey = Enum.KeyCode.T,  -- Keybind to snap to nearest
        -- Movement
        WalkSpeedEnabled = false,
        WalkSpeed = 16,
        JumpPowerEnabled = false,
        JumpPower = 50,
        InfiniteJumpEnabled = false,
        NoClipEnabled = false,
    }

    -- Deep merge utility for Game Presets
    function Config:Merge(overrideConfig)
        if type(overrideConfig) ~= "table" then return end
        
        local function deepMerge(t1, t2)
            for k, v in pairs(t2) do
                if type(v) == "table" and type(t1[k]) == "table" then
                    deepMerge(t1[k], v)
                else
                    t1[k] = v
                end
            end
        end
        
        deepMerge(self, overrideConfig)
    end

    return Config
end
