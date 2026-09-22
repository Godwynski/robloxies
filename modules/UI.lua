return function(Core)
    local UI = {}
    local Config = Core.Config
    local Utility = Core.Utility

    function UI.Init()
        local UILibrary = require("modules.UILibrary")(Core)
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
                           Config.AutoFarmEnabled or Config.WalkSpeedEnabled or Config.JumpPowerEnabled or
                           Config.NoClipEnabled or Config.InfiniteJumpEnabled

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

            RestTab:AddSection("AUTOMATION WORKFLOW")
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

            RestTab:AddSection("TELEPORTATION & NAVIGATION")
            RestTab:AddToggle("Auto-Teleport to Stations", Config.AutoTeleportEnabled, function(val)
                Config.AutoTeleportEnabled = val
            end)
            RestTab:AddSlider("Station Delay (x10 ms)", math.floor((Config.TeleportDelay or 0.15) * 100), 5, 100, function(val)
                Config.TeleportDelay = val / 100
            end)
            RestTab:AddToggle("Scope to Own Plot Only", Config.PlotScopingEnabled, function(val)
                Config.PlotScopingEnabled = val
            end)
            RestTab:AddToggle("Prevent Sitting in Chairs", Config.PreventSitting, function(val)
                Config.PreventSitting = val
            end)

            RestTab:AddSection("INTERACTIONS & AFK")
            RestTab:AddToggle("Instant Proximity Prompts", Config.InstantPromptEnabled, function(val)
                Config.InstantPromptEnabled = val
            end)
            RestTab:AddToggle("Anti-AFK Disconnect Guard", Config.AntiAFKEnabled, function(val)
                Config.AntiAFKEnabled = val
            end)
            RestTab:AddToggle("GPU Saver / Performance Mode", Config.GPUSaverEnabled, function(val)
                Config.GPUSaverEnabled = val
                Utility.SetGPUSaver(val)
            end)
            RestTab:AddSlider("Cycle Speed (s)", math.floor(Config.ActionDelay * 10), 1, 30, function(val)
                Config.ActionDelay = val / 10
            end)

            RestTab:AddSection("QUICK ACTIONS")
            RestTab:AddButton("Trigger All Workstations Now", function(btn)
                if Core.Restaurant then
                    pcall(Core.Restaurant.HandleFarming)
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
            RestTab:AddButton("Teleport to Restaurant Center", function(btn)
                if Core.Restaurant then
                    local plot = Core.Restaurant.GetPlayerPlot()
                    if plot and plot ~= workspace then
                        Core.Restaurant.TeleportTo(plot)
                    end
                end
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
        end
    end

    return UI
end
