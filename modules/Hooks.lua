return function(Core)
    local Hooks = {}

    local ReplicatedStorage = Core.Services.ReplicatedStorage
    local LocalPlayer = Core.Services.Players.LocalPlayer
    local Config = Core.Config
    local State = Core.State
    local Utility = Core.Utility

    function Hooks.Init()
        -- NPC scanner loop — guarded by State.Running (#2)
        task.spawn(function()
            while Core.State.Running do
                if Config.TargetMode == "NPCs" or Config.TargetMode == "Both" then
                    local newCache = {}
                    local count = 0
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if not Core.State.Running then break end -- fast exit
                        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
                            if not Core.Services.Players:GetPlayerFromCharacter(obj) then
                                local hum = obj:FindFirstChildOfClass("Humanoid")
                                if hum then table.insert(newCache, obj) end
                            end
                        end
                        count = count + 1
                        if count % 1000 == 0 then task.wait() end
                    end
                    State.NPCCache = newCache
                    task.wait(3)
                else
                    task.wait(1)
                end
            end
        end)

        -- Sink the ServerReplicateCFrame to prevent "invocation queue exhausted" console spam
        task.spawn(function()
            pcall(function()
                local repCFrame = ReplicatedStorage:WaitForChild("ServerReplicateCFrame", 5)
                if repCFrame and repCFrame:IsA("RemoteEvent") then
                    Utility.RegisterConnection(repCFrame.OnClientEvent:Connect(function() end))
                end
            end)
        end)

        task.spawn(function()
            task.wait(2)

            local killedRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "GameClient", "Killed")
            if killedRemote and killedRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(killedRemote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    pcall(function()
                        local killer, victim = "?", "?"

                        -- Helper: resolve name from an arg, checking both Name and DisplayName (#13)
                        local function resolveName(arg)
                            if typeof(arg) == "Instance" and arg:IsA("Player") then
                                return arg.Name, arg.DisplayName
                            elseif type(arg) == "string" then
                                return arg, arg
                            elseif typeof(arg) == "Instance" then
                                return arg.Name, arg.Name
                            end
                            return "?", "?"
                        end

                        local killerName, killerDisplay = resolveName(args[1])
                        local victimName, victimDisplay = resolveName(args[2])
                        killer = killerDisplay
                        victim = victimDisplay

                        local color = Color3.new(1, 1, 1)
                        -- Compare both Name and DisplayName to handle either format (#13)
                        local isKiller = killerName == LocalPlayer.Name or killerDisplay == LocalPlayer.DisplayName
                        local isVictim = victimName == LocalPlayer.Name or victimDisplay == LocalPlayer.DisplayName
                        if isKiller then
                            State.KillCount = State.KillCount + 1
                            color = Color3.fromRGB(50, 255, 50)
                        elseif isVictim then
                            State.DeathCount = State.DeathCount + 1
                            color = Color3.fromRGB(255, 50, 50)
                        end
                        Utility.AddKillFeedEntry(killer .. " ▸ " .. victim, color)
                    end)
                    if Config.RemoteLogEnabled then
                        table.insert(State.RemoteLog, 1, {name = "Killed", time = tick()})
                        if #State.RemoteLog > 50 then table.remove(State.RemoteLog, 51) end
                    end
                end))
            end

            local assistRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "GameClient", "Assist")
            if assistRemote and assistRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(assistRemote.OnClientEvent:Connect(function()
                    State.AssistCount = State.AssistCount + 1
                    Utility.AddKillFeedEntry("ASSIST!", Color3.fromRGB(100, 200, 255))
                end))
            end

            local beDamagedRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "EntityService", "BeDamaged")
            if beDamagedRemote and beDamagedRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(beDamagedRemote.OnClientEvent:Connect(function(...)
                    State.HitMarkerTime = tick()
                    if Config.RemoteLogEnabled then
                        table.insert(State.RemoteLog, 1, {name = "BeDamaged", time = tick()})
                        if #State.RemoteLog > 50 then table.remove(State.RemoteLog, 51) end
                    end
                end))
            end

            local diedRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "EntityService", "Died")
            if diedRemote and diedRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(diedRemote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    pcall(function()
                        if typeof(args[1]) == "Instance" then
                            if args[1] == LocalPlayer.Character or args[1] == LocalPlayer then
                                State.IsAlive = false
                                State.DeathTime = tick()
                            end
                        end
                    end)
                end))
            end

            local spawnedRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "EntityService", "Spawned")
            if spawnedRemote and spawnedRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(spawnedRemote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    pcall(function()
                        if typeof(args[1]) == "Instance" then
                            if args[1] == LocalPlayer.Character or args[1] == LocalPlayer then
                                State.IsAlive = true
                                Utility.AddKillFeedEntry("Respawned", Color3.fromRGB(50, 200, 255))
                            end
                        end
                    end)
                end))
            end

            local wpRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "WeaponPickup")
            if wpRemote and wpRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(wpRemote.OnClientEvent:Connect(function()
                    Utility.AddKillFeedEntry("⚔ Weapon Pickup", Color3.fromRGB(255, 200, 50))
                end))
            end

            local gsRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "RoomManager", "Room", "GameStarted")
            if gsRemote and gsRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(gsRemote.OnClientEvent:Connect(function()
                    State.KillCount, State.DeathCount, State.AssistCount = 0, 0, 0
                    Utility.AddKillFeedEntry("— GAME STARTED —", Color3.fromRGB(255, 255, 100))
                end))
            end

            local geRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "RoomManager", "Room", "GameEnded")
            if geRemote and geRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(geRemote.OnClientEvent:Connect(function()
                    Utility.AddKillFeedEntry(string.format("GAME OVER  K:%d D:%d A:%d", State.KillCount, State.DeathCount, State.AssistCount), Color3.fromRGB(255, 200, 50))
                end))
            end

            local rsRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "RoomManager", "Room", "RoundStarted")
            if rsRemote and rsRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(rsRemote.OnClientEvent:Connect(function()
                    Utility.AddKillFeedEntry("— ROUND START —", Color3.fromRGB(180, 180, 255))
                end))
            end

            local dwRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "GameMode", "Duel", "Winner")
            if dwRemote and dwRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(dwRemote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    pcall(function()
                        local w = "Unknown"
                        if typeof(args[1]) == "Instance" then w = args[1].Name
                        elseif type(args[1]) == "string" then w = args[1] end
                        local c = (w == LocalPlayer.Name) and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 150, 50)
                        Utility.AddKillFeedEntry("DUEL WINNER: " .. w, c)
                    end)
                end))
            end

            local teamUpdateRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "TeamService", "UpdateData")
            if teamUpdateRemote and teamUpdateRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(teamUpdateRemote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    State.TeamDataRaw = args
                    pcall(function()
                        if type(args[1]) == "table" then
                            for k, v in pairs(args[1]) do
                                if type(k) == "string" then
                                    State.TeamData[k] = tostring(v)
                                end
                            end
                        end
                    end)
                    if Config.RemoteLogEnabled then
                        table.insert(State.RemoteLog, 1, {name = "TeamService.UpdateData", time = tick(), argCount = #args})
                        if #State.RemoteLog > 50 then table.remove(State.RemoteLog, 51) end
                    end
                end))
            end

            local wsRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "EntityService", "WalkSpeed")
            if wsRemote and wsRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(wsRemote.OnClientEvent:Connect(function(...)
                    if Config.RemoteLogEnabled then
                        table.insert(State.RemoteLog, 1, {name = "WalkSpeed", time = tick()})
                        if #State.RemoteLog > 50 then table.remove(State.RemoteLog, 51) end
                    end
                end))
            end

            local rcRemote = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "GameClient", "RoleChanged")
            if rcRemote and rcRemote:IsA("RemoteEvent") then
                Utility.RegisterConnection(rcRemote.OnClientEvent:Connect(function(...)
                    local args = {...}
                    pcall(function()
                        local role = tostring(args[1] or "Unknown")
                        State.TeamData["__myRole"] = role
                        Utility.AddKillFeedEntry("Role: " .. role, Color3.fromRGB(200, 150, 255))
                    end)
                end))
            end
        end)

        task.spawn(function()
            local function hookHumanoid()
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                State.IsAlive = hum.Health > 0
                Utility.RegisterConnection(hum.Died:Connect(function()
                    State.IsAlive = false
                    State.DeathTime = tick()
                end))
            end
            hookHumanoid()
            Utility.RegisterConnection(LocalPlayer.CharacterAdded:Connect(function()
                State.IsAlive = true
                State.LockedTarget = nil
                State.LockedCharacter = nil
                task.wait(0.5)
                hookHumanoid()
            end))
        end)

        -- Auto-respawn loop — guarded by State.Running (#2)
        task.spawn(function()
            while Core.State.Running do
                if Config.AutoRespawn and not State.IsAlive and (tick() - State.DeathTime) > 2 then
                    pcall(function()
                        local r = Utility.SafeFind(ReplicatedStorage, "Remote", "GameService", "Respawn")
                        if r and r:IsA("RemoteEvent") then
                            r:FireServer()
                            Utility.AddKillFeedEntry("Auto-Respawn", Color3.fromRGB(50, 255, 200))
                        end
                    end)
                    task.wait(3)
                end
                task.wait(0.5)
            end
        end)
    end

    return Hooks
end
