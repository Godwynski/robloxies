-- analyzer/modules/UI.lua
-- Glassmorphic In-Game Diagnostic Dashboard for LuauLens

local Utility = require("analyzer.modules.Utility")
local Serializer = require("analyzer.modules.Serializer")

local UI = {}

local Services = {
    CoreGui = game:GetService("CoreGui"),
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
}

local Theme = {
    Background = Color3.fromRGB(13, 16, 23),
    Sidebar = Color3.fromRGB(18, 22, 32),
    CardBg = Color3.fromRGB(24, 29, 42),
    CardHover = Color3.fromRGB(32, 38, 56),
    Stroke = Color3.fromRGB(45, 52, 75),
    Accent = Color3.fromRGB(99, 102, 241),      -- Modern Indigo
    AccentHover = Color3.fromRGB(129, 140, 248),
    Success = Color3.fromRGB(34, 197, 94),      -- Green
    Warning = Color3.fromRGB(245, 158, 11),     -- Amber
    Text = Color3.fromRGB(241, 245, 249),
    TextMuted = Color3.fromRGB(148, 163, 184),
    CodeBg = Color3.fromRGB(10, 12, 18),
}

local screenGui = nil
local mainFrame = nil
local activeTab = "Overview"
local tabButtons = {}
local tabContainers = {}
local isVisible = true

local codeAnalysisData = nil
local livePackets = {}
local activePacketFilter = ""
local activeScriptFilter = ""

-- Create rounded corner
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

-- Create subtle stroke border
local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Stroke
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

-- Make a frame draggable
local function makeDraggable(dragHandle, targetFrame)
    local dragging, dragStart, startPos = false, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
        end
    end)

    Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Switch active tab
function UI.SelectTab(tabName)
    activeTab = tabName
    for name, btn in pairs(tabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Theme.Accent
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Theme.Sidebar
            btn.TextColor3 = Theme.TextMuted
        end
    end

    for name, container in pairs(tabContainers) do
        container.Visible = (name == tabName)
    end
end

-- Toggle GUI visibility
function UI.Toggle()
    isVisible = not isVisible
    if mainFrame then
        mainFrame.Visible = isVisible
    end
end

-- Build the UI layout
function UI.Init(analyzerCore)
    local env = Utility.GetEnvironment()
    local parentGui = nil
    if env.HasGetHui then
        parentGui = gethui()
    else
        pcall(function() parentGui = Services.CoreGui end)
        if not parentGui then
            local localPlayer = Services.Players.LocalPlayer
            parentGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
        end
    end

    if not parentGui then return end

    -- Clean old instances
    for _, child in ipairs(parentGui:GetChildren()) do
        if child.Name == "LuauLensAnalyzer" then
            pcall(function() child:Destroy() end)
        end
    end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LuauLensAnalyzer"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parentGui

    -- Main Container (Width: 860, Height: 540)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 860, 0, 540)
    mainFrame.Position = UDim2.new(0.5, -430, 0.5, -270)
    mainFrame.BackgroundColor3 = Theme.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    addCorner(mainFrame, 10)
    addStroke(mainFrame, Theme.Stroke, 1.5)
    mainFrame.Parent = screenGui

    -- Top Header Bar
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Theme.Sidebar
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    makeDraggable(header, mainFrame)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 300, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Theme.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🔍 LuauLens — Educational Game Architecture Analyzer"
    title.Parent = header

    -- Close / Hide Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "✕"
    addCorner(closeBtn, 6)
    closeBtn.Parent = header
    closeBtn.MouseButton1Click:Connect(function()
        UI.Toggle()
    end)

    -- Status Subtitle
    local envTag = Instance.new("TextLabel")
    envTag.Size = UDim2.new(0, 120, 0, 20)
    envTag.Position = UDim2.new(1, -170, 0.5, -10)
    envTag.BackgroundColor3 = Theme.CardBg
    envTag.Font = Enum.Font.GothamMedium
    envTag.TextSize = 11
    envTag.TextColor3 = Theme.AccentHover
    envTag.Text = env.IsStudio and "Roblox Studio" or "Runtime Client"
    addCorner(envTag, 4)
    addStroke(envTag, Theme.Stroke, 1)
    envTag.Parent = header

    -- Tab Navigation Bar
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, 0, 0, 36)
    tabBar.Position = UDim2.new(0, 0, 0, 44)
    tabBar.BackgroundColor3 = Theme.Sidebar
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 12)
    tabPadding.Parent = tabBar

    -- Content Body
    local contentBody = Instance.new("Frame")
    contentBody.Name = "ContentBody"
    contentBody.Size = UDim2.new(1, 0, 1, -80)
    contentBody.Position = UDim2.new(0, 0, 0, 80)
    contentBody.BackgroundTransparency = 1
    contentBody.Parent = mainFrame

    -- Tabs Definition
    local tabs = {
        { Id = "Overview", Name = "📊 Overview" },
        { Id = "Code", Name = "📜 Code & Systems" },
        { Id = "Network", Name = "📡 Network Sniffer" },
        { Id = "Tracker", Name = "🔄 Content Tracker" },
        { Id = "Docs", Name = "📚 Educational Docs" },
    }

    for _, t in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. t.Id
        btn.Size = UDim2.new(0, 150, 0, 28)
        btn.BackgroundColor3 = Theme.Sidebar
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.TextColor3 = Theme.TextMuted
        btn.Text = t.Name
        addCorner(btn, 6)
        btn.Parent = tabBar
        tabButtons[t.Id] = btn

        local container = Instance.new("Frame")
        container.Name = "Container_" .. t.Id
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1
        container.Visible = false
        container.Parent = contentBody
        tabContainers[t.Id] = container

        btn.MouseButton1Click:Connect(function()
            UI.SelectTab(t.Id)
        end)
    end

    -- ==========================================
    -- TAB 1: OVERVIEW
    -- ==========================================
    local ov = tabContainers["Overview"]
    local ovPadding = Instance.new("UIPadding")
    ovPadding.PaddingTop = UDim.new(0, 14)
    ovPadding.PaddingLeft = UDim.new(0, 16)
    ovPadding.PaddingRight = UDim.new(0, 16)
    ovPadding.Parent = ov

    local ovGrid = Instance.new("Frame")
    ovGrid.Size = UDim2.new(1, 0, 0, 180)
    ovGrid.BackgroundTransparency = 1
    ovGrid.Parent = ov

    -- Metric Cards
    local metrics = {
        { Id = "Card_Scripts", Title = "Client Scripts", Value = "0", Sub = "LocalScripts & Modules" },
        { Id = "Card_Remotes", Title = "Network Remotes", Value = "0", Sub = "RemoteEvents & Functions" },
        { Id = "Card_Tags", Title = "Component Tags", Value = "0", Sub = "CollectionService Tags" },
        { Id = "Card_Framework", Title = "Detected Framework", Value = "Scanning...", Sub = "Architecture Pattern" },
        { Id = "Card_Memory", Title = "Memory Usage", Value = "0 MB", Sub = "Client Engine Footprint" },
        { Id = "Card_Packets", Title = "Live Packets", Value = "0", Sub = "Intercepted Traffic" },
    }

    local cardLabels = {}
    for i, m in ipairs(metrics) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.315, 0, 0, 80)
        card.Position = UDim2.new(col * 0.342, 0, row * 90, 0)
        card.BackgroundColor3 = Theme.CardBg
        addCorner(card, 8)
        addStroke(card, Theme.Stroke, 1)
        card.Parent = ovGrid

        local cTitle = Instance.new("TextLabel")
        cTitle.Size = UDim2.new(1, -16, 0, 16)
        cTitle.Position = UDim2.new(0, 10, 0, 8)
        cTitle.BackgroundTransparency = 1
        cTitle.Font = Enum.Font.Gotham
        cTitle.TextSize = 11
        cTitle.TextColor3 = Theme.TextMuted
        cTitle.TextXAlignment = Enum.TextXAlignment.Left
        cTitle.Text = m.Title
        cTitle.Parent = card

        local cVal = Instance.new("TextLabel")
        cVal.Size = UDim2.new(1, -16, 0, 28)
        cVal.Position = UDim2.new(0, 10, 0, 24)
        cVal.BackgroundTransparency = 1
        cVal.Font = Enum.Font.GothamBold
        cVal.TextSize = 18
        cVal.TextColor3 = Theme.Text
        cVal.TextXAlignment = Enum.TextXAlignment.Left
        cVal.Text = m.Value
        cVal.Parent = card
        cardLabels[m.Id] = cVal

        local cSub = Instance.new("TextLabel")
        cSub.Size = UDim2.new(1, -16, 0, 14)
        cSub.Position = UDim2.new(0, 10, 0, 54)
        cSub.BackgroundTransparency = 1
        cSub.Font = Enum.Font.Gotham
        cSub.TextSize = 10
        cSub.TextColor3 = Theme.AccentHover
        cSub.TextXAlignment = Enum.TextXAlignment.Left
        cSub.Text = m.Sub
        cSub.Parent = card
    end

    -- Quick Action Banner
    local actionBanner = Instance.new("Frame")
    actionBanner.Size = UDim2.new(1, 0, 0, 220)
    actionBanner.Position = UDim2.new(0, 0, 0, 200)
    actionBanner.BackgroundColor3 = Theme.CardBg
    addCorner(actionBanner, 8)
    addStroke(actionBanner, Theme.Stroke, 1)
    actionBanner.Parent = ov

    local actionTitle = Instance.new("TextLabel")
    actionTitle.Size = UDim2.new(1, -20, 0, 24)
    actionTitle.Position = UDim2.new(0, 14, 0, 10)
    actionTitle.BackgroundTransparency = 1
    actionTitle.Font = Enum.Font.GothamBold
    actionTitle.TextSize = 14
    actionTitle.TextColor3 = Theme.Text
    actionTitle.TextXAlignment = Enum.TextXAlignment.Left
    actionTitle.Text = "⚡ Quick Actions & Analysis Controls"
    actionTitle.Parent = actionBanner

    local function createActionButton(name, pos, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 180, 0, 36)
        btn.Position = pos
        btn.BackgroundColor3 = Theme.CardHover
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextColor3 = Theme.Text
        btn.Text = name
        addCorner(btn, 6)
        addStroke(btn, Theme.Accent, 1)
        btn.Parent = actionBanner
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    createActionButton("🔍 Run Code Analysis", UDim2.new(0, 14, 0, 48), function()
        if analyzerCore and analyzerCore.CodeAnalyzer then
            codeAnalysisData = analyzerCore.CodeAnalyzer.RunAnalysis()
            cardLabels["Card_Scripts"].Text = tostring(codeAnalysisData.TotalScripts)
            cardLabels["Card_Tags"].Text = tostring(#codeAnalysisData.Tags)
            if codeAnalysisData.Frameworks[1] then
                cardLabels["Card_Framework"].Text = codeAnalysisData.Frameworks[1].Name
            end
            UI.RefreshCodeList()
        end
    end)

    createActionButton("📸 Take Snapshot", UDim2.new(0, 206, 0, 48), function()
        if analyzerCore and analyzerCore.ContentTracker then
            local snap = analyzerCore.ContentTracker.TakeSnapshot()
            cardLabels["Card_Remotes"].Text = tostring(snap.Counts.Remotes)
        end
    end)

    createActionButton("📝 Generate Full Report", UDim2.new(0, 398, 0, 48), function()
        UI.SelectTab("Docs")
        UI.GenerateReportDoc()
    end)

    local statusNote = Instance.new("TextLabel")
    statusNote.Size = UDim2.new(1, -28, 0, 100)
    statusNote.Position = UDim2.new(0, 14, 0, 100)
    statusNote.BackgroundColor3 = Theme.CodeBg
    statusNote.Font = Enum.Font.Code
    statusNote.TextSize = 11
    statusNote.TextColor3 = Theme.TextMuted
    statusNote.TextXAlignment = Enum.TextXAlignment.Left
    statusNote.TextYAlignment = Enum.TextYAlignment.Top
    statusNote.Text = [[
Welcome to LuauLens Architecture & Mechanics Analyzer.
• Hotkey F4 or RightControl to toggle this interface.
• Code & Systems: Inspect client script decomposition, frameworks, and CollectionService tags.
• Network Sniffer: Inspect real-time RemoteEvent & RemoteFunction payloads with argument typing.
• Content Tracker: Capture snapshots and generate automated game mechanics changelogs.
• Educational Docs: Export comprehensive Markdown architecture specs and Mermaid diagrams.]]
    addCorner(statusNote, 6)
    local snPad = Instance.new("UIPadding")
    snPad.PaddingTop = UDim.new(0, 8)
    snPad.PaddingLeft = UDim.new(0, 10)
    snPad.Parent = statusNote
    statusNote.Parent = actionBanner

    -- ==========================================
    -- TAB 2: CODE & SYSTEMS
    -- ==========================================
    local codeTab = tabContainers["Code"]
    local ctPad = Instance.new("UIPadding")
    ctPad.PaddingTop = UDim.new(0, 10)
    ctPad.PaddingLeft = UDim.new(0, 14)
    ctPad.PaddingRight = UDim.new(0, 14)
    ctPad.Parent = codeTab

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, 0, 0, 32)
    searchBox.BackgroundColor3 = Theme.CardBg
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12
    searchBox.TextColor3 = Theme.Text
    searchBox.PlaceholderText = "🔎 Filter scripts by name, category, or service..."
    searchBox.PlaceholderColor3 = Theme.TextMuted
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    addCorner(searchBox, 6)
    addStroke(searchBox, Theme.Stroke, 1)
    local sbPad = Instance.new("UIPadding")
    sbPad.PaddingLeft = UDim.new(0, 10)
    sbPad.Parent = searchBox
    searchBox.Parent = codeTab

    local codeScroll = Instance.new("ScrollingFrame")
    codeScroll.Size = UDim2.new(1, 0, 1, -48)
    codeScroll.Position = UDim2.new(0, 0, 0, 42)
    codeScroll.BackgroundColor3 = Theme.CardBg
    codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    codeScroll.ScrollBarThickness = 6
    codeScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(codeScroll, 6)
    addStroke(codeScroll, Theme.Stroke, 1)
    codeScroll.Parent = codeTab

    local codeListLayout = Instance.new("UIListLayout")
    codeListLayout.Padding = UDim.new(0, 4)
    codeListLayout.Parent = codeScroll

    function UI.RefreshCodeList()
        for _, child in ipairs(codeScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        if not codeAnalysisData or not codeAnalysisData.Scripts then return end

        local ySize = 0
        for _, s in ipairs(codeAnalysisData.Scripts) do
            local matches = true
            if activeScriptFilter ~= "" then
                local textTarget = (s.Name .. " " .. s.Category .. " " .. s.FullName):lower()
                matches = textTarget:find(activeScriptFilter:lower(), 1, true) ~= nil
            end

            if matches then
                ySize = ySize + 48
                local item = Instance.new("Frame")
                item.Size = UDim2.new(1, -8, 0, 44)
                item.BackgroundColor3 = Theme.Background
                addCorner(item, 4)
                item.Parent = codeScroll

                local catBadge = Instance.new("TextLabel")
                catBadge.Size = UDim2.new(0, 110, 0, 20)
                catBadge.Position = UDim2.new(0, 8, 0, 12)
                catBadge.BackgroundColor3 = Theme.CardHover
                catBadge.Font = Enum.Font.GothamBold
                catBadge.TextSize = 10
                catBadge.TextColor3 = Theme.AccentHover
                catBadge.Text = s.Category
                addCorner(catBadge, 4)
                catBadge.Parent = item

                local nameLbl = Instance.new("TextLabel")
                nameLbl.Size = UDim2.new(0, 220, 0, 16)
                nameLbl.Position = UDim2.new(0, 126, 0, 6)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Font = Enum.Font.GothamBold
                nameLbl.TextSize = 12
                nameLbl.TextColor3 = Theme.Text
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.Text = s.Name .. " (" .. s.ClassName .. ")"
                nameLbl.Parent = item

                local pathLbl = Instance.new("TextLabel")
                pathLbl.Size = UDim2.new(1, -360, 0, 14)
                pathLbl.Position = UDim2.new(0, 126, 0, 24)
                pathLbl.BackgroundTransparency = 1
                pathLbl.Font = Enum.Font.Code
                pathLbl.TextSize = 10
                pathLbl.TextColor3 = Theme.TextMuted
                pathLbl.TextXAlignment = Enum.TextXAlignment.Left
                pathLbl.Text = Utility.Truncate(s.FullName, 60)
                pathLbl.Parent = item

                local copyBtn = Instance.new("TextButton")
                copyBtn.Size = UDim2.new(0, 80, 0, 24)
                copyBtn.Position = UDim2.new(1, -90, 0, 10)
                copyBtn.BackgroundColor3 = Theme.CardHover
                copyBtn.Font = Enum.Font.GothamMedium
                copyBtn.TextSize = 10
                copyBtn.TextColor3 = Theme.Text
                copyBtn.Text = "Copy Path"
                addCorner(copyBtn, 4)
                copyBtn.Parent = item
                copyBtn.MouseButton1Click:Connect(function()
                    Utility.SetClipboard(s.FullName)
                    copyBtn.Text = "Copied!"
                    task.delay(1, function() copyBtn.Text = "Copy Path" end)
                end)
            end
        end

        codeScroll.CanvasSize = UDim2.new(0, 0, 0, ySize + 10)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        activeScriptFilter = searchBox.Text
        UI.RefreshCodeList()
    end)

    -- ==========================================
    -- TAB 3: NETWORK SNIFFER
    -- ==========================================
    local netTab = tabContainers["Network"]
    local ntPad = Instance.new("UIPadding")
    ntPad.PaddingTop = UDim.new(0, 10)
    ntPad.PaddingLeft = UDim.new(0, 14)
    ntPad.PaddingRight = UDim.new(0, 14)
    ntPad.Parent = netTab

    local netControls = Instance.new("Frame")
    netControls.Size = UDim2.new(1, 0, 0, 32)
    netControls.BackgroundTransparency = 1
    netControls.Parent = netTab

    local netSearch = Instance.new("TextBox")
    netSearch.Size = UDim2.new(1, -220, 1, 0)
    netSearch.BackgroundColor3 = Theme.CardBg
    netSearch.Font = Enum.Font.Gotham
    netSearch.TextSize = 12
    netSearch.TextColor3 = Theme.Text
    netSearch.PlaceholderText = "🔎 Filter packets by remote name or system..."
    netSearch.PlaceholderColor3 = Theme.TextMuted
    netSearch.TextXAlignment = Enum.TextXAlignment.Left
    addCorner(netSearch, 6)
    addStroke(netSearch, Theme.Stroke, 1)
    local nsPad = Instance.new("UIPadding")
    nsPad.PaddingLeft = UDim.new(0, 10)
    nsPad.Parent = netSearch
    netSearch.Parent = netControls

    local clearNetBtn = Instance.new("TextButton")
    clearNetBtn.Size = UDim2.new(0, 95, 1, 0)
    clearNetBtn.Position = UDim2.new(1, -205, 0, 0)
    clearNetBtn.BackgroundColor3 = Theme.CardBg
    clearNetBtn.Font = Enum.Font.GothamMedium
    clearNetBtn.TextSize = 11
    clearNetBtn.TextColor3 = Theme.Text
    clearNetBtn.Text = "🗑️ Clear Log"
    addCorner(clearNetBtn, 6)
    addStroke(clearNetBtn, Theme.Stroke, 1)
    clearNetBtn.Parent = netControls

    local pauseNetBtn = Instance.new("TextButton")
    pauseNetBtn.Size = UDim2.new(0, 95, 1, 0)
    pauseNetBtn.Position = UDim2.new(1, -100, 0, 0)
    pauseNetBtn.BackgroundColor3 = Theme.Accent
    pauseNetBtn.Font = Enum.Font.GothamBold
    pauseNetBtn.TextSize = 11
    pauseNetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pauseNetBtn.Text = "⏸️ Pause"
    addCorner(pauseNetBtn, 6)
    pauseNetBtn.Parent = netControls

    local netScroll = Instance.new("ScrollingFrame")
    netScroll.Size = UDim2.new(1, 0, 1, -48)
    netScroll.Position = UDim2.new(0, 0, 0, 42)
    netScroll.BackgroundColor3 = Theme.CardBg
    netScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    netScroll.ScrollBarThickness = 6
    netScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(netScroll, 6)
    addStroke(netScroll, Theme.Stroke, 1)
    netScroll.Parent = netTab

    local netListLayout = Instance.new("UIListLayout")
    netListLayout.Padding = UDim.new(0, 3)
    netListLayout.Parent = netScroll

    local isPaused = false
    pauseNetBtn.MouseButton1Click:Connect(function()
        isPaused = not isPaused
        pauseNetBtn.Text = isPaused and "▶️ Resume" or "⏸️ Pause"
        pauseNetBtn.BackgroundColor3 = isPaused and Theme.Success or Theme.Accent
    end)

    clearNetBtn.MouseButton1Click:Connect(function()
        if analyzerCore and analyzerCore.NetworkMonitor then
            analyzerCore.NetworkMonitor.Clear()
        end
        livePackets = {}
        for _, child in ipairs(netScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        netScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        cardLabels["Card_Packets"].Text = "0"
    end)

    function UI.AddPacketRow(packet)
        if isPaused then return end
        table.insert(livePackets, packet)
        cardLabels["Card_Packets"].Text = tostring(#livePackets)

        if activePacketFilter ~= "" then
            local t = (packet.RemoteName .. " " .. packet.System .. " " .. packet.Direction):lower()
            if not t:find(activePacketFilter:lower(), 1, true) then return end
        end

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 38)
        row.BackgroundColor3 = Theme.Background
        addCorner(row, 4)
        row.Parent = netScroll

        local dirLabel = Instance.new("TextLabel")
        dirLabel.Size = UDim2.new(0, 30, 0, 20)
        dirLabel.Position = UDim2.new(0, 6, 0, 9)
        dirLabel.BackgroundColor3 = packet.Direction:find("Client %->") and Theme.Success or Theme.Accent
        dirLabel.Font = Enum.Font.GothamBold
        dirLabel.TextSize = 11
        dirLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        dirLabel.Text = packet.Direction:find("Client %->") and "OUT" or "IN"
        addCorner(dirLabel, 4)
        dirLabel.Parent = row

        local timeLbl = Instance.new("TextLabel")
        timeLbl.Size = UDim2.new(0, 80, 0, 16)
        timeLbl.Position = UDim2.new(0, 42, 0, 11)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Font = Enum.Font.Code
        timeLbl.TextSize = 10
        timeLbl.TextColor3 = Theme.TextMuted
        timeLbl.TextXAlignment = Enum.TextXAlignment.Left
        timeLbl.Text = packet.Timestamp
        timeLbl.Parent = row

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0, 180, 0, 16)
        nameLbl.Position = UDim2.new(0, 126, 0, 11)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextColor3 = Theme.Text
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Text = packet.RemoteName
        nameLbl.Parent = row

        local sysBadge = Instance.new("TextLabel")
        sysBadge.Size = UDim2.new(0, 120, 0, 18)
        sysBadge.Position = UDim2.new(0, 310, 0, 10)
        sysBadge.BackgroundColor3 = Theme.CardHover
        sysBadge.Font = Enum.Font.Gotham
        sysBadge.TextSize = 9
        sysBadge.TextColor3 = Theme.AccentHover
        sysBadge.Text = packet.System
        addCorner(sysBadge, 4)
        sysBadge.Parent = row

        local argsLbl = Instance.new("TextLabel")
        argsLbl.Size = UDim2.new(1, -540, 0, 16)
        argsLbl.Position = UDim2.new(0, 436, 0, 11)
        argsLbl.BackgroundTransparency = 1
        argsLbl.Font = Enum.Font.Code
        argsLbl.TextSize = 10
        argsLbl.TextColor3 = Theme.TextMuted
        argsLbl.TextXAlignment = Enum.TextXAlignment.Left
        argsLbl.Text = "(" .. table.concat(packet.ArgTypes, ", ") .. ")"
        argsLbl.Parent = row

        local copyPayload = Instance.new("TextButton")
        copyPayload.Size = UDim2.new(0, 85, 0, 22)
        copyPayload.Position = UDim2.new(1, -95, 0, 8)
        copyPayload.BackgroundColor3 = Theme.CardHover
        copyPayload.Font = Enum.Font.GothamMedium
        copyPayload.TextSize = 10
        copyPayload.TextColor3 = Theme.Text
        copyPayload.Text = "Copy JSON"
        addCorner(copyPayload, 4)
        copyPayload.Parent = row
        copyPayload.MouseButton1Click:Connect(function()
            local jsonStr = Serializer.ToJSON(packet.Arguments, 0)
            Utility.SetClipboard(jsonStr)
            copyPayload.Text = "Copied!"
            task.delay(1, function() copyPayload.Text = "Copy JSON" end)
        end)

        netScroll.CanvasSize = UDim2.new(0, 0, 0, #livePackets * 42)
    end

    netSearch:GetPropertyChangedSignal("Text"):Connect(function()
        activePacketFilter = netSearch.Text
    end)

    -- ==========================================
    -- TAB 4: CONTENT TRACKER
    -- ==========================================
    local trkTab = tabContainers["Tracker"]
    local trkPad = Instance.new("UIPadding")
    trkPad.PaddingTop = UDim.new(0, 10)
    trkPad.PaddingLeft = UDim.new(0, 14)
    trkPad.PaddingRight = UDim.new(0, 14)
    trkPad.Parent = trkTab

    local trkBanner = Instance.new("Frame")
    trkBanner.Size = UDim2.new(1, 0, 0, 48)
    trkBanner.BackgroundColor3 = Theme.CardBg
    addCorner(trkBanner, 6)
    addStroke(trkBanner, Theme.Stroke, 1)
    trkBanner.Parent = trkTab

    local snapBtn = Instance.new("TextButton")
    snapBtn.Size = UDim2.new(0, 150, 0, 32)
    snapBtn.Position = UDim2.new(0, 10, 0, 8)
    snapBtn.BackgroundColor3 = Theme.Accent
    snapBtn.Font = Enum.Font.GothamBold
    snapBtn.TextSize = 12
    snapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    snapBtn.Text = "📸 Take Snapshot"
    addCorner(snapBtn, 6)
    snapBtn.Parent = trkBanner

    local diffBtn = Instance.new("TextButton")
    diffBtn.Size = UDim2.new(0, 180, 0, 32)
    diffBtn.Position = UDim2.new(0, 170, 0, 8)
    diffBtn.BackgroundColor3 = Theme.CardHover
    diffBtn.Font = Enum.Font.GothamMedium
    diffBtn.TextSize = 12
    diffBtn.TextColor3 = Theme.Text
    diffBtn.Text = "🔄 Compare Session Diffs"
    addCorner(diffBtn, 6)
    addStroke(diffBtn, Theme.Stroke, 1)
    diffBtn.Parent = trkBanner

    local trkDisplay = Instance.new("ScrollingFrame")
    trkDisplay.Size = UDim2.new(1, 0, 1, -62)
    trkDisplay.Position = UDim2.new(0, 0, 0, 56)
    trkDisplay.BackgroundColor3 = Theme.CardBg
    trkDisplay.ScrollBarThickness = 6
    trkDisplay.ScrollBarImageColor3 = Theme.Accent
    addCorner(trkDisplay, 6)
    addStroke(trkDisplay, Theme.Stroke, 1)
    trkDisplay.Parent = trkTab

    local trkText = Instance.new("TextLabel")
    trkText.Size = UDim2.new(1, -20, 1, 0)
    trkText.Position = UDim2.new(0, 10, 0, 10)
    trkText.BackgroundTransparency = 1
    trkText.Font = Enum.Font.Code
    trkText.TextSize = 11
    trkText.TextColor3 = Theme.Text
    trkText.TextXAlignment = Enum.TextXAlignment.Left
    trkText.TextYAlignment = Enum.TextYAlignment.Top
    trkText.Text = "Click 'Take Snapshot' to record the initial game state, then click 'Compare Session Diffs' after gameplay to see new remotes, assets, or script changes."
    trkText.Parent = trkDisplay

    snapBtn.MouseButton1Click:Connect(function()
        if analyzerCore and analyzerCore.ContentTracker then
            local snap = analyzerCore.ContentTracker.TakeSnapshot()
            trkText.Text = string.format("Recorded %s with %d scripts, %d remotes, %d assets, %d tags.",
                snap.Label, snap.Counts.Scripts, snap.Counts.Remotes, snap.Counts.Assets, snap.Counts.Tags)
        end
    end)

    diffBtn.MouseButton1Click:Connect(function()
        if analyzerCore and analyzerCore.ContentTracker then
            local snaps = analyzerCore.ContentTracker.GetSnapshots()
            if #snaps < 2 then
                trkText.Text = "Need at least 2 snapshots to perform comparison. Please take another snapshot first."
            else
                local diff = analyzerCore.ContentTracker.CompareSnapshots(snaps[1], snaps[#snaps])
                local changelog = analyzerCore.ContentTracker.GenerateChangelog(diff)
                trkText.Text = changelog
            end
        end
    end)

    -- ==========================================
    -- TAB 5: EDUCATIONAL DOCS
    -- ==========================================
    local docsTab = tabContainers["Docs"]
    local dtPad = Instance.new("UIPadding")
    dtPad.PaddingTop = UDim.new(0, 10)
    dtPad.PaddingLeft = UDim.new(0, 14)
    dtPad.PaddingRight = UDim.new(0, 14)
    dtPad.Parent = docsTab

    local docsBar = Instance.new("Frame")
    docsBar.Size = UDim2.new(1, 0, 0, 40)
    docsBar.BackgroundColor3 = Theme.CardBg
    addCorner(docsBar, 6)
    addStroke(docsBar, Theme.Stroke, 1)
    docsBar.Parent = docsTab

    local genReportBtn = Instance.new("TextButton")
    genReportBtn.Size = UDim2.new(0, 150, 0, 28)
    genReportBtn.Position = UDim2.new(0, 8, 0, 6)
    genReportBtn.BackgroundColor3 = Theme.Accent
    genReportBtn.Font = Enum.Font.GothamMedium
    genReportBtn.TextSize = 11
    genReportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    genReportBtn.Text = "📄 Architecture Spec"
    addCorner(genReportBtn, 4)
    genReportBtn.Parent = docsBar

    local genTutorialBtn = Instance.new("TextButton")
    genTutorialBtn.Size = UDim2.new(0, 140, 0, 28)
    genTutorialBtn.Position = UDim2.new(0, 164, 0, 6)
    genTutorialBtn.BackgroundColor3 = Theme.CardHover
    genTutorialBtn.Font = Enum.Font.GothamMedium
    genTutorialBtn.TextSize = 11
    genTutorialBtn.TextColor3 = Theme.Text
    genTutorialBtn.Text = "🎓 Luau Tutorials"
    addCorner(genTutorialBtn, 4)
    addStroke(genTutorialBtn, Theme.Stroke, 1)
    genTutorialBtn.Parent = docsBar

    local copyDocBtn = Instance.new("TextButton")
    copyDocBtn.Size = UDim2.new(0, 130, 0, 28)
    copyDocBtn.Position = UDim2.new(1, -270, 0, 6)
    copyDocBtn.BackgroundColor3 = Theme.CardHover
    copyDocBtn.Font = Enum.Font.GothamMedium
    copyDocBtn.TextSize = 11
    copyDocBtn.TextColor3 = Theme.Text
    copyDocBtn.Text = "📋 Copy Markdown"
    addCorner(copyDocBtn, 4)
    addStroke(copyDocBtn, Theme.Stroke, 1)
    copyDocBtn.Parent = docsBar

    local saveFileBtn = Instance.new("TextButton")
    saveFileBtn.Size = UDim2.new(0, 125, 0, 28)
    saveFileBtn.Position = UDim2.new(1, -132, 0, 6)
    saveFileBtn.BackgroundColor3 = Theme.Success
    saveFileBtn.Font = Enum.Font.GothamMedium
    saveFileBtn.TextSize = 11
    saveFileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveFileBtn.Text = "💾 Save to File"
    addCorner(saveFileBtn, 4)
    saveFileBtn.Parent = docsBar

    local docScroll = Instance.new("ScrollingFrame")
    docScroll.Size = UDim2.new(1, 0, 1, -54)
    docScroll.Position = UDim2.new(0, 0, 0, 48)
    docScroll.BackgroundColor3 = Theme.CardBg
    docScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    docScroll.ScrollBarThickness = 6
    docScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(docScroll, 6)
    addStroke(docScroll, Theme.Stroke, 1)
    docScroll.Parent = docsTab

    local docText = Instance.new("TextLabel")
    docText.Size = UDim2.new(1, -24, 0, 2000)
    docText.Position = UDim2.new(0, 12, 0, 10)
    docText.BackgroundTransparency = 1
    docText.Font = Enum.Font.Code
    docText.TextSize = 11
    docText.TextColor3 = Theme.Text
    docText.TextXAlignment = Enum.TextXAlignment.Left
    docText.TextYAlignment = Enum.TextYAlignment.Top
    docText.Text = "Select 'Architecture Spec' or 'Luau Tutorials' above to generate educational documentation."
    docText.Parent = docScroll

    local currentDocContent = ""

    function UI.GenerateReportDoc()
        if analyzerCore and analyzerCore.DocGenerator then
            if not codeAnalysisData and analyzerCore.CodeAnalyzer then
                codeAnalysisData = analyzerCore.CodeAnalyzer.RunAnalysis()
            end
            local report = analyzerCore.DocGenerator.GenerateArchitectureReport({
                CodeAnalysis = codeAnalysisData,
                NetworkStats = analyzerCore.NetworkMonitor and analyzerCore.NetworkMonitor.GetStats() or {},
                TotalRemotes = 0
            })
            currentDocContent = report
            docText.Text = report
            docScroll.CanvasSize = UDim2.new(0, 0, 0, #report:split("\n") * 16 + 40)
        end
    end

    genReportBtn.MouseButton1Click:Connect(function()
        UI.GenerateReportDoc()
    end)

    genTutorialBtn.MouseButton1Click:Connect(function()
        if analyzerCore and analyzerCore.DocGenerator then
            local tut = analyzerCore.DocGenerator.GenerateTutorial("Architecture")
            currentDocContent = tut
            docText.Text = tut
            docScroll.CanvasSize = UDim2.new(0, 0, 0, #tut:split("\n") * 16 + 40)
        end
    end)

    copyDocBtn.MouseButton1Click:Connect(function()
        if #currentDocContent > 0 then
            Utility.SetClipboard(currentDocContent)
            copyDocBtn.Text = "Copied!"
            task.delay(1, function() copyDocBtn.Text = "📋 Copy Markdown" end)
        end
    end)

    saveFileBtn.MouseButton1Click:Connect(function()
        if #currentDocContent > 0 then
            local filename = "LuauLens_Report_" .. tostring(os.time()) .. ".md"
            local success, msg = Utility.SaveFile(filename, currentDocContent)
            saveFileBtn.Text = success and "Saved!" or "Saved Failed"
            task.delay(2, function() saveFileBtn.Text = "💾 Save to File" end)
        end
    end)

    -- Register Hotkey (F4 or RightControl)
    Services.UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.F4 or input.KeyCode == Enum.KeyCode.RightControl then
            UI.Toggle()
        end
    end)

    -- Memory stat ticker
    task.spawn(function()
        while screenGui and screenGui.Parent do
            cardLabels["Card_Memory"].Text = string.format("%.1f MB", Utility.GetMemoryUsageMB())
            task.wait(2)
        end
    end)

    -- Select initial tab
    UI.SelectTab("Overview")

    -- Initial code analysis run
    task.spawn(function()
        task.wait(0.5)
        if analyzerCore and analyzerCore.CodeAnalyzer then
            codeAnalysisData = analyzerCore.CodeAnalyzer.RunAnalysis()
            cardLabels["Card_Scripts"].Text = tostring(codeAnalysisData.TotalScripts)
            cardLabels["Card_Tags"].Text = tostring(#codeAnalysisData.Tags)
            if codeAnalysisData.Frameworks[1] then
                cardLabels["Card_Framework"].Text = codeAnalysisData.Frameworks[1].Name
            end
            UI.RefreshCodeList()
        end
    end)
end

return UI
