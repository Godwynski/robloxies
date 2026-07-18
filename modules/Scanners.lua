return function(Core)
    local Scanners = {}

    local CollectionService = Core.Services.CollectionService
    local Players = Core.Services.Players
    local LocalPlayer = Players.LocalPlayer
    local State = Core.State

    function Scanners.MegaScan()
        local r = string.rep("=", 50) .. "\nMEGA DIAGNOSTICS REPORT\n" .. string.rep("=", 50) .. "\n\n"
        local executor = (identifyexecutor and identifyexecutor()) or "Unknown"
        r = r .. "[ ENVIRONMENT ]\nExecutor: " .. executor .. "\nPlaceID: " .. tostring(game.PlaceId) .. "\n\n"
        r = r .. "[ TEAMS IN GAME ]\n"
        local teamsOk, teams = pcall(function() return game:GetService("Teams"):GetChildren() end)
        if teamsOk and #teams > 0 then
            for _, t in ipairs(teams) do r = r .. string.format(" - %s (Color: %s)\n", t.Name, tostring(t.TeamColor)) end
        else r = r .. "No Teams found.\n" end
        r = r .. "\n"

        r = r .. string.rep("-", 40) .. "\n[ NETWORK REMOTES ]\n"
        local rCount = 0
        for _, container in ipairs({game:GetService("ReplicatedStorage"), workspace}) do
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        r = r .. string.format("%s -> %s\n", obj.ClassName, obj:GetFullName())
                        rCount = rCount + 1
                    end
                end
            end)
        end
        r = r .. "Total Remotes: " .. rCount .. "\n\n"

        r = r .. string.rep("-", 40) .. "\n[ ENVIRONMENT MAP ]\n"
        local interactableClasses = {"ProximityPrompt", "ClickDetector", "SelectionBox", "TouchTransmitter"}
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Camera") or child:IsA("Terrain") then continue end
            local descendants = {}
            local ok = pcall(function() descendants = child:GetDescendants() end)
            r = r .. string.format("[%s] %s — %d children, %d descendants\n", child.ClassName, child.Name, #child:GetChildren(), ok and #descendants or 0)
            if ok then
                local inter = {}
                for _, d in ipairs(descendants) do
                    for _, cn in ipairs(interactableClasses) do
                        if d:IsA(cn) then inter[cn] = (inter[cn] or 0) + 1 end
                    end
                end
                for cn, cnt in pairs(inter) do r = r .. string.format("  -> %d x %s\n", cnt, cn) end
            end
        end
        r = r .. "Workspace.Gravity: " .. tostring(workspace.Gravity) .. "\n\n"

        return r
    end

    function Scanners.GameData()
        local function getDetailedData(model, player)
            if not model then return "No Model\n" end
            local data = ""
            data = data .. "Name: " .. model.Name .. "\n"
            data = data .. "Parent: " .. (model.Parent and model.Parent.Name or "None") .. " [" .. (model.Parent and model.Parent.ClassName or "N/A") .. "]\n"
            if player then
                data = data .. "Team: " .. (player.Team and player.Team.Name or "None") .. "\n"
            end
            local hum = model:FindFirstChildOfClass("Humanoid")
            data = data .. "RigType: " .. (hum and hum.RigType.Name or "None") .. "\n"
            if hum then
                data = data .. string.format("Health: %.1f / %.1f\n", hum.Health, hum.MaxHealth)
                data = data .. string.format("WalkSpeed: %.1f | JumpPower: %.1f\n", hum.WalkSpeed, hum.JumpPower)
            end
            data = data .. "Attributes:\n"
            local attrs = model:GetAttributes()
            local ac = 0
            for k, v in pairs(attrs) do
                data = data .. string.format(" - %s: %s\n", tostring(k), tostring(v))
                ac = ac + 1
            end
            if ac == 0 then data = data .. " - None\n" end
            data = data .. "Tags: "
            local tags = CollectionService:GetTags(model)
            data = data .. (#tags > 0 and table.concat(tags, ", ") or "None") .. "\n"
            data = data .. "Values (String/Int/Bool etc):\n"
            local vc = 0
            for _, child in ipairs(model:GetChildren()) do
                if child:IsA("ValueBase") then
                    data = data .. string.format(" - %s [%s] = %s\n", child.Name, child.ClassName, tostring(child.Value))
                    vc = vc + 1
                end
            end
            if vc == 0 then data = data .. " - None\n" end
            return data
        end

        local executor = (identifyexecutor and identifyexecutor()) or "Unknown"

        local closestObj, isPlrObj, closestDist = nil, true, math.huge
        local function evalDist(model, isPlr)
            if model and model:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local d = (model.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if d < closestDist then closestDist = d; closestObj = model; isPlrObj = isPlr end
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then evalDist(plr.Character, true) end
        end
        for _, npc in ipairs(State.NPCCache) do evalDist(npc, false) end

        local r = string.rep("=", 40) .. "\nGAME DIAGNOSTICS REPORT\n" .. string.rep("=", 40) .. "\n\n"
        r = r .. "[ ENVIRONMENT ]\nExecutor: " .. executor .. "\nPlaceID: " .. tostring(game.PlaceId) .. "\n"
        r = r .. "\n[ TEAMS IN GAME ]\n"
        local teamsOk2, teams2 = pcall(function() return game:GetService("Teams"):GetChildren() end)
        if teamsOk2 and #teams2 > 0 then
            for _, t in ipairs(teams2) do r = r .. string.format(" - %s (Color: %s)\n", t.Name, tostring(t.TeamColor)) end
        else r = r .. "No Teams found in Teams Service.\n" end
        r = r .. "\n[ LOCAL PLAYER ]\n" .. getDetailedData(LocalPlayer.Character, LocalPlayer) .. "\n"
        r = r .. "[ CLOSEST TARGET (" .. (closestObj and closestObj.Name or "None") .. ") ]\n"
        local p = isPlrObj and Players:GetPlayerFromCharacter(closestObj) or nil
        r = r .. getDetailedData(closestObj, p)
        return r
    end

    function Scanners.ScanRemotes()
        local r = string.rep("=", 40) .. "\nNETWORK REMOTES MAP\n" .. string.rep("=", 40) .. "\n\n"
        local containers = {{game:GetService("ReplicatedStorage"), "ReplicatedStorage"}, {workspace, "Workspace"}}
        local total = 0
        for _, entry in ipairs(containers) do
            local container, name = entry[1], entry[2]
            r = r .. "[ " .. name .. " ]\n"
            local count = 0
            local ok, desc = pcall(function() return container:GetDescendants() end)
            if ok then
                for _, obj in ipairs(desc) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        r = r .. string.format("  %s  ->  %s\n", obj.ClassName, obj:GetFullName())
                        count = count + 1; total = total + 1
                    end
                end
            end
            if count == 0 then r = r .. "  No remotes found.\n" end
            r = r .. "\n"
        end
        r = r .. "Total Remotes Found: " .. total .. "\n"
        return r
    end

    function Scanners.ScanConfigs()
        local keywords = {"Config", "Setting", "Stat", "Data", "Weapon", "Profile", "Shop", "Item", "Ability", "Skill"}
        local r = string.rep("=", 40) .. "\nMODULE CONFIGURATION SCAN\n" .. string.rep("=", 40) .. "\n\n"
        r = r .. "Keywords: " .. table.concat(keywords, ", ") .. "\n\n"

        local function matchKW(n)
            local lo = n:lower()
            for _, kw in ipairs(keywords) do if lo:find(kw:lower()) then return true end end
            return false
        end
        local function serialize(tbl, indent, depth)
            if depth > 3 then return indent .. "... (max depth)\n" end
            local res, c = "", 0
            for k, v in pairs(tbl) do
                if c >= 30 then res = res .. indent .. "... (truncated)\n"; break end
                if type(v) == "table" then
                    res = res .. indent .. tostring(k) .. " [table]:\n" .. serialize(v, indent.."  ", depth+1)
                else
                    res = res .. indent .. tostring(k) .. " [" .. typeof(v) .. "] = " .. tostring(v) .. "\n"
                end
                c = c + 1
            end
            return res
        end

        local containers = {{game:GetService("ReplicatedStorage"), "ReplicatedStorage"}, {game:GetService("StarterPlayer"), "StarterPlayer"}}
        local total = 0
        for _, entry in ipairs(containers) do
            local container, name = entry[1], entry[2]
            r = r .. "[ " .. name .. " ]\n"
            local count = 0
            local ok, desc = pcall(function() return container:GetDescendants() end)
            if ok then
                for _, obj in ipairs(desc) do
                    if obj:IsA("ModuleScript") and matchKW(obj.Name) then
                        r = r .. string.format("\n  Module: %s\n  Path: %s\n", obj.Name, obj:GetFullName())
                        count = count + 1; total = total + 1
                        local rok, result = pcall(function() return require(obj) end)
                        if rok then
                            if type(result) == "table" then
                                r = r .. "  Contents:\n" .. serialize(result, "    ", 1)
                            else
                                r = r .. "  Returns: [" .. typeof(result) .. "] " .. tostring(result) .. "\n"
                            end
                        else r = r .. "  require() failed: " .. tostring(result) .. "\n" end
                    end
                end
            end
            if count == 0 then r = r .. "  No matching modules found.\n" end
            r = r .. "\n"
        end
        r = r .. "Total Config Modules Found: " .. total .. "\n"
        return r
    end

    function Scanners.ScanEnvironment()
        local r = string.rep("=", 40) .. "\nENVIRONMENT & OBJECT MAP\n" .. string.rep("=", 40) .. "\n\n"
        local interactableClasses = {"ProximityPrompt", "ClickDetector", "SelectionBox", "TouchTransmitter"}
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Camera") or child:IsA("Terrain") then continue end
            local descendants = {}
            local ok = pcall(function() descendants = child:GetDescendants() end)
            r = r .. string.format("[%s] %s  —  %d children, %d descendants\n",
                child.ClassName, child.Name, #child:GetChildren(), ok and #descendants or 0)
            if ok then
                local inter = {}
                for _, d in ipairs(descendants) do
                    for _, cn in ipairs(interactableClasses) do
                        if d:IsA(cn) then inter[cn] = (inter[cn] or 0) + 1 end
                    end
                end
                for cn, cnt in pairs(inter) do
                    r = r .. string.format("  -> %d x %s\n", cnt, cn)
                end
            end
        end
        r = r .. "\n" .. string.rep("-", 40) .. "\nWorkspace.Gravity: " .. tostring(workspace.Gravity) .. "\n"
        return r
    end

    function Scanners.ScanPlayerGui()
        local r = string.rep("=", 40) .. "\nPLAYERGUI UI LAYER INSPECTION\n" .. string.rep("=", 40) .. "\n\n"
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then r = r .. "PlayerGui not found!\n"
        else
            local textElem, progBars, cap = 0, 0, 200
            r = r .. "[ TEXT ELEMENTS ]\n"
            local allDesc = playerGui:GetDescendants()
            for _, d in ipairs(allDesc) do
                if textElem >= cap then r = r .. "... (capped at " .. cap .. ")\n"; break end
                if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text ~= "" then
                    if Core.UI and Core.UI.MainContainer and d:IsDescendantOf(Core.UI.MainContainer) then continue end
                    r = r .. string.format("  %s [%s]\n  Text: \"%s\"\n\n", d:GetFullName(), d.ClassName, d.Text:sub(1,100))
                    textElem = textElem + 1
                end
            end
            if textElem == 0 then r = r .. "  None found.\n" end
            r = r .. "\n[ POTENTIAL PROGRESS BARS ]\n"
            for _, d in ipairs(allDesc) do
                if progBars >= cap then break end
                if d:IsA("Frame") and Core.UI and Core.UI.MainContainer and not d:IsDescendantOf(Core.UI.MainContainer) then
                    for _, inner in ipairs(d:GetChildren()) do
                        if inner:IsA("Frame") or inner:IsA("ImageLabel") then
                            local sx = inner.Size.X.Scale
                            if sx > 0 and sx < 1 then
                                r = r .. string.format("  %s\n  Inner: %s (Width: %.2f)\n\n", d:GetFullName(), inner.Name, sx)
                                progBars = progBars + 1; break
                            end
                        end
                    end
                end
            end
            if progBars == 0 then r = r .. "  None found.\n" end
            r = r .. "\nTotal: " .. textElem .. " text, " .. progBars .. " progress bars\n"
        end
        return r
    end

    function Scanners.RemoteLog()
        if #State.RemoteLog == 0 then
            return "Log empty!"
        end
        local r = string.rep("=", 40) .. "\nREMOTE ACTIVITY LOG\n" .. string.rep("=", 40) .. "\n\n"
        for i, entry in ipairs(State.RemoteLog) do
            r = r .. string.format("[%d] %s  (%.1fs ago)\n", i, entry.name, tick() - entry.time)
        end
        return r
    end

    function Scanners.ScanTeams()
        local r = string.rep("=", 50) .. "\n"
        r = r .. "TEAM DETECTION DEEP SCAN\n"
        r = r .. "Run this DURING a team match (TDM/etc) for best results\n"
        r = r .. string.rep("=", 50) .. "\n\n"

        r = r .. "[ CAPTURED TeamService.UpdateData ]\n"
        if next(State.TeamData) then
            for k, v in pairs(State.TeamData) do
                r = r .. string.format("  %s = %s\n", tostring(k), tostring(v))
            end
        else
            r = r .. "  No data captured yet. Join a team match first.\n"
        end
        r = r .. "\n  Raw arg count: " .. #State.TeamDataRaw .. "\n"
        if #State.TeamDataRaw > 0 then
            for i, arg in ipairs(State.TeamDataRaw) do
                if type(arg) == "table" then
                    local entryCount = 0
                    for _ in pairs(arg) do entryCount = entryCount + 1 end
                    r = r .. string.format("  Arg[%d] = table with %d entries:\n", i, entryCount)
                    local c = 0
                    for k2, v2 in pairs(arg) do
                        r = r .. string.format("    [%s] (%s) = %s (%s)\n", tostring(k2), type(k2), tostring(v2), type(v2))
                        c = c + 1
                        if c >= 30 then r = r .. "    ... truncated\n"; break end
                    end
                else
                    r = r .. string.format("  Arg[%d] = %s (%s)\n", i, tostring(arg), type(arg))
                end
            end
        end
        r = r .. "\n"

        r = r .. "[ PLAYER COMPARISON ]\n"
        r = r .. string.format("  %-20s | %-12s | %-12s | %-20s | Attributes\n", "Name", "RobloxTeam", "Parent", "Tags")
        r = r .. "  " .. string.rep("-", 100) .. "\n"

        local myChar = LocalPlayer.Character
        local allPlayers = Players:GetPlayers()

        for _, plr in ipairs(allPlayers) do
            local char = plr.Character
            if not char then continue end

            local teamName = plr.Team and plr.Team.Name or "None"
            local parentName = char.Parent and char.Parent.Name or "nil"
            local tags = CollectionService:GetTags(char)
            local tagStr = #tags > 0 and table.concat(tags, ",") or "None"

            local attrStr = ""
            local attrs = char:GetAttributes()
            for k, v in pairs(attrs) do
                attrStr = attrStr .. k .. "=" .. tostring(v) .. " "
            end
            if attrStr == "" then attrStr = "None" end

            local marker = plr == LocalPlayer and " (YOU)" or ""
            r = r .. string.format("  %-20s | %-12s | %-12s | %-20s | %s%s\n",
                plr.Name, teamName, parentName, tagStr, attrStr, marker)
        end
        r = r .. "\n"

        r = r .. "[ CHARACTER PARENT HIERARCHY ]\n"
        for _, plr in ipairs(allPlayers) do
            local char = plr.Character
            if not char then continue end
            local path = ""
            local current = char
            for i = 1, 5 do
                if not current then break end
                path = path .. (path ~= "" and " ← " or "") .. current.Name .. " [" .. current.ClassName .. "]"
                current = current.Parent
            end
            r = r .. "  " .. plr.Name .. ": " .. path .. "\n"
        end
        r = r .. "\n"

        r = r .. "[ TEAM-LIKE CHILDREN IN CHARACTERS ]\n"
        local teamKeywords = {"team", "faction", "side", "role", "group", "squad", "color", "ally", "enemy"}
        for _, plr in ipairs(allPlayers) do
            local char = plr.Character
            if not char then continue end
            local found = {}
            for _, child in ipairs(char:GetDescendants()) do
                local lowerName = child.Name:lower()
                for _, kw in ipairs(teamKeywords) do
                    if lowerName:find(kw) then
                        local val = ""
                        if child:IsA("ValueBase") then val = " = " .. tostring(child.Value) end
                        table.insert(found, child.Name .. " [" .. child.ClassName .. "]" .. val)
                        break
                    end
                end
            end
            if #found > 0 then
                r = r .. "  " .. plr.Name .. ":\n"
                for _, f in ipairs(found) do r = r .. "    - " .. f .. "\n" end
            end
        end
        r = r .. "\n"

        r = r .. "[ PLAYER ATTRIBUTES ON PLAYER OBJECTS ]\n"
        for _, plr in ipairs(allPlayers) do
            local attrs = plr:GetAttributes()
            local attrStr = ""
            for k, v in pairs(attrs) do
                attrStr = attrStr .. k .. "=" .. tostring(v) .. " "
            end
            if attrStr ~= "" then
                r = r .. "  " .. plr.Name .. ": " .. attrStr .. "\n"
            end
        end
        r = r .. "\n"

        r = r .. "[ HIGHLIGHT / TEAM COLORS ]\n"
        for _, plr in ipairs(allPlayers) do
            local char = plr.Character
            if not char then continue end
            for _, desc in ipairs(char:GetDescendants()) do
                if desc:IsA("Highlight") then
                    r = r .. string.format("  %s: FillColor=%s OutlineColor=%s FillTransparency=%.2f\n",
                        plr.Name, tostring(desc.FillColor), tostring(desc.OutlineColor), desc.FillTransparency)
                end
            end
            if char.Parent then
                for _, sibling in ipairs(char.Parent:GetChildren()) do
                    if sibling:IsA("Highlight") then
                        r = r .. string.format("  %s (parent): FillColor=%s OutlineColor=%s\n",
                            plr.Name, tostring(sibling.FillColor), tostring(sibling.OutlineColor))
                    end
                end
            end
        end

        return r
    end

    function Scanners.TargetDebug()
        local r = string.rep("=", 40) .. "\nTARGETING SYSTEM DEBUG\n" .. string.rep("=", 40) .. "\n\n"
        local Aim = Core.Aim
        local Config = Core.Config
        local myChar = LocalPlayer.Character
        
        local function checkChar(char, title)
            if not char then return "" end
            local s = "[" .. title .. " - " .. char.Name .. "]\n"
            local valid = Aim.IsValidTarget(char)
            local enemy = Aim.IsEnemy(char)
            local sameTeam = Aim.IsSameTeam(myChar, char)
            
            s = s .. "IsValidTarget: " .. tostring(valid) .. "\n"
            s = s .. "IsEnemy: " .. tostring(enemy) .. "\n"
            s = s .. "IsSameTeam: " .. tostring(sameTeam) .. "\n"
            
            local root = char:FindFirstChild(Config.FocusPoint) or char:FindFirstChild("HumanoidRootPart")
            s = s .. "Has RootPart: " .. tostring(root ~= nil) .. "\n"
            if root then
                local inLoS = Aim.HasLoS(root)
                s = s .. "Has LineOfSight: " .. tostring(inLoS) .. "\n"
            end
            
            s = s .. "Target Result: " .. ((valid and not sameTeam) and "SHOULD TARGET" or "IGNORED") .. "\n\n"
            return s
        end

        r = r .. "Config: TeamCheck=" .. tostring(Config.TeamCheck) .. ", TargetMode=" .. tostring(Config.TargetMode) .. "\n\n"

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                r = r .. checkChar(plr.Character, "PLAYER")
            end
        end
        
        for _, npc in ipairs(State.NPCCache) do
            r = r .. checkChar(npc, "NPC")
        end

        return r
    end

    return Scanners
end
