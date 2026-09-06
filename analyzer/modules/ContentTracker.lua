-- analyzer/modules/ContentTracker.lua
-- Content Tracking System: Track game assets, scripts, attributes, and remotes over time

local Utility = require("analyzer.modules.Utility")
local Serializer = require("analyzer.modules.Serializer")

local ContentTracker = {}

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
local snapshotCounter = 0

-- Extract asset IDs from an instance if applicable
local function extractAssetIds(inst, assetMap)
    local assetProps = { "MeshId", "TextureID", "TextureId", "SoundId", "AnimationId" }
    for _, prop in ipairs(assetProps) do
        pcall(function()
            local val = inst[prop]
            if val and type(val) == "string" and #val > 0 then
                if not assetMap[val] then
                    assetMap[val] = {
                        Id = val,
                        Property = prop,
                        SampleHost = inst.Name,
                        HostClass = inst.ClassName,
                        Count = 0,
                    }
                end
                assetMap[val].Count = assetMap[val].Count + 1
            end
        end)
    end
end

-- Scan containers and collect fingerprints
local function scanHierarchy(container, remotes, scripts, assetMap, attributesMap)
    if not container then return end

    local success, descendants = pcall(function()
        return container:GetDescendants()
    end)
    if not success or not descendants then return end

    for _, inst in ipairs(descendants) do
        local path = Utility.GetInstancePath(inst)

        -- Track Remotes
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            remotes[path] = {
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = path,
            }
        end

        -- Track Client Scripts
        if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
            scripts[path] = {
                Name = inst.Name,
                ClassName = inst.ClassName,
                Path = path,
            }
        end

        -- Track Assets
        extractAssetIds(inst, assetMap)

        -- Track Attributes
        pcall(function()
            local attrs = inst:GetAttributes()
            local hasAttr = false
            for _ in pairs(attrs) do
                hasAttr = true
                break
            end
            if hasAttr then
                attributesMap[path] = Serializer.Serialize(attrs, 2)
            end
        end)
    end
end

-- Capture full game structural fingerprint
function ContentTracker.TakeSnapshot(label)
    snapshotCounter = snapshotCounter + 1
    local snapId = "snap_" .. tostring(snapshotCounter) .. "_" .. tostring(os.time())
    label = label or ("Snapshot #" .. snapshotCounter)

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
        scanHierarchy(container, remotes, scripts, assetMap, attributesMap)
    end

    -- Capture CollectionService tags
    local tagsMap = {}
    pcall(function()
        for _, tag in ipairs(Services.CollectionService:GetAllTags()) do
            local tagged = Services.CollectionService:GetTagged(tag)
            tagsMap[tag] = #tagged
        end
    end)

    local placeVersion = 0
    pcall(function() placeVersion = game.PlaceVersion end)

    local snapshot = {
        Id = snapId,
        Label = label,
        Timestamp = os.time(),
        FormattedTime = Utility.GetFormattedTime(),
        PlaceId = game.PlaceId,
        PlaceVersion = placeVersion,
        JobId = game.JobId,
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
            Attributes = 0,
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

-- Compare two snapshots and produce detailed diffs
function ContentTracker.CompareSnapshots(oldSnap, newSnap)
    if not oldSnap or not newSnap then
        return { Error = "Invalid snapshots provided for comparison" }
    end

    local diff = {
        BaselineLabel = oldSnap.Label,
        CurrentLabel = newSnap.Label,
        TimeDeltaSeconds = newSnap.Timestamp - oldSnap.Timestamp,
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
            NewFeaturesIdentified = 0,
        }
    }

    -- 1. Compare Remotes
    for path, remote in pairs(newSnap.Remotes) do
        if not oldSnap.Remotes[path] then
            table.insert(diff.AddedRemotes, remote)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for path, remote in pairs(oldSnap.Remotes) do
        if not newSnap.Remotes[path] then
            table.insert(diff.RemovedRemotes, remote)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 2. Compare Scripts
    for path, sc in pairs(newSnap.Scripts) do
        if not oldSnap.Scripts[path] then
            table.insert(diff.AddedScripts, sc)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for path, sc in pairs(oldSnap.Scripts) do
        if not newSnap.Scripts[path] then
            table.insert(diff.RemovedScripts, sc)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 3. Compare Tags
    for tag, count in pairs(newSnap.Tags) do
        if not oldSnap.Tags[tag] then
            table.insert(diff.AddedTags, { Tag = tag, Count = count })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        elseif oldSnap.Tags[tag] ~= count then
            table.insert(diff.ChangedTags, { Tag = tag, OldCount = oldSnap.Tags[tag], NewCount = count })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end
    for tag, count in pairs(oldSnap.Tags) do
        if not newSnap.Tags[tag] then
            table.insert(diff.RemovedTags, { Tag = tag, PreviousCount = count })
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    -- 4. Compare Assets
    for id, asset in pairs(newSnap.Assets) do
        if not oldSnap.Assets[id] then
            table.insert(diff.AddedAssets, asset)
            diff.Summary.TotalChanges = diff.Summary.TotalChanges + 1
        end
    end

    diff.Summary.NewFeaturesIdentified = #diff.AddedRemotes + #diff.AddedScripts + #diff.AddedTags

    return diff
end

-- Generate educational changelog based on snapshot differences
function ContentTracker.GenerateChangelog(diff)
    local lines = {}
    table.insert(lines, "# 🔄 Game Content Evolution & Changelog")
    table.insert(lines, string.format("**Baseline:** %s | **Comparison:** %s", diff.BaselineLabel, diff.CurrentLabel))
    table.insert(lines, string.format("**Time Delta:** %d seconds | **Total Structural Changes:** %d", diff.TimeDeltaSeconds or 0, diff.Summary.TotalChanges or 0))
    table.insert(lines, "")

    -- Added Remotes
    if #diff.AddedRemotes > 0 then
        table.insert(lines, "### 📡 Discovered New Remotes & Communication Endpoints")
        table.insert(lines, "New network communication points indicate newly implemented gameplay features or server capabilities:")
        for _, r in ipairs(diff.AddedRemotes) do
            table.insert(lines, string.format("- **`%s`** (`%s`): `%s`", r.Name, r.ClassName, r.Path))
        end
        table.insert(lines, "")
    end

    -- Added Scripts
    if #diff.AddedScripts > 0 then
        table.insert(lines, "### 📜 Discovered New Client Scripts & Modules")
        table.insert(lines, "New client-side logic controllers or shared libraries:")
        for _, s in ipairs(diff.AddedScripts) do
            table.insert(lines, string.format("- **`%s`** (`%s`): `%s`", s.Name, s.ClassName, s.Path))
        end
        table.insert(lines, "")
    end

    -- Added Tags
    if #diff.AddedTags > 0 then
        table.insert(lines, "### 🏷️ New CollectionService Tags")
        table.insert(lines, "New component tags for dynamic entity binding:")
        for _, t in ipairs(diff.AddedTags) do
            table.insert(lines, string.format("- **Tag:** `%s` (Applied to %d instances)", t.Tag, t.Count))
        end
        table.insert(lines, "")
    end

    -- Added Assets
    if #diff.AddedAssets > 0 then
        table.insert(lines, string.format("### 🎨 Newly Loaded Assets (%d items)", #diff.AddedAssets))
        table.insert(lines, "| Asset ID | Type | Sample Host | Instances |")
        table.insert(lines, "| --- | --- | --- | --- |")
        for i = 1, math.min(#diff.AddedAssets, 15) do
            local a = diff.AddedAssets[i]
            table.insert(lines, string.format("| `%s` | %s | %s | %d |", Utility.Truncate(a.Id, 25), a.Property, a.SampleHost, a.Count))
        end
        if #diff.AddedAssets > 15 then
            table.insert(lines, string.format("*...and %d more newly introduced assets.*", #diff.AddedAssets - 15))
        end
        table.insert(lines, "")
    end

    if diff.Summary.TotalChanges == 0 then
        table.insert(lines, "> **No structural changes detected between snapshots.** The game hierarchy and network endpoints remained static.")
    end

    return table.concat(lines, "\n")
end

-- Get all stored snapshots
function ContentTracker.GetSnapshots()
    return snapshotStore
end

return ContentTracker
