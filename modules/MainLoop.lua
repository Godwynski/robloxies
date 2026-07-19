return function(Core)
    local MainLoop = {}

    local Config = Core.Config
    local State = Core.State
    local Utility = Core.Utility
    local Services = Core.Services
    local EventManager = Core.EventManager

    local NetworkPing = 0
    local LastFrame = tick()
    local FPS = 0

    function MainLoop.Init()
        -- Ping polling loop
        task.spawn(function()
            while Core.State.Running do
                pcall(function() NetworkPing = math.floor(Services.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
                task.wait(1)
            end
        end)

        Services.RunService:BindToRenderStep("PureAutoAimLoop", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
            local now = tick()
            FPS = math.floor(1 / math.max(now - LastFrame, 0.001))
            LastFrame = now

            -- Prepare render context to pass to modules
            local context = {
                deltaTime = deltaTime,
                FPS = FPS,
                NetworkPing = NetworkPing,
                Camera = workspace.CurrentCamera,
                MouseLocation = Services.UserInputService:GetMouseLocation(),
                ViewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(0, 0)
            }

            EventManager:Fire("OnRender", context)
            
            -- Update floating circle status indicator
            if Core.UI and Core.UI.UpdateFloatStatus then
                pcall(Core.UI.UpdateFloatStatus)
            end
        end)

        Utility.RegisterConnection(Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            
            if input.KeyCode == Enum.KeyCode.RightShift then
                if Core.UI.Window and Core.UI.Window.Library then
                    local lib = Core.UI.Window.Library
                    if lib.FloatingCircle and lib.FloatingCircle.Visible then
                        lib.FloatingCircle.Visible = false
                        lib.MainContainer.Visible = true
                    elseif lib.MainContainer then
                        lib.MainContainer.Visible = not lib.MainContainer.Visible
                    end
                end
            elseif input.KeyCode == Enum.KeyCode.CapsLock then
                Config.AutoAimEnabled = not Config.AutoAimEnabled
                Core.Drawings.FOVCircle.Visible = Config.AutoAimEnabled
                local color = Config.AutoAimEnabled and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 200, 50)
                Utility.AddKillFeedEntry("Auto-Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF"), color)
                
                -- Sync the UI button text if it exists
                if Core.UI.SyncAutoAimButton then
                    Core.UI.SyncAutoAimButton()
                end
            end
            
            EventManager:Fire("OnInput", input)
        end))

        print("⚡ Pure Auto-Aim v3.0.0 Loaded (Scalable). RightShift = toggle UI | CapsLock = toggle aim")
    end

    return MainLoop
end
