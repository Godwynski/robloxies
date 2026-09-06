-- analyzer/modules/CodeAnalyzer.lua
-- Client-Side Code Analysis: Script extraction, structural decomposition, framework detection, and component relationships

local CodeAnalyzer = {}

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ReplicatedFirst = game:GetService("ReplicatedFirst"),
    StarterPlayer = game:GetService("StarterPlayer"),
    StarterGui = game:GetService("StarterGui"),
    CollectionService = game:GetService("CollectionService"),
    Workspace = game:GetService("Workspace"),
}

local CATEGORY_RULES = {
    {
        Category = "Controller",
        Matches = { "controller$", "client$", "input$", "movement$", "camera$", "character$" },
        Description = "Client-side controller coordinating user inputs, camera, and local actor behavior"
    },
    {
        Category = "Game Mechanic",
        Matches = { "combat", "inventory", "shop", "quest", "skill", "weapon", "ability", "crafting", "mining", "building", "racing", "dialog" },
        Description = "Core gameplay mechanic orchestrator"
    },
    {
        Category = "Network Adapter",
        Matches = { "network", "remote", "packet", "eventhandler", "clientcomm", "replicaclient", "bridge" },
        Description = "Handles client-server remote communication and packet serialization"
    },
    {
        Category = "UI Component",
        Matches = { "component$", "view$", "screen$", "hud$", "window$", "modal$", "frame$", "gui$" },
        Description = "User interface rendering, HUD elements, and view-controller binding"
    },
    {
        Category = "State Store",
        Matches = { "store$", "state$", "reducer$", "action$", "rodux", "replica", "atom" },
        Description = "Client-side state management, centralized data store, or replicated cache"
    },
    {
        Category = "Utility & Helper",
        Matches = { "util", "helper", "maid", "trove", "promise", "signal", "fastsignal", "goodsignal", "timer" },
        Description = "General-purpose utility library or memory management helper"
    },
    {
        Category = "Config & Data",
        Matches = { "config", "setting", "constant", "definition", "itemdata", "types", "table" },
        Description = "Static game configuration, asset tables, or constant definitions"
    },
}

-- Classify a script based on its name and parent hierarchy
local function classifyScript(inst)
    local name = inst.Name:lower()
    local parentPath = inst:GetFullName():lower()

    -- Check if inside PlayerGui or StarterGui
    if parentPath:find("playergui") or parentPath:find("startergui") then
        return "UI Component", "Located inside GUI tree; manages visual interface and user HUD"
    end

    for _, rule in ipairs(CATEGORY_RULES) do
        for _, pattern in ipairs(rule.Matches) do
            if name:find(pattern) then
                return rule.Category, rule.Description
            end
        end
    end

    if inst:IsA("LocalScript") then
        return "Local Controller", "Standard client script executing local logic"
    elseif inst:IsA("ModuleScript") then
        return "Shared Module", "Reusable module exposing functions, classes, or state"
    else
        return "Client Script", "Client-executing script instance"
    end
end

-- Inspect source code or decompile if permitted (for educational AST / pattern detection)
local function getScriptSourceInfo(inst)
    local hasSource = false
    local lineCount = 0
    local sourcePreview = ""

    pcall(function()
        -- In Roblox Studio, script.Source is directly readable
        if inst.Source and type(inst.Source) == "string" and #inst.Source > 0 then
            hasSource = true
            local lines = inst.Source:split("\n")
            lineCount = #lines
            sourcePreview = inst.Source:sub(1, 200)
        end
    end)

    if not hasSource and type(decompile) == "function" then
        pcall(function()
            local decomp = decompile(inst)
            if decomp and type(decomp) == "string" and #decomp > 0 then
                hasSource = true
                local lines = decomp:split("\n")
                lineCount = #lines
                sourcePreview = decomp:sub(1, 200)
            end
        end)
    end

    return {
        HasSource = hasSource,
        LineCount = lineCount,
        SourcePreview = sourcePreview,
    }
end

-- Scan a container recursively for script instances
local function scanContainer(container, results, visited)
    if not container then return end
    if visited[container] then return end
    visited[container] = true

    local success, children = pcall(function()
        return container:GetChildren()
    end)
    if not success or not children then return end

    for _, child in ipairs(children) do
        local isClientScript = false
        if child:IsA("LocalScript") or child:IsA("ModuleScript") then
            isClientScript = true
        elseif child:IsA("Script") then
            pcall(function()
                if child.RunContext == Enum.RunContext.Client then
                    isClientScript = true
                end
            end)
        end

        if isClientScript then
            local category, catDesc = classifyScript(child)
            local srcInfo = getScriptSourceInfo(child)
            local tags = {}
            pcall(function()
                tags = Services.CollectionService:GetTags(child)
            end)

            local attributes = {}
            pcall(function()
                attributes = child:GetAttributes()
            end)

            table.insert(results, {
                Instance = child,
                Name = child.Name,
                ClassName = child.ClassName,
                FullName = child:GetFullName(),
                Category = category,
                Description = catDesc,
                Tags = tags,
                Attributes = attributes,
                ParentName = child.Parent and child.Parent.Name or "None",
                SourceInfo = srcInfo,
            })
        end

        -- Recurse unless it's a huge non-script hierarchy
        if not (child:IsA("Terrain") or child:IsA("MeshPart") or child:IsA("BasePart")) then
            scanContainer(child, results, visited)
        end
    end
end

-- Detect prominent Roblox frameworks used in the experience
function CodeAnalyzer.DetectFrameworks(scriptsList)
    local frameworks = {}

    local checks = {
        Knit = { Count = 0, Indicators = { "knit", "knitclient", "createservice", "createcontroller" } },
        Flamework = { Count = 0, Indicators = { "flamework", "@controller", "@component", "flamework-reflect" } },
        Roact = { Count = 0, Indicators = { "roact", "rodux", "roactrodux", "roact-spring" } },
        ReplicaService = { Count = 0, Indicators = { "replica", "replicaclient", "replicacontroller" } },
        MatterECS = { Count = 0, Indicators = { "matter", "ecs", "world.spawn", "system" } },
        RedNetworking = { Count = 0, Indicators = { "red", "red.client", "red.server" } },
    }

    for _, item in ipairs(scriptsList) do
        local nameLower = item.Name:lower()
        local pathLower = item.FullName:lower()

        for fwName, fwData in pairs(checks) do
            for _, ind in ipairs(fwData.Indicators) do
                if nameLower:find(ind) or pathLower:find(ind) then
                    fwData.Count = fwData.Count + 1
                    break
                end
            end
        end
    end

    for fwName, fwData in pairs(checks) do
        if fwData.Count > 0 then
            table.insert(frameworks, {
                Name = fwName,
                Confidence = fwData.Count >= 3 and "High" or (fwData.Count >= 1 and "Moderate" or "Low"),
                Occurrences = fwData.Count,
            })
        end
    end

    if #frameworks == 0 then
        table.insert(frameworks, {
            Name = "Standard Modular Luau / Custom OOP",
            Confidence = "High",
            Occurrences = #scriptsList,
            Description = "Standard Roblox module hierarchy using ModuleScripts, LocalScripts, and metatables"
        })
    end

    return frameworks
end

-- Analyze CollectionService tags and component bindings
function CodeAnalyzer.AnalyzeTags()
    local tagReport = {}
    local tags = {}
    pcall(function()
        tags = Services.CollectionService:GetAllTags()
    end)

    for _, tag in ipairs(tags) do
        local instances = {}
        pcall(function()
            instances = Services.CollectionService:GetTagged(tag)
        end)

        local classCounts = {}
        for _, inst in ipairs(instances) do
            classCounts[inst.ClassName] = (classCounts[inst.ClassName] or 0) + 1
        end

        local classSummary = {}
        for cls, count in pairs(classCounts) do
            table.insert(classSummary, string.format("%s (%d)", cls, count))
        end

        table.insert(tagReport, {
            TagName = tag,
            Count = #instances,
            SampleClass = instances[1] and instances[1].ClassName or "None",
            ClassDistribution = table.concat(classSummary, ", "),
            EducationalNote = string.format("Component tag '%s' applied to %d instances for dynamic behavior binding", tag, #instances)
        })
    end

    table.sort(tagReport, function(a, b)
        return a.Count > b.Count
    end)

    return tagReport
end

-- Perform complete client-side code analysis across all accessible services
function CodeAnalyzer.RunAnalysis()
    local scriptsList = {}
    local visited = {}

    local localPlayer = Services.Players.LocalPlayer
    local scanTargets = {
        { Name = "ReplicatedStorage", Container = Services.ReplicatedStorage },
        { Name = "ReplicatedFirst", Container = Services.ReplicatedFirst },
        { Name = "StarterPlayer", Container = Services.StarterPlayer },
        { Name = "StarterGui", Container = Services.StarterGui },
        { Name = "Workspace", Container = Services.Workspace },
    }

    if localPlayer then
        local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            table.insert(scanTargets, 1, { Name = "PlayerScripts", Container = playerScripts })
        end
        local playerGui = localPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            table.insert(scanTargets, 2, { Name = "PlayerGui", Container = playerGui })
        end
    end

    for _, target in ipairs(scanTargets) do
        scanContainer(target.Container, scriptsList, visited)
    end

    -- Group by category
    local categoryGroups = {}
    for _, s in ipairs(scriptsList) do
        categoryGroups[s.Category] = categoryGroups[s.Category] or {}
        table.insert(categoryGroups[s.Category], s)
    end

    local frameworks = CodeAnalyzer.DetectFrameworks(scriptsList)
    local tags = CodeAnalyzer.AnalyzeTags()

    return {
        Timestamp = os.time(),
        TotalScripts = #scriptsList,
        Scripts = scriptsList,
        Categories = categoryGroups,
        Frameworks = frameworks,
        Tags = tags,
    }
end

return CodeAnalyzer
