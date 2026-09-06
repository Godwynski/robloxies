-- analyzer/modules/NetworkMonitor.lua
-- Network Communication Analysis: Monitor, document, and analyze client-server remote patterns

local Serializer = require("analyzer.modules.Serializer")
local Utility = require("analyzer.modules.Utility")

local NetworkMonitor = {}

local Services = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    RunService = game:GetService("RunService"),
}

local packetCounter = 0
local history = {}
local MAX_HISTORY = 300

local remoteStats = {} -- [remotePath] = { Count = 0, LastCall = 0, Directions = {}, TotalBytes = 0 }
local listeners = {}
local isMonitoring = false
local originalNamecall = nil
local activeConnections = {}

-- Classify remote into functional game system based on name and path
local function classifyRemoteSystem(remoteName, remotePath)
    local n = (remoteName .. " " .. remotePath):lower()

    if n:find("attack") or n:find("damage") or n:find("hit") or n:find("combat") or n:find("shoot") or n:find("skill") or n:find("parry") or n:find("block") then
        return "Combat System", "Handles real-time attacks, hitbox confirmation, damage calculation, or defensive mechanics"
    elseif n:find("buy") or n:find("sell") or n:find("shop") or n:find("purchase") or n:find("trade") or n:find("currency") or n:find("gold") or n:find("gem") then
        return "Economy & Shop", "Facilitates in-game transactions, merchant interactions, and currency exchanges"
    elseif n:find("inventory") or n:find("equip") or n:find("unequip") or n:find("drop") or n:find("item") or n:find("bag") or n:find("stash") then
        return "Inventory & Equipment", "Coordinates item slots, equipment state changes, and inventory replication"
    elseif n:find("move") or n:find("dash") or n:find("sprint") or n:find("teleport") or n:find("position") or n:find("velocity") or n:find("state") then
        return "Movement & Replication", "Replicates character kinematic state, custom movement skills, or server position checks"
    elseif n:find("quest") or n:find("dialog") or n:find("npc") or n:find("interact") or n:find("level") or n:find("xp") or n:find("stat") then
        return "Progression & Story", "Manages mission objectives, NPC dialogue trees, and player stat progression"
    elseif n:find("chat") or n:find("message") or n:find("party") or n:find("guild") or n:find("clan") or n:find("friend") then
        return "Social & Chat", "Multiplayer social networking, party synchronization, and text messaging"
    else
        return "General Core", "General engine communication or unclassified gameplay remote"
    end
end

-- Estimate payload size in bytes
local function estimateSize(args)
    local jsonStr = Serializer.ToJSON(args)
    return #jsonStr
end

-- Record a network packet
local function recordPacket(packetData)
    packetCounter = packetCounter + 1
    packetData.Id = packetCounter

    local rPath = packetData.RemotePath
    if not remoteStats[rPath] then
        remoteStats[rPath] = {
            Name = packetData.RemoteName,
            Path = rPath,
            System = packetData.System,
            Count = 0,
            LastCall = os.clock(),
            Directions = {},
            TotalBytes = 0,
            ArgSignatures = {},
        }
    end

    local stat = remoteStats[rPath]
    stat.Count = stat.Count + 1
    stat.LastCall = os.clock()
    stat.Directions[packetData.Direction] = (stat.Directions[packetData.Direction] or 0) + 1
    stat.TotalBytes = stat.TotalBytes + (packetData.PayloadBytes or 0)

    -- Record signature
    local sig = table.concat(packetData.ArgTypes, ", ")
    stat.ArgSignatures[sig] = (stat.ArgSignatures[sig] or 0) + 1

    table.insert(history, packetData)
    if #history > MAX_HISTORY then
        table.remove(history, 1)
    end

    -- Notify subscribers
    for _, callback in ipairs(listeners) do
        pcall(function() callback(packetData) end)
    end
end

-- Intercept and inspect remote calls
function NetworkMonitor.ProcessCall(remoteInst, method, direction, callerScript, rawArgs)
    if not isMonitoring then return end
    if not remoteInst or not remoteInst.Name then return end

    local argTypes = {}
    local serializedArgs = {}

    for i, arg in ipairs(rawArgs) do
        table.insert(argTypes, typeof(arg))
        table.insert(serializedArgs, Serializer.Serialize(arg, 3))
    end

    local remotePath = Utility.GetInstancePath(remoteInst)
    local system, sysDesc = classifyRemoteSystem(remoteInst.Name, remotePath)
    local payloadBytes = estimateSize(serializedArgs)

    local packet = {
        Timestamp = Utility.GetFormattedTime(),
        Clock = os.clock(),
        Direction = direction,
        Method = method,
        RemoteName = remoteInst.Name,
        RemoteClass = remoteInst.ClassName,
        RemotePath = remotePath,
        Caller = callerScript or "Unknown Caller",
        ArgTypes = argTypes,
        Arguments = serializedArgs,
        PayloadBytes = payloadBytes,
        System = system,
        SystemDescription = sysDesc,
    }

    recordPacket(packet)
end

-- Discover and attach listeners to all existing and future Remotes
local function attachRemoteListeners()
    local function hookRemote(remote)
        if not remote:IsA("RemoteEvent") and not remote:IsA("RemoteFunction") then return end

        if remote:IsA("RemoteEvent") then
            local conn
            pcall(function()
                conn = remote.OnClientEvent:Connect(function(...)
                    local args = { ... }
                    NetworkMonitor.ProcessCall(remote, "OnClientEvent", "Server -> Client", "Server", args)
                end)
                table.insert(activeConnections, conn)
            end)
        end
    end

    -- Scan ReplicatedStorage and Workspace for remotes
    local function scanForRemotes(parent)
        pcall(function()
            for _, desc in ipairs(parent:GetDescendants()) do
                hookRemote(desc)
            end
        end)
    end

    scanForRemotes(Services.ReplicatedStorage)
    scanForRemotes(Services.Workspace)

    -- Listen for newly added remotes
    local descConn = Services.ReplicatedStorage.DescendantAdded:Connect(hookRemote)
    table.insert(activeConnections, descConn)
end

-- Initialize metamethod hooks if executor environment allows
local function setupMetamethodHook()
    local env = Utility.GetEnvironment()
    if not env.HasHookMeta then return false end

    local success = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                local caller = "Unknown"
                pcall(function()
                    local src = getcallingscript()
                    if src then caller = src:GetFullName() end
                end)

                local args = { ... }
                NetworkMonitor.ProcessCall(self, method, "Client -> Server", caller, args)
            end
            return oldNamecall(self, ...)
        end)
        originalNamecall = oldNamecall
    end)

    return success
end

-- Start monitoring
function NetworkMonitor.Start()
    if isMonitoring then return end
    isMonitoring = true

    -- 1. Metamethod hook for outbound calls
    setupMetamethodHook()

    -- 2. Passive listeners for inbound Remotes
    attachRemoteListeners()
end

-- Stop monitoring and clean up connections
function NetworkMonitor.Stop()
    isMonitoring = false
    for _, conn in ipairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    activeConnections = {}
end

-- Subscribe to packet reception events
function NetworkMonitor.OnPacket(callback)
    table.insert(listeners, callback)
end

-- Get complete recorded history
function NetworkMonitor.GetHistory()
    return history
end

-- Get aggregated remote statistics
function NetworkMonitor.GetStats()
    return remoteStats
end

-- Clear history
function NetworkMonitor.Clear()
    history = {}
    remoteStats = {}
    packetCounter = 0
end

return NetworkMonitor
