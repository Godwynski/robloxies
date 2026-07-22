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

        local origin = cam.CFrame.Position
        local targetPos = part.Position
        local dir = targetPos - origin

        local rayParams = RaycastParams.new()
        local filterList = {}
        if LocalPlayer.Character then table.insert(filterList, LocalPlayer.Character) end
        if part.Parent then table.insert(filterList, part.Parent) end

        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        -- Multi-pass raycast to ignore other characters/players standing in front
        local passes = 0
        while passes < 6 do
            passes = passes + 1
            rayParams.FilterDescendantsInstances = filterList

            local res = workspace:Raycast(origin, dir, rayParams)
            if not res then
                return true -- Nothing blocking = clear LoS
            end

            local hitInst = res.Instance
            if not hitInst then return true end

            -- Check if hit instance belongs to a player or NPC character model
            local hitModel = hitInst:FindFirstAncestorOfClass("Model")
            local isCharacter = false
            if hitModel then
                if hitModel:FindFirstChildOfClass("Humanoid")
                   or Core.Services.Players:GetPlayerFromCharacter(hitModel)
                   or hitModel:GetAttribute("vc_Visible") ~= nil then
                    isCharacter = true
                end
            end

            if isCharacter and hitModel then
                -- Hit another character; add to filter list and continue raycast through them
                table.insert(filterList, hitModel)
            else
                -- Hit map geometry / solid wall
                return false
            end
        end

        return false
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
        if not charA or not charB then return false end
        if charA == charB then return true end

        local plrA = Core.Services.Players:GetPlayerFromCharacter(charA)
        local plrB = Core.Services.Players:GetPlayerFromCharacter(charB)

        if not plrA and charA == LocalPlayer.Character then
            plrA = LocalPlayer
        end

        if plrA and plrB then
            if plrA == plrB then return true end

            -- 1. Roblox Neutral state (Free-For-All mode)
            local neutralA = plrA.Neutral
            local neutralB = plrB.Neutral

            -- 2. Native Roblox Teams & TeamColors
            local teamA = plrA.Team
            local teamB = plrB.Team
            if teamA ~= nil and teamB ~= nil and not neutralA and not neutralB then
                return teamA == teamB
            end

            local colorA = plrA.TeamColor
            local colorB = plrB.TeamColor
            if colorA ~= nil and colorB ~= nil and not neutralA and not neutralB then
                return colorA == colorB
            end

            -- 3. Custom Player Attributes ("Team", "TeamColor", "Faction", "Side", "Group")
            local attrNames = {"Team", "TeamColor", "Faction", "Side", "Group"}
            for _, attr in ipairs(attrNames) do
                local valA = plrA:GetAttribute(attr)
                local valB = plrB:GetAttribute(attr)
                if valA ~= nil and valB ~= nil then
                    return tostring(valA) == tostring(valB)
                end
            end

            -- 4. Leaderstats Teams / Factions
            local lsA = plrA:FindFirstChild("leaderstats")
            local lsB = plrB:FindFirstChild("leaderstats")
            if lsA and lsB then
                for _, attr in ipairs(attrNames) do
                    local vA = lsA:FindFirstChild(attr)
                    local vB = lsB:FindFirstChild(attr)
                    if vA and vB and vA.Value ~= nil and vB.Value ~= nil then
                        return tostring(vA.Value) == tostring(vB.Value)
                    end
                end
            end

            -- 5. Custom Intercepted Remotes (State.TeamData)
            if State.TeamData and next(State.TeamData) then
                local tA = State.TeamData[plrA.Name] or State.TeamData[tostring(plrA.UserId)]
                local tB = State.TeamData[plrB.Name] or State.TeamData[tostring(plrB.UserId)]
                if tA ~= nil and tB ~= nil then
                    return tostring(tA) == tostring(tB)
                end
            end
        end

        -- 6. Custom Character Attributes
        local charAttrNames = {"Team", "TeamColor", "Faction", "Side"}
        for _, attr in ipairs(charAttrNames) do
            local valA = charA:GetAttribute(attr)
            local valB = charB:GetAttribute(attr)
            if valA ~= nil and valB ~= nil then
                return tostring(valA) == tostring(valB)
            end
        end

        -- 7. Specific Enemy Markers (Red highlights, Enemy folders)
        if Aim.IsEnemy(charB) then return false end

        -- 8. Parent Folder Matching (e.g. workspace.Teams.Blue)
        if charA.Parent and charB.Parent and charA.Parent == charB.Parent then
            local parentName = charA.Parent.Name:lower()
            if charA.Parent ~= workspace and not parentName:find("enemy") and not parentName:find("player") then
                return true
            end
        end

        -- 9. If charB is an NPC (not a player), default to enemy
        if not plrB then
            return false
        end

        -- FFA / no team match -> enemy
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

    local lastLoSSuccessTime = 0
    local LOCK_LOS_GRACE_PERIOD = 0.35 -- 350ms grace window to retain target lock when briefly ducking behind poles/cover

    function Aim.GetTargetScore(char, part, mouseLoc, cam)
        cam = cam or workspace.CurrentCamera
        if not cam then return nil, math.huge end

        local screenPos, onScreen = cam:WorldToScreenPoint(part.Position)
        if not onScreen then return nil, math.huge end

        local viewport = cam.ViewportSize
        if screenPos.X < 0 or screenPos.X > viewport.X or screenPos.Y < 0 or screenPos.Y > viewport.Y then
            return nil, math.huge
        end

        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude

        -- Give currently locked character 25% larger FOV limit so lock doesn't drop at FOV boundary
        local fovLimit = Config.ViewAngle
        if char == State.LockedCharacter then
            fovLimit = fovLimit * 1.25
        end

        if screenDist > fovLimit then return nil, math.huge end

        local score = screenDist
        if Config.PriorityMode == "LowHP" then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hp = hum and hum.Health or 100
            score = hp + (screenDist * 0.01)
        elseif Config.PriorityMode == "Closest3D" then
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local dist3D = (part.Position - myRoot.Position).Magnitude
                score = dist3D
            end
        end

        -- Target Stickiness Bias (Hysteresis):
        -- Discount score for locked target by 40% to prevent micro-flicking between close targets
        if char == State.LockedCharacter then
            score = score * 0.6
        end

        return score, screenDist
    end

    function Aim.GetTarget()
        local mouseLoc = UserInputService:GetMouseLocation()
        local myChar = LocalPlayer.Character
        if not myChar then return nil, "No Character" end
        local cam = workspace.CurrentCamera
        if not cam then return nil, "No Camera" end

        local debugState = "Scanning..."
        local validCount, inFOV = 0, 0
        local now = tick()

        -- 1. Sticky Target Persistence check
        if Config.StickyTarget and State.LockedCharacter and State.LockedTarget then
            if Aim.IsValidTarget(State.LockedCharacter) and not Aim.IsSameTeam(myChar, State.LockedCharacter) then
                local part = State.LockedCharacter:FindFirstChild(Config.FocusPoint) or State.LockedCharacter:FindFirstChild("HumanoidRootPart")
                if part then
                    local sp, onScreen = cam:WorldToScreenPoint(part.Position)
                    if onScreen then
                        local viewport = cam.ViewportSize
                        local inViewport = sp.X >= 0 and sp.X <= viewport.X and sp.Y >= 0 and sp.Y <= viewport.Y
                        local dist = (Vector2.new(sp.X, sp.Y) - mouseLoc).Magnitude
                        -- Allow active lock to persist up to 25% outside normal FOV ring to prevent jitter
                        if inViewport and dist <= (Config.ViewAngle * 1.25) then
                            local inLoS = Aim.HasLoS(part)
                            if inLoS then
                                lastLoSSuccessTime = now
                                return part, "Locked!"
                            elseif (now - lastLoSSuccessTime) < LOCK_LOS_GRACE_PERIOD then
                                return part, "Locked!"
                            end
                        end
                    end
                end
            end

            -- Target became invalid, dead, or left FOV/LoS past grace window
            State.LockedTarget = nil
            State.LockedCharacter = nil
        end

        -- 2. Full Target Scan
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

            local score, screenDist = Aim.GetTargetScore(char, part, mouseLoc, cam)
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
            lastLoSSuccessTime = now
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
            
            CombatTab:AddSlider("Deadzone", Config.AimDeadzone, 0, 300, function(val) Config.AimDeadzone = val end)
            CombatTab:AddSlider("Smoothing", Config.Smoothing, 0.01, 30, function(val) Config.Smoothing = val end)

            local styleBtn = CombatTab:AddButton("Smooth Style: " .. Config.SmoothingStyle, function() end)
            Utility.RegisterConnection(styleBtn.Activated:Connect(function()
                Config.SmoothingStyle = Config.SmoothingStyle == "Linear" and "Exponential" or "Linear"
                styleBtn.Text = "Smooth Style: " .. Config.SmoothingStyle
            end))

            CombatTab:AddToggle("Auto-Shoot (TriggerBot)", Config.AutoShoot, function(val) Config.AutoShoot = val end)

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
                if not ctx.Camera then
                    aimState = "No Camera"
                else
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
                                local dx = sp.X - ctx.MouseLocation.X
                                local dy = sp.Y - ctx.MouseLocation.Y
                                local dist = math.sqrt(dx*dx + dy*dy)
                                
                                if dist > Config.AimDeadzone then
                                    local factor = Config.Smoothing + 1
                                    if Config.SmoothingStyle == "Exponential" then
                                        factor = factor * (1 + (dist / (Config.ViewAngle + 1)))
                                    end
                                    pcall(function() mousemoverel(dx / factor, dy / factor) end)
                                end
                            end
                        elseif Config.TrackingMethod == "Camera" then
                            local curCF = ctx.Camera.CFrame
                            local tgtCF = CFrame.new(curCF.Position, aimPos)
                            local alpha = 1 / (Config.Smoothing + 1)
                            
                            -- Apply Deadzone check for Camera
                            local _, onScreen = ctx.Camera:WorldToScreenPoint(aimPos)
                            if onScreen then
                                local sp2 = ctx.Camera:WorldToScreenPoint(aimPos)
                                local dx = sp2.X - ctx.MouseLocation.X
                                local dy = sp2.Y - ctx.MouseLocation.Y
                                local dist = math.sqrt(dx*dx + dy*dy)
                                if dist <= Config.AimDeadzone then
                                    alpha = 0
                                elseif Config.SmoothingStyle == "Exponential" then
                                    alpha = math.clamp(alpha * (dist / 100), 0, 1)
                                end
                            end
                            
                            if alpha > 0 then
                                -- Detect if the target is nearly behind the camera.
                                local dot = curCF.LookVector:Dot(tgtCF.LookVector)
                                if dot < -0.5 then
                                    ctx.Camera.CFrame = tgtCF
                                else
                                    ctx.Camera.CFrame = curCF:Lerp(tgtCF, alpha)
                                end
                            end
                        end

                        -- Auto-Shoot (TriggerBot) Logic
                        if Config.AutoShoot and aimState == "Locked!" then
                            -- Debounce clicking so we don't spam it every frame
                            if not State.LastAutoShoot or (tick() - State.LastAutoShoot) > 0.05 then
                                State.LastAutoShoot = tick()
                                pcall(function() mouse1click() end)
                            end
                        end
                    else
                        Core.Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
                    end
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
