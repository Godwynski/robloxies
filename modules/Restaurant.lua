return function(Core)
    local Restaurant = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer
    local State = Core.State

    -- Plot & Anchor references
    local cachedPlot = nil
    local lastPlotSearch = 0
    local lastMemoryClean = os.clock()
    local lastQuestCheck = 0
    Restaurant.RestaurantCenter = nil

    -- Per-prompt cooldown tracker
    local promptCooldowns = setmetatable({}, {__mode = "k"})
    -- Unaffordable prompt backoff tracker (prevents spamming unaffordable land/items)
    local unaffordableBackoff = setmetatable({}, {__mode = "k"})

    local function isPromptReady(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        local exp = promptCooldowns[prompt]
        if exp and os.clock() < exp then return false end
        return true
    end

    local function isPromptAffordable(prompt)
        if not prompt or not prompt.Parent then return false end
        local backoff = unaffordableBackoff[prompt]
        if backoff and os.clock() < backoff then return false end

        local price = Utility.ParsePrice(nil, prompt)
        if price and price > 0 then
            local canAfford, needed = Utility.CanAfford(price)
            if not canAfford then
                unaffordableBackoff[prompt] = os.clock() + (Config.AffordabilityBackoff or 30)
                return false
            end
        end
        return true
    end

    local function setPromptCooldown(prompt, duration)
        if prompt then
            promptCooldowns[prompt] = os.clock() + (duration or 2.5)
        end
    end

    -- Periodic memory cleanup
    local function cleanExpiredCooldowns()
        local now = os.clock()
        if now - lastMemoryClean > 300 then
            lastMemoryClean = now
            for p, exp in pairs(promptCooldowns) do
                if now >= exp or not p or not p.Parent then
                    promptCooldowns[p] = nil
                end
            end
            for p, exp in pairs(unaffordableBackoff) do
                if now >= exp or not p or not p.Parent then
                    unaffordableBackoff[p] = nil
                end
            end
        end
    end

    -- Safe character resolver
    local function getAliveCharacter()
        local char = LocalPlayer and LocalPlayer.Character
        if not char then return nil, nil, nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return nil, nil, nil end
        return char, root, hum
    end

    -- Safely unseat character without breaking physics
    local function releaseSeat(hum, char)
        if not hum then return end
        if hum.Sit then
            hum.Sit = false
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, child in ipairs(root:GetChildren()) do
                        if child:IsA("Weld") and child.Name == "SeatWeld" then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end
            end
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(0.05)
        end
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

    -- Recalibrate the center of the restaurant to current avatar position
    function Restaurant.RecalibrateAnchor()
        local _, root = getAliveCharacter()
        if root then
            Restaurant.RestaurantCenter = root.Position
            cachedPlot = nil
            return true
        end
        return false
    end

    -- Locate player's designated restaurant / farm plot
    function Restaurant.GetPlayerPlot()
        if not Config.PlotScopingEnabled then return workspace end
        local now = os.clock()
        if cachedPlot and cachedPlot.Parent and (now - lastPlotSearch < 15) then
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
            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
            return cachedPlot
        end
        local plotAttr = LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("Restaurant")
        if typeof(plotAttr) == "Instance" then
            cachedPlot = plotAttr
            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
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
                                Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                                return item
                            end
                        end
                        if item:GetAttribute("Owner") == LocalPlayer.UserId or tostring(item:GetAttribute("Owner")):lower() == playerName then
                            cachedPlot = item
                            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                            return item
                        end

                        -- Check item name
                        local itemName = item.Name:lower()
                        if itemName:find(playerName, 1, true) or itemName:find(userId, 1, true) then
                            cachedPlot = item
                            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                            return item
                        end

                        -- Check billboard text
                        for _, desc in ipairs(item:GetDescendants()) do
                            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                local txt = (desc.Text or ""):lower()
                                if (txt:find(playerName, 1, true) or txt:find(displayName, 1, true)) and 
                                   (txt:find("restaurant", 1, true) or txt:find("plot", 1, true) or txt:find("farm", 1, true)) then
                                    cachedPlot = item
                                    Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                                    return item
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 3. Fallback: Find closest plot model to player or anchor to player position
        local _, root = getAliveCharacter()
        if root then
            if not Restaurant.RestaurantCenter then
                Restaurant.RestaurantCenter = root.Position
            end
        end

        return cachedPlot or workspace
    end

    -- Teleport player safely to a target workstation (Zero-NaN safe)
    function Restaurant.TeleportTo(targetInstance)
        local char, root, hum = getAliveCharacter()
        if not char or not root or not hum then return false end

        local targetPos = getTargetPosition(targetInstance)
        if not targetPos then return false end

        -- Prevent accidental sitting in customer chairs
        if Config.PreventSitting and hum.Sit then
            releaseSeat(hum, char)
        end

        -- Stand offset from workstation part (2.5 studs back)
        local standOffset = Vector3.new(0, 0, 2.5)
        if targetInstance:IsA("BasePart") then
            standOffset = targetInstance.CFrame.LookVector * 2.5
        elseif targetInstance:IsA("ProximityPrompt") and targetInstance.Parent and targetInstance.Parent:IsA("BasePart") then
            standOffset = targetInstance.Parent.CFrame.LookVector * 2.5
        end
        if standOffset.Magnitude < 0.5 then
            standOffset = Vector3.new(0, 0, 2.5)
        end

        local standPos = targetPos + Vector3.new(standOffset.X, 0, standOffset.Z)
        local safePos = Utility.GetGroundPosition(standPos, {char})

        -- Orient avatar toward the target position safely (Prevents NaN flings)
        local lookPos = Vector3.new(targetPos.X, safePos.Y, targetPos.Z)
        local targetCFrame
        if (lookPos - safePos).Magnitude > 0.5 then
            targetCFrame = CFrame.lookAt(safePos, lookPos)
        else
            targetCFrame = CFrame.new(safePos)
        end

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

        setPromptCooldown(prompt, debounceTime or 2.5)

        if Config.InstantPromptEnabled then
            pcall(function()
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 24)
            end)
        end

        -- 1. Try executor native fireproximityprompt
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function()
                fireproximityprompt(prompt)
            end)
            if ok then return true end
            pcall(function()
                fireproximityprompt(prompt, 1)
            end)
            return true
        end

        -- 2. Fallback input simulation
        local holdTime = prompt.HoldDuration or 0
        if Config.InstantPromptEnabled then
            holdTime = 0
            pcall(function() prompt.HoldDuration = 0 end)
        end

        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                if holdTime > 0 then
                    task.wait(holdTime + 0.05)
                else
                    task.wait(0.05)
                end
                if prompt.InputHoldEnd then
                    prompt:InputHoldEnd()
                end
            end
        end)
        return true
    end

    -- Single-pass prompt aggregator (High-speed, zero-lag, no full workspace spam)
    function Restaurant.ScanPrompts()
        local container = Restaurant.GetPlayerPlot()
        local _, root = getAliveCharacter()
        local center = Restaurant.RestaurantCenter or (root and root.Position)
        local maxDist = Config.MaxScanRadius or 120

        local categorized = {
            Cash = {},
            Order = {},
            Cook = {},
            Serve = {},
            Clean = {},
            Seat = {},
            Delivery = {},
            Restock = {},
            Farm = {},
            Expand = {},
            Buy = {},
            Place = {},
            Quest = {},
        }

        local searchList = {}
        if container and container ~= workspace then
            searchList = container:GetDescendants()
        else
            -- Proximity scoped: Only search models within maxDist to prevent scanning 50,000 objects
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model") or obj:IsA("Folder") then
                    local pos = getTargetPosition(obj)
                    if not center or not pos or (pos - center).Magnitude <= (maxDist + 35) then
                        for _, d in ipairs(obj:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then
                                table.insert(searchList, d)
                            end
                        end
                    end
                elseif obj:IsA("ProximityPrompt") then
                    table.insert(searchList, obj)
                end
            end
        end

        for _, obj in ipairs(searchList) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and isPromptReady(obj) then
                local pos = getTargetPosition(obj)
                if not center or not pos or (pos - center).Magnitude <= maxDist then
                    local act = (obj.ActionText or ""):lower()
                    local objTxt = (obj.ObjectText or obj.Name or (obj.Parent and obj.Parent.Name or "")):lower()
                    local combined = act .. " " .. objTxt

                    -- 1. Cash, Tips & Free Reward Chests
                    if combined:find("tip") or combined:find("cash") or combined:find("register") or combined:find("collect") or combined:find("money") or combined:find("gift") or combined:find("reward") or combined:find("chest") then
                        table.insert(categorized.Cash, obj)

                    -- 2. Customer Orders
                    elseif (combined:find("order") or combined:find("menu") or combined:find("ticket") or combined:find("take order")) and not combined:find("delivery") then
                        table.insert(categorized.Order, obj)

                    -- 3. Cook Food
                    elseif combined:find("cook") or combined:find("prepare") or combined:find("bake") or combined:find("grill") or combined:find("stove") or combined:find("oven") then
                        table.insert(categorized.Cook, obj)

                    -- 4. Serve Prepared Dishes
                    elseif combined:find("serve") or combined:find("bring") or combined:find("plate") or (combined:find("dish") and not combined:find("sink")) then
                        table.insert(categorized.Serve, obj)

                    -- 5. Clean Dirty Tables
                    elseif combined:find("clean") or combined:find("wash") or combined:find("wipe") or combined:find("dirty") or combined:find("bus") or combined:find("trash") or combined:find("sink") then
                        table.insert(categorized.Clean, obj)

                    -- 6. Add / Place Furniture, Chairs & Tables (BEFORE Customer Seating)
                    elseif combined:find("place") or combined:find("build") or combined:find("assemble") or combined:find("put down") or
                           combined:find("add table") or combined:find("add chair") or combined:find("add seat") or combined:find("add furniture") or
                           combined:find("new table") or combined:find("new chair") or combined:find("new seat") or
                           (combined:find("add") and (combined:find("table") or combined:find("chair") or combined:find("furniture") or combined:find("seat"))) then
                        table.insert(categorized.Place, obj)

                    -- 7. Customer Seating (Host / Welcome)
                    elseif combined:find("seat") or combined:find("host") or combined:find("welcome") or combined:find("customer") or combined:find("guest") or combined:find("party") then
                        table.insert(categorized.Seat, obj)

                    -- 8. Delivery Orders
                    elseif combined:find("package") or combined:find("box") or combined:find("scooter") or combined:find("takeout") or combined:find("delivery") then
                        table.insert(categorized.Delivery, obj)

                    -- 9. Restock Storage
                    elseif combined:find("restock") or combined:find("deposit") or combined:find("fridge") or combined:find("cooler") or combined:find("pantry") then
                        table.insert(categorized.Restock, obj)

                    -- 10. Farm Harvest
                    elseif combined:find("harvest") or combined:find("crop") or combined:find("wheat") or combined:find("plant") or combined:find("gather") or combined:find("pick") then
                        table.insert(categorized.Farm, obj)

                    -- 11. Buy Furniture & Equipment
                    elseif (combined:find("buy") or combined:find("purchase")) and not combined:find("floor") and not combined:find("expand") then
                        if isPromptAffordable(obj) then
                            table.insert(categorized.Buy, obj)
                        end

                    -- 12. Expand Land & Floors
                    elseif combined:find("expand") or combined:find("unlock") or (combined:find("floor") and (combined:find("buy") or combined:find("unlock") or combined:find("purchase"))) then
                        if isPromptAffordable(obj) then
                            table.insert(categorized.Expand, obj)
                        end

                    -- 13. Quest NPCs, Quest Boards, Bounty Givers & Turn-Ins
                    elseif combined:find("quest") or combined:find("mission") or combined:find("bounty") or combined:find("board") or combined:find("contract") or (combined:find("talk") and not combined:find("seat")) then
                        table.insert(categorized.Quest, obj)
                    end
                end
            end
        end

        -- VIP Customer Priority: Sort VIP patrons to front of queue
        if Config.VIPPriorityEnabled then
            local function sortVip(list)
                if #list > 1 then
                    table.sort(list, function(a, b)
                        local aTxt = ((a.ObjectText or "") .. " " .. (a.Parent and a.Parent.Name or "")):lower()
                        local bTxt = ((b.ObjectText or "") .. " " .. (b.Parent and b.Parent.Name or "")):lower()
                        local aVip = aTxt:find("vip") or aTxt:find("gold") or aTxt:find("celebrity") or aTxt:find("star") or aTxt:find("rich")
                        local bVip = bTxt:find("vip") or bTxt:find("gold") or bTxt:find("celebrity") or bTxt:find("star") or bTxt:find("rich")
                        if aVip and not bVip then return true end
                        return false
                    end)
                end
            end
            sortVip(categorized.Seat)
            sortVip(categorized.Order)
        end

        return categorized
    end

    -- Spatial clustering: Find ready prompts in the same category within radius studs
    function Restaurant.GetNearbyCluster(primaryPrompt, promptsList, radius, maxCount)
        local cluster = {}
        if not primaryPrompt or not promptsList then return cluster end
        local primaryPos = getTargetPosition(primaryPrompt)
        if not primaryPos then return cluster end

        radius = radius or 14
        maxCount = maxCount or (Config.StationBatchSize or 3)

        for _, prompt in ipairs(promptsList) do
            if prompt ~= primaryPrompt and isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                local pos = getTargetPosition(prompt)
                if pos and (pos - primaryPos).Magnitude <= radius then
                    table.insert(cluster, prompt)
                    if #cluster >= (maxCount - 1) then
                        break
                    end
                end
            end
        end
        return cluster
    end

    -- Trigger nearby prompts across ANY enabled category opportunistically (same room/station)
    function Restaurant.TriggerOpportunisticNearby(centerPos, allPrompts, radius)
        if not Config.RemotePromptBatching or not centerPos or not allPrompts then return 0 end
        radius = radius or 14
        local triggeredCount = 0
        local isMaster = Config.MasterAutoFarmEnabled

        local categoryConfigs = {
            Cash = { enabled = isMaster or Config.AutoCollectCashEnabled, stat = "CashCollected", cooldown = 3.0 },
            Order = { enabled = isMaster or Config.AutoOrderEnabled, stat = "OrdersTaken", cooldown = 2.5 },
            Cook = { enabled = isMaster or Config.AutoCookEnabled, stat = "DishesCooked", cooldown = 2.5 },
            Serve = { enabled = isMaster or Config.AutoServeEnabled, stat = "DishesServed", cooldown = 2.5 },
            Clean = { enabled = isMaster or Config.AutoCleanEnabled, stat = "TablesCleaned", cooldown = 3.0 },
            Seat = { enabled = isMaster or Config.AutoSeatEnabled, stat = "CustomersSeated", cooldown = 3.0 },
            Delivery = { enabled = isMaster or Config.AutoDeliveryEnabled, stat = "DeliveriesCompleted", cooldown = 4.0 },
            Restock = { enabled = isMaster or Config.AutoRestockEnabled, stat = "StorageRestocked", cooldown = 3.5 },
            Farm = { enabled = isMaster or Config.AutoFarmEnabled, stat = "CropsHarvested", cooldown = 3.0 },
        }

        for catName, catInfo in pairs(categoryConfigs) do
            if catInfo.enabled and allPrompts[catName] then
                for _, prompt in ipairs(allPrompts[catName]) do
                    if isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                        local pos = getTargetPosition(prompt)
                        if pos and (pos - centerPos).Magnitude <= radius then
                            State.InFlightTasks[prompt] = true
                            task.spawn(function()
                                pcall(function()
                                    triggerPrompt(prompt, catInfo.cooldown)
                                    if State.Stats[catInfo.stat] ~= nil then
                                        State.Stats[catInfo.stat] = State.Stats[catInfo.stat] + 1
                                    end
                                end)
                                State.InFlightTasks[prompt] = nil
                            end)
                            triggeredCount = triggeredCount + 1
                            if triggeredCount >= 3 then break end
                        end
                    end
                end
            end
        end
        return triggeredCount
    end

    -- Wait until the active prompt/task is confirmed done before allowing subsequent tasks
    local function waitForTaskCompletion(prompt, maxTimeout)
        if not prompt then return true end
        local timeout = maxTimeout or 1.6
        local hold = prompt.HoldDuration or 0
        if hold > 0 and not Config.InstantPromptEnabled then
            timeout = math.max(timeout, hold + 0.4)
        end

        local start = os.clock()
        while (os.clock() - start) < timeout do
            -- 1. Prompt or parent was destroyed (e.g., dirty dishes cleaned, meal picked up, customer seated)
            if not prompt or not prompt.Parent then
                break
            end
            -- 2. Prompt disabled by game logic (e.g., stove began cooking, customer order accepted)
            if not prompt.Enabled then
                break
            end
            task.wait(0.04)
        end

        -- 3. Post-action settling delay to guarantee server replication before moving avatar
        local settle = math.clamp(Config.PostActionDelay or 0.18, 0.05, 1.0)
        task.wait(settle)
        return true
    end

    -- Execute a single action cleanly with strict task completion and mutex safety
    local function executeAction(prompt, cooldown, statKey)
        if not prompt or not prompt.Parent then return false end
        if State.InFlightTasks[prompt] then return false end

        State.InFlightTasks[prompt] = true

        local success = false
        pcall(function()
            -- 1. Teleport safely if enabled
            if Config.AutoTeleportEnabled then
                local ok = Restaurant.TeleportTo(prompt)
                if ok then
                    task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
                end
            end

            -- 2. Trigger prompt
            triggerPrompt(prompt, cooldown or 2.5)

            -- 3. STRICT TASK COMPLETION: Wait until task finishes before proceeding
            if Config.StrictTaskCompletion then
                waitForTaskCompletion(prompt, 1.6)
            else
                task.wait(0.08)
            end

            -- 4. Increment statistics
            if statKey and State.Stats[statKey] ~= nil then
                State.Stats[statKey] = State.Stats[statKey] + 1
            end

            success = true
        end)

        State.InFlightTasks[prompt] = nil
        return success
    end

    -- Execute a workstation cluster cleanly with sequential completion at the station
    local function executeCluster(primaryPrompt, cluster, cooldown, statKey, allPrompts)
        if not primaryPrompt or not primaryPrompt.Parent then return false end
        if State.InFlightTasks[primaryPrompt] then return false end

        State.InFlightTasks[primaryPrompt] = true
        for _, p in ipairs(cluster) do
            State.InFlightTasks[p] = true
        end

        local success = false
        pcall(function()
            -- 1. Teleport safely to primary prompt once
            if Config.AutoTeleportEnabled then
                local ok = Restaurant.TeleportTo(primaryPrompt)
                if ok then
                    task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
                end
            end

            -- 2. Trigger primary prompt and ensure it is completed
            triggerPrompt(primaryPrompt, cooldown or 2.5)
            if Config.StrictTaskCompletion then
                waitForTaskCompletion(primaryPrompt, 1.6)
            else
                task.wait(0.08)
            end
            if statKey and State.Stats[statKey] ~= nil then
                State.Stats[statKey] = State.Stats[statKey] + 1
            end
            State.InFlightTasks[primaryPrompt] = nil

            -- 3. Complete each cluster prompt sequentially while standing at the station
            for _, prompt in ipairs(cluster) do
                if prompt and prompt.Parent and prompt.Enabled and isPromptReady(prompt) then
                    triggerPrompt(prompt, cooldown or 2.5)
                    if Config.StrictTaskCompletion then
                        waitForTaskCompletion(prompt, 1.6)
                    else
                        task.wait(0.08)
                    end
                    if statKey and State.Stats[statKey] ~= nil then
                        State.Stats[statKey] = State.Stats[statKey] + 1
                    end
                end
                State.InFlightTasks[prompt] = nil
            end

            -- 4. Opportunistic cross-category batching for ready prompts within 14 studs
            local primaryPos = getTargetPosition(primaryPrompt)
            if primaryPos and allPrompts and Config.RemotePromptBatching then
                Restaurant.TriggerOpportunisticNearby(primaryPos, allPrompts, 14)
            end

            success = true
        end)

        State.InFlightTasks[primaryPrompt] = nil
        for _, p in ipairs(cluster) do
            State.InFlightTasks[p] = nil
        end
        return success
    end

    -- Sweep dropped physical coins/cash parts remotely without teleport flinging
    function Restaurant.SweepFloorCash()
        local char, root = getAliveCharacter()
        if not root then return end

        local hasFireTouch = (type(firetouchinterest) == "function")
        local center = Restaurant.RestaurantCenter or root.Position
        local maxDist = Config.MaxScanRadius or 120

        local container = Restaurant.GetPlayerPlot()
        local searchParts = (container and container ~= workspace) and container:GetDescendants() or workspace:GetChildren()

        local count = 0
        for _, item in ipairs(searchParts) do
            if item:IsA("BasePart") and not item.Anchored and item.Parent ~= char then
                local name = item.Name:lower()
                if (name:find("coin") or name:find("cash") or name:find("money") or name:find("tip")) then
                    if (item.Position - center).Magnitude <= maxDist then
                        if hasFireTouch then
                            pcall(function()
                                firetouchinterest(root, item, 0)
                                task.wait()
                                firetouchinterest(root, item, 1)
                            end)
                            count = count + 1
                            if count >= 12 then break end
                        end
                    end
                end
            end
        end
        if count > 0 then
            State.Stats.CashCollected = State.Stats.CashCollected + count
        end
    end

    -- Individual handlers for manual button triggering
    function Restaurant.HandleCashCollection()
        local p = Restaurant.ScanPrompts()
        if #p.Cash > 0 then
            local primary = p.Cash[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Cash, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CashCollected", p)
        end
        Restaurant.SweepFloorCash()
    end
    function Restaurant.HandleOrdering()
        local p = Restaurant.ScanPrompts()
        if #p.Order > 0 then
            local primary = p.Order[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Order, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "OrdersTaken", p)
        end
    end
    function Restaurant.HandleCooking()
        local p = Restaurant.ScanPrompts()
        if #p.Cook > 0 then
            local primary = p.Cook[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Cook, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesCooked", p)
        end
    end
    function Restaurant.HandleServing()
        local p = Restaurant.ScanPrompts()
        if #p.Serve > 0 then
            local primary = p.Serve[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Serve, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesServed", p)
        end
    end
    function Restaurant.HandleCleaning()
        local p = Restaurant.ScanPrompts()
        if #p.Clean > 0 then
            local primary = p.Clean[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Clean, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "TablesCleaned", p)
        end
    end
    function Restaurant.HandleSeating()
        local p = Restaurant.ScanPrompts()
        if #p.Seat > 0 then
            local primary = p.Seat[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Seat, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CustomersSeated", p)
        end
    end
    function Restaurant.HandleDelivery()
        local p = Restaurant.ScanPrompts()
        if #p.Delivery > 0 then
            local primary = p.Delivery[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Delivery, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 4.0, "DeliveriesCompleted", p)
        end
    end
    function Restaurant.HandleRestock()
        local p = Restaurant.ScanPrompts()
        if #p.Restock > 0 then
            local primary = p.Restock[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Restock, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.5, "StorageRestocked", p)
        end
    end
    function Restaurant.HandleFarming()
        local p = Restaurant.ScanPrompts()
        if #p.Farm > 0 then
            local primary = p.Farm[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Farm, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CropsHarvested", p)
        end
    end
    function Restaurant.HandleExpansion()
        if not Config.AutoExpandEnabled then return false end
        local p = Restaurant.ScanPrompts()
        if #p.Expand == 0 then return false end

        for _, prompt in ipairs(p.Expand) do
            if isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                local combined = ((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "") .. " " .. (prompt.Parent and prompt.Parent.Name or "")):lower()
                local isFloor = combined:find("floor")
                local isLand = combined:find("land") or combined:find("plot") or combined:find("expand")

                local allowed = (isFloor and Config.AutoBuyFloors) or (isLand and Config.AutoBuyLand) or (not isFloor and not isLand and (Config.AutoBuyLand or Config.AutoBuyFloors))

                if allowed then
                    local price = Utility.ParsePrice(combined, prompt)
                    local canAfford, needed = Utility.CanAfford(price)
                    if canAfford then
                        local ok = executeAction(prompt, 6.0, "ExpansionsPurchased")
                        if ok then return true end
                    else
                        unaffordableBackoff[prompt] = os.clock() + (Config.AffordabilityBackoff or 30)
                    end
                end
            end
        end
        return false
    end

    local lastBuyCheck = 0
    function Restaurant.HandleAutoBuy()
        if not Config.AutoBuyEnabled then return false end
        local now = os.clock()
        if now - lastBuyCheck < 2.5 then return false end
        lastBuyCheck = now

        -- 1. Check in-world shop prompts
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Buy > 0 then
            for _, p in ipairs(prompts.Buy) do
                if isPromptReady(p) and not State.InFlightTasks[p] then
                    local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                    local isStove = text:find("stove") or text:find("oven")
                    local isGrill = text:find("grill") or text:find("fryer") or text:find("smoker")
                    local isTable = text:find("table") and not text:find("chair")
                    local isChair = text:find("chair") or text:find("seat") or text:find("stool") or text:find("booth") or text:find("bench")
                    local isAppliance = text:find("sink") or text:find("dish") or text:find("fridge") or text:find("cooler") or text:find("appliance")
                    local isCounter = text:find("counter") or text:find("prep") or text:find("station")
                    local isLighting = text:find("light") or text:find("lamp") or text:find("chandelier")
                    local isFurniture = text:find("furniture") or text:find("decor") or text:find("shelf") or text:find("plant") or text:find("tree") or text:find("painting")

                    local shouldBuy = (Config.AutoBuyStoves and isStove)
                                   or (Config.AutoBuyGrills and isGrill)
                                   or (Config.AutoBuyTables and isTable)
                                   or (Config.AutoBuyChairs and isChair)
                                   or (Config.AutoBuyAppliances and isAppliance)
                                   or (Config.AutoBuyCounters and isCounter)
                                   or (Config.AutoBuyLighting and isLighting)
                                   or (Config.AutoBuyFurniture and isFurniture)

                    if shouldBuy then
                        local price = Utility.ParsePrice(text, p)
                        local canAfford, needed = Utility.CanAfford(price)
                        if canAfford then
                            local ok = executeAction(p, 4.0, "ItemsPurchased")
                            if ok then return true end
                        else
                            unaffordableBackoff[p] = os.clock() + (Config.AffordabilityBackoff or 30)
                        end
                    end
                end
            end
        end

        -- 2. Check Shop GUI in PlayerGui
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local gpName = (btn.Parent and btn.Parent.Parent and btn.Parent.Parent.Name or ""):lower()

                    if (bText:find("buy") or bText:find("purchase") or bName:find("buy") or bName:find("purchase")) and not bText:find("robux") then
                        local combined = (bText .. " " .. bName .. " " .. pName .. " " .. gpName):lower()
                        local isStove = combined:find("stove") or combined:find("oven")
                        local isGrill = combined:find("grill") or combined:find("fryer") or combined:find("smoker")
                        local isTable = combined:find("table") and not combined:find("chair")
                        local isChair = combined:find("chair") or combined:find("seat") or combined:find("stool") or combined:find("booth") or combined:find("bench")
                        local isAppliance = combined:find("sink") or combined:find("dish") or combined:find("fridge") or combined:find("cooler")
                        local isCounter = combined:find("counter") or combined:find("prep") or combined:find("station")
                        local isLighting = combined:find("light") or combined:find("lamp")
                        local isFurniture = combined:find("furniture") or combined:find("decor") or combined:find("plant") or combined:find("tree")

                        local shouldBuy = (Config.AutoBuyStoves and isStove)
                                       or (Config.AutoBuyGrills and isGrill)
                                       or (Config.AutoBuyTables and isTable)
                                       or (Config.AutoBuyChairs and isChair)
                                       or (Config.AutoBuyAppliances and isAppliance)
                                       or (Config.AutoBuyCounters and isCounter)
                                       or (Config.AutoBuyLighting and isLighting)
                                       or (Config.AutoBuyFurniture and isFurniture)

                        if shouldBuy then
                            local price = Utility.ParsePrice(combined, btn)
                            local canAfford, needed = Utility.CanAfford(price)
                            if canAfford then
                                pcall(function()
                                    if type(firesignal) == "function" and btn.Activated then
                                        firesignal(btn.Activated)
                                    elseif btn.Activate then
                                        btn:Activate()
                                    end
                                end)
                                State.Stats.ItemsPurchased = State.Stats.ItemsPurchased + 1
                                task.wait(Config.PostActionDelay or 0.2)
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    local lastStaffCheck = 0
    function Restaurant.HandleStaffManage()
        if not Config.AutoHireStaffEnabled then return false end
        local now = os.clock()
        if now - lastStaffCheck < 3.5 then return false end
        lastStaffCheck = now

        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return false end

        for _, btn in ipairs(pg:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                local bName = btn.Name:lower()
                local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                local combined = (bText .. " " .. bName .. " " .. pName):lower()

                local isHire = (combined:find("hire") or combined:find("upgrade") or combined:find("recruit") or combined:find("level up")) and not combined:find("robux")
                if isHire then
                    local isCook = combined:find("cook") or combined:find("chef")
                    local isWaiter = combined:find("waiter") or combined:find("server")
                    local isCleaner = combined:find("clean") or combined:find("busser") or combined:find("janitor")

                    local shouldHire = (Config.AutoHireCooks and isCook)
                                    or (Config.AutoHireWaiters and isWaiter)
                                    or (Config.AutoHireCleaners and isCleaner)
                                    or (not isCook and not isWaiter and not isCleaner and (Config.AutoHireCooks or Config.AutoHireWaiters or Config.AutoHireCleaners))

                    if shouldHire then
                        local price = Utility.ParsePrice(combined, btn)
                        local canAfford, needed = Utility.CanAfford(price)
                        if canAfford then
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)
                            if State.Stats.StaffHired ~= nil then
                                State.Stats.StaffHired = State.Stats.StaffHired + 1
                            end
                            task.wait(Config.PostActionDelay or 0.2)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- Scan and group all currently available purchasable items & upgrades across world prompts and UI catalog
    function Restaurant.ScanAvailablePurchases()
        local results = {
            LandFloors = {},
            Cooking = {},
            Dining = {},
            Kitchen = {},
            Decor = {},
            Staff = {},
            All = {}
        }

        local seenNames = {}

        -- 1. Scan in-world Prompts (Expansion & Buy)
        local prompts = Restaurant.ScanPrompts()
        local candidatePrompts = {}
        for _, p in ipairs(prompts.Expand) do table.insert(candidatePrompts, { Prompt = p, Type = "Expand" }) end
        for _, p in ipairs(prompts.Buy) do table.insert(candidatePrompts, { Prompt = p, Type = "Buy" }) end

        for _, item in ipairs(candidatePrompts) do
            local p = item.Prompt
            local act = (p.ActionText or ""):lower()
            local obj = (p.ObjectText or p.Name or (p.Parent and p.Parent.Name or "")):lower()
            local combined = act .. " " .. obj
            local cleanTitle = (p.ObjectText and #p.ObjectText > 0) and p.ObjectText or (p.Parent and p.Parent.Name or "Item")
            if not seenNames[cleanTitle] then
                seenNames[cleanTitle] = true
                local price = Utility.ParsePrice(combined, p) or 0
                local canAfford, needed = Utility.CanAfford(price)
                local category = "Kitchen"
                local catLabel = "🍽️ Kitchen Equipment"

                if item.Type == "Expand" or combined:find("floor") or combined:find("land") or combined:find("expand") then
                    category = "LandFloors"
                    catLabel = "🏰 Land & Floors"
                elseif combined:find("stove") or combined:find("oven") or combined:find("grill") or combined:find("fryer") then
                    category = "Cooking"
                    catLabel = "🍳 Cooking Appliances"
                elseif combined:find("table") or combined:find("chair") or combined:find("stool") or combined:find("booth") then
                    category = "Dining"
                    catLabel = "🪑 Dining Furniture"
                elseif combined:find("decor") or combined:find("plant") or combined:find("light") or combined:find("paint") then
                    category = "Decor"
                    catLabel = "🌿 Decor & Aesthetics"
                end

                local entry = {
                    Title = cleanTitle,
                    Category = category,
                    CategoryLabel = catLabel,
                    Price = price,
                    PriceText = price > 0 and ("$" .. tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or "Free / Unknown",
                    CanAfford = canAfford,
                    Needed = needed,
                    Prompt = p,
                    Type = "Prompt"
                }

                table.insert(results[category], entry)
                table.insert(results.All, entry)
            end
        end

        -- 2. Scan PlayerGui Shop and Staff buttons
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local combined = (bText .. " " .. bName .. " " .. pName):lower()

                    local isBuy = (combined:find("buy") or combined:find("purchase")) and not combined:find("robux")
                    local isHire = (combined:find("hire") or combined:find("upgrade") or combined:find("recruit")) and not combined:find("robux")

                    if isBuy or isHire then
                        local rawText = btn:IsA("TextButton") and btn.Text or btn.Name
                        local cleanTitle = rawText:gsub("%$%s*[%d%,%.]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
                        if #cleanTitle > 2 and not seenNames[cleanTitle] then
                            seenNames[cleanTitle] = true
                            local price = Utility.ParsePrice(combined, btn) or 0
                            local canAfford, needed = Utility.CanAfford(price)
                            local category = "Kitchen"
                            local catLabel = "🍽️ Kitchen Equipment"

                            if isHire or combined:find("cook") or combined:find("waiter") or combined:find("cleaner") or combined:find("staff") then
                                category = "Staff"
                                catLabel = "👨‍🍳 Staff Personnel"
                            elseif combined:find("floor") or combined:find("land") or combined:find("expand") then
                                category = "LandFloors"
                                catLabel = "🏰 Land & Floors"
                            elseif combined:find("stove") or combined:find("oven") or combined:find("grill") or combined:find("fryer") then
                                category = "Cooking"
                                catLabel = "🍳 Cooking Appliances"
                            elseif combined:find("table") or combined:find("chair") or combined:find("stool") or combined:find("booth") then
                                category = "Dining"
                                catLabel = "🪑 Dining Furniture"
                            elseif combined:find("decor") or combined:find("plant") or combined:find("light") then
                                category = "Decor"
                                catLabel = "🌿 Decor & Aesthetics"
                            end

                            local entry = {
                                Title = cleanTitle,
                                Category = category,
                                CategoryLabel = catLabel,
                                Price = price,
                                PriceText = price > 0 and ("$" .. tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or "Free / In-Store",
                                CanAfford = canAfford,
                                Needed = needed,
                                Button = btn,
                                Type = "Button"
                            }

                            table.insert(results[category], entry)
                            table.insert(results.All, entry)
                        end
                    end
                end
            end
        end

        return results
    end

    local lastPlaceCheck = 0
    local placeGridIndex = 0
    function Restaurant.HandleAutoPlace()
        if not Config.AutoPlaceEnabled then return false end
        local now = os.clock()
        if now - lastPlaceCheck < 1.8 then return false end
        lastPlaceCheck = now

        -- 1. Check in-world "Place" / "Build" prompts on player's plot
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Place > 0 then
            for _, p in ipairs(prompts.Place) do
                if isPromptReady(p) and not State.InFlightTasks[p] then
                    local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                    local isTable = text:find("table")
                    local isChair = text:find("chair") or text:find("seat")
                    local isFurniture = text:find("furniture") or text:find("decor")

                    local shouldPlace = (Config.AutoPlaceTables and isTable)
                                     or (Config.AutoPlaceChairs and isChair)
                                     or (Config.AutoPlaceFurniture and isFurniture)
                                     or (not isTable and not isChair and not isFurniture)

                    if shouldPlace then
                        local ok = executeAction(p, 3.0, "ItemsPlaced")
                        if ok then return true end
                    end
                end
            end
        end

        -- 2. Check Build / Inventory GUI in PlayerGui for unplaced items
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local char, root = getAliveCharacter()
        local center = Restaurant.RestaurantCenter or (root and root.Position)
        if pg and center and char then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()

                    local isPlaceBtn = (bText == "place" or bText:find("place") or bName:find("place") or bText == "deploy" or bText == "build" or bText == "add") and not bText:find("cancel") and not bName:find("close")
                    if isPlaceBtn then
                        local combined = (bText .. " " .. bName .. " " .. pName):lower()
                        local isTable = combined:find("table")
                        local isChair = combined:find("chair") or combined:find("seat")
                        local isFurniture = combined:find("furniture") or combined:find("decor")

                        local shouldPlace = (Config.AutoPlaceTables and isTable)
                                         or (Config.AutoPlaceChairs and isChair)
                                         or (Config.AutoPlaceFurniture and isFurniture)
                                         or (not isTable and not isChair and not isFurniture)

                        if shouldPlace then
                            -- Trigger place button on item
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)

                            -- Calculate open floor grid coordinate near restaurant center
                            placeGridIndex = (placeGridIndex + 1) % 48
                            local ring = math.floor(placeGridIndex / 8) + 1
                            local angle = (placeGridIndex % 8) * (math.pi / 4)
                            local dist = ring * 6.5
                            local targetGridPos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                            local safeFloor = Utility.GetGroundPosition(targetGridPos, {char})

                            -- Teleport near position so placement raycasts succeed
                            if Config.AutoTeleportEnabled and root then
                                root.CFrame = CFrame.new(safeFloor + Vector3.new(0, 3, 0))
                                task.wait(0.15)
                            end

                            -- Check for placement confirm button in UI
                            for _, confirmBtn in ipairs(pg:GetDescendants()) do
                                if (confirmBtn:IsA("TextButton") or confirmBtn:IsA("ImageButton")) and confirmBtn.Visible then
                                    local cText = (confirmBtn:IsA("TextButton") and confirmBtn.Text or ""):lower()
                                    local cName = confirmBtn.Name:lower()
                                    if cText == "confirm" or cText == "✓" or cText:find("confirm") or cName:find("confirm") or cText == "place" then
                                        pcall(function()
                                            if type(firesignal) == "function" and confirmBtn.Activated then
                                                firesignal(confirmBtn.Activated)
                                            elseif confirmBtn.Activate then
                                                confirmBtn:Activate()
                                            end
                                        end)
                                        break
                                    end
                                end
                            end

                            -- Check ReplicatedStorage placement remote
                            local rs = game:GetService("ReplicatedStorage")
                            local placeRemote = rs:FindFirstChild("PlaceItem", true) or rs:FindFirstChild("PlaceObject", true) or rs:FindFirstChild("PlaceFurniture", true) or rs:FindFirstChild("BuildItem", true)
                            if placeRemote and placeRemote:IsA("RemoteEvent") then
                                pcall(function()
                                    placeRemote:FireServer(bName, CFrame.new(safeFloor))
                                end)
                            end

                            State.Stats.ItemsPlaced = State.Stats.ItemsPlaced + 1
                            task.wait(Config.PostActionDelay or 0.2)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- Auto-do and auto-claim quests, tasks, and daily objectives
    local lastQuestAutomation = 0
    function Restaurant.HandleQuestAutomation()
        if not Config.MasterAutoFarmEnabled and not Config.AutoClaimQuestsEnabled and not Config.AutoDoQuestsEnabled then
            return false
        end

        local now = os.clock()
        if now - lastQuestAutomation < 2.5 then return false end
        lastQuestAutomation = now

        -- 1. Auto-claim all finished quests, goals, milestones, and playtime rewards
        if Config.MasterAutoFarmEnabled or Config.AutoClaimQuestsEnabled then
            pcall(function()
                local claimed = Utility.ClaimAllRewards()
                if claimed and claimed > 0 then
                    State.Stats.QuestsClaimed = (State.Stats.QuestsClaimed or 0) + claimed
                end
            end)
        end

        -- 2. Auto-accept new quests and parse active quest directives
        if Config.MasterAutoFarmEnabled or Config.AutoDoQuestsEnabled then
            pcall(function()
                local directives = Utility.AcceptAndDoQuests()
                if directives then
                    if directives.Buy then pcall(Restaurant.HandleAutoBuy) end
                    if directives.Place then pcall(Restaurant.HandleAutoPlace) end
                    if directives.Staff then pcall(Restaurant.HandleStaffManage) end
                end
            end)
        end

        return true
    end

    -- Interleaved multi-queue pipeline categories definition
    local pipelineCategories = {
        { name = "Serve", configKey = "AutoServeEnabled", stat = "DishesServed", cooldown = 2.5 },
        { name = "Cook", configKey = "AutoCookEnabled", stat = "DishesCooked", cooldown = 2.5 },
        { name = "Order", configKey = "AutoOrderEnabled", stat = "OrdersTaken", cooldown = 2.5 },
        { name = "Clean", configKey = "AutoCleanEnabled", stat = "TablesCleaned", cooldown = 3.0 },
        { name = "Seat", configKey = "AutoSeatEnabled", stat = "CustomersSeated", cooldown = 3.0 },
        { name = "Cash", configKey = "AutoCollectCashEnabled", stat = "CashCollected", cooldown = 3.0 },
        { name = "Quest", configKey = "AutoDoQuestsEnabled", stat = "QuestsCompleted", cooldown = 3.0 },
        { name = "Delivery", configKey = "AutoDeliveryEnabled", stat = "DeliveriesCompleted", cooldown = 4.0 },
        { name = "Restock", configKey = "AutoRestockEnabled", stat = "StorageRestocked", cooldown = 3.5 },
        { name = "Farm", configKey = "AutoFarmEnabled", stat = "CropsHarvested", cooldown = 3.0 },
        { name = "Expand", configKey = "AutoExpandEnabled", stat = "ExpansionsPurchased", cooldown = 6.0, requireExplicit = true },
    }
    local pipelineCursor = 1

    -- Interleaved multi-queue scheduler: Dispatches next ready category round-robin to eliminate starvation
    function Restaurant.DispatchInterleavedPipeline(prompts)
        local isMaster = Config.MasterAutoFarmEnabled
        local totalCategories = #pipelineCategories

        for i = 0, totalCategories - 1 do
            local idx = ((pipelineCursor - 1 + i) % totalCategories) + 1
            local cat = pipelineCategories[idx]

            local isCategoryEnabled = cat.requireExplicit and Config[cat.configKey] or (isMaster or Config[cat.configKey])

            if isCategoryEnabled and prompts[cat.name] and #prompts[cat.name] > 0 then
                -- Find first ready prompt that is not currently in flight and is affordable if it's Expand/Buy
                local primaryPrompt = nil
                for _, p in ipairs(prompts[cat.name]) do
                    if isPromptReady(p) and not State.InFlightTasks[p] then
                        if cat.name == "Expand" or cat.name == "Buy" then
                            if isPromptAffordable(p) then
                                primaryPrompt = p
                                break
                            end
                        else
                            primaryPrompt = p
                            break
                        end
                    end
                end

                if primaryPrompt then
                    if Config.ConcurrentExecutionEnabled then
                        local cluster = Restaurant.GetNearbyCluster(primaryPrompt, prompts[cat.name], 14, Config.StationBatchSize or 3)
                        executeCluster(primaryPrompt, cluster, cat.cooldown, cat.stat, prompts)
                    else
                        executeAction(primaryPrompt, cat.cooldown, cat.stat)
                    end

                    -- Advance cursor to next category for balanced, starvation-free progression
                    pipelineCursor = (idx % totalCategories) + 1
                    return true
                end
            end
        end

        return false
    end

    -- Master Autonomous Dispatcher & Parallel Workers
    local runningLoop = false
    function Restaurant.StartLoop()
        if runningLoop then return end
        runningLoop = true

        -- Decoupled Worker 1: Parallel Floor Cash Sweeper (Continuous remote pickup via firetouchinterest)
        task.spawn(function()
            while Core.State.Running and runningLoop do
                if Config.MasterAutoFarmEnabled or Config.AutoCollectCashEnabled then
                    pcall(function()
                        Restaurant.SweepFloorCash()
                    end)
                end
                task.wait(0.35)
            end
        end)

        -- Decoupled Worker 2: Parallel Background UI Manager (Quests, Daily Gifts, Staff, UI Catalog)
        task.spawn(function()
            while Core.State.Running and runningLoop do
                -- Auto-claim all quests, gifts, daily rewards, and auto-do quest actions
                local now = os.clock()
                if (Config.MasterAutoFarmEnabled or Config.AutoClaimRewardsEnabled or Config.AutoClaimQuestsEnabled or Config.AutoDoQuestsEnabled) and (now - lastQuestCheck > 3) then
                    lastQuestCheck = now
                    pcall(function()
                        Restaurant.HandleQuestAutomation()
                    end)
                end

                -- Auto-hire / upgrade staff in background without interrupting kitchen
                if Config.AutoHireStaffEnabled then
                    pcall(function()
                        Restaurant.HandleStaffManage()
                    end)
                end

                -- Auto-buy catalog items if enabled
                if Config.AutoBuyEnabled then
                    pcall(function()
                        Restaurant.HandleAutoBuy()
                    end)
                end

                task.wait(2.5)
            end
        end)

        -- Master Worker 3: Physical Workstation Automation Loop
        task.spawn(function()
            while Core.State.Running and runningLoop do
                local delayTime = math.clamp(Config.ActionDelay or 0.3, 0.05, 5)

                -- Run memory sanitation
                cleanExpiredCooldowns()

                local char, _, hum = getAliveCharacter()
                if char and hum and hum.Health > 0 then
                    local prompts = Restaurant.ScanPrompts()
                    local dispatched = false

                    if Config.InterleavedPipelineEnabled then
                        dispatched = Restaurant.DispatchInterleavedPipeline(prompts)
                    else
                        -- Fallback: Classical single/cluster prioritized ladder
                        local isMaster = Config.MasterAutoFarmEnabled
                        local function dispatchCategory(list, cooldown, statKey)
                            for _, p in ipairs(list) do
                                if isPromptReady(p) and not State.InFlightTasks[p] then
                                    if Config.ConcurrentExecutionEnabled then
                                        local cluster = Restaurant.GetNearbyCluster(p, list, 14, Config.StationBatchSize or 3)
                                        return executeCluster(p, cluster, cooldown, statKey, prompts)
                                    else
                                        return executeAction(p, cooldown, statKey)
                                    end
                                end
                            end
                            return false
                        end

                        if (isMaster or Config.AutoCollectCashEnabled) and #prompts.Cash > 0 then
                            dispatched = dispatchCategory(prompts.Cash, 3.0, "CashCollected")
                        elseif (isMaster or Config.AutoOrderEnabled) and #prompts.Order > 0 then
                            dispatched = dispatchCategory(prompts.Order, 2.5, "OrdersTaken")
                        elseif (isMaster or Config.AutoServeEnabled) and #prompts.Serve > 0 then
                            dispatched = dispatchCategory(prompts.Serve, 2.5, "DishesServed")
                        elseif (isMaster or Config.AutoCookEnabled) and #prompts.Cook > 0 then
                            dispatched = dispatchCategory(prompts.Cook, 2.5, "DishesCooked")
                        elseif (isMaster or Config.AutoCleanEnabled) and #prompts.Clean > 0 then
                            dispatched = dispatchCategory(prompts.Clean, 3.0, "TablesCleaned")
                        elseif (isMaster or Config.AutoSeatEnabled) and #prompts.Seat > 0 then
                            dispatched = dispatchCategory(prompts.Seat, 3.0, "CustomersSeated")
                        elseif (isMaster or Config.AutoDoQuestsEnabled) and #prompts.Quest > 0 then
                            dispatched = dispatchCategory(prompts.Quest, 3.0, "QuestsCompleted")
                        elseif (isMaster or Config.AutoDeliveryEnabled) and #prompts.Delivery > 0 then
                            dispatched = dispatchCategory(prompts.Delivery, 4.0, "DeliveriesCompleted")
                        elseif (isMaster or Config.AutoRestockEnabled) and #prompts.Restock > 0 then
                            dispatched = dispatchCategory(prompts.Restock, 3.5, "StorageRestocked")
                        elseif (isMaster or Config.AutoFarmEnabled) and #prompts.Farm > 0 then
                            dispatched = dispatchCategory(prompts.Farm, 3.0, "CropsHarvested")
                        elseif (isMaster or Config.AutoPlaceEnabled) and Restaurant.HandleAutoPlace() then
                            dispatched = true
                        elseif Config.AutoExpandEnabled and #prompts.Expand > 0 then
                            for _, p in ipairs(prompts.Expand) do
                                if isPromptAffordable(p) then
                                    dispatched = dispatchCategory({p}, 6.0, "ExpansionsPurchased")
                                    if dispatched then break end
                                end
                            end
                        end
                    end

                    -- Auto-place check if not already handled
                    if not dispatched and (Config.MasterAutoFarmEnabled or Config.AutoPlaceEnabled) then
                        pcall(function()
                            Restaurant.HandleAutoPlace()
                        end)
                    end
                end

                task.wait(delayTime)
            end
            runningLoop = false
        end)
    end

    function Restaurant.Init()
        Restaurant.GetPlayerPlot()
        Restaurant.StartLoop()
        print("🍽️ Run a Restaurant autonomous engine initialized successfully.")
    end

    function Restaurant.Cleanup()
        runningLoop = false
        cachedPlot = nil
        Restaurant.RestaurantCenter = nil
        table.clear(promptCooldowns)
        table.clear(State.InFlightTasks)

        local _, root = getAliveCharacter()
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    return Restaurant
end
