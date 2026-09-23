return function(Core)
    local State = {
        ActiveConnections = {},
        InFlightTasks = setmetatable({}, {__mode = "k"}),
        Running = true,
        StartTime = tick(),
        HoldingType = "None", -- "DirtyDishes", "Food", "None"
        HoldingCount = 0,
        HandsFull = false,
        HandsFullUntil = 0,
        SinksFull = false,
        SinksFullUntil = 0,
        InteractionBlockedUntil = 0,
        ActivePrompt = nil,
        LastActionType = nil,
        ExpansionQuestLocked = false,
        ExpansionQuestLockedUntil = 0,
        ExpansionLockReason = nil,
        BlockedCategories = {}, -- e.g. { Cook = timestamp, Seat = timestamp, Serve = timestamp }
        ActiveGoal = {
            Title = "None",
            Objective = "Monitoring...",
            Progress = "0%",
            Category = "None",
            TargetItem = nil,
            TargetRole = nil,
        },
        Stats = {
            CustomersSeated = 0,
            OrdersTaken = 0,
            DishesCooked = 0,
            DishesServed = 0,
            TablesCleaned = 0,
            DishesWashed = 0,
            CashCollected = 0,
            CropsHarvested = 0,
            DeliveriesCompleted = 0,
            StorageRestocked = 0,
            QuestsClaimed = 0,
            QuestsCompleted = 0,
            RewardsClaimed = 0,
            ExpansionsPurchased = 0,
            ItemsPurchased = 0,
            ItemsPlaced = 0,
            StaffHired = 0,
        },
    }
    return State
end
