return function(Core)
    local Utility = {}

    function Utility.RegisterConnection(conn)
        table.insert(Core.State.ActiveConnections, conn)
        return conn
    end

    function Utility.SafeDestroy(obj)
        if not obj then return end
        if typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        elseif type(obj) == "table" or type(obj) == "userdata" then
            pcall(function()
                if obj.Remove then
                    obj:Remove()
                elseif obj.Destroy then
                    obj:Destroy()
                end
            end)
        end
    end

    function Utility.Terminate()
        local State = Core.State
        State.Running = false
        _G.__Movement_Running = false
        _G.__Restaurant_Running = false

        -- Disconnect all event connections
        for _, conn in ipairs(State.ActiveConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
        table.clear(State.ActiveConnections)

        -- Clean up Restaurant module
        if Core.Restaurant and Core.Restaurant.Cleanup then
            pcall(Core.Restaurant.Cleanup)
        end

        -- Restore Movement if active
        if Core.Movement and Core.Movement.Cleanup then
            pcall(Core.Movement.Cleanup)
        end

        -- Clean up UI ScreenGui if active
        pcall(function()
            if Core.UI and Core.UI.Window and Core.UI.Window.Library and Core.UI.Window.Library.Interface then
                Core.UI.Window.Library.Interface:Destroy()
            end
        end)
    end

    return Utility
end
