return function(Core)
    local Restaurant = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer

    -- Helper: Fire or trigger a ProximityPrompt safely
    local function triggerPrompt(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        
        -- Custom executor fireproximityprompt if supported
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function()
                fireproximityprompt(prompt, 0)
            end)
            if ok then return true end
        end

        -- Fallback: Zero hold duration
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
        end)
        return true
    end

    -- Hook newly created ProximityPrompts for instant interaction
    local function setupPromptHook()
        Utility.RegisterConnection(workspace.DescendantAdded:Connect(function(desc)
            if Config.InstantPromptEnabled and desc:IsA("ProximityPrompt") then
                pcall(function()
                    desc.HoldDuration = 0
                    desc.RequiresLineOfSight = false
                end)
            end
        end))

        -- Apply to existing prompts
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                pcall(function()
                    if Config.InstantPromptEnabled then
                        desc.HoldDuration = 0
                        desc.RequiresLineOfSight = false
                    end
                end)
            end
        end
    end

    -- Scan workspace for matching prompts by action text, name, or object type
    local function scanAndTrigger(keywords)
        local count = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local action = (obj.ActionText or ""):lower()
                local name = (obj.ObjectText or obj.Name or ""):lower()
                local parentName = (obj.Parent and obj.Parent.Name or ""):lower()

                for _, kw in ipairs(keywords) do
                    kw = kw:lower()
                    if action:find(kw, 1, true) or name:find(kw, 1, true) or parentName:find(kw, 1, true) then
                        triggerPrompt(obj)
                        count = count + 1
                        break
                    end
                end
            end
        end
        return count
    end

    -- Specific Workflow Handlers
    function Restaurant.HandleSeating()
        if not Config.AutoSeatEnabled then return end
        scanAndTrigger({"seat", "customer", "lead", "table", "chair", "welcome", "host"})
    end

    function Restaurant.HandleOrdering()
        if not Config.AutoOrderEnabled then return end
        scanAndTrigger({"order", "take order", "menu", "ask"})
    end

    function Restaurant.HandleCooking()
        if not Config.AutoCookEnabled then return end
        scanAndTrigger({"cook", "prepare", "bake", "fry", "stove", "grill", "oven", "pot", "pan"})
    end

    function Restaurant.HandleServing()
        if not Config.AutoServeEnabled then return end
        scanAndTrigger({"serve", "deliver", "dish", "plate", "food", "tray"})
    end

    function Restaurant.HandleCleaning()
        if not Config.AutoCleanEnabled then return end
        scanAndTrigger({"clean", "dirty", "trash", "wash", "clear", "wipe", "sink"})
    end

    function Restaurant.HandleCashCollection()
        if not Config.AutoCollectCashEnabled then return end
        -- Check for cash prompts
        scanAndTrigger({"cash", "coin", "tip", "bill", "pay", "collect", "register", "money"})

        -- Also check for dropped touch-interest coins / cash parts in workspace
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and Config.AutoCollectCashEnabled then
            for _, item in ipairs(workspace:GetChildren()) do
                local name = item.Name:lower()
                if (name:find("coin") or name:find("cash") or name:find("money") or name:find("tip")) and item:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(root, item, 0)
                        task.wait()
                        firetouchinterest(root, item, 1)
                    end)
                end
            end
        end
    end

    -- Main automation loop running safely in the background
    local runningLoop = false
    function Restaurant.StartLoop()
        if runningLoop then return end
        runningLoop = true

        task.spawn(function()
            while Core.State.Running and runningLoop do
                local delayTime = math.clamp(Config.ActionDelay or 0.3, 0.05, 5)

                if Config.AutoSeatEnabled then
                    pcall(Restaurant.HandleSeating)
                end
                if Config.AutoOrderEnabled then
                    pcall(Restaurant.HandleOrdering)
                end
                if Config.AutoCookEnabled then
                    pcall(Restaurant.HandleCooking)
                end
                if Config.AutoServeEnabled then
                    pcall(Restaurant.HandleServing)
                end
                if Config.AutoCleanEnabled then
                    pcall(Restaurant.HandleCleaning)
                end
                if Config.AutoCollectCashEnabled then
                    pcall(Restaurant.HandleCashCollection)
                end

                task.wait(delayTime)
            end
            runningLoop = false
        end)
    end

    function Restaurant.Init()
        setupPromptHook()
        Restaurant.StartLoop()
        print("🍽️ Restaurant automation module initialized.")
    end

    function Restaurant.Cleanup()
        runningLoop = false
    end

    return Restaurant
end
