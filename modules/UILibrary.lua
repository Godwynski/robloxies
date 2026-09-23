return function(Core)
    local UILibrary = {}
    local Services = Core.Services
    local Utility = Core.Utility
    local TweenService = game:GetService("TweenService")
    local UserInputService = Services.UserInputService

    -- =========================================================================
    -- 1. PRODUCTION THEME ENGINE
    -- =========================================================================
    local Themes = {
        Violet = {
            Name = "Midnight Violet",
            Primary = Color3.fromRGB(130, 95, 255),
            PrimaryGradient = Color3.fromRGB(165, 125, 255),
            PrimaryDark = Color3.fromRGB(85, 55, 190),
            AccentGlow = Color3.fromRGB(130, 95, 255),
        },
        Emerald = {
            Name = "Emerald Cyber",
            Primary = Color3.fromRGB(16, 185, 129),
            PrimaryGradient = Color3.fromRGB(52, 211, 153),
            PrimaryDark = Color3.fromRGB(5, 120, 85),
            AccentGlow = Color3.fromRGB(16, 185, 129),
        },
        Sapphire = {
            Name = "Sapphire Ocean",
            Primary = Color3.fromRGB(59, 130, 246),
            PrimaryGradient = Color3.fromRGB(96, 165, 250),
            PrimaryDark = Color3.fromRGB(29, 78, 216),
            AccentGlow = Color3.fromRGB(59, 130, 246),
        },
        Amber = {
            Name = "Sunset Amber",
            Primary = Color3.fromRGB(245, 158, 11),
            PrimaryGradient = Color3.fromRGB(251, 191, 36),
            PrimaryDark = Color3.fromRGB(180, 83, 9),
            AccentGlow = Color3.fromRGB(245, 158, 11),
        },
        Carbon = {
            Name = "Obsidian Carbon",
            Primary = Color3.fromRGB(226, 232, 240),
            PrimaryGradient = Color3.fromRGB(248, 250, 252),
            PrimaryDark = Color3.fromRGB(100, 116, 139),
            AccentGlow = Color3.fromRGB(148, 163, 184),
        }
    }
    UILibrary.Themes = Themes

    local ActiveThemeName = (Core.Config and Core.Config.Theme) or "Violet"
    if not Themes[ActiveThemeName] then ActiveThemeName = "Violet" end

    local Theme = {
        CurrentName = ActiveThemeName,
        -- Base Glassmorphic Slate Palette
        Background = Color3.fromRGB(13, 15, 22),
        BackgroundGlow = Color3.fromRGB(18, 21, 32),
        Sidebar = Color3.fromRGB(10, 12, 17),
        Header = Color3.fromRGB(16, 19, 28),
        Card = Color3.fromRGB(21, 25, 36),
        CardHover = Color3.fromRGB(28, 33, 48),
        CardActive = Color3.fromRGB(32, 38, 56),
        CardBorder = Color3.fromRGB(38, 44, 64),
        CardBorderHover = Color3.fromRGB(62, 72, 102),
        CardInner = Color3.fromRGB(15, 18, 26),
        
        -- Text Palette
        TextPrimary = Color3.fromRGB(245, 247, 252),
        TextSecondary = Color3.fromRGB(150, 160, 180),
        TextMuted = Color3.fromRGB(100, 110, 130),
        
        -- Status Accents
        Success = Color3.fromRGB(34, 197, 94),
        Danger = Color3.fromRGB(239, 68, 68),
        Warning = Color3.fromRGB(245, 158, 11),
        Info = Color3.fromRGB(59, 130, 246),
        
        -- Dynamic Theme Accent
        Primary = Themes[ActiveThemeName].Primary,
        PrimaryGradient = Themes[ActiveThemeName].PrimaryGradient,
        PrimaryDark = Themes[ActiveThemeName].PrimaryDark,
        AccentGlow = Themes[ActiveThemeName].AccentGlow,
    }
    UILibrary.Theme = Theme

    -- Listeners for runtime theme updates
    local ThemeUpdateListeners = {}
    function UILibrary:RegisterThemeListener(callback)
        table.insert(ThemeUpdateListeners, callback)
    end

    function UILibrary:SetTheme(name)
        if not Themes[name] then return end
        Theme.CurrentName = name
        local pal = Themes[name]
        Theme.Primary = pal.Primary
        Theme.PrimaryGradient = pal.PrimaryGradient
        Theme.PrimaryDark = pal.PrimaryDark
        Theme.AccentGlow = pal.AccentGlow
        if Core.Config then Core.Config.Theme = name end
        for _, cb in ipairs(ThemeUpdateListeners) do
            pcall(cb, Theme)
        end
    end

    -- =========================================================================
    -- 2. AUDIO & ANIMATION HELPERS
    -- =========================================================================
    function UILibrary:PlaySound(soundType)
        if not Core.Config or not Core.Config.UISoundEnabled then return end
        task.spawn(function()
            local soundId = "rbxassetid://6895079853" -- default clean tick
            if soundType == "toggle" then soundId = "rbxassetid://6895079683"
            elseif soundType == "notify" then soundId = "rbxassetid://4590662766"
            elseif soundType == "tab" then soundId = "rbxassetid://6895079774"
            end
            local snd = Instance.new("Sound")
            snd.SoundId = soundId
            snd.Volume = 0.4
            snd.Parent = Services.CoreGui
            snd:Play()
            snd.Ended:Connect(function() snd:Destroy() end)
        end)
    end

    local function tween(object, properties, time, style, direction)
        time = time or 0.2
        style = style or Enum.EasingStyle.Quad
        direction = direction or Enum.EasingDirection.Out
        local tw = TweenService:Create(object, TweenInfo.new(time, style, direction), properties)
        tw:Play()
        return tw
    end
    UILibrary.Tween = tween

    -- Global drag/slider state
    local floatDragging, floatHasMoved, floatDragStart, floatStartPos
    local dragging, dragStart, startPos
    local resizing, resizeStart, sizeStart
    local activeSliderId = nil
    local sliderCallbacks = {}
    local sliderIdCounter = 0

    local activeKeybindBtn = nil
    local activeKeybindCb = nil

    -- =========================================================================
    -- 3. GLOBAL INPUT DISPATCHER (Desktop & Touch)
    -- =========================================================================
    function UILibrary:InitInputDispatchers()
        Utility.RegisterConnection(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            
            if floatDragging then
                local delta = input.Position - floatDragStart
                if delta.Magnitude > 3 then
                    floatHasMoved = true
                    local screenX = math.clamp(floatStartPos.X.Offset + delta.X, 10, Services.CoreGui.AbsoluteSize.X - 160)
                    local screenY = math.clamp(floatStartPos.Y.Offset + delta.Y, 10, Services.CoreGui.AbsoluteSize.Y - 60)
                    self.FloatingWidget.Position = UDim2.new(floatStartPos.X.Scale, screenX, floatStartPos.Y.Scale, screenY)
                end
            elseif dragging then
                local delta = input.Position - dragStart
                local screenW = Services.CoreGui.AbsoluteSize.X
                local screenH = Services.CoreGui.AbsoluteSize.Y
                local newX = math.clamp(startPos.X.Offset + delta.X, -self.MainContainer.AbsoluteSize.X * 0.5, screenW * 0.5)
                local newY = math.clamp(startPos.Y.Offset + delta.Y, -self.MainContainer.AbsoluteSize.Y * 0.5, screenH * 0.5)
                self.MainContainer.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
            elseif resizing then
                local delta = input.Position - resizeStart
                local newW = math.clamp(sizeStart.X + delta.X, 480, 1100)
                local newH = math.clamp(sizeStart.Y + delta.Y, 380, 850)
                self.MainContainer.Size = UDim2.new(0, newW, 0, newH)
            elseif activeSliderId then
                local cb = sliderCallbacks[activeSliderId]
                if cb then cb(input) end
            end
        end))

        Utility.RegisterConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if floatDragging and not floatHasMoved then
                    self:RestoreFromFloating()
                end
                floatDragging = false
                dragging = false
                resizing = false
                activeSliderId = nil
            end
        end))

        Utility.RegisterConnection(UserInputService.InputBegan:Connect(function(input)
            if activeKeybindBtn and input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if key == Enum.KeyCode.Escape then
                    activeKeybindBtn.Text = "None"
                    if activeKeybindCb then activeKeybindCb(Enum.KeyCode.None) end
                else
                    activeKeybindBtn.Text = key.Name
                    if activeKeybindCb then activeKeybindCb(key) end
                end
                tween(activeKeybindBtn, {BackgroundColor3 = Theme.CardInner})
                activeKeybindBtn = nil
                activeKeybindCb = nil
            end
        end))
    end

    -- =========================================================================
    -- 4. TOAST NOTIFICATION ENGINE
    -- =========================================================================
    function UILibrary:Notify(options)
        if not self.NotificationContainer then return end
        options = options or {}
        local title = options.Title or "Notification"
        local content = options.Content or ""
        local notifyType = options.Type or "Info" -- "Success", "Error", "Warning", "Info"
        local duration = options.Duration or 3.5

        local accentColor = Theme.Primary
        local iconSymbol = "ℹ"
        if notifyType == "Success" then
            accentColor = Theme.Success
            iconSymbol = "✓"
        elseif notifyType == "Error" then
            accentColor = Theme.Danger
            iconSymbol = "✕"
        elseif notifyType == "Warning" then
            accentColor = Theme.Warning
            iconSymbol = "⚠"
        end

        local toast = Instance.new("Frame")
        toast.Parent = self.NotificationContainer
        toast.Size = UDim2.new(1, 0, 0, 68)
        toast.Position = UDim2.new(1, 300, 0, 0)
        toast.BackgroundColor3 = Theme.Card
        toast.BorderSizePixel = 0
        toast.ClipsDescendants = true
        Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = toast
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local iconBg = Instance.new("Frame")
        iconBg.Parent = toast
        iconBg.Size = UDim2.new(0, 32, 0, 32)
        iconBg.Position = UDim2.new(0, 10, 0, 10)
        iconBg.BackgroundColor3 = accentColor
        iconBg.BackgroundTransparency = 0.85
        Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 6)

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Parent = iconBg
        iconLbl.Size = UDim2.new(1, 0, 1, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Text = iconSymbol
        iconLbl.TextColor3 = accentColor
        iconLbl.TextSize = 14

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = toast
        titleLbl.Size = UDim2.new(1, -75, 0, 18)
        titleLbl.Position = UDim2.new(0, 50, 0, 8)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = title
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local msgLbl = Instance.new("TextLabel")
        msgLbl.Parent = toast
        msgLbl.Size = UDim2.new(1, -75, 0, 32)
        msgLbl.Position = UDim2.new(0, 50, 0, 26)
        msgLbl.BackgroundTransparency = 1
        msgLbl.Font = Enum.Font.GothamMedium
        msgLbl.Text = content
        msgLbl.TextColor3 = Theme.TextSecondary
        msgLbl.TextSize = 11
        msgLbl.TextWrapped = true
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left
        msgLbl.TextYAlignment = Enum.TextYAlignment.Top

        -- Close cross button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Parent = toast
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -26, 0, 6)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Theme.TextMuted
        closeBtn.TextSize = 12

        -- Bottom Progress bar
        local progTrack = Instance.new("Frame")
        progTrack.Parent = toast
        progTrack.Size = UDim2.new(1, 0, 0, 3)
        progTrack.Position = UDim2.new(0, 0, 1, -3)
        progTrack.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
        progTrack.BorderSizePixel = 0

        local progFill = Instance.new("Frame")
        progFill.Parent = progTrack
        progFill.Size = UDim2.new(1, 0, 1, 0)
        progFill.BackgroundColor3 = accentColor
        progFill.BorderSizePixel = 0

        self:PlaySound("notify")

        -- Slide in
        tween(toast, {Position = UDim2.new(0, 0, 0, 0)}, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        tween(progFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

        local dismissed = false
        local function dismiss()
            if dismissed then return end
            dismissed = true
            local tw = tween(toast, {Position = UDim2.new(1, 300, 0, 0)}, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tw.Completed:Connect(function()
                toast:Destroy()
            end)
        end

        closeBtn.Activated:Connect(dismiss)
        task.delay(duration, dismiss)
    end

    -- =========================================================================
    -- 5. FLOATING WIDGET HUD (Compact Farming Pill)
    -- =========================================================================
    function UILibrary:CreateFloatingWidget()
        local pill = Instance.new("Frame")
        pill.Name = "RestaurantFloatingWidget"
        pill.Parent = self.Interface
        pill.Size = UDim2.new(0, 155, 0, 42)
        pill.Position = UDim2.new(0, 24, 0.5, -21)
        pill.BackgroundColor3 = Theme.Header
        pill.BorderSizePixel = 0
        pill.Active = true
        pill.Visible = false
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = pill
        stroke.Color = Theme.Primary
        stroke.Thickness = 1.5

        local icon = Instance.new("TextLabel")
        icon.Parent = pill
        icon.Size = UDim2.new(0, 30, 1, 0)
        icon.Position = UDim2.new(0, 10, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.Text = "🍽️"
        icon.TextSize = 18

        local dot = Instance.new("Frame")
        dot.Parent = pill
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.Position = UDim2.new(0, 44, 0.5, -4)
        dot.BackgroundColor3 = Theme.TextMuted
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local title = Instance.new("TextLabel")
        title.Parent = pill
        title.Size = UDim2.new(1, -60, 0, 16)
        title.Position = UDim2.new(0, 58, 0, 6)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "AUTO-FARM"
        title.TextColor3 = Theme.TextPrimary
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left

        local sub = Instance.new("TextLabel")
        sub.Parent = pill
        sub.Size = UDim2.new(1, -60, 0, 14)
        sub.Position = UDim2.new(0, 58, 0, 22)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.GothamMedium
        sub.Text = "IDLE (Click to open)"
        sub.TextColor3 = Theme.TextSecondary
        sub.TextSize = 9
        sub.TextXAlignment = Enum.TextXAlignment.Left

        -- Dragging logic
        pill.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                floatDragging = true
                floatHasMoved = false
                floatDragStart = input.Position
                floatStartPos = pill.Position
            end
        end)

        self.FloatingWidget = pill
        self.FloatingCircle = pill -- Alias for backward compatibility
        self.FloatingStatusDot = dot
        self.FloatingStatusSub = sub
        self.FloatingStroke = stroke

        self:RegisterThemeListener(function(t)
            stroke.Color = t.Primary
        end)
    end

    function UILibrary:UpdateFloatingStatus(isActive, statusText)
        if not self.FloatingWidget then return end
        if isActive then
            self.FloatingStatusDot.BackgroundColor3 = Theme.Success
            self.FloatingStatusSub.Text = statusText or "Farming Active"
            self.FloatingStatusSub.TextColor3 = Theme.Success
            self.FloatingStroke.Color = Theme.Primary
        else
            self.FloatingStatusDot.BackgroundColor3 = Theme.TextMuted
            self.FloatingStatusSub.Text = statusText or "IDLE (Click to open)"
            self.FloatingStatusSub.TextColor3 = Theme.TextSecondary
            self.FloatingStroke.Color = Theme.CardBorder
        end
    end

    function UILibrary:MinimizeToFloating()
        if not self.MainContainer or not self.FloatingWidget then return end
        self:PlaySound("toggle")
        self.SavedWindowSize = self.MainContainer.Size
        local tw = tween(self.MainContainer, {
            Size = UDim2.new(0, self.MainContainer.Size.X.Offset * 0.7, 0, 0),
            Position = UDim2.new(self.MainContainer.Position.X.Scale, self.MainContainer.Position.X.Offset, self.MainContainer.Position.Y.Scale, self.MainContainer.Position.Y.Offset + 50)
        }, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        tw.Completed:Connect(function()
            self.MainContainer.Visible = false
            self.FloatingWidget.Visible = true
            self.FloatingWidget.Position = UDim2.new(0, 24, 0.5, -21)
        end)
    end

    function UILibrary:RestoreFromFloating()
        if not self.MainContainer or not self.FloatingWidget then return end
        self:PlaySound("toggle")
        self.FloatingWidget.Visible = false
        self.MainContainer.Visible = true
        local targetSize = self.SavedWindowSize or UDim2.new(0, 620, 0, 490)
        self.MainContainer.Size = UDim2.new(0, targetSize.X.Offset * 0.8, 0, 0)
        tween(self.MainContainer, {Size = targetSize}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end

    function UILibrary:ToggleWindow()
        if not self.MainContainer then return end
        if self.MainContainer.Visible then
            self:MinimizeToFloating()
        else
            self:RestoreFromFloating()
        end
    end

    -- =========================================================================
    -- 6. MAIN WINDOW CREATION
    -- =========================================================================
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

        -- Main Window Canvas
        local MainContainer = Instance.new("Frame")
        MainContainer.Name = "MainContainer"
        MainContainer.Parent = Interface
        MainContainer.Size = UDim2.new(0, 620, 0, 490)
        MainContainer.Position = UDim2.new(0.5, -310, 0.5, -245)
        MainContainer.BackgroundColor3 = Theme.Background
        MainContainer.BorderSizePixel = 0
        MainContainer.Active = true
        MainContainer.ClipsDescendants = false
        Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0, 10)
        self.MainContainer = MainContainer

        -- Subtle Outer Glow & Specular Border
        local UIStroke = Instance.new("UIStroke")
        UIStroke.Parent = MainContainer
        UIStroke.Color = Theme.CardBorder
        UIStroke.Thickness = 1.2
        self.WindowStroke = UIStroke

        -- Toast Notification Container (Bottom-Right)
        local NotificationContainer = Instance.new("Frame")
        NotificationContainer.Name = "NotificationContainer"
        NotificationContainer.Parent = Interface
        NotificationContainer.Size = UDim2.new(0, 270, 0, 360)
        NotificationContainer.Position = UDim2.new(1, -285, 1, -375)
        NotificationContainer.BackgroundTransparency = 1
        NotificationContainer.ClipsDescendants = false

        local notifyList = Instance.new("UIListLayout")
        notifyList.Parent = NotificationContainer
        notifyList.SortOrder = Enum.SortOrder.LayoutOrder
        notifyList.VerticalAlignment = Enum.VerticalAlignment.Bottom
        notifyList.Padding = UDim.new(0, 8)
        self.NotificationContainer = NotificationContainer

        -- =====================================================================
        -- 6A. HEADER BAR
        -- =====================================================================
        local Header = Instance.new("Frame")
        Header.Name = "Header"
        Header.Parent = MainContainer
        Header.Size = UDim2.new(1, 0, 0, 46)
        Header.BackgroundColor3 = Theme.Header
        Header.BorderSizePixel = 0
        Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

        -- Bottom square filler to merge header seamlessly with body
        local HeaderSquare = Instance.new("Frame")
        HeaderSquare.Parent = Header
        HeaderSquare.Size = UDim2.new(1, 0, 0, 10)
        HeaderSquare.Position = UDim2.new(0, 0, 1, -10)
        HeaderSquare.BackgroundColor3 = Theme.Header
        HeaderSquare.BorderSizePixel = 0

        local HeaderBorderLine = Instance.new("Frame")
        HeaderBorderLine.Parent = Header
        HeaderBorderLine.Size = UDim2.new(1, 0, 0, 1)
        HeaderBorderLine.Position = UDim2.new(0, 0, 1, 0)
        HeaderBorderLine.BackgroundColor3 = Theme.CardBorder
        HeaderBorderLine.BorderSizePixel = 0

        -- App Branding (Icon + Title + Pro Badge)
        local BrandIcon = Instance.new("TextLabel")
        BrandIcon.Parent = Header
        BrandIcon.Size = UDim2.new(0, 26, 1, 0)
        BrandIcon.Position = UDim2.new(0, 14, 0, 0)
        BrandIcon.BackgroundTransparency = 1
        BrandIcon.Font = Enum.Font.GothamBold
        BrandIcon.Text = "🍽️"
        BrandIcon.TextSize = 18

        local TitleLbl = Instance.new("TextLabel")
        TitleLbl.Parent = Header
        TitleLbl.Size = UDim2.new(0, 150, 1, 0)
        TitleLbl.Position = UDim2.new(0, 42, 0, 0)
        TitleLbl.BackgroundTransparency = 1
        TitleLbl.Font = Enum.Font.GothamBold
        TitleLbl.Text = titleText
        TitleLbl.TextColor3 = Theme.TextPrimary
        TitleLbl.TextSize = 13
        TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local ProBadge = Instance.new("Frame")
        ProBadge.Parent = Header
        ProBadge.Size = UDim2.new(0, 52, 0, 18)
        ProBadge.Position = UDim2.new(0, 196, 0.5, -9)
        ProBadge.BackgroundColor3 = Theme.Primary
        ProBadge.BackgroundTransparency = 0.8
        Instance.new("UICorner", ProBadge).CornerRadius = UDim.new(0, 4)

        local ProBadgeStroke = Instance.new("UIStroke")
        ProBadgeStroke.Parent = ProBadge
        ProBadgeStroke.Color = Theme.Primary
        ProBadgeStroke.Thickness = 1

        local ProBadgeLbl = Instance.new("TextLabel")
        ProBadgeLbl.Parent = ProBadge
        ProBadgeLbl.Size = UDim2.new(1, 0, 1, 0)
        ProBadgeLbl.BackgroundTransparency = 1
        ProBadgeLbl.Font = Enum.Font.GothamBold
        ProBadgeLbl.Text = "PRO v2.0"
        ProBadgeLbl.TextColor3 = Theme.Primary
        ProBadgeLbl.TextSize = 9

        -- Global Live Status Dot & Text
        local StatusPill = Instance.new("Frame")
        StatusPill.Parent = Header
        StatusPill.Size = UDim2.new(0, 68, 0, 20)
        StatusPill.Position = UDim2.new(0, 256, 0.5, -10)
        StatusPill.BackgroundColor3 = Theme.CardInner
        Instance.new("UICorner", StatusPill).CornerRadius = UDim.new(1, 0)

        local StatusDot = Instance.new("Frame")
        StatusDot.Parent = StatusPill
        StatusDot.Size = UDim2.new(0, 6, 0, 6)
        StatusDot.Position = UDim2.new(0, 8, 0.5, -3)
        StatusDot.BackgroundColor3 = Theme.TextMuted
        Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

        local StatusText = Instance.new("TextLabel")
        StatusText.Parent = StatusPill
        StatusText.Size = UDim2.new(1, -20, 1, 0)
        StatusText.Position = UDim2.new(0, 18, 0, 0)
        StatusText.BackgroundTransparency = 1
        StatusText.Font = Enum.Font.GothamBold
        StatusText.Text = "IDLE"
        StatusText.TextColor3 = Theme.TextSecondary
        StatusText.TextSize = 9
        StatusText.TextXAlignment = Enum.TextXAlignment.Left

        self.HeaderStatusDot = StatusDot
        self.HeaderStatusText = StatusText

        -- Header Search Bar (Instant Filter)
        local SearchBoxFrame = Instance.new("Frame")
        SearchBoxFrame.Parent = Header
        SearchBoxFrame.Size = UDim2.new(0, 130, 0, 26)
        SearchBoxFrame.Position = UDim2.new(1, -230, 0.5, -13)
        SearchBoxFrame.BackgroundColor3 = Theme.CardInner
        Instance.new("UICorner", SearchBoxFrame).CornerRadius = UDim.new(0, 6)

        local SearchStroke = Instance.new("UIStroke")
        SearchStroke.Parent = SearchBoxFrame
        SearchStroke.Color = Theme.CardBorder
        SearchStroke.Thickness = 1

        local SearchIcon = Instance.new("TextLabel")
        SearchIcon.Parent = SearchBoxFrame
        SearchIcon.Size = UDim2.new(0, 22, 1, 0)
        SearchIcon.Position = UDim2.new(0, 4, 0, 0)
        SearchIcon.BackgroundTransparency = 1
        SearchIcon.Font = Enum.Font.GothamBold
        SearchIcon.Text = "🔍"
        SearchIcon.TextSize = 11

        local SearchInput = Instance.new("TextBox")
        SearchInput.Parent = SearchBoxFrame
        SearchInput.Size = UDim2.new(1, -28, 1, 0)
        SearchInput.Position = UDim2.new(0, 26, 0, 0)
        SearchInput.BackgroundTransparency = 1
        SearchInput.Font = Enum.Font.GothamMedium
        SearchInput.PlaceholderText = "Search options..."
        SearchInput.PlaceholderColor3 = Theme.TextMuted
        SearchInput.Text = ""
        SearchInput.TextColor3 = Theme.TextPrimary
        SearchInput.TextSize = 11
        SearchInput.TextXAlignment = Enum.TextXAlignment.Left
        SearchInput.ClearTextOnFocus = false

        SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
            self:FilterCards(SearchInput.Text)
        end)

        -- Window Controls (Reset Pos, Minimize, Close)
        local ControlsGroup = Instance.new("Frame")
        ControlsGroup.Parent = Header
        ControlsGroup.Size = UDim2.new(0, 88, 0, 28)
        ControlsGroup.Position = UDim2.new(1, -94, 0.5, -14)
        ControlsGroup.BackgroundTransparency = 1

        local function makeHeaderBtn(icon, posX, colorHover, onClick)
            local btn = Instance.new("TextButton")
            btn.Parent = ControlsGroup
            btn.Size = UDim2.new(0, 26, 0, 26)
            btn.Position = UDim2.new(0, posX, 0, 1)
            btn.BackgroundColor3 = Theme.CardInner
            btn.Text = icon
            btn.TextColor3 = Theme.TextSecondary
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

            local bStroke = Instance.new("UIStroke")
            bStroke.Parent = btn
            bStroke.Color = Theme.CardBorder
            bStroke.Thickness = 1

            btn.MouseEnter:Connect(function()
                tween(btn, {BackgroundColor3 = colorHover, TextColor3 = Theme.TextPrimary}, 0.15)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundColor3 = Theme.CardInner, TextColor3 = Theme.TextSecondary}, 0.15)
            end)
            btn.Activated:Connect(onClick)
            return btn
        end

        -- 1. Center Window Button
        makeHeaderBtn("⟲", 0, Theme.CardHover, function()
            self:PlaySound("click")
            tween(MainContainer, {Position = UDim2.new(0.5, -MainContainer.AbsoluteSize.X * 0.5, 0.5, -MainContainer.AbsoluteSize.Y * 0.5)}, 0.3, Enum.EasingStyle.Back)
            self:Notify({Title = "Position Reset", Content = "Window centered on screen.", Type = "Info", Duration = 2})
        end)

        -- 2. Minimize Button
        makeHeaderBtn("—", 30, Color3.fromRGB(180, 130, 40), function()
            self:MinimizeToFloating()
        end)

        -- 3. Close / Unload Button
        makeHeaderBtn("✕", 60, Theme.Danger, function()
            self:PlaySound("click")
            Utility.Terminate()
        end)

        -- Header Dragging
        Header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainContainer.Position
            end
        end)

        -- =====================================================================
        -- 6B. BODY LAYOUT (Left Sidebar + Right Tab View)
        -- =====================================================================
        local Sidebar = Instance.new("Frame")
        Sidebar.Name = "Sidebar"
        Sidebar.Parent = MainContainer
        Sidebar.Size = UDim2.new(0, 142, 1, -47)
        Sidebar.Position = UDim2.new(0, 0, 0, 47)
        Sidebar.BackgroundColor3 = Theme.Sidebar
        Sidebar.BorderSizePixel = 0
        Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

        -- Right border hairline for sidebar
        local SidebarRightLine = Instance.new("Frame")
        SidebarRightLine.Parent = Sidebar
        SidebarRightLine.Size = UDim2.new(0, 1, 1, 0)
        SidebarRightLine.Position = UDim2.new(1, -1, 0, 0)
        SidebarRightLine.BackgroundColor3 = Theme.CardBorder
        SidebarRightLine.BorderSizePixel = 0

        local SidebarScroll = Instance.new("ScrollingFrame")
        SidebarScroll.Parent = Sidebar
        SidebarScroll.Size = UDim2.new(1, 0, 1, -10)
        SidebarScroll.Position = UDim2.new(0, 0, 0, 6)
        SidebarScroll.BackgroundTransparency = 1
        SidebarScroll.BorderSizePixel = 0
        SidebarScroll.ScrollBarThickness = 2
        SidebarScroll.ScrollBarImageColor3 = Theme.CardBorder
        SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

        local SidebarList = Instance.new("UIListLayout")
        SidebarList.Parent = SidebarScroll
        SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
        SidebarList.Padding = UDim.new(0, 4)
        SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, SidebarList.AbsoluteContentSize.Y + 12)
        end)
        self.SidebarScroll = SidebarScroll

        -- Active Tab Indicator (Sliding accent bar)
        local ActiveIndicator = Instance.new("Frame")
        ActiveIndicator.Parent = Sidebar
        ActiveIndicator.Size = UDim2.new(0, 3, 0, 22)
        ActiveIndicator.Position = UDim2.new(0, 0, 0, 12)
        ActiveIndicator.BackgroundColor3 = Theme.Primary
        ActiveIndicator.BorderSizePixel = 0
        Instance.new("UICorner", ActiveIndicator).CornerRadius = UDim.new(1, 0)
        self.ActiveIndicator = ActiveIndicator

        -- Right Content Viewport
        local ContentViewport = Instance.new("Frame")
        ContentViewport.Name = "ContentViewport"
        ContentViewport.Parent = MainContainer
        ContentViewport.Size = UDim2.new(1, -143, 1, -47)
        ContentViewport.Position = UDim2.new(0, 143, 0, 47)
        ContentViewport.BackgroundTransparency = 1
        ContentViewport.ClipsDescendants = true
        self.ContentViewport = ContentViewport

        -- Resize Handle (Bottom-Right)
        local ResizeHandle = Instance.new("TextButton")
        ResizeHandle.Parent = MainContainer
        ResizeHandle.Size = UDim2.new(0, 24, 0, 24)
        ResizeHandle.Position = UDim2.new(1, -24, 1, -24)
        ResizeHandle.BackgroundTransparency = 1
        ResizeHandle.Font = Enum.Font.GothamBold
        ResizeHandle.Text = "⋱"
        ResizeHandle.TextColor3 = Theme.TextMuted
        ResizeHandle.TextSize = 14
        ResizeHandle.ZIndex = 50

        ResizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeStart = input.Position
                sizeStart = MainContainer.AbsoluteSize
            end
        end)

        -- Theme changes reactive updates
        self:RegisterThemeListener(function(t)
            ProBadge.BackgroundColor3 = t.Primary
            ProBadgeStroke.Color = t.Primary
            ProBadgeLbl.TextColor3 = t.Primary
            ActiveIndicator.BackgroundColor3 = t.Primary
        end)

        self.Tabs = {}
        self.TabFrames = {}
        self.TabButtons = {}
        self.TabCards = {} -- For search indexing
        self.TabCount = 0
        self.ActiveTab = nil

        self:CreateFloatingWidget()
        self:InitInputDispatchers()

        local Window = { Library = self }
        function Window:AddTab(name, icon) return self.Library:CreateTab(name, icon) end
        function Window:SelectTab(name) self.Library:SelectTab(name) end
        function Window:Notify(options) self.Library:Notify(options) end
        function Window:SetTheme(name) self.Library:SetTheme(name) end
        function Window:UpdateStatus(isActive, text) self.Library:UpdateStatus(isActive, text) end

        return Window
    end

    -- =========================================================================
    -- 7. TAB MANAGEMENT (Left Sidebar Items & Scrolling Containers)
    -- =========================================================================
    function UILibrary:CreateTab(name, icon)
        self.TabCount = self.TabCount + 1
        local tabIndex = self.TabCount
        icon = icon or "📁"

        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. name
        btn.Parent = self.SidebarScroll
        btn.Size = UDim2.new(0.92, 0, 0, 36)
        btn.BackgroundColor3 = Theme.Sidebar
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel = 0
        btn.LayoutOrder = tabIndex
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local tabIcon = Instance.new("TextLabel")
        tabIcon.Parent = btn
        tabIcon.Size = UDim2.new(0, 24, 1, 0)
        tabIcon.Position = UDim2.new(0, 8, 0, 0)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Font = Enum.Font.GothamBold
        tabIcon.Text = icon
        tabIcon.TextSize = 14

        local tabTitle = Instance.new("TextLabel")
        tabTitle.Parent = btn
        tabTitle.Size = UDim2.new(1, -38, 1, 0)
        tabTitle.Position = UDim2.new(0, 36, 0, 0)
        tabTitle.BackgroundTransparency = 1
        tabTitle.Font = Enum.Font.GothamMedium
        tabTitle.Text = name
        tabTitle.TextColor3 = Theme.TextSecondary
        tabTitle.TextSize = 12
        tabTitle.TextXAlignment = Enum.TextXAlignment.Left

        -- Hover state
        btn.MouseEnter:Connect(function()
            if self.ActiveTab ~= name then
                tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = Theme.CardHover})
                tween(tabTitle, {TextColor3 = Theme.TextPrimary})
            end
        end)
        btn.MouseLeave:Connect(function()
            if self.ActiveTab ~= name then
                tween(btn, {BackgroundTransparency = 1})
                tween(tabTitle, {TextColor3 = Theme.TextSecondary})
            end
        end)

        btn.Activated:Connect(function()
            self:SelectTab(name)
        end)

        self.TabButtons[name] = { Button = btn, Title = tabTitle, Icon = tabIcon }

        -- Content Frame for Tab
        local frame = Instance.new("ScrollingFrame")
        frame.Name = "TabFrame_" .. name
        frame.Parent = self.ContentViewport
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ScrollBarThickness = 4
        frame.ScrollBarImageColor3 = Theme.CardBorder
        frame.CanvasSize = UDim2.new(0, 0, 0, 0)
        frame.Visible = false

        local UIList = Instance.new("UIListLayout")
        UIList.Parent = frame
        UIList.SortOrder = Enum.SortOrder.LayoutOrder
        UIList.Padding = UDim.new(0, 8)
        UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local UIPad = Instance.new("UIPadding")
        UIPad.Parent = frame
        UIPad.PaddingTop = UDim.new(0, 10)
        UIPad.PaddingBottom = UDim.new(0, 14)
        UIPad.PaddingLeft = UDim.new(0, 8)
        UIPad.PaddingRight = UDim.new(0, 8)

        UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            frame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 24)
        end)

        self.TabFrames[name] = frame
        self.TabCards[name] = {}

        if self.TabCount == 1 then
            task.defer(function() self:SelectTab(name) end)
        end

        local TabObj = { Frame = frame, Name = name, Library = self }

        function TabObj:AddHeroCard(data) return self.Library:CreateHeroCard(self.Frame, self.Name, data) end
        function TabObj:AddMetricGrid() return self.Library:CreateMetricGrid(self.Frame, self.Name) end
        function TabObj:AddSection(text, secIcon) return self.Library:CreateSection(self.Frame, self.Name, text, secIcon) end
        function TabObj:AddToggle(title, desc, default, cb) return self.Library:CreateToggle(self.Frame, self.Name, title, desc, default, cb) end
        function TabObj:AddSlider(title, desc, default, min, max, precision, suffix, cb) return self.Library:CreateSlider(self.Frame, self.Name, title, desc, default, min, max, precision, suffix, cb) end
        function TabObj:AddDropdown(title, desc, options, default, cb) return self.Library:CreateDropdown(self.Frame, self.Name, title, desc, options, default, cb) end
        function TabObj:AddKeybind(title, desc, defaultKey, cb) return self.Library:CreateKeybind(self.Frame, self.Name, title, desc, defaultKey, cb) end
        function TabObj:AddButton(title, desc, variant, cb) return self.Library:CreateButton(self.Frame, self.Name, title, desc, variant, cb) end
        function TabObj:AddParagraph(title, content) return self.Library:CreateParagraph(self.Frame, self.Name, title, content) end

        return TabObj
    end

    function UILibrary:SelectTab(name)
        if not self.TabFrames[name] then return end
        self:PlaySound("tab")
        self.ActiveTab = name

        for tName, data in pairs(self.TabButtons) do
            local isSelected = (tName == name)
            if isSelected then
                tween(data.Button, {BackgroundTransparency = 0, BackgroundColor3 = Theme.Card})
                tween(data.Title, {TextColor3 = Theme.Primary})
                local posY = data.Button.Position.Y.Offset + data.Button.AbsolutePosition.Y - self.SidebarScroll.AbsolutePosition.Y
                tween(self.ActiveIndicator, {Position = UDim2.new(0, 0, 0, data.Button.Position.Y.Offset + 7)}, 0.25, Enum.EasingStyle.Quart)
            else
                tween(data.Button, {BackgroundTransparency = 1})
                tween(data.Title, {TextColor3 = Theme.TextSecondary})
            end
        end

        for tName, frame in pairs(self.TabFrames) do
            if tName == name then
                frame.Visible = true
                frame.Position = UDim2.new(0, 8, 0, 0)
                tween(frame, {Position = UDim2.new(0, 0, 0, 0)}, 0.2, Enum.EasingStyle.Quad)
            else
                frame.Visible = false
            end
        end
    end

    function UILibrary:UpdateStatus(isActive, text)
        if self.HeaderStatusDot and self.HeaderStatusText then
            if isActive then
                self.HeaderStatusDot.BackgroundColor3 = Theme.Success
                self.HeaderStatusText.Text = text or "ACTIVE"
                self.HeaderStatusText.TextColor3 = Theme.Success
            else
                self.HeaderStatusDot.BackgroundColor3 = Theme.TextMuted
                self.HeaderStatusText.Text = text or "IDLE"
                self.HeaderStatusText.TextColor3 = Theme.TextSecondary
            end
        end
        self:UpdateFloatingStatus(isActive, text)
    end

    -- =========================================================================
    -- 8. SEARCH & FILTERING ENGINE
    -- =========================================================================
    function UILibrary:FilterCards(query)
        if not self.ActiveTab or not self.TabCards[self.ActiveTab] then return end
        query = query and query:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""

        for _, item in ipairs(self.TabCards[self.ActiveTab]) do
            if query == "" then
                item.Card.Visible = true
            else
                local match = (item.Title and item.Title:lower():find(query, 1, true)) or
                              (item.Desc and item.Desc:lower():find(query, 1, true))
                item.Card.Visible = match and true or false
            end
        end
    end

    local function NextOrder(parent)
        local c = 0
        for _, v in ipairs(parent:GetChildren()) do if v:IsA("GuiObject") then c = c + 1 end end
        return c
    end

    -- =========================================================================
    -- 9. COMPONENT SUITE
    -- =========================================================================

    -- 9A. HERO DASHBOARD MASTER CARD
    function UILibrary:CreateHeroCard(parent, tabName, data)
        data = data or {}
        local card = Instance.new("Frame")
        card.Name = "HeroCard"
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, 80)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Primary
        stroke.Thickness = 1.2

        local gradient = Instance.new("UIGradient")
        gradient.Parent = card
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Card),
            ColorSequenceKeypoint.new(1, Theme.CardHover)
        })
        gradient.Rotation = 45

        local icon = Instance.new("TextLabel")
        icon.Parent = card
        icon.Size = UDim2.new(0, 42, 0, 42)
        icon.Position = UDim2.new(0, 14, 0.5, -21)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.Text = data.Icon or "⚡"
        icon.TextSize = 26

        local title = Instance.new("TextLabel")
        title.Parent = card
        title.Size = UDim2.new(1, -160, 0, 20)
        title.Position = UDim2.new(0, 62, 0, 14)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = data.Title or "Master Auto-Farm"
        title.TextColor3 = Theme.TextPrimary
        title.TextSize = 15
        title.TextXAlignment = Enum.TextXAlignment.Left

        local sub = Instance.new("TextLabel")
        sub.Parent = card
        sub.Size = UDim2.new(1, -160, 0, 16)
        sub.Position = UDim2.new(0, 62, 0, 36)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.GothamMedium
        sub.Text = data.Subtitle or "Synchronizes all seating, cooking, serving, and cash automation."
        sub.TextColor3 = Theme.TextSecondary
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left

        local extraInfo = Instance.new("TextLabel")
        extraInfo.Parent = card
        extraInfo.Size = UDim2.new(1, -160, 0, 14)
        extraInfo.Position = UDim2.new(0, 62, 0, 54)
        extraInfo.BackgroundTransparency = 1
        extraInfo.Font = Enum.Font.GothamBold
        extraInfo.Text = "⏱ Uptime: 00:00:00  •  Rate: +$0 / hr"
        extraInfo.TextColor3 = Theme.Primary
        extraInfo.TextSize = 10
        extraInfo.TextXAlignment = Enum.TextXAlignment.Left

        -- Master Toggle Switch
        local switchTrack = Instance.new("Frame")
        switchTrack.Parent = card
        switchTrack.Size = UDim2.new(0, 48, 0, 26)
        switchTrack.Position = UDim2.new(1, -64, 0.5, -13)
        switchTrack.BackgroundColor3 = data.InitialState and Theme.Success or Theme.CardInner
        Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

        local switchKnob = Instance.new("Frame")
        switchKnob.Parent = switchTrack
        switchKnob.Size = UDim2.new(0, 20, 0, 20)
        switchKnob.Position = data.InitialState and UDim2.new(0, 24, 0.5, -10) or UDim2.new(0, 4, 0.5, -10)
        switchKnob.BackgroundColor3 = Color3.fromRGB(250, 252, 255)
        Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

        local switchBtn = Instance.new("TextButton")
        switchBtn.Parent = switchTrack
        switchBtn.Size = UDim2.new(1, 0, 1, 0)
        switchBtn.BackgroundTransparency = 1
        switchBtn.Text = ""

        local isToggled = data.InitialState or false
        local function setHeroState(state)
            isToggled = state
            tween(switchTrack, {BackgroundColor3 = state and Theme.Success or Theme.CardInner}, 0.2)
            tween(switchKnob, {Position = state and UDim2.new(0, 24, 0.5, -10) or UDim2.new(0, 4, 0.5, -10)}, 0.2, Enum.EasingStyle.Quad)
            if data.OnToggle then data.OnToggle(state) end
        end

        switchBtn.Activated:Connect(function()
            self:PlaySound("toggle")
            setHeroState(not isToggled)
        end)

        self:RegisterThemeListener(function(t)
            stroke.Color = t.Primary
            extraInfo.TextColor3 = t.Primary
        end)

        return {
            Card = card,
            SetState = setHeroState,
            SetInfo = function(text) extraInfo.Text = text end
        }
    end

    -- 9B. LIVE METRIC TILES GRID
    function UILibrary:CreateMetricGrid(parent, tabName)
        local gridFrame = Instance.new("Frame")
        gridFrame.Name = "MetricGrid"
        gridFrame.Parent = parent
        gridFrame.Size = UDim2.new(0.96, 0, 0, 0)
        gridFrame.BackgroundTransparency = 1
        gridFrame.LayoutOrder = NextOrder(parent)

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.Parent = gridFrame
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.CellSize = UDim2.new(0.485, 0, 0, 58)
        gridLayout.CellPadding = UDim2.new(0.03, 0, 0, 8)

        gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            gridFrame.Size = UDim2.new(0.96, 0, 0, gridLayout.AbsoluteContentSize.Y)
        end)

        local metrics = {}
        local gridObj = { Frame = gridFrame }

        function gridObj:AddMetric(id, icon, titleText, initialVal, accentColor)
            accentColor = accentColor or Theme.Primary

            local tile = Instance.new("Frame")
            tile.Name = "Metric_" .. id
            tile.Parent = gridFrame
            tile.BackgroundColor3 = Theme.Card
            tile.BorderSizePixel = 0
            Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 8)

            local stroke = Instance.new("UIStroke")
            stroke.Parent = tile
            stroke.Color = Theme.CardBorder
            stroke.Thickness = 1

            local iconBox = Instance.new("Frame")
            iconBox.Parent = tile
            iconBox.Size = UDim2.new(0, 34, 0, 34)
            iconBox.Position = UDim2.new(0, 10, 0.5, -17)
            iconBox.BackgroundColor3 = accentColor
            iconBox.BackgroundTransparency = 0.85
            Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 6)

            local iconLbl = Instance.new("TextLabel")
            iconLbl.Parent = iconBox
            iconLbl.Size = UDim2.new(1, 0, 1, 0)
            iconLbl.BackgroundTransparency = 1
            iconLbl.Font = Enum.Font.GothamBold
            iconLbl.Text = icon
            iconLbl.TextSize = 16

            local tLbl = Instance.new("TextLabel")
            tLbl.Parent = tile
            tLbl.Size = UDim2.new(1, -54, 0, 16)
            tLbl.Position = UDim2.new(0, 50, 0, 8)
            tLbl.BackgroundTransparency = 1
            tLbl.Font = Enum.Font.GothamMedium
            tLbl.Text = titleText
            tLbl.TextColor3 = Theme.TextSecondary
            tLbl.TextSize = 10
            tLbl.TextXAlignment = Enum.TextXAlignment.Left

            local vLbl = Instance.new("TextLabel")
            vLbl.Parent = tile
            vLbl.Size = UDim2.new(1, -54, 0, 24)
            vLbl.Position = UDim2.new(0, 50, 0, 24)
            vLbl.BackgroundTransparency = 1
            vLbl.Font = Enum.Font.GothamBold
            vLbl.Text = tostring(initialVal or 0)
            vLbl.TextColor3 = Theme.TextPrimary
            vLbl.TextSize = 15
            vLbl.TextXAlignment = Enum.TextXAlignment.Left

            metrics[id] = { ValueLabel = vLbl, Tile = tile }

            tile.MouseEnter:Connect(function()
                tween(tile, {BackgroundColor3 = Theme.CardHover})
                tween(stroke, {Color = accentColor})
            end)
            tile.MouseLeave:Connect(function()
                tween(tile, {BackgroundColor3 = Theme.Card})
                tween(stroke, {Color = Theme.CardBorder})
            end)
        end

        function gridObj:UpdateMetric(id, newVal)
            if metrics[id] then
                metrics[id].ValueLabel.Text = tostring(newVal)
            end
        end

        return gridObj
    end

    -- 9C. SECTION DIVIDER
    function UILibrary:CreateSection(parent, tabName, text, icon)
        icon = icon or "◆"
        local secFrame = Instance.new("Frame")
        secFrame.Name = "Section_" .. text
        secFrame.Parent = parent
        secFrame.Size = UDim2.new(0.96, 0, 0, 28)
        secFrame.BackgroundTransparency = 1
        secFrame.LayoutOrder = NextOrder(parent)

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Parent = secFrame
        iconLbl.Size = UDim2.new(0, 16, 1, 0)
        iconLbl.Position = UDim2.new(0, 2, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Text = icon
        iconLbl.TextColor3 = Theme.Primary
        iconLbl.TextSize = 11

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = secFrame
        titleLbl.Size = UDim2.new(0, 200, 1, 0)
        titleLbl.Position = UDim2.new(0, 20, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = text:upper()
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 11
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local dividerLine = Instance.new("Frame")
        dividerLine.Parent = secFrame
        dividerLine.Size = UDim2.new(1, -225, 0, 1)
        dividerLine.Position = UDim2.new(0, 225, 0.5, 0)
        dividerLine.BackgroundColor3 = Theme.CardBorder
        dividerLine.BorderSizePixel = 0

        self:RegisterThemeListener(function(t)
            iconLbl.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = secFrame, Title = text, Desc = "" })
        return secFrame
    end

    -- 9D. MODERN TOGGLE WITH SUBTEXT
    function UILibrary:CreateToggle(parent, tabName, titleText, descText, initialState, callback)
        local hasDesc = descText and #descText > 0
        local cardHeight = hasDesc and 48 or 38

        local card = Instance.new("Frame")
        card.Name = "Toggle_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, cardHeight)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(1, -70, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -70, 0, 16)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local track = Instance.new("Frame")
        track.Parent = card
        track.Size = UDim2.new(0, 42, 0, 22)
        track.Position = UDim2.new(1, -54, 0.5, -11)
        track.BackgroundColor3 = initialState and Theme.Success or Theme.CardInner
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Parent = track
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initialState and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(245, 247, 252)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""

        local isToggled = initialState or false
        local function updateToggle(state)
            isToggled = state
            tween(track, {BackgroundColor3 = state and Theme.Success or Theme.CardInner}, 0.2)
            tween(knob, {Position = state and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, 0.2, Enum.EasingStyle.Quad)
        end

        btn.MouseEnter:Connect(function()
            tween(card, {BackgroundColor3 = Theme.CardHover})
        end)
        btn.MouseLeave:Connect(function()
            tween(card, {BackgroundColor3 = Theme.Card})
        end)

        btn.Activated:Connect(function()
            self:PlaySound("toggle")
            isToggled = not isToggled
            updateToggle(isToggled)
            if callback then callback(isToggled) end
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })

        return {
            Card = card,
            SetState = function(selfObj, val)
                updateToggle(val)
            end
        }
    end

    -- 9E. MODERN SLIDER WITH INTERACTIVE TEXT INPUT BADGE
    function UILibrary:CreateSlider(parent, tabName, titleText, descText, default, min, max, precision, suffix, callback)
        min = min or 0
        max = max or 100
        precision = precision or 0
        suffix = suffix or ""
        default = math.clamp(default or min, min, max)

        sliderIdCounter = sliderIdCounter + 1
        local sliderId = sliderIdCounter

        local hasDesc = descText and #descText > 0
        local cardHeight = hasDesc and 58 or 48

        local card = Instance.new("Frame")
        card.Name = "Slider_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, cardHeight)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(0.65, 0, 0, 18)
        titleLbl.Position = UDim2.new(0, 12, 0, 5)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(0.65, 0, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 21)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        -- Numeric Editable Input Badge
        local badge = Instance.new("Frame")
        badge.Parent = card
        badge.Size = UDim2.new(0, 60, 0, 20)
        badge.Position = UDim2.new(1, -72, 0, 6)
        badge.BackgroundColor3 = Theme.CardInner
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)

        local bStroke = Instance.new("UIStroke")
        bStroke.Parent = badge
        bStroke.Color = Theme.CardBorder
        bStroke.Thickness = 1

        local valBox = Instance.new("TextBox")
        valBox.Parent = badge
        valBox.Size = UDim2.new(1, 0, 1, 0)
        valBox.BackgroundTransparency = 1
        valBox.Font = Enum.Font.GothamBold
        valBox.Text = tostring(default) .. suffix
        valBox.TextColor3 = Theme.Primary
        valBox.TextSize = 11
        valBox.ClearTextOnFocus = false

        -- Draggable Slider Track
        local track = Instance.new("TextButton")
        track.Parent = card
        track.Size = UDim2.new(1, -24, 0, 6)
        track.Position = UDim2.new(0, 12, 1, -12)
        track.BackgroundColor3 = Theme.CardInner
        track.Text = ""
        track.AutoButtonColor = false
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Parent = track
        fill.Size = UDim2.new((default - min) / math.max(1, max - min), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Primary
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local currentVal = default
        local function setSliderVal(newVal, fireCb)
            newVal = math.clamp(newVal, min, max)
            if precision == 0 then
                newVal = math.floor(newVal + 0.5)
            else
                local mult = 10 ^ precision
                newVal = math.floor(newVal * mult + 0.5) / mult
            end
            currentVal = newVal
            local pct = (newVal - min) / math.max(1, max - min)
            tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
            valBox.Text = tostring(newVal) .. suffix
            if fireCb and callback then callback(newVal) end
        end

        local function updateFromInput(input)
            local width = math.max(1, track.AbsoluteSize.X)
            local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, width)
            local pct = posX / width
            local rawVal = min + (max - min) * pct
            setSliderVal(rawVal, true)
        end

        sliderCallbacks[sliderId] = updateFromInput

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeSliderId = sliderId
                updateFromInput(input)
            end
        end)

        valBox.FocusLost:Connect(function()
            local num = tonumber(valBox.Text:gsub("[^%d.-]", ""))
            if num then
                setSliderVal(num, true)
            else
                valBox.Text = tostring(currentVal) .. suffix
            end
        end)

        self:RegisterThemeListener(function(t)
            fill.BackgroundColor3 = t.Primary
            valBox.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })

        return {
            Card = card,
            SetValue = function(selfObj, v) setSliderVal(v, false) end
        }
    end

    -- 9F. MODERN SELECT DROPDOWN
    function UILibrary:CreateDropdown(parent, tabName, titleText, descText, options, default, callback)
        options = options or {}
        default = default or options[1] or ""
        local hasDesc = descText and #descText > 0

        local card = Instance.new("Frame")
        card.Name = "Dropdown_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, hasDesc and 48 or 40)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        card.ClipsDescendants = true
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(0.5, 0, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(0.5, 0, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local selectBtn = Instance.new("TextButton")
        selectBtn.Parent = card
        selectBtn.Size = UDim2.new(0, 120, 0, 26)
        selectBtn.Position = UDim2.new(1, -132, 0, hasDesc and 11 or 7)
        selectBtn.BackgroundColor3 = Theme.CardInner
        selectBtn.Font = Enum.Font.GothamBold
        selectBtn.Text = default .. " ▼"
        selectBtn.TextColor3 = Theme.Primary
        selectBtn.TextSize = 11
        Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 6)

        local sStroke = Instance.new("UIStroke")
        sStroke.Parent = selectBtn
        sStroke.Color = Theme.CardBorder
        sStroke.Thickness = 1

        -- Options Dropdown Box (Collapsible Frame)
        local optionsFrame = Instance.new("Frame")
        optionsFrame.Parent = card
        optionsFrame.Size = UDim2.new(1, -24, 0, #options * 26 + 6)
        optionsFrame.Position = UDim2.new(0, 12, 0, hasDesc and 52 or 44)
        optionsFrame.BackgroundColor3 = Theme.CardInner
        optionsFrame.BorderSizePixel = 0
        Instance.new("UICorner", optionsFrame).CornerRadius = UDim.new(0, 6)

        local oList = Instance.new("UIListLayout")
        oList.Parent = optionsFrame
        oList.SortOrder = Enum.SortOrder.LayoutOrder
        oList.Padding = UDim.new(0, 2)

        local isExpanded = false
        local function toggleDropdown()
            isExpanded = not isExpanded
            selectBtn.Text = default .. (isExpanded and " ▲" or " ▼")
            local targetH = isExpanded and ((hasDesc and 56 or 48) + #options * 28) or (hasDesc and 48 or 40)
            tween(card, {Size = UDim2.new(0.96, 0, 0, targetH)}, 0.25, Enum.EasingStyle.Quart)
        end

        selectBtn.Activated:Connect(function()
            self:PlaySound("click")
            toggleDropdown()
        end)

        for i, opt in ipairs(options) do
            local oBtn = Instance.new("TextButton")
            oBtn.Parent = optionsFrame
            oBtn.Size = UDim2.new(1, 0, 0, 24)
            oBtn.BackgroundTransparency = 1
            oBtn.Font = Enum.Font.GothamMedium
            oBtn.Text = "   " .. opt
            oBtn.TextColor3 = (opt == default) and Theme.Primary or Theme.TextSecondary
            oBtn.TextSize = 11
            oBtn.TextXAlignment = Enum.TextXAlignment.Left

            oBtn.MouseEnter:Connect(function()
                tween(oBtn, {BackgroundTransparency = 0, BackgroundColor3 = Theme.CardHover})
            end)
            oBtn.MouseLeave:Connect(function()
                tween(oBtn, {BackgroundTransparency = 1})
            end)

            oBtn.Activated:Connect(function()
                self:PlaySound("click")
                default = opt
                toggleDropdown()
                for _, child in ipairs(optionsFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.TextColor3 = (child.Text:find(opt, 1, true)) and Theme.Primary or Theme.TextSecondary
                    end
                end
                if callback then callback(opt) end
            end)
        end

        self:RegisterThemeListener(function(t)
            selectBtn.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })

        return { Card = card }
    end

    -- 9G. MODERN KEYBIND CHIP
    function UILibrary:CreateKeybind(parent, tabName, titleText, descText, defaultKey, callback)
        local hasDesc = descText and #descText > 0
        local card = Instance.new("Frame")
        card.Name = "Keybind_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, hasDesc and 48 or 38)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(1, -110, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -110, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(0, 84, 0, 24)
        btn.Position = UDim2.new(1, -96, 0.5, -12)
        btn.BackgroundColor3 = Theme.CardInner
        btn.Font = Enum.Font.GothamBold
        btn.Text = (defaultKey and defaultKey.Name) or "None"
        btn.TextColor3 = Theme.Primary
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local bStroke = Instance.new("UIStroke")
        bStroke.Parent = btn
        bStroke.Color = Theme.CardBorder
        bStroke.Thickness = 1

        btn.Activated:Connect(function()
            self:PlaySound("click")
            if activeKeybindBtn then
                activeKeybindBtn.Text = "None"
                tween(activeKeybindBtn, {BackgroundColor3 = Theme.CardInner})
            end
            activeKeybindBtn = btn
            activeKeybindCb = callback
            btn.Text = "Press Key..."
            tween(btn, {BackgroundColor3 = Theme.PrimaryDark})
        end)

        self:RegisterThemeListener(function(t)
            btn.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })
        return { Card = card }
    end

    -- 9H. MODERN BUTTON
    function UILibrary:CreateButton(parent, tabName, titleText, descText, variant, onClick)
        variant = variant or "Secondary" -- "Primary", "Secondary", "Danger"
        local hasDesc = descText and #descText > 0
        local card = Instance.new("Frame")
        card.Name = "Button_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, hasDesc and 48 or 36)
        card.BackgroundColor3 = (variant == "Primary") and Theme.Primary or Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = (variant == "Danger") and Theme.Danger or Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(1, -24, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = (variant == "Danger") and Theme.Danger or Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = hasDesc and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -24, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""

        btn.MouseEnter:Connect(function()
            if variant == "Primary" then
                tween(card, {BackgroundColor3 = Theme.PrimaryGradient})
            elseif variant == "Danger" then
                tween(card, {BackgroundColor3 = Color3.fromRGB(60, 20, 24)})
            else
                tween(card, {BackgroundColor3 = Theme.CardHover})
            end
        end)
        btn.MouseLeave:Connect(function()
            if variant == "Primary" then
                tween(card, {BackgroundColor3 = Theme.Primary})
            elseif variant == "Danger" then
                tween(card, {BackgroundColor3 = Theme.Card})
            else
                tween(card, {BackgroundColor3 = Theme.Card})
            end
        end)

        btn.Activated:Connect(function()
            self:PlaySound("click")
            if onClick then onClick(titleLbl) end
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })
        return {
            Card = card,
            SetText = function(selfObj, text) titleLbl.Text = text end
        }
    end

    -- 9I. MODERN PARAGRAPH CARD
    function UILibrary:CreateParagraph(parent, tabName, titleText, content)
        local card = Instance.new("Frame")
        card.Name = "Paragraph_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, 56)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local tLbl = Instance.new("TextLabel")
        tLbl.Parent = card
        tLbl.Size = UDim2.new(1, -24, 0, 18)
        tLbl.Position = UDim2.new(0, 12, 0, 6)
        tLbl.BackgroundTransparency = 1
        tLbl.Font = Enum.Font.GothamBold
        tLbl.Text = titleText
        tLbl.TextColor3 = Theme.TextPrimary
        tLbl.TextSize = 12
        tLbl.TextXAlignment = Enum.TextXAlignment.Left

        local cLbl = Instance.new("TextLabel")
        cLbl.Parent = card
        cLbl.Size = UDim2.new(1, -24, 0, 26)
        cLbl.Position = UDim2.new(0, 12, 0, 24)
        cLbl.BackgroundTransparency = 1
        cLbl.Font = Enum.Font.GothamMedium
        cLbl.Text = content
        cLbl.TextColor3 = Theme.TextSecondary
        cLbl.TextSize = 10
        cLbl.TextWrapped = true
        cLbl.TextXAlignment = Enum.TextXAlignment.Left
        cLbl.TextYAlignment = Enum.TextYAlignment.Top

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = content })

        return {
            Card = card,
            SetContent = function(selfObj, newContent) cLbl.Text = newContent end
        }
    end

    return UILibrary
end
