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
    }
    return Config
end
