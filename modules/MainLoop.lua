return function(Core)
    local MainLoop = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services

    local function isValidKey(key)
        return key ~= nil and key ~= Enum.KeyCode.None and key ~= Enum.KeyCode.Unknown
    end

    local function matchesKey(boundKey, inputKey)
        return isValidKey(boundKey) and inputKey == boundKey
    end

    function MainLoop.Init()
        -- Keybind handling
        Utility.RegisterConnection(Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            -- Only process keyboard inputs; ignore mouse clicks, touches, and non-keyboard events
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if not isValidKey(input.KeyCode) then return end

            -- Toggle Menu
            if matchesKey(Config.MenuKey, input.KeyCode) then
                if Core.UI and Core.UI.Window and Core.UI.Window.Library then
                    local lib = Core.UI.Window.Library
                    if lib.ToggleWindow then
                        lib:ToggleWindow()
                    elseif lib.MainContainer then
                        lib.MainContainer.Visible = not lib.MainContainer.Visible
                    end
                end

            -- Toggle No-Clip
            elseif matchesKey(Config.ToggleNoClipKey, input.KeyCode) then
                Config.NoClipEnabled = not Config.NoClipEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
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
            elseif matchesKey(Config.ToggleSpeedKey, input.KeyCode) then
                Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
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
            elseif matchesKey(Config.ToggleJumpKey, input.KeyCode) then
                Config.JumpPowerEnabled = not Config.JumpPowerEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
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
            elseif matchesKey(Config.ToggleInfJumpKey, input.KeyCode) then
                Config.InfiniteJumpEnabled = not Config.InfiniteJumpEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
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
