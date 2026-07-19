return function(Core)
    local UILibrary = {}
    local Services = Core.Services
    local Utility = Core.Utility

    -- State for dragging/resizing
    local floatDragging, floatHasMoved, floatDragStart, floatStartPos
    local dragging, dragStart, startPos
    local resizing, resizeStart, sizeStart
    local activeSliderId = nil
    local sliderCallbacks = {}
    local sliderIdCounter = 0

    local IDLE_COLOR = Color3.fromRGB(40, 40, 50)
    local HOVER_COLOR = Color3.fromRGB(60, 60, 75)

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
                end
                floatDragging = false
                dragging = false
                resizing = false
                activeSliderId = nil
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
        MainContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        MainContainer.BorderSizePixel = 0
        MainContainer.Active = true
        Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0, 10)
        self.MainContainer = MainContainer

        local UIStroke = Instance.new("UIStroke")
        UIStroke.Parent = MainContainer
        UIStroke.Color = Color3.fromRGB(60, 50, 90)
        UIStroke.Thickness = 1.5

        local Header = Instance.new("Frame")
        Header.Parent = MainContainer
        Header.Size = UDim2.new(1, 0, 0, 38)
        Header.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Header.BorderSizePixel = 0
        Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

        local HeaderBottom = Instance.new("Frame")
        HeaderBottom.Parent = Header
        HeaderBottom.Size = UDim2.new(1, 0, 0, 10)
        HeaderBottom.Position = UDim2.new(0, 0, 1, -10)
        HeaderBottom.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        HeaderBottom.BorderSizePixel = 0

        local Title = Instance.new("TextLabel")
        Title.Parent = Header
        Title.Size = UDim2.new(1, -120, 1, 0)
        Title.Position = UDim2.new(0, 12, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = titleText
        Title.TextColor3 = Color3.fromRGB(190, 170, 255)
        Title.TextSize = 15
        Title.TextXAlignment = Enum.TextXAlignment.Left

        local CloseBtn = Instance.new("TextButton")
        CloseBtn.Parent = Header
        CloseBtn.Size = UDim2.new(0, 28, 0, 28)
        CloseBtn.Position = UDim2.new(1, -33, 0, 5)
        CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        CloseBtn.Text = "X"
        CloseBtn.TextColor3 = Color3.new(1, 1, 1)
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
        RefreshBtn.TextColor3 = Color3.new(1, 1, 1)
        RefreshBtn.Font = Enum.Font.GothamBold
        RefreshBtn.TextSize = 16
        Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)
        Utility.RegisterConnection(RefreshBtn.Activated:Connect(function()
            Utility.Terminate()
            Interface:Destroy()
            task.wait(0.1)
            pcall(function()
                if isfile and isfile("init.lua") then
                    loadstring(readfile("init.lua"))()
                else
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/init.lua?nocache=" .. tostring(tick())))()
                end
            end)
        end))

        local MinimizeBtn = Instance.new("TextButton")
        MinimizeBtn.Parent = Header
        MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
        MinimizeBtn.Position = UDim2.new(1, -99, 0, 5)
        MinimizeBtn.BackgroundColor3 = Color3.fromRGB(150, 120, 50)
        MinimizeBtn.Text = "—"
        MinimizeBtn.TextColor3 = Color3.new(1, 1, 1)
        MinimizeBtn.Font = Enum.Font.GothamBold
        MinimizeBtn.TextSize = 13
        Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

        -- Floating Circle for Minimize
        local FloatingCircle = Instance.new("ImageButton")
        FloatingCircle.Parent = Interface
        FloatingCircle.Size = UDim2.new(0, 50, 0, 50)
        FloatingCircle.Position = UDim2.new(0, 20, 0.5, -25)
        FloatingCircle.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        FloatingCircle.Visible = false
        FloatingCircle.Active = true
        Instance.new("UICorner", FloatingCircle).CornerRadius = UDim.new(1, 0)
        self.FloatingCircle = FloatingCircle
        
        local FloatStroke = Instance.new("UIStroke")
        FloatStroke.Parent = FloatingCircle
        FloatStroke.Color = Color3.fromRGB(190, 170, 255)
        FloatStroke.Thickness = 2
        self.FloatStroke = FloatStroke
        
        local FloatIcon = Instance.new("TextLabel")
        FloatIcon.Parent = FloatingCircle
        FloatIcon.Size = UDim2.new(1, 0, 1, 0)
        FloatIcon.BackgroundTransparency = 1
        FloatIcon.Text = "⚡"
        FloatIcon.TextSize = 24
        FloatIcon.TextColor3 = Color3.new(1, 1, 1)
        FloatIcon.Font = Enum.Font.GothamBold

        Utility.RegisterConnection(MinimizeBtn.Activated:Connect(function()
            MainContainer.Visible = false
            FloatingCircle.Visible = true
        end))

        Utility.RegisterConnection(FloatingCircle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                floatDragging = true
                floatHasMoved = false
                floatDragStart = input.Position
                floatStartPos = FloatingCircle.Position
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
        ResizeBtn.TextColor3 = Color3.fromRGB(100, 100, 120)
        ResizeBtn.Font = Enum.Font.GothamBold
        ResizeBtn.TextSize = 22
        ResizeBtn.ZIndex = 100
        ResizeBtn.Active = true

        Utility.RegisterConnection(ResizeBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = true
                resizeStart = input.Position
                sizeStart = MainContainer.AbsoluteSize
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

        -- Single resize listener for tab widths (not per-tab to avoid jitter)
        Utility.RegisterConnection(self.TabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:UpdateTabWidths() end))
        
        -- Window object to return
        local Window = {
            Library = self,
            Tabs = {}
        }
        
        function Window:AddTab(name)
            return self.Library:CreateTab(name)
        end
        
        function Window:SelectTab(name)
            self.Library:SelectTab(name)
        end

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
                btn.BackgroundColor3 = Color3.fromRGB(80, 70, 120)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                self.TabFrames[tName].Visible = true
            else
                btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                btn.TextColor3 = Color3.fromRGB(150, 150, 150)
                self.TabFrames[tName].Visible = false
            end
        end
    end

    function UILibrary:CreateTab(name)
        self.TabCount = self.TabCount + 1
        
        local btn = Instance.new("TextButton")
        btn.Parent = self.TabBar
        btn.Size = UDim2.new(0, 0, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.Font = Enum.Font.GothamBold
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        btn.TextSize = 13
        btn.LayoutOrder = self.TabCount
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        Utility.RegisterConnection(btn.MouseEnter:Connect(function()
            if self.TabFrames[name] and not self.TabFrames[name].Visible then
                btn.BackgroundColor3 = Color3.fromRGB(50, 45, 70)
            end
        end))
        Utility.RegisterConnection(btn.MouseLeave:Connect(function()
            if self.TabFrames[name] and not self.TabFrames[name].Visible then
                btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            end
        end))

        Utility.RegisterConnection(btn.Activated:Connect(function() self:SelectTab(name) end))
        self.Tabs[name] = btn

        local frame = Instance.new("ScrollingFrame")
        frame.Parent = self.TabContainer
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.ScrollBarThickness = 4
        frame.ScrollBarImageColor3 = Color3.fromRGB(80, 70, 120)
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

        local TabObj = {
            Frame = frame,
            Library = self
        }

        function TabObj:AddSection(text)
            return self.Library:CreateSection(self.Frame, text)
        end
        function TabObj:AddButton(text, callback)
            return self.Library:CreateButton(self.Frame, text, callback)
        end
        function TabObj:AddToggle(text, initialState, callback)
            -- Syntactic sugar over AddButton
            local btn
            btn = self.Library:CreateButton(self.Frame, text .. ": " .. (initialState and "ON" or "OFF"), function()
                initialState = not initialState
                btn.Text = text .. ": " .. (initialState and "ON" or "OFF")
                btn.BackgroundColor3 = initialState and Color3.fromRGB(35, 120, 35) or IDLE_COLOR
                callback(initialState)
            end)
            btn.BackgroundColor3 = initialState and Color3.fromRGB(35, 120, 35) or IDLE_COLOR
            return {
                SetState = function(state)
                    initialState = state
                    btn.Text = text .. ": " .. (initialState and "ON" or "OFF")
                    btn.BackgroundColor3 = initialState and Color3.fromRGB(35, 120, 35) or IDLE_COLOR
                end
            }
        end
        function TabObj:AddSlider(text, default, min, max, callback)
            return self.Library:CreateSlider(self.Frame, text, default, callback, min, max)
        end

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
        f.Size = UDim2.new(0.92, 0, 0, 22)
        f.BackgroundTransparency = 1
        f.LayoutOrder = NextOrder(parent)
        local l = Instance.new("TextLabel")
        l.Parent = f; l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
        l.Text = "— " .. text .. " —"
        l.TextColor3 = Color3.fromRGB(140, 130, 190)
        l.Font = Enum.Font.GothamBold; l.TextSize = 11
    end

    function UILibrary:CreateButton(parent, text, onClick)
        local btn = Instance.new("TextButton")
        btn.Parent = parent
        btn.Size = UDim2.new(0.9, 0, 0, 32)
        btn.BackgroundColor3 = IDLE_COLOR
        btn.Font = Enum.Font.GothamBold
        btn.Text = text
        btn.TextColor3 = Color3.new(1,1,1)
        btn.TextSize = 13
        btn.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        Utility.RegisterConnection(btn.MouseEnter:Connect(function()
            if btn.BackgroundColor3 == IDLE_COLOR then
                btn.BackgroundColor3 = HOVER_COLOR
            end
        end))
        Utility.RegisterConnection(btn.MouseLeave:Connect(function()
            if btn.BackgroundColor3 == HOVER_COLOR then
                btn.BackgroundColor3 = IDLE_COLOR
            end
        end))

        Utility.RegisterConnection(btn.Activated:Connect(function() onClick(btn) end))
        return btn
    end

    function UILibrary:CreateSlider(parent, text, default, cb, min, max)
        min = min or 0
        max = max or (default > 0 and default * 2 or 100)
        if default < min then default = min end
        if default > max then default = max end

        sliderIdCounter = sliderIdCounter + 1
        local sliderId = sliderIdCounter

        local f = Instance.new("Frame")
        f.Parent = parent
        f.Size = UDim2.new(0.9, 0, 0, 48)
        f.BackgroundTransparency = 1
        f.LayoutOrder = NextOrder(parent)

        local lbl = Instance.new("TextLabel")
        lbl.Parent = f; lbl.Size = UDim2.new(0.7,0,0,20)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.new(1,1,1); lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left

        local valLbl = Instance.new("TextLabel")
        valLbl.Parent = f; valLbl.Size = UDim2.new(0.3,0,0,20)
        valLbl.Position = UDim2.new(0.7,0,0,0)
        valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(default)
        valLbl.TextColor3 = Color3.new(1,1,1); valLbl.Font = Enum.Font.Gotham
        valLbl.TextSize = 13; valLbl.TextXAlignment = Enum.TextXAlignment.Right

        local sliderBG = Instance.new("TextButton")
        sliderBG.Parent = f; sliderBG.Size = UDim2.new(1,0,0,10)
        sliderBG.Position = UDim2.new(0,0,0,26)
        sliderBG.BackgroundColor3 = Color3.fromRGB(30,30,40)
        sliderBG.Text = ""; sliderBG.AutoButtonColor = false
        Instance.new("UICorner", sliderBG).CornerRadius = UDim.new(1, 0)

        local sliderFill = Instance.new("Frame")
        sliderFill.Parent = sliderBG; sliderFill.Size = UDim2.new((default - min) / (max - min),0,1,0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(120, 100, 200)
        Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

        local function updateSlider(input)
            local posX = math.clamp(input.Position.X - sliderBG.AbsolutePosition.X, 0, sliderBG.AbsoluteSize.X)
            local pct = posX / sliderBG.AbsoluteSize.X
            sliderFill.Size = UDim2.new(pct, 0, 1, 0)
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

        return f
    end

    return UILibrary
end
