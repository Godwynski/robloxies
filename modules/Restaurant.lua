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

    local function isPromptReady(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        local exp = promptCooldowns[prompt]
        if exp and os.clock() < exp then return false end
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

                    if combined:find("tip") or combined:find("cash") or combined:find("register") or combined:find("collect") or combined:find("money") then
                        table.insert(categorized.Cash, obj)
                    elseif combined:find("order") or combined:find("menu") or combined:find("ticket") or combined:find("take order") then
                        table.insert(categorized.Order, obj)
                    elseif combined:find("cook") or combined:find("prepare") or combined:find("bake") or combined:find("grill") or combined:find("stove") or combined:find("oven") then
                        table.insert(categorized.Cook, obj)
                    elseif combined:find("serve") or combined:find("deliver") or combined:find("bring") or combined:find("plate") or combined:find("dish") then
                        table.insert(categorized.Serve, obj)
                    elseif combined:find("clean") or combined:find("wash") or combined:find("wipe") or combined:find("dirty") or combined:find("bus") or combined:find("trash") or combined:find("sink") then
                        table.insert(categorized.Clean, obj)
                    elseif combined:find("seat") or combined:find("host") or combined:find("welcome") or combined:find("customer") or combined:find("guest") then
                        table.insert(categorized.Seat, obj)
                    elseif combined:find("package") or combined:find("box") or combined:find("scooter") or combined:find("takeout") or combined:find("delivery") then
                        table.insert(categorized.Delivery, obj)
                    elseif combined:find("restock") or combined:find("deposit") or combined:find("fridge") or combined:find("cooler") or combined:find("pantry") then
                        table.insert(categorized.Restock, obj)
                    elseif combined:find("harvest") or combined:find("crop") or combined:find("wheat") or combined:find("plant") or combined:find("gather") or combined:find("pick") then
                        table.insert(categorized.Farm, obj)
                    elseif combined:find("place") or combined:find("build") or combined:find("assemble") or combined:find("put down") then
                        table.insert(categorized.Place, obj)
                    elseif (combined:find("buy") or combined:find("purchase")) and not combined:find("floor") and not combined:find("expand") then
                        table.insert(categorized.Buy, obj)
                    elseif combined:find("expand") or combined:find("floor") or combined:find("unlock") or combined:find("purchase") or combined:find("buy") then
                        table.insert(categorized.Expand, obj)
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

    -- Execute a single action cleanly with stability delay
    local function executeAction(prompt, cooldown, statKey)
        if not prompt or not prompt.Parent then return false end

        -- 1. Teleport safely if enabled
        if Config.AutoTeleportEnabled then
            local ok = Restaurant.TeleportTo(prompt)
            if ok then
                task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
            end
        end

        -- 2. Trigger prompt
        triggerPrompt(prompt, cooldown or 2.5)

        -- 3. Increment statistics
        if statKey and State.Stats[statKey] ~= nil then
            State.Stats[statKey] = State.Stats[statKey] + 1
        end

        task.wait(0.1)
        return true
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
                            if count >= 8 then break end
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
        if #p.Cash > 0 then executeAction(p.Cash[1], 3.0, "CashCollected") end
        Restaurant.SweepFloorCash()
    end
    function Restaurant.HandleOrdering()
        local p = Restaurant.ScanPrompts()
        if #p.Order > 0 then executeAction(p.Order[1], 2.5, "OrdersTaken") end
    end
    function Restaurant.HandleCooking()
        local p = Restaurant.ScanPrompts()
        if #p.Cook > 0 then executeAction(p.Cook[1], 2.5, "DishesCooked") end
    end
    function Restaurant.HandleServing()
        local p = Restaurant.ScanPrompts()
        if #p.Serve > 0 then executeAction(p.Serve[1], 2.5, "DishesServed") end
    end
    function Restaurant.HandleCleaning()
        local p = Restaurant.ScanPrompts()
        if #p.Clean > 0 then executeAction(p.Clean[1], 3.0, "TablesCleaned") end
    end
    function Restaurant.HandleSeating()
        local p = Restaurant.ScanPrompts()
        if #p.Seat > 0 then executeAction(p.Seat[1], 3.0, "CustomersSeated") end
    end
    function Restaurant.HandleDelivery()
        local p = Restaurant.ScanPrompts()
        if #p.Delivery > 0 then executeAction(p.Delivery[1], 4.0, "DeliveriesCompleted") end
    end
    function Restaurant.HandleRestock()
        local p = Restaurant.ScanPrompts()
        if #p.Restock > 0 then executeAction(p.Restock[1], 3.5, "StorageRestocked") end
    end
    function Restaurant.HandleFarming()
        local p = Restaurant.ScanPrompts()
        if #p.Farm > 0 then executeAction(p.Farm[1], 3.0, "CropsHarvested") end
    end
    function Restaurant.HandleExpansion()
        local p = Restaurant.ScanPrompts()
        if #p.Expand > 0 then executeAction(p.Expand[1], 6.0, "ExpansionsPurchased") end
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
                local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                local isStove = text:find("stove") or text:find("oven") or text:find("grill")
                local isTable = text:find("table") or text:find("chair") or text:find("seat")
                local isAppliance = text:find("sink") or text:find("dish") or text:find("fridge") or text:find("cooler") or text:find("appliance")

                local shouldBuy = (Config.AutoBuyStoves and isStove) or (Config.AutoBuyTables and isTable) or (Config.AutoBuyAppliances and isAppliance) or (not isStove and not isTable and not isAppliance)
                if shouldBuy then
                    local ok = executeAction(p, 4.0, "ItemsPurchased")
                    if ok then return true end
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
                        local isStove = combined:find("stove") or combined:find("oven") or combined:find("grill")
                        local isTable = combined:find("table") or combined:find("chair")
                        local isAppliance = combined:find("sink") or combined:find("dish") or combined:find("fridge")

                        if (Config.AutoBuyStoves and isStove) or (Config.AutoBuyTables and isTable) or (Config.AutoBuyAppliances and isAppliance) or (not isStove and not isTable and not isAppliance) then
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)
                            State.Stats.ItemsPurchased = State.Stats.ItemsPurchased + 1
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local lastPlaceCheck = 0
    local placeGridIndex = 0
    function Restaurant.HandleAutoPlace()
        if not Config.AutoPlaceEnabled then return false end
        local now = os.clock()
        if now - lastPlaceCheck < 2.0 then return false end
        lastPlaceCheck = now

        -- 1. Check in-world "Place" / "Build" prompts on player's plot
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Place > 0 then
            local ok = executeAction(prompts.Place[1], 3.0, "ItemsPlaced")
            if ok then return true end
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

                    if (bText == "place" or bText:find("place") or bName:find("place") or bText == "deploy" or bText == "build") and not bText:find("cancel") and not bName:find("close") then
                        -- Trigger place button on item
                        pcall(function()
                            if type(firesignal) == "function" and btn.Activated then
                                firesignal(btn.Activated)
                            elseif btn.Activate then
                                btn:Activate()
                            end
                        end)

                        -- Calculate open floor grid coordinate near restaurant center
                        placeGridIndex = (placeGridIndex + 1) % 36
                        local ring = math.floor(placeGridIndex / 8) + 1
                        local angle = (placeGridIndex % 8) * (math.pi / 4)
                        local dist = ring * 7
                        local targetGridPos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                        local safeFloor = Utility.GetGroundPosition(targetGridPos, {char})

                        -- Teleport near position so placement raycasts succeed
                        if Config.AutoTeleportEnabled and root then
                            root.CFrame = CFrame.new(safeFloor + Vector3.new(0, 3, 0))
                            task.wait(0.12)
                        end

                        -- Check for placement confirm button in UI
                        for _, confirmBtn in ipairs(pg:GetDescendants()) do
                            if (confirmBtn:IsA("TextButton") or confirmBtn:IsA("ImageButton")) and confirmBtn.Visible then
                                local cText = (confirmBtn:IsA("TextButton") and confirmBtn.Text or ""):lower()
                                local cName = confirmBtn.Name:lower()
                                if cText == "confirm" or cText == "✓" or cText:find("confirm") or cName:find("confirm") then
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
                        return true
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
        if now - lastStaffCheck < 4.0 then return false end
        lastStaffCheck = now

        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return false end

        for _, btn in ipairs(pg:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                local name = btn.Name:lower()
                local pName = (btn.Parent and btn.Parent.Name or ""):lower()

                if (text:find("hire") or text:find("recruit") or name:find("hire") or (pName:find("staff") and text:find("upgrade"))) and not text:find("robux") then
                    pcall(function()
                        if type(firesignal) == "function" and btn.Activated then
                            firesignal(btn.Activated)
                        elseif btn.Activate then
                            btn:Activate()
                        end
                        State.Stats.StaffHired = State.Stats.StaffHired + 1
                    end)
                    return true
                end
            end
        end
        return false
    end

    -- Master Autonomous Priority Dispatcher Loop
    local runningLoop = false
    function Restaurant.StartLoop()
        if runningLoop then return end
        runningLoop = true

        task.spawn(function()
            while Core.State.Running and runningLoop do
                local delayTime = math.clamp(Config.ActionDelay or 0.3, 0.05, 5)

                -- Run memory sanitation
                cleanExpiredCooldowns()

                -- Auto-claim finished quests / gifts every 10 seconds
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
                    local isMaster = Config.MasterAutoFarmEnabled
                    local prompts = Restaurant.ScanPrompts()

                    -- Prioritized Single-Action Dispatch: Attends to ONE highest-priority task per tick
                    -- 1. Cash & Tips: Immediate payout, frees tables & registers
                    if (isMaster or Config.AutoCollectCashEnabled) and #prompts.Cash > 0 then
                        executeAction(prompts.Cash[1], 3.0, "CashCollected")

                    -- 2. Customer Orders: Frees customer wait timer, creates tickets
                    elseif (isMaster or Config.AutoOrderEnabled) and #prompts.Order > 0 then
                        executeAction(prompts.Order[1], 2.5, "OrdersTaken")

                    -- 3. Serve Prepared Dishes: Clears counters and delivers to hungry customers
                    elseif (isMaster or Config.AutoServeEnabled) and #prompts.Serve > 0 then
                        executeAction(prompts.Serve[1], 2.5, "DishesServed")

                    -- 4. Cook Food: Prepares tickets on stoves/ovens
                    elseif (isMaster or Config.AutoCookEnabled) and #prompts.Cook > 0 then
                        executeAction(prompts.Cook[1], 2.5, "DishesCooked")

                    -- 5. Clean Tables: Clears dirty dishes so new customers can sit
                    elseif (isMaster or Config.AutoCleanEnabled) and #prompts.Clean > 0 then
                        executeAction(prompts.Clean[1], 3.0, "TablesCleaned")

                    -- 6. Seat Customers: Brings waiting customers to open tables
                    elseif (isMaster or Config.AutoSeatEnabled) and #prompts.Seat > 0 then
                        executeAction(prompts.Seat[1], 3.0, "CustomersSeated")

                    -- 7. Delivery Orders: High multiplier takeout fulfillment
                    elseif (isMaster or Config.AutoDeliveryEnabled) and #prompts.Delivery > 0 then
                        executeAction(prompts.Delivery[1], 4.0, "DeliveriesCompleted")

                    -- 8. Restock Storage: Keeps kitchen supplied with ingredients
                    elseif (isMaster or Config.AutoRestockEnabled) and #prompts.Restock > 0 then
                        executeAction(prompts.Restock[1], 3.5, "StorageRestocked")

                    -- 9. Farm Harvesting: Gathers ripe crops
                    elseif (isMaster or Config.AutoFarmEnabled) and #prompts.Farm > 0 then
                        executeAction(prompts.Farm[1], 3.0, "CropsHarvested")

                    -- 10. Auto-Place stored furniture & appliances
                    elseif (isMaster or Config.AutoPlaceEnabled) and Restaurant.HandleAutoPlace() then
                        -- handled in HandleAutoPlace

                    -- 11. Auto-Buy equipment & appliances
                    elseif (isMaster or Config.AutoBuyEnabled) and Restaurant.HandleAutoBuy() then
                        -- handled in HandleAutoBuy

                    -- 12. Auto-Hire & Upgrade staff
                    elseif Config.AutoHireStaffEnabled and Restaurant.HandleStaffManage() then
                        -- handled in HandleStaffManage

                    -- 13. Floor & Land Expansion
                    elseif Config.AutoExpandEnabled and #prompts.Expand > 0 then
                        executeAction(prompts.Expand[1], 6.0, "ExpansionsPurchased")

                    else
                        -- When idle, sweep floor cash
                        if (isMaster or Config.AutoCollectCashEnabled) then
                            Restaurant.SweepFloorCash()
                        end
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
