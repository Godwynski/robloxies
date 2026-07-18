return function(Core)
    local Aim = {}

    local LocalPlayer = Core.Services.Players.LocalPlayer
    local UserInputService = Core.Services.UserInputService
    local Config = Core.Config
    local State = Core.State
    local Utility = Core.Utility

    function Aim.HasLoS(part)
        if not Config.WallCheck then return true end
        local cam = workspace.CurrentCamera
        if not cam then return true end
        local ray = RaycastParams.new()
        -- Filter both our character AND the target character so the ray
        -- only hits world geometry. Fixes false negatives when targets
        -- are reparented into HighlightHolder/Enemy folders.
        local filterList = {}
        if LocalPlayer.Character then table.insert(filterList, LocalPlayer.Character) end
        if part.Parent then table.insert(filterList, part.Parent) end
        ray.FilterDescendantsInstances = filterList
        ray.FilterType = Enum.RaycastFilterType.Exclude
        local origin = cam.CFrame.Position
        local dir = part.Position - origin
        local res = workspace:Raycast(origin, dir, ray)
        return res == nil -- nil means nothing blocking = clear LoS
    end

    function Aim.IsValidTarget(char)
        if not char or not char.Parent then return false end

        local vcVisible = char:GetAttribute("vc_Visible")
        if vcVisible == false then return false end

        if vcVisible == nil then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return false end
        end

        if char:FindFirstChildOfClass("ForceField") then return false end

        local part = char:FindFirstChild(Config.FocusPoint) or char:FindFirstChild("HumanoidRootPart")
        if not part then return false end

        return true
    end

    -- Enemy detection cache to avoid heavy GetDescendants() calls every frame
    local enemyCache = {}
    local ENEMY_CACHE_TTL = 0.5

    function Aim.IsEnemy(char)
        -- Check cache first
        local cached = enemyCache[char]
        if cached and (tick() - cached.time) < ENEMY_CACHE_TTL then
            return cached.result
        end

        local result = false

        -- Check if character is inside an "Enemy" folder
        local current = char.Parent
        while current and current ~= workspace do
            if current.Name:lower():find("enemy") then
                result = true
                break
            end
            current = current.Parent
        end

        if not result then
            local function checkHighlight(hl)
                if not hl or not hl:IsA("Highlight") then return false end
                if hl.Adornee and hl.Adornee ~= char and not char:IsDescendantOf(hl.Adornee) then
                    return false
                end
                local c1, c2 = hl.OutlineColor, hl.FillColor
                if (c1.R > 0.5 and c1.G < 0.5 and c1.B < 0.5) or 
                   (c2.R > 0.5 and c2.G < 0.5 and c2.B < 0.5) then
                    return true
                end
                return false
            end

            for _, desc in ipairs(char:GetDescendants()) do
                if checkHighlight(desc) then result = true; break end
            end
            
            if not result and char.Parent then
                for _, child in ipairs(char.Parent:GetChildren()) do
                    if checkHighlight(child) then result = true; break end
                end
            end
            
            if not result then
                local hlFolder = workspace:FindFirstChild("Highlight")
                if hlFolder then
                    for _, hl in ipairs(hlFolder:GetDescendants()) do
                        if hl:IsA("Highlight") and hl.Adornee then
                            if hl.Adornee == char or char:IsDescendantOf(hl.Adornee) then
                                if checkHighlight(hl) then result = true; break end
                            end
                        end
                    end
                end
            end
        end

        enemyCache[char] = { result = result, time = tick() }
        return result
    end

    function Aim.IsSameTeam(charA, charB)
        if not Config.TeamCheck then return false end

        local plrA = Core.Services.Players:GetPlayerFromCharacter(charA)
        local plrB = Core.Services.Players:GetPlayerFromCharacter(charB)
        
        if plrA and plrB then
            local teamA = plrA:GetAttribute("Team")
            local teamB = plrB:GetAttribute("Team")
            -- If both have a Team attribute and they differ, they are enemies
            if teamA and teamB and teamA ~= teamB then
                return false
            end
        end

        if Aim.IsEnemy(charB) then return false end
        
        -- If charB is an NPC (not a player), treat them as an enemy by default
        if not plrB then
            return false
        end

        return true
    end

    function Aim.SnapToNearest()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local bestPart, bestDist = nil, math.huge

        local targetsList = {}
        if Config.TargetMode == "Players" or Config.TargetMode == "Both" then
            for _, plr in ipairs(Core.Services.Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    table.insert(targetsList, plr.Character)
                end
            end
        end
        if Config.TargetMode == "NPCs" or Config.TargetMode == "Both" then
            for _, npc in ipairs(State.NPCCache) do
                if npc and npc.Parent then table.insert(targetsList, npc) end
            end
        end

        for _, char in ipairs(targetsList) do
            if not Aim.IsValidTarget(char) then continue end
            if Aim.IsSameTeam(myChar, char) then continue end

            local part = char:FindFirstChild(Config.FocusPoint) or char:FindFirstChild("HumanoidRootPart")
            if not part then continue end

            local d = (part.Position - myRoot.Position).Magnitude
            if d < bestDist then
                bestDist = d
                bestPart = part
            end
        end

        if bestPart then
            State.LockedTarget = bestPart
            State.LockedCharacter = bestPart.Parent

            -- Smooth snap instead of instant teleport (less obvious)
            task.spawn(function()
                for i = 1, 5 do
                    local cam = workspace.CurrentCamera
                    if not cam or not bestPart.Parent then break end
                    local curCF = cam.CFrame
                    local tgtCF = CFrame.new(curCF.Position, bestPart.Position)
                    cam.CFrame = curCF:Lerp(tgtCF, 0.5)
                    task.wait()
                end
            end)

            Utility.AddKillFeedEntry("⚡ Snapped → " .. bestPart.Parent.Name .. string.format(" [%dm]", math.floor(bestDist)), Color3.fromRGB(255, 200, 50))
        end
    end

    function Aim.GetTargetScore(char, part, mouseLoc)
        local screenPos, onScreen = workspace.CurrentCamera:WorldToScreenPoint(part.Position)
        if not onScreen then return nil, math.huge end

        local viewport = workspace.CurrentCamera.ViewportSize
        if screenPos.X < 0 or screenPos.X > viewport.X or screenPos.Y < 0 or screenPos.Y > viewport.Y then
            return nil, math.huge
        end

        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
        if screenDist > Config.ViewAngle then return nil, math.huge end

        if Config.PriorityMode == "Distance" then
            return screenDist, screenDist
        elseif Config.PriorityMode == "LowHP" then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hp = hum and hum.Health or 100
            return hp + (screenDist * 0.01), screenDist
        elseif Config.PriorityMode == "Closest3D" then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local dist3D = (part.Position - myRoot.Position).Magnitude
                return dist3D, screenDist
            end
            return screenDist, screenDist
        end
        return screenDist, screenDist
    end

    function Aim.GetTarget()
        local mouseLoc = UserInputService:GetMouseLocation()
        local myChar = LocalPlayer.Character
        if not myChar then return nil, "No Character" end

        local debugState = "Scanning..."
        local validCount, inFOV = 0, 0

        if Config.StickyTarget and State.LockedCharacter and State.LockedTarget then
            if Aim.IsValidTarget(State.LockedCharacter) and not Aim.IsSameTeam(myChar, State.LockedCharacter) then
                local part = State.LockedCharacter:FindFirstChild(Config.FocusPoint) or State.LockedCharacter:FindFirstChild("HumanoidRootPart")
                if part then
                    local sp, onScreen = workspace.CurrentCamera:WorldToScreenPoint(part.Position)
                    if onScreen then
                        local viewport = workspace.CurrentCamera.ViewportSize
                        local inViewport = sp.X >= 0 and sp.X <= viewport.X and sp.Y >= 0 and sp.Y <= viewport.Y
                        local dist = (Vector2.new(sp.X, sp.Y) - mouseLoc).Magnitude
                        if inViewport and dist <= Config.ViewAngle then
                            local inLoS = Aim.HasLoS(part)
                            if inLoS then
                                return part, "Locked!"
                            end
                        end
                    end
                end
            end
            State.LockedTarget = nil
            State.LockedCharacter = nil
        end

        local targetsList = {}
        if Config.TargetMode == "Players" or Config.TargetMode == "Both" then
            for _, plr in ipairs(Core.Services.Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    table.insert(targetsList, plr.Character)
                end
            end
        end
        if Config.TargetMode == "NPCs" or Config.TargetMode == "Both" then
            for _, npc in ipairs(State.NPCCache) do
                if npc and npc.Parent then table.insert(targetsList, npc) end
            end
        end

        local bestPart, bestScore = nil, math.huge

        for _, char in ipairs(targetsList) do
            if not Aim.IsValidTarget(char) then continue end
            if Aim.IsSameTeam(myChar, char) then continue end

            local part = char:FindFirstChild(Config.FocusPoint) or char:FindFirstChild("HumanoidRootPart")
            if not part then continue end

            validCount = validCount + 1

            local score, screenDist = Aim.GetTargetScore(char, part, mouseLoc)
            if not score then continue end

            inFOV = inFOV + 1

            local inLoS = Aim.HasLoS(part)

            if inLoS then
                if score < bestScore then
                    bestScore = score
                    bestPart = part
                    debugState = "Locked!"
                end
            else
                if not bestPart then debugState = "Blocked by Wall" end
            end
        end

        if validCount == 0 then debugState = "No valid targets"
        elseif inFOV == 0 and not bestPart then debugState = "Nobody in FOV" end

        if bestPart and Config.StickyTarget then
            State.LockedTarget = bestPart
            State.LockedCharacter = bestPart.Parent
        end

        return bestPart, debugState
    end

    return Aim
end
