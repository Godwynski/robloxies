return function(Core)
    local UI = {}
    local Config = Core.Config
    local Utility = Core.Utility
    local State = Core.State

    function UI.Init()
        local UILibrary = loadModule("modules.UILibrary")(Core)
        local Theme = UILibrary.Theme or {}

        -- Create the main window
        local Window = UILibrary:CreateWindow("🍽️ Run a Restaurant Utility")
        UI.Window = Window

        if UILibrary.FloatIcon then
            UILibrary.FloatIcon.Text = "🍽️"
        end

        function UI.UpdateFloatStatus()
            if not UILibrary.FloatingCircle or not UILibrary.FloatingCircle.Visible then return end
            local active = Config.AutoSeatEnabled or Config.AutoOrderEnabled or Config.AutoCookEnabled or
                           Config.AutoServeEnabled or Config.AutoCleanEnabled or Config.AutoCollectCashEnabled or
                           Config.AutoFarmEnabled or Config.AutoDeliveryEnabled or Config.AutoRestockEnabled or
                           Config.WalkSpeedEnabled or Config.JumpPowerEnabled or Config.NoClipEnabled or Config.InfiniteJumpEnabled

            if active then
                UILibrary.FloatStroke.Color = Theme.TextAccent
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(28, 22, 54)
            else
                UILibrary.FloatStroke.Color = Theme.Stroke
                UILibrary.FloatingCircle.BackgroundColor3 = Theme.ElementIdle
            end
        end

        -- Build the Restaurant Automation Tab
        function UI.BuildRestaurantTab()
            local RestTab = Window:AddTab("Restaurant")

            -- 1. LIVE PERFORMANCE & PROFIT HUD
            RestTab:AddSection("LIVE RESTAURANT STATS")
            local statsLabel1 = RestTab:AddLabel("💵 Cash Swept: $0 | 🎁 Quests: 0")
            local statsLabel2 = RestTab:AddLabel("👥 Seated: 0 | 📋 Orders: 0 | 🍳 Cooked: 0")
            local statsLabel3 = RestTab:AddLabel("🍽️ Served: 0 | 🧼 Cleaned: 0 | 📦 Delivered: 0")
            local statsLabel4 = RestTab:AddLabel("🌾 Harvested: 0 | 🧊 Restocked: 0 | 🏰 Expansions: 0")
            local statsLabel5 = RestTab:AddLabel("🛒 Purchased: 0 | 🔨 Placed: 0 | 👨‍🍳 Staff: 0")

            -- Sync live stats every second
            task.spawn(function()
                while State.Running do
                    pcall(function()
                        local s = State.Stats
                        statsLabel1:SetText(string.format("💵 Cash Swept: %d items | 🎁 Quests: %d", s.CashCollected, s.QuestsClaimed))
                        statsLabel2:SetText(string.format("👥 Seated: %d | 📋 Orders: %d | 🍳 Cooked: %d", s.CustomersSeated, s.OrdersTaken, s.DishesCooked))
                        statsLabel3:SetText(string.format("🍽️ Served: %d | 🧼 Cleaned: %d | 📦 Delivered: %d", s.DishesServed, s.TablesCleaned, s.DeliveriesCompleted))
                        statsLabel4:SetText(string.format("🌾 Harvested: %d | 🧊 Restocked: %d | 🏰 Expansions: %d", s.CropsHarvested, s.StorageRestocked, s.ExpansionsPurchased))
                        statsLabel5:SetText(string.format("🛒 Purchased: %d | 🔨 Placed: %d | 👨‍🍳 Staff: %d", s.ItemsPurchased, s.ItemsPlaced, s.StaffHired))
                    end)
                    task.wait(0.8)
                end
            end)

            -- 2. AUTOMATION WORKFLOW
            RestTab:AddSection("AUTOMATION WORKFLOW")
            RestTab:AddToggle("⚡ MASTER RESTAURANT AUTO-FARM", Config.MasterAutoFarmEnabled, function(val)
                Config.MasterAutoFarmEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Seat Customers", Config.AutoSeatEnabled, function(val)
                Config.AutoSeatEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Take Orders", Config.AutoOrderEnabled, function(val)
                Config.AutoOrderEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Cook Food", Config.AutoCookEnabled, function(val)
                Config.AutoCookEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Serve Dishes", Config.AutoServeEnabled, function(val)
                Config.AutoServeEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Clean Tables", Config.AutoCleanEnabled, function(val)
                Config.AutoCleanEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Collect Cash & Tips", Config.AutoCollectCashEnabled, function(val)
                Config.AutoCollectCashEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Harvest Farm & Ranch", Config.AutoFarmEnabled, function(val)
                Config.AutoFarmEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Fulfill Delivery Orders", Config.AutoDeliveryEnabled, function(val)
                Config.AutoDeliveryEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Restock Kitchen Storage", Config.AutoRestockEnabled, function(val)
                Config.AutoRestockEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Buy Stoves & Appliances", Config.AutoBuyEnabled, function(val)
                Config.AutoBuyEnabled = val
            end)
            RestTab:AddToggle("Auto-Place Stored Furniture", Config.AutoPlaceEnabled, function(val)
                Config.AutoPlaceEnabled = val
            end)
            RestTab:AddToggle("Auto-Hire & Upgrade Staff", Config.AutoHireStaffEnabled, function(val)
                Config.AutoHireStaffEnabled = val
            end)
            RestTab:AddToggle("Auto-Claim Quests & Daily Gifts", Config.AutoClaimQuestsEnabled, function(val)
                Config.AutoClaimQuestsEnabled = val
            end)
            RestTab:AddToggle("VIP & Celebrity Customer Priority", Config.VIPPriorityEnabled, function(val)
                Config.VIPPriorityEnabled = val
            end)
            RestTab:AddToggle("Auto-Expand Floors & Land", Config.AutoExpandEnabled, function(val)
                Config.AutoExpandEnabled = val
            end)

            -- 3. PIPELINE & CONCURRENCY
            RestTab:AddSection("PIPELINE & CONCURRENCY")
            RestTab:AddToggle("Simultaneous Multi-Queue Pipeline", Config.InterleavedPipelineEnabled, function(val)
                Config.InterleavedPipelineEnabled = val
            end)
            RestTab:AddToggle("Concurrent Workstation Batching", Config.ConcurrentExecutionEnabled, function(val)
                Config.ConcurrentExecutionEnabled = val
            end)
            RestTab:AddSlider("Station Batch Size", Config.StationBatchSize or 3, 1, 5, function(val)
                Config.StationBatchSize = val
            end)
            RestTab:AddToggle("Opportunistic Nearby Batching", Config.RemotePromptBatching, function(val)
                Config.RemotePromptBatching = val
            end)

            -- 4. TELEPORTATION & NAVIGATION
            RestTab:AddSection("TELEPORTATION & NAVIGATION")
            RestTab:AddToggle("Auto-Teleport to Stations", Config.AutoTeleportEnabled, function(val)
                Config.AutoTeleportEnabled = val
            end)
            RestTab:AddSlider("Station Stay Delay (s)", math.floor((Config.StationStayDelay or 0.22) * 100), 8, 100, function(val)
                Config.StationStayDelay = val / 100
            end)
            RestTab:AddSlider("Restaurant Radius (studs)", Config.MaxScanRadius or 120, 40, 300, function(val)
                Config.MaxScanRadius = val
            end)
            RestTab:AddToggle("Scope to Own Plot Only", Config.PlotScopingEnabled, function(val)
                Config.PlotScopingEnabled = val
            end)
            RestTab:AddToggle("Prevent Sitting in Chairs", Config.PreventSitting, function(val)
                Config.PreventSitting = val
            end)
            RestTab:AddToggle("Multi-Floor Safe Raycast", Config.MultiFloorSafeRaycast, function(val)
                Config.MultiFloorSafeRaycast = val
            end)

            -- 5. INTERACTIONS & PERFORMANCE
            RestTab:AddSection("INTERACTIONS & PERFORMANCE")
            RestTab:AddToggle("Instant Proximity Prompts", Config.InstantPromptEnabled, function(val)
                Config.InstantPromptEnabled = val
            end)
            RestTab:AddToggle("Anti-AFK Disconnect Guard", Config.AntiAFKEnabled, function(val)
                Config.AntiAFKEnabled = val
            end)
            RestTab:AddToggle("24/7 Auto-Rejoin on Disconnect", Config.AutoRejoinEnabled, function(val)
                Config.AutoRejoinEnabled = val
            end)
            RestTab:AddToggle("GPU Saver / Performance Mode", Config.GPUSaverEnabled, function(val)
                Config.GPUSaverEnabled = val
                Utility.SetGPUSaver(val)
            end)
            RestTab:AddSlider("Cycle Speed (s)", math.floor(Config.ActionDelay * 10), 1, 30, function(val)
                Config.ActionDelay = val / 10
            end)

            -- 6. QUICK ACTIONS
            RestTab:AddSection("QUICK ACTIONS")
            RestTab:AddButton("📍 Set Restaurant Anchor Here", function(btn)
                if Core.Restaurant and Core.Restaurant.RecalibrateAnchor then
                    local ok = Core.Restaurant.RecalibrateAnchor()
                    local old = btn.Text
                    btn.Text = ok and "📍 Anchor Calibrated!" or "Error Calibrating"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("Redeem Active Promo Codes", function(btn)
                local count = Utility.RedeemKnownCodes()
                local old = btn.Text
                btn.Text = count > 0 and ("Submitted " .. count .. " Codes!") or "Codes Submitted!"
                task.delay(1.5, function() btn.Text = old end)
            end)
            RestTab:AddButton("Claim All Finished Quests & Gifts", function(btn)
                local claimed = Utility.ClaimQuestsAndGifts()
                local old = btn.Text
                btn.Text = claimed > 0 and ("Claimed " .. claimed .. " Rewards!") or "No Rewards Pending"
                task.delay(1.5, function() btn.Text = old end)
            end)
            RestTab:AddButton("Trigger All Workstations Now", function(btn)
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
                    local old = btn.Text
                    btn.Text = "Dispatched!"
                    task.delay(1.2, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("🛒 Auto-Buy Next Equipment Now", function(btn)
                if Core.Restaurant and Core.Restaurant.HandleAutoBuy then
                    Config.AutoBuyEnabled = true
                    pcall(Core.Restaurant.HandleAutoBuy)
                    local old = btn.Text
                    btn.Text = "Checked Shop!"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("🔨 Auto-Place Stored Items Now", function(btn)
                if Core.Restaurant and Core.Restaurant.HandleAutoPlace then
                    Config.AutoPlaceEnabled = true
                    pcall(Core.Restaurant.HandleAutoPlace)
                    local old = btn.Text
                    btn.Text = "Placed on Grid!"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("👨‍🍳 Auto-Hire Available Staff Now", function(btn)
                if Core.Restaurant and Core.Restaurant.HandleStaffManage then
                    Config.AutoHireStaffEnabled = true
                    pcall(Core.Restaurant.HandleStaffManage)
                    local old = btn.Text
                    btn.Text = "Hired Staff!"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("Teleport to Restaurant Center", function(btn)
                if Core.Restaurant then
                    local center = Core.Restaurant.RestaurantCenter
                    if center then
                        local char = Core.Services.Players.LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root then
                            root.CFrame = CFrame.new(center + Vector3.new(0, 3, 0))
                        end
                    end
                end
            end)
            RestTab:AddButton("🔴 Unload & Close Utility", function()
                Utility.Terminate()
            end)
        end

        -- Build the Settings Tab
        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings")
            SettingsTab:AddSection("KEYBINDS")
            SettingsTab:AddKeybind("Toggle Menu", Config.MenuKey, function(key) Config.MenuKey = key end)
            SettingsTab:AddKeybind("Toggle No-Clip", Config.ToggleNoClipKey, function(key) Config.ToggleNoClipKey = key end)
            SettingsTab:AddKeybind("Toggle Speed Hack", Config.ToggleSpeedKey, function(key) Config.ToggleSpeedKey = key end)
            SettingsTab:AddKeybind("Toggle Jump Hack", Config.ToggleJumpKey, function(key) Config.ToggleJumpKey = key end)
            SettingsTab:AddKeybind("Toggle Infinite Jump", Config.ToggleInfJumpKey, function(key) Config.ToggleInfJumpKey = key end)

            SettingsTab:AddSection("CONFIG")
            SettingsTab:AddButton("Save Config", function(btn)
                if Core.Config.Save then
                    local success = Core.Config:Save()
                    local oldText = btn.Text
                    btn.Text = success and "Saved!" or "Error Saving"
                    task.delay(1.5, function() btn.Text = oldText end)
                end
            end)
            SettingsTab:AddButton("Load Config", function(btn)
                if Core.Config.Load then
                    local success = Core.Config:Load()
                    local oldText = btn.Text
                    btn.Text = success and "Loaded!" or "Error Loading"
                    task.delay(1.5, function() btn.Text = oldText end)
                end
            end)

            SettingsTab:AddSection("UNLOAD SCRIPT")
            SettingsTab:AddButton("🔴 Unload & Close Script Completely", function()
                Utility.Terminate()
            end)
        end
    end

    return UI
end
