return function(Core)
    local MainLoop = {}

    local Config = Core.Config
    local State = Core.State
    local Utility = Core.Utility
    local Services = Core.Services
    local EventManager = Core.EventManager

    function MainLoop.Init()
        Services.RunService:BindToRenderStep("PureAutoAimLoop", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)

            local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(0, 0)
            local mouseLoc = Services.UserInputService:GetMouseLocation()
            
            if Config.AimOrigin == "Center" or (mouseLoc.X <= 5 and mouseLoc.Y <= 40 and vpSize.X > 0) then
                mouseLoc = vpSize / 2
            end

            -- Prepare render context to pass to modules
            local context = {
                deltaTime = deltaTime,
                Camera = workspace.CurrentCamera,
                MouseLocation = mouseLoc,
                ViewportSize = vpSize
            }

            EventManager:Fire("OnRender", context)
            
            -- Update floating circle status indicator
            if Core.UI and Core.UI.UpdateFloatStatus then
                pcall(Core.UI.UpdateFloatStatus)
            end
        end)

        Utility.RegisterConnection(Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            
            if Config.MenuKey and input.KeyCode == Config.MenuKey then
                if Core.UI.Window and Core.UI.Window.Library then
                    local lib = Core.UI.Window.Library
                    if lib.FloatingCircle and lib.FloatingCircle.Visible then
                        lib.FloatingCircle.Visible = false
                        lib.MainContainer.Visible = true
                        lib.MainContainer.Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 0)
                        if lib.Tween then
                            lib.Tween(lib.MainContainer, {Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 520)}, 0.3, Enum.EasingStyle.Back)
                        end
                    elseif lib.MainContainer then
                        if lib.MainContainer.Visible then
                            if lib.Tween then
                                local tw = lib.Tween(lib.MainContainer, {Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 0)}, 0.2)
                                tw.Completed:Wait()
                            end
                            lib.MainContainer.Visible = false
                            lib.FloatingCircle.Visible = true
                        else
                            lib.MainContainer.Visible = true
                            lib.MainContainer.Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 0)
                            if lib.Tween then
                                lib.Tween(lib.MainContainer, {Size = UDim2.new(0, lib.MainContainer.Size.X.Offset, 0, 520)}, 0.3, Enum.EasingStyle.Back)
                            end
                        end
                    end
                end
            elseif Config.AimKey and input.KeyCode == Config.AimKey then
                Config.AutoAimEnabled = not Config.AutoAimEnabled
                Core.Drawings.FOVCircle.Visible = Config.AutoAimEnabled
                local color = Config.AutoAimEnabled and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 200, 50)
                Utility.AddKillFeedEntry("Auto-Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF"), color)
                
                -- Sync the UI button text if it exists
                if Core.UI.SyncAutoAimButton then
                    Core.UI.SyncAutoAimButton()
                end
            elseif Config.NearestTargetKey and input.KeyCode == Config.NearestTargetKey then
                if Core.Aim and Core.Aim.SnapToNearest then
                    Core.Aim.SnapToNearest()
                end
            end
            
            EventManager:Fire("OnInput", input)
        end))

        print("⚡ Pure Auto-Aim v3.0.0 Loaded (Scalable). RightShift = toggle UI | CapsLock = toggle aim")
    end

    return MainLoop
end
