return function(Core)
    local UI = {}

    function UI.Init()
        local Config = Core.Config
        local State = Core.State
        local Utility = Core.Utility
        local Drawings = Core.Drawings
        local LocalPlayer = Core.Services.Players.LocalPlayer
        local CoreGui = Core.Services.CoreGui
        local UserInputService = Core.Services.UserInputService
        local CollectionService = Core.Services.CollectionService
        local Players = Core.Services.Players

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
        MainContainer.Size = UDim2.new(0, 310, 0, 520)
        MainContainer.Position = UDim2.new(0.5, -155, 0.5, -260)
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
        Title.Size = UDim2.new(1, -50, 1, 0)
        Title.Position = UDim2.new(0, 12, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "⚡ Pure Auto-Aim v2"
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

        local dragging, dragStart, startPos
        Utility.RegisterConnection(Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = MainContainer.Position
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

        local ScrollFrame = Instance.new("ScrollingFrame")
        ScrollFrame.Parent = MainContainer
        ScrollFrame.Position = UDim2.new(0, 0, 0, 40)
        ScrollFrame.Size = UDim2.new(1, 0, 1, -40)
        ScrollFrame.BackgroundTransparency = 1
        ScrollFrame.ScrollBarThickness = 4
        ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 70, 120)
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        ScrollFrame.BorderSizePixel = 0
        ScrollFrame.Active = true

        local UIList = Instance.new("UIListLayout")
        UIList.Parent = ScrollFrame
        UIList.SortOrder = Enum.SortOrder.LayoutOrder
        UIList.Padding = UDim.new(0, 4)
        UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local UIPad = Instance.new("UIPadding")
        UIPad.Parent = ScrollFrame
        UIPad.PaddingTop = UDim.new(0, 6)
        UIPad.PaddingBottom = UDim.new(0, 10)

        Utility.RegisterConnection(UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 20)
        end))

        local layoutOrder = 0
        local function NextOrder() layoutOrder = layoutOrder + 1; return layoutOrder end

        local function CreateSection(text)
            local f = Instance.new("Frame")
            f.Parent = ScrollFrame
            f.Size = UDim2.new(0.92, 0, 0, 22)
            f.BackgroundTransparency = 1
            f.LayoutOrder = NextOrder()
            local l = Instance.new("TextLabel")
            l.Parent = f; l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
            l.Text = "— " .. text .. " —"
            l.TextColor3 = Color3.fromRGB(140, 130, 190)
            l.Font = Enum.Font.GothamBold; l.TextSize = 11
        end

        local function CreateButton(text, onClick)
            local btn = Instance.new("TextButton")
            btn.Parent = ScrollFrame
            btn.Size = UDim2.new(0.88, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            btn.Font = Enum.Font.GothamBold
            btn.Text = text
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = 13
            btn.LayoutOrder = NextOrder()
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            Utility.RegisterConnection(btn.Activated:Connect(function() onClick(btn) end))
            return btn
        end

        local function CreateSlider(text, default, cb, min, max)
            min = min or 0
            max = max or math.max(default * 2, 100)
            if default < min then default = min end
            if default > max then default = max end

            local f = Instance.new("Frame")
            f.Parent = ScrollFrame
            f.Size = UDim2.new(0.88, 0, 0, 45)
            f.BackgroundTransparency = 1
            f.LayoutOrder = NextOrder()

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
            sliderBG.Parent = f; sliderBG.Size = UDim2.new(1,0,0,8)
            sliderBG.Position = UDim2.new(0,0,0,25)
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

        CreateSection("AIM")

        CreateButton("Auto-Aim: OFF", function(btn)
            Config.AutoAimEnabled = not Config.AutoAimEnabled
            btn.Text = "Auto-Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.AutoAimEnabled and Color3.fromRGB(35, 120, 35) or Color3.fromRGB(40,40,50)
            Drawings.FOVCircle.Visible = Config.AutoAimEnabled
        end)

        CreateSlider("FOV Radius:", Config.ViewAngle, function(v) Config.ViewAngle = v; Drawings.FOVCircle.Radius = v end, 10, 800)
        CreateSlider("Smoothing:", Config.Smoothing, function(v) Config.Smoothing = v end, 1, 30)

        CreateButton("Focus: " .. Config.FocusPoint, function(btn)
            Config.FocusPoint = Config.FocusPoint == "HumanoidRootPart" and "Head" or "HumanoidRootPart"
            btn.Text = "Focus: " .. Config.FocusPoint
        end)

        CreateButton("Method: " .. Config.TrackingMethod, function(btn)
            Config.TrackingMethod = Config.TrackingMethod == "Camera" and "Mouse" or "Camera"
            btn.Text = "Method: " .. Config.TrackingMethod
        end)

        CreateButton("Target: Both", function(btn)
            if Config.TargetMode == "Players" then Config.TargetMode = "NPCs"
            elseif Config.TargetMode == "NPCs" then Config.TargetMode = "Both"
            else Config.TargetMode = "Players" end
            btn.Text = "Target: " .. Config.TargetMode
        end)

        CreateButton("Priority: Distance", function(btn)
            if Config.PriorityMode == "Distance" then Config.PriorityMode = "LowHP"
            elseif Config.PriorityMode == "LowHP" then Config.PriorityMode = "Closest3D"
            else Config.PriorityMode = "Distance" end
            btn.Text = "Priority: " .. Config.PriorityMode
        end)

        CreateSection("ADVANCED")

        CreateButton("Wall Check: ON", function(btn)
            Config.WallCheck = not Config.WallCheck
            btn.Text = "Wall Check: " .. (Config.WallCheck and "ON" or "OFF")
        end)

        CreateButton("Team Check: ON", function(btn)
            Config.TeamCheck = not Config.TeamCheck
            btn.Text = "Team Check: " .. (Config.TeamCheck and "ON" or "OFF")
        end)

        CreateButton("Sticky Target: ON", function(btn)
            Config.StickyTarget = not Config.StickyTarget
            btn.Text = "Sticky Target: " .. (Config.StickyTarget and "ON" or "OFF")
            if not Config.StickyTarget then State.LockedTarget = nil; State.LockedCharacter = nil end
        end)

        CreateButton("Prediction: OFF", function(btn)
            Config.Prediction = not Config.Prediction
            btn.Text = "Prediction: " .. (Config.Prediction and "ON" or "OFF")
            btn.BackgroundColor3 = Config.Prediction and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
        end)

        CreateSlider("Predict Scale:", Config.PredictionScale, function(v) Config.PredictionScale = v end, 0, 1)

        CreateSection("FEATURES")

        CreateButton("Auto-Respawn: OFF", function(btn)
            Config.AutoRespawn = not Config.AutoRespawn
            btn.Text = "Auto-Respawn: " .. (Config.AutoRespawn and "ON" or "OFF")
            btn.BackgroundColor3 = Config.AutoRespawn and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
        end)

        CreateButton("Kill Feed: ON", function(btn)
            Config.KillFeedEnabled = not Config.KillFeedEnabled
            btn.Text = "Kill Feed: " .. (Config.KillFeedEnabled and "ON" or "OFF")
        end)

        CreateButton("Target Info: ON", function(btn)
            Config.TargetInfoEnabled = not Config.TargetInfoEnabled
            btn.Text = "Target Info: " .. (Config.TargetInfoEnabled and "ON" or "OFF")
        end)

        CreateButton("Diagnostics: OFF", function(btn)
            Config.DiagnosticsEnabled = not Config.DiagnosticsEnabled
            btn.Text = "Diagnostics: " .. (Config.DiagnosticsEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.DiagnosticsEnabled and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
            Drawings.DiagnosticText.Visible = Config.DiagnosticsEnabled
        end)

        CreateButton("Remote Logger: OFF", function(btn)
            Config.RemoteLogEnabled = not Config.RemoteLogEnabled
            btn.Text = "Remote Logger: " .. (Config.RemoteLogEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.RemoteLogEnabled and Color3.fromRGB(35,120,35) or Color3.fromRGB(40,40,50)
        end)

        CreateSection("ESP")

        CreateButton("ESP: OFF", function(btn)
            Config.ESPEnabled = not Config.ESPEnabled
            btn.Text = "ESP: " .. (Config.ESPEnabled and "ON" or "OFF")
            btn.BackgroundColor3 = Config.ESPEnabled and Color3.fromRGB(120, 35, 120) or Color3.fromRGB(40,40,50)
            if not Config.ESPEnabled then
                for _, cache in pairs(State.ESPCache) do
                    for _, d in pairs(cache) do pcall(function() d.Visible = false end) end
                end
            end
        end)

        CreateButton("ESP Boxes: ON", function(btn)
            Config.ESPBoxes = not Config.ESPBoxes
            btn.Text = "ESP Boxes: " .. (Config.ESPBoxes and "ON" or "OFF")
        end)

        CreateButton("ESP Names: ON", function(btn)
            Config.ESPNames = not Config.ESPNames
            btn.Text = "ESP Names: " .. (Config.ESPNames and "ON" or "OFF")
        end)

        CreateButton("ESP Health: ON", function(btn)
            Config.ESPHealth = not Config.ESPHealth
            btn.Text = "ESP Health: " .. (Config.ESPHealth and "ON" or "OFF")
        end)

        CreateButton("ESP Distance: ON", function(btn)
            Config.ESPDistance = not Config.ESPDistance
            btn.Text = "ESP Distance: " .. (Config.ESPDistance and "ON" or "OFF")
        end)

        CreateButton("ESP Tracers: OFF", function(btn)
            Config.ESPTracers = not Config.ESPTracers
            btn.Text = "ESP Tracers: " .. (Config.ESPTracers and "ON" or "OFF")
            btn.BackgroundColor3 = Config.ESPTracers and Color3.fromRGB(120,35,120) or Color3.fromRGB(40,40,50)
        end)

        CreateButton("ESP Team Color: ON", function(btn)
            Config.ESPTeamColor = not Config.ESPTeamColor
            btn.Text = "ESP Team Color: " .. (Config.ESPTeamColor and "ON" or "OFF")
        end)

        CreateSlider("ESP Max Dist:", Config.ESPMaxDist, function(v) Config.ESPMaxDist = v end, 50, 5000)

        UI.MainContainer = MainContainer
    end

    return UI
end
