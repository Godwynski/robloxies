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
        ESPCache = {},
        TeamData = {},
        TeamDataRaw = {},
        NPCCache = {},
        ActiveConnections = {}
    }
    return State
end
