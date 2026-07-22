return function(Core)
    local State = {
        LockedTarget = nil,
        LockedCharacter = nil,
        KillFeedEntries = {},
        RemoteLog = {},
        DeathTime = 0,
        IsAlive = true,
        HitMarkerTime = 0,
        KillCount = 0,
        DeathCount = 0,
        AssistCount = 0,
        AimState = "Disabled",
        CurrentTarget = nil,
        ESPCache = setmetatable({}, {__mode = "k"}),
        TeamData = {},
        TeamDataRaw = {},
        NPCCache = {},
        ActiveConnections = {},
        Running = true, -- Set to false by Terminate() to stop all background loops
    }
    return State
end
