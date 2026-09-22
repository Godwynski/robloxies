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
                    if lib.FloatingCircle and lib.FloatingCircle.Visible then
                        lib.FloatingCircle.Visible = false
                        lib.MainContainer.Visible = true
                        lib.MainContainer.Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 0)
                        if lib.Tween then
                            lib.Tween(lib.MainContainer, {Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, lib.SavedHeight or 520)}, 0.3, Enum.EasingStyle.Back)
                        end
                    elseif lib.MainContainer then
                        if lib.MainContainer.Visible then
                            task.spawn(function()
                                lib.SavedHeight = lib.MainContainer.AbsoluteSize.Y
                                if lib.Tween then
                                    local tw = lib.Tween(lib.MainContainer, {Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 0)}, 0.2)
                                    pcall(function() tw.Completed:Wait() end)
                                end
                                lib.MainContainer.Visible = false
                                lib.FloatingCircle.Visible = true
                            end)
                        else
                            lib.MainContainer.Visible = true
                            lib.MainContainer.Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 0)
                            if lib.Tween then
                                lib.Tween(lib.MainContainer, {Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, lib.SavedHeight or 520)}, 0.3, Enum.EasingStyle.Back)
                            end
                        end
                    end
                end

            -- Toggle No-Clip
            elseif Config.ToggleNoClipKey and input.KeyCode == Config.ToggleNoClipKey then
                Config.NoClipEnabled = not Config.NoClipEnabled
                if Core.UI and Core.UI.UpdateFloatStatus then
                    pcall(Core.UI.UpdateFloatStatus)
                end

            -- Toggle Speed Hack
            elseif Config.ToggleSpeedKey and input.KeyCode == Config.ToggleSpeedKey then
                Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
                if Core.UI and Core.UI.UpdateFloatStatus then
                    pcall(Core.UI.UpdateFloatStatus)
                end

            -- Toggle Jump Hack
            elseif Config.ToggleJumpKey and input.KeyCode == Config.ToggleJumpKey then
                Config.JumpPowerEnabled = not Config.JumpPowerEnabled
                if Core.UI and Core.UI.UpdateFloatStatus then
                    pcall(Core.UI.UpdateFloatStatus)
                end

            -- Toggle Infinite Jump
            elseif Config.ToggleInfJumpKey and input.KeyCode == Config.ToggleInfJumpKey then
                Config.InfiniteJumpEnabled = not Config.InfiniteJumpEnabled
                if Core.UI and Core.UI.UpdateFloatStatus then
                    pcall(Core.UI.UpdateFloatStatus)
                end
            end
        end))

        print("🏃 Movement Utility Loaded. RightShift = toggle UI | N = toggle No-Clip")
    end

    return MainLoop
end
