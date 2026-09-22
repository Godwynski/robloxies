-- init.lua
local repoURL = "https://raw.githubusercontent.com/Godwynski/robloxies/plain/"

-- Terminate previous instance if running
if _G.__Movement_Running then
    pcall(function() _G.__Movement_Terminate() end)
end
if _G.__PureAutoAim_Running then
    pcall(function() _G.__PureAutoAim_Terminate() end)
end
_G.__Movement_Running = true

-- Clean up any lingering GUI instances
local hiddenUI = (gethui and gethui()) or game:GetService("CoreGui")
for _, gui in ipairs(hiddenUI:GetChildren()) do
    if gui.Name == "RobloxMovementPanel" or gui.Name == "PureAutoAimPanel" then
        pcall(function() gui:Destroy() end)
    end
end
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name == "RobloxMovementPanel" or gui.Name == "PureAutoAimPanel" then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end)

print("Initializing Movement Utility...")

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
    local fileName = "Movement_Config.json"

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
        Running = true,
    }
    return State
end

end)()(Core)
Core.Utility = (function()
return function(Core)
    local Utility = {}

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

    function Utility.Terminate()
        local State = Core.State
        State.Running = false
        _G.__Movement_Running = false

        -- Disconnect all event connections
        for _, conn in ipairs(State.ActiveConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
        table.clear(State.ActiveConnections)

        -- Restore Movement if active
        if Core.Movement and Core.Movement.Cleanup then
            pcall(Core.Movement.Cleanup)
        end

        -- Clean up UI ScreenGui if active
        pcall(function()
            if Core.UI and Core.UI.Window and Core.UI.Window.Library and Core.UI.Window.Library.Interface then
                Core.UI.Window.Library.Interface:Destroy()
            end
        end)
    end

    return Utility
end

end)()(Core)

-- 3. Load UI Director
Core.UI = (function()
return function(Core)
    local UI = {}
    local Config = Core.Config

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
        Interface.Name = "RobloxMovementPanel"
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
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Theme.TextPrimary
        CloseBtn.Font = Enum.Font.GothamBold
        CloseBtn.TextSize = 13
        Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
        Utility.RegisterConnection(CloseBtn.Activated:Connect(function()
            Utility.Terminate()
            Interface:Destroy()
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
                        loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/plain/dist/main.lua?nocache=" .. tostring(tick())))()
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
        TabList.Padding = UDim.new(0, 8)

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
        local available = self.TabBar.AbsoluteSize.X - (self.TabCount - 1) * 8
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
        btn.TextSize = 13
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
        local Window = UILibrary:CreateWindow("🏃 Movement Utility")
        UI.Window = Window

        if UILibrary.FloatIcon then
            UILibrary.FloatIcon.Text = "🏃"
        end

        function UI.UpdateFloatStatus()
            if not UILibrary.FloatingCircle or not UILibrary.FloatingCircle.Visible then return end
            if Config.WalkSpeedEnabled or Config.JumpPowerEnabled or Config.NoClipEnabled or Config.InfiniteJumpEnabled then
                UILibrary.FloatStroke.Color = Theme.TextAccent
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(28, 22, 54)
            else
                UILibrary.FloatStroke.Color = Theme.Stroke
                UILibrary.FloatingCircle.BackgroundColor3 = Theme.ElementIdle
            end
        end

        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings")
            SettingsTab:AddSection("KEYBINDS")
            SettingsTab:AddKeybind("Toggle Menu", Config.MenuKey, function(key) Config.MenuKey = key end)
            SettingsTab:AddKeybind("Toggle No-Clip", Config.ToggleNoClipKey, function(key) Config.ToggleNoClipKey = key end)
            SettingsTab:AddKeybind("Toggle Speed Hack", Config.ToggleSpeedKey, function(key) Config.ToggleSpeedKey = key end)
            SettingsTab:AddKeybind("Toggle Jump Hack", Config.ToggleJumpKey, function(key) Config.ToggleJumpKey = key end)
            SettingsTab:AddKeybind("Toggle Infinite Jump", Config.ToggleInfJumpKey, function(key) Config.ToggleInfJumpKey = key end)

            SettingsTab:AddSection("CONFIG")
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
        end
    end

    return UI
end

end)()(Core)
Core.UI.Init()

-- 4. Load Movement Module
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
            if originalWalkSpeed ~= nil then
                hum.WalkSpeed = originalWalkSpeed
                originalWalkSpeed = nil
            end
            if originalJumpPower ~= nil then
                hum.JumpPower = originalJumpPower
                originalJumpPower = nil
            end
            if originalJumpHeight ~= nil then
                hum.JumpHeight = originalJumpHeight
                originalJumpHeight = nil
            end
        end

        if next(noClipCache) then
            for part, _ in pairs(noClipCache) do
                if part and part.Parent then
                    part.CanCollide = true
                end
            end
            table.clear(noClipCache)
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

-- 5. Build Settings Tab & Select Movement Tab
Core.UI.BuildSettingsTab()
if Core.UI and Core.UI.Window then
    pcall(function() Core.UI.Window:SelectTab("Movement") end)
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

print("Movement Utility loaded successfully!")
_G.__Movement_Terminate = Core.Utility.Terminate
