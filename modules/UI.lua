return function(Core)
    local UI = {}
    local Config = Core.Config
    local Utility = Core.Utility
    local State = Core.State

    function UI.Init()
        local UILibrary = loadModule("modules.UILibrary")(Core)
        UI.Library = UILibrary

        -- Create main production window
        local Window = UILibrary:CreateWindow("Run a Restaurant")
        UI.Window = Window

        function UI.UpdateStatus()
            local active = Config.MasterAutoFarmEnabled or Config.AutoSeatEnabled or Config.AutoOrderEnabled or
                           Config.AutoCookEnabled or Config.AutoServeEnabled or Config.AutoCleanEnabled or
                           Config.AutoCollectCashEnabled or Config.AutoFarmEnabled or Config.AutoDeliveryEnabled or
                           Config.AutoRestockEnabled or Config.AutoDoQuestsEnabled or Config.AutoClaimQuestsEnabled or
                           Config.WalkSpeedEnabled or Config.JumpPowerEnabled or Config.NoClipEnabled or Config.InfiniteJumpEnabled

            local text = Config.MasterAutoFarmEnabled and "FARMING" or (active and "ACTIVE" or "IDLE")
            Window:UpdateStatus(active, text)
        end

        -- =====================================================================
        -- 1. DASHBOARD & LIVE ANALYTICS TAB
        -- =====================================================================
        function UI.BuildDashboardTab()
            local DashTab = Window:AddTab("Dashboard", "📊")

            -- Hero Master Automation Card
            local heroCard = DashTab:AddHeroCard({
                Icon = "⚡",
                Title = "Master Restaurant Auto-Farm",
                Subtitle = "Synchronizes seating, ordering, cooking, serving, cleaning, cash sweeping, and auto doing & claiming quests.",
                InitialState = Config.MasterAutoFarmEnabled,
                OnToggle = function(state)
                    Config.MasterAutoFarmEnabled = state
                    if state then
                        Config.AutoDoQuestsEnabled = true
                        Config.AutoClaimQuestsEnabled = true
                    end
                    UI.UpdateStatus()
                    Window:Notify({
                        Title = state and "Auto-Farm Activated" or "Auto-Farm Paused",
                        Content = state and "All kitchen, dining, quest completion, and reward claiming workflows are running." or "All restaurant tasks paused.",
                        Type = state and "Success" or "Info",
                        Duration = 3.5
                    })
                end
            })

            -- Live Analytics Metric Grid
            DashTab:AddSection("LIVE RESTAURANT ANALYTICS", "📈")
            local metricGrid = DashTab:AddMetricGrid()

            metricGrid:AddMetric("Cash", "💵", "Cash Swept", 0, Color3.fromRGB(34, 197, 94))
            metricGrid:AddMetric("Rewards", "🎁", "Rewards Claimed", 0, Color3.fromRGB(245, 158, 11))
            metricGrid:AddMetric("Quests", "📜", "Quests Done", 0, Color3.fromRGB(168, 85, 247))
            metricGrid:AddMetric("Seated", "👥", "Guests Seated", 0, Color3.fromRGB(59, 130, 246))
            metricGrid:AddMetric("Orders", "📋", "Orders Processed", 0, Color3.fromRGB(217, 70, 239))
            metricGrid:AddMetric("Cooked", "🍳", "Dishes Cooked", 0, Color3.fromRGB(249, 115, 22))
            metricGrid:AddMetric("Served", "🍽️", "Dishes Served", 0, Color3.fromRGB(16, 185, 129))
            metricGrid:AddMetric("Cleaned", "🧼", "Tables Cleaned", 0, Color3.fromRGB(6, 182, 212))
            metricGrid:AddMetric("Deliveries", "📦", "Deliveries Done", 0, Color3.fromRGB(234, 179, 8))
            metricGrid:AddMetric("Harvested", "🌾", "Crops Harvested", 0, Color3.fromRGB(132, 204, 22))
            metricGrid:AddMetric("Restocked", "🧊", "Storage Restocked", 0, Color3.fromRGB(14, 165, 233))
            metricGrid:AddMetric("Expansions", "🏰", "Expansions", 0, Color3.fromRGB(139, 92, 246))
            metricGrid:AddMetric("Purchased", "🛒", "Items Bought", 0, Color3.fromRGB(236, 72, 153))
            metricGrid:AddMetric("Placed", "🔨", "Items Placed", 0, Color3.fromRGB(20, 184, 166))
            metricGrid:AddMetric("Staff", "👨‍🍳", "Staff Hired", 0, Color3.fromRGB(244, 63, 94))

            -- Background Loop for Live Telemetry (Uptime, Rate, Metric counters)
            task.spawn(function()
                local startTime = State.StartTime or tick()
                while State.Running do
                    pcall(function()
                        local s = State.Stats
                        local elapsed = math.max(1, tick() - startTime)
                        local hours = math.floor(elapsed / 3600)
                        local mins = math.floor((elapsed % 3600) / 60)
                        local secs = math.floor(elapsed % 60)
                        local uptimeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

                        -- Rate estimation: items swept per hour
                        local ratePerHour = math.floor(((s.CashCollected or 0) / elapsed) * 3600)
                        heroCard.SetInfo(string.format("⏱ Uptime: %s  •  Rate: ~%d items/hr", uptimeStr, ratePerHour))

                        -- Update metrics
                        local totalRewards = (s.RewardsClaimed or 0) + (s.QuestsClaimed or 0)
                        metricGrid:UpdateMetric("Cash", string.format("%d items", s.CashCollected or 0))
                        metricGrid:UpdateMetric("Rewards", totalRewards)
                        metricGrid:UpdateMetric("Quests", s.QuestsCompleted or 0)
                        metricGrid:UpdateMetric("Seated", s.CustomersSeated or 0)
                        metricGrid:UpdateMetric("Orders", s.OrdersTaken or 0)
                        metricGrid:UpdateMetric("Cooked", s.DishesCooked or 0)
                        metricGrid:UpdateMetric("Served", s.DishesServed or 0)
                        metricGrid:UpdateMetric("Cleaned", s.TablesCleaned or 0)
                        metricGrid:UpdateMetric("Deliveries", s.DeliveriesCompleted or 0)
                        metricGrid:UpdateMetric("Harvested", s.CropsHarvested or 0)
                        metricGrid:UpdateMetric("Restocked", s.StorageRestocked or 0)
                        metricGrid:UpdateMetric("Expansions", s.ExpansionsPurchased or 0)
                        metricGrid:UpdateMetric("Purchased", s.ItemsPurchased or 0)
                        metricGrid:UpdateMetric("Placed", s.ItemsPlaced or 0)
                        metricGrid:UpdateMetric("Staff", s.StaffHired or 0)
                    end)
                    task.wait(0.6)
                end
            end)

            -- Quick Dispatch Actions
            DashTab:AddSection("QUICK COMMANDS", "⚡")
            DashTab:AddButton("⚡ Trigger All Workstations Now", "Immediately dispatches all cooking, serving, cleaning, and seating routines.", "Primary", function()
                if Core.Restaurant then
                    pcall(Core.Restaurant.HandleRestock)
                    pcall(Core.Restaurant.HandleFarming)
                    pcall(Core.Restaurant.HandleDelivery)
                    pcall(Core.Restaurant.HandleCashCollection)
                    pcall(Core.Restaurant.HandleCleaning)
                    pcall(Core.Restaurant.HandleSeating)
                    pcall(Core.Restaurant.HandleOrdering)
                    pcall(Core.Restaurant.HandleCooking)
                    pcall(Core.Restaurant.HandleServing)
                    Window:Notify({Title = "Workstations Dispatched", Content = "Triggered all active station queues.", Type = "Success", Duration = 2.5})
                end
            end)

            DashTab:AddButton("📍 Set Restaurant Anchor Here", "Calibrates your plot center to avatar position, preventing cross-plot drift.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.RecalibrateAnchor then
                    local ok = Core.Restaurant.RecalibrateAnchor()
                    Window:Notify({
                        Title = ok and "Anchor Calibrated" or "Calibration Failed",
                        Content = ok and "Restaurant anchor successfully locked." or "Could not calibrate plot anchor.",
                        Type = ok and "Success" or "Error",
                        Duration = 3
                    })
                end
            end)

            DashTab:AddButton("🎁 Claim All Rewards & Gifts Now", "Claims pending daily gifts, playtime rewards, and quest achievements.", "Secondary", function()
                local count = Utility.ClaimAllRewards()
                Window:Notify({
                    Title = "Rewards Claimed",
                    Content = (count and count > 0) and string.format("Successfully redeemed %d rewards!", count) or "All rewards already claimed.",
                    Type = "Success",
                    Duration = 3
                })
            end)
        end

        -- =====================================================================
        -- 2. RESTAURANT OPERATIONS TAB
        -- =====================================================================
        function UI.BuildRestaurantTab()
            local RestTab = Window:AddTab("Restaurant", "🍳")

            -- Kitchen & Dining Operations
            RestTab:AddSection("KITCHEN & DINING OPERATIONS", "🍽️")
            RestTab:AddToggle("Auto-Seat Customers", "Detects waiting guests at host stand and escorts them to vacant tables.", Config.AutoSeatEnabled, function(val)
                Config.AutoSeatEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Take Orders", "Takes food orders from seated tables the moment they are ready.", Config.AutoOrderEnabled, function(val)
                Config.AutoOrderEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Cook Food", "Operates cooking stoves, grills, and ovens to prepare customer food tickets.", Config.AutoCookEnabled, function(val)
                Config.AutoCookEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Serve Dishes", "Delivers finished meals from the kitchen counter directly to tables.", Config.AutoServeEnabled, function(val)
                Config.AutoServeEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Clean Tables", "Clears dirty dishes and sanitizes tables immediately after guests depart.", Config.AutoCleanEnabled, function(val)
                Config.AutoCleanEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Collect Cash & Tips", "Continuously sweeps dropped coins, tip jars, and register earnings.", Config.AutoCollectCashEnabled, function(val)
                Config.AutoCollectCashEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("VIP & Celebrity Customer Priority", "Sorts and attends to VIP and gold customers first for massive tip multipliers.", Config.VIPPriorityEnabled, function(val)
                Config.VIPPriorityEnabled = val
            end)

            -- Supply & Extra Revenue
            RestTab:AddSection("SUPPLY & EXTRA REVENUE", "📦")
            RestTab:AddToggle("Auto-Fulfill Delivery Orders", "Packages delivery meals and loads scooters for high cash multipliers.", Config.AutoDeliveryEnabled, function(val)
                Config.AutoDeliveryEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Restock Kitchen Storage", "Deposits harvested produce into fridges and pantries for chefs.", Config.AutoRestockEnabled, function(val)
                Config.AutoRestockEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Harvest Farm & Ranch", "Gathers wheat, tomatoes, and animal goods from your farm plot.", Config.AutoFarmEnabled, function(val)
                Config.AutoFarmEnabled = val
                UI.UpdateStatus()
            end)

            -- Quests & Tasks Automation
            RestTab:AddSection("QUESTS & TASKS AUTOMATION", "📜")
            RestTab:AddToggle("Auto-Do Quests", "Automatically fulfills active quest objectives, talks to quest NPCs, and prioritizes quest tasks.", Config.AutoDoQuestsEnabled, function(val)
                Config.AutoDoQuestsEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Claim Quests & Goals", "Automatically claims completed quests, daily tasks, and milestone rewards.", Config.AutoClaimQuestsEnabled, function(val)
                Config.AutoClaimQuestsEnabled = val
                UI.UpdateStatus()
            end)

            -- Workstation Actions
            RestTab:AddSection("WORKSTATION ACTIONS", "📍")
            RestTab:AddButton("Teleport to Restaurant Center", "Safely moves avatar to calibrated center with floor raycasting.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.RestaurantCenter then
                    local char = Core.Services.Players.LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(Core.Restaurant.RestaurantCenter + Vector3.new(0, 3, 0))
                        Window:Notify({Title = "Teleported", Content = "Arrived at restaurant center.", Type = "Info", Duration = 2})
                    end
                end
            end)
        end

        -- =====================================================================
        -- 3. BUILD & STAFF MANAGEMENT TAB
        -- =====================================================================
        -- 3. BUILD, EXPANSION & STAFF TAB
        -- =====================================================================
        function UI.BuildBuildTab()
            local BuildTab = Window:AddTab("Build/Staff", "🏗️")

            -- Budget & Affordability Safety
            BuildTab:AddSection("BUDGET & AFFORDABILITY SAFETY", "🛡️")
            local balancePara = BuildTab:AddParagraph("💵 Detected Balance & Safety Buffer", "Loading financial status...")

            BuildTab:AddSlider("Minimum Cash Reserve", "Keeps this minimum cash untouched so you never go bankrupt.", Config.MinCashReserve, 0, 100000, 0, "$", function(val)
                Config.MinCashReserve = val
            end)
            BuildTab:AddSlider("Max Single Item Price", "Maximum price allowed for a single purchase (0 = no limit).", Config.MaxItemPrice, 0, 250000, 0, "$", function(val)
                Config.MaxItemPrice = val
            end)

            -- What I Can Buy (Catalog Inspector)
            BuildTab:AddSection("WHAT I CAN BUY (CATALOG INSPECTOR)", "📋")
            local catalogPara = BuildTab:AddParagraph("📋 Available Upgrades by Category", "Press 'Scan Available Purchases' below to inspect.")

            local function updateCatalogView()
                local bal = Core.Utility.GetPlayerBalance()
                local reserve = Config.MinCashReserve or 0
                local usable = math.max(0, bal - reserve)
                local balFormatted = "$" .. tostring(bal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                local resFormatted = "$" .. tostring(reserve):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                local useFormatted = "$" .. tostring(usable):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

                balancePara:SetContent(string.format("Current Balance: %s  |  Safety Reserve: %s  |  Usable Budget: %s", balFormatted, resFormatted, useFormatted))

                if Core.Restaurant and Core.Restaurant.ScanAvailablePurchases then
                    local data = Core.Restaurant.ScanAvailablePurchases()
                    local lines = {}
                    local totalFound = #data.All
                    local affordableCount = 0

                    for _, item in ipairs(data.All) do
                        if item.CanAfford then affordableCount = affordableCount + 1 end
                    end

                    table.insert(lines, string.format("Found %d upgrades in world/shop (%d affordable right now):\n", totalFound, affordableCount))

                    local function formatCategory(catKey, catTitle)
                        local items = data[catKey]
                        if items and #items > 0 then
                            table.insert(lines, catTitle .. ":")
                            for _, it in ipairs(items) do
                                local status = it.CanAfford and "✓ AFFORDABLE" or (it.Needed > 0 and ("✗ Need +$" .. tostring(it.Needed):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or "✗ Unaffordable")
                                table.insert(lines, string.format("  • %s — %s [%s]", it.Title, it.PriceText, status))
                            end
                        end
                    end

                    formatCategory("LandFloors", "🏰 Land & Floors")
                    formatCategory("Cooking", "🍳 Cooking Appliances")
                    formatCategory("Dining", "🪑 Dining Furniture")
                    formatCategory("Kitchen", "🍽️ Kitchen Equipment")
                    formatCategory("Staff", "👨‍🍳 Staff Personnel")
                    formatCategory("Decor", "🌿 Decor & Aesthetics")

                    if totalFound == 0 then
                        table.insert(lines, "No shop prompts or UI items detected currently in range. Step near the shop or open the catalog.")
                    end

                    catalogPara:SetContent(table.concat(lines, "\n"))
                end
            end

            BuildTab:AddButton("🔄 Scan Available Purchases Now", "Inspects restaurant plot and shop to list all buyable items and prices.", "Secondary", function()
                updateCatalogView()
                Window:Notify({Title = "Catalog Scanned", Content = "Updated list of available items and affordability status.", Type = "Info", Duration = 2.5})
            end)
            BuildTab:AddButton("🛒 Auto-Buy Next Affordable Upgrade", "Instantly checks the shop and buys affordable upgrades.", "Primary", function()
                if Core.Restaurant and Core.Restaurant.HandleAutoBuy then
                    Config.AutoBuyEnabled = true
                    pcall(Core.Restaurant.HandleAutoBuy)
                    updateCatalogView()
                    Window:Notify({Title = "Shop Checked", Content = "Evaluated catalog and purchased available upgrades.", Type = "Success", Duration = 2.5})
                end
            end)

            -- Land & Floor Expansions (Strictly manual opt-in)
            BuildTab:AddSection("LAND & PROPERTY EXPANSIONS", "🏰")
            BuildTab:AddToggle("Auto-Expand Land & Floors (Master)", "Master toggle for buying land and multi-story floor unlocks as cash allows.", Config.AutoExpandEnabled, function(val)
                Config.AutoExpandEnabled = val
            end)
            BuildTab:AddToggle("Expand Plot Land Footprint", "Allows purchasing plot acreage and property boundaries.", Config.AutoBuyLand, function(val)
                Config.AutoBuyLand = val
            end)
            BuildTab:AddToggle("Unlock Upper Floors", "Allows purchasing 2nd Floor, 3rd Floor, etc.", Config.AutoBuyFloors, function(val)
                Config.AutoBuyFloors = val
            end)

            -- Cooking Appliances
            BuildTab:AddSection("COOKING APPLIANCES & UPGRADES", "🍳")
            BuildTab:AddToggle("Auto-Buy Upgrades (Master)", "Enables automatic equipment purchasing according to choices below.", Config.AutoBuyEnabled, function(val)
                Config.AutoBuyEnabled = val
            end)
            BuildTab:AddToggle("Buy Cooking Stoves & Ovens", "Purchases higher-tier stoves to cook meals faster.", Config.AutoBuyStoves, function(val)
                Config.AutoBuyStoves = val
            end)
            BuildTab:AddToggle("Buy Grills, Smokers & Fryers", "Purchases BBQ grills, smokers, and deep fryers.", Config.AutoBuyGrills, function(val)
                Config.AutoBuyGrills = val
            end)

            -- Dining Furniture
            BuildTab:AddSection("DINING ROOM FURNITURE", "🪑")
            BuildTab:AddToggle("Buy Dining Tables", "Purchases 2-seater and 4-seater dining tables.", Config.AutoBuyTables, function(val)
                Config.AutoBuyTables = val
            end)
            BuildTab:AddToggle("Buy Dining Chairs & Seating", "Purchases chairs, bar stools, and comfortable booths.", Config.AutoBuyChairs, function(val)
                Config.AutoBuyChairs = val
            end)

            -- Kitchen Equipment
            BuildTab:AddSection("KITCHEN EQUIPMENT & STORAGE", "🍽️")
            BuildTab:AddToggle("Buy Kitchen Appliances & Sinks", "Purchases dishwashers, fridges, coolers, and prep sinks.", Config.AutoBuyAppliances, function(val)
                Config.AutoBuyAppliances = val
            end)
            BuildTab:AddToggle("Buy Prep Counters & Stations", "Purchases food prep stations and kitchen counters.", Config.AutoBuyCounters, function(val)
                Config.AutoBuyCounters = val
            end)

            -- Decor & Aesthetics
            BuildTab:AddSection("DECOR & AMBIENCE", "🌿")
            BuildTab:AddToggle("Buy Decor & Aesthetic Plants", "Purchases indoor plants, trees, and decorative art.", Config.AutoBuyFurniture, function(val)
                Config.AutoBuyFurniture = val
            end)
            BuildTab:AddToggle("Buy Ambient Lighting & Lamps", "Purchases chandeliers, ceiling lights, and lamps.", Config.AutoBuyLighting, function(val)
                Config.AutoBuyLighting = val
            end)

            -- Staff Personnel Management
            BuildTab:AddSection("STAFF PERSONNEL MANAGEMENT", "👨‍🍳")
            BuildTab:AddToggle("Auto-Hire & Upgrade Staff (Master)", "Hires and levels up Cooks, Waiters, and Cleaners from Manage menu.", Config.AutoHireStaffEnabled, function(val)
                Config.AutoHireStaffEnabled = val
            end)
            BuildTab:AddToggle("Hire Cooks & Chefs", "Recruits and levels up kitchen cooks.", Config.AutoHireCooks, function(val)
                Config.AutoHireCooks = val
            end)
            BuildTab:AddToggle("Hire Waiters & Servers", "Recruits and levels up dining servers.", Config.AutoHireWaiters, function(val)
                Config.AutoHireWaiters = val
            end)
            BuildTab:AddToggle("Hire Cleaners & Janitors", "Recruits and levels up dishwashers and bussers.", Config.AutoHireCleaners, function(val)
                Config.AutoHireCleaners = val
            end)
            BuildTab:AddButton("👨‍🍳 Auto-Hire Available Staff Now", "Checks employee limits and hires available kitchen staff.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.HandleStaffManage then
                    Config.AutoHireStaffEnabled = true
                    pcall(Core.Restaurant.HandleStaffManage)
                    Window:Notify({Title = "Staff Managed", Content = "Hired and leveled up restaurant staff.", Type = "Success", Duration = 2.5})
                end
            end)

            -- Auto-Place Furniture & Seating
            BuildTab:AddSection("AUTO-PLACE STORED FURNITURE", "🔨")
            BuildTab:AddToggle("Auto-Place Stored Items (Master)", "Scans build inventory and places unplaced items on open floor grid.", Config.AutoPlaceEnabled, function(val)
                Config.AutoPlaceEnabled = val
            end)
            BuildTab:AddToggle("Place Dining Tables", "Automatically places stored tables on open floor positions.", Config.AutoPlaceTables, function(val)
                Config.AutoPlaceTables = val
            end)
            BuildTab:AddToggle("Place Dining Chairs", "Automatically positions stored chairs neatly around tables.", Config.AutoPlaceChairs, function(val)
                Config.AutoPlaceChairs = val
            end)
            BuildTab:AddToggle("Place General Furniture", "Places counters, sinks, and decor onto available floor tiles.", Config.AutoPlaceFurniture, function(val)
                Config.AutoPlaceFurniture = val
            end)
            BuildTab:AddButton("🔨 Auto-Place Stored Items Now", "Immediately places any inventory furniture onto the restaurant layout.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.HandleAutoPlace then
                    Config.AutoPlaceEnabled = true
                    pcall(Core.Restaurant.HandleAutoPlace)
                    Window:Notify({Title = "Furniture Placed", Content = "Placed unassigned inventory items on the floor grid.", Type = "Success", Duration = 2.5})
                end
            end)

            -- Auto-refresh catalog view after tab creation
            task.delay(1.0, function()
                pcall(updateCatalogView)
            end)
        end

        -- =====================================================================
        -- 4. AUTOMATION & NAVIGATION ENGINE TAB
        -- =====================================================================
        function UI.BuildAutomationTab()
            local AutoTab = Window:AddTab("Automation", "⚙️")

            -- Task Completion & Sequencing
            AutoTab:AddSection("TASK COMPLETION & TIMING", "⏱️")
            AutoTab:AddToggle("Strict Task Completion Guard", "Guarantees server prompt destruction before moving avatar to avoid dropped actions.", Config.StrictTaskCompletion, function(val)
                Config.StrictTaskCompletion = val
            end)
            AutoTab:AddSlider("Station Stay Delay", "Wait duration at cooking/dining stations for server registration.", Config.StationStayDelay or 0.22, 0.08, 1.0, 2, "s", function(val)
                Config.StationStayDelay = val
            end)
            AutoTab:AddSlider("Post-Action Settling Delay", "Micro-settling pause after finishing a task before next teleport.", Config.PostActionDelay or 0.18, 0.05, 0.8, 2, "s", function(val)
                Config.PostActionDelay = val
            end)
            AutoTab:AddSlider("Cycle Speed Delay", "Delay between global scheduler dispatch iterations.", Config.ActionDelay or 0.3, 0.1, 2.5, 2, "s", function(val)
                Config.ActionDelay = val
            end)

            -- Pipeline & Concurrency
            AutoTab:AddSection("PIPELINE & CONCURRENCY", "🔄")
            AutoTab:AddToggle("Simultaneous Multi-Queue Pipeline", "Interleaves cooking, serving, ordering, and cleaning to prevent starvation.", Config.InterleavedPipelineEnabled, function(val)
                Config.InterleavedPipelineEnabled = val
            end)
            AutoTab:AddToggle("Concurrent Workstation Batching", "Processes multiple ready prompts within 14 studs sequentially in one visit.", Config.ConcurrentExecutionEnabled, function(val)
                Config.ConcurrentExecutionEnabled = val
            end)
            AutoTab:AddSlider("Station Batch Size", "Maximum number of prompts to resolve per workstation visit.", Config.StationBatchSize or 3, 1, 5, 0, "", function(val)
                Config.StationBatchSize = val
            end)
            AutoTab:AddToggle("Opportunistic Nearby Batching", "Concurrently fires nearby ready prompts across all categories near station.", Config.RemotePromptBatching, function(val)
                Config.RemotePromptBatching = val
            end)

            -- Teleportation & Navigation
            AutoTab:AddSection("TELEPORTATION & NAVIGATION", "📍")
            AutoTab:AddToggle("Auto-Teleport to Stations", "Smooth floor raycast navigation directly to active tasks.", Config.AutoTeleportEnabled, function(val)
                Config.AutoTeleportEnabled = val
            end)
            AutoTab:AddSlider("Restaurant Scan Radius", "Maximum stud distance from plot anchor to search for tasks.", Config.MaxScanRadius or 120, 40, 300, 0, " studs", function(val)
                Config.MaxScanRadius = val
            end)
            AutoTab:AddToggle("Scope to Own Plot Only", "Filters all prompts exclusively to your own restaurant plot.", Config.PlotScopingEnabled, function(val)
                Config.PlotScopingEnabled = val
            end)
            AutoTab:AddToggle("Prevent Sitting in Chairs", "Prevents avatar from getting stuck sitting in dining chairs.", Config.PreventSitting, function(val)
                Config.PreventSitting = val
            end)
            AutoTab:AddToggle("Multi-Floor Safe Raycast", "Bounded vertical raycasting to prevent falling through floor expansions.", Config.MultiFloorSafeRaycast, function(val)
                Config.MultiFloorSafeRaycast = val
            end)

            -- AFK & Performance
            AutoTab:AddSection("AFK & PERFORMANCE", "🛡️")
            AutoTab:AddToggle("Instant Proximity Prompts", "Removes hold duration and line-of-sight checks for instant interaction.", Config.InstantPromptEnabled, function(val)
                Config.InstantPromptEnabled = val
            end)
            AutoTab:AddToggle("Anti-AFK Disconnect Guard", "Prevents Roblox's 20-minute idle disconnect kick.", Config.AntiAFKEnabled, function(val)
                Config.AntiAFKEnabled = val
            end)
            AutoTab:AddToggle("24/7 Auto-Rejoin on Disconnect", "Automatically reconnects into the server if disconnected.", Config.AutoRejoinEnabled, function(val)
                Config.AutoRejoinEnabled = val
            end)
            AutoTab:AddToggle("GPU Saver / Performance Mode", "Disables 3D viewport rendering for ultra-low power overnight farming.", Config.GPUSaverEnabled, function(val)
                Config.GPUSaverEnabled = val
                Utility.SetGPUSaver(val)
            end)
        end

        -- =====================================================================
        -- 5. SETTINGS & UTILITIES TAB
        -- =====================================================================
        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings", "🛠️")

            -- Appearance & Sound
            SettingsTab:AddSection("APPEARANCE & SOUND", "🎨")
            local themeOptions = {"Midnight Violet", "Emerald Cyber", "Sapphire Ocean", "Sunset Amber", "Obsidian Carbon"}
            local themeMap = {
                ["Midnight Violet"] = "Violet",
                ["Emerald Cyber"] = "Emerald",
                ["Sapphire Ocean"] = "Sapphire",
                ["Sunset Amber"] = "Amber",
                ["Obsidian Carbon"] = "Carbon"
            }
            local currentDisplayTheme = "Midnight Violet"
            for disp, internal in pairs(themeMap) do
                if internal == Config.Theme then currentDisplayTheme = disp; break end
            end

            SettingsTab:AddDropdown("Theme Preset", "Switch between glassmorphic dark theme color palettes.", themeOptions, currentDisplayTheme, function(selected)
                local themeKey = themeMap[selected] or "Violet"
                Config.Theme = themeKey
                Window:SetTheme(themeKey)
                Window:Notify({Title = "Theme Applied", Content = "Switched to " .. selected .. ".", Type = "Success", Duration = 2.5})
            end)

            SettingsTab:AddToggle("UI Sound Effects", "Subtle audio clicks and feedback on toggles and tabs.", Config.UISoundEnabled, function(val)
                Config.UISoundEnabled = val
            end)

            -- Keybinds
            SettingsTab:AddSection("KEYBOARD SHORTCUTS", "⌨️")
            SettingsTab:AddKeybind("Toggle Menu Key", "Keyboard shortcut to show/hide this interface.", Config.MenuKey, function(key)
                Config.MenuKey = key
                Window:Notify({Title = "Keybind Updated", Content = "Menu key set to " .. (key and key.Name or "None") .. ".", Type = "Info", Duration = 2})
            end)
            SettingsTab:AddKeybind("Toggle No-Clip", "Shortcut to toggle walking through walls and furniture.", Config.ToggleNoClipKey, function(key)
                Config.ToggleNoClipKey = key
            end)
            SettingsTab:AddKeybind("Toggle Speed Hack", "Shortcut to toggle sprint speed override.", Config.ToggleSpeedKey, function(key)
                Config.ToggleSpeedKey = key
            end)
            SettingsTab:AddKeybind("Toggle Jump Hack", "Shortcut to toggle jump launch override.", Config.ToggleJumpKey, function(key)
                Config.ToggleJumpKey = key
            end)
            SettingsTab:AddKeybind("Toggle Infinite Jump", "Shortcut to toggle infinite mid-air jumps.", Config.ToggleInfJumpKey, function(key)
                Config.ToggleInfJumpKey = key
            end)

            -- Profile Configuration
            SettingsTab:AddSection("CONFIGURATION PROFILES", "💾")
            SettingsTab:AddButton("Save Configuration Profile", "Saves all current toggle and slider settings to disk.", "Primary", function()
                if Core.Config.Save then
                    local ok = Core.Config:Save()
                    Window:Notify({
                        Title = ok and "Config Saved" or "Save Failed",
                        Content = ok and "Settings saved to Restaurant_Config.json." or "Could not write config file.",
                        Type = ok and "Success" or "Error",
                        Duration = 3
                    })
                end
            end)
            SettingsTab:AddButton("Load Configuration Profile", "Restores previously saved settings from disk.", "Secondary", function()
                if Core.Config.Load then
                    local ok = Core.Config:Load()
                    Window:Notify({
                        Title = ok and "Config Loaded" or "Load Failed",
                        Content = ok and "Restored saved configuration settings." or "No saved config file found.",
                        Type = ok and "Success" or "Error",
                        Duration = 3
                    })
                end
            end)

            -- Promo Code Redeemer
            SettingsTab:AddSection("PROMOTIONAL CODES", "🎟️")
            SettingsTab:AddButton("🎟️ Redeem Active Promo Codes", "Submits active event codes (FISHIES, RAR4EVER) for free exclusive items.", "Secondary", function()
                local count = Utility.RedeemKnownCodes()
                Window:Notify({
                    Title = "Codes Submitted",
                    Content = (count and count > 0) and string.format("Redeemed %d active codes!", count) or "Promo codes submitted to server.",
                    Type = "Success",
                    Duration = 3
                })
            end)

            -- Complete Unload
            SettingsTab:AddSection("UNLOAD SCRIPT", "🔴")
            SettingsTab:AddButton("🔴 Unload & Terminate Script Cleanly", "Disconnects all listeners, restores character physics, and destroys GUI.", "Danger", function()
                Window:Notify({Title = "Terminating...", Content = "Restoring player character and unloading.", Type = "Warning", Duration = 2})
                task.wait(0.5)
                Utility.Terminate()
            end)
        end
    end

    return UI
end
