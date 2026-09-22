return function(Core)
    local Utility = {}
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer
    local Config = Core.Config

    function Utility.RegisterConnection(conn)
        table.insert(Core.State.ActiveConnections, conn)
        return conn
    end

    function Utility.SafeDestroy(obj)
        if not obj then return end
        if typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        elseif type(obj) == "table" or type(obj) == "userdata" then
            pcall(function()
                if obj.Remove then
                    obj:Remove()
                elseif obj.Destroy then
                    obj:Destroy()
                end
            end)
        end
    end

    -- Downward raycasting helper with multi-floor height support
    function Utility.GetGroundPosition(targetPos, ignoreList)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local list = ignoreList or {}
        if LocalPlayer and LocalPlayer.Character then
            table.insert(list, LocalPlayer.Character)
        end
        raycastParams.FilterDescendantsInstances = list
        raycastParams.IgnoreWater = true

        -- Multi-floor support: Use tight bounded search (8 studs down) to avoid dropping to lower floors
        local downDistance = Config.MultiFloorSafeRaycast and -10 or -30
        local origin = targetPos + Vector3.new(0, 3, 0)
        local direction = Vector3.new(0, downDistance, 0)
        local result = workspace:Raycast(origin, direction, raycastParams)

        if result and result.Position then
            return result.Position + Vector3.new(0, 3, 0)
        end
        return targetPos + Vector3.new(0, 2.5, 0)
    end

    -- GPU Saver / 3D Rendering Toggle
    function Utility.SetGPUSaver(enabled)
        pcall(function()
            Services.RunService:Set3dRenderingEnabled(not enabled)
        end)
    end

    -- Auto-Claim finished quests, achievements, and free playtime gifts from UI
    function Utility.ClaimQuestsAndGifts()
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return 0 end
        local claimed = 0

        for _, btn in ipairs(pg:GetDescendants()) do
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                local name = btn.Name:lower()
                local parentName = (btn.Parent and btn.Parent.Name or ""):lower()

                if btn.Visible and (
                    text == "claim" or text == "collect" or text == "reward" or
                    name:find("claim", 1, true) or name:find("reward", 1, true) or
                    parentName:find("quest", 1, true) or parentName:find("gift", 1, true)
                ) then
                    pcall(function()
                        if type(firesignal) == "function" and btn.Activated then
                            firesignal(btn.Activated)
                        elseif btn.Activate then
                            btn:Activate()
                        end
                        claimed = claimed + 1
                    end)
                end
            end
        end
        return claimed
    end

    -- Redeem known active promotional codes automatically
    function Utility.RedeemKnownCodes()
        local codes = {"FISHIES", "RAR4EVER"}
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return 0 end
        local redeemed = 0

        for _, desc in ipairs(pg:GetDescendants()) do
            if desc:IsA("TextBox") then
                local boxName = desc.Name:lower()
                local parentName = (desc.Parent and desc.Parent.Name or ""):lower()
                local ph = (desc.PlaceholderText or ""):lower()

                if boxName:find("code") or parentName:find("code") or ph:find("code") then
                    local submitBtn = nil
                    for _, sibling in ipairs(desc.Parent:GetChildren()) do
                        if (sibling:IsA("TextButton") or sibling:IsA("ImageButton")) and sibling ~= desc then
                            local sName = sibling.Name:lower()
                            local sText = (sibling:IsA("TextButton") and sibling.Text or ""):lower()
                            if sName:find("submit") or sName:find("enter") or sName:find("redeem") or sText:find("submit") or sText:find("redeem") then
                                submitBtn = sibling
                                break
                            end
                        end
                    end

                    for _, code in ipairs(codes) do
                        desc.Text = code
                        if submitBtn then
                            pcall(function()
                                if type(firesignal) == "function" and submitBtn.Activated then
                                    firesignal(submitBtn.Activated)
                                elseif submitBtn.Activate then
                                    submitBtn:Activate()
                                end
                            end)
                        end
                        redeemed = redeemed + 1
                        task.wait(0.25)
                    end
                end
            end
        end
        return redeemed
    end

    -- Setup Anti-AFK Listener
    local VirtualUser = game:GetService("VirtualUser")
    if LocalPlayer then
        Utility.RegisterConnection(LocalPlayer.Idled:Connect(function()
            if Config.AntiAFKEnabled then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end))
    end

    -- Setup 24/7 Auto-Rejoin on Disconnect or Server Kick (Only on explicit ErrorPrompt)
    function Utility.SetupAutoRejoin()
        local TeleportService = game:GetService("TeleportService")

        pcall(function()
            local overlay = Services.CoreGui:WaitForChild("RobloxPromptGui", 5)
            if overlay then
                local prompt = overlay:WaitForChild("promptOverlay", 5)
                if prompt then
                    Utility.RegisterConnection(prompt.ChildAdded:Connect(function(child)
                        if Config.AutoRejoinEnabled and child.Name == "ErrorPrompt" then
                            task.wait(2.5)
                            pcall(function()
                                TeleportService:Teleport(game.PlaceId, LocalPlayer)
                            end)
                        end
                    end))
                end
            end
        end)
    end
    Utility.SetupAutoRejoin()

    function Utility.Terminate()
        local State = Core.State
        State.Running = false
        _G.__Movement_Running = false
        _G.__Restaurant_Running = false
        _G.__Movement_Terminate = nil
        _G.__Restaurant_Terminate = nil
        _G.loadModule = nil
        pcall(function()
            if getgenv then getgenv().loadModule = nil end
        end)

        -- Restore 3D rendering in case GPU saver was active
        pcall(function()
            Services.RunService:Set3dRenderingEnabled(true)
        end)

        -- Disconnect all event connections
        for _, conn in ipairs(State.ActiveConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
        table.clear(State.ActiveConnections)

        -- Clean up Restaurant module
        if Core.Restaurant and Core.Restaurant.Cleanup then
            pcall(Core.Restaurant.Cleanup)
        end

        -- Restore Movement physics if active
        if Core.Movement and Core.Movement.Cleanup then
            pcall(Core.Movement.Cleanup)
        end

        -- Clean up UI ScreenGui directly if cached
        pcall(function()
            if Core.UI and Core.UI.Window and Core.UI.Window.Library and Core.UI.Window.Library.Interface then
                Core.UI.Window.Library.Interface:Destroy()
            end
        end)

        -- Clean up all UI ScreenGui instances across all possible containers
        local containers = {
            (gethui and gethui()) or nil,
            Services.CoreGui,
            Services.Players.LocalPlayer and Services.Players.LocalPlayer:FindFirstChild("PlayerGui"),
        }
        for _, parent in ipairs(containers) do
            if parent then
                pcall(function()
                    for _, child in ipairs(parent:GetChildren()) do
                        if child.Name == "RestaurantUtilityPanel" or child.Name == "RobloxMovementPanel" or child.Name == "PureAutoAimPanel" then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end)
            end
        end

        print("🍽️ Run a Restaurant Utility has been completely unloaded.")
    end

    return Utility
end
