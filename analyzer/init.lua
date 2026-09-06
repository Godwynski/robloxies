-- analyzer/init.lua
-- LuauLens: Educational Roblox Game Architecture & Mechanics Analyzer
-- Main entry point and lifecycle coordinator

if _G.__LuauLens_Running then
    pcall(function() _G.__LuauLens_Terminate() end)
end
_G.__LuauLens_Running = true

print([[
=====================================================
🔍 LuauLens v1.0.0
Educational Game Architecture & Mechanics Analyzer
Press F4 or RightControl to toggle diagnostic dashboard
=====================================================
]])

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

local Core = {}

-- 1. Load sub-modules
Core.Serializer = require("analyzer.modules.Serializer")
Core.Utility = require("analyzer.modules.Utility")
Core.CodeAnalyzer = require("analyzer.modules.CodeAnalyzer")
Core.NetworkMonitor = require("analyzer.modules.NetworkMonitor")
Core.ContentTracker = require("analyzer.modules.ContentTracker")
Core.DocGenerator = require("analyzer.modules.DocGenerator")
Core.UI = require("analyzer.modules.UI")

-- 2. Wire NetworkMonitor events to UI
Core.NetworkMonitor.OnPacket(function(packet)
    if Core.UI and Core.UI.AddPacketRow then
        Core.UI.AddPacketRow(packet)
    end
end)

-- 3. Start background network sniffer
Core.NetworkMonitor.Start()

-- 4. Initialize Diagnostic Dashboard
Core.UI.Init(Core)

-- 5. Take initial baseline snapshot
task.spawn(function()
    task.wait(1)
    Core.ContentTracker.TakeSnapshot("Baseline (Initial Join)")
end)

-- 6. Programmatic Public API for command bar & automated scripts
local LuauLens = {
    Core = Core,

    Analyze = function()
        return Core.CodeAnalyzer.RunAnalysis()
    end,

    TakeSnapshot = function(label)
        return Core.ContentTracker.TakeSnapshot(label)
    end,

    CompareSnapshots = function(idxA, idxB)
        local snaps = Core.ContentTracker.GetSnapshots()
        idxA = idxA or 1
        idxB = idxB or #snaps
        return Core.ContentTracker.CompareSnapshots(snaps[idxA], snaps[idxB])
    end,

    GenerateReport = function()
        local codeData = Core.CodeAnalyzer.RunAnalysis()
        local netStats = Core.NetworkMonitor.GetStats()
        return Core.DocGenerator.GenerateArchitectureReport({
            CodeAnalysis = codeData,
            NetworkStats = netStats,
            TotalRemotes = 0
        })
    end,

    GenerateTutorial = function(topic)
        return Core.DocGenerator.GenerateTutorial(topic)
    end,

    ExportJSON = function()
        local codeData = Core.CodeAnalyzer.RunAnalysis()
        local netHistory = Core.NetworkMonitor.GetHistory()
        local snaps = Core.ContentTracker.GetSnapshots()

        local exportPackage = {
            Metadata = {
                Tool = "LuauLens",
                Version = "1.0.0",
                Timestamp = os.time(),
                PlaceId = game.PlaceId,
                PlaceVersion = game.PlaceVersion,
            },
            CodeAnalysis = codeData,
            NetworkTrafficSample = netHistory,
            Snapshots = snaps,
        }

        return Core.Serializer.ToJSON(exportPackage, 0)
    end,

    ToggleUI = function()
        Core.UI.Toggle()
    end,
}

_G.LuauLens = LuauLens

-- Termination handler for hot-reloading
_G.__LuauLens_Terminate = function()
    print("[LuauLens] Terminating active instance...")
    if Core.NetworkMonitor then Core.NetworkMonitor.Stop() end
    local env = Core.Utility.GetEnvironment()
    local parentGui = (env.HasGetHui and gethui()) or game:GetService("CoreGui")
    pcall(function()
        if parentGui then
            local existing = parentGui:FindFirstChild("LuauLensAnalyzer")
            if existing then existing:Destroy() end
        end
    end)
    _G.__LuauLens_Running = false
    _G.LuauLens = nil
    print("[LuauLens] Cleanup complete.")
end

return LuauLens
