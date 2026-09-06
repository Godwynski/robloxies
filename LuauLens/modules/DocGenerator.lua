--[[
    LuauLens/modules/DocGenerator.lua
    Generates developer-facing Markdown documentation, system architecture specifications,
    and Mermaid sequence/flow diagrams from analyzed game data.
]]

local DocGenerator = {}

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

--[[
    DocGenerator.GenerateArchitectureDiagram(analysisData)
    Constructs a Mermaid graph TD diagram mapping client controllers, services, and remotes.
]]
function DocGenerator.GenerateArchitectureDiagram(analysisData)
    local lines = {}
    table.insert(lines, "```mermaid")
    table.insert(lines, "graph TD")
    table.insert(lines, "    subgraph Client [Client Runtime Environment]")
    table.insert(lines, "        PlayerInput[User Input & Movement]")
    table.insert(lines, "        HUDView[PlayerGui / HUD Presentation]")

    local categories = analysisData and analysisData.Categories or {}
    if categories["Controllers"] and #categories["Controllers"] > 0 then
        table.insert(lines, "        subgraph Controllers [Client Controllers]")
        for i = 1, math.min(#categories["Controllers"], 4) do
            local c = categories["Controllers"][i]
            table.insert(lines, string.format('            Ctrl_%d["%s"]', i, c.Name))
        end
        table.insert(lines, "        end")
    end

    if categories["Mechanics"] and #categories["Mechanics"] > 0 then
        table.insert(lines, "        subgraph Mechanics [Game Mechanics]")
        for i = 1, math.min(#categories["Mechanics"], 4) do
            local m = categories["Mechanics"][i]
            table.insert(lines, string.format('            Mech_%d["%s"]', i, m.Name))
        end
        table.insert(lines, "        end")
    end

    table.insert(lines, "        PlayerInput --> Controllers")
    table.insert(lines, "        Controllers --> HUDView")
    table.insert(lines, "    end")

    -- Network layer
    table.insert(lines, "    subgraph ReplicatedStorage [ReplicatedStorage / Network Layer]")
    table.insert(lines, '        RemoteLayer["RemoteEvents & RemoteFunctions"]')
    table.insert(lines, "        Controllers -.->|FireServer / InvokeServer| RemoteLayer")
    table.insert(lines, "    end")

    -- Server layer
    table.insert(lines, "    subgraph Server [Roblox Authoritative Server]")
    table.insert(lines, "        ServerLogic[Server Authority & Combat Formulas]")
    table.insert(lines, "        DataStore[(PlayerData / DataStores)]")
    table.insert(lines, "        RemoteLayer --> ServerLogic")
    table.insert(lines, "        ServerLogic --> DataStore")
    table.insert(lines, "    end")

    table.insert(lines, "```")
    return table.concat(lines, "\n")
end

--[[
    DocGenerator.GenerateSequenceDiagram(systemName, sampleRemote)
    Generates a Mermaid sequenceDiagram illustrating the client prediction & server validation flow.
]]
function DocGenerator.GenerateSequenceDiagram(systemName, sampleRemote)
    systemName = systemName or "Gameplay"
    sampleRemote = sampleRemote or "ActionRequest"

    local lines = {
        "```mermaid",
        "sequenceDiagram",
        "    autonumber",
        "    actor Player as Player Client",
        "    participant Controller as Client Controller",
        "    participant HUD as Player HUD View",
        "    participant Remote as " .. sampleRemote,
        "    participant Server as Server Authoritative Handler",
        "    participant Store as Server DataStore",
        "",
        "    Player->>Controller: Triggers Input (Keybind / Click)",
        "    activate Controller",
        "    Note over Controller: Client Prediction:<br/>Play local animation & sound immediately",
        "    Controller->>HUD: Update cooldown and crosshair",
        "    Controller->>Remote: FireServer(ActionIntent, TargetId, Timestamp)",
        "    deactivate Controller",
        "",
        "    activate Remote",
        "    Remote->>Server: Network Packet Transmission",
        "    deactivate Remote",
        "",
        "    activate Server",
        "    Note over Server: Authoritative Verification:<br/>1. Check cooldown timers<br/>2. Verify player-to-target distance<br/>3. Verify state permissions",
        "    alt Valid Request",
        "        Server->>Store: Persist State Change (XP, HP, Gold)",
        "        Server-->>Remote: Replicate State Broadcast",
        "        Remote-->>Player: Confirm Action Outcome",
        "    else Invalid / Out of Sync",
        "        Server-->>Player: Trigger State Reconciliation / Reject",
        "    end",
        "    deactivate Server",
        "```"
    }

    return table.concat(lines, "\n")
end

--[[
    DocGenerator.GenerateFullReport(analysisData, networkData)
    Compiles code analysis and network data into a single, comprehensive Markdown document.
]]
function DocGenerator.GenerateFullReport(analysisData, networkData)
    local lines = {}
    local timeStr = os.date("%Y-%m-%d %H:%M:%S")

    analysisData = analysisData or {}
    networkData = networkData or {}

    table.insert(lines, "# 🎓 LuauLens Diagnostic & Architecture Report")
    table.insert(lines, string.format("*Generated on %s | PlaceId: %s | Environment Memory: %.1f MB*",
        timeStr, tostring(game.PlaceId), Utility.GetMemoryUsageMB()))
    table.insert(lines, "")

    -- 1. Architecture Overview
    table.insert(lines, "## 1. High-Level Architecture & Frameworks")
    local frameworks = analysisData.Frameworks or {}
    local fwStrings = {}
    for _, f in ipairs(frameworks) do
        table.insert(fwStrings, string.format("**%s** (%s confidence)", f.Name, f.Confidence))
    end
    table.insert(lines, string.format("- **Primary Framework:** %s", #fwStrings > 0 and table.concat(fwStrings, ", ") or "Modular Luau"))
    table.insert(lines, string.format("- **Total Client Scripts:** %d", analysisData.TotalScripts or 0))
    table.insert(lines, string.format("- **Network Remotes Logged:** %d events", #networkData))
    table.insert(lines, "")
    table.insert(lines, "### System Architecture Flow")
    table.insert(lines, DocGenerator.GenerateArchitectureDiagram(analysisData))
    table.insert(lines, "")

    -- 2. Client Scripts Breakdown
    table.insert(lines, "## 2. Client Component Decomposition")
    local categories = analysisData.Categories or {}
    for catName, scripts in pairs(categories) do
        table.insert(lines, string.format("### %s (%d modules)", catName, #scripts))
        table.insert(lines, string.format("*%s*", scripts[1] and scripts[1].Role or "Module component"))
        table.insert(lines, "")
        table.insert(lines, "| Script Name | Class | Hierarchy Path | Tags |")
        table.insert(lines, "| --- | --- | --- | --- |")
        for i = 1, math.min(#scripts, 10) do
            local s = scripts[i]
            local tagCount = s.Tags and #s.Tags or 0
            table.insert(lines, string.format("| `%s` | %s | `%s` | %d |", s.Name, s.ClassName, Utility.Truncate(s.FullName, 40), tagCount))
        end
        if #scripts > 10 then
            table.insert(lines, string.format("*...and %d more modules in %s.*", #scripts - 10, catName))
        end
        table.insert(lines, "")
    end

    -- 3. CollectionService Tags
    local tags = analysisData.Tags or {}
    if #tags > 0 then
        table.insert(lines, "## 3. Entity-Component System (CollectionService)")
        table.insert(lines, "| Tag Name | Instance Count | Class Distribution | Role |")
        table.insert(lines, "| --- | --- | --- | --- |")
        for _, t in ipairs(tags) do
            table.insert(lines, string.format("| `%s` | %d | %s | %s |", t.TagName, t.Count, Utility.Truncate(t.ClassDistribution, 25), t.EducationalNote))
        end
        table.insert(lines, "")
    end

    -- 4. Network Contracts
    table.insert(lines, "## 4. Network Remote Contracts & Security Analysis")
    table.insert(lines, "| Timestamp | Method | Remote Name | System | Caller Script | Arguments Signature |")
    table.insert(lines, "| --- | --- | --- | --- | --- | --- |")
    for i = 1, math.min(#networkData, 15) do
        local pkt = networkData[i]
        local sig = "(" .. table.concat(pkt.ArgTypes, ", ") .. ")"
        table.insert(lines, string.format("| %s | `%s` | **`%s`** | %s | `%s` | `%s` |",
            pkt.Timestamp, pkt.Method, pkt.RemoteName, pkt.System, Utility.Truncate(pkt.Caller, 25), sig))
    end
    if #networkData == 0 then
        table.insert(lines, "> *No network traffic captured yet. Interact with the experience to log remote calls.*")
    end
    table.insert(lines, "")

    -- 5. Interaction Sequence Flow
    table.insert(lines, "## 5. Interaction Sequence Flow (Client Prediction & Server Authority)")
    table.insert(lines, DocGenerator.GenerateSequenceDiagram("Gameplay", "GameplayRemote"))
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

--[[
    DocGenerator.GenerateTutorial(topic)
    Generates a comprehensive educational Luau code tutorial.
]]
function DocGenerator.GenerateTutorial(topic)
    local lines = {
        "# 📚 Educational Guide: Writing Secure, Scalable Luau Systems",
        "",
        "## Principle 1: The Client-Server Security Boundary (Never Trust the Client)",
        "Because client memory is in the hands of the user, client-side calculations must never dictate server authority.",
        "",
        "### ❌ Vulnerable Pattern (Client decides damage)",
        "```lua",
        "-- CLIENT",
        "Remote:FireServer(targetEnemy, 50) -- Exploitable: Client controls the damage number!",
        "```",
        "",
        "### ✅ Secure Authoritative Pattern (Server validates and computes)",
        "```lua",
        "-- SERVER",
        "Remote.OnServerEvent:Connect(function(player, targetEnemy)",
        "    local char = player.Character",
        "    if not char or not char:FindFirstChild('Humanoid') or char.Humanoid.Health <= 0 then return end",
        "    ",
        "    -- 1. Anti-spam & Cooldown check",
        "    if not CombatManager.CanAttack(player) then return end",
        "    ",
        "    -- 2. Spatial distance check",
        "    local dist = (char.PrimaryPart.Position - targetEnemy.PrimaryPart.Position).Magnitude",
        "    if dist > CombatConfig.MAX_WEAPON_RANGE then return end",
        "    ",
        "    -- 3. Calculate damage server-side",
        "    local weapon = InventoryManager.GetEquippedWeapon(player)",
        "    local damage = CombatFormula.Calculate(weapon, targetEnemy)",
        "    targetEnemy.Humanoid:TakeDamage(damage)",
        "end)",
        "```",
        "",
        "## Principle 2: Component-Driven Architecture via CollectionService",
        "Instead of duplicating scripts inside hundreds of instances, bind behavior dynamically using Tags:",
        "```lua",
        "local CollectionService = game:GetService('CollectionService')",
        "local TAG = 'InteractableChest'",
        "",
        "local function onChestAdded(chestModel)",
        "    local prompt = chestModel:WaitForChild('ProximityPrompt')",
        "    prompt.Triggered:Connect(function(player)",
        "        print(player.Name .. ' opened ' .. chestModel.Name)",
        "    end)",
        "end",
        "",
        "for _, inst in ipairs(CollectionService:GetTagged(TAG)) do onChestAdded(inst) end",
        "CollectionService:GetInstanceAddedSignal(TAG):Connect(onChestAdded)",
        "```"
    }

    return table.concat(lines, "\n")
end

return DocGenerator
