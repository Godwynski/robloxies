return function(Core)
    local Config = {
        -- Master Switch
        MasterAutoFarmEnabled = false,

        -- Restaurant Core Automation
        AutoSeatEnabled = false,
        AutoOrderEnabled = false,
        AutoCookEnabled = false,
        AutoServeEnabled = false,
        AutoCleanEnabled = false,
        AutoCollectCashEnabled = false,
        AutoFarmEnabled = false,
        AutoDeliveryEnabled = false,
        AutoRestockEnabled = false,
        AutoClaimQuestsEnabled = true,
        AutoClaimRewardsEnabled = true,
        AutoExpandEnabled = false,
        AutoBuyEnabled = false,
        AutoPlaceEnabled = false,
        AutoHireStaffEnabled = false,
        AutoBuyStoves = true,
        AutoBuyTables = true,
        AutoBuyChairs = true,
        AutoBuyAppliances = true,
        AutoBuyFurniture = true,
        AutoPlaceTables = true,
        AutoPlaceChairs = true,
        AutoPlaceFurniture = true,
        VIPPriorityEnabled = true,
        InstantPromptEnabled = true,
        ActionDelay = 0.3,
        StationStayDelay = 0.22,
        StrictTaskCompletion = true,
        PostActionDelay = 0.18,
        MaxScanRadius = 120,

        -- Multi-Queue Pipeline & Concurrency
        ConcurrentExecutionEnabled = true,
        InterleavedPipelineEnabled = true,
        StationBatchSize = 3,
        RemotePromptBatching = true,

        -- Teleport & Navigation
        AutoTeleportEnabled = true,
        TeleportDelay = 0.15,
        PlotScopingEnabled = true,
        PreventSitting = true,
        MultiFloorSafeRaycast = true,

        -- AFK & Performance
        AntiAFKEnabled = true,
        AutoRejoinEnabled = false,
        GPUSaverEnabled = false,

        -- Movement Physics
        WalkSpeedEnabled = false,
        WalkSpeed = 16,
        JumpPowerEnabled = false,
        JumpPower = 50,
        InfiniteJumpEnabled = false,
        NoClipEnabled = false,

        -- UI & Themes
        Theme = "Violet",
        UISoundEnabled = false,

        -- Keybinds
        MenuKey = Enum.KeyCode.RightShift,
        ToggleNoClipKey = Enum.KeyCode.N,
        ToggleSpeedKey = Enum.KeyCode.None,
        ToggleJumpKey = Enum.KeyCode.None,
        ToggleInfJumpKey = Enum.KeyCode.None,
    }

    local HttpService = game:GetService("HttpService")
    local fileName = "Restaurant_Config.json"

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
        local ok, _ = pcall(function()
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
            if type(self[k]) ~= "function" then
                if type(v) == "table" and v.Type == "EnumItem" then
                    pcall(function()
                        local enumName = tostring(v.EnumType):gsub("^Enum%.", "")
                        if Enum[enumName] and Enum[enumName][v.Name] then
                            self[k] = Enum[enumName][v.Name]
                        end
                    end)
                else
                    self[k] = v
                end
            end
        end
        return true
    end

    return Config
end
