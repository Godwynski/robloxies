return function(Core)
    local Hooks = {}

    local Players = Core.Services.Players
    local LocalPlayer = Players.LocalPlayer
    local Config = Core.Config
    local State = Core.State
    local Utility = Core.Utility

    function Hooks.Init()
        -- ==================== 1. UNIVERSAL NPC SCANNER ====================
        task.spawn(function()
            local function isNPCModel(obj)
                if not obj or not obj.Parent or not obj:IsA("Model") then return false end
                if obj == LocalPlayer.Character then return false end
                if Players:GetPlayerFromCharacter(obj) then return false end
                return obj:FindFirstChildOfClass("Humanoid") ~= nil
            end

            local npcSet = {}
            local function addNPC(model)
                if model and not npcSet[model] and isNPCModel(model) then
                    npcSet[model] = true
                    table.insert(State.NPCCache, model)
                end
            end

            -- Single startup scan with throttle
            task.spawn(function()
                local count = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if not State.Running then break end
                    if isNPCModel(obj) then
                        addNPC(obj)
                    end
                    count = count + 1
                    if count % 1500 == 0 then task.wait() end
                end
            end)

            -- Event-driven detection for new NPCs
            Utility.RegisterConnection(workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("Humanoid") then
                    addNPC(obj.Parent)
                end
            end))

            -- Periodic cleanup for destroyed NPCs
            while State.Running do
                if Config.TargetMode == "NPCs" or Config.TargetMode == "Both" then
                    local newCache = {}
                    local newSet = {}
                    for _, npc in ipairs(State.NPCCache) do
                        if isNPCModel(npc) then
                            table.insert(newCache, npc)
                            newSet[npc] = true
                        end
                    end
                    State.NPCCache = newCache
                    npcSet = newSet
                end
                task.wait(2)
            end
        end)

        -- ==================== 2. UNIVERSAL LOCAL PLAYER LIFECYCLE ====================
        task.spawn(function()
            local function hookHumanoid(hum)
                if not hum then return end
                State.IsAlive = hum.Health > 0

                Utility.RegisterConnection(hum.Died:Connect(function()
                    State.IsAlive = false
                    State.DeathTime = os.clock()
                    State.DeathCount = State.DeathCount + 1
                    Utility.AddKillFeedEntry("You died", Color3.fromRGB(255, 60, 60))
                end))
            end

            local function onCharacter(char)
                if not char then return end
                State.IsAlive = true
                State.LockedTarget = nil
                State.LockedCharacter = nil
                Utility.AddKillFeedEntry("Respawned", Color3.fromRGB(50, 200, 255))

                local hum = char:WaitForChild("Humanoid", 3) or char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hookHumanoid(hum)
                end
            end

            if LocalPlayer.Character then
                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hookHumanoid(hum) end
            end

            Utility.RegisterConnection(LocalPlayer.CharacterAdded:Connect(onCharacter))
        end)

        -- ==================== 3. UNIVERSAL KILL FEED & LEADERSTATS ====================
        task.spawn(function()
            -- Track kills via leaderstats changes across games
            local killKeywords = {"kill", "ko", "elim", "frag", "score", "points", "bounty"}

            local function hookLeaderstats(ls)
                if not ls then return end
                local function checkStat(stat)
                    if not (stat:IsA("IntValue") or stat:IsA("NumberValue")) then return end
                    local statNameLower = stat.Name:lower()
                    local isKillStat = false
                    for _, kw in ipairs(killKeywords) do
                        if statNameLower:find(kw) then
                            isKillStat = true
                            break
                        end
                    end

                    if isKillStat then
                        local lastVal = stat.Value
                        Utility.RegisterConnection(stat.Changed:Connect(function(newVal)
                            if newVal > lastVal then
                                local diff = newVal - lastVal
                                State.KillCount = State.KillCount + diff
                                Utility.AddKillFeedEntry("KILL (+" .. diff .. ")", Color3.fromRGB(50, 255, 50))
                            end
                            lastVal = newVal
                        end))
                    end
                end

                for _, child in ipairs(ls:GetChildren()) do
                    checkStat(child)
                end
                Utility.RegisterConnection(ls.ChildAdded:Connect(checkStat))
            end

            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                hookLeaderstats(ls)
            else
                Utility.RegisterConnection(LocalPlayer.ChildAdded:Connect(function(child)
                    if child.Name == "leaderstats" then
                        hookLeaderstats(child)
                    end
                end))
            end

            -- Track player deaths universally
            local function hookPlayer(plr)
                if plr == LocalPlayer then return end

                local lastHealth = 100
                local function hookChar(char)
                    local hum = char:WaitForChild("Humanoid", 3) or char:FindFirstChildOfClass("Humanoid")
                    if not hum then return end

                    lastHealth = hum.Health

                    -- Hitmarker detection: trigger when locked target loses health
                    Utility.RegisterConnection(hum.HealthChanged:Connect(function(hp)
                        if State.LockedCharacter == char and hp < lastHealth then
                            State.HitMarkerTime = os.clock()
                        end
                        lastHealth = hp
                    end))

                    -- Death detection
                    Utility.RegisterConnection(hum.Died:Connect(function()
                        local pName = plr.DisplayName or plr.Name
                        if State.LockedCharacter == char then
                            State.KillCount = State.KillCount + 1
                            Utility.AddKillFeedEntry("Eliminated " .. pName, Color3.fromRGB(50, 255, 50))
                            State.LockedTarget = nil
                            State.LockedCharacter = nil
                        else
                            Utility.AddKillFeedEntry(pName .. " died", Color3.fromRGB(180, 180, 180))
                        end
                    end))
                end

                if plr.Character then hookChar(plr.Character) end
                Utility.RegisterConnection(plr.CharacterAdded:Connect(hookChar))
            end

            for _, plr in ipairs(Players:GetPlayers()) do
                hookPlayer(plr)
            end
            Utility.RegisterConnection(Players.PlayerAdded:Connect(hookPlayer))
        end)

        -- ==================== 4. UNIVERSAL AUTO-RESPAWN ====================
        task.spawn(function()
            while State.Running do
                if Config.AutoRespawn and not State.IsAlive and (os.clock() - State.DeathTime) > 3 then
                    pcall(function()
                        if LocalPlayer.Character then
                            LocalPlayer.Character:BreakJoints()
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if hum then
                                hum.Health = 0
                            end
                        end
                    end)
                    State.DeathTime = os.clock()
                end
                task.wait(0.5)
            end
        end)
    end

    return Hooks
end
