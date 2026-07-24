return function(Core)
    local UI = {}
    local Config = Core.Config

    function UI.Init()
        -- Load the UI Library
        local UILibrary
        if isfile and isfile("modules/UILibrary.lua") then
            UILibrary = loadstring(readfile("modules/UILibrary.lua"))()(Core)
        else
            UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/modules/UILibrary.lua?nocache=" .. tostring(tick())))()(Core)
        end

        local Theme = UILibrary.Theme or {}

        -- Create the main window
        local Window = UILibrary:CreateWindow("⚡ Pure Auto-Aim v3.0.0 (Premium)")
        UI.Window = Window

        -- Expose a method to update the floating circle color
        function UI.UpdateFloatStatus()
            if not UILibrary.FloatingCircle.Visible then return end
            if Config.AutoAimEnabled then
                UILibrary.FloatStroke.Color = Theme.TextAccent
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(28, 22, 54)
            elseif Config.ESPEnabled then
                UILibrary.FloatStroke.Color = Color3.fromRGB(160, 140, 255)
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(34, 28, 66)
            else
                UILibrary.FloatStroke.Color = Theme.Stroke
                UILibrary.FloatingCircle.BackgroundColor3 = Theme.ElementIdle
            end
        end

        -- To be called by MainLoop to build the generic settings UI
        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings")
            SettingsTab:AddSection("SYSTEM FEATURES")
            SettingsTab:AddToggle("Auto-Respawn", Config.AutoRespawn, function(val) Config.AutoRespawn = val end)
            SettingsTab:AddToggle("Kill Feed", Config.KillFeedEnabled, function(val) Config.KillFeedEnabled = val end)
            SettingsTab:AddToggle("Target Info Overlay", Config.TargetInfoEnabled, function(val) Config.TargetInfoEnabled = val end)
            
            SettingsTab:AddSection("KEYBINDS")
            SettingsTab:AddKeybind("Toggle Menu", Config.MenuKey, function(key) Config.MenuKey = key end)
            SettingsTab:AddKeybind("Toggle Auto-Aim", Config.AimKey, function(key) Config.AimKey = key end)
            SettingsTab:AddKeybind("Snap to Nearest Target", Config.NearestTargetKey, function(key) Config.NearestTargetKey = key end)
            
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
