return function(Core)
    local UI = {}
    local Config = Core.Config

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
            RestTab:AddToggle("Auto-Collect Cash / Tips", Config.AutoCollectCashEnabled, function(val)
                Config.AutoCollectCashEnabled = val
                UI.UpdateFloatStatus()
            end)

            RestTab:AddSection("INTERACTIONS")
            RestTab:AddToggle("Instant Proximity Prompts", Config.InstantPromptEnabled, function(val)
                Config.InstantPromptEnabled = val
            end)
            RestTab:AddSlider("Action Loop Speed (s)", math.floor(Config.ActionDelay * 10), 1, 20, function(val)
                Config.ActionDelay = val / 10
            end)

            RestTab:AddSection("QUICK ACTIONS")
            RestTab:AddButton("Trigger All Nearby Prompts", function(btn)
                if Core.Restaurant then
                    pcall(Core.Restaurant.HandleSeating)
                    pcall(Core.Restaurant.HandleOrdering)
                    pcall(Core.Restaurant.HandleCooking)
                    pcall(Core.Restaurant.HandleServing)
                    pcall(Core.Restaurant.HandleCleaning)
                    pcall(Core.Restaurant.HandleCashCollection)
                    local old = btn.Text
                    btn.Text = "Triggered!"
                    task.delay(1.2, function() btn.Text = old end)
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
