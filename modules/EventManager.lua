return function(Core)
    local EventManager = {
        _events = {}
    }

    -- Register a new event type if it doesn't exist
    function EventManager:RegisterEvent(eventName)
        if not self._events[eventName] then
            self._events[eventName] = {}
        end
    end

    -- Subscribe to an event
    function EventManager:Subscribe(eventName, identifier, callback)
        self:RegisterEvent(eventName)
        self._events[eventName][identifier] = callback
    end

    -- Unsubscribe from an event
    function EventManager:Unsubscribe(eventName, identifier)
        if self._events[eventName] then
            self._events[eventName][identifier] = nil
        end
    end

    -- Fire an event, calling all subscribed callbacks
    function EventManager:Fire(eventName, ...)
        if self._events[eventName] then
            for identifier, callback in pairs(self._events[eventName]) do
                local success, err = pcall(callback, ...)
                if not success then
                    warn("[EventManager] Error in callback '" .. tostring(identifier) .. "' for event '" .. tostring(eventName) .. "':", err)
                end
            end
        end
    end

    return EventManager
end
