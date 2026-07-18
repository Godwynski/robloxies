return function(Core)
    local MainLoop = {}

    local Config = Core.Config
    local State = Core.State
    local Utility = Core.Utility
    local Drawings = Core.Drawings
    local LocalPlayer = Core.Services.Players.LocalPlayer
    local RunService = Core.Services.RunService
    local UserInputService = Core.Services.UserInputService
    local Aim = Core.Aim
    local ESP = Core.ESP
    local Stats = Core.Services.Stats


    local NetworkPing = 0
    local LastFrame = tick()
    local FPS = 0

    function MainLoop.Init()
        task.spawn(function()
            while true do
                pcall(function() NetworkPing = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
                task.wait(1)
            end
        end)

        RunService:BindToRenderStep("AutoAimLoop", Enum.RenderPriority.Camera.Value + 1, function()
            local now = tick()
            FPS = math.floor(1 / math.max(now - LastFrame, 0.001))
            LastFrame = now

            local Camera = workspace.CurrentCamera
            local mouseLoc = UserInputService:GetMouseLocation()
            local viewport = Camera.ViewportSize

            if Drawings.FOVCircle then
                Drawings.FOVCircle.Position = mouseLoc
                Drawings.FOVCircle.Radius = Config.ViewAngle
            end

            local target = nil
            local aimState = "Disabled"

            if Config.AutoAimEnabled then
                target, aimState = Aim.GetTarget()

                if target then
                    Drawings.FOVCircle.Color = Color3.fromRGB(50, 255, 50)
                else
                    Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
                end

                if target then
                    local aimPos = target.Position
                    if Config.Prediction then
                        local vel = Vector3.zero
                        pcall(function()
                            vel = target.AssemblyLinearVelocity or target.Velocity or Vector3.zero
                        end)
                        aimPos = aimPos + vel * Config.PredictionScale
                    end

                    if Config.TrackingMethod == "Mouse" then
                        local sp, onScreen = workspace.CurrentCamera:WorldToScreenPoint(aimPos)
                        if onScreen then
                            local dx = (sp.X - mouseLoc.X) / Config.Smoothing
                            local dy = (sp.Y - mouseLoc.Y) / Config.Smoothing
                            pcall(function() mousemoverel(dx, dy) end)
                        end
                    elseif Config.TrackingMethod == "Camera" then
                        local curCF = workspace.CurrentCamera.CFrame
                        local tgtCF = CFrame.new(curCF.Position, aimPos)
                        local alpha = math.clamp(1 / Config.Smoothing, 0.01, 1)
                        workspace.CurrentCamera.CFrame = curCF:Lerp(tgtCF, alpha)
                    end
                end
            else
                Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
            end

            if Config.ESPEnabled then
                pcall(ESP.UpdateESP)
            else
                for _, cache in pairs(State.ESPCache) do
                    ESP.HideESPDrawings(cache)
                end
            end

            if Config.TargetInfoEnabled and target then
                local sp, onScreen = workspace.CurrentCamera:WorldToScreenPoint(target.Position)
                if onScreen then
                    local char = target.Parent
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local name = char and char.Name or "?"
                    local hp = hum and hum.Health or 0
                    local maxHp = hum and hum.MaxHealth or 100
                    local hpPct = math.clamp(hp / math.max(maxHp, 1), 0, 1)

                    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local dist = myRoot and math.floor((target.Position - myRoot.Position).Magnitude) or 0

                    Drawings.TargetInfoText.Text = string.format("%s  [%dm]", name, dist)
                    Drawings.TargetInfoText.Position = Vector2.new(sp.X, sp.Y - 35)
                    Drawings.TargetInfoText.Visible = true

                    local barW = 60
                    local barH = 4
                    Drawings.TargetHealthBG.Size = Vector2.new(barW, barH)
                    Drawings.TargetHealthBG.Position = Vector2.new(sp.X - barW/2, sp.Y - 22)
                    Drawings.TargetHealthBG.Visible = true

                    Drawings.TargetHealthFill.Size = Vector2.new(barW * hpPct, barH)
                    Drawings.TargetHealthFill.Position = Vector2.new(sp.X - barW/2, sp.Y - 22)
                    Drawings.TargetHealthFill.Visible = true

                    if hpPct > 0.6 then Drawings.TargetHealthFill.Color = Color3.fromRGB(50, 200, 50)
                    elseif hpPct > 0.3 then Drawings.TargetHealthFill.Color = Color3.fromRGB(255, 200, 50)
                    else Drawings.TargetHealthFill.Color = Color3.fromRGB(255, 60, 60) end

                    Drawings.LockIndicator.Position = Vector2.new(sp.X, sp.Y)
                    Drawings.LockIndicator.Visible = true
                else
                    Drawings.TargetInfoText.Visible = false
                    Drawings.TargetHealthBG.Visible = false
                    Drawings.TargetHealthFill.Visible = false
                    Drawings.LockIndicator.Visible = false
                end
            else
                Drawings.TargetInfoText.Visible = false
                Drawings.TargetHealthBG.Visible = false
                Drawings.TargetHealthFill.Visible = false
                Drawings.LockIndicator.Visible = false
            end

            if (now - State.HitMarkerTime) < 0.3 then
                Drawings.HitMarker.Position = Vector2.new(viewport.X / 2, viewport.Y / 2)
                Drawings.HitMarker.Visible = true
            else
                Drawings.HitMarker.Visible = false
            end

            if Config.KillFeedEnabled then
                local feedX = viewport.X - 20
                local feedY = 60
                for i, entry in ipairs(State.KillFeedEntries) do
                    local d = Drawings.KillFeedDrawings[i]
                    if d then
                        local age = now - entry.time
                        if age < 5 then
                            d.Text = entry.text
                            d.Color = entry.color
                            d.Position = Vector2.new(feedX - d.TextBounds.X, feedY + (i-1) * 20)
                            d.Transparency = math.clamp(1 - ((age - 3.5) / 1.5), 0, 1)
                            d.Visible = true
                        else
                            d.Visible = false
                        end
                    end
                end
                for i = #State.KillFeedEntries + 1, Drawings.MAX_KILLFEED do
                    if Drawings.KillFeedDrawings[i] then Drawings.KillFeedDrawings[i].Visible = false end
                end
            else
                for _, d in ipairs(Drawings.KillFeedDrawings) do d.Visible = false end
            end

            if Config.DiagnosticsEnabled and Drawings.DiagnosticText then
                local camType = workspace.CurrentCamera and workspace.CurrentCamera.CameraType.Name or "?"
                local tgtStr = target and target.Parent.Name or "None"
                local tgtHP = "N/A"
                if target then
                    local h = target.Parent and target.Parent:FindFirstChildOfClass("Humanoid")
                    if h then tgtHP = string.format("%.0f/%.0f", h.Health, h.MaxHealth) end
                end

                local ws, jp, jh, ps = 0, 0, 0, "N/A"
                local lc = LocalPlayer.Character
                if lc then
                    local h = lc:FindFirstChildOfClass("Humanoid")
                    if h then
                        ws = h.WalkSpeed; jp = h.JumpPower; jh = h.JumpHeight
                        pcall(function() ps = h:GetState().Name end)
                    end
                end

                local kda = string.format("K:%d D:%d A:%d", State.KillCount, State.DeathCount, State.AssistCount)

                Drawings.DiagnosticText.Text = string.format(
                    "--- Diagnostics ---\nFPS: %d | Ping: %d ms\nAim: %s | %s\nCam: %s | Track: %s\nTarget: %s (%s)\nPriority: %s | Sticky: %s\n--- Physics ---\nSpeed: %.1f | JP: %.1f | JH: %.1f\nState: %s | Gravity: %.1f\n--- Stats ---\n%s | Alive: %s",
                    FPS, NetworkPing, aimState, Config.Prediction and "PRED" or "STD",
                    camType, Config.TrackingMethod,
                    tgtStr, tgtHP,
                    Config.PriorityMode, Config.StickyTarget and "ON" or "OFF",
                    ws, jp, jh, ps, workspace.Gravity,
                    kda, State.IsAlive and "Yes" or "No"
                )
                Drawings.DiagnosticText.Position = mouseLoc + Vector2.new(40, -60)
                Drawings.DiagnosticText.Visible = true
            else
                if Drawings.DiagnosticText then Drawings.DiagnosticText.Visible = false end
            end

            -- Update floating circle status indicator
            if Core.UI and Core.UI.UpdateFloatStatus then
                pcall(Core.UI.UpdateFloatStatus)
            end
        end)

        Utility.RegisterConnection(UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.RightShift then
                -- Handle minimize state properly
                if Core.UI and Core.UI.FloatingCircle and Core.UI.FloatingCircle.Visible then
                    Core.UI.FloatingCircle.Visible = false
                    Core.UI.MainContainer.Visible = true
                elseif Core.UI and Core.UI.MainContainer then
                    Core.UI.MainContainer.Visible = not Core.UI.MainContainer.Visible
                end
            elseif input.KeyCode == Enum.KeyCode.CapsLock then
                Config.AutoAimEnabled = not Config.AutoAimEnabled
                Drawings.FOVCircle.Visible = Config.AutoAimEnabled
                local color = Config.AutoAimEnabled and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 200, 50)
                Utility.AddKillFeedEntry("Auto-Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF"), color)
            elseif input.KeyCode == Config.NearestTargetKey then
                Aim.SnapToNearest()
            end
        end))

        print("⚡ Pure Auto-Aim v2.2 Loaded (Modular). RightShift = toggle UI | CapsLock = toggle aim | T = snap nearest")
    end

    return MainLoop
end
