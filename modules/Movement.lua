return function(Core)
    local Movement = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local LocalPlayer = Core.Services.Players.LocalPlayer
    local RunService = Core.Services.RunService
    local UserInputService = Core.Services.UserInputService

    function Movement.Init()
        -- Infinite Jump Logic
        Utility.RegisterConnection(UserInputService.JumpRequest:Connect(function()
            if Config.InfiniteJumpEnabled then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end))

        -- NoClip Logic (Stepped runs before physics simulation)
        Utility.RegisterConnection(RunService.Stepped:Connect(function()
            if not Config.NoClipEnabled then return end
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = false
                    end
                end
            end
        end))

        -- WalkSpeed & JumpPower Enforcement (Heartbeat is better for physics)
        Utility.RegisterConnection(RunService.Heartbeat:Connect(function()
            if not Config.WalkSpeedEnabled and not Config.JumpPowerEnabled then return end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if Config.WalkSpeedEnabled and hum.WalkSpeed ~= Config.WalkSpeed then
                    hum.WalkSpeed = Config.WalkSpeed
                end
                
                if Config.JumpPowerEnabled then
                    if hum.UseJumpPower then
                        if hum.JumpPower ~= Config.JumpPower then
                            hum.JumpPower = Config.JumpPower
                        end
                    else
                        -- In case the game uses JumpHeight instead
                        local targetHeight = Config.JumpPower * 0.144
                        if math.abs(hum.JumpHeight - targetHeight) > 0.1 then
                            hum.JumpHeight = targetHeight
                        end
                    end
                end
            end
        end))
    end

    return Movement
end
