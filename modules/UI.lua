return function(Core)
    local UI = {}

    function UI.Init()
        local Config = Core.Config
        local State = Core.State
        local Utility = Core.Utility
        local Drawings = Core.Drawings
        local Scanners = Core.Scanners
        local LocalPlayer = Core.Services.Players.LocalPlayer
        local CoreGui = Core.Services.CoreGui
        local UserInputService = Core.Services.UserInputService

        local Interface = Instance.new("ScreenGui")
        Interface.Name = "PureAutoAimPanel"
        Interface.ResetOnSpawn = false
        Interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        pcall(function() Interface.Parent = CoreGui end)
        if not Interface.Parent then
            Interface.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        local MainContainer = Instance.new("Frame")
        MainContainer.Parent = Interface
        MainContainer.Size = UDim2.new(0, 480, 0, 520)
        MainContainer.Position = UDim2.new(0.5, -240, 0.5, -260)
        MainContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        MainContainer.BorderSizePixel = 0
        MainContainer.Active = true
        Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0, 10)

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
        Title.Text = "⚡ Pure Auto-Aim v2.2.1 (Modular)"
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
        RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
        RefreshBtn.Text = "🔄"
        RefreshBtn.TextColor3 = Color3.new(1, 1, 1)
        RefreshBtn.Font = Enum.Font.GothamBold
        RefreshBtn.TextSize = 13
        Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)

        Utility.RegisterConnection(RefreshBtn.Activated:Connect(function()
            Utility.Terminate()
            Interface:Destroy()
            task.delay(0.2, function()
                local noCache = "?nocache=" .. tostring(tick())
                if isfile and isfile("init.lua") then
                    pcall(function() loadstring(readfile("init.lua"))() end)
                else
                    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/init.lua" .. noCache))() end)
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

        local FloatingCircle = Instance.new("ImageButton")
        FloatingCircle.Parent = Interface
        FloatingCircle.Size = UDim2.new(0, 50, 0, 50)
        FloatingCircle.Position = UDim2.new(0, 20, 0.5, -25)
        FloatingCircle.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        FloatingCircle.Visible = false
        FloatingCircle.Active = true
        Instance.new("UICorner", FloatingCircle).CornerRadius = UDim.new(1, 0)
        
        local floatStroke = Instance.new("UIStroke")
        floatStroke.Parent = FloatingCircle
        floatStroke.Color = Color3.fromRGB(190, 170, 255)
        floatStroke.Thickness = 2
        
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

        local floatDragging, floatDragStart, floatStartPos, floatHasMoved
        Utility.RegisterConnection(FloatingCircle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                floatDragging = true
                floatHasMoved = false
                floatDragStart = input.Position
                floatStartPos = FloatingCircle.Position
            end
        end))
        Utility.RegisterConnection(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and floatDragging then
                local delta = input.Position - floatDragStart
                if delta.Magnitude > 3 then
                    floatHasMoved = true
                    FloatingCircle.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
                end
            end
        end))
        Utility.RegisterConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then 
                if floatDragging and not floatHasMoved then
                    FloatingCircle.Visible = false
                    MainContainer.Visible = true
                end
                floatDragging = false 
            end
        end))

        local dragging, dragStart, startPos
        Utility.RegisterConnection(Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; dragStart = input.Position; startPos = MainContainer.Position
            end
        end))
        Utility.RegisterConnection(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                local delta = input.Position - dragStart
                MainContainer.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        Utility.RegisterConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end))

        -- Resize Handle
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

        local resizing, resizeStart, sizeStart
        Utility.RegisterConnection(ResizeBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = true
                resizeStart = input.Position
                sizeStart = MainContainer.AbsoluteSize
            end
        end))
        Utility.RegisterConnection(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and resizing then
                local delta = input.Position - resizeStart
                local newW = math.clamp(sizeStart.X + delta.X, 480, 1200)
                local newH = math.clamp(sizeStart.Y + delta.Y, 300, 1000)
                MainContainer.Size = UDim2.new(0, newW, 0, newH)
            end
        end))
        Utility.RegisterConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
        end))

        -- Tabs Bar
        local TabBar = Instance.new("Frame")
        TabBar.Parent = MainContainer
        TabBar.Size = UDim2.new(1, -16, 0, 36)
        TabBar.Position = UDim2.new(0, 8, 0, 46)
        TabBar.BackgroundTransparency = 1

        local TabList = Instance.new("UIListLayout")
        TabList.Parent = TabBar
        TabList.FillDirection = Enum.FillDirection.Horizontal
        TabList.SortOrder = Enum.SortOrder.LayoutOrder
        TabList.Padding = UDim.new(0, 8)

        local TabContainer = Instance.new("Frame")
        TabContainer.Parent = MainContainer
        TabContainer.Size = UDim2.new(1, 0, 1, -90)
        TabContainer.Position = UDim2.new(0, 0, 0, 90)
        TabContainer.BackgroundTransparency = 1

        local tabs = {}
        local tabFrames = {}

        local function SelectTab(name)
            for tName, btn in pairs(tabs) do
                if tName == name then
                    btn.BackgroundColor3 = Color3.fromRGB(80, 70, 120)
                    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    tabFrames[tName].Visible = true
                else
                    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
                    tabFrames[tName].Visible = false
                end
            end
        end

        local function CreateTabButton(name, order)
            local btn = Instance.new("TextButton")
            btn.Parent = TabBar
            btn.Size = UDim2.new(0.2, -6, 1, 0)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            btn.Font = Enum.Font.GothamBold
            btn.Text = name
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
            btn.TextSize = 13
            btn.LayoutOrder = order
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            Utility.RegisterConnection(btn.Activated:Connect(function() SelectTab(name) end))
            tabs[name] = btn

            local frame
            if name == "Info" then
                frame = Instance.new("Frame")
                frame.Parent = TabContainer
                frame.Size = UDim2.new(1, 0, 1, 0)
                frame.BackgroundTransparency = 1
                frame.Visible = false
            else
                frame = Instance.new("ScrollingFrame")
                frame.Parent = TabContainer
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
            end
            tabFrames[name] = frame
            return frame
        end

        local CombatFrame = CreateTabButton("Combat", 1)
        local VisualsFrame = CreateTabButton("Visuals", 2)
        local MovementFrame = CreateTabButton("Movement", 3)
        local SettingsFrame = CreateTabButton("Settings", 4)
        local InfoFrame = CreateTabButton("Info", 5)

        local function NextOrder(parent)
            local c = 0
            for _, v in ipairs(parent:GetChildren()) do if v:IsA("GuiObject") then c = c + 1 end end
            return c
        end

        local function CreateSection(parent, text)
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

        local function CreateButton(parent, text, onClick)
            local btn = Instance.new("TextButton")
            btn.Parent = parent
            btn.Size = UDim2.new(0.9, 0, 0, 32)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            btn.Font = Enum.Font.GothamBold
            btn.Text = text
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = 13
            btn.LayoutOrder = NextOrder(parent)
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            Utility.RegisterConnection(btn.Activated:Connect(function() onClick(btn) end))
            return btn
        end

        local function CreateSlider(parent, text, default, cb, min, max)
            min = min or 0
            max = max or math.max(default * 2, 100)
            if default < min then default = min end
            if default > max then default = max end

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

            local isDragging = false
            local function updateSlider(input)
                local posX = math.clamp(input.Position.X - sliderBG.AbsolutePosition.X, 0, sliderBG.AbsoluteSize.X)
                local pct = posX / sliderBG.AbsoluteSize.X
                sliderFill.Size = UDim2.new(pct, 0, 1, 0)
                local val = min + ((max - min) * pct)
                val = math.floor(val * 100) / 100
                valLbl.Text = tostring(val)
                cb(val)
            end

            Utility.RegisterConnection(sliderBG.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDragging = true
                    updateSlider(input)
                end
            end))

            Utility.RegisterConnection(UserInputService.InputChanged:Connect(function(input)
                if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(input)
                end
            end))

            Utility.RegisterConnection(UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDragging = false
                end
            end))

            return f
        end

        -- ================== COMBAT TAB ==================
        CreateSection(CombatFrame, "AIM")
        CreateButton(CombatFrame, "Auto-Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF"), function(btn)
            Config.AutoAimEnabled = not Config.AutoAimEnabled
            btn.Text = "Auto-Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.AutoAimEnabled and Color3.fromRGB(35, 120, 35) or Color3.fromRGB(40,40,50)
            Drawings.FOVCircle.Visible = Config.AutoAimEnabled
        end).BackgroundColor3 = Config.AutoAimEnabled and Color3.fromRGB(35, 120, 35) or Color3.fromRGB(40,40,50)

        CreateSlider(CombatFrame, "FOV Radius:", Config.ViewAngle, function(v) Config.ViewAngle = v; Drawings.FOVCircle.Radius = v end, 10, 800)
        CreateSlider(CombatFrame, "Smoothing:", Config.Smoothing, function(v) Config.Smoothing = v end, 0.01, 30)

        CreateButton(CombatFrame, "Focus: " .. Config.FocusPoint, function(btn)
            Config.FocusPoint = Config.FocusPoint == "HumanoidRootPart" and "Head" or "HumanoidRootPart"
            btn.Text = "Focus: " .. Config.FocusPoint
        end)

        CreateButton(CombatFrame, "Method: " .. Config.TrackingMethod, function(btn)
            Config.TrackingMethod = Config.TrackingMethod == "Camera" and "Mouse" or "Camera"
            btn.Text = "Method: " .. Config.TrackingMethod
        end)

        CreateButton(CombatFrame, "Target: " .. Config.TargetMode, function(btn)
            if Config.TargetMode == "Players" then Config.TargetMode = "NPCs"
            elseif Config.TargetMode == "NPCs" then Config.TargetMode = "Both"
            else Config.TargetMode = "Players" end
            btn.Text = "Target: " .. Config.TargetMode
        end)

        CreateButton(CombatFrame, "Priority: " .. Config.PriorityMode, function(btn)
            if Config.PriorityMode == "Distance" then Config.PriorityMode = "LowHP"
            elseif Config.PriorityMode == "LowHP" then Config.PriorityMode = "Closest3D"
            else Config.PriorityMode = "Distance" end
            btn.Text = "Priority: " .. Config.PriorityMode
        end)

        CreateSection(CombatFrame, "ADVANCED")
        CreateButton(CombatFrame, "Wall Check: " .. (Config.WallCheck and "ON" or "OFF"), function(btn)
            Config.WallCheck = not Config.WallCheck
            btn.Text = "Wall Check: " .. (Config.WallCheck and "ON" or "OFF")
        end)

        CreateButton(CombatFrame, "Team Check: " .. (Config.TeamCheck and "ON" or "OFF"), function(btn)
            Config.TeamCheck = not Config.TeamCheck
            btn.Text = "Team Check: " .. (Config.TeamCheck and "ON" or "OFF")
        end)

        CreateButton(CombatFrame, "Sticky Target: " .. (Config.StickyTarget and "ON" or "OFF"), function(btn)
            Config.StickyTarget = not Config.StickyTarget
            btn.Text = "Sticky Target: " .. (Config.StickyTarget and "ON" or "OFF")
            if not Config.StickyTarget then State.LockedTarget = nil; State.LockedCharacter = nil end
        end)

        CreateButton(CombatFrame, "Prediction: " .. (Config.Prediction and "ON" or "OFF"), function(btn)
            Config.Prediction = not Config.Prediction
            btn.Text = "Prediction: " .. (Config.Prediction and "ON" or "OFF")
            btn.BackgroundColor3 = Config.Prediction and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.Prediction and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)

        CreateSlider(CombatFrame, "Predict Scale:", Config.PredictionScale, function(v) Config.PredictionScale = v end, 0, 1)

        -- ================== VISUALS TAB ==================
        CreateSection(VisualsFrame, "ESP OVERLAYS")
        CreateButton(VisualsFrame, "ESP: " .. (Config.ESPEnabled and "ON" or "OFF"), function(btn)
            Config.ESPEnabled = not Config.ESPEnabled
            btn.Text = "ESP: " .. (Config.ESPEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.ESPEnabled and Color3.fromRGB(120, 35, 120) or Color3.fromRGB(40,40,50)
            if not Config.ESPEnabled then
                for _, cache in pairs(State.ESPCache) do
                    for _, d in pairs(cache) do pcall(function() d.Visible = false end) end
                end
            end
        end).BackgroundColor3 = Config.ESPEnabled and Color3.fromRGB(120, 35, 120) or Color3.fromRGB(40,40,50)

        CreateButton(VisualsFrame, "ESP Boxes: " .. (Config.ESPBoxes and "ON" or "OFF"), function(btn)
            Config.ESPBoxes = not Config.ESPBoxes; btn.Text = "ESP Boxes: " .. (Config.ESPBoxes and "ON" or "OFF")
        end)
        CreateButton(VisualsFrame, "ESP Names: " .. (Config.ESPNames and "ON" or "OFF"), function(btn)
            Config.ESPNames = not Config.ESPNames; btn.Text = "ESP Names: " .. (Config.ESPNames and "ON" or "OFF")
        end)
        CreateButton(VisualsFrame, "ESP Health: " .. (Config.ESPHealth and "ON" or "OFF"), function(btn)
            Config.ESPHealth = not Config.ESPHealth; btn.Text = "ESP Health: " .. (Config.ESPHealth and "ON" or "OFF")
        end)
        CreateButton(VisualsFrame, "ESP Distance: " .. (Config.ESPDistance and "ON" or "OFF"), function(btn)
            Config.ESPDistance = not Config.ESPDistance; btn.Text = "ESP Distance: " .. (Config.ESPDistance and "ON" or "OFF")
        end)
        CreateButton(VisualsFrame, "ESP Tracers: " .. (Config.ESPTracers and "ON" or "OFF"), function(btn)
            Config.ESPTracers = not Config.ESPTracers
            btn.Text = "ESP Tracers: " .. (Config.ESPTracers and "ON" or "OFF")
            btn.BackgroundColor3 = Config.ESPTracers and Color3.fromRGB(120,35,120) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.ESPTracers and Color3.fromRGB(120,35,120) or Color3.fromRGB(40,40,50)

        CreateButton(VisualsFrame, "ESP Team Color: " .. (Config.ESPTeamColor and "ON" or "OFF"), function(btn)
            Config.ESPTeamColor = not Config.ESPTeamColor; btn.Text = "ESP Team Color: " .. (Config.ESPTeamColor and "ON" or "OFF")
        end)

        CreateSlider(VisualsFrame, "ESP Max Dist:", Config.ESPMaxDist, function(v) Config.ESPMaxDist = v end, 50, 5000)

        CreateSection(VisualsFrame, "OPTIMIZATION")
        CreateButton(VisualsFrame, "Optimize FPS (Potato Mode)", function(btn)
            Core.Utility.OptimizeFPS()
            local old = btn.Text
            btn.Text = "Optimization Applied!"
            btn.BackgroundColor3 = Color3.fromRGB(35, 120, 35)
            task.delay(2, function() btn.Text = old; btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50) end)
        end)

        -- ================== MOVEMENT TAB ==================
        CreateSection(MovementFrame, "PLAYER MOVEMENT")
        
        CreateButton(MovementFrame, "WalkSpeed Override: " .. (Config.WalkSpeedEnabled and "ON" or "OFF"), function(btn)
            Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
            btn.Text = "WalkSpeed Override: " .. (Config.WalkSpeedEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.WalkSpeedEnabled and Color3.fromRGB(35,120,120) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.WalkSpeedEnabled and Color3.fromRGB(35,120,120) or Color3.fromRGB(40,40,50)

        CreateSlider(MovementFrame, "WalkSpeed:", Config.WalkSpeed, function(v) Config.WalkSpeed = v end, 16, 100)

        CreateButton(MovementFrame, "JumpPower Override: " .. (Config.JumpPowerEnabled and "ON" or "OFF"), function(btn)
            Config.JumpPowerEnabled = not Config.JumpPowerEnabled
            btn.Text = "JumpPower Override: " .. (Config.JumpPowerEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.JumpPowerEnabled and Color3.fromRGB(35,120,120) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.JumpPowerEnabled and Color3.fromRGB(35,120,120) or Color3.fromRGB(40,40,50)

        CreateSlider(MovementFrame, "JumpPower:", Config.JumpPower, function(v) Config.JumpPower = v end, 50, 200)

        CreateSection(MovementFrame, "EXPLOITS")
        
        CreateButton(MovementFrame, "Infinite Jump: " .. (Config.InfiniteJumpEnabled and "ON" or "OFF"), function(btn)
            Config.InfiniteJumpEnabled = not Config.InfiniteJumpEnabled
            btn.Text = "Infinite Jump: " .. (Config.InfiniteJumpEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.InfiniteJumpEnabled and Color3.fromRGB(120,120,35) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.InfiniteJumpEnabled and Color3.fromRGB(120,120,35) or Color3.fromRGB(40,40,50)

        CreateButton(MovementFrame, "NoClip: " .. (Config.NoClipEnabled and "ON" or "OFF"), function(btn)
            Config.NoClipEnabled = not Config.NoClipEnabled
            btn.Text = "NoClip: " .. (Config.NoClipEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.NoClipEnabled and Color3.fromRGB(120,35,35) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.NoClipEnabled and Color3.fromRGB(120,35,35) or Color3.fromRGB(40,40,50)

        -- ================== SETTINGS TAB ==================
        CreateSection(SettingsFrame, "SYSTEM FEATURES")
        CreateButton(SettingsFrame, "Auto-Respawn: " .. (Config.AutoRespawn and "ON" or "OFF"), function(btn)
            Config.AutoRespawn = not Config.AutoRespawn
            btn.Text = "Auto-Respawn: " .. (Config.AutoRespawn and "ON" or "OFF")
            btn.BackgroundColor3 = Config.AutoRespawn and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.AutoRespawn and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)

        CreateButton(SettingsFrame, "Kill Feed: " .. (Config.KillFeedEnabled and "ON" or "OFF"), function(btn)
            Config.KillFeedEnabled = not Config.KillFeedEnabled; btn.Text = "Kill Feed: " .. (Config.KillFeedEnabled and "ON" or "OFF")
        end)

        CreateButton(SettingsFrame, "Target Info Overlay: " .. (Config.TargetInfoEnabled and "ON" or "OFF"), function(btn)
            Config.TargetInfoEnabled = not Config.TargetInfoEnabled; btn.Text = "Target Info Overlay: " .. (Config.TargetInfoEnabled and "ON" or "OFF")
        end)

        CreateButton(SettingsFrame, "Diagnostics Overlay: " .. (Config.DiagnosticsEnabled and "ON" or "OFF"), function(btn)
            Config.DiagnosticsEnabled = not Config.DiagnosticsEnabled
            btn.Text = "Diagnostics Overlay: " .. (Config.DiagnosticsEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.DiagnosticsEnabled and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
            Drawings.DiagnosticText.Visible = Config.DiagnosticsEnabled
        end).BackgroundColor3 = Config.DiagnosticsEnabled and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)

        CreateButton(SettingsFrame, "Remote Logger: " .. (Config.RemoteLogEnabled and "ON" or "OFF"), function(btn)
            Config.RemoteLogEnabled = not Config.RemoteLogEnabled
            btn.Text = "Remote Logger: " .. (Config.RemoteLogEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.RemoteLogEnabled and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
        end).BackgroundColor3 = Config.RemoteLogEnabled and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)

        -- ================== INFO / SCANNERS TAB ==================
        local ScannersList = Instance.new("ScrollingFrame")
        ScannersList.Parent = InfoFrame
        ScannersList.Size = UDim2.new(0, 150, 1, -10)
        ScannersList.Position = UDim2.new(0, 10, 0, 5)
        ScannersList.BackgroundTransparency = 1
        ScannersList.ScrollBarThickness = 3
        ScannersList.ScrollBarImageColor3 = Color3.fromRGB(80, 70, 120)
        ScannersList.BorderSizePixel = 0

        local SListLayout = Instance.new("UIListLayout")
        SListLayout.Parent = ScannersList
        SListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        SListLayout.Padding = UDim.new(0, 6)

        Utility.RegisterConnection(SListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ScannersList.CanvasSize = UDim2.new(0, 0, 0, SListLayout.AbsoluteContentSize.Y + 10)
        end))

        local OutputFrame = Instance.new("Frame")
        OutputFrame.Parent = InfoFrame
        OutputFrame.Size = UDim2.new(1, -180, 1, -10)
        OutputFrame.Position = UDim2.new(0, 170, 0, 5)
        OutputFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Instance.new("UICorner", OutputFrame).CornerRadius = UDim.new(0, 6)

        local OutputScroll = Instance.new("ScrollingFrame")
        OutputScroll.Parent = OutputFrame
        OutputScroll.Size = UDim2.new(1, -16, 1, -46)
        OutputScroll.Position = UDim2.new(0, 8, 0, 8)
        OutputScroll.BackgroundTransparency = 1
        OutputScroll.ScrollBarThickness = 4
        OutputScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 70, 120)
        OutputScroll.BorderSizePixel = 0

        local OutputBox = Instance.new("TextBox")
        OutputBox.Parent = OutputScroll
        OutputBox.Size = UDim2.new(1, -8, 0, 500)
        OutputBox.BackgroundTransparency = 1
        OutputBox.ClearTextOnFocus = false
        OutputBox.TextEditable = false -- Allows selection for copying
        OutputBox.MultiLine = true
        OutputBox.TextWrapped = true
        OutputBox.TextXAlignment = Enum.TextXAlignment.Left
        OutputBox.TextYAlignment = Enum.TextYAlignment.Top
        OutputBox.Font = Enum.Font.RobotoMono
        OutputBox.TextSize = 12
        OutputBox.TextColor3 = Color3.fromRGB(200, 200, 200)
        OutputBox.Text = "Select a scanner from the left to view output here.\n\nYou can click the button below to copy the text."

        local function updateScroll()
            local y = OutputBox.TextBounds.Y
            if y < OutputScroll.AbsoluteSize.Y then y = OutputScroll.AbsoluteSize.Y end
            OutputBox.Size = UDim2.new(1, -8, 0, y + 20)
            OutputScroll.CanvasSize = UDim2.new(0, 0, 0, y + 30)
        end
        Utility.RegisterConnection(OutputBox:GetPropertyChangedSignal("TextBounds"):Connect(updateScroll))
        Utility.RegisterConnection(OutputBox:GetPropertyChangedSignal("Text"):Connect(updateScroll))

        local CopyBtn = Instance.new("TextButton")
        CopyBtn.Parent = OutputFrame
        CopyBtn.Size = UDim2.new(1, -16, 0, 30)
        CopyBtn.Position = UDim2.new(0, 8, 1, -38)
        CopyBtn.BackgroundColor3 = Color3.fromRGB(80, 70, 120)
        CopyBtn.Font = Enum.Font.GothamBold
        CopyBtn.Text = "📋 Copy Output to Clipboard"
        CopyBtn.TextColor3 = Color3.new(1, 1, 1)
        CopyBtn.TextSize = 13
        Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 6)
        Utility.RegisterConnection(CopyBtn.Activated:Connect(function()
            if setclipboard then
                setclipboard(OutputBox.Text)
                local oldText = CopyBtn.Text
                CopyBtn.Text = "Copied!"
                task.delay(1.5, function() CopyBtn.Text = oldText end)
            else
                local oldText = CopyBtn.Text
                CopyBtn.Text = "Executor does not support setclipboard!"
                task.delay(2, function() CopyBtn.Text = oldText end)
            end
        end))

        local function CreateScannerButton(name, scannerFunc)
            local btn = Instance.new("TextButton")
            btn.Parent = ScannersList
            btn.Size = UDim2.new(1, -8, 0, 32)
            btn.BackgroundColor3 = Color3.fromRGB(50, 45, 75)
            btn.Font = Enum.Font.GothamBold
            btn.Text = name
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = 11
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            Utility.RegisterConnection(btn.Activated:Connect(function()
                OutputBox.Text = "Scanning...\n"
                task.wait()
                local ok, res = pcall(scannerFunc)
                if ok then 
                    OutputBox.Text = res
                    -- Automatically copy to clipboard if supported by executor
                    if setclipboard then
                        pcall(function() setclipboard(res) end)
                    end
                else 
                    OutputBox.Text = "Error during scan:\n" .. tostring(res) 
                end
            end))
        end

        CreateScannerButton("Mega Scan", Scanners.MegaScan)
        CreateScannerButton("Game Data", Scanners.GameData)
        CreateScannerButton("Targeting Debug", Scanners.TargetDebug)
        CreateScannerButton("Network Remotes", Scanners.ScanRemotes)
        CreateScannerButton("Modules & Configs", Scanners.ScanConfigs)
        CreateScannerButton("Environment Map", Scanners.ScanEnvironment)
        CreateScannerButton("PlayerGui Scan", Scanners.ScanPlayerGui)
        CreateScannerButton("Team Services", Scanners.ScanTeams)
        CreateScannerButton("View Remote Log", Scanners.RemoteLog)

        -- Initialize Tab
        SelectTab("Combat")

        UI.MainContainer = MainContainer
        UI.FloatingCircle = FloatingCircle
        UI.FloatStroke = floatStroke

        function UI.UpdateFloatStatus()
            if not FloatingCircle.Visible then return end
            if Config.AutoAimEnabled then
                floatStroke.Color = Color3.fromRGB(50, 255, 50)
                FloatingCircle.BackgroundColor3 = Color3.fromRGB(25, 45, 25)
            elseif Config.ESPEnabled then
                floatStroke.Color = Color3.fromRGB(180, 50, 220)
                FloatingCircle.BackgroundColor3 = Color3.fromRGB(40, 25, 45)
            else
                floatStroke.Color = Color3.fromRGB(190, 170, 255)
                FloatingCircle.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            end
        end
    end

    return UI
end
