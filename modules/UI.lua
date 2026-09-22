return function(Core)
    local UI = {}
    local Config = Core.Config

    function UI.Init()
        local UILibrary = require("modules.UILibrary")(Core)
        local Theme = UILibrary.Theme or {}

        -- Create the main window
        local Window = UILibrary:CreateWindow("🏃 Movement Utility")
        UI.Window = Window

        if UILibrary.FloatIcon then
            UILibrary.FloatIcon.Text = "🏃"
        end

        function UI.UpdateFloatStatus()
            if not UILibrary.FloatingCircle or not UILibrary.FloatingCircle.Visible then return end
            if Config.WalkSpeedEnabled or Config.JumpPowerEnabled or Config.NoClipEnabled or Config.InfiniteJumpEnabled then
                UILibrary.FloatStroke.Color = Theme.TextAccent
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(28, 22, 54)
            else
                UILibrary.FloatStroke.Color = Theme.Stroke
                UILibrary.FloatingCircle.BackgroundColor3 = Theme.ElementIdle
            end
        end

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
