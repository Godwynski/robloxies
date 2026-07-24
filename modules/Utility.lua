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

    local autoFpsConn = nil

    local function buildCharacterSet()
        local set = {}
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            if plr.Character then set[plr.Character] = true end
        end
        return set
    end

    local cachedCharSet = nil
    local lastCharSetBuild = 0
    local function getCharacterSet()
        local now = os.clock()
        if not cachedCharSet or now - lastCharSetBuild > 0.5 then
            cachedCharSet = buildCharacterSet()
            lastCharSetBuild = now
        end
        return cachedCharSet
    end

    local function isCharacterPart(obj, charSet)
        local current = obj
        while current and current ~= workspace do
            if charSet[current] then return true end
            current = current.Parent
        end
        return false
    end

    local function optimizeObject(obj, level, charSet)
        if not obj or not obj.Parent or isCharacterPart(obj, charSet) then return end

        if level >= 1 then
            if obj:IsA("PostEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("BloomEffect") or obj:IsA("DepthOfFieldEffect") then
                pcall(function() obj.Enabled = false end)
            end
        end

        if level >= 2 then
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                end)
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                pcall(function() obj.Transparency = 1 end)
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                pcall(function()
                    obj.Enabled = false
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                        obj.Lifetime = NumberRange.new(0)
                    end
                end)
            elseif obj:IsA("Fire") or obj:IsA("SpotLight") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("PointLight") or obj:IsA("SurfaceLight") then
                pcall(function() obj.Enabled = false end)
            end
        end

        if level >= 3 then
            if obj:IsA("SurfaceAppearance") then
                pcall(function() obj:Destroy() end)
            elseif obj:IsA("MeshPart") then
                pcall(function() obj.RenderFidelity = Enum.RenderFidelity.Performance end)
            end
        end
    end

    function Utility.OptimizeFPS(level)
        level = level or 3
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass('Terrain')

        -- 1. Lighting Optimizations
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        pcall(function()
            Lighting.EnvironmentSpecularScale = 0
            Lighting.EnvironmentDiffuseScale = 0
        end)
        if sethiddenproperty then
            pcall(function() sethiddenproperty(Lighting, "Technology", 2) end)
        end

        -- 2. Terrain Optimizations
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
            pcall(function() Terrain.Decoration = false end)
        end

        -- 3. Lighting Descendants (Post-processing)
        for _, obj in ipairs(Lighting:GetDescendants()) do
            if obj:IsA("PostEffect") or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("BloomEffect") or obj:IsA("DepthOfFieldEffect") then
                pcall(function() obj.Enabled = false end)
            end
        end

        -- 4. Workspace Descendants Optimization with O(1) Character Set lookup
        local charSet = getCharacterSet()
        local count = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            optimizeObject(obj, level, charSet)
            count = count + 1
            if count % 1500 == 0 then task.wait() end
        end
    end

    function Utility.EnableAutoFPSOptimizer(enabled)
        if autoFpsConn then
            pcall(function() autoFpsConn:Disconnect() end)
            autoFpsConn = nil
        end
        if enabled then
            autoFpsConn = workspace.DescendantAdded:Connect(function(obj)
                task.defer(function()
                    local charSet = getCharacterSet()
                    optimizeObject(obj, 3, charSet)
                end)
            end)
            Utility.RegisterConnection(autoFpsConn)
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
            time = os.clock(),
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
            if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
        table.clear(State.ActiveConnections)
        pcall(function() Core.Services.RunService:UnbindFromRenderStep("PureAutoAimLoop") end)

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
