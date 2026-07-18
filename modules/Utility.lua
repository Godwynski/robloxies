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
        local MAX_KILLFEED = 6
        if #State.KillFeedEntries > MAX_KILLFEED then
            table.remove(State.KillFeedEntries, MAX_KILLFEED + 1)
        end
    end

    function Utility.Terminate()
        local State = Core.State
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
