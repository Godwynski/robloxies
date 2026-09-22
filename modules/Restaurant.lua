return function(Core)
    local Restaurant = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer
    local State = Core.State

    -- Cached plot reference
    local cachedPlot = nil
    local lastPlotSearch = 0
    local lastMemoryClean = os.clock()
    local lastQuestCheck = 0

    -- Per-prompt cooldown tracker to prevent rapid-fire animation spam
    local promptCooldowns = setmetatable({}, {__mode = "k"})

    local function isPromptReady(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        local exp = promptCooldowns[prompt]
        if exp and os.clock() < exp then return false end
        return true
    end

    local function setPromptCooldown(prompt, duration)
        promptCooldowns[prompt] = os.clock() + (duration or 2.5)
    end

    -- Periodic memory cleanup to prevent memory bloat over 12+ hour runs
    local function cleanExpiredCooldowns()
        local now = os.clock()
        if now - lastMemoryClean > 300 then
            lastMemoryClean = now
            for p, exp in pairs(promptCooldowns) do
                if now >= exp or not p or not p.Parent then
                    promptCooldowns[p] = nil
                end
            end
        end
    end

    -- Safe character resolver ensuring humanoid is alive and loaded
    local function getAliveCharacter()
        local char = LocalPlayer.Character
        if not char then return nil, nil, nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return nil, nil, nil end
        return char, root, hum
    end

    -- Release character from any seat welds safely
    local function releaseSeat(hum, char)
        if not hum then return end
        if hum.Sit then
            hum.Sit = false
        end
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("Weld") or part:IsA("ManualWeld") or part:IsA("Snap") then
                    if part.Name == "SeatWeld" or (part.Part0 and part.Part0:IsA("Seat")) or (part.Part1 and part.Part1:IsA("Seat")) then
                        pcall(function() part:Destroy() end)
                    end
                end
            end
        end
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end

    -- Locate the LocalPlayer's designated restaurant/farm plot
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

        -- 1. Direct LocalPlayer plot references
        local plotVal = LocalPlayer:FindFirstChild("Plot") or LocalPlayer:FindFirstChild("Restaurant") or LocalPlayer:FindFirstChild("Tycoon")
        if plotVal and plotVal:IsA("ObjectValue") and plotVal.Value then
            cachedPlot = plotVal.Value
            return cachedPlot
        end
        local plotAttr = LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("Restaurant")
        if typeof(plotAttr) == "Instance" then
            cachedPlot = plotAttr
            return cachedPlot
        end

        -- 2. Search common plot containers in workspace
        local map = workspace:FindFirstChild("Map")
        local searchContainers = {
            workspace:FindFirstChild("Plots"),
            workspace:FindFirstChild("Restaurants"),
            workspace:FindFirstChild("PlayerRestaurants"),
            workspace:FindFirstChild("PlayerPlots"),
            workspace:FindFirstChild("Tycoons"),
            workspace:FindFirstChild("Farms"),
            map and map:FindFirstChild("Plots"),
            map and map:FindFirstChild("Restaurants"),
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

                        -- Check item name
                        local itemName = item.Name:lower()
                        if itemName:find(playerName, 1, true) or itemName:find(userId, 1, true) then
                            cachedPlot = item
                            return item
                        end

                        -- Check billboard text
                        for _, desc in ipairs(item:GetDescendants()) do
                            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                local txt = (desc.Text or ""):lower()
                                if (txt:find(playerName, 1, true) or txt:find(displayName, 1, true)) and 
                                   (txt:find("restaurant", 1, true) or txt:find("plot", 1, true) or txt:find("farm", 1, true)) then
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

    -- Extract target world position safely
    local function getTargetPosition(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then
            return inst.Position
        elseif inst:IsA("Model") then
            if inst.PrimaryPart then return inst.PrimaryPart.Position end
            return inst:GetPivot().Position
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

    -- Teleport player safely to a target workstation
    function Restaurant.TeleportTo(targetInstance)
        local char, root, hum = getAliveCharacter()
        if not char or not root or not hum then return false end

        local targetPos = getTargetPosition(targetInstance)
        if not targetPos then return false end

        -- Prevent accidental sitting in customer chairs
        if Config.PreventSitting then
            releaseSeat(hum, char)
        end

        -- Calculate safe floor position via downward raycast with multi-floor safety
        local safePos = Utility.GetGroundPosition(targetPos, {char})

        -- Orient avatar toward the workstation/customer
        local lookPos = Vector3.new(targetPos.X, safePos.Y, targetPos.Z)
        local targetCFrame = CFrame.lookAt(safePos, lookPos)

        root.CFrame = targetCFrame

        -- Zero out velocity to prevent flinging
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        return true
    end

    -- Trigger a ProximityPrompt safely
    local function triggerPrompt(prompt, debounceTime)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end

        -- Set cooldown immediately
        setPromptCooldown(prompt, debounceTime or 2.5)

        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 32)
        end)

        -- Custom executor fireproximityprompt
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function()
                fireproximityprompt(prompt, 0)
            end)
            if ok then return true end
            pcall(function()
                fireproximityprompt(prompt)
            end)
            return true
        end

        -- Fallback simulation
        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                task.wait(0.05)
                if prompt.InputHoldEnd then prompt:InputHoldEnd() end
            end
        end)
        return true
    end

    -- Setup prompt hooks for automatic optimization
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

    -- Match prompt using action-text priority and optional object text (prevents cross-triggering)
    local function matchPrompt(prompt, actionKeywords, objectKeywords)
        if not isPromptReady(prompt) then return false end
        local actionText = (prompt.ActionText or ""):lower()
        local objectText = (prompt.ObjectText or prompt.Name or ""):lower()

        -- 1. Match ActionText (Primary)
        for _, kw in ipairs(actionKeywords) do
            kw = kw:lower()
            if actionText:find(kw, 1, true) then
                return true
            end
        end

        -- 2. Match ObjectText if specified
        if objectKeywords then
            for _, kw in ipairs(objectKeywords) do
                kw = kw:lower()
                if objectText:find(kw, 1, true) then
                    return true
                end
            end
        end

        return false
    end

    -- Find matching active prompts within the scoped plot
    local function findMatchingPrompts(actionKeywords, objectKeywords)
        local rootContainer = Restaurant.GetPlayerPlot()
        local matches = {}

        for _, obj in ipairs(rootContainer:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                if matchPrompt(obj, actionKeywords, objectKeywords) then
                    table.insert(matches, obj)
                end
            end
        end

        -- VIP & Celebrity customer priority: place high-value customers at front of queue
        if Config.VIPPriorityEnabled and #matches > 1 then
            table.sort(matches, function(a, b)
                local aName = (a.ObjectText or a.Name or (a.Parent and a.Parent.Name or "")):lower()
                local bName = (b.ObjectText or b.Name or (b.Parent and b.Parent.Name or "")):lower()
                local aIsVip = (aName:find("vip", 1, true) or aName:find("gold", 1, true) or aName:find("rich", 1, true) or aName:find("celebrity", 1, true) or aName:find("star", 1, true)) ~= nil
                local bIsVip = (bName:find("vip", 1, true) or bName:find("gold", 1, true) or bName:find("rich", 1, true) or bName:find("celebrity", 1, true) or bName:find("star", 1, true)) ~= nil
                if aIsVip and not bIsVip then return true end
                return false
            end)
        end

        return matches
    end

    -- Process queue sequentially with teleportation and debounce
    local function processPromptQueue(prompts, maxPerCycle, debounceDuration)
        local limit = maxPerCycle or 3
        local processed = 0

        for _, prompt in ipairs(prompts) do
            if not Core.State.Running then break end
            if not isPromptReady(prompt) then continue end

            if Config.AutoTeleportEnabled then
                Restaurant.TeleportTo(prompt)
                task.wait(math.clamp(Config.TeleportDelay or 0.15, 0.05, 1))
            end

            triggerPrompt(prompt, debounceDuration)
            processed = processed + 1

            if processed >= limit then break end
            task.wait(0.08)
        end
        return processed
    end

    -- Handlers with ActionText priority & Stats tracking
    function Restaurant.HandleSeating()
        if not Config.AutoSeatEnabled then return end
        local prompts = findMatchingPrompts(
            {"seat", "host", "lead", "welcome", "invite"},
            {"customer", "guest"}
        )
        local count = processPromptQueue(prompts, 2, 3.5)
        State.Stats.CustomersSeated = State.Stats.CustomersSeated + count
    end

    function Restaurant.HandleOrdering()
        if not Config.AutoOrderEnabled then return end
        local prompts = findMatchingPrompts(
            {"order", "take order", "menu", "ask"},
            {"order", "ticket"}
        )
        local count = processPromptQueue(prompts, 3, 3.0)
        State.Stats.OrdersTaken = State.Stats.OrdersTaken + count
    end

    function Restaurant.HandleCooking()
        if not Config.AutoCookEnabled then return end
        local prompts = findMatchingPrompts(
            {"cook", "prepare", "bake", "fry", "grill", "boil", "brew", "flip", "chop"},
            {"stove", "oven", "grill", "station", "pan", "pot"}
        )
        local count = processPromptQueue(prompts, 3, 2.5)
        State.Stats.DishesCooked = State.Stats.DishesCooked + count
    end

    function Restaurant.HandleServing()
        if not Config.AutoServeEnabled then return end
        local prompts = findMatchingPrompts(
            {"serve", "deliver", "bring", "give"},
            {"dish", "plate", "food", "tray", "meal"}
        )
        local count = processPromptQueue(prompts, 3, 2.5)
        State.Stats.DishesServed = State.Stats.DishesServed + count
    end

    function Restaurant.HandleCleaning()
        if not Config.AutoCleanEnabled then return end
        local prompts = findMatchingPrompts(
            {"clean", "wash", "wipe", "clear", "bus", "trash", "empty"},
            {"dish", "dishes", "plate", "table", "tray", "sink"}
        )
        local count = processPromptQueue(prompts, 4, 3.0)
        State.Stats.TablesCleaned = State.Stats.TablesCleaned + count
    end

    function Restaurant.HandleFarming()
        if not Config.AutoFarmEnabled then return end
        local prompts = findMatchingPrompts(
            {"harvest", "plant", "water", "gather", "pick", "shear", "milk", "feed", "collect"},
            {"crop", "wheat", "tomato", "pumpkin", "cow", "chicken", "tree", "seed", "plant", "animal", "egg"}
        )
        local count = processPromptQueue(prompts, 3, 3.0)
        State.Stats.CropsHarvested = State.Stats.CropsHarvested + count
    end

    function Restaurant.HandleDelivery()
        if not Config.AutoDeliveryEnabled then return end
        local prompts = findMatchingPrompts(
            {"deliver", "package", "pack", "load", "ship", "fulfill"},
            {"delivery", "box", "takeout", "scooter", "bike", "order", "station"}
        )
        local count = processPromptQueue(prompts, 2, 4.0)
        State.Stats.DeliveriesCompleted = State.Stats.DeliveriesCompleted + count
    end

    function Restaurant.HandleRestock()
        if not Config.AutoRestockEnabled then return end
        local prompts = findMatchingPrompts(
            {"deposit", "restock", "store", "refill", "put", "stock"},
            {"fridge", "cooler", "pantry", "storage", "shelf", "crate"}
        )
        local count = processPromptQueue(prompts, 2, 4.0)
        State.Stats.StorageRestocked = State.Stats.StorageRestocked + count
    end

    function Restaurant.HandleExpansion()
        if not Config.AutoExpandEnabled then return end
        local prompts = findMatchingPrompts(
            {"expand", "floor", "unlock", "purchase", "upgrade", "buy"},
            {"floor", "plot", "land", "expand", "room", "greenhouse"}
        )
        local count = processPromptQueue(prompts, 1, 6.0)
        State.Stats.ExpansionsPurchased = State.Stats.ExpansionsPurchased + count
    end

    function Restaurant.HandleCashCollection()
        if not Config.AutoCollectCashEnabled then return end
        -- Register & tip prompts
        local prompts = findMatchingPrompts(
            {"collect", "take", "claim", "withdraw", "empty"},
            {"cash", "coin", "tip", "tips", "bill", "money", "register"}
        )
        local count = processPromptQueue(prompts, 3, 4.0)
        State.Stats.CashCollected = State.Stats.CashCollected + count

        -- Dropped physical coins / cash parts
        local char, root = getAliveCharacter()
        if not root then return end

        local container = Restaurant.GetPlayerPlot()
        local hasFireTouch = (type(firetouchinterest) == "function")
        local coinsCollected = 0

        for _, item in ipairs(container:GetDescendants()) do
            if item:IsA("BasePart") and not item.Anchored and item.Parent ~= char then
                local name = item.Name:lower()
                if (name:find("coin") or name:find("cash") or name:find("money") or name:find("tip")) then
                    if hasFireTouch then
                        pcall(function()
                            firetouchinterest(root, item, 0)
                            task.wait()
                            firetouchinterest(root, item, 1)
                        end)
                        coinsCollected = coinsCollected + 1
                        if coinsCollected >= 15 then break end
                    elseif Config.AutoTeleportEnabled then
                        Restaurant.TeleportTo(item)
                        task.wait(0.08)
                        coinsCollected = coinsCollected + 1
                        if coinsCollected >= 5 then break end
                    end
                end
            end
        end
        State.Stats.CashCollected = State.Stats.CashCollected + coinsCollected
    end

    -- Main automation loop with strict priority order & memory safety
    local runningLoop = false
    function Restaurant.StartLoop()
        if runningLoop then return end
        runningLoop = true

        task.spawn(function()
            while Core.State.Running and runningLoop do
                local delayTime = math.clamp(Config.ActionDelay or 0.3, 0.05, 5)

                -- Run memory sanitation
                cleanExpiredCooldowns()

                -- Check and auto-claim finished quests / gifts every 10 seconds
                local now = os.clock()
                if Config.AutoClaimQuestsEnabled and (now - lastQuestCheck > 10) then
                    lastQuestCheck = now
                    local claimed = Utility.ClaimQuestsAndGifts()
                    if claimed and claimed > 0 then
                        State.Stats.QuestsClaimed = State.Stats.QuestsClaimed + claimed
                    end
                end

                local char, _, hum = getAliveCharacter()
                if char and hum and hum.Health > 0 then
                    -- 1. Restock fridge/storage so chefs have ingredients
                    if Config.AutoRestockEnabled then
                        pcall(Restaurant.HandleRestock)
                    end

                    -- 2. Harvest farm goods (keeps kitchen supplied)
                    if Config.AutoFarmEnabled then
                        pcall(Restaurant.HandleFarming)
                    end

                    -- 3. Fulfill high-value delivery orders
                    if Config.AutoDeliveryEnabled then
                        pcall(Restaurant.HandleDelivery)
                    end

                    -- 4. Auto-expand floors and land plots
                    if Config.AutoExpandEnabled then
                        pcall(Restaurant.HandleExpansion)
                    end

                    -- 5. Collect cash/tips (frees registers & tables)
                    if Config.AutoCollectCashEnabled then
                        pcall(Restaurant.HandleCashCollection)
                    end

                    -- 5. Clean tables (frees seats for new guests)
                    if Config.AutoCleanEnabled then
                        pcall(Restaurant.HandleCleaning)
                    end

                    -- 6. Seat waiting customers (now that tables are clear)
                    if Config.AutoSeatEnabled then
                        pcall(Restaurant.HandleSeating)
                    end

                    -- 7. Take customer orders
                    if Config.AutoOrderEnabled then
                        pcall(Restaurant.HandleOrdering)
                    end

                    -- 8. Cook food at stations
                    if Config.AutoCookEnabled then
                        pcall(Restaurant.HandleCooking)
                    end

                    -- 9. Serve prepared dishes
                    if Config.AutoServeEnabled then
                        pcall(Restaurant.HandleServing)
                    end
                end

                task.wait(delayTime)
            end
            runningLoop = false
        end)
    end

    function Restaurant.Init()
        setupPromptHook()
        Restaurant.StartLoop()
        print("🍽️ Run a Restaurant full economic empire automation loaded.")
    end

    function Restaurant.Cleanup()
        runningLoop = false
        cachedPlot = nil
        table.clear(promptCooldowns)
    end

    return Restaurant
end
