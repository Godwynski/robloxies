--[[
    LuauLens/modules/Utility.lua
    Environment detection, file/clipboard export abstraction, and reflection helper functions.
]]

local Utility = {}

local Services = {
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Stats = game:GetService("Stats"),
}

Utility.Services = Services

--[[
    Utility.IsStudio()
    Returns true if the current environment is running inside Roblox Studio.
]]
function Utility.IsStudio()
    local isStudio = false
    pcall(function()
        isStudio = Services.RunService:IsStudio()
    end)
    return isStudio
end

--[[
    Utility.GetEnvironment()
    Discovers available runtime APIs and execution capabilities.
]]
function Utility.GetEnvironment()
    return {
        IsStudio = Utility.IsStudio(),
        HasWritefile = type(writefile) == "function",
        HasClipboard = (type(setclipboard) == "function") or (type(toclipboard) == "function"),
        HasHookMeta = type(hookmetamethod) == "function",
        HasGetHui = type(gethui) == "function",
    }
end

--[[
    Utility.GetInstancePath(instance)
    Computes the canonical game hierarchy path of an Instance.
    Example: game:GetService("ReplicatedStorage").Remotes.AttackEvent
]]
function Utility.GetInstancePath(instance)
    if not instance then return "nil" end

    local success, path = pcall(function()
        local segments = {}
        local current = instance
        while current and current ~= game do
            table.insert(segments, 1, current.Name)
            current = current.Parent
        end

        if #segments == 0 then return "game" end

        local serviceName = segments[1]
        local isKnownService = false
        pcall(function()
            if game:GetService(serviceName) then isKnownService = true end
        end)

        local result = ""
        if isKnownService then
            result = string.format('game:GetService("%s")', serviceName)
        else
            result = string.format('game["%s"]', serviceName)
        end

        for i = 2, #segments do
            local seg = segments[i]
            if seg:match("^[%a_][%w_]*$") then
                result = result .. "." .. seg
            else
                result = result .. string.format('["%s"]', seg:gsub('"', '\\"'))
            end
        end
        return result
    end)

    if success then
        return path
    else
        return instance.Name or "UnknownInstance"
    end
end

--[[
    Utility.Export(data, filename)
    Handles saving data. Uses writefile if available, and setclipboard as a graceful fallback.
    Returns (success: boolean, message: string).
]]
function Utility.Export(data, filename)
    filename = filename or ("LuauLens_Export_" .. tostring(os.time()) .. ".txt")
    local strContent = (type(data) == "table") and tostring(data) or tostring(data)

    -- 1. Try writefile (Studio plugins, local environments, or supported tools)
    if type(writefile) == "function" then
        local success, err = pcall(function()
            writefile(filename, strContent)
        end)
        if success then
            return true, "Successfully saved to file: " .. filename
        end
    end

    -- 2. Fallback: Copy to system clipboard
    if type(setclipboard) == "function" then
        local success = pcall(function() setclipboard(strContent) end)
        if success then
            return true, "Exported to clipboard (via setclipboard)"
        end
    end

    if type(toclipboard) == "function" then
        local success = pcall(function() toclipboard(strContent) end)
        if success then
            return true, "Exported to clipboard (via toclipboard)"
        end
    end

    return false, "Neither writefile nor clipboard API available in this environment."
end

-- Formatted timestamp: HH:MM:SS.mmm
function Utility.GetFormattedTime()
    local clock = os.clock()
    local sec = math.floor(clock)
    local millis = math.floor((clock - sec) * 1000)
    local dateTable = os.date("*t")
    return string.format("%02d:%02d:%02d.%03d", dateTable.hour, dateTable.min, dateTable.sec, millis)
end

-- Total memory usage in MB
function Utility.GetMemoryUsageMB()
    local mem = 0
    pcall(function()
        mem = Services.Stats:GetTotalMemoryUsageMb()
    end)
    return math.floor(mem * 10) / 10
end

-- String truncation helper
function Utility.Truncate(str, maxLen)
    maxLen = maxLen or 40
    if not str then return "" end
    if #str > maxLen then
        return str:sub(1, maxLen - 3) .. "..."
    end
    return str
end

return Utility
