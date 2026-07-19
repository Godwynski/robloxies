return function(Core)
    local Movement = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local LocalPlayer = Core.Services.Players.LocalPlayer
    local RunService = Core.Services.RunService
    local UserInputService = Core.Services.UserInputService

    -- Cache original WalkSpeed/JumpPower so we can restore them when disabled (#7)
    local originalWalkSpeed = nil
    local originalJumpPower = nil
    local originalJumpHeight = nil

    -- Cache of parts whose CanCollide was changed by NoClip, for restoration (#6)
    local noClipCache = {}

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
            local char = LocalPlayer.Character
            if not char then return end

            if Config.NoClipEnabled then
                -- Disable collision and remember which parts we touched
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if part.CanCollide then
                            -- Store original value only once per part
                            if noClipCache[part] == nil then
                                noClipCache[part] = true
                            end
                            part.CanCollide = false
                        end
                    end
                end
            else
                -- Restore CanCollide for all parts we previously disabled (#6)
                if next(noClipCache) then
                    for part, _ in pairs(noClipCache) do
                        if part and part.Parent then
                            part.CanCollide = true
                        end
                    end
                    table.clear(noClipCache)
                end
            end
        end))

        -- WalkSpeed & JumpPower Enforcement (Heartbeat is better for physics)
        Utility.RegisterConnection(RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end

            -- Capture originals once before we override anything (#7)
            if Config.WalkSpeedEnabled then
                if originalWalkSpeed == nil then
                    originalWalkSpeed = hum.WalkSpeed
                end
                if hum.WalkSpeed ~= Config.WalkSpeed then
                    hum.WalkSpeed = Config.WalkSpeed
                end
            else
                -- Restore original WalkSpeed when disabled (#7)
                if originalWalkSpeed ~= nil then
                    hum.WalkSpeed = originalWalkSpeed
                    originalWalkSpeed = nil
                end
            end

            if Config.JumpPowerEnabled then
                if hum.UseJumpPower then
                    if originalJumpPower == nil then
                        originalJumpPower = hum.JumpPower
                    end
                    if hum.JumpPower ~= Config.JumpPower then
                        hum.JumpPower = Config.JumpPower
                    end
                else
                    -- Fix #19: use workspace.Gravity instead of hardcoded constant
                    -- Correct formula: JumpHeight = JumpPower² / (2 * gravity)
                    local gravity = workspace.Gravity > 0 and workspace.Gravity or 196.2
                    local targetHeight = (Config.JumpPower * Config.JumpPower) / (2 * gravity)
                    if originalJumpHeight == nil then
                        originalJumpHeight = hum.JumpHeight
                    end
                    if math.abs(hum.JumpHeight - targetHeight) > 0.1 then
                        hum.JumpHeight = targetHeight
                    end
                end
            else
                -- Restore original JumpPower/JumpHeight when disabled (#7)
                if originalJumpPower ~= nil then
                    hum.JumpPower = originalJumpPower
                    originalJumpPower = nil
                end
                if originalJumpHeight ~= nil then
                    hum.JumpHeight = originalJumpHeight
                    originalJumpHeight = nil
                end
            end
        end))

        -- Reset caches on respawn so originals are re-captured from fresh character
        Utility.RegisterConnection(LocalPlayer.CharacterAdded:Connect(function()
            originalWalkSpeed = nil
            originalJumpPower = nil
            originalJumpHeight = nil
            table.clear(noClipCache)
        end))
    end

    return Movement
end
