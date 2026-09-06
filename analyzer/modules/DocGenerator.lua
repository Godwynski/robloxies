-- analyzer/modules/DocGenerator.lua
-- Educational Documentation Generator: Generates architecture specs, Mermaid diagrams, and Luau tutorials

local Utility = require("analyzer.modules.Utility")

local DocGenerator = {}

-- Generates a Mermaid architecture diagram representing component relationships
function DocGenerator.GenerateArchitectureDiagram(analysisData)
    local lines = {}
    table.insert(lines, "```mermaid")
    table.insert(lines, "graph TD")
    table.insert(lines, "    subgraph Client [Client Runtime Environment]")
    table.insert(lines, "        PlayerInput[User Input & Camera]")
    table.insert(lines, "        UI[PlayerGui / HUD Views]")

    local scriptNodes = {}
    local categories = analysisData.CodeAnalysis and analysisData.CodeAnalysis.Categories or {}

    -- Group controllers
    if categories["Controller"] and #categories["Controller"] > 0 then
        table.insert(lines, "        subgraph Controllers [Client Controllers]")
        for i = 1, math.min(#categories["Controller"], 4) do
            local s = categories["Controller"][i]
            local id = "Ctrl_" .. i
            table.insert(lines, string.format('            %s["%s"]', id, s.Name))
            table.insert(scriptNodes, id)
        end
        table.insert(lines, "        end")
    end

    -- Group mechanics
    if categories["Game Mechanic"] and #categories["Game Mechanic"] > 0 then
        table.insert(lines, "        subgraph Mechanics [Game Mechanics]")
        for i = 1, math.min(#categories["Game Mechanic"], 4) do
            local s = categories["Game Mechanic"][i]
            local id = "Mech_" .. i
            table.insert(lines, string.format('            %s["%s"]', id, s.Name))
            table.insert(scriptNodes, id)
        end
        table.insert(lines, "        end")
    end

    table.insert(lines, "        PlayerInput --> Controllers")
    table.insert(lines, "        Controllers --> UI")
    table.insert(lines, "    end")

    -- Shared / Network remotes
    table.insert(lines, "    subgraph ReplicatedStorage [ReplicatedStorage / Network Layer]")
    local netStats = analysisData.NetworkStats or {}
    local remoteCount = 0
    for path, stat in pairs(netStats) do
        remoteCount = remoteCount + 1
        if remoteCount <= 5 then
            local rId = "Rem_" .. remoteCount
            table.insert(lines, string.format('        %s["%s (%s)"]', rId, stat.Name, stat.System or "Remote"))
            table.insert(lines, string.format("        Controllers -.->|Fire/Invoke| %s", rId))
        end
    end
    if remoteCount == 0 then
        table.insert(lines, '        Rem_Default["RemoteEvents & RemoteFunctions"]')
        table.insert(lines, "        Controllers -.->|FireServer| Rem_Default")
    end
    table.insert(lines, "    end")

    -- Server
    table.insert(lines, "    subgraph Server [Roblox Server Services]")
    table.insert(lines, "        ServerLogic[Server Authority & Validation]")
    table.insert(lines, "        DataStore[(PlayerData & DataStores)]")
    if remoteCount > 0 then
        for i = 1, math.min(remoteCount, 5) do
            table.insert(lines, string.format("        Rem_%d --> ServerLogic", i))
        end
    else
        table.insert(lines, "        Rem_Default --> ServerLogic")
    end
    table.insert(lines, "        ServerLogic --> DataStore")
    table.insert(lines, "    end")

    table.insert(lines, "```")
    return table.concat(lines, "\n")
end

-- Generates a Mermaid sequence diagram showing typical gameplay interaction loops
function DocGenerator.GenerateSequenceDiagram(systemName, sampleRemote)
    systemName = systemName or "Combat"
    sampleRemote = sampleRemote or "AttackEvent"

    local lines = {
        "```mermaid",
        "sequenceDiagram",
        "    autonumber",
        "    actor Player as Player / Local Client",
        "    participant Controller as Client Controller",
        "    participant UI as HUD / Feedback UI",
        "    participant Remote as ReplicatedStorage." .. sampleRemote,
        "    participant Server as Server Authoritative Logic",
        "    participant DB as Server DataStore / MemoryCache",
        "",
        "    Player->>Controller: Triggers Input Action (e.g. Click / Keypress)",
        "    activate Controller",
        "    Note over Controller: Perform client prediction & instant local VFX",
        "    Controller->>UI: Show immediate local animation/sound",
        "    Controller->>Remote: FireServer(ActionData, TargetId, Timestamp)",
        "    deactivate Controller",
        "",
        "    activate Remote",
        "    Remote->>Server: Deliver Packet over Network Layer",
        "    deactivate Remote",
        "",
        "    activate Server",
        "    Note over Server: Server Security & Sanity Checks:<br/>1. Verify Player distance & Line-of-Sight<br/>2. Validate Cooldowns & Stamina<br/>3. Verify inventory/equipped weapon",
        "    alt Valid Request",
        "        Server->>DB: Mutate Game State (Deduct HP, Award XP)",
        "        Server-->>Remote: Replicate State / Broadcast Effects to Clients",
        "        Remote-->>Player: Confirm State Update (Reliable Replication)",
        "    else Invalid or Desynchronized Request",
        "        Server-->>Player: Reconcile / Reject Action",
        "    end",
        "    deactivate Server",
        "```"
    }

    return table.concat(lines, "\n")
end

-- Generates the comprehensive Educational Architecture Document
function DocGenerator.GenerateArchitectureReport(analysisData)
    local lines = {}
    local timeStr = os.date("%Y-%m-%d %H:%M:%S")

    table.insert(lines, "# 🎓 Educational Game Architecture & Systems Specification")
    table.insert(lines, string.format("*Generated by LuauLens on %s | PlaceId: %s | Engine Memory: %.1f MB*",
        timeStr, tostring(game.PlaceId), Utility.GetMemoryUsageMB()))
    table.insert(lines, "")

    -- Section 1: Executive Architectural Overview
    table.insert(lines, "## 1. Architectural Overview & Design Patterns")
    local frameworks = analysisData.CodeAnalysis and analysisData.CodeAnalysis.Frameworks or {}
    local fwNames = {}
    for _, fw in ipairs(frameworks) do
        table.insert(fwNames, string.format("**%s** (%s confidence)", fw.Name, fw.Confidence))
    end

    table.insert(lines, string.format("- **Primary Framework / Pattern:** %s", table.concat(fwNames, ", ")))
    table.insert(lines, string.format("- **Total Discovered Client Scripts:** %d", analysisData.CodeAnalysis and analysisData.CodeAnalysis.TotalScripts or 0))
    table.insert(lines, string.format("- **Active Network Endpoints:** %d Remotes Monitored", analysisData.TotalRemotes or 0))
    table.insert(lines, "")
    table.insert(lines, "### System Architecture Diagram")
    table.insert(lines, DocGenerator.GenerateArchitectureDiagram(analysisData))
    table.insert(lines, "")

    -- Section 2: Component Breakdown & Categorization
    table.insert(lines, "## 2. Client-Side Component Breakdown")
    table.insert(lines, "The client experience is decomposed into discrete architectural layers:")
    table.insert(lines, "")

    local categories = analysisData.CodeAnalysis and analysisData.CodeAnalysis.Categories or {}
    for catName, scripts in pairs(categories) do
        table.insert(lines, string.format("### %s (%d modules)", catName, #scripts))
        table.insert(lines, string.format("*%s*", scripts[1].Description or "Client logic module"))
        table.insert(lines, "")
        table.insert(lines, "| Script Name | Class | Service Location | Attributes/Tags |")
        table.insert(lines, "| --- | --- | --- | --- |")
        for i = 1, math.min(#scripts, 8) do
            local s = scripts[i]
            local tagCount = s.Tags and #s.Tags or 0
            table.insert(lines, string.format("| `%s` | %s | `%s` | %d tags |", s.Name, s.ClassName, Utility.Truncate(s.FullName, 35), tagCount))
        end
        if #scripts > 8 then
            table.insert(lines, string.format("*...and %d more modules in this category.*", #scripts - 8))
        end
        table.insert(lines, "")
    end

    -- Section 3: CollectionService Tags & Composition
    local tags = analysisData.CodeAnalysis and analysisData.CodeAnalysis.Tags or {}
    if #tags > 0 then
        table.insert(lines, "## 3. Entity-Component Composition (CollectionService)")
        table.insert(lines, "Rather than hardcoding script logic onto individual Workspace objects, modern Roblox experiences use `CollectionService` tags to bind behavior declaratively:")
        table.insert(lines, "")
        table.insert(lines, "| Component Tag | Active Instances | Target Classes | Educational Role |")
        table.insert(lines, "| --- | --- | --- | --- |")
        for _, t in ipairs(tags) do
            table.insert(lines, string.format("| `%s` | %d | %s | %s |", t.TagName, t.Count, Utility.Truncate(t.ClassDistribution, 25), t.EducationalNote))
        end
        table.insert(lines, "")
    end

    -- Section 4: Network Communication Specification
    table.insert(lines, "## 4. Network Communication Specification & Remote Contracts")
    table.insert(lines, "The client-server boundary is defined by RemoteEvents and RemoteFunctions:")
    table.insert(lines, "")
    table.insert(lines, "| Remote Name | Classification | Direction | Observed Signatures | Calls | Security Validation Considerations |")
    table.insert(lines, "| --- | --- | --- | --- | --- | --- |")

    local netStats = analysisData.NetworkStats or {}
    for path, stat in pairs(netStats) do
        local sigs = {}
        for sig, _ in pairs(stat.ArgSignatures or {}) do
            table.insert(sigs, "(" .. (sig == "" and "void" or sig) .. ")")
        end
        local sigStr = #sigs > 0 and table.concat(sigs, " <br> ") or "(void)"

        local secNote = "Validate caller distance and state permissions"
        if stat.System:find("Combat") then
            secNote = "⚠️ **Crucial:** Server must compute damage and verify hitbox line-of-sight"
        elseif stat.System:find("Economy") then
            secNote = "🔒 **Strict:** Never trust price from client; query server item catalog"
        elseif stat.System:find("Movement") then
            secNote = "⏱️ **Anti-Exploit:** Enforce maximum velocity and sanity-check delta time"
        end

        table.insert(lines, string.format("| `%s` | %s | %s | %s | %d | %s |",
            stat.Name, stat.System or "General", "Bidirectional", sigStr, stat.Count, secNote))
    end
    table.insert(lines, "")

    -- Section 5: Interaction Flow Diagram
    table.insert(lines, "## 5. Client-Server Interaction Sequence")
    table.insert(lines, DocGenerator.GenerateSequenceDiagram("Gameplay", "GameplayEvent"))
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

-- Generates a step-by-step educational tutorial teaching observed patterns
function DocGenerator.GenerateTutorial(topic)
    topic = topic or "Architecture"

    local tutorial = {
        "# 📚 Educational Guide: Modern Roblox Software Architecture",
        "",
        "## Overview",
        "Studying real-world Roblox experiences reveals crucial software design principles necessary for scalable, secure, and maintainable multiplayer games.",
        "",
        "---",
        "",
        "## Core Concept 1: The Client-Server Security Boundary (Never Trust the Client)",
        "",
        "### ❌ The Vulnerable Anti-Pattern",
        "Many beginner developers mistakenly allow the client to determine game outcomes directly (e.g. sending damage values or item prices over RemoteEvents):",
        "",
        "```lua",
        "-- CLIENT (Vulnerable)",
        "local DamageRemote = game:GetService('ReplicatedStorage').DealDamage",
        "DamageRemote:FireServer(enemyHumanoid, 50) -- Client decides damage number!",
        "",
        "-- SERVER (Vulnerable)",
        "DamageRemote.OnServerEvent:Connect(function(player, targetHumanoid, damage)",
        "    targetHumanoid:TakeDamage(damage) -- Server blindly trusts client!",
        "end)",
        "```",
        "",
        "### ✅ The Robust Authoritative Pattern",
        "In professional experiences, the client only sends *intent*, while the server calculates and enforces the outcome:",
        "",
        "```lua",
        "-- CLIENT (Intent-Only)",
        "local AttackRemote = game:GetService('ReplicatedStorage').PerformAttack",
        "AttackRemote:FireServer(targetCharacter) -- Client simply requests the attack",
        "",
        "-- SERVER (Authoritative Validation)",
        "AttackRemote.OnServerEvent:Connect(function(player, targetCharacter)",
        "    -- 1. Verify Player state",
        "    local char = player.Character",
        "    if not char or not char:FindFirstChild('Humanoid') or char.Humanoid.Health <= 0 then return end",
        "",
        "    -- 2. Verify cooldown & stamina",
        "    if not CombatManager.CanAttack(player) then return end",
        "",
        "    -- 3. Verify spatial distance (sanity check against teleport/range exploits)",
        "    local dist = (char.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude",
        "    if dist > CombatConfig.MAX_WEAPON_RANGE then return end",
        "",
        "    -- 4. Server computes authentic damage from inventory stats",
        "    local weapon = InventoryManager.GetEquippedWeapon(player)",
        "    local finalDamage = CombatFormula.Calculate(weapon, targetCharacter)",
        "    targetCharacter.Humanoid:TakeDamage(finalDamage)",
        "end)",
        "```",
        "",
        "---",
        "",
        "## Core Concept 2: Component-Driven Design with CollectionService",
        "",
        "Instead of pasting scripts into hundreds of parts or models, modern Roblox developers use **Tags** and a single centralized component controller.",
        "",
        "### Component Implementation Example",
        "```lua",
        "-- ReplicatedStorage.Components.ChestComponent",
        "local CollectionService = game:GetService('CollectionService')",
        "local TAG_NAME = 'LootChest'",
        "",
        "local ChestComponent = {}",
        "ChestComponent.__index = ChestComponent",
        "",
        "function ChestComponent.new(instance)",
        "    local self = setmetatable({}, ChestComponent)",
        "    self.Instance = instance",
        "    self.Prompt = instance:WaitForChild('ProximityPrompt')",
        "",
        "    self.Connection = self.Prompt.Triggered:Connect(function(player)",
        "        self:OnTriggered(player)",
        "    end)",
        "    return self",
        "end",
        "",
        "function ChestComponent:OnTriggered(player)",
        "    print(player.Name .. ' opened chest: ' .. self.Instance.Name)",
        "end",
        "",
        "function ChestComponent:Destroy()",
        "    if self.Connection then self.Connection:Disconnect() end",
        "end",
        "",
        "-- Centralized lifecycle binding",
        "for _, inst in ipairs(CollectionService:GetTagged(TAG_NAME)) do",
        "    ChestComponent.new(inst)",
        "end",
        "",
        "CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(function(inst)",
        "    ChestComponent.new(inst)",
        "end)",
        "```",
        "",
        "---",
        "",
        "## Core Concept 3: Client Prediction & Responsiveness",
        "",
        "Because network packets take 30–150ms to reach the server and return, waiting for server confirmation before showing any visual feedback creates perceptible input lag.",
        "- **Immediate Local Feedback:** Play swing animation and sound effects instantly on the client when the key is pressed.",
        "- **Authoritative Reconciliation:** If the server rejects the action (e.g. cooldown was active), gently revert or reset the client's visual state.",
        "",
        "---",
        "",
        "## Summary Checklist for Robust Game Development",
        "1. **Single Source of Truth:** Never store master inventory, money, or stats on the client.",
        "2. **Rate Limiting:** Throttle incoming RemoteEvents on the server to prevent packet flooding.",
        "3. **Decoupled Architecture:** Use Signals, Controllers, and Components rather than monolithic spaghetti scripts.",
        "4. **Memory Hygiene:** Always clean up Connections using Maid, Trove, or Janitor patterns when instances are destroyed."
    }

    return table.concat(tutorial, "\n")
end

return DocGenerator
