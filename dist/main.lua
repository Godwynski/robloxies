-- init.lua
local repoURL = "https://raw.githubusercontent.com/Godwynski/robloxies/run-a-restaurant/"

-- Terminate previous instance if running
if _G.__Restaurant_Running then
    pcall(function() _G.__Restaurant_Terminate() end)
end
if _G.__Movement_Running then
    pcall(function() _G.__Movement_Terminate() end)
end
if _G.__PureAutoAim_Running then
    pcall(function() _G.__PureAutoAim_Terminate() end)
end
_G.__Restaurant_Running = true

-- Clean up any lingering GUI instances
local hiddenUI = (gethui and gethui()) or game:GetService("CoreGui")
for _, gui in ipairs(hiddenUI:GetChildren()) do
    if gui.Name == "RestaurantUtilityPanel" or gui.Name == "RobloxMovementPanel" or gui.Name == "PureAutoAimPanel" then
        pcall(function() gui:Destroy() end)
    end
end
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name == "RestaurantUtilityPanel" or gui.Name == "RobloxMovementPanel" or gui.Name == "PureAutoAimPanel" then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end)

-- Helper loader supporting both modular HttpGet and bundled execution
local loadModule
loadModule = function(modulePath)
    local ok, res = pcall(require, modulePath)
    if ok and res then return res end

    local filePath = modulePath:gsub("%.", "/") .. ".lua"
    local url = repoURL .. filePath
    local success, src = pcall(game.HttpGet, game, url)
    if not success or not src or #src == 0 then
        error("Failed to download module '" .. modulePath .. "' from " .. url)
    end
    local fn, err = loadstring(src)
    if not fn then
        error("Failed to compile module '" .. modulePath .. "': " .. tostring(err))
    end
    return fn()
end
_G.loadModule = loadModule
if getgenv then getgenv().loadModule = loadModule end

print("Initializing Run a Restaurant Utility...")

if not game:IsLoaded() then game.Loaded:Wait() end

-- 1. Construct Core System
local Core = {
    Services = {
        Players = game:GetService("Players"),
        RunService = game:GetService("RunService"),
        UserInputService = game:GetService("UserInputService"),
        CoreGui = game:GetService("CoreGui"),
    }
}

-- 2. Load Core Data & Utility
Core.Config = (function()
return function(Core)
    local Config = {
        -- Master Switch
        MasterAutoFarmEnabled = false,

        -- Restaurant Core Automation
        AutoSeatEnabled = false,
        AutoOrderEnabled = false,
        AutoCookEnabled = false,
        AutoServeEnabled = false,
        AutoCleanEnabled = false,
        AutoCollectCashEnabled = false,
        AutoFarmEnabled = false,
        AutoDeliveryEnabled = false,
        AutoRestockEnabled = false,
        AutoClaimQuestsEnabled = true,
        AutoClaimRewardsEnabled = true,
        AutoExpandEnabled = false,
        AutoBuyEnabled = false,
        AutoPlaceEnabled = false,
        AutoHireStaffEnabled = false,
        AutoBuyStoves = true,
        AutoBuyTables = true,
        AutoBuyChairs = true,
        AutoBuyAppliances = true,
        AutoBuyFurniture = true,
        AutoPlaceTables = true,
        AutoPlaceChairs = true,
        AutoPlaceFurniture = true,
        VIPPriorityEnabled = true,
        InstantPromptEnabled = true,
        ActionDelay = 0.3,
        StationStayDelay = 0.22,
        StrictTaskCompletion = true,
        PostActionDelay = 0.18,
        MaxScanRadius = 120,

        -- Multi-Queue Pipeline & Concurrency
        ConcurrentExecutionEnabled = true,
        InterleavedPipelineEnabled = true,
        StationBatchSize = 3,
        RemotePromptBatching = true,

        -- Teleport & Navigation
        AutoTeleportEnabled = true,
        TeleportDelay = 0.15,
        PlotScopingEnabled = true,
        PreventSitting = true,
        MultiFloorSafeRaycast = true,

        -- AFK & Performance
        AntiAFKEnabled = true,
        AutoRejoinEnabled = false,
        GPUSaverEnabled = false,

        -- Movement Physics
        WalkSpeedEnabled = false,
        WalkSpeed = 16,
        JumpPowerEnabled = false,
        JumpPower = 50,
        InfiniteJumpEnabled = false,
        NoClipEnabled = false,

        -- Keybinds
        MenuKey = Enum.KeyCode.RightShift,
        ToggleNoClipKey = Enum.KeyCode.N,
        ToggleSpeedKey = Enum.KeyCode.None,
        ToggleJumpKey = Enum.KeyCode.None,
        ToggleInfJumpKey = Enum.KeyCode.None,
    }

    local HttpService = game:GetService("HttpService")
    local fileName = "Restaurant_Config.json"

    function Config:Save()
        if type(writefile) ~= "function" then return false end
        local saveTable = {}
        for k, v in pairs(self) do
            if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                saveTable[k] = v
            elseif typeof(v) == "EnumItem" then
                saveTable[k] = {Type = "EnumItem", EnumType = tostring(v.EnumType), Name = v.Name}
            end
        end
        local ok, _ = pcall(function()
            writefile(fileName, HttpService:JSONEncode(saveTable))
        end)
        return ok
    end

    function Config:Load()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local ok, data = pcall(function()
            if isfile(fileName) then
                return HttpService:JSONDecode(readfile(fileName))
            end
            return nil
        end)
        if not ok or type(data) ~= "table" then return false end

        for k, v in pairs(data) do
            if type(self[k]) ~= "function" then
                if type(v) == "table" and v.Type == "EnumItem" then
                    pcall(function()
                        local enumName = tostring(v.EnumType):gsub("^Enum%.", "")
                        if Enum[enumName] and Enum[enumName][v.Name] then
                            self[k] = Enum[enumName][v.Name]
                        end
                    end)
                else
                    self[k] = v
                end
            end
        end
        return true
    end

    return Config
end

end)()(Core)
Core.State = (function()
return function(Core)
    local State = {
        ActiveConnections = {},
        InFlightTasks = setmetatable({}, {__mode = "k"}),
        Running = true,
        Stats = {
            CustomersSeated = 0,
            OrdersTaken = 0,
            DishesCooked = 0,
            DishesServed = 0,
            TablesCleaned = 0,
            CashCollected = 0,
            CropsHarvested = 0,
            DeliveriesCompleted = 0,
            StorageRestocked = 0,
            QuestsClaimed = 0,
            RewardsClaimed = 0,
            ExpansionsPurchased = 0,
            ItemsPurchased = 0,
            ItemsPlaced = 0,
            StaffHired = 0,
        },
    }
    return State
end

end)()(Core)
Core.Utility = (function()
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

    -- Auto-Claim all finished quests, daily gifts, playtime rewards, spin wheels, and achievements
    function Utility.ClaimAllRewards()
        if not Config.AutoClaimRewardsEnabled and not Config.AutoClaimQuestsEnabled then return 0 end
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local claimed = 0

        -- 1. Scan PlayerGui for claim, reward, gift, daily, spin, milestone buttons
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local name = btn.Name:lower()
                    local parentName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local grandParentName = (btn.Parent and btn.Parent.Parent and btn.Parent.Parent.Name or ""):lower()

                    local isClaimText = text == "claim" or text == "collect" or text == "reward" or text == "open" or text == "free" or text == "spin" or text == "redeem"
                    local hasClaimWord = text:find("claim") or text:find("collect") or text:find("reward") or text:find("free gift") or text:find("daily") or text:find("spin")
                    local hasRewardName = name:find("claim") or name:find("reward") or name:find("collect") or name:find("gift") or name:find("spin") or name:find("daily")
                    local isRewardContainer = parentName:find("quest") or parentName:find("gift") or parentName:find("reward") or parentName:find("daily") or parentName:find("milestone") or grandParentName:find("reward")

                    if not text:find("robux") and not text:find("buy") and not text:find("purchase") and not text:find("cancel") and not text:find("close") then
                        if isClaimText or hasClaimWord or (hasRewardName and (isRewardContainer or text ~= "")) then
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
            end
        end

        -- 2. Check ReplicatedStorage reward claiming remotes
        local rs = game:GetService("ReplicatedStorage")
        local remoteNames = {
            "ClaimReward", "ClaimDaily", "ClaimDailyReward", "ClaimGift",
            "ClaimPlaytime", "ClaimQuest", "ClaimGoal", "ClaimAchievement",
            "ClaimMilestone", "ClaimPass", "ClaimFreeGift", "SpinWheel", "FreeSpin"
        }
        for _, rName in ipairs(remoteNames) do
            local remote = rs:FindFirstChild(rName, true)
            if remote and remote:IsA("RemoteEvent") then
                pcall(function()
                    remote:FireServer()
                    claimed = claimed + 1
                end)
            elseif remote and remote:IsA("RemoteFunction") then
                pcall(function()
                    remote:InvokeServer()
                    claimed = claimed + 1
                end)
            end
        end

        if claimed > 0 and Core.State and Core.State.Stats then
            Core.State.Stats.RewardsClaimed = (Core.State.Stats.RewardsClaimed or 0) + claimed
            Core.State.Stats.QuestsClaimed = (Core.State.Stats.QuestsClaimed or 0) + claimed
        end

        return claimed
    end
    Utility.ClaimQuestsAndGifts = Utility.ClaimAllRewards

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

end)()(Core)

-- 3. Load UI Director & Build Tabs
Core.UI = (function()
return function(Core)
    local UI = {}
    local Config = Core.Config
    local Utility = Core.Utility
    local State = Core.State

    function UI.Init()
        local UILibrary = (function()
return function(Core)
    local UILibrary = {}
    local Services = Core.Services
    local Utility = Core.Utility
    local TweenService = game:GetService("TweenService")

    local Theme = {
        Background = Color3.fromRGB(14, 16, 22),
        Header = Color3.fromRGB(10, 12, 16),
        Stroke = Color3.fromRGB(38, 42, 58),
        TextPrimary = Color3.fromRGB(240, 242, 248),
        TextSecondary = Color3.fromRGB(140, 148, 168),
        TextAccent = Color3.fromRGB(160, 140, 255),
        ElementIdle = Color3.fromRGB(22, 26, 36),
        ElementHover = Color3.fromRGB(34, 40, 56),
        ElementActive = Color3.fromRGB(110, 86, 255),
        Success = Color3.fromRGB(110, 86, 255),
        SliderFill = Color3.fromRGB(124, 92, 255),
        CloseButton = Color3.fromRGB(220, 60, 80),
    }
    UILibrary.Theme = Theme -- Expose theme for UI.lua

    local function tween(object, properties, time, style, direction)
        time = time or 0.2
        style = style or Enum.EasingStyle.Sine
        direction = direction or Enum.EasingDirection.Out
        local tw = TweenService:Create(object, TweenInfo.new(time, style, direction), properties)
        tw:Play()
        return tw
    end
    UILibrary.Tween = tween

    -- State for dragging/resizing
    local floatDragging, floatHasMoved, floatDragStart, floatStartPos
    local dragging, dragStart, startPos
    local resizing, resizeStart, sizeStart
    local activeSliderId = nil
    local sliderCallbacks = {}
    local sliderIdCounter = 0

    local activeKeybindBtn = nil
    local activeKeybindCb = nil

    -- Shared Input handlers for entire UI
    function UILibrary:InitInputDispatchers()
        Utility.RegisterConnection(Services.UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            
            if floatDragging then
                local delta = input.Position - floatDragStart
                if delta.Magnitude > 3 then
                    floatHasMoved = true
                    self.FloatingCircle.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
                end
            elseif dragging then
                local delta = input.Position - dragStart
                self.MainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            elseif resizing then
                local delta = input.Position - resizeStart
                local newW = math.clamp(sizeStart.X + delta.X, 320, 1200)
                local newH = math.clamp(sizeStart.Y + delta.Y, 260, 1000)
                self.MainContainer.Size = UDim2.new(0, newW, 0, newH)
            elseif activeSliderId then
                local cb = sliderCallbacks[activeSliderId]
                if cb then cb(input) end
            end
        end))

        Utility.RegisterConnection(Services.UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if floatDragging and not floatHasMoved then
                    self.FloatingCircle.Visible = false
                    self.MainContainer.Visible = true
                    -- Animate open
                    local targetH = self.SavedHeight or 520
                    self.MainContainer.Size = UDim2.new(0, self.MainContainer.Size.X.Offset, 0, 0)
                    tween(self.MainContainer, {Size = UDim2.new(0, self.MainContainer.Size.X.Offset, 0, targetH)}, 0.3, Enum.EasingStyle.Back)
                end
                floatDragging = false
                dragging = false
                resizing = false
                activeSliderId = nil
            end
        end))

        Utility.RegisterConnection(Services.UserInputService.InputBegan:Connect(function(input)
            if activeKeybindBtn and input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if key == Enum.KeyCode.Escape then
                    activeKeybindBtn.Text = "None"
                    activeKeybindCb(nil)
                else
                    local keyName = key.Name
                    activeKeybindBtn.Text = keyName
                    activeKeybindCb(key)
                end
                tween(activeKeybindBtn, {BackgroundColor3 = Theme.ElementIdle})
                activeKeybindBtn = nil
                activeKeybindCb = nil
            end
        end))
    end

    function UILibrary:CreateWindow(titleText)
        local Interface = Instance.new("ScreenGui")
        Interface.Name = "RestaurantUtilityPanel"
        Interface.ResetOnSpawn = false
        Interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local hiddenContainer = (gethui and gethui()) or nil
        pcall(function()
            if hiddenContainer then
                Interface.Parent = hiddenContainer
            else
                Interface.Parent = Services.CoreGui
            end
        end)
        if not Interface.Parent then
            local localPlr = Services.Players.LocalPlayer
            if localPlr then
                Interface.Parent = localPlr:WaitForChild("PlayerGui", 5) or localPlr:FindFirstChild("PlayerGui")
            end
        end
        self.Interface = Interface

        local MainContainer = Instance.new("Frame")
        MainContainer.Parent = Interface
        MainContainer.Size = UDim2.new(0, 480, 0, 520)
        MainContainer.Position = UDim2.new(0.5, -240, 0.5, -260)
        MainContainer.BackgroundColor3 = Theme.Background
        MainContainer.BorderSizePixel = 0
        MainContainer.Active = true
        Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0, 10)
        self.MainContainer = MainContainer

        local UIStroke = Instance.new("UIStroke")
        UIStroke.Parent = MainContainer
        UIStroke.Color = Theme.Stroke
        UIStroke.Thickness = 1.5

        local Header = Instance.new("Frame")
        Header.Parent = MainContainer
        Header.Size = UDim2.new(1, 0, 0, 38)
        Header.BackgroundColor3 = Theme.Header
        Header.BorderSizePixel = 0
        Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

        local HeaderBottom = Instance.new("Frame")
        HeaderBottom.Parent = Header
        HeaderBottom.Size = UDim2.new(1, 0, 0, 10)
        HeaderBottom.Position = UDim2.new(0, 0, 1, -10)
        HeaderBottom.BackgroundColor3 = Theme.Header
        HeaderBottom.BorderSizePixel = 0

        local Title = Instance.new("TextLabel")
        Title.Parent = Header
        Title.Size = UDim2.new(1, -120, 1, 0)
        Title.Position = UDim2.new(0, 12, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = titleText
        Title.TextColor3 = Theme.TextAccent
        Title.TextSize = 15
        Title.TextXAlignment = Enum.TextXAlignment.Left

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Parent = Header
        CloseBtn.Size = UDim2.new(0, 28, 0, 28)
        CloseBtn.Position = UDim2.new(1, -33, 0, 5)
        CloseBtn.BackgroundColor3 = Theme.CloseButton
        CloseBtn.Text = "✕"
        CloseBtn.TextColor3 = Theme.TextPrimary
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.TextSize = 13
        Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

        CloseBtn.MouseEnter:Connect(function()
            tween(CloseBtn, {BackgroundColor3 = Color3.fromRGB(255, 45, 65)}, 0.15)
        end)
        CloseBtn.MouseLeave:Connect(function()
            tween(CloseBtn, {BackgroundColor3 = Theme.CloseButton}, 0.15)
        end)

        Utility.RegisterConnection(CloseBtn.Activated:Connect(function()
            Utility.Terminate()
        end))

        local RefreshBtn = Instance.new("TextButton")
        RefreshBtn.Parent = Header
        RefreshBtn.Size = UDim2.new(0, 28, 0, 28)
        RefreshBtn.Position = UDim2.new(1, -66, 0, 5)
        RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
        RefreshBtn.Text = "↻"
        RefreshBtn.TextColor3 = Theme.TextPrimary
        RefreshBtn.Font = Enum.Font.GothamBold
        RefreshBtn.TextSize = 16
        Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)
        Utility.RegisterConnection(RefreshBtn.Activated:Connect(function()
            Utility.Terminate()
            Interface:Destroy()
            task.wait(0.1)
            task.spawn(function()
                local ok, err = pcall(function()
                    if isfile and isfile("dist/main.lua") then
                        loadstring(readfile("dist/main.lua"))()
                    else
                        loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/run-a-restaurant/dist/main.lua?nocache=" .. tostring(tick())))()
                    end
                end)
                if not ok then warn("[UILibrary] Refresh failed:", tostring(err)) end
            end)
        end))

        local MinimizeBtn = Instance.new("TextButton")
        MinimizeBtn.Parent = Header
        MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
        MinimizeBtn.Position = UDim2.new(1, -99, 0, 5)
        MinimizeBtn.BackgroundColor3 = Color3.fromRGB(150, 120, 50)
        MinimizeBtn.Text = "—"
        MinimizeBtn.TextColor3 = Theme.TextPrimary
        MinimizeBtn.Font = Enum.Font.GothamBold
        MinimizeBtn.TextSize = 13
        Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

        -- Floating Circle for Minimize
        local FloatingCircle = Instance.new("ImageButton")
        FloatingCircle.Parent = Interface
        FloatingCircle.Size = UDim2.new(0, 50, 0, 50)
        FloatingCircle.Position = UDim2.new(0, 20, 0.5, -25)
        FloatingCircle.BackgroundColor3 = Theme.ElementIdle
        FloatingCircle.Visible = false
        FloatingCircle.Active = true
        Instance.new("UICorner", FloatingCircle).CornerRadius = UDim.new(1, 0)
        self.FloatingCircle = FloatingCircle
        
        local FloatStroke = Instance.new("UIStroke")
        FloatStroke.Parent = FloatingCircle
        FloatStroke.Color = Theme.TextAccent
        FloatStroke.Thickness = 2
        self.FloatStroke = FloatStroke
        
        local FloatIcon = Instance.new("TextLabel")
        FloatIcon.Parent = FloatingCircle
        FloatIcon.Size = UDim2.new(1, 0, 1, 0)
        FloatIcon.BackgroundTransparency = 1
        FloatIcon.Text = "🏃"
        FloatIcon.TextSize = 24
        FloatIcon.TextColor3 = Theme.TextPrimary
        FloatIcon.Font = Enum.Font.GothamBold
        self.FloatIcon = FloatIcon

        Utility.RegisterConnection(MinimizeBtn.Activated:Connect(function()
            self.SavedHeight = MainContainer.AbsoluteSize.Y
            local tw = tween(MainContainer, {Size = UDim2.new(0, MainContainer.Size.X.Offset, 0, 0)}, 0.2)
            tw.Completed:Wait()
            MainContainer.Visible = false
            FloatingCircle.Visible = true
        end))

        Utility.RegisterConnection(FloatingCircle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                floatDragging = true; floatHasMoved = false; floatDragStart = input.Position; floatStartPos = FloatingCircle.Position
            end
        end))

        Utility.RegisterConnection(FloatingCircle.MouseButton2Click:Connect(function()
            Utility.Terminate()
        end))

        Utility.RegisterConnection(Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; dragStart = input.Position; startPos = MainContainer.Position
            end
        end))

        local ResizeBtn = Instance.new("TextButton")
        ResizeBtn.Parent = MainContainer
        ResizeBtn.Size = UDim2.new(0, 35, 0, 35)
        ResizeBtn.Position = UDim2.new(1, -35, 1, -35)
        ResizeBtn.BackgroundTransparency = 1
        ResizeBtn.Text = "↘"
        ResizeBtn.TextColor3 = Theme.TextSecondary
        ResizeBtn.Font = Enum.Font.GothamBold
        ResizeBtn.TextSize = 22
        ResizeBtn.ZIndex = 100
        ResizeBtn.Active = true

        Utility.RegisterConnection(ResizeBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = true; resizeStart = input.Position; sizeStart = MainContainer.AbsoluteSize
            end
        end))

        -- Tabs System
        self.TabBar = Instance.new("Frame")
        self.TabBar.Parent = MainContainer
        self.TabBar.Size = UDim2.new(1, -16, 0, 36)
        self.TabBar.Position = UDim2.new(0, 8, 0, 46)
        self.TabBar.BackgroundTransparency = 1

        local TabList = Instance.new("UIListLayout")
        TabList.Parent = self.TabBar
        TabList.FillDirection = Enum.FillDirection.Horizontal
        TabList.SortOrder = Enum.SortOrder.LayoutOrder
        TabList.Padding = UDim.new(0, 6)

        self.TabContainer = Instance.new("Frame")
        self.TabContainer.Parent = MainContainer
        self.TabContainer.Size = UDim2.new(1, 0, 1, -90)
        self.TabContainer.Position = UDim2.new(0, 0, 0, 90)
        self.TabContainer.BackgroundTransparency = 1

        self.Tabs = {}
        self.TabFrames = {}
        self.TabCount = 0

        self:InitInputDispatchers()
        Utility.RegisterConnection(self.TabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:UpdateTabWidths() end))
        
        local Window = { Library = self, Tabs = {} }
        function Window:AddTab(name) return self.Library:CreateTab(name) end
        function Window:SelectTab(name) self.Library:SelectTab(name) end
        return Window
    end

    function UILibrary:UpdateTabWidths()
        local available = self.TabBar.AbsoluteSize.X - (self.TabCount - 1) * 6
        local w = math.floor(available / math.max(1, self.TabCount))
        for _, btn in pairs(self.Tabs) do
            btn.Size = UDim2.new(0, w, 1, 0)
        end
    end

    function UILibrary:SelectTab(name)
        for tName, btn in pairs(self.Tabs) do
            if tName == name then
                tween(btn, {BackgroundColor3 = Theme.ElementActive, TextColor3 = Theme.TextPrimary})
                self.TabFrames[tName].Visible = true
            else
                tween(btn, {BackgroundColor3 = Theme.ElementIdle, TextColor3 = Theme.TextSecondary})
                self.TabFrames[tName].Visible = false
            end
        end
    end

    function UILibrary:CreateTab(name)
        self.TabCount = self.TabCount + 1
        
        local btn = Instance.new("TextButton")
        btn.Parent = self.TabBar
        btn.Size = UDim2.new(0, 0, 1, 0)
        btn.BackgroundColor3 = Theme.ElementIdle
        btn.Font = Enum.Font.GothamBold
        btn.Text = name
        btn.TextColor3 = Theme.TextSecondary
        btn.TextSize = 12
        btn.LayoutOrder = self.TabCount
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        Utility.RegisterConnection(btn.MouseEnter:Connect(function()
            if self.TabFrames[name] and not self.TabFrames[name].Visible then
                tween(btn, {BackgroundColor3 = Theme.ElementHover})
            end
        end))
        Utility.RegisterConnection(btn.MouseLeave:Connect(function()
            if self.TabFrames[name] and not self.TabFrames[name].Visible then
                tween(btn, {BackgroundColor3 = Theme.ElementIdle})
            end
        end))

        Utility.RegisterConnection(btn.Activated:Connect(function() self:SelectTab(name) end))
        self.Tabs[name] = btn

        local frame = Instance.new("ScrollingFrame")
        frame.Parent = self.TabContainer
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.ScrollBarThickness = 4
        frame.ScrollBarImageColor3 = Theme.ElementActive
        frame.CanvasSize = UDim2.new(0, 0, 0, 0)
        frame.BorderSizePixel = 0
        frame.Visible = false

        local UIList = Instance.new("UIListLayout")
        UIList.Parent = frame
        UIList.SortOrder = Enum.SortOrder.LayoutOrder
        UIList.Padding = UDim.new(0, 6)
        UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local UIPad = Instance.new("UIPadding")
        UIPad.Parent = frame
        UIPad.PaddingTop = UDim.new(0, 4)
        UIPad.PaddingBottom = UDim.new(0, 10)

        Utility.RegisterConnection(UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            frame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 20)
        end))
        
        self.TabFrames[name] = frame
        task.defer(function() self:UpdateTabWidths() end)

        if self.TabCount == 1 then
            self:SelectTab(name)
        end

        local TabObj = { Frame = frame, Library = self }
        function TabObj:AddSection(text) return self.Library:CreateSection(self.Frame, text) end
        function TabObj:AddButton(text, callback) return self.Library:CreateButton(self.Frame, text, callback) end
        function TabObj:AddToggle(text, initialState, callback) return self.Library:CreateToggle(self.Frame, text, initialState, callback) end
        function TabObj:AddSlider(text, default, min, max, callback) return self.Library:CreateSlider(self.Frame, text, default, callback, min, max) end
        function TabObj:AddKeybind(text, defaultKey, callback) return self.Library:CreateKeybind(self.Frame, text, defaultKey, callback) end
        function TabObj:AddLabel(text) return self.Library:CreateLabel(self.Frame, text) end

        return TabObj
    end

    local function NextOrder(parent)
        local c = 0
        for _, v in ipairs(parent:GetChildren()) do if v:IsA("GuiObject") then c = c + 1 end end
        return c
    end

    function UILibrary:CreateSection(parent, text)
        local f = Instance.new("Frame")
        f.Parent = parent
        f.Size = UDim2.new(0.92, 0, 0, 26)
        f.BackgroundTransparency = 1
        f.LayoutOrder = NextOrder(parent)

        local dot = Instance.new("Frame")
        dot.Parent = f
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0, 4, 0.5, -3)
        dot.BackgroundColor3 = Theme.TextAccent
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local l = Instance.new("TextLabel")
        l.Parent = f; l.Size = UDim2.new(1, -16, 1, 0)
        l.Position = UDim2.new(0, 16, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text:upper()
        l.TextColor3 = Theme.TextAccent
        l.Font = Enum.Font.GothamBold; l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
    end

    function UILibrary:CreateLabel(parent, text)
        local card = Instance.new("Frame")
        card.Parent = parent
        card.Size = UDim2.new(0.92, 0, 0, 30)
        card.BackgroundColor3 = Theme.ElementIdle
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Stroke
        stroke.Thickness = 1

        local lbl = Instance.new("TextLabel")
        lbl.Parent = card
        lbl.Size = UDim2.new(1, -20, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = text
        lbl.TextColor3 = Theme.TextPrimary
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local obj = {
            Frame = card,
            Label = lbl,
            SetText = function(self, newText)
                lbl.Text = newText
            end
        }
        return obj
    end

    function UILibrary:CreateButton(parent, text, onClick)
        local card = Instance.new("Frame")
        card.Parent = parent
        card.Size = UDim2.new(0.92, 0, 0, 36)
        card.BackgroundColor3 = Theme.ElementIdle
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Stroke
        stroke.Thickness = 1

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Font = Enum.Font.GothamBold
        btn.Text = text
        btn.TextColor3 = Theme.TextPrimary
        btn.TextSize = 13

        Utility.RegisterConnection(btn.MouseEnter:Connect(function() tween(card, {BackgroundColor3 = Theme.ElementHover}) end))
        Utility.RegisterConnection(btn.MouseLeave:Connect(function() tween(card, {BackgroundColor3 = Theme.ElementIdle}) end))
        Utility.RegisterConnection(btn.Activated:Connect(function() onClick(btn) end))
        
        return btn
    end

    function UILibrary:CreateToggle(parent, text, initialState, callback)
        local card = Instance.new("Frame")
        card.Parent = parent
        card.Size = UDim2.new(0.92, 0, 0, 36)
        card.BackgroundColor3 = Theme.ElementIdle
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Stroke
        stroke.Thickness = 1

        local lbl = Instance.new("TextLabel")
        lbl.Parent = card
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextColor3 = Theme.TextPrimary
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local track = Instance.new("Frame")
        track.Parent = card
        track.Size = UDim2.new(0, 38, 0, 20)
        track.Position = UDim2.new(1, -50, 0.5, -10)
        track.BackgroundColor3 = initialState and Theme.Success or Color3.fromRGB(36, 40, 54)
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Parent = track
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initialState and UDim2.new(0, 20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(240, 242, 248)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""

        local function updateVisuals(state)
            tween(track, {BackgroundColor3 = state and Theme.Success or Color3.fromRGB(36, 40, 54)}, 0.2)
            tween(knob, {Position = state and UDim2.new(0, 20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2, Enum.EasingStyle.Quad)
        end

        Utility.RegisterConnection(btn.MouseEnter:Connect(function() tween(card, {BackgroundColor3 = Theme.ElementHover}) end))
        Utility.RegisterConnection(btn.MouseLeave:Connect(function() tween(card, {BackgroundColor3 = Theme.ElementIdle}) end))

        Utility.RegisterConnection(btn.Activated:Connect(function()
            initialState = not initialState
            updateVisuals(initialState)
            callback(initialState)
        end))

        return {
            SetState = function(state)
                initialState = state
                updateVisuals(initialState)
            end
        }
    end

    function UILibrary:CreateSlider(parent, text, default, cb, min, max)
        min = min or 0
        max = max or (default > 0 and default * 2 or 100)
        if default < min then default = min end
        if default > max then default = max end

        sliderIdCounter = sliderIdCounter + 1
        local sliderId = sliderIdCounter

        local card = Instance.new("Frame")
        card.Parent = parent
        card.Size = UDim2.new(0.92, 0, 0, 50)
        card.BackgroundColor3 = Theme.ElementIdle
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Stroke
        stroke.Thickness = 1

        local lbl = Instance.new("TextLabel")
        lbl.Parent = card; lbl.Size = UDim2.new(0.7,0,0,22)
        lbl.Position = UDim2.new(0, 12, 0, 4)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Theme.TextPrimary; lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left

        local valBadge = Instance.new("Frame")
        valBadge.Parent = card
        valBadge.Size = UDim2.new(0, 48, 0, 18)
        valBadge.Position = UDim2.new(1, -60, 0, 6)
        valBadge.BackgroundColor3 = Color3.fromRGB(32, 38, 54)
        Instance.new("UICorner", valBadge).CornerRadius = UDim.new(0, 4)

        local valLbl = Instance.new("TextLabel")
        valLbl.Parent = valBadge; valLbl.Size = UDim2.new(1,0,1,0)
        valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(default)
        valLbl.TextColor3 = Theme.TextAccent; valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11; valLbl.TextXAlignment = Enum.TextXAlignment.Center

        local sliderBG = Instance.new("TextButton")
        sliderBG.Parent = card; sliderBG.Size = UDim2.new(1, -24, 0, 6)
        sliderBG.Position = UDim2.new(0, 12, 0, 34)
        sliderBG.BackgroundColor3 = Color3.fromRGB(36, 40, 54)
        sliderBG.Text = ""; sliderBG.AutoButtonColor = false
        Instance.new("UICorner", sliderBG).CornerRadius = UDim.new(1, 0)

        local sliderFill = Instance.new("Frame")
        sliderFill.Parent = sliderBG; sliderFill.Size = UDim2.new((default - min) / (max - min),0,1,0)
        sliderFill.BackgroundColor3 = Theme.SliderFill
        Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

        local function updateSlider(input)
            local width = math.max(1, sliderBG.AbsoluteSize.X)
            local posX = math.clamp(input.Position.X - sliderBG.AbsolutePosition.X, 0, width)
            local pct = posX / width
            tween(sliderFill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
            local val = min + ((max - min) * pct)
            val = math.floor(val * 100) / 100
            valLbl.Text = tostring(val)
            cb(val)
        end

        sliderCallbacks[sliderId] = updateSlider

        Utility.RegisterConnection(sliderBG.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                activeSliderId = sliderId
                updateSlider(input)
            end
        end))

        return card
    end

    function UILibrary:CreateKeybind(parent, text, defaultKey, cb)
        local card = Instance.new("Frame")
        card.Parent = parent
        card.Size = UDim2.new(0.92, 0, 0, 36)
        card.BackgroundColor3 = Theme.ElementIdle
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Stroke
        stroke.Thickness = 1

        local lbl = Instance.new("TextLabel")
        lbl.Parent = card; lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Theme.TextPrimary; lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton")
        btn.Parent = card; btn.Size = UDim2.new(0, 80, 0, 24)
        btn.Position = UDim2.new(1, -92, 0.5, -12)
        btn.BackgroundColor3 = Color3.fromRGB(32, 38, 54)
        btn.Font = Enum.Font.GothamBold
        btn.Text = defaultKey and defaultKey.Name or "None"
        btn.TextColor3 = Theme.TextAccent
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        Utility.RegisterConnection(btn.MouseEnter:Connect(function() 
            if activeKeybindBtn ~= btn then tween(btn, {BackgroundColor3 = Theme.ElementHover}) end
        end))
        Utility.RegisterConnection(btn.MouseLeave:Connect(function() 
            if activeKeybindBtn ~= btn then tween(btn, {BackgroundColor3 = Color3.fromRGB(32, 38, 54)}) end
        end))

        Utility.RegisterConnection(btn.Activated:Connect(function()
            if activeKeybindBtn then
                activeKeybindBtn.Text = "None"
                tween(activeKeybindBtn, {BackgroundColor3 = Color3.fromRGB(32, 38, 54)})
            end
            activeKeybindBtn = btn
            activeKeybindCb = cb
            btn.Text = "..."
            tween(btn, {BackgroundColor3 = Theme.ElementActive})
        end))

        return card
    end

    return UILibrary
end

end)()(Core)
        local Theme = UILibrary.Theme or {}

        -- Create the main window
        local Window = UILibrary:CreateWindow("🍽️ Run a Restaurant Utility")
        UI.Window = Window

        if UILibrary.FloatIcon then
            UILibrary.FloatIcon.Text = "🍽️"
        end

        function UI.UpdateFloatStatus()
            if not UILibrary.FloatingCircle or not UILibrary.FloatingCircle.Visible then return end
            local active = Config.MasterAutoFarmEnabled or Config.AutoSeatEnabled or Config.AutoOrderEnabled or
                           Config.AutoCookEnabled or Config.AutoServeEnabled or Config.AutoCleanEnabled or
                           Config.AutoCollectCashEnabled or Config.AutoFarmEnabled or Config.AutoDeliveryEnabled or
                           Config.AutoRestockEnabled or Config.WalkSpeedEnabled or Config.JumpPowerEnabled or
                           Config.NoClipEnabled or Config.InfiniteJumpEnabled

            if active then
                UILibrary.FloatStroke.Color = Theme.TextAccent
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(28, 22, 54)
            else
                UILibrary.FloatStroke.Color = Theme.Stroke
                UILibrary.FloatingCircle.BackgroundColor3 = Theme.ElementIdle
            end
        end

        -- 1. RESTAURANT OPERATIONS TAB
        function UI.BuildRestaurantTab()
            local RestTab = Window:AddTab("Restaurant")

            -- LIVE PERFORMANCE & PROFIT HUD
            RestTab:AddSection("LIVE RESTAURANT HUD")
            local statsLabel1 = RestTab:AddLabel("💵 Cash Swept: $0 | 🎁 Rewards: 0")
            local statsLabel2 = RestTab:AddLabel("👥 Seated: 0 | 📋 Orders: 0 | 🍳 Cooked: 0")
            local statsLabel3 = RestTab:AddLabel("🍽️ Served: 0 | 🧼 Cleaned: 0 | 📦 Delivered: 0")
            local statsLabel4 = RestTab:AddLabel("🌾 Harvested: 0 | 🧊 Restocked: 0 | 🏰 Expansions: 0")
            local statsLabel5 = RestTab:AddLabel("🛒 Purchased: 0 | 🔨 Placed: 0 | 👨‍🍳 Staff: 0")

            -- Sync live stats every second
            task.spawn(function()
                while State.Running do
                    pcall(function()
                        local s = State.Stats
                        local totalRewards = (s.RewardsClaimed or 0) + (s.QuestsClaimed or 0)
                        statsLabel1:SetText(string.format("💵 Cash Swept: %d items | 🎁 Rewards: %d", s.CashCollected, totalRewards))
                        statsLabel2:SetText(string.format("👥 Seated: %d | 📋 Orders: %d | 🍳 Cooked: %d", s.CustomersSeated, s.OrdersTaken, s.DishesCooked))
                        statsLabel3:SetText(string.format("🍽️ Served: %d | 🧼 Cleaned: %d | 📦 Delivered: %d", s.DishesServed, s.TablesCleaned, s.DeliveriesCompleted))
                        statsLabel4:SetText(string.format("🌾 Harvested: %d | 🧊 Restocked: %d | 🏰 Expansions: %d", s.CropsHarvested, s.StorageRestocked, s.ExpansionsPurchased))
                        statsLabel5:SetText(string.format("🛒 Purchased: %d | 🔨 Placed: %d | 👨‍🍳 Staff: %d", s.ItemsPurchased, s.ItemsPlaced, s.StaffHired))
                    end)
                    task.wait(0.8)
                end
            end)

            -- MASTER AUTOMATION SWITCH
            RestTab:AddSection("MASTER AUTOMATION")
            RestTab:AddToggle("⚡ MASTER RESTAURANT AUTO-FARM", Config.MasterAutoFarmEnabled, function(val)
                Config.MasterAutoFarmEnabled = val
                UI.UpdateFloatStatus()
            end)

            -- KITCHEN & DINING OPERATIONS
            RestTab:AddSection("KITCHEN & DINING")
            RestTab:AddToggle("Auto-Seat Customers", Config.AutoSeatEnabled, function(val)
                Config.AutoSeatEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Take Orders", Config.AutoOrderEnabled, function(val)
                Config.AutoOrderEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Cook Food", Config.AutoCookEnabled, function(val)
                Config.AutoCookEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Serve Dishes", Config.AutoServeEnabled, function(val)
                Config.AutoServeEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Clean Tables", Config.AutoCleanEnabled, function(val)
                Config.AutoCleanEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Collect Cash & Tips", Config.AutoCollectCashEnabled, function(val)
                Config.AutoCollectCashEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("VIP & Celebrity Customer Priority", Config.VIPPriorityEnabled, function(val)
                Config.VIPPriorityEnabled = val
            end)

            -- SUPPLY & EXTRA REVENUE
            RestTab:AddSection("SUPPLY & EXTRA REVENUE")
            RestTab:AddToggle("Auto-Fulfill Delivery Orders", Config.AutoDeliveryEnabled, function(val)
                Config.AutoDeliveryEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Restock Kitchen Storage", Config.AutoRestockEnabled, function(val)
                Config.AutoRestockEnabled = val
                UI.UpdateFloatStatus()
            end)
            RestTab:AddToggle("Auto-Harvest Farm & Ranch", Config.AutoFarmEnabled, function(val)
                Config.AutoFarmEnabled = val
                UI.UpdateFloatStatus()
            end)

            -- QUICK WORKSTATION ACTIONS
            RestTab:AddSection("QUICK WORKSTATION ACTIONS")
            RestTab:AddButton("Trigger All Workstations Now", function(btn)
                if Core.Restaurant then
                    pcall(Core.Restaurant.HandleRestock)
                    pcall(Core.Restaurant.HandleFarming)
                    pcall(Core.Restaurant.HandleDelivery)
                    pcall(Core.Restaurant.HandleCashCollection)
                    pcall(Core.Restaurant.HandleCleaning)
                    pcall(Core.Restaurant.HandleSeating)
                    pcall(Core.Restaurant.HandleOrdering)
                    pcall(Core.Restaurant.HandleCooking)
                    pcall(Core.Restaurant.HandleServing)
                    local old = btn.Text
                    btn.Text = "Dispatched!"
                    task.delay(1.2, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("📍 Set Restaurant Anchor Here", function(btn)
                if Core.Restaurant and Core.Restaurant.RecalibrateAnchor then
                    local ok = Core.Restaurant.RecalibrateAnchor()
                    local old = btn.Text
                    btn.Text = ok and "📍 Anchor Calibrated!" or "Error Calibrating"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            RestTab:AddButton("Teleport to Restaurant Center", function()
                if Core.Restaurant and Core.Restaurant.RestaurantCenter then
                    local char = Core.Services.Players.LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(Core.Restaurant.RestaurantCenter + Vector3.new(0, 3, 0))
                    end
                end
            end)
        end

        -- 2. BUILD & STAFF MANAGEMENT TAB
        function UI.BuildBuildTab()
            local BuildTab = Window:AddTab("Build/Staff")

            -- AUTO-BUY EQUIPMENT & FURNITURE
            BuildTab:AddSection("AUTO-BUY EQUIPMENT & FURNITURE")
            BuildTab:AddToggle("Auto-Buy Upgrades (Master)", Config.AutoBuyEnabled, function(val)
                Config.AutoBuyEnabled = val
            end)
            BuildTab:AddToggle("Buy Cooking Stoves & Ovens", Config.AutoBuyStoves, function(val)
                Config.AutoBuyStoves = val
            end)
            BuildTab:AddToggle("Buy Dining Tables", Config.AutoBuyTables, function(val)
                Config.AutoBuyTables = val
            end)
            BuildTab:AddToggle("Buy Dining Chairs & Seating", Config.AutoBuyChairs, function(val)
                Config.AutoBuyChairs = val
            end)
            BuildTab:AddToggle("Buy Kitchen Appliances & Sinks", Config.AutoBuyAppliances, function(val)
                Config.AutoBuyAppliances = val
            end)
            BuildTab:AddToggle("Buy General Furniture & Decor", Config.AutoBuyFurniture, function(val)
                Config.AutoBuyFurniture = val
            end)

            -- AUTO-PLACE FURNITURE & SEATING
            BuildTab:AddSection("AUTO-PLACE FURNITURE & SEATING")
            BuildTab:AddToggle("Auto-Place Stored Items (Master)", Config.AutoPlaceEnabled, function(val)
                Config.AutoPlaceEnabled = val
            end)
            BuildTab:AddToggle("Place Dining Tables", Config.AutoPlaceTables, function(val)
                Config.AutoPlaceTables = val
            end)
            BuildTab:AddToggle("Place Dining Chairs", Config.AutoPlaceChairs, function(val)
                Config.AutoPlaceChairs = val
            end)
            BuildTab:AddToggle("Place General Furniture", Config.AutoPlaceFurniture, function(val)
                Config.AutoPlaceFurniture = val
            end)

            -- STAFF & PROPERTY EXPANSIONS
            BuildTab:AddSection("STAFF & PROPERTY EXPANSIONS")
            BuildTab:AddToggle("Auto-Hire & Upgrade Staff", Config.AutoHireStaffEnabled, function(val)
                Config.AutoHireStaffEnabled = val
            end)
            BuildTab:AddToggle("Auto-Expand Floors & Land", Config.AutoExpandEnabled, function(val)
                Config.AutoExpandEnabled = val
            end)
            BuildTab:AddToggle("Auto-Claim All Rewards & Gifts", Config.AutoClaimRewardsEnabled, function(val)
                Config.AutoClaimRewardsEnabled = val
                Config.AutoClaimQuestsEnabled = val
            end)

            -- INSTANT ONE-CLICK ACTIONS
            BuildTab:AddSection("INSTANT ACTIONS")
            BuildTab:AddButton("🛒 Auto-Buy Next Equipment Now", function(btn)
                if Core.Restaurant and Core.Restaurant.HandleAutoBuy then
                    Config.AutoBuyEnabled = true
                    pcall(Core.Restaurant.HandleAutoBuy)
                    local old = btn.Text
                    btn.Text = "Checked Shop!"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            BuildTab:AddButton("🔨 Auto-Place Stored Items Now", function(btn)
                if Core.Restaurant and Core.Restaurant.HandleAutoPlace then
                    Config.AutoPlaceEnabled = true
                    pcall(Core.Restaurant.HandleAutoPlace)
                    local old = btn.Text
                    btn.Text = "Placed on Grid!"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
            BuildTab:AddButton("👨‍🍳 Auto-Hire Available Staff Now", function(btn)
                if Core.Restaurant and Core.Restaurant.HandleStaffManage then
                    Config.AutoHireStaffEnabled = true
                    pcall(Core.Restaurant.HandleStaffManage)
                    local old = btn.Text
                    btn.Text = "Hired Staff!"
                    task.delay(1.5, function() btn.Text = old end)
                end
            end)
        end

        -- 3. AUTOMATION & NAVIGATION ENGINE TAB
        function UI.BuildAutomationTab()
            local AutoTab = Window:AddTab("Automation")

            -- TASK COMPLETION & SEQUENCING
            AutoTab:AddSection("TASK COMPLETION & SEQUENCING")
            AutoTab:AddToggle("Strict Task Completion Guard", Config.StrictTaskCompletion, function(val)
                Config.StrictTaskCompletion = val
            end)
            AutoTab:AddSlider("Station Stay Delay (s)", math.floor((Config.StationStayDelay or 0.22) * 100), 8, 100, function(val)
                Config.StationStayDelay = val / 100
            end)
            AutoTab:AddSlider("Post-Action Settling Delay (s)", math.floor((Config.PostActionDelay or 0.18) * 100), 5, 80, function(val)
                Config.PostActionDelay = val / 100
            end)
            AutoTab:AddSlider("Cycle Speed (s)", math.floor(Config.ActionDelay * 10), 1, 30, function(val)
                Config.ActionDelay = val / 10
            end)

            -- PIPELINE & CONCURRENCY
            AutoTab:AddSection("PIPELINE & CONCURRENCY")
            AutoTab:AddToggle("Simultaneous Multi-Queue Pipeline", Config.InterleavedPipelineEnabled, function(val)
                Config.InterleavedPipelineEnabled = val
            end)
            AutoTab:AddToggle("Concurrent Workstation Batching", Config.ConcurrentExecutionEnabled, function(val)
                Config.ConcurrentExecutionEnabled = val
            end)
            AutoTab:AddSlider("Station Batch Size", Config.StationBatchSize or 3, 1, 5, function(val)
                Config.StationBatchSize = val
            end)
            AutoTab:AddToggle("Opportunistic Nearby Batching", Config.RemotePromptBatching, function(val)
                Config.RemotePromptBatching = val
            end)

            -- TELEPORTATION & NAVIGATION
            AutoTab:AddSection("TELEPORTATION & NAVIGATION")
            AutoTab:AddToggle("Auto-Teleport to Stations", Config.AutoTeleportEnabled, function(val)
                Config.AutoTeleportEnabled = val
            end)
            AutoTab:AddSlider("Restaurant Radius (studs)", Config.MaxScanRadius or 120, 40, 300, function(val)
                Config.MaxScanRadius = val
            end)
            AutoTab:AddToggle("Scope to Own Plot Only", Config.PlotScopingEnabled, function(val)
                Config.PlotScopingEnabled = val
            end)
            AutoTab:AddToggle("Prevent Sitting in Chairs", Config.PreventSitting, function(val)
                Config.PreventSitting = val
            end)
            AutoTab:AddToggle("Multi-Floor Safe Raycast", Config.MultiFloorSafeRaycast, function(val)
                Config.MultiFloorSafeRaycast = val
            end)

            -- AFK & PERFORMANCE
            AutoTab:AddSection("AFK & PERFORMANCE")
            AutoTab:AddToggle("Instant Proximity Prompts", Config.InstantPromptEnabled, function(val)
                Config.InstantPromptEnabled = val
            end)
            AutoTab:AddToggle("Anti-AFK Disconnect Guard", Config.AntiAFKEnabled, function(val)
                Config.AntiAFKEnabled = val
            end)
            AutoTab:AddToggle("24/7 Auto-Rejoin on Disconnect", Config.AutoRejoinEnabled, function(val)
                Config.AutoRejoinEnabled = val
            end)
            AutoTab:AddToggle("GPU Saver / Performance Mode", Config.GPUSaverEnabled, function(val)
                Config.GPUSaverEnabled = val
                Utility.SetGPUSaver(val)
            end)
        end

        -- 4. SETTINGS & UTILITIES TAB
        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings")

            -- KEYBINDS
            SettingsTab:AddSection("KEYBINDS")
            SettingsTab:AddKeybind("Toggle Menu", Config.MenuKey, function(key) Config.MenuKey = key end)
            SettingsTab:AddKeybind("Toggle No-Clip", Config.ToggleNoClipKey, function(key) Config.ToggleNoClipKey = key end)
            SettingsTab:AddKeybind("Toggle Speed Hack", Config.ToggleSpeedKey, function(key) Config.ToggleSpeedKey = key end)
            SettingsTab:AddKeybind("Toggle Jump Hack", Config.ToggleJumpKey, function(key) Config.ToggleJumpKey = key end)
            SettingsTab:AddKeybind("Toggle Infinite Jump", Config.ToggleInfJumpKey, function(key) Config.ToggleInfJumpKey = key end)

            -- CONFIG MANAGEMENT
            SettingsTab:AddSection("CONFIG MANAGEMENT")
            SettingsTab:AddButton("Save Config", function(btn)
                if Core.Config.Save then
                    local success = Core.Config:Save()
                    local oldText = btn.Text
                    btn.Text = success and "Saved!" or "Error Saving"
                    task.delay(1.5, function() btn.Text = oldText end)
                end
            end)
            SettingsTab:AddButton("Load Config", function(btn)
                if Core.Config.Load then
                    local success = Core.Config:Load()
                    local oldText = btn.Text
                    btn.Text = success and "Loaded!" or "Error Loading"
                    task.delay(1.5, function() btn.Text = oldText end)
                end
            end)

            -- REWARDS & PROMO CODES
            SettingsTab:AddSection("REWARDS & PROMO CODES")
            SettingsTab:AddButton("🎁 Claim All Rewards & Gifts Now", function(btn)
                local claimed = Utility.ClaimAllRewards()
                local old = btn.Text
                btn.Text = (claimed and claimed > 0) and ("Claimed " .. claimed .. " Rewards!") or "All Claimed!"
                task.delay(1.5, function() btn.Text = old end)
            end)
            SettingsTab:AddButton("🎟️ Redeem Active Promo Codes", function(btn)
                local count = Utility.RedeemKnownCodes()
                local old = btn.Text
                btn.Text = (count and count > 0) and ("Submitted " .. count .. " Codes!") or "Codes Submitted!"
                task.delay(1.5, function() btn.Text = old end)
            end)

            -- UNLOAD SCRIPT
            SettingsTab:AddSection("UNLOAD SCRIPT")
            SettingsTab:AddButton("🔴 Unload & Close Script Completely", function()
                Utility.Terminate()
            end)
        end
    end

    return UI
end

end)()(Core)
Core.UI.Init()
Core.UI.BuildRestaurantTab()
Core.UI.BuildBuildTab()
Core.UI.BuildAutomationTab()

-- 4. Load Automation & Movement Modules
Core.Restaurant = (function()
return function(Core)
    local Restaurant = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer
    local State = Core.State

    -- Plot & Anchor references
    local cachedPlot = nil
    local lastPlotSearch = 0
    local lastMemoryClean = os.clock()
    local lastQuestCheck = 0
    Restaurant.RestaurantCenter = nil

    -- Per-prompt cooldown tracker
    local promptCooldowns = setmetatable({}, {__mode = "k"})

    local function isPromptReady(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        local exp = promptCooldowns[prompt]
        if exp and os.clock() < exp then return false end
        return true
    end

    local function setPromptCooldown(prompt, duration)
        if prompt then
            promptCooldowns[prompt] = os.clock() + (duration or 2.5)
        end
    end

    -- Periodic memory cleanup
    local function cleanExpiredCooldowns()
        local now = os.clock()
        if now - lastMemoryClean > 300 then
            lastMemoryClean = now
            for p, exp in pairs(promptCooldowns) do
                if now >= exp or not p or not p.Parent then
                    promptCooldowns[p] = nil
                end
            end
        end
    end

    -- Safe character resolver
    local function getAliveCharacter()
        local char = LocalPlayer and LocalPlayer.Character
        if not char then return nil, nil, nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return nil, nil, nil end
        return char, root, hum
    end

    -- Safely unseat character without breaking physics
    local function releaseSeat(hum, char)
        if not hum then return end
        if hum.Sit then
            hum.Sit = false
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, child in ipairs(root:GetChildren()) do
                        if child:IsA("Weld") and child.Name == "SeatWeld" then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end
            end
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(0.05)
        end
    end

    -- Extract target world position safely
    local function getTargetPosition(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then
            return inst.Position
        elseif inst:IsA("Model") then
            if inst.PrimaryPart then return inst.PrimaryPart.Position end
            return inst:GetPivot().Position
        elseif inst:IsA("ProximityPrompt") then
            local p = inst.Parent
            if p and p:IsA("BasePart") then
                return p.Position
            elseif p and p:IsA("Model") then
                return p:GetPivot().Position
            elseif p and p.Parent and p.Parent:IsA("BasePart") then
                return p.Parent.Position
            end
        end
        return nil
    end

    -- Recalibrate the center of the restaurant to current avatar position
    function Restaurant.RecalibrateAnchor()
        local _, root = getAliveCharacter()
        if root then
            Restaurant.RestaurantCenter = root.Position
            cachedPlot = nil
            return true
        end
        return false
    end

    -- Locate player's designated restaurant / farm plot
    function Restaurant.GetPlayerPlot()
        if not Config.PlotScopingEnabled then return workspace end
        local now = os.clock()
        if cachedPlot and cachedPlot.Parent and (now - lastPlotSearch < 15) then
            return cachedPlot
        end
        lastPlotSearch = now

        local playerName = LocalPlayer.Name:lower()
        local displayName = LocalPlayer.DisplayName:lower()
        local userId = tostring(LocalPlayer.UserId)

        -- 1. Direct LocalPlayer plot references
        local plotVal = LocalPlayer:FindFirstChild("Plot") or LocalPlayer:FindFirstChild("Restaurant") or LocalPlayer:FindFirstChild("Tycoon")
        if plotVal and plotVal:IsA("ObjectValue") and plotVal.Value then
            cachedPlot = plotVal.Value
            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
            return cachedPlot
        end
        local plotAttr = LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("Restaurant")
        if typeof(plotAttr) == "Instance" then
            cachedPlot = plotAttr
            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
            return cachedPlot
        end

        -- 2. Search common plot containers in workspace
        local map = workspace:FindFirstChild("Map")
        local searchContainers = {
            workspace:FindFirstChild("Plots"),
            workspace:FindFirstChild("Restaurants"),
            workspace:FindFirstChild("PlayerRestaurants"),
            workspace:FindFirstChild("PlayerPlots"),
            workspace:FindFirstChild("Tycoons"),
            workspace:FindFirstChild("Farms"),
            map and map:FindFirstChild("Plots"),
            map and map:FindFirstChild("Restaurants"),
        }

        for _, container in ipairs(searchContainers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Model") or item:IsA("Folder") then
                        -- Check Owner value or attribute
                        local ownerObj = item:FindFirstChild("Owner") or item:FindFirstChild("Player") or item:FindFirstChild("OwnerId")
                        if ownerObj then
                            local val = tostring(ownerObj.Value):lower()
                            if val == playerName or val == userId or val == displayName then
                                cachedPlot = item
                                Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                                return item
                            end
                        end
                        if item:GetAttribute("Owner") == LocalPlayer.UserId or tostring(item:GetAttribute("Owner")):lower() == playerName then
                            cachedPlot = item
                            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                            return item
                        end

                        -- Check item name
                        local itemName = item.Name:lower()
                        if itemName:find(playerName, 1, true) or itemName:find(userId, 1, true) then
                            cachedPlot = item
                            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                            return item
                        end

                        -- Check billboard text
                        for _, desc in ipairs(item:GetDescendants()) do
                            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                local txt = (desc.Text or ""):lower()
                                if (txt:find(playerName, 1, true) or txt:find(displayName, 1, true)) and 
                                   (txt:find("restaurant", 1, true) or txt:find("plot", 1, true) or txt:find("farm", 1, true)) then
                                    cachedPlot = item
                                    Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                                    return item
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 3. Fallback: Find closest plot model to player or anchor to player position
        local _, root = getAliveCharacter()
        if root then
            if not Restaurant.RestaurantCenter then
                Restaurant.RestaurantCenter = root.Position
            end
        end

        return cachedPlot or workspace
    end

    -- Teleport player safely to a target workstation (Zero-NaN safe)
    function Restaurant.TeleportTo(targetInstance)
        local char, root, hum = getAliveCharacter()
        if not char or not root or not hum then return false end

        local targetPos = getTargetPosition(targetInstance)
        if not targetPos then return false end

        -- Prevent accidental sitting in customer chairs
        if Config.PreventSitting and hum.Sit then
            releaseSeat(hum, char)
        end

        -- Stand offset from workstation part (2.5 studs back)
        local standOffset = Vector3.new(0, 0, 2.5)
        if targetInstance:IsA("BasePart") then
            standOffset = targetInstance.CFrame.LookVector * 2.5
        elseif targetInstance:IsA("ProximityPrompt") and targetInstance.Parent and targetInstance.Parent:IsA("BasePart") then
            standOffset = targetInstance.Parent.CFrame.LookVector * 2.5
        end
        if standOffset.Magnitude < 0.5 then
            standOffset = Vector3.new(0, 0, 2.5)
        end

        local standPos = targetPos + Vector3.new(standOffset.X, 0, standOffset.Z)
        local safePos = Utility.GetGroundPosition(standPos, {char})

        -- Orient avatar toward the target position safely (Prevents NaN flings)
        local lookPos = Vector3.new(targetPos.X, safePos.Y, targetPos.Z)
        local targetCFrame
        if (lookPos - safePos).Magnitude > 0.5 then
            targetCFrame = CFrame.lookAt(safePos, lookPos)
        else
            targetCFrame = CFrame.new(safePos)
        end

        root.CFrame = targetCFrame

        -- Zero out velocity to prevent flinging
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        return true
    end

    -- Trigger a ProximityPrompt safely
    local function triggerPrompt(prompt, debounceTime)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end

        setPromptCooldown(prompt, debounceTime or 2.5)

        if Config.InstantPromptEnabled then
            pcall(function()
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 24)
            end)
        end

        -- 1. Try executor native fireproximityprompt
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function()
                fireproximityprompt(prompt)
            end)
            if ok then return true end
            pcall(function()
                fireproximityprompt(prompt, 1)
            end)
            return true
        end

        -- 2. Fallback input simulation
        local holdTime = prompt.HoldDuration or 0
        if Config.InstantPromptEnabled then
            holdTime = 0
            pcall(function() prompt.HoldDuration = 0 end)
        end

        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                if holdTime > 0 then
                    task.wait(holdTime + 0.05)
                else
                    task.wait(0.05)
                end
                if prompt.InputHoldEnd then
                    prompt:InputHoldEnd()
                end
            end
        end)
        return true
    end

    -- Single-pass prompt aggregator (High-speed, zero-lag, no full workspace spam)
    function Restaurant.ScanPrompts()
        local container = Restaurant.GetPlayerPlot()
        local _, root = getAliveCharacter()
        local center = Restaurant.RestaurantCenter or (root and root.Position)
        local maxDist = Config.MaxScanRadius or 120

        local categorized = {
            Cash = {},
            Order = {},
            Cook = {},
            Serve = {},
            Clean = {},
            Seat = {},
            Delivery = {},
            Restock = {},
            Farm = {},
            Expand = {},
            Buy = {},
            Place = {},
        }

        local searchList = {}
        if container and container ~= workspace then
            searchList = container:GetDescendants()
        else
            -- Proximity scoped: Only search models within maxDist to prevent scanning 50,000 objects
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model") or obj:IsA("Folder") then
                    local pos = getTargetPosition(obj)
                    if not center or not pos or (pos - center).Magnitude <= (maxDist + 35) then
                        for _, d in ipairs(obj:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then
                                table.insert(searchList, d)
                            end
                        end
                    end
                elseif obj:IsA("ProximityPrompt") then
                    table.insert(searchList, obj)
                end
            end
        end

        for _, obj in ipairs(searchList) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and isPromptReady(obj) then
                local pos = getTargetPosition(obj)
                if not center or not pos or (pos - center).Magnitude <= maxDist then
                    local act = (obj.ActionText or ""):lower()
                    local objTxt = (obj.ObjectText or obj.Name or (obj.Parent and obj.Parent.Name or "")):lower()
                    local combined = act .. " " .. objTxt

                    -- 1. Cash, Tips & Free Reward Chests
                    if combined:find("tip") or combined:find("cash") or combined:find("register") or combined:find("collect") or combined:find("money") or combined:find("gift") or combined:find("reward") or combined:find("chest") then
                        table.insert(categorized.Cash, obj)

                    -- 2. Customer Orders
                    elseif (combined:find("order") or combined:find("menu") or combined:find("ticket") or combined:find("take order")) and not combined:find("delivery") then
                        table.insert(categorized.Order, obj)

                    -- 3. Cook Food
                    elseif combined:find("cook") or combined:find("prepare") or combined:find("bake") or combined:find("grill") or combined:find("stove") or combined:find("oven") then
                        table.insert(categorized.Cook, obj)

                    -- 4. Serve Prepared Dishes
                    elseif combined:find("serve") or combined:find("bring") or combined:find("plate") or (combined:find("dish") and not combined:find("sink")) then
                        table.insert(categorized.Serve, obj)

                    -- 5. Clean Dirty Tables
                    elseif combined:find("clean") or combined:find("wash") or combined:find("wipe") or combined:find("dirty") or combined:find("bus") or combined:find("trash") or combined:find("sink") then
                        table.insert(categorized.Clean, obj)

                    -- 6. Add / Place Furniture, Chairs & Tables (BEFORE Customer Seating)
                    elseif combined:find("place") or combined:find("build") or combined:find("assemble") or combined:find("put down") or
                           combined:find("add table") or combined:find("add chair") or combined:find("add seat") or combined:find("add furniture") or
                           combined:find("new table") or combined:find("new chair") or combined:find("new seat") or
                           (combined:find("add") and (combined:find("table") or combined:find("chair") or combined:find("furniture") or combined:find("seat"))) then
                        table.insert(categorized.Place, obj)

                    -- 7. Customer Seating (Host / Welcome)
                    elseif combined:find("seat") or combined:find("host") or combined:find("welcome") or combined:find("customer") or combined:find("guest") or combined:find("party") then
                        table.insert(categorized.Seat, obj)

                    -- 8. Delivery Orders
                    elseif combined:find("package") or combined:find("box") or combined:find("scooter") or combined:find("takeout") or combined:find("delivery") then
                        table.insert(categorized.Delivery, obj)

                    -- 9. Restock Storage
                    elseif combined:find("restock") or combined:find("deposit") or combined:find("fridge") or combined:find("cooler") or combined:find("pantry") then
                        table.insert(categorized.Restock, obj)

                    -- 10. Farm Harvest
                    elseif combined:find("harvest") or combined:find("crop") or combined:find("wheat") or combined:find("plant") or combined:find("gather") or combined:find("pick") then
                        table.insert(categorized.Farm, obj)

                    -- 11. Buy Furniture & Equipment
                    elseif (combined:find("buy") or combined:find("purchase")) and not combined:find("floor") and not combined:find("expand") then
                        table.insert(categorized.Buy, obj)

                    -- 12. Expand Land & Floors
                    elseif combined:find("expand") or combined:find("unlock") or (combined:find("floor") and (combined:find("buy") or combined:find("unlock") or combined:find("purchase"))) then
                        table.insert(categorized.Expand, obj)
                    end
                end
            end
        end

        -- VIP Customer Priority: Sort VIP patrons to front of queue
        if Config.VIPPriorityEnabled then
            local function sortVip(list)
                if #list > 1 then
                    table.sort(list, function(a, b)
                        local aTxt = ((a.ObjectText or "") .. " " .. (a.Parent and a.Parent.Name or "")):lower()
                        local bTxt = ((b.ObjectText or "") .. " " .. (b.Parent and b.Parent.Name or "")):lower()
                        local aVip = aTxt:find("vip") or aTxt:find("gold") or aTxt:find("celebrity") or aTxt:find("star") or aTxt:find("rich")
                        local bVip = bTxt:find("vip") or bTxt:find("gold") or bTxt:find("celebrity") or bTxt:find("star") or bTxt:find("rich")
                        if aVip and not bVip then return true end
                        return false
                    end)
                end
            end
            sortVip(categorized.Seat)
            sortVip(categorized.Order)
        end

        return categorized
    end

    -- Spatial clustering: Find ready prompts in the same category within radius studs
    function Restaurant.GetNearbyCluster(primaryPrompt, promptsList, radius, maxCount)
        local cluster = {}
        if not primaryPrompt or not promptsList then return cluster end
        local primaryPos = getTargetPosition(primaryPrompt)
        if not primaryPos then return cluster end

        radius = radius or 14
        maxCount = maxCount or (Config.StationBatchSize or 3)

        for _, prompt in ipairs(promptsList) do
            if prompt ~= primaryPrompt and isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                local pos = getTargetPosition(prompt)
                if pos and (pos - primaryPos).Magnitude <= radius then
                    table.insert(cluster, prompt)
                    if #cluster >= (maxCount - 1) then
                        break
                    end
                end
            end
        end
        return cluster
    end

    -- Trigger nearby prompts across ANY enabled category opportunistically (same room/station)
    function Restaurant.TriggerOpportunisticNearby(centerPos, allPrompts, radius)
        if not Config.RemotePromptBatching or not centerPos or not allPrompts then return 0 end
        radius = radius or 14
        local triggeredCount = 0
        local isMaster = Config.MasterAutoFarmEnabled

        local categoryConfigs = {
            Cash = { enabled = isMaster or Config.AutoCollectCashEnabled, stat = "CashCollected", cooldown = 3.0 },
            Order = { enabled = isMaster or Config.AutoOrderEnabled, stat = "OrdersTaken", cooldown = 2.5 },
            Cook = { enabled = isMaster or Config.AutoCookEnabled, stat = "DishesCooked", cooldown = 2.5 },
            Serve = { enabled = isMaster or Config.AutoServeEnabled, stat = "DishesServed", cooldown = 2.5 },
            Clean = { enabled = isMaster or Config.AutoCleanEnabled, stat = "TablesCleaned", cooldown = 3.0 },
            Seat = { enabled = isMaster or Config.AutoSeatEnabled, stat = "CustomersSeated", cooldown = 3.0 },
            Delivery = { enabled = isMaster or Config.AutoDeliveryEnabled, stat = "DeliveriesCompleted", cooldown = 4.0 },
            Restock = { enabled = isMaster or Config.AutoRestockEnabled, stat = "StorageRestocked", cooldown = 3.5 },
            Farm = { enabled = isMaster or Config.AutoFarmEnabled, stat = "CropsHarvested", cooldown = 3.0 },
        }

        for catName, catInfo in pairs(categoryConfigs) do
            if catInfo.enabled and allPrompts[catName] then
                for _, prompt in ipairs(allPrompts[catName]) do
                    if isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                        local pos = getTargetPosition(prompt)
                        if pos and (pos - centerPos).Magnitude <= radius then
                            State.InFlightTasks[prompt] = true
                            task.spawn(function()
                                pcall(function()
                                    triggerPrompt(prompt, catInfo.cooldown)
                                    if State.Stats[catInfo.stat] ~= nil then
                                        State.Stats[catInfo.stat] = State.Stats[catInfo.stat] + 1
                                    end
                                end)
                                State.InFlightTasks[prompt] = nil
                            end)
                            triggeredCount = triggeredCount + 1
                            if triggeredCount >= 3 then break end
                        end
                    end
                end
            end
        end
        return triggeredCount
    end

    -- Wait until the active prompt/task is confirmed done before allowing subsequent tasks
    local function waitForTaskCompletion(prompt, maxTimeout)
        if not prompt then return true end
        local timeout = maxTimeout or 1.6
        local hold = prompt.HoldDuration or 0
        if hold > 0 and not Config.InstantPromptEnabled then
            timeout = math.max(timeout, hold + 0.4)
        end

        local start = os.clock()
        while (os.clock() - start) < timeout do
            -- 1. Prompt or parent was destroyed (e.g., dirty dishes cleaned, meal picked up, customer seated)
            if not prompt or not prompt.Parent then
                break
            end
            -- 2. Prompt disabled by game logic (e.g., stove began cooking, customer order accepted)
            if not prompt.Enabled then
                break
            end
            task.wait(0.04)
        end

        -- 3. Post-action settling delay to guarantee server replication before moving avatar
        local settle = math.clamp(Config.PostActionDelay or 0.18, 0.05, 1.0)
        task.wait(settle)
        return true
    end

    -- Execute a single action cleanly with strict task completion and mutex safety
    local function executeAction(prompt, cooldown, statKey)
        if not prompt or not prompt.Parent then return false end
        if State.InFlightTasks[prompt] then return false end

        State.InFlightTasks[prompt] = true

        local success = false
        pcall(function()
            -- 1. Teleport safely if enabled
            if Config.AutoTeleportEnabled then
                local ok = Restaurant.TeleportTo(prompt)
                if ok then
                    task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
                end
            end

            -- 2. Trigger prompt
            triggerPrompt(prompt, cooldown or 2.5)

            -- 3. STRICT TASK COMPLETION: Wait until task finishes before proceeding
            if Config.StrictTaskCompletion then
                waitForTaskCompletion(prompt, 1.6)
            else
                task.wait(0.08)
            end

            -- 4. Increment statistics
            if statKey and State.Stats[statKey] ~= nil then
                State.Stats[statKey] = State.Stats[statKey] + 1
            end

            success = true
        end)

        State.InFlightTasks[prompt] = nil
        return success
    end

    -- Execute a workstation cluster cleanly with sequential completion at the station
    local function executeCluster(primaryPrompt, cluster, cooldown, statKey, allPrompts)
        if not primaryPrompt or not primaryPrompt.Parent then return false end
        if State.InFlightTasks[primaryPrompt] then return false end

        State.InFlightTasks[primaryPrompt] = true
        for _, p in ipairs(cluster) do
            State.InFlightTasks[p] = true
        end

        local success = false
        pcall(function()
            -- 1. Teleport safely to primary prompt once
            if Config.AutoTeleportEnabled then
                local ok = Restaurant.TeleportTo(primaryPrompt)
                if ok then
                    task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
                end
            end

            -- 2. Trigger primary prompt and ensure it is completed
            triggerPrompt(primaryPrompt, cooldown or 2.5)
            if Config.StrictTaskCompletion then
                waitForTaskCompletion(primaryPrompt, 1.6)
            else
                task.wait(0.08)
            end
            if statKey and State.Stats[statKey] ~= nil then
                State.Stats[statKey] = State.Stats[statKey] + 1
            end
            State.InFlightTasks[primaryPrompt] = nil

            -- 3. Complete each cluster prompt sequentially while standing at the station
            for _, prompt in ipairs(cluster) do
                if prompt and prompt.Parent and prompt.Enabled and isPromptReady(prompt) then
                    triggerPrompt(prompt, cooldown or 2.5)
                    if Config.StrictTaskCompletion then
                        waitForTaskCompletion(prompt, 1.6)
                    else
                        task.wait(0.08)
                    end
                    if statKey and State.Stats[statKey] ~= nil then
                        State.Stats[statKey] = State.Stats[statKey] + 1
                    end
                end
                State.InFlightTasks[prompt] = nil
            end

            -- 4. Opportunistic cross-category batching for ready prompts within 14 studs
            local primaryPos = getTargetPosition(primaryPrompt)
            if primaryPos and allPrompts and Config.RemotePromptBatching then
                Restaurant.TriggerOpportunisticNearby(primaryPos, allPrompts, 14)
            end

            success = true
        end)

        State.InFlightTasks[primaryPrompt] = nil
        for _, p in ipairs(cluster) do
            State.InFlightTasks[p] = nil
        end
        return success
    end

    -- Sweep dropped physical coins/cash parts remotely without teleport flinging
    function Restaurant.SweepFloorCash()
        local char, root = getAliveCharacter()
        if not root then return end

        local hasFireTouch = (type(firetouchinterest) == "function")
        local center = Restaurant.RestaurantCenter or root.Position
        local maxDist = Config.MaxScanRadius or 120

        local container = Restaurant.GetPlayerPlot()
        local searchParts = (container and container ~= workspace) and container:GetDescendants() or workspace:GetChildren()

        local count = 0
        for _, item in ipairs(searchParts) do
            if item:IsA("BasePart") and not item.Anchored and item.Parent ~= char then
                local name = item.Name:lower()
                if (name:find("coin") or name:find("cash") or name:find("money") or name:find("tip")) then
                    if (item.Position - center).Magnitude <= maxDist then
                        if hasFireTouch then
                            pcall(function()
                                firetouchinterest(root, item, 0)
                                task.wait()
                                firetouchinterest(root, item, 1)
                            end)
                            count = count + 1
                            if count >= 12 then break end
                        end
                    end
                end
            end
        end
        if count > 0 then
            State.Stats.CashCollected = State.Stats.CashCollected + count
        end
    end

    -- Individual handlers for manual button triggering
    function Restaurant.HandleCashCollection()
        local p = Restaurant.ScanPrompts()
        if #p.Cash > 0 then
            local primary = p.Cash[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Cash, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CashCollected", p)
        end
        Restaurant.SweepFloorCash()
    end
    function Restaurant.HandleOrdering()
        local p = Restaurant.ScanPrompts()
        if #p.Order > 0 then
            local primary = p.Order[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Order, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "OrdersTaken", p)
        end
    end
    function Restaurant.HandleCooking()
        local p = Restaurant.ScanPrompts()
        if #p.Cook > 0 then
            local primary = p.Cook[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Cook, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesCooked", p)
        end
    end
    function Restaurant.HandleServing()
        local p = Restaurant.ScanPrompts()
        if #p.Serve > 0 then
            local primary = p.Serve[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Serve, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesServed", p)
        end
    end
    function Restaurant.HandleCleaning()
        local p = Restaurant.ScanPrompts()
        if #p.Clean > 0 then
            local primary = p.Clean[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Clean, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "TablesCleaned", p)
        end
    end
    function Restaurant.HandleSeating()
        local p = Restaurant.ScanPrompts()
        if #p.Seat > 0 then
            local primary = p.Seat[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Seat, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CustomersSeated", p)
        end
    end
    function Restaurant.HandleDelivery()
        local p = Restaurant.ScanPrompts()
        if #p.Delivery > 0 then
            local primary = p.Delivery[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Delivery, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 4.0, "DeliveriesCompleted", p)
        end
    end
    function Restaurant.HandleRestock()
        local p = Restaurant.ScanPrompts()
        if #p.Restock > 0 then
            local primary = p.Restock[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Restock, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.5, "StorageRestocked", p)
        end
    end
    function Restaurant.HandleFarming()
        local p = Restaurant.ScanPrompts()
        if #p.Farm > 0 then
            local primary = p.Farm[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Farm, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CropsHarvested", p)
        end
    end
    function Restaurant.HandleExpansion()
        local p = Restaurant.ScanPrompts()
        if #p.Expand > 0 then executeAction(p.Expand[1], 6.0, "ExpansionsPurchased") end
    end

    local lastBuyCheck = 0
    function Restaurant.HandleAutoBuy()
        if not Config.AutoBuyEnabled then return false end
        local now = os.clock()
        if now - lastBuyCheck < 2.5 then return false end
        lastBuyCheck = now

        -- 1. Check in-world shop prompts
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Buy > 0 then
            for _, p in ipairs(prompts.Buy) do
                local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                local isStove = text:find("stove") or text:find("oven") or text:find("grill")
                local isTable = text:find("table") and not text:find("chair")
                local isChair = text:find("chair") or text:find("seat") or text:find("stool") or text:find("booth") or text:find("bench")
                local isAppliance = text:find("sink") or text:find("dish") or text:find("fridge") or text:find("cooler") or text:find("appliance")
                local isFurniture = text:find("furniture") or text:find("decor") or text:find("shelf") or text:find("plant") or text:find("light")

                local shouldBuy = (Config.AutoBuyStoves and isStove)
                               or (Config.AutoBuyTables and isTable)
                               or (Config.AutoBuyChairs and isChair)
                               or (Config.AutoBuyAppliances and isAppliance)
                               or (Config.AutoBuyFurniture and isFurniture)
                               or (not isStove and not isTable and not isChair and not isAppliance and not isFurniture)

                if shouldBuy then
                    local ok = executeAction(p, 4.0, "ItemsPurchased")
                    if ok then return true end
                end
            end
        end

        -- 2. Check Shop GUI in PlayerGui
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local gpName = (btn.Parent and btn.Parent.Parent and btn.Parent.Parent.Name or ""):lower()

                    if (bText:find("buy") or bText:find("purchase") or bName:find("buy") or bName:find("purchase")) and not bText:find("robux") then
                        local combined = (bText .. " " .. bName .. " " .. pName .. " " .. gpName):lower()
                        local isStove = combined:find("stove") or combined:find("oven") or combined:find("grill")
                        local isTable = combined:find("table") and not combined:find("chair")
                        local isChair = combined:find("chair") or combined:find("seat") or combined:find("stool") or combined:find("booth") or combined:find("bench")
                        local isAppliance = combined:find("sink") or combined:find("dish") or combined:find("fridge")
                        local isFurniture = combined:find("furniture") or combined:find("decor") or combined:find("plant") or combined:find("light")

                        local shouldBuy = (Config.AutoBuyStoves and isStove)
                                       or (Config.AutoBuyTables and isTable)
                                       or (Config.AutoBuyChairs and isChair)
                                       or (Config.AutoBuyAppliances and isAppliance)
                                       or (Config.AutoBuyFurniture and isFurniture)
                                       or (not isStove and not isTable and not isChair and not isAppliance and not isFurniture)

                        if shouldBuy then
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)
                            State.Stats.ItemsPurchased = State.Stats.ItemsPurchased + 1
                            task.wait(Config.PostActionDelay or 0.2)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local lastPlaceCheck = 0
    local placeGridIndex = 0
    function Restaurant.HandleAutoPlace()
        if not Config.AutoPlaceEnabled then return false end
        local now = os.clock()
        if now - lastPlaceCheck < 1.8 then return false end
        lastPlaceCheck = now

        -- 1. Check in-world "Place" / "Build" prompts on player's plot
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Place > 0 then
            for _, p in ipairs(prompts.Place) do
                if isPromptReady(p) and not State.InFlightTasks[p] then
                    local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                    local isTable = text:find("table")
                    local isChair = text:find("chair") or text:find("seat")
                    local isFurniture = text:find("furniture") or text:find("decor")

                    local shouldPlace = (Config.AutoPlaceTables and isTable)
                                     or (Config.AutoPlaceChairs and isChair)
                                     or (Config.AutoPlaceFurniture and isFurniture)
                                     or (not isTable and not isChair and not isFurniture)

                    if shouldPlace then
                        local ok = executeAction(p, 3.0, "ItemsPlaced")
                        if ok then return true end
                    end
                end
            end
        end

        -- 2. Check Build / Inventory GUI in PlayerGui for unplaced items
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local char, root = getAliveCharacter()
        local center = Restaurant.RestaurantCenter or (root and root.Position)
        if pg and center and char then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()

                    local isPlaceBtn = (bText == "place" or bText:find("place") or bName:find("place") or bText == "deploy" or bText == "build" or bText == "add") and not bText:find("cancel") and not bName:find("close")
                    if isPlaceBtn then
                        local combined = (bText .. " " .. bName .. " " .. pName):lower()
                        local isTable = combined:find("table")
                        local isChair = combined:find("chair") or combined:find("seat")
                        local isFurniture = combined:find("furniture") or combined:find("decor")

                        local shouldPlace = (Config.AutoPlaceTables and isTable)
                                         or (Config.AutoPlaceChairs and isChair)
                                         or (Config.AutoPlaceFurniture and isFurniture)
                                         or (not isTable and not isChair and not isFurniture)

                        if shouldPlace then
                            -- Trigger place button on item
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)

                            -- Calculate open floor grid coordinate near restaurant center
                            placeGridIndex = (placeGridIndex + 1) % 48
                            local ring = math.floor(placeGridIndex / 8) + 1
                            local angle = (placeGridIndex % 8) * (math.pi / 4)
                            local dist = ring * 6.5
                            local targetGridPos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                            local safeFloor = Utility.GetGroundPosition(targetGridPos, {char})

                            -- Teleport near position so placement raycasts succeed
                            if Config.AutoTeleportEnabled and root then
                                root.CFrame = CFrame.new(safeFloor + Vector3.new(0, 3, 0))
                                task.wait(0.15)
                            end

                            -- Check for placement confirm button in UI
                            for _, confirmBtn in ipairs(pg:GetDescendants()) do
                                if (confirmBtn:IsA("TextButton") or confirmBtn:IsA("ImageButton")) and confirmBtn.Visible then
                                    local cText = (confirmBtn:IsA("TextButton") and confirmBtn.Text or ""):lower()
                                    local cName = confirmBtn.Name:lower()
                                    if cText == "confirm" or cText == "✓" or cText:find("confirm") or cName:find("confirm") or cText == "place" then
                                        pcall(function()
                                            if type(firesignal) == "function" and confirmBtn.Activated then
                                                firesignal(confirmBtn.Activated)
                                            elseif confirmBtn.Activate then
                                                confirmBtn:Activate()
                                            end
                                        end)
                                        break
                                    end
                                end
                            end

                            -- Check ReplicatedStorage placement remote
                            local rs = game:GetService("ReplicatedStorage")
                            local placeRemote = rs:FindFirstChild("PlaceItem", true) or rs:FindFirstChild("PlaceObject", true) or rs:FindFirstChild("PlaceFurniture", true) or rs:FindFirstChild("BuildItem", true)
                            if placeRemote and placeRemote:IsA("RemoteEvent") then
                                pcall(function()
                                    placeRemote:FireServer(bName, CFrame.new(safeFloor))
                                end)
                            end

                            State.Stats.ItemsPlaced = State.Stats.ItemsPlaced + 1
                            task.wait(Config.PostActionDelay or 0.2)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local lastStaffCheck = 0
    function Restaurant.HandleStaffManage()
        if not Config.AutoHireStaffEnabled then return false end
        local now = os.clock()
        if now - lastStaffCheck < 4.0 then return false end
        lastStaffCheck = now

        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return false end

        for _, btn in ipairs(pg:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                local name = btn.Name:lower()
                local pName = (btn.Parent and btn.Parent.Name or ""):lower()

                if (text:find("hire") or text:find("recruit") or name:find("hire") or (pName:find("staff") and text:find("upgrade"))) and not text:find("robux") then
                    pcall(function()
                        if type(firesignal) == "function" and btn.Activated then
                            firesignal(btn.Activated)
                        elseif btn.Activate then
                            btn:Activate()
                        end
                        State.Stats.StaffHired = State.Stats.StaffHired + 1
                    end)
                    return true
                end
            end
        end
        return false
    end

    -- Interleaved multi-queue pipeline categories definition
    local pipelineCategories = {
        { name = "Serve", configKey = "AutoServeEnabled", stat = "DishesServed", cooldown = 2.5 },
        { name = "Cook", configKey = "AutoCookEnabled", stat = "DishesCooked", cooldown = 2.5 },
        { name = "Order", configKey = "AutoOrderEnabled", stat = "OrdersTaken", cooldown = 2.5 },
        { name = "Clean", configKey = "AutoCleanEnabled", stat = "TablesCleaned", cooldown = 3.0 },
        { name = "Seat", configKey = "AutoSeatEnabled", stat = "CustomersSeated", cooldown = 3.0 },
        { name = "Cash", configKey = "AutoCollectCashEnabled", stat = "CashCollected", cooldown = 3.0 },
        { name = "Delivery", configKey = "AutoDeliveryEnabled", stat = "DeliveriesCompleted", cooldown = 4.0 },
        { name = "Restock", configKey = "AutoRestockEnabled", stat = "StorageRestocked", cooldown = 3.5 },
        { name = "Farm", configKey = "AutoFarmEnabled", stat = "CropsHarvested", cooldown = 3.0 },
        { name = "Expand", configKey = "AutoExpandEnabled", stat = "ExpansionsPurchased", cooldown = 6.0 },
    }
    local pipelineCursor = 1

    -- Interleaved multi-queue scheduler: Dispatches next ready category round-robin to eliminate starvation
    function Restaurant.DispatchInterleavedPipeline(prompts)
        local isMaster = Config.MasterAutoFarmEnabled
        local totalCategories = #pipelineCategories

        for i = 0, totalCategories - 1 do
            local idx = ((pipelineCursor - 1 + i) % totalCategories) + 1
            local cat = pipelineCategories[idx]

            if (isMaster or Config[cat.configKey]) and prompts[cat.name] and #prompts[cat.name] > 0 then
                -- Find first ready prompt that is not currently in flight
                local primaryPrompt = nil
                for _, p in ipairs(prompts[cat.name]) do
                    if isPromptReady(p) and not State.InFlightTasks[p] then
                        primaryPrompt = p
                        break
                    end
                end

                if primaryPrompt then
                    if Config.ConcurrentExecutionEnabled then
                        local cluster = Restaurant.GetNearbyCluster(primaryPrompt, prompts[cat.name], 14, Config.StationBatchSize or 3)
                        executeCluster(primaryPrompt, cluster, cat.cooldown, cat.stat, prompts)
                    else
                        executeAction(primaryPrompt, cat.cooldown, cat.stat)
                    end

                    -- Advance cursor to next category for balanced, starvation-free progression
                    pipelineCursor = (idx % totalCategories) + 1
                    return true
                end
            end
        end

        return false
    end

    -- Master Autonomous Dispatcher & Parallel Workers
    local runningLoop = false
    function Restaurant.StartLoop()
        if runningLoop then return end
        runningLoop = true

        -- Decoupled Worker 1: Parallel Floor Cash Sweeper (Continuous remote pickup via firetouchinterest)
        task.spawn(function()
            while Core.State.Running and runningLoop do
                if Config.MasterAutoFarmEnabled or Config.AutoCollectCashEnabled then
                    pcall(function()
                        Restaurant.SweepFloorCash()
                    end)
                end
                task.wait(0.35)
            end
        end)

        -- Decoupled Worker 2: Parallel Background UI Manager (Quests, Daily Gifts, Staff, UI Catalog)
        task.spawn(function()
            while Core.State.Running and runningLoop do
                -- Auto-claim all quests, gifts, daily rewards, spin wheels, achievements
                local now = os.clock()
                if (Config.AutoClaimRewardsEnabled or Config.AutoClaimQuestsEnabled) and (now - lastQuestCheck > 4) then
                    lastQuestCheck = now
                    pcall(function()
                        Utility.ClaimAllRewards()
                    end)
                end

                -- Auto-hire / upgrade staff in background without interrupting kitchen
                if Config.AutoHireStaffEnabled then
                    pcall(function()
                        Restaurant.HandleStaffManage()
                    end)
                end

                -- Auto-buy catalog items if enabled
                if Config.AutoBuyEnabled then
                    pcall(function()
                        Restaurant.HandleAutoBuy()
                    end)
                end

                task.wait(2.5)
            end
        end)

        -- Master Worker 3: Physical Workstation Automation Loop
        task.spawn(function()
            while Core.State.Running and runningLoop do
                local delayTime = math.clamp(Config.ActionDelay or 0.3, 0.05, 5)

                -- Run memory sanitation
                cleanExpiredCooldowns()

                local char, _, hum = getAliveCharacter()
                if char and hum and hum.Health > 0 then
                    local prompts = Restaurant.ScanPrompts()
                    local dispatched = false

                    if Config.InterleavedPipelineEnabled then
                        dispatched = Restaurant.DispatchInterleavedPipeline(prompts)
                    else
                        -- Fallback: Classical single/cluster prioritized ladder
                        local isMaster = Config.MasterAutoFarmEnabled
                        local function dispatchCategory(list, cooldown, statKey)
                            for _, p in ipairs(list) do
                                if isPromptReady(p) and not State.InFlightTasks[p] then
                                    if Config.ConcurrentExecutionEnabled then
                                        local cluster = Restaurant.GetNearbyCluster(p, list, 14, Config.StationBatchSize or 3)
                                        return executeCluster(p, cluster, cooldown, statKey, prompts)
                                    else
                                        return executeAction(p, cooldown, statKey)
                                    end
                                end
                            end
                            return false
                        end

                        if (isMaster or Config.AutoCollectCashEnabled) and #prompts.Cash > 0 then
                            dispatched = dispatchCategory(prompts.Cash, 3.0, "CashCollected")
                        elseif (isMaster or Config.AutoOrderEnabled) and #prompts.Order > 0 then
                            dispatched = dispatchCategory(prompts.Order, 2.5, "OrdersTaken")
                        elseif (isMaster or Config.AutoServeEnabled) and #prompts.Serve > 0 then
                            dispatched = dispatchCategory(prompts.Serve, 2.5, "DishesServed")
                        elseif (isMaster or Config.AutoCookEnabled) and #prompts.Cook > 0 then
                            dispatched = dispatchCategory(prompts.Cook, 2.5, "DishesCooked")
                        elseif (isMaster or Config.AutoCleanEnabled) and #prompts.Clean > 0 then
                            dispatched = dispatchCategory(prompts.Clean, 3.0, "TablesCleaned")
                        elseif (isMaster or Config.AutoSeatEnabled) and #prompts.Seat > 0 then
                            dispatched = dispatchCategory(prompts.Seat, 3.0, "CustomersSeated")
                        elseif (isMaster or Config.AutoDeliveryEnabled) and #prompts.Delivery > 0 then
                            dispatched = dispatchCategory(prompts.Delivery, 4.0, "DeliveriesCompleted")
                        elseif (isMaster or Config.AutoRestockEnabled) and #prompts.Restock > 0 then
                            dispatched = dispatchCategory(prompts.Restock, 3.5, "StorageRestocked")
                        elseif (isMaster or Config.AutoFarmEnabled) and #prompts.Farm > 0 then
                            dispatched = dispatchCategory(prompts.Farm, 3.0, "CropsHarvested")
                        elseif (isMaster or Config.AutoPlaceEnabled) and Restaurant.HandleAutoPlace() then
                            dispatched = true
                        elseif Config.AutoExpandEnabled and #prompts.Expand > 0 then
                            dispatched = dispatchCategory(prompts.Expand, 6.0, "ExpansionsPurchased")
                        end
                    end

                    -- Auto-place check if not already handled
                    if not dispatched and (Config.MasterAutoFarmEnabled or Config.AutoPlaceEnabled) then
                        pcall(function()
                            Restaurant.HandleAutoPlace()
                        end)
                    end
                end

                task.wait(delayTime)
            end
            runningLoop = false
        end)
    end

    function Restaurant.Init()
        Restaurant.GetPlayerPlot()
        Restaurant.StartLoop()
        print("🍽️ Run a Restaurant autonomous engine initialized successfully.")
    end

    function Restaurant.Cleanup()
        runningLoop = false
        cachedPlot = nil
        Restaurant.RestaurantCenter = nil
        table.clear(promptCooldowns)
        table.clear(State.InFlightTasks)

        local _, root = getAliveCharacter()
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    return Restaurant
end

end)()(Core)
Core.Restaurant.Init()

Core.Movement = (function()
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
    local noClipCache = setmetatable({}, {__mode = "k"})

    function Movement.Cleanup()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = (originalWalkSpeed ~= nil) and originalWalkSpeed or 16
            originalWalkSpeed = nil

            hum.JumpPower = (originalJumpPower ~= nil) and originalJumpPower or 50
            originalJumpPower = nil

            hum.JumpHeight = (originalJumpHeight ~= nil) and originalJumpHeight or 7.2
            originalJumpHeight = nil
        end

        if next(noClipCache) then
            for part, _ in pairs(noClipCache) do
                if part and part.Parent then
                    part.CanCollide = true
                end
            end
            table.clear(noClipCache)
        end
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end

    function Movement.Init()
        if Core.UI and Core.UI.Window then
            local MoveTab = Core.UI.Window:AddTab("Movement")
            MoveTab:AddSection("PHYSICS OVERRIDES")
            
            MoveTab:AddToggle("Speed Hack", Config.WalkSpeedEnabled, function(val) Config.WalkSpeedEnabled = val end)
            MoveTab:AddSlider("Walk Speed", Config.WalkSpeed, 16, 200, function(val) Config.WalkSpeed = val end)
            
            MoveTab:AddToggle("Jump Hack", Config.JumpPowerEnabled, function(val) Config.JumpPowerEnabled = val end)
            MoveTab:AddSlider("Jump Power", Config.JumpPower, 50, 300, function(val) Config.JumpPower = val end)
            
            MoveTab:AddSection("UTILITY")
            MoveTab:AddToggle("No-Clip", Config.NoClipEnabled, function(val) Config.NoClipEnabled = val end)
            MoveTab:AddToggle("Infinite Jump", Config.InfiniteJumpEnabled, function(val) Config.InfiniteJumpEnabled = val end)
        end

        -- Infinite Jump Logic
        Utility.RegisterConnection(UserInputService.JumpRequest:Connect(function()
            if Config.InfiniteJumpEnabled then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and not hum.Sit then
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

end)()(Core)
Core.Movement.Init()

-- 5. Build Settings Tab & Select Restaurant Tab
Core.UI.BuildSettingsTab()
if Core.UI and Core.UI.Window then
    pcall(function() Core.UI.Window:SelectTab("Restaurant") end)
end

-- 6. Start Keybind & Event Loop
Core.MainLoop = (function()
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

end)()(Core)
Core.MainLoop.Init()

print("🍽️ Run a Restaurant Utility loaded successfully!")
_G.__Restaurant_Terminate = Core.Utility.Terminate
