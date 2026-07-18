return function(Core)
    local ESP = {}

    local Config = Core.Config
    local State = Core.State
    local LocalPlayer = Core.Services.Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    local Aim = Core.Aim

    function ESP.CreateESPDrawings()
        local box = Drawing.new("Square")
        box.Visible = false; box.Color = Color3.fromRGB(255, 50, 50)
        box.Thickness = 1.5; box.Filled = false

        local nameTag = Drawing.new("Text")
        nameTag.Visible = false; nameTag.Size = 13
        nameTag.Color = Color3.new(1,1,1); nameTag.Outline = true
        nameTag.Center = true; nameTag.Text = ""

        local healthBG = Drawing.new("Square")
        healthBG.Visible = false; healthBG.Color = Color3.fromRGB(30,30,30)
        healthBG.Filled = true; healthBG.Transparency = 0.5

        local healthFill = Drawing.new("Square")
        healthFill.Visible = false; healthFill.Color = Color3.fromRGB(50,200,50)
        healthFill.Filled = true

        local distTag = Drawing.new("Text")
        distTag.Visible = false; distTag.Size = 12
        distTag.Color = Color3.fromRGB(200,200,200); distTag.Outline = true
        distTag.Center = true; distTag.Text = ""

        local tracer = Drawing.new("Line")
        tracer.Visible = false; tracer.Color = Color3.fromRGB(255,50,50)
        tracer.Thickness = 1

        return {
            box = box, name = nameTag, healthBG = healthBG,
            healthFill = healthFill, dist = distTag, tracer = tracer
        }
    end

    function ESP.RemoveESPDrawings(cache)
        for _, d in pairs(cache) do pcall(function() d:Remove() end) end
    end

    function ESP.HideESPDrawings(cache)
        for _, d in pairs(cache) do pcall(function() d.Visible = false end) end
    end

    function ESP.UpdateESP()
        if not Config.ESPEnabled then return end

        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local viewport = Camera.ViewportSize

        local activeModels = {}
        local targets = {}

        if Config.TargetMode == "Players" or Config.TargetMode == "Both" then
            for _, plr in ipairs(Core.Services.Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    table.insert(targets, {char = plr.Character, name = plr.DisplayName or plr.Name})
                end
            end
        end
        if Config.TargetMode == "NPCs" or Config.TargetMode == "Both" then
            for _, npc in ipairs(State.NPCCache) do
                if npc and npc.Parent then
                    table.insert(targets, {char = npc, name = npc.Name})
                end
            end
        end

        for _, data in ipairs(targets) do
            local char = data.char
            activeModels[char] = true

            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not root then
                if State.ESPCache[char] then ESP.HideESPDrawings(State.ESPCache[char]) end
                continue
            end

            local vcVisible = char:GetAttribute("vc_Visible")
            if vcVisible == false then
                if State.ESPCache[char] then ESP.HideESPDrawings(State.ESPCache[char]) end
                continue
            end
            if vcVisible == nil and hum and hum.Health <= 0 then
                if State.ESPCache[char] then ESP.HideESPDrawings(State.ESPCache[char]) end
                continue
            end

            local dist3D = myRoot and (root.Position - myRoot.Position).Magnitude or 0
            if dist3D > Config.ESPMaxDist then
                if State.ESPCache[char] then ESP.HideESPDrawings(State.ESPCache[char]) end
                continue
            end

            local sp, onScreen = Camera:WorldToScreenPoint(root.Position)
            if not onScreen then
                if State.ESPCache[char] then ESP.HideESPDrawings(State.ESPCache[char]) end
                continue
            end

            if not State.ESPCache[char] then
                State.ESPCache[char] = ESP.CreateESPDrawings()
            end
            local cache = State.ESPCache[char]

            local espColor = Color3.fromRGB(255, 50, 50)
            if Config.ESPTeamColor and myChar then
                if Aim.IsSameTeam(myChar, char) then
                    espColor = Color3.fromRGB(50, 255, 50)
                end
            end

            local cf = root.CFrame
            local size = Vector3.new(4, 5.5, 2)
            local x, y, z = size.X/2, size.Y/2, size.Z/2
            
            local corners = {
                (cf * CFrame.new(x, y, z)).Position,
                (cf * CFrame.new(-x, y, z)).Position,
                (cf * CFrame.new(x, -y, z)).Position,
                (cf * CFrame.new(-x, -y, z)).Position,
                (cf * CFrame.new(x, y, -z)).Position,
                (cf * CFrame.new(-x, y, -z)).Position,
                (cf * CFrame.new(x, -y, -z)).Position,
                (cf * CFrame.new(-x, -y, -z)).Position,
            }
            
            local minX, minY = math.huge, math.huge
            local maxX, maxY = -math.huge, -math.huge
            
            for _, pt in ipairs(corners) do
                local ptSp = Camera:WorldToScreenPoint(pt)
                if ptSp.X < minX then minX = ptSp.X end
                if ptSp.X > maxX then maxX = ptSp.X end
                if ptSp.Y < minY then minY = ptSp.Y end
                if ptSp.Y > maxY then maxY = ptSp.Y end
            end
            
            local boxW = maxX - minX
            local boxH = maxY - minY
            local boxX = minX
            local boxY = minY

            if Config.ESPBoxes then
                cache.box.Size = Vector2.new(boxW, boxH)
                cache.box.Position = Vector2.new(boxX, boxY)
                cache.box.Color = espColor
                cache.box.Visible = true
            else
                cache.box.Visible = false
            end

            if Config.ESPNames then
                cache.name.Text = data.name
                cache.name.Position = Vector2.new(sp.X, boxY - 16)
                cache.name.Color = espColor
                cache.name.Visible = true
            else
                cache.name.Visible = false
            end

            if Config.ESPHealth then
                local hpPct = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 1
                local barW = 3
                local barX = boxX - barW - 2

                cache.healthBG.Size = Vector2.new(barW, boxH)
                cache.healthBG.Position = Vector2.new(barX, boxY)
                cache.healthBG.Visible = true

                local fillH = boxH * hpPct
                cache.healthFill.Size = Vector2.new(barW, fillH)
                cache.healthFill.Position = Vector2.new(barX, boxY + (boxH - fillH))
                if hpPct > 0.6 then cache.healthFill.Color = Color3.fromRGB(50, 200, 50)
                elseif hpPct > 0.3 then cache.healthFill.Color = Color3.fromRGB(255, 200, 50)
                else cache.healthFill.Color = Color3.fromRGB(255, 60, 60) end
                cache.healthFill.Visible = true
            else
                cache.healthBG.Visible = false
                cache.healthFill.Visible = false
            end

            if Config.ESPDistance then
                cache.dist.Text = string.format("%dm", math.floor(dist3D))
                cache.dist.Position = Vector2.new(sp.X, boxY + boxH + 2)
                cache.dist.Visible = true
            else
                cache.dist.Visible = false
            end

            if Config.ESPTracers then
                cache.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
                cache.tracer.To = Vector2.new(sp.X, boxY + boxH)
                cache.tracer.Color = espColor
                cache.tracer.Visible = true
            else
                cache.tracer.Visible = false
            end
        end

        for model, cache in pairs(State.ESPCache) do
            if not activeModels[model] then
                ESP.RemoveESPDrawings(cache)
                State.ESPCache[model] = nil
            end
        end
    end

    return ESP
end
