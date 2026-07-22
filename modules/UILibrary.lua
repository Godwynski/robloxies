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
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            
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
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if floatDragging and not floatHasMoved then
                    self.FloatingCircle.Visible = false
                    self.MainContainer.Visible = true
                    -- Animate open
                    self.MainContainer.Size = UDim2.new(0, self.MainContainer.Size.X.Offset, 0, 0)
                    tween(self.MainContainer, {Size = UDim2.new(0, self.MainContainer.Size.X.Offset, 0, self.MainContainer.Size.Y.Offset > 0 and self.MainContainer.Size.Y.Offset or 520)}, 0.3, Enum.EasingStyle.Back)
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
        Interface.Name = "PureAutoAimPanel"
        Interface.ResetOnSpawn = false
        Interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        pcall(function() Interface.Parent = Services.CoreGui end)
        if not Interface.Parent then
            Interface.Parent = Services.Players.LocalPlayer:WaitForChild("PlayerGui")
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
            local ok, err = pcall(function()
                if isfile and isfile("init.lua") then
                    loadstring(readfile("init.lua"))()
                else
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/init.lua?nocache=" .. tostring(tick())))()
                end
            end)
            if not ok then warn("[UILibrary] Refresh failed:", tostring(err)) end
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
        FloatIcon.Text = "⚡"
        FloatIcon.TextSize = 24
        FloatIcon.TextColor3 = Theme.TextPrimary
        FloatIcon.Font = Enum.Font.GothamBold

        Utility.RegisterConnection(MinimizeBtn.Activated:Connect(function()
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
        
        return card
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
            local posX = math.clamp(input.Position.X - sliderBG.AbsolutePosition.X, 0, sliderBG.AbsoluteSize.X)
            local pct = posX / sliderBG.AbsoluteSize.X
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
