--[[
    LuauLens/modules/CodeAnalyzer.lua
    Script hierarchy crawler, framework detection, and component relationship mapping.
]]

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
        Category = "Controllers",
        Patterns = { "controller$", "client$", "input$", "movement$", "camera$" },
        Role = "Coordinates user input, camera manipulation, and local actor behavior."
    },
    {
        Category = "Services",
        Patterns = { "service$", "manager$", "handler$", "network$", "packet$" },
        Role = "Manages gameplay state, remote communication, and centralized subsystem APIs."
    },
    {
        Category = "UI",
        Patterns = { "component$", "view$", "screen$", "hud$", "window$", "modal$", "frame$", "gui$" },
        Role = "User interface presentation, HUD elements, and view-controller binding."
    },
    {
        Category = "Mechanics",
        Patterns = { "combat", "inventory", "shop", "quest", "skill", "weapon", "ability", "crafting" },
        Role = "Specific core gameplay loops and interactive game mechanics."
    },
    {
        Category = "State",
        Patterns = { "store$", "state$", "reducer$", "action$", "rodux", "replica" },
        Role = "Centralized state containers and client-server replicated data stores."
    },
    {
        Category = "Utilities",
        Patterns = { "util", "helper", "maid", "trove", "promise", "signal", "timer" },
        Role = "Reusable libraries, signal emitters, and memory lifecycle helpers."
    },
    {
        Category = "Configs",
        Patterns = { "config", "setting", "constant", "definition", "itemdata", "types" },
        Role = "Static definitions, game balances, item catalogs, and type annotations."
    }
}

-- Classify script based on naming patterns and parent service location
local function classifyScript(inst)
    local name = inst.Name:lower()
    local path = inst:GetFullName():lower()

    if path:find("playergui") or path:find("startergui") then
        return "UI", "Located inside GUI hierarchy; renders visual elements and binds HUD."
    end

    for _, rule in ipairs(CATEGORY_RULES) do
        for _, pat in ipairs(rule.Patterns) do
            if name:find(pat) then
                return rule.Category, rule.Role
            end
        end
    end

    if inst:IsA("LocalScript") then
        return "Controllers", "Standard client script executing local actor logic."
    else
        return "Shared Modules", "Reusable ModuleScript exposing functions, classes, or state."
    end
end

-- Detect prominent Roblox frameworks used in the project
local function detectFrameworks(scriptsList)
    local frameworks = {}

    local checks = {
        Knit = { Count = 0, Indicators = { "knit", "knitclient", "createservice", "createcontroller" } },
        Flamework = { Count = 0, Indicators = { "flamework", "@controller", "@component", "flamework-reflect" } },
        Roact = { Count = 0, Indicators = { "roact", "rodux", "roactrodux", "roact-spring" } },
        ReplicaService = { Count = 0, Indicators = { "replica", "replicaclient", "replicacontroller" } },
        MatterECS = { Count = 0, Indicators = { "matter", "ecs", "world.spawn", "system" } },
    }

    -- Check global namespace
    pcall(function()
        if _G.Knit or (shared and shared.Knit) then checks.Knit.Count = checks.Knit.Count + 10 end
        if _G.Flamework or (shared and shared.Flamework) then checks.Flamework.Count = checks.Flamework.Count + 10 end
    end)

    -- Check script names and paths
    for _, s in ipairs(scriptsList) do
        local n = s.Name:lower()
        local p = s.FullName:lower()
        for fw, data in pairs(checks) do
            for _, ind in ipairs(data.Indicators) do
                if n:find(ind) or p:find(ind) then
                    data.Count = data.Count + 1
                    break
                end
            end
        end
    end

    for fw, data in pairs(checks) do
        if data.Count > 0 then
            table.insert(frameworks, {
                Name = fw,
                Confidence = (data.Count >= 5) and "High" or ((data.Count >= 2) and "Moderate" or "Low"),
                Occurrences = data.Count
            })
        end
    end

    if #frameworks == 0 then
        table.insert(frameworks, {
            Name = "Modular Luau / Custom OOP",
            Confidence = "High",
            Occurrences = #scriptsList,
            Description = "Standard modular architecture using ModuleScripts and object-oriented metatables."
        })
    end

    return frameworks
end

-- Inspect CollectionService tags and component instances
local function analyzeTags()
    local tagsData = {}
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

        table.insert(tagsData, {
            TagName = tag,
            Count = #instances,
            SampleClass = instances[1] and instances[1].ClassName or "None",
            ClassDistribution = table.concat(classSummary, ", "),
            EducationalNote = string.format("Component tag '%s' applied to %d entities for dynamic behavior binding.", tag, #instances)
        })
    end

    table.sort(tagsData, function(a, b) return a.Count > b.Count end)
    return tagsData
end

-- Recursively scan a container for script objects
local function scanContainer(container, results, visited)
    if not container then return end
    if visited[container] then return end
    visited[container] = true

    local success, children = pcall(function()
        return container:GetChildren()
    end)
    if not success or not children then return end

    for _, child in ipairs(children) do
        local isScript = false
        if child:IsA("LocalScript") or child:IsA("ModuleScript") then
            isScript = true
        elseif child:IsA("Script") then
            pcall(function()
                if child.RunContext == Enum.RunContext.Client then isScript = true end
            end)
        end

        if isScript then
            local category, role = classifyScript(child)
            local tags = {}
            pcall(function() tags = Services.CollectionService:GetTags(child) end)

            local attributes = {}
            pcall(function() attributes = child:GetAttributes() end)

            table.insert(results, {
                Instance = child,
                Name = child.Name,
                ClassName = child.ClassName,
                FullName = child:GetFullName(),
                Category = category,
                Role = role,
                Tags = tags,
                Attributes = attributes,
                ParentName = child.Parent and child.Parent.Name or "None"
            })
        end

        -- Recurse unless large non-script 3D terrain
        if not (child:IsA("Terrain") or child:IsA("MeshPart") or child:IsA("BasePart")) then
            scanContainer(child, results, visited)
        end
    end
end

--[[
    CodeAnalyzer.ScanGameHierarchy()
    Recursively scans services (ReplicatedStorage, PlayerScripts, StarterGui, etc.),
    categorizes discovered scripts, detects active frameworks, and builds an architectural map.
]]
function CodeAnalyzer.ScanGameHierarchy()
    local scriptsList = {}
    local visited = {}

    local localPlayer = Services.Players.LocalPlayer
    local targets = {
        { Name = "ReplicatedStorage", Container = Services.ReplicatedStorage },
        { Name = "ReplicatedFirst", Container = Services.ReplicatedFirst },
        { Name = "StarterPlayer", Container = Services.StarterPlayer },
        { Name = "StarterGui", Container = Services.StarterGui },
        { Name = "Workspace", Container = Services.Workspace },
    }

    if localPlayer then
        local ps = localPlayer:FindFirstChild("PlayerScripts")
        if ps then table.insert(targets, 1, { Name = "PlayerScripts", Container = ps }) end
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(targets, 2, { Name = "PlayerGui", Container = pg }) end
    end

    for _, target in ipairs(targets) do
        scanContainer(target.Container, scriptsList, visited)
    end

    -- Group scripts by category
    local categories = {}
    for _, s in ipairs(scriptsList) do
        categories[s.Category] = categories[s.Category] or {}
        table.insert(categories[s.Category], s)
    end

    local frameworks = detectFrameworks(scriptsList)
    local tags = analyzeTags()

    return {
        Timestamp = os.time(),
        TotalScripts = #scriptsList,
        Scripts = scriptsList,
        Categories = categories,
        Frameworks = frameworks,
        Tags = tags,
    }
end

return CodeAnalyzer
