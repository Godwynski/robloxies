return function(Core)
    local State = {
        ActiveConnections = {},
        Running = true,
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
        },
    }
    return State
end
