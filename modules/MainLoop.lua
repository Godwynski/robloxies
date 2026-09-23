return function(Core)
    local MainLoop = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services

    function MainLoop.Init()
        -- Keybind handling
        Utility.RegisterConnection(Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end

            -- Toggle Menu
            if Config.MenuKey and input.KeyCode == Config.MenuKey then
                if Core.UI and Core.UI.Window and Core.UI.Window.Library then
                    local lib = Core.UI.Window.Library
                    if lib.ToggleWindow then
                        lib:ToggleWindow()
                    elseif lib.MainContainer then
                        lib.MainContainer.Visible = not lib.MainContainer.Visible
                    end
                end

            -- Toggle No-Clip
            elseif Config.ToggleNoClipKey and input.KeyCode == Config.ToggleNoClipKey then
                Config.NoClipEnabled = not Config.NoClipEnabled
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "No-Clip",
                        Content = Config.NoClipEnabled and "Collision disabled (Walking through walls)" or "Collision restored to normal",
                        Type = Config.NoClipEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end

            -- Toggle Speed Hack
            elseif Config.ToggleSpeedKey and input.KeyCode == Config.ToggleSpeedKey then
                Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "Speed Hack",
                        Content = Config.WalkSpeedEnabled and ("Sprint speed set to " .. tostring(Config.WalkSpeed)) or "WalkSpeed restored to normal",
                        Type = Config.WalkSpeedEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end

            -- Toggle Jump Hack
            elseif Config.ToggleJumpKey and input.KeyCode == Config.ToggleJumpKey then
                Config.JumpPowerEnabled = not Config.JumpPowerEnabled
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "Jump Hack",
                        Content = Config.JumpPowerEnabled and ("Jump power set to " .. tostring(Config.JumpPower)) or "JumpPower restored to normal",
                        Type = Config.JumpPowerEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end

            -- Toggle Infinite Jump
            elseif Config.ToggleInfJumpKey and input.KeyCode == Config.ToggleInfJumpKey then
                Config.InfiniteJumpEnabled = not Config.InfiniteJumpEnabled
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "Infinite Jump",
                        Content = Config.InfiniteJumpEnabled and "Mid-air jumping active" or "Infinite jump disabled",
                        Type = Config.InfiniteJumpEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end
            end
        end))

        print("🏃 Movement Utility Loaded. RightShift = toggle UI | N = toggle No-Clip")
    end

    return MainLoop
end
