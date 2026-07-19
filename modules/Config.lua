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
        AimDeadzone = 0,             -- Radius in pixels where it stops tracking
        SmoothingStyle = "Linear",   -- "Linear" | "Exponential"
        StickyTarget = true,         -- Lock target until dead/gone
        Prediction = false,          -- Lead moving targets
        PredictionScale = 0.08,      -- Velocity multiplier for lead
        PriorityMode = "Distance",   -- "Distance" | "LowHP" | "Closest3D"
        AutoShoot = false,           -- Automatically click when aimed at target
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
        ESPChams = false,
        ESPMaxDist = 1000,         -- Max render distance in studs
        ESPTeamColor = true,       -- Color by team (green=ally, red=enemy)
        
        -- Keybinds
        MenuKey = Enum.KeyCode.RightShift,
        AimKey = Enum.KeyCode.CapsLock,
        NearestTargetKey = Enum.KeyCode.T,
        
        -- Movement
        WalkSpeedEnabled = false,
        WalkSpeed = 16,
        JumpPowerEnabled = false,
        JumpPower = 50,
        InfiniteJumpEnabled = false,
        NoClipEnabled = false,
    }

    local HttpService = game:GetService("HttpService")
    local fileName = "PureAutoAim_Config.json"

    function Config:Save()
        if type(writefile) ~= "function" then return false end
        local saveTable = {}
        for k, v in pairs(self) do
            if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                saveTable[k] = v
            elseif typeof(v) == "EnumItem" then
                saveTable[k] = {Type = "EnumItem", EnumType = tostring(v.EnumType), Name = v.Name}
            end
        end
        local ok, err = pcall(function()
            writefile(fileName, HttpService:JSONEncode(saveTable))
        end)
        return ok
    end

    function Config:Load()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local ok, data = pcall(function()
            if isfile(fileName) then
                return HttpService:JSONDecode(readfile(fileName))
            end
            return nil
        end)
        if not ok or type(data) ~= "table" then return false end

        for k, v in pairs(data) do
            if type(v) == "table" and v.Type == "EnumItem" then
                pcall(function()
                    self[k] = Enum[tostring(v.EnumType):split(".")[2] or v.EnumType][v.Name]
                end)
            else
                self[k] = v
            end
        end
        return true
    end

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
