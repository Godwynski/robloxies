--[[
    LuauLens/modules/UI.lua
    Clean, dark-themed diagnostic dashboard using ScreenGui and Frame objects.
    Features tabs for Overview, Code, Network, Content, and Documentation export.
]]

local UI = {}

local function resolveModule(modName)
    local success, res = pcall(function()
        if script and script.Parent and script.Parent:FindFirstChild(modName) then
            return require(script.Parent[modName])
        end
    end)
    if success and res then return res end
    return require("LuauLens.modules." .. modName)
end

local Utility = resolveModule("Utility")
local Serializer = resolveModule("Serializer")

local Services = {
    CoreGui = game:GetService("CoreGui"),
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
}

local Theme = {
    Background = Color3.fromRGB(15, 18, 25),
    Header = Color3.fromRGB(20, 24, 34),
    Card = Color3.fromRGB(26, 32, 46),
    CardHover = Color3.fromRGB(35, 43, 62),
    Stroke = Color3.fromRGB(48, 56, 78),
    Accent = Color3.fromRGB(99, 102, 241),       -- Indigo
    AccentHover = Color3.fromRGB(129, 140, 248),
    Success = Color3.fromRGB(34, 197, 94),       -- Emerald
    Warning = Color3.fromRGB(245, 158, 11),      -- Amber
    Text = Color3.fromRGB(243, 244, 246),
    TextMuted = Color3.fromRGB(156, 163, 175),
    CodeBg = Color3.fromRGB(11, 13, 19),
}

local screenGui = nil
local mainFrame = nil
local isVisible = true
local activeTab = "Overview"
local tabButtons = {}
local tabContainers = {}

local codeData = nil
local livePackets = {}
local scriptFilter = ""
local packetFilter = ""

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Stroke
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function makeDraggable(handle, frame)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
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

function UI.SelectTab(tabName)
    activeTab = tabName
    for name, btn in pairs(tabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Theme.Accent
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Theme.Header
            btn.TextColor3 = Theme.TextMuted
        end
    end
    for name, container in pairs(tabContainers) do
        container.Visible = (name == tabName)
    end
end

function UI.Toggle()
    isVisible = not isVisible
    if mainFrame then mainFrame.Visible = isVisible end
end

--[[
    UI.CreateDashboard(core)
    Constructs the entire dark-themed diagnostic dashboard.
]]
function UI.CreateDashboard(core)
    local env = Utility.GetEnvironment()
    local parentGui = nil
    if env.HasGetHui then
        parentGui = gethui()
    else
        pcall(function() parentGui = Services.CoreGui end)
        if not parentGui then
            local lp = Services.Players.LocalPlayer
            parentGui = lp and lp:FindFirstChild("PlayerGui")
        end
    end

    if not parentGui then return end

    -- Clean old instances
    for _, child in ipairs(parentGui:GetChildren()) do
        if child.Name == "LuauLensDashboard" then
            pcall(function() child:Destroy() end)
        end
    end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LuauLensDashboard"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parentGui

    -- Main Container (860 x 540)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 860, 0, 540)
    mainFrame.Position = UDim2.new(0.5, -430, 0.5, -270)
    mainFrame.BackgroundColor3 = Theme.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    addCorner(mainFrame, 8)
    addStroke(mainFrame, Theme.Stroke, 1.5)
    mainFrame.Parent = screenGui

    -- 1. Top Header Bar
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Theme.Header
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    makeDraggable(header, mainFrame)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 360, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = Theme.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🔍 LuauLens — In-Game Architecture & Diagnostic Suite"
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "✕"
    addCorner(closeBtn, 6)
    closeBtn.Parent = header
    closeBtn.MouseButton1Click:Connect(function() UI.Toggle() end)

    local envBadge = Instance.new("TextLabel")
    envBadge.Size = UDim2.new(0, 110, 0, 22)
    envBadge.Position = UDim2.new(1, -160, 0.5, -11)
    envBadge.BackgroundColor3 = Theme.Card
    envBadge.Font = Enum.Font.GothamMedium
    envBadge.TextSize = 11
    envBadge.TextColor3 = Theme.AccentHover
    envBadge.Text = Utility.IsStudio() and "Roblox Studio" or "Runtime Client"
    addCorner(envBadge, 4)
    addStroke(envBadge, Theme.Stroke, 1)
    envBadge.Parent = header

    -- 2. Tab Navigation Bar
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, 0, 0, 36)
    tabBar.Position = UDim2.new(0, 0, 0, 44)
    tabBar.BackgroundColor3 = Theme.Header
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 14)
    tabPadding.Parent = tabBar

    -- 3. Content Body
    local contentBody = Instance.new("Frame")
    contentBody.Name = "ContentBody"
    contentBody.Size = UDim2.new(1, 0, 1, -80)
    contentBody.Position = UDim2.new(0, 0, 0, 80)
    contentBody.BackgroundTransparency = 1
    contentBody.Parent = mainFrame

    local tabs = {
        { Id = "Overview", Name = "📊 Overview" },
        { Id = "Code", Name = "📜 Code" },
        { Id = "Network", Name = "📡 Network" },
        { Id = "Content", Name = "🔄 Content" },
        { Id = "Docs", Name = "📄 Report & Export" },
    }

    for _, t in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. t.Id
        btn.Size = UDim2.new(0, 140, 0, 28)
        btn.BackgroundColor3 = Theme.Header
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
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

        btn.MouseButton1Click:Connect(function() UI.SelectTab(t.Id) end)
    end

    -- ==========================================
    -- TAB 1: OVERVIEW
    -- ==========================================
    local ov = tabContainers["Overview"]
    local ovPad = Instance.new("UIPadding")
    ovPad.PaddingTop = UDim.new(0, 14)
    ovPad.PaddingLeft = UDim.new(0, 16)
    ovPad.PaddingRight = UDim.new(0, 16)
    ovPad.Parent = ov

    local ovGrid = Instance.new("Frame")
    ovGrid.Size = UDim2.new(1, 0, 0, 180)
    ovGrid.BackgroundTransparency = 1
    ovGrid.Parent = ov

    local metrics = {
        { Id = "Metric_Scripts", Title = "Client Scripts", Value = "0", Sub = "LocalScripts & Modules" },
        { Id = "Metric_Remotes", Title = "Network Remotes", Value = "0", Sub = "RemoteEvents & Functions" },
        { Id = "Metric_Tags", Title = "Component Tags", Value = "0", Sub = "CollectionService Tags" },
        { Id = "Metric_Framework", Title = "Detected Framework", Value = "Scanning...", Sub = "Architecture Pattern" },
        { Id = "Metric_Memory", Title = "Memory Footprint", Value = "0 MB", Sub = "Engine Memory Usage" },
        { Id = "Metric_Packets", Title = "Packets Logged", Value = "0", Sub = "Remote Calls Intercepted" },
    }

    local metricLabels = {}
    for i, m in ipairs(metrics) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.315, 0, 0, 80)
        card.Position = UDim2.new(col * 0.342, 0, row * 90, 0)
        card.BackgroundColor3 = Theme.Card
        addCorner(card, 8)
        addStroke(card, Theme.Stroke, 1)
        card.Parent = ovGrid

        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(1, -16, 0, 16)
        tLbl.Position = UDim2.new(0, 10, 0, 8)
        tLbl.BackgroundTransparency = 1
        tLbl.Font = Enum.Font.Gotham
        tLbl.TextSize = 11
        tLbl.TextColor3 = Theme.TextMuted
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.Text = m.Title
        tLbl.Parent = card

        local vLbl = Instance.new("TextLabel")
        vLbl.Size = UDim2.new(1, -16, 0, 26)
        vLbl.Position = UDim2.new(0, 10, 0, 24)
        vLbl.BackgroundTransparency = 1
        vLbl.Font = Enum.Font.GothamBold
        vLbl.TextSize = 18
        vLbl.TextColor3 = Theme.Text
        vLbl.TextXAlignment = Enum.TextXAlignment.Left
        vLbl.Text = m.Value
        vLbl.Parent = card
        metricLabels[m.Id] = vLbl

        local sLbl = Instance.new("TextLabel")
        sLbl.Size = UDim2.new(1, -16, 0, 14)
        sLbl.Position = UDim2.new(0, 10, 0, 54)
        sLbl.BackgroundTransparency = 1
        sLbl.Font = Enum.Font.Gotham
        sLbl.TextSize = 10
        sLbl.TextColor3 = Theme.AccentHover
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
        sLbl.Text = m.Sub
        sLbl.Parent = card
    end

    -- Overview Action Controls
    local ovActions = Instance.new("Frame")
    ovActions.Size = UDim2.new(1, 0, 0, 230)
    ovActions.Position = UDim2.new(0, 0, 0, 195)
    ovActions.BackgroundColor3 = Theme.Card
    addCorner(ovActions, 8)
    addStroke(ovActions, Theme.Stroke, 1)
    ovActions.Parent = ov

    local ovActTitle = Instance.new("TextLabel")
    ovActTitle.Size = UDim2.new(1, -20, 0, 24)
    ovActTitle.Position = UDim2.new(0, 14, 0, 10)
    ovActTitle.BackgroundTransparency = 1
    ovActTitle.Font = Enum.Font.GothamBold
    ovActTitle.TextSize = 14
    ovActTitle.TextColor3 = Theme.Text
    ovActTitle.TextXAlignment = Enum.TextXAlignment.Left
    ovActTitle.Text = "⚡ Diagnostic Controls"
    ovActTitle.Parent = ovActions

    local function makeBtn(txt, pos, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 180, 0, 34)
        btn.Position = pos
        btn.BackgroundColor3 = Theme.CardHover
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextColor3 = Theme.Text
        btn.Text = txt
        addCorner(btn, 6)
        addStroke(btn, Theme.Accent, 1)
        btn.Parent = ovActions
        btn.MouseButton1Click:Connect(cb)
        return btn
    end

    makeBtn("🔍 Scan Hierarchy", UDim2.new(0, 14, 0, 44), function()
        if core and core.CodeAnalyzer then
            codeData = core.CodeAnalyzer.ScanGameHierarchy()
            metricLabels["Metric_Scripts"].Text = tostring(codeData.TotalScripts)
            metricLabels["Metric_Tags"].Text = tostring(#codeData.Tags)
            if codeData.Frameworks[1] then
                metricLabels["Metric_Framework"].Text = codeData.Frameworks[1].Name
            end
            UI.RefreshCodeList()
        end
    end)

    makeBtn("📸 Create Snapshot", UDim2.new(0, 206, 0, 44), function()
        if core and core.ContentTracker then
            local snap = core.ContentTracker.CreateSnapshot()
            metricLabels["Metric_Remotes"].Text = tostring(snap.Counts.Remotes)
        end
    end)

    makeBtn("📄 Generate Report", UDim2.new(0, 398, 0, 44), function()
        UI.SelectTab("Docs")
        UI.RenderReport()
    end)

    local ovGuide = Instance.new("TextLabel")
    ovGuide.Size = UDim2.new(1, -28, 0, 120)
    ovGuide.Position = UDim2.new(0, 14, 0, 92)
    ovGuide.BackgroundColor3 = Theme.CodeBg
    ovGuide.Font = Enum.Font.Code
    ovGuide.TextSize = 11
    ovGuide.TextColor3 = Theme.TextMuted
    ovGuide.TextXAlignment = Enum.TextXAlignment.Left
    ovGuide.TextYAlignment = Enum.TextYAlignment.Top
    ovGuide.Text = [[
LuauLens Developer Architecture & Diagnostics:
• Toggle UI visibility anytime using RightControl (or F4).
• Code tab: Crawls ReplicatedStorage, PlayerScripts, StarterGui and categorizes script tiers.
• Network tab: Intercepts FireServer & InvokeServer calls with payload type signatures.
• Content tab: Takes DataModel snapshots and compares diffs over time.
• Report & Export: Generates comprehensive Markdown documentation with Mermaid diagrams.]]
    addCorner(ovGuide, 6)
    local ogPad = Instance.new("UIPadding")
    ogPad.PaddingTop = UDim.new(0, 10)
    ogPad.PaddingLeft = UDim.new(0, 12)
    ogPad.Parent = ovGuide
    ovGuide.Parent = ovActions

    -- ==========================================
    -- TAB 2: CODE (CATEGORIZED SCRIPT TREE)
    -- ==========================================
    local codeTab = tabContainers["Code"]
    local ctPad = Instance.new("UIPadding")
    ctPad.PaddingTop = UDim.new(0, 10)
    ctPad.PaddingLeft = UDim.new(0, 14)
    ctPad.PaddingRight = UDim.new(0, 14)
    ctPad.Parent = codeTab

    local codeSearch = Instance.new("TextBox")
    codeSearch.Size = UDim2.new(1, 0, 0, 32)
    codeSearch.BackgroundColor3 = Theme.Card
    codeSearch.Font = Enum.Font.Gotham
    codeSearch.TextSize = 12
    codeSearch.TextColor3 = Theme.Text
    codeSearch.PlaceholderText = "🔎 Filter scripts by name, category, or path..."
    codeSearch.PlaceholderColor3 = Theme.TextMuted
    codeSearch.TextXAlignment = Enum.TextXAlignment.Left
    addCorner(codeSearch, 6)
    addStroke(codeSearch, Theme.Stroke, 1)
    local csPad = Instance.new("UIPadding")
    csPad.PaddingLeft = UDim.new(0, 10)
    csPad.Parent = codeSearch
    codeSearch.Parent = codeTab

    local codeScroll = Instance.new("ScrollingFrame")
    codeScroll.Size = UDim2.new(1, 0, 1, -48)
    codeScroll.Position = UDim2.new(0, 0, 0, 42)
    codeScroll.BackgroundColor3 = Theme.Card
    codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    codeScroll.ScrollBarThickness = 6
    codeScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(codeScroll, 6)
    addStroke(codeScroll, Theme.Stroke, 1)
    codeScroll.Parent = codeTab

    local codeLayout = Instance.new("UIListLayout")
    codeLayout.Padding = UDim.new(0, 4)
    codeLayout.Parent = codeScroll

    function UI.RefreshCodeList()
        for _, child in ipairs(codeScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        if not codeData or not codeData.Scripts then return end

        local y = 0
        for _, s in ipairs(codeData.Scripts) do
            local matches = true
            if scriptFilter ~= "" then
                local full = (s.Name .. " " .. s.Category .. " " .. s.FullName):lower()
                matches = full:find(scriptFilter:lower(), 1, true) ~= nil
            end

            if matches then
                y = y + 46
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -8, 0, 42)
                row.BackgroundColor3 = Theme.Background
                addCorner(row, 4)
                row.Parent = codeScroll

                local catBadge = Instance.new("TextLabel")
                catBadge.Size = UDim2.new(0, 105, 0, 20)
                catBadge.Position = UDim2.new(0, 8, 0, 11)
                catBadge.BackgroundColor3 = Theme.CardHover
                catBadge.Font = Enum.Font.GothamBold
                catBadge.TextSize = 10
                catBadge.TextColor3 = Theme.AccentHover
                catBadge.Text = s.Category
                addCorner(catBadge, 4)
                catBadge.Parent = row

                local nLbl = Instance.new("TextLabel")
                nLbl.Size = UDim2.new(0, 240, 0, 16)
                nLbl.Position = UDim2.new(0, 122, 0, 5)
                nLbl.BackgroundTransparency = 1
                nLbl.Font = Enum.Font.GothamBold
                nLbl.TextSize = 12
                nLbl.TextColor3 = Theme.Text
                nLbl.TextXAlignment = Enum.TextXAlignment.Left
                nLbl.Text = s.Name .. " (" .. s.ClassName .. ")"
                nLbl.Parent = row

                local pLbl = Instance.new("TextLabel")
                pLbl.Size = UDim2.new(1, -380, 0, 14)
                pLbl.Position = UDim2.new(0, 122, 0, 23)
                pLbl.BackgroundTransparency = 1
                pLbl.Font = Enum.Font.Code
                pLbl.TextSize = 10
                pLbl.TextColor3 = Theme.TextMuted
                pLbl.TextXAlignment = Enum.TextXAlignment.Left
                pLbl.Text = Utility.Truncate(s.FullName, 60)
                pLbl.Parent = row

                local copyBtn = Instance.new("TextButton")
                copyBtn.Size = UDim2.new(0, 80, 0, 24)
                copyBtn.Position = UDim2.new(1, -90, 0, 9)
                copyBtn.BackgroundColor3 = Theme.CardHover
                copyBtn.Font = Enum.Font.GothamMedium
                copyBtn.TextSize = 10
                copyBtn.TextColor3 = Theme.Text
                copyBtn.Text = "Copy Path"
                addCorner(copyBtn, 4)
                copyBtn.Parent = row
                copyBtn.MouseButton1Click:Connect(function()
                    Utility.Export(s.FullName, "Path.txt")
                    copyBtn.Text = "Copied!"
                    task.delay(1, function() copyBtn.Text = "Copy Path" end)
                end)
            end
        end
        codeScroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
    end

    codeSearch:GetPropertyChangedSignal("Text"):Connect(function()
        scriptFilter = codeSearch.Text
        UI.RefreshCodeList()
    end)

    -- ==========================================
    -- TAB 3: NETWORK (LIVE LOG FROM NETWORKMONITOR)
    -- ==========================================
    local netTab = tabContainers["Network"]
    local ntPad = Instance.new("UIPadding")
    ntPad.PaddingTop = UDim.new(0, 10)
    ntPad.PaddingLeft = UDim.new(0, 14)
    ntPad.PaddingRight = UDim.new(0, 14)
    ntPad.Parent = netTab

    local netBar = Instance.new("Frame")
    netBar.Size = UDim2.new(1, 0, 0, 32)
    netBar.BackgroundTransparency = 1
    netBar.Parent = netTab

    local netSearch = Instance.new("TextBox")
    netSearch.Size = UDim2.new(1, -210, 1, 0)
    netSearch.BackgroundColor3 = Theme.Card
    netSearch.Font = Enum.Font.Gotham
    netSearch.TextSize = 12
    netSearch.TextColor3 = Theme.Text
    netSearch.PlaceholderText = "🔎 Filter network calls by remote name or system..."
    netSearch.PlaceholderColor3 = Theme.TextMuted
    netSearch.TextXAlignment = Enum.TextXAlignment.Left
    addCorner(netSearch, 6)
    addStroke(netSearch, Theme.Stroke, 1)
    local nsbPad = Instance.new("UIPadding")
    nsbPad.PaddingLeft = UDim.new(0, 10)
    nsbPad.Parent = netSearch
    netSearch.Parent = netBar

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 95, 1, 0)
    clearBtn.Position = UDim2.new(1, -200, 0, 0)
    clearBtn.BackgroundColor3 = Theme.Card
    clearBtn.Font = Enum.Font.GothamMedium
    clearBtn.TextSize = 11
    clearBtn.TextColor3 = Theme.Text
    clearBtn.Text = "🗑️ Clear"
    addCorner(clearBtn, 6)
    addStroke(clearBtn, Theme.Stroke, 1)
    clearBtn.Parent = netBar

    local pauseBtn = Instance.new("TextButton")
    pauseBtn.Size = UDim2.new(0, 95, 1, 0)
    pauseBtn.Position = UDim2.new(1, -95, 0, 0)
    pauseBtn.BackgroundColor3 = Theme.Accent
    pauseBtn.Font = Enum.Font.GothamBold
    pauseBtn.TextSize = 11
    pauseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pauseBtn.Text = "⏸️ Pause"
    addCorner(pauseBtn, 6)
    pauseBtn.Parent = netBar

    local netScroll = Instance.new("ScrollingFrame")
    netScroll.Size = UDim2.new(1, 0, 1, -48)
    netScroll.Position = UDim2.new(0, 0, 0, 42)
    netScroll.BackgroundColor3 = Theme.Card
    netScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    netScroll.ScrollBarThickness = 6
    netScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(netScroll, 6)
    addStroke(netScroll, Theme.Stroke, 1)
    netScroll.Parent = netTab

    local netLayout = Instance.new("UIListLayout")
    netLayout.Padding = UDim.new(0, 3)
    netLayout.Parent = netScroll

    local netPaused = false
    pauseBtn.MouseButton1Click:Connect(function()
        netPaused = not netPaused
        pauseBtn.Text = netPaused and "▶️ Resume" or "⏸️ Pause"
        pauseBtn.BackgroundColor3 = netPaused and Theme.Success or Theme.Accent
    end)

    clearBtn.MouseButton1Click:Connect(function()
        if core and core.NetworkMonitor then core.NetworkMonitor.Clear() end
        livePackets = {}
        for _, c in ipairs(netScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        netScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        metricLabels["Metric_Packets"].Text = "0"
    end)

    function UI.AddPacketRow(packet)
        if netPaused then return end
        table.insert(livePackets, packet)
        metricLabels["Metric_Packets"].Text = tostring(#livePackets)

        if packetFilter ~= "" then
            local t = (packet.RemoteName .. " " .. packet.System .. " " .. packet.Direction):lower()
            if not t:find(packetFilter:lower(), 1, true) then return end
        end

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 38)
        row.BackgroundColor3 = Theme.Background
        addCorner(row, 4)
        row.Parent = netScroll

        local dir = Instance.new("TextLabel")
        dir.Size = UDim2.new(0, 32, 0, 20)
        dir.Position = UDim2.new(0, 6, 0, 9)
        dir.BackgroundColor3 = packet.Direction:find("Client %->") and Theme.Success or Theme.Accent
        dir.Font = Enum.Font.GothamBold
        dir.TextSize = 10
        dir.TextColor3 = Color3.fromRGB(255, 255, 255)
        dir.Text = packet.Direction:find("Client %->") and "OUT" or "IN"
        addCorner(dir, 4)
        dir.Parent = row

        local timeLbl = Instance.new("TextLabel")
        timeLbl.Size = UDim2.new(0, 80, 0, 16)
        timeLbl.Position = UDim2.new(0, 44, 0, 11)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Font = Enum.Font.Code
        timeLbl.TextSize = 10
        timeLbl.TextColor3 = Theme.TextMuted
        timeLbl.TextXAlignment = Enum.TextXAlignment.Left
        timeLbl.Text = packet.Timestamp
        timeLbl.Parent = row

        local rNameLbl = Instance.new("TextLabel")
        rNameLbl.Size = UDim2.new(0, 180, 0, 16)
        rNameLbl.Position = UDim2.new(0, 128, 0, 11)
        rNameLbl.BackgroundTransparency = 1
        rNameLbl.Font = Enum.Font.GothamBold
        rNameLbl.TextSize = 11
        rNameLbl.TextColor3 = Theme.Text
        rNameLbl.TextXAlignment = Enum.TextXAlignment.Left
        rNameLbl.Text = packet.RemoteName
        rNameLbl.Parent = row

        local sBadge = Instance.new("TextLabel")
        sBadge.Size = UDim2.new(0, 110, 0, 18)
        sBadge.Position = UDim2.new(0, 314, 0, 10)
        sBadge.BackgroundColor3 = Theme.CardHover
        sBadge.Font = Enum.Font.Gotham
        sBadge.TextSize = 9
        sBadge.TextColor3 = Theme.AccentHover
        sBadge.Text = packet.System
        addCorner(sBadge, 4)
        sBadge.Parent = row

        local sigLbl = Instance.new("TextLabel")
        sigLbl.Size = UDim2.new(1, -540, 0, 16)
        sigLbl.Position = UDim2.new(0, 432, 0, 11)
        sigLbl.BackgroundTransparency = 1
        sigLbl.Font = Enum.Font.Code
        sigLbl.TextSize = 10
        sigLbl.TextColor3 = Theme.TextMuted
        sigLbl.TextXAlignment = Enum.TextXAlignment.Left
        sigLbl.Text = "(" .. table.concat(packet.ArgTypes, ", ") .. ")"
        sigLbl.Parent = row

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
            Utility.Export(jsonStr, "Packet_" .. packet.RemoteName .. ".json")
            copyPayload.Text = "Copied!"
            task.delay(1, function() copyPayload.Text = "Copy JSON" end)
        end)

        netScroll.CanvasSize = UDim2.new(0, 0, 0, #livePackets * 42)
    end

    netSearch:GetPropertyChangedSignal("Text"):Connect(function()
        packetFilter = netSearch.Text
    end)

    -- ==========================================
    -- TAB 4: CONTENT (SNAPSHOTS & DIFFS)
    -- ==========================================
    local cntTab = tabContainers["Content"]
    local cntPad = Instance.new("UIPadding")
    cntPad.PaddingTop = UDim.new(0, 10)
    cntPad.PaddingLeft = UDim.new(0, 14)
    cntPad.PaddingRight = UDim.new(0, 14)
    cntPad.Parent = cntTab

    local cntBar = Instance.new("Frame")
    cntBar.Size = UDim2.new(1, 0, 0, 44)
    cntBar.BackgroundColor3 = Theme.Card
    addCorner(cntBar, 6)
    addStroke(cntBar, Theme.Stroke, 1)
    cntBar.Parent = cntTab

    local snapBtn = Instance.new("TextButton")
    snapBtn.Size = UDim2.new(0, 150, 0, 30)
    snapBtn.Position = UDim2.new(0, 10, 0, 7)
    snapBtn.BackgroundColor3 = Theme.Accent
    snapBtn.Font = Enum.Font.GothamBold
    snapBtn.TextSize = 12
    snapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    snapBtn.Text = "📸 Take Snapshot"
    addCorner(snapBtn, 6)
    snapBtn.Parent = cntBar

    local diffBtn = Instance.new("TextButton")
    diffBtn.Size = UDim2.new(0, 180, 0, 30)
    diffBtn.Position = UDim2.new(0, 170, 0, 7)
    diffBtn.BackgroundColor3 = Theme.CardHover
    diffBtn.Font = Enum.Font.GothamMedium
    diffBtn.TextSize = 12
    diffBtn.TextColor3 = Theme.Text
    diffBtn.Text = "🔄 Compare Snapshots"
    addCorner(diffBtn, 6)
    addStroke(diffBtn, Theme.Stroke, 1)
    diffBtn.Parent = cntBar

    local cntScroll = Instance.new("ScrollingFrame")
    cntScroll.Size = UDim2.new(1, 0, 1, -58)
    cntScroll.Position = UDim2.new(0, 0, 0, 52)
    cntScroll.BackgroundColor3 = Theme.Card
    cntScroll.ScrollBarThickness = 6
    cntScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(cntScroll, 6)
    addStroke(cntScroll, Theme.Stroke, 1)
    cntScroll.Parent = cntTab

    local cntText = Instance.new("TextLabel")
    cntText.Size = UDim2.new(1, -20, 1, 0)
    cntText.Position = UDim2.new(0, 10, 0, 10)
    cntText.BackgroundTransparency = 1
    cntText.Font = Enum.Font.Code
    cntText.TextSize = 11
    cntText.TextColor3 = Theme.Text
    cntText.TextXAlignment = Enum.TextXAlignment.Left
    cntText.TextYAlignment = Enum.TextYAlignment.Top
    cntText.Text = "Click 'Take Snapshot' to capture initial game state, then click 'Compare Snapshots' to inspect newly introduced scripts, remotes, attributes, or tags."
    cntText.Parent = cntScroll

    snapBtn.MouseButton1Click:Connect(function()
        if core and core.ContentTracker then
            local snap = core.ContentTracker.CreateSnapshot()
            cntText.Text = string.format("Recorded %s:\n• %d Client Scripts\n• %d Network Remotes\n• %d Game Assets\n• %d CollectionService Tags\n• %d Attributes Recorded.",
                snap.Label, snap.Counts.Scripts, snap.Counts.Remotes, snap.Counts.Assets, snap.Counts.Tags, snap.Counts.Attributes)
        end
    end)

    diffBtn.MouseButton1Click:Connect(function()
        if core and core.ContentTracker then
            local snaps = core.ContentTracker.GetSnapshots()
            if #snaps < 2 then
                cntText.Text = "At least 2 snapshots are needed to compute a diff. Please take another snapshot first."
            else
                local diff = core.ContentTracker.CompareSnapshots(snaps[1], snaps[#snaps])
                local changelog = core.ContentTracker.GenerateChangelog(diff)
                cntText.Text = changelog
            end
        end
    end)

    -- ==========================================
    -- TAB 5: REPORT & EXPORT
    -- ==========================================
    local docTab = tabContainers["Docs"]
    local dtPad = Instance.new("UIPadding")
    dtPad.PaddingTop = UDim.new(0, 10)
    dtPad.PaddingLeft = UDim.new(0, 14)
    dtPad.PaddingRight = UDim.new(0, 14)
    dtPad.Parent = docTab

    local docBar = Instance.new("Frame")
    docBar.Size = UDim2.new(1, 0, 0, 40)
    docBar.BackgroundColor3 = Theme.Card
    addCorner(docBar, 6)
    addStroke(docBar, Theme.Stroke, 1)
    docBar.Parent = docTab

    local repBtn = Instance.new("TextButton")
    repBtn.Size = UDim2.new(0, 150, 0, 28)
    repBtn.Position = UDim2.new(0, 8, 0, 6)
    repBtn.BackgroundColor3 = Theme.Accent
    repBtn.Font = Enum.Font.GothamMedium
    repBtn.TextSize = 11
    repBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    repBtn.Text = "📄 Generate Report"
    addCorner(repBtn, 4)
    repBtn.Parent = docBar

    local tutBtn = Instance.new("TextButton")
    tutBtn.Size = UDim2.new(0, 140, 0, 28)
    tutBtn.Position = UDim2.new(0, 166, 0, 6)
    tutBtn.BackgroundColor3 = Theme.CardHover
    tutBtn.Font = Enum.Font.GothamMedium
    tutBtn.TextSize = 11
    tutBtn.TextColor3 = Theme.Text
    tutBtn.Text = "🎓 Luau Tutorials"
    addCorner(tutBtn, 4)
    addStroke(tutBtn, Theme.Stroke, 1)
    tutBtn.Parent = docBar

    local expBtn = Instance.new("TextButton")
    expBtn.Size = UDim2.new(0, 150, 0, 28)
    expBtn.Position = UDim2.new(1, -160, 0, 6)
    expBtn.BackgroundColor3 = Theme.Success
    expBtn.Font = Enum.Font.GothamBold
    expBtn.TextSize = 11
    expBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    expBtn.Text = "💾 Export Report"
    addCorner(expBtn, 4)
    expBtn.Parent = docBar

    local docScroll = Instance.new("ScrollingFrame")
    docScroll.Size = UDim2.new(1, 0, 1, -54)
    docScroll.Position = UDim2.new(0, 0, 0, 48)
    docScroll.BackgroundColor3 = Theme.Card
    docScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    docScroll.ScrollBarThickness = 6
    docScroll.ScrollBarImageColor3 = Theme.Accent
    addCorner(docScroll, 6)
    addStroke(docScroll, Theme.Stroke, 1)
    docScroll.Parent = docTab

    local docText = Instance.new("TextLabel")
    docText.Size = UDim2.new(1, -24, 0, 2500)
    docText.Position = UDim2.new(0, 12, 0, 10)
    docText.BackgroundTransparency = 1
    docText.Font = Enum.Font.Code
    docText.TextSize = 11
    docText.TextColor3 = Theme.Text
    docText.TextXAlignment = Enum.TextXAlignment.Left
    docText.TextYAlignment = Enum.TextYAlignment.Top
    docText.Text = "Select 'Generate Report' or 'Luau Tutorials' to render documentation."
    docText.Parent = docScroll

    local currentReportContent = ""

    function UI.RenderReport()
        if core and core.DocGenerator then
            if not codeData and core.CodeAnalyzer then
                codeData = core.CodeAnalyzer.ScanGameHierarchy()
            end
            local netLogs = core.NetworkMonitor and core.NetworkMonitor.GetNetworkLog() or {}
            local report = core.DocGenerator.GenerateFullReport(codeData, netLogs)
            currentReportContent = report
            docText.Text = report
            docScroll.CanvasSize = UDim2.new(0, 0, 0, #report:split("\n") * 16 + 50)
        end
    end

    repBtn.MouseButton1Click:Connect(function() UI.RenderReport() end)

    tutBtn.MouseButton1Click:Connect(function()
        if core and core.DocGenerator then
            local tut = core.DocGenerator.GenerateTutorial("Architecture")
            currentReportContent = tut
            docText.Text = tut
            docScroll.CanvasSize = UDim2.new(0, 0, 0, #tut:split("\n") * 16 + 50)
        end
    end)

    expBtn.MouseButton1Click:Connect(function()
        if #currentReportContent > 0 then
            local filename = "LuauLens_Report_" .. tostring(os.time()) .. ".md"
            local success, msg = Utility.Export(currentReportContent, filename)
            expBtn.Text = success and "Exported!" or "Export Failed"
            task.delay(2, function() expBtn.Text = "💾 Export Report" end)
        end
    end)

    -- Memory stat update thread
    task.spawn(function()
        while screenGui and screenGui.Parent do
            metricLabels["Metric_Memory"].Text = string.format("%.1f MB", Utility.GetMemoryUsageMB())
            task.wait(2)
        end
    end)

    -- Initial tab selection
    UI.SelectTab("Overview")

    -- Initial scan
    task.spawn(function()
        task.wait(0.5)
        if core and core.CodeAnalyzer then
            codeData = core.CodeAnalyzer.ScanGameHierarchy()
            metricLabels["Metric_Scripts"].Text = tostring(codeData.TotalScripts)
            metricLabels["Metric_Tags"].Text = tostring(#codeData.Tags)
            if codeData.Frameworks[1] then
                metricLabels["Metric_Framework"].Text = codeData.Frameworks[1].Name
            end
            UI.RefreshCodeList()
        end
    end)
end

return UI
