--[[
    LuauLens/modules/ContentTracker.lua
    Captures hierarchical snapshots of key DataModel components and computes structural diffs over time.
]]

local ContentTracker = {}

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

local Utility = resolveModule("Utility")
local Serializer = resolveModule("Serializer")

local Services = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ReplicatedFirst = game:GetService("ReplicatedFirst"),
    Players = game:GetService("Players"),
    StarterPlayer = game:GetService("StarterPlayer"),
    StarterGui = game:GetService("StarterGui"),
    CollectionService = game:GetService("CollectionService"),
    Workspace = game:GetService("Workspace"),
}

local snapshotStore = {}
local snapshotCount = 0

-- Extract asset IDs from an instance
local function extractAssets(inst, assetMap)
    local props = { "MeshId", "TextureID", "TextureId", "SoundId", "AnimationId" }
    for _, prop in ipairs(props) do
        pcall(function()
            local val = inst[prop]
            if val and type(val) == "string" and #val > 0 then
                if not assetMap[val] then
                    assetMap[val] = {
                        Id = val,
                        Property = prop,
                        SampleHost = inst.Name,
                        HostClass = inst.ClassName,
                        Count = 0
                    }
                end
                assetMap[val].Count = assetMap[val].Count + 1
            end
        end)
    end
end

-- Scan a container and record instances, attributes, remotes, and scripts
local function scanContainer(container, remotes, scripts, assetMap, attributesMap)
    if not container then return end

    local success, descendants = pcall(function()
        return container:GetDescendants()
    end)
    if not success or not descendants then return end

    for _, inst in ipairs(descendants) do
        local path = Utility and Utility.GetInstancePath(inst) or inst:GetFullName()

        -- Remotes
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
            remotes[path] = {
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = path
            }
        end

        -- Client Scripts
        if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
            scripts[path] = {
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = path
            }
        end

        -- Assets: filter by known asset container classes to prevent thousands of redundant pcalls on BaseParts
        if inst:IsA("MeshPart") or inst:IsA("SpecialMesh") or inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("Sound") or inst:IsA("Animation") then
            extractAssets(inst, assetMap)
        end

        -- Attributes
        pcall(function()
            local attrs = inst:GetAttributes()
            local hasAttr = false
            for _ in pairs(attrs) do
                hasAttr = true
                break
            end
            if hasAttr then
                if Serializer and Serializer.Serialize then
                    attributesMap[path] = Serializer.Serialize(attrs, 2)
                else
                    attributesMap[path] = attrs
                end
            end
        end)
    end
end

--[[
    ContentTracker.CreateSnapshot(label)
    Serializes key parts of the DataModel (Workspace, ReplicatedStorage, PlayerScripts, etc.),
    including Instance properties, attributes, and CollectionService tags.
]]
function ContentTracker.CreateSnapshot(label)
    snapshotCount = snapshotCount + 1
    label = label or ("Snapshot #" .. snapshotCount)

    local remotes = {}
    local scripts = {}
    local assetMap = {}
    local attributesMap = {}

    local targets = {
        Services.ReplicatedStorage,
        Services.ReplicatedFirst,
        Services.StarterPlayer,
        Services.StarterGui,
        Services.Workspace,
    }

    local localPlayer = Services.Players.LocalPlayer
    if localPlayer then
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        if ps then table.insert(targets, ps) end
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(targets, pg) end
    end

    for _, container in ipairs(targets) do
        scanContainer(container, remotes, scripts, assetMap, attributesMap)
    end

    -- CollectionService tags
    local tagsMap = {}
    pcall(function()
        for _, tag in ipairs(Services.CollectionService:GetAllTags()) do
            local tagged = Services.CollectionService:GetTagged(tag)
            tagsMap[tag] = #tagged
        end
    end)

    local placeVersion = 0
    pcall(function() placeVersion = game.PlaceVersion end)

    local timeStr = Utility and Utility.GetFormattedTime and Utility.GetFormattedTime() or os.date("%H:%M:%S")

    local snapshot = {
        Id = "snap_" .. tostring(snapshotCount) .. "_" .. tostring(os.time()),
        Label = label,
        Timestamp = os.time(),
        FormattedTime = timeStr,
        PlaceId = game.PlaceId,
        PlaceVersion = placeVersion,
        Remotes = remotes,
        Scripts = scripts,
        Assets = assetMap,
        Attributes = attributesMap,
        Tags = tagsMap,
        Counts = {
            Remotes = 0,
            Scripts = 0,
            Assets = 0,
            Tags = 0,
            Attributes = 0
        }
    }

    for _ in pairs(remotes) do snapshot.Counts.Remotes = snapshot.Counts.Remotes + 1 end
    for _ in pairs(scripts) do snapshot.Counts.Scripts = snapshot.Counts.Scripts + 1 end
    for _ in pairs(assetMap) do snapshot.Counts.Assets = snapshot.Counts.Assets + 1 end
    for _ in pairs(tagsMap) do snapshot.Counts.Tags = snapshot.Counts.Tags + 1 end
    for _ in pairs(attributesMap) do snapshot.Counts.Attributes = snapshot.Counts.Attributes + 1 end

    table.insert(snapshotStore, snapshot)
    return snapshot
end

--[[
    ContentTracker.CompareSnapshots(snapshot1, snapshot2)
    Compares two snapshots and generates a comprehensive structural diff report.
]]
function ContentTracker.CompareSnapshots(snapshot1, snapshot2)
    if not snapshot1 or not snapshot2 then
        return { Error = "Two valid snapshots are required for comparison." }
    end

    local diff = {
        Baseline = snapshot1.Label,
        Current = snapshot2.Label,
        TimeDelta = snapshot2.Timestamp - snapshot1.Timestamp,
        AddedRemotes = {},
        RemovedRemotes = {},
        AddedScripts = {},
        RemovedScripts = {},
        AddedTags = {},
        RemovedTags = {},
        ChangedTags = {},
        AddedAssets = {},
        ChangedAttributes = {},
        Summary = {
            TotalChanges = 0,
            NewFeatures = 0
        }
    }

    -- 1. Compare Remotes
    for path, r in pairs(snapshot2.Remotes) do
        if not snapshot1.Remotes[path] then
            table.insert(diff.AddedRemotes, r)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for path, r in pairs(snapshot1.Remotes) do
        if not snapshot2.Remotes[path] then
            table.insert(diff.RemovedRemotes, r)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 2. Compare Scripts
    for path, s in pairs(snapshot2.Scripts) do
        if not snapshot1.Scripts[path] then
            table.insert(diff.AddedScripts, s)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for path, s in pairs(snapshot1.Scripts) do
        if not snapshot2.Scripts[path] then
            table.insert(diff.RemovedScripts, s)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 3. Compare Tags
    for tag, count in pairs(snapshot2.Tags) do
        if not snapshot1.Tags[tag] then
            table.insert(diff.AddedTags, { Tag = tag, Count = count })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        elseif snapshot1.Tags[tag] ~= count then
            table.insert(diff.ChangedTags, { Tag = tag, Old = snapshot1.Tags[tag], New = count })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for tag, count in pairs(snapshot1.Tags) do
        if not snapshot2.Tags[tag] then
            table.insert(diff.RemovedTags, { Tag = tag, Previous = count })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 4. Compare Assets
    for id, a in pairs(snapshot2.Assets) do
        if not snapshot1.Assets[id] then
            table.insert(diff.AddedAssets, a)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 5. Compare Attributes (Added and Removed)
    for path, attrs in pairs(snapshot2.Attributes) do
        if not snapshot1.Attributes[path] then
            table.insert(diff.ChangedAttributes, { Path = path, Action = "AddedAttributes" })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for path, attrs in pairs(snapshot1.Attributes) do
        if not snapshot2.Attributes[path] then
            table.insert(diff.ChangedAttributes, { Path = path, Action = "RemovedAttributes" })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    diff.Summary.NewFeatures = #diff.AddedRemotes + #diff.AddedScripts + #diff.AddedTags
    return diff
end

-- Generate a readable Markdown changelog from diff
function ContentTracker.GenerateChangelog(diff)
    local lines = {}
    table.insert(lines, "# 🔄 Game Structural Evolution & Changelog")
    table.insert(lines, string.format("**Baseline:** %s | **Comparison:** %s", diff.Baseline, diff.Current))
    table.insert(lines, string.format("**Time Delta:** %d seconds | **Total Changes:** %d", diff.TimeDelta or 0, diff.Summary.TotalChanges or 0))
    table.insert(lines, "")

    if #diff.AddedRemotes > 0 then
        table.insert(lines, "### 📡 Newly Discovered Remotes")
        for _, r in ipairs(diff.AddedRemotes) do
            table.insert(lines, string.format("- **`%s`** (`%s`): `%s`", r.Name, r.ClassName, r.Path))
        end
        table.insert(lines, "")
    end

    if #diff.AddedScripts > 0 then
        table.insert(lines, "### 📜 Newly Added Scripts & Modules")
        for _, s in ipairs(diff.AddedScripts) do
            table.insert(lines, string.format("- **`%s`** (`%s`): `%s`", s.Name, s.ClassName, s.Path))
        end
        table.insert(lines, "")
    end

    if #diff.AddedTags > 0 then
        table.insert(lines, "### 🏷️ New CollectionService Component Tags")
        for _, t in ipairs(diff.AddedTags) do
            table.insert(lines, string.format("- **Tag:** `%s` (Applied to %d instances)", t.Tag, t.Count))
        end
        table.insert(lines, "")
    end

    if #diff.AddedAssets > 0 then
        table.insert(lines, string.format("### 🎨 Newly Loaded Game Assets (%d items)", #diff.AddedAssets))
        for i = 1, math.min(#diff.AddedAssets, 10) do
            local a = diff.AddedAssets[i]
            table.insert(lines, string.format("- **`%s`** (`%s` on `%s`)", Utility and Utility.Truncate(a.Id, 30) or a.Id, a.Property, a.SampleHost))
        end
        table.insert(lines, "")
    end

    if diff.Summary.TotalChanges == 0 then
        table.insert(lines, "> **No structural changes detected.** The DataModel remained identical between snapshots.")
    end

    return table.concat(lines, "\n")
end

-- Get stored snapshots
function ContentTracker.GetSnapshots()
    return snapshotStore
end

-- Aliases for API compatibility
ContentTracker.TakeSnapshot = ContentTracker.CreateSnapshot

return ContentTracker
