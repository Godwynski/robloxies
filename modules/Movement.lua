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
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end))

        -- WalkSpeed & JumpPower Enforcement (RenderStepped for immediate client response)
        Utility.RegisterConnection(RunService.RenderStepped:Connect(function()
            if not Config.WalkSpeedEnabled and not Config.JumpPowerEnabled then return end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if Config.WalkSpeedEnabled then
                    hum.WalkSpeed = Config.WalkSpeed
                end
                
                if Config.JumpPowerEnabled then
                    if hum.UseJumpPower then
                        hum.JumpPower = Config.JumpPower
                    else
                        -- In case the game uses JumpHeight instead
                        hum.JumpHeight = Config.JumpPower * 0.144
                    end
                end
            end
        end))
    end

    return Movement
end
