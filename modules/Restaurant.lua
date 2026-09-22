return function(Core)
    local Restaurant = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer

    -- Cached reference to player's restaurant/farm plot
    local cachedPlot = nil
    local lastPlotSearch = 0

    -- Helper: Locate the LocalPlayer's designated restaurant/farm plot
    function Restaurant.GetPlayerPlot()
        if not Config.PlotScopingEnabled then return workspace end
        local now = os.clock()
        if cachedPlot and cachedPlot.Parent and (now - lastPlotSearch < 10) then
            return cachedPlot
        end
        lastPlotSearch = now

        local playerName = LocalPlayer.Name:lower()
        local displayName = LocalPlayer.DisplayName:lower()
        local userId = tostring(LocalPlayer.UserId)

        -- Search common plot containers
        local searchContainers = {
            workspace:FindFirstChild("Plots"),
            workspace:FindFirstChild("Restaurants"),
            workspace:FindFirstChild("Tycoons"),
            workspace:FindFirstChild("Farms"),
            workspace
        }

        for _, container in ipairs(searchContainers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Model") or item:IsA("Folder") then
                        -- Check Owner value or attribute
                        local ownerObj = item:FindFirstChild("Owner") or item:FindFirstChild("Player") or item:FindFirstChild("OwnerId")
                        if ownerObj then
                            local val = tostring(ownerObj.Value):lower()
                            if val == playerName or val == userId or val == displayName then
                                cachedPlot = item
                                return item
                            end
                        end
                        if item:GetAttribute("Owner") == LocalPlayer.UserId or tostring(item:GetAttribute("Owner")):lower() == playerName then
                            cachedPlot = item
                            return item
                        end

                        -- Check item name or billboard
                        local itemName = item.Name:lower()
                        if itemName:find(playerName, 1, true) or itemName:find(userId, 1, true) then
                            cachedPlot = item
                            return item
                        end

                        for _, desc in ipairs(item:GetDescendants()) do
                            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                local txt = (desc.Text or ""):lower()
                                if (txt:find(playerName, 1, true) or txt:find(displayName, 1, true)) and (txt:find("restaurant", 1, true) or txt:find("plot", 1, true) or txt:find("farm", 1, true)) then
                                    cachedPlot = item
                                    return item
                                end
                            end
                        end
                    end
                end
            end
        end

        return workspace
    end

    -- Helper: Extract world position from an instance (Part, Model, or Prompt)
    local function getTargetPosition(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then
            return inst.Position
        elseif inst:IsA("Model") then
            if inst.PrimaryPart then return inst.PrimaryPart.Position end
            local cframe = inst:GetPivot()
            return cframe.Position
        elseif inst:IsA("ProximityPrompt") then
            local p = inst.Parent
            if p and p:IsA("BasePart") then
                return p.Position
            elseif p and p:IsA("Model") then
                return p:GetPivot().Position
            elseif p and p.Parent and p.Parent:IsA("BasePart") then
                return p.Parent.Position
            end
        end
        return nil
    end

    -- Teleport the player safely to a target workstation or station
    function Restaurant.TeleportTo(targetInstance)
        local char = LocalPlayer.Character
        if not char then return false end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return false end

        local targetPos = getTargetPosition(targetInstance)
        if not targetPos then return false end

        -- Prevent accidental sitting in customer chairs during teleport
        if Config.PreventSitting and hum.Sit then
            hum.Sit = false
        end

        -- Calculate safe floor position via downward raycasting
        local safePos = Utility.GetGroundPosition(targetPos, {char})

        -- Face toward the target
        local lookPos = Vector3.new(targetPos.X, safePos.Y, targetPos.Z)
        local targetCFrame = CFrame.lookAt(safePos, lookPos)

        -- Perform teleportation
        root.CFrame = targetCFrame

        -- Zero out residual physics velocity to avoid fling
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        return true
    end

    -- Safely trigger an in-game ProximityPrompt with enhanced properties
    local function triggerPrompt(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end

        -- Ensure prompt properties are optimized for interaction
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 32)
        end)

        -- Custom executor fireproximityprompt if supported
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function()
                fireproximityprompt(prompt, 0)
            end)
            if ok then return true end
        end

        -- Input began simulation fallback
        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                task.wait(0.05)
                if prompt.InputHoldEnd then prompt:InputHoldEnd() end
            end
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
                    desc.MaxActivationDistance = math.max(desc.MaxActivationDistance or 10, 32)
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
                        desc.MaxActivationDistance = math.max(desc.MaxActivationDistance or 10, 32)
                    end
                end)
            end
        end
    end

    -- Find matching active prompts within the scoped plot
    local function findMatchingPrompts(keywords)
        local rootContainer = Restaurant.GetPlayerPlot()
        local matches = {}

        for _, obj in ipairs(rootContainer:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local action = (obj.ActionText or ""):lower()
                local name = (obj.ObjectText or obj.Name or ""):lower()
                local parentName = (obj.Parent and obj.Parent.Name or ""):lower()

                for _, kw in ipairs(keywords) do
                    kw = kw:lower()
                    if action:find(kw, 1, true) or name:find(kw, 1, true) or parentName:find(kw, 1, true) then
                        table.insert(matches, obj)
                        break
                    end
                end
            end
        end
        return matches
    end

    -- Process a queue of prompts sequentially with teleportation and safety delays
    local function processPromptQueue(prompts, maxPerCycle)
        local limit = maxPerCycle or 3
        local processed = 0

        for _, prompt in ipairs(prompts) do
            if not Core.State.Running then break end
            if not prompt or not prompt.Parent or not prompt.Enabled then continue end

            if Config.AutoTeleportEnabled then
                Restaurant.TeleportTo(prompt)
                task.wait(math.clamp(Config.TeleportDelay or 0.15, 0.05, 1))
            end

            triggerPrompt(prompt)
            processed = processed + 1

            if processed >= limit then break end
            task.wait(0.08)
        end
        return processed
    end

    -- Specific Workflow Handlers
    function Restaurant.HandleSeating()
        if not Config.AutoSeatEnabled then return end
        local prompts = findMatchingPrompts({"seat", "customer", "lead", "table", "chair", "welcome", "host", "invite"})
        processPromptQueue(prompts, 2)
    end

    function Restaurant.HandleOrdering()
        if not Config.AutoOrderEnabled then return end
        local prompts = findMatchingPrompts({"order", "take order", "menu", "ask", "ticket"})
        processPromptQueue(prompts, 3)
    end

    function Restaurant.HandleCooking()
        if not Config.AutoCookEnabled then return end
        local prompts = findMatchingPrompts({"cook", "prepare", "bake", "fry", "stove", "grill", "oven", "pot", "pan", "station", "brew"})
        processPromptQueue(prompts, 3)
    end

    function Restaurant.HandleServing()
        if not Config.AutoServeEnabled then return end
        local prompts = findMatchingPrompts({"serve", "deliver", "dish", "plate", "food", "tray", "counter"})
        processPromptQueue(prompts, 3)
    end

    function Restaurant.HandleCleaning()
        if not Config.AutoCleanEnabled then return end
        local prompts = findMatchingPrompts({"clean", "dirty", "trash", "wash", "clear", "wipe", "sink", "bus"})
        processPromptQueue(prompts, 4)
    end

    function Restaurant.HandleFarming()
        if not Config.AutoFarmEnabled then return end
        local prompts = findMatchingPrompts({"harvest", "crop", "plant", "water", "gather", "pick", "egg", "milk", "animal", "feed", "seed", "wheat", "tomato"})
        processPromptQueue(prompts, 3)
    end

    function Restaurant.HandleCashCollection()
        if not Config.AutoCollectCashEnabled then return end
        -- Collect via prompts
        local prompts = findMatchingPrompts({"cash", "coin", "tip", "bill", "pay", "collect", "register", "money"})
        processPromptQueue(prompts, 4)

        -- Collect via dropped touch-interest coins / cash parts in player plot
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and Config.AutoCollectCashEnabled then
            local container = Restaurant.GetPlayerPlot()
            for _, item in ipairs(container:GetDescendants()) do
                if item:IsA("BasePart") then
                    local name = item.Name:lower()
                    if (name:find("coin") or name:find("cash") or name:find("money") or name:find("tip")) then
                        if Config.AutoTeleportEnabled then
                            Restaurant.TeleportTo(item)
                            task.wait(0.05)
                        end
                        pcall(function()
                            firetouchinterest(root, item, 0)
                            task.wait()
                            firetouchinterest(root, item, 1)
                        end)
                    end
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

                -- Keep chair sit guard active if enabled
                if Config.PreventSitting and LocalPlayer.Character then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Sit then
                        hum.Sit = false
                    end
                end

                -- Run prioritized workflow cycle
                if Config.AutoFarmEnabled then
                    pcall(Restaurant.HandleFarming)
                end
                if Config.AutoCollectCashEnabled then
                    pcall(Restaurant.HandleCashCollection)
                end
                if Config.AutoCleanEnabled then
                    pcall(Restaurant.HandleCleaning)
                end
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

                task.wait(delayTime)
            end
            runningLoop = false
        end)
    end

    function Restaurant.Init()
        setupPromptHook()
        Restaurant.StartLoop()
        print("🍽️ Run a Restaurant automation module loaded with teleportation & plot scoping.")
    end

    function Restaurant.Cleanup()
        runningLoop = false
        cachedPlot = nil
    end

    return Restaurant
end
