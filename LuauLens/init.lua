--[[
    LuauLens/init.lua
    Main entry point, service bootstrapping, and module coordinator for LuauLens.
    A developer diagnostic and architecture analysis suite for Roblox experiences and Studio.
]]

local UserInputService = game:GetService("UserInputService")

-- Module dependency resolver (handles Studio script hierarchy, bundles, and direct paths)
local function resolveModule(modName)
    local success, res = pcall(function()
        if script and script:FindFirstChild("modules") and script.modules:FindFirstChild(modName) then
            return require(script.modules[modName])
        end
        if script and script.Parent and script.Parent:FindFirstChild(modName) then
            return require(script.Parent[modName])
        end
    end)
    if success and res then return res end
    return require("LuauLens.modules." .. modName)
end

local LuauLens = {}
LuauLens.__index = LuauLens

-- 1. Load Sub-Modules
LuauLens.Serializer = resolveModule("Serializer")
LuauLens.Utility = resolveModule("Utility")
LuauLens.CodeAnalyzer = resolveModule("CodeAnalyzer")
LuauLens.NetworkMonitor = resolveModule("NetworkMonitor")
LuauLens.ContentTracker = resolveModule("ContentTracker")
LuauLens.DocGenerator = resolveModule("DocGenerator")
LuauLens.UI = resolveModule("UI")

local isInitialized = false
local inputConnection = nil

--[[
    LuauLens:Initialize(options)
    Initializes the entire LuauLens diagnostic suite:
    - Starts the network monitoring hook
    - Wires network traffic to the dashboard
    - Builds the dark-themed UI
    - Registers the toggle keybind (RightControl / F4)
    - Records an initial baseline DataModel snapshot
]]
function LuauLens:Initialize(options)
    if isInitialized then
        print("[LuauLens] Suite is already initialized.")
        return self
    end
    isInitialized = true

    print([[
=====================================================
🔍 LuauLens Architecture & Diagnostic Suite Initialized
Hotkey: RightControl or F4 to toggle in-game dashboard
=====================================================
]])

    -- 1. Wire network packet stream to UI
    self.NetworkMonitor.OnPacket(function(packet)
        if self.UI and self.UI.AddPacketRow then
            self.UI.AddPacketRow(packet)
        end
    end)

    -- 2. Start Network Traffic Monitoring
    self.NetworkMonitor.Start()

    -- 3. Construct Dashboard UI
    self.UI.CreateDashboard(self)

    -- 4. Register Toggle Keybind (RightControl and F4)
    if inputConnection then inputConnection:Disconnect() end
    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.F4 then
            self.UI.Toggle()
        end
    end)

    -- 5. Record initial baseline snapshot
    task.spawn(function()
        task.wait(1)
        self.ContentTracker.CreateSnapshot("Initial Baseline")
    end)

    _G.LuauLens = self
    return self
end

-- Scan script hierarchy and return structured architecture data
function LuauLens:AnalyzeCode()
    return self.CodeAnalyzer.ScanGameHierarchy()
end

-- Get chronological log of all captured network calls
function LuauLens:GetNetworkLog()
    return self.NetworkMonitor.GetNetworkLog()
end

-- Create a snapshot of current DataModel state
function LuauLens:CreateSnapshot(label)
    return self.ContentTracker.CreateSnapshot(label)
end

-- Compare two recorded snapshots
function LuauLens:CompareSnapshots(idxA, idxB)
    local snaps = self.ContentTracker.GetSnapshots()
    idxA = idxA or 1
    idxB = idxB or #snaps
    return self.ContentTracker.CompareSnapshots(snaps[idxA], snaps[idxB])
end

-- Generate a comprehensive Markdown architecture and network report
function LuauLens:GenerateReport()
    local codeData = self.CodeAnalyzer.ScanGameHierarchy()
    local netLogs = self.NetworkMonitor.GetNetworkLog()
    return self.DocGenerator.GenerateFullReport(codeData, netLogs)
end

-- Export the generated report to file or clipboard
function LuauLens:ExportReport(filename)
    local report = self:GenerateReport()
    return self.Utility.Export(report, filename or "LuauLens_Report.md")
end

-- Toggle UI visibility
function LuauLens:ToggleUI()
    self.UI.Toggle()
end

-- Terminate and clean up suite
function LuauLens:Terminate()
    if inputConnection then inputConnection:Disconnect() end
    if self.NetworkMonitor then self.NetworkMonitor.Stop() end
    isInitialized = false
    _G.LuauLens = nil
    print("[LuauLens] Suite terminated.")
end

-- Automatically initialize when executed as a root script
task.spawn(function()
    if not game:IsLoaded() then
        pcall(function() game.Loaded:Wait() end)
    end
    LuauLens:Initialize()
end)

return LuauLens
