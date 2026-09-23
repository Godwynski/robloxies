return function(Core)
    local State = {
        ActiveConnections = {},
        InFlightTasks = setmetatable({}, {__mode = "k"}),
        Running = true,
        StartTime = tick(),
        Stats = {
            CustomersSeated = 0,
            OrdersTaken = 0,
            DishesCooked = 0,
            DishesServed = 0,
            TablesCleaned = 0,
            CashCollected = 0,
            CropsHarvested = 0,
            DeliveriesCompleted = 0,
            StorageRestocked = 0,
            QuestsClaimed = 0,
            RewardsClaimed = 0,
            ExpansionsPurchased = 0,
            ItemsPurchased = 0,
            ItemsPlaced = 0,
            StaffHired = 0,
        },
    }
    return State
end
