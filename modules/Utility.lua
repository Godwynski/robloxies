return function(Core)
    local Utility = {}

    function Utility.SafeFind(parent, ...)
        local current = parent
        for _, name in ipairs({...}) do
            if not current then return nil end
            current = current:FindFirstChild(name)
        end
        return current
    end

    function Utility.OptimizeFPS()
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass('Terrain')
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        if sethiddenproperty then
            pcall(function() sethiddenproperty(Lighting, "Technology", 2) end)
        end

        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
        end

        for _, obj in ipairs(workspace:GetDescendants()) do
            -- Skip all player characters to avoid breaking gameplay/detection
            local isCharPart = false
            for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
                if plr.Character and obj:IsDescendantOf(plr.Character) then
                    isCharPart = true; break
                end
            end
            if isCharPart then continue end

            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Lifetime = NumberRange.new(0)
            elseif obj:IsA("Fire") or obj:IsA("SpotLight") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end

        for _, obj in ipairs(Lighting:GetDescendants()) do
            if obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("BloomEffect") or obj:IsA("DepthOfFieldEffect") then
                obj.Enabled = false
            end
        end
    end

    function Utility.RegisterConnection(conn)
        table.insert(Core.State.ActiveConnections, conn)
        return conn
    end

    function Utility.AddKillFeedEntry(text, color)
        local State = Core.State
        table.insert(State.KillFeedEntries, 1, {
            text = text,
            time = tick(),
            color = color or Color3.new(1, 1, 1)
        })
        local MAX = Core.Config.MaxKillFeed or 6
        if #State.KillFeedEntries > MAX then
            table.remove(State.KillFeedEntries, MAX + 1)
        end
    end

    function Utility.Terminate()
        local State = Core.State
        State.Running = false -- Signal all background while-true loops to stop
        _G.__PureAutoAim_Running = false -- Clear global guard so re-execution is clean

        for _, conn in ipairs(State.ActiveConnections) do
            if conn.Connected then pcall(function() conn:Disconnect() end) end
        end
        table.clear(State.ActiveConnections)
        pcall(function() Core.Services.RunService:UnbindFromRenderStep("AutoAimLoop") end)

        local Drawings = Core.Drawings
        if Drawings then
            local allDrawings = {
                Drawings.FOVCircle, Drawings.DiagnosticText, Drawings.TargetInfoText, 
                Drawings.TargetHealthBG, Drawings.TargetHealthFill, Drawings.HitMarker, 
                Drawings.LockIndicator
            }
            for _, d in ipairs(allDrawings) do pcall(function() d:Remove() end) end
            for _, d in ipairs(Drawings.KillFeedDrawings) do pcall(function() d:Remove() end) end
        end

        for plr, cache in pairs(State.ESPCache) do
            for _, drawing in pairs(cache) do
                pcall(function() drawing:Remove() end)
            end
        end
        table.clear(State.ESPCache)
    end

    return Utility
end
