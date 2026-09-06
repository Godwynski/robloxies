--[[
    LuauLens/modules/NetworkMonitor.lua
    Hooks and logs RemoteEvent, RemoteFunction, and UnreliableRemoteEvent traffic
    for developer diagnostics and security analysis.
]]

local NetworkMonitor = {}

-- Module dependency resolvers (Studio and bundle compatible)
local function resolveModule(modName)
    if type(__require) == "function" then
        local ok, mod = pcall(__require, modName)
        if ok and mod then return mod end
    end
    local success, res = pcall(function()
        if script and script:FindFirstChild("modules") and script.modules:FindFirstChild(modName) then
            return require(script.modules[modName])
        end
        if script and script.Parent and script.Parent:FindFirstChild(modName) then
            return require(script.Parent[modName])
        end
    end)
    if success and res then return res end
    local ok, resMod = pcall(function()
        local r = require
        return r(modName)
    end)
    if ok and resMod then return resMod end
    return nil
end

local Serializer = resolveModule("Serializer")
local Utility = resolveModule("Utility")

local Services = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
}

local packetLogs = {}
local MAX_LOG_SIZE = 400
local isRunning = false
local originalNamecall = nil
local activeConnections = {}
local packetListeners = {}
local remoteStatistics = {}

-- Classify remote into functional game system
local function classifySystem(name, path)
    local combined = (name .. " " .. path):lower()
    if combined:find("attack") or combined:find("damage") or combined:find("hit") or combined:find("combat") or combined:find("skill") then
        return "Combat", "Real-time attacks, hitbox confirmation, and damage calculation."
    elseif combined:find("buy") or combined:find("sell") or combined:find("shop") or combined:find("purchase") or combined:find("currency") or combined:find("trade") then
        return "Economy", "In-game store transactions and currency operations."
    elseif combined:find("inventory") or combined:find("equip") or combined:find("item") or combined:find("bag") or combined:find("drop") then
        return "Inventory", "Item equipment state, hotbar slots, and bag storage."
    elseif combined:find("move") or combined:find("dash") or combined:find("teleport") or combined:find("position") or combined:find("velocity") then
        return "Movement", "Character kinematics replication and spatial movement skills."
    elseif combined:find("quest") or combined:find("dialog") or combined:find("npc") or combined:find("level") or combined:find("xp") then
        return "Progression", "Quests, NPC dialogue branches, and character progression."
    else
        return "Core / Gameplay", "General engine communication or unclassified gameplay remote."
    end
end

-- Process and record an intercepted packet
local function recordCall(remoteInst, method, direction, callerPath, rawArgs)
    if not isRunning or typeof(remoteInst) ~= "Instance" or not remoteInst.Name then return end

    local remotePath = Utility and Utility.GetInstancePath(remoteInst) or remoteInst:GetFullName()
    local system, sysDesc = classifySystem(remoteInst.Name, remotePath)

    local argTypes = {}
    local serializedArgs = {}
    local payloadSize = 0

    for _, arg in ipairs(rawArgs) do
        local t = typeof(arg)
        table.insert(argTypes, t)
        if Serializer and Serializer.Serialize then
            table.insert(serializedArgs, Serializer.Serialize(arg, 3))
        else
            table.insert(serializedArgs, tostring(arg))
        end

        if t == "string" then
            payloadSize = payloadSize + #arg
        elseif t == "number" or t == "boolean" then
            payloadSize = payloadSize + 8
        elseif t == "Vector3" or t == "CFrame" then
            payloadSize = payloadSize + 32
        elseif t == "table" then
            payloadSize = payloadSize + 64
        else
            payloadSize = payloadSize + 16
        end
    end

    local timeStr = Utility and Utility.GetFormattedTime and Utility.GetFormattedTime() or os.date("%H:%M:%S")

    local packet = {
        Id = #packetLogs + 1,
        Timestamp = timeStr,
        Clock = os.clock(),
        Method = method,
        Direction = direction,
        RemoteName = remoteInst.Name,
        RemoteClass = remoteInst.ClassName,
        RemotePath = remotePath,
        Caller = callerPath or "Unknown Script",
        ArgTypes = argTypes,
        Arguments = serializedArgs,
        PayloadBytes = payloadSize,
        System = system,
        SystemDescription = sysDesc,
    }

    -- Record in chronological table
    table.insert(packetLogs, packet)
    if #packetLogs > MAX_LOG_SIZE then
        table.remove(packetLogs, 1)
    end

    -- Update statistics
    if not remoteStatistics[remotePath] then
        remoteStatistics[remotePath] = {
            Name = remoteInst.Name,
            Path = remotePath,
            System = system,
            Count = 0,
            LastCall = os.clock(),
            Signatures = {},
            TotalBytes = 0
        }
    end
    local stat = remoteStatistics[remotePath]
    stat.Count = stat.Count + 1
    stat.LastCall = os.clock()
    stat.TotalBytes = stat.TotalBytes + payloadSize
    local sig = table.concat(argTypes, ", ")
    stat.Signatures[sig] = (stat.Signatures[sig] or 0) + 1

    -- Notify live subscribers (UI)
    for _, cb in ipairs(packetListeners) do
        pcall(function() cb(packet) end)
    end
end

-- Hook metamethod __namecall for outbound FireServer & InvokeServer
local function hookNamecall()
    local env = Utility and Utility.GetEnvironment() or {}
    if not env.HasHookMeta then return false end
    if originalNamecall then return true end

    local success = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if not isRunning then return oldNamecall(self, ...) end
            local method = getnamecallmethod()
            if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
                if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent") then
                    local caller = "Unknown Caller"
                    pcall(function()
                        if type(getcallingscript) == "function" then
                            local cs = getcallingscript()
                            if cs then caller = cs:GetFullName() end
                        end
                    end)

                    local args = { ... }
                    recordCall(self, method, "Client -> Server", caller, args)
                end
            end
            return oldNamecall(self, ...)
        end)
        originalNamecall = oldNamecall
    end)

    return success
end

-- Attach passive listeners to incoming Remotes (Server -> Client)
local function attachInboundListeners()
    local function bindRemote(inst)
        if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
            local conn
            pcall(function()
                conn = inst.OnClientEvent:Connect(function(...)
                    local args = { ... }
                    recordCall(inst, "OnClientEvent", "Server -> Client", "Server Authority", args)
                end)
                table.insert(activeConnections, conn)
            end)
        end
    end

    local function scan(container)
        pcall(function()
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                    bindRemote(d)
                end
            end
        end)
    end

    scan(Services.ReplicatedStorage)
    scan(Services.Workspace)

    local addedConn = Services.ReplicatedStorage.DescendantAdded:Connect(function(inst)
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
            bindRemote(inst)
        end
    end)
    table.insert(activeConnections, addedConn)
end

--[[
    NetworkMonitor.Start()
    Activates the __namecall hook and remote event listeners to monitor traffic.
]]
function NetworkMonitor.Start()
    if isRunning then return end
    isRunning = true

    -- Hook outbound calls
    hookNamecall()

    -- Listen to inbound calls
    attachInboundListeners()
end

--[[
    NetworkMonitor.Stop()
    Halts network monitoring and disconnects event connections.
]]
function NetworkMonitor.Stop()
    isRunning = false
    for _, conn in ipairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    activeConnections = {}
end

--[[
    NetworkMonitor.GetNetworkLog()
    Returns the complete chronological table of captured network calls.
]]
function NetworkMonitor.GetNetworkLog()
    return packetLogs
end

-- Returns aggregated remote statistics
function NetworkMonitor.GetStatistics()
    return remoteStatistics
end

-- Aliases for API parity
NetworkMonitor.GetStats = NetworkMonitor.GetStatistics
NetworkMonitor.GetHistory = NetworkMonitor.GetNetworkLog

-- Clear network logs
function NetworkMonitor.Clear()
    packetLogs = {}
    remoteStatistics = {}
end

-- Subscribe to packet arrival events
function NetworkMonitor.OnPacket(callback)
    table.insert(packetListeners, callback)
end

return NetworkMonitor
