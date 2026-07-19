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
    local lastCacheClean = 0

    function Aim.IsEnemy(char)
        -- Prune stale/destroyed entries every 2 seconds to prevent memory leaks (#14)
        local now = tick()
        if now - lastCacheClean > 2 then
            lastCacheClean = now
            for cachedChar, entry in pairs(enemyCache) do
                -- Destroyed instances lose their Parent; evict them
                if not cachedChar.Parent or (now - entry.time) > ENEMY_CACHE_TTL * 10 then
                    enemyCache[cachedChar] = nil
                end
            end
        end

        -- Check cache first
        local cached = enemyCache[char]
        if cached and (now - cached.time) < ENEMY_CACHE_TTL then
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

        enemyCache[char] = { result = result, time = now }
        return result
    end

    function Aim.IsSameTeam(charA, charB)
        if not Config.TeamCheck then return false end

        local plrA = Core.Services.Players:GetPlayerFromCharacter(charA)
        local plrB = Core.Services.Players:GetPlayerFromCharacter(charB)
        
        if plrA and plrB then
            -- 1. Check native Roblox Teams
            if plrA.Team ~= nil and plrB.Team ~= nil then
                if plrA.Team == plrB.Team then return true else return false end
            end
            
            -- 2. Check custom "Team" attribute
            local teamA = plrA:GetAttribute("Team")
            local teamB = plrB:GetAttribute("Team")
            if teamA ~= nil and teamB ~= nil then
                if teamA == teamB then return true else return false end
            end
        end

        -- 3. Check for specific enemy markers (Red highlights, "Enemy" folders)
        if Aim.IsEnemy(charB) then return false end
        
        -- 4. If charB is an NPC (not a player), treat them as an enemy
        if not plrB then
            return false
        end

        -- 5. If we have absolutely no team data (FFA game, no teams assigned), 
        -- we default to false (treat as enemy) so the aimbot actually targets them.
        -- The old logic returned true here, which made it ignore everyone!
        return false
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

    function Aim.Init()
        -- Register UI
        if Core.UI and Core.UI.Window then
            local CombatTab = Core.UI.Window:AddTab("Combat")
            CombatTab:AddSection("AIM")
            
            Core.UI.SyncAutoAimButton = function() end -- Provide a fallback
            
            local aimBtn = CombatTab:AddToggle("Auto-Aim", Config.AutoAimEnabled, function(val)
                Config.AutoAimEnabled = val
                Core.Drawings.FOVCircle.Visible = val
            end)
            
            Core.UI.SyncAutoAimButton = function()
                aimBtn.SetState(Config.AutoAimEnabled)
            end

            CombatTab:AddSlider("FOV Radius", Config.ViewAngle, 10, 800, function(val)
                Config.ViewAngle = val
                Core.Drawings.FOVCircle.Radius = val
            end)
            
            CombatTab:AddSlider("Smoothing", Config.Smoothing, 0.01, 30, function(val) Config.Smoothing = val end)

            local focusBtn = CombatTab:AddButton("Focus: " .. Config.FocusPoint, function() end)
            -- Hacky way to override the callback for a toggle-like text update
            Utility.RegisterConnection(focusBtn.Activated:Connect(function()
                Config.FocusPoint = Config.FocusPoint == "HumanoidRootPart" and "Head" or "HumanoidRootPart"
                focusBtn.Text = "Focus: " .. Config.FocusPoint
            end))

            local methodBtn = CombatTab:AddButton("Method: " .. Config.TrackingMethod, function() end)
            Utility.RegisterConnection(methodBtn.Activated:Connect(function()
                Config.TrackingMethod = Config.TrackingMethod == "Camera" and "Mouse" or "Camera"
                methodBtn.Text = "Method: " .. Config.TrackingMethod
            end))

            local targetBtn = CombatTab:AddButton("Target: " .. Config.TargetMode, function() end)
            Utility.RegisterConnection(targetBtn.Activated:Connect(function()
                if Config.TargetMode == "Players" then Config.TargetMode = "NPCs"
                elseif Config.TargetMode == "NPCs" then Config.TargetMode = "Both"
                else Config.TargetMode = "Players" end
                targetBtn.Text = "Target: " .. Config.TargetMode
            end))

            local prioBtn = CombatTab:AddButton("Priority: " .. Config.PriorityMode, function() end)
            Utility.RegisterConnection(prioBtn.Activated:Connect(function()
                if Config.PriorityMode == "Distance" then Config.PriorityMode = "LowHP"
                elseif Config.PriorityMode == "LowHP" then Config.PriorityMode = "Closest3D"
                else Config.PriorityMode = "Distance" end
                prioBtn.Text = "Priority: " .. Config.PriorityMode
            end))

            CombatTab:AddSection("ADVANCED")
            CombatTab:AddToggle("Wall Check", Config.WallCheck, function(val) Config.WallCheck = val end)
            CombatTab:AddToggle("Team Check", Config.TeamCheck, function(val) Config.TeamCheck = val end)
            CombatTab:AddToggle("Sticky Target", Config.StickyTarget, function(val)
                Config.StickyTarget = val
                if not val then State.LockedTarget = nil; State.LockedCharacter = nil end
            end)
            CombatTab:AddToggle("Prediction", Config.Prediction, function(val) Config.Prediction = val end)
            CombatTab:AddSlider("Predict Scale", Config.PredictionScale, 0, 1, function(val) Config.PredictionScale = val end)
        end

        -- Subscribe to Render Loop
        Core.EventManager:Subscribe("OnRender", "AimBotRender", function(ctx)
            if Core.Drawings.FOVCircle then
                Core.Drawings.FOVCircle.Position = ctx.MouseLocation
                Core.Drawings.FOVCircle.Radius = Config.ViewAngle
            end

            local target = nil
            local aimState = "Disabled"

            if Config.AutoAimEnabled then
                target, aimState = Aim.GetTarget()

                if target then
                    Core.Drawings.FOVCircle.Color = Color3.fromRGB(50, 255, 50)
                    
                    local aimPos = target.Position
                    if Config.Prediction then
                        local vel = Vector3.zero
                        pcall(function() vel = target.AssemblyLinearVelocity or target.Velocity or Vector3.zero end)
                        aimPos = aimPos + vel * Config.PredictionScale
                    end

                    if Config.TrackingMethod == "Mouse" then
                        local sp, onScreen = ctx.Camera:WorldToScreenPoint(aimPos)
                        if onScreen then
                            local dx = (sp.X - ctx.MouseLocation.X) / (Config.Smoothing + 1)
                            local dy = (sp.Y - ctx.MouseLocation.Y) / (Config.Smoothing + 1)
                            pcall(function() mousemoverel(dx, dy) end)
                        end
                    elseif Config.TrackingMethod == "Camera" then
                        local curCF = ctx.Camera.CFrame
                        local tgtCF = CFrame.new(curCF.Position, aimPos)
                        local alpha = 1 / (Config.Smoothing + 1)
                        -- Detect if the target is nearly behind the camera.
                        -- CFrame:Lerp uses slerp which takes the shortest arc; when the
                        -- angle approaches 180° it can flip the wrong way ("avoidance bug").
                        local dot = curCF.LookVector:Dot(tgtCF.LookVector)
                        if dot < -0.5 then
                            -- Target is >120° away — snap directly to avoid wrong-way slerp
                            ctx.Camera.CFrame = tgtCF
                        else
                            ctx.Camera.CFrame = curCF:Lerp(tgtCF, alpha)
                        end
                    end
                else
                    Core.Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
                end
            else
                if Core.Drawings.FOVCircle then
                    Core.Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
                end
            end
            
            State.AimState = aimState
            State.CurrentTarget = target
        end)
    end

    return Aim
end
