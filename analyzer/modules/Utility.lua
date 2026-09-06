-- analyzer/modules/Utility.lua
-- General utilities, environment detection, file exports, and reflection helpers

local Utility = {}

local Services = {
    RunService = game:GetService("RunService"),
    Players = game:GetService("Players"),
    Stats = game:GetService("Stats"),
    HttpService = game:GetService("HttpService"),
}

Utility.Services = Services

-- Environment capabilities detection
function Utility.GetEnvironment()
    local isStudio = false
    pcall(function()
        isStudio = Services.RunService:IsStudio()
    end)

    local hasWritefile = type(writefile) == "function"
    local hasClipboard = (type(setclipboard) == "function") or (type(toclipboard) == "function")
    local hasHookMeta = type(hookmetamethod) == "function"
    local hasGetGC = type(getgc) == "function"
    local hasDecompile = type(decompile) == "function"
    local hasGetHui = type(gethui) == "function"

    return {
        IsStudio = isStudio,
        HasWritefile = hasWritefile,
        HasClipboard = hasClipboard,
        HasHookMeta = hasHookMeta,
        HasGetGC = hasGetGC,
        HasDecompile = hasDecompile,
        HasGetHui = hasGetHui,
    }
end

-- Safely copy text to clipboard or fallback
function Utility.SetClipboard(text)
    if type(setclipboard) == "function" then
        local success = pcall(function() setclipboard(text) end)
        if success then return true, "Copied to clipboard (setclipboard)" end
    end
    if type(toclipboard) == "function" then
        local success = pcall(function() toclipboard(text) end)
        if success then return true, "Copied to clipboard (toclipboard)" end
    end
    return false, "Clipboard API not available in current environment"
end

-- Safely export data to file or return content
function Utility.SaveFile(filename, content)
    if type(writefile) == "function" then
        local success, err = pcall(function()
            writefile(filename, content)
        end)
        if success then
            return true, "Saved to " .. filename
        else
            return false, "writefile error: " .. tostring(err)
        end
    end
    return false, "writefile API not available (fallback to clipboard or UI export)"
end

-- Formatted timestamp: HH:MM:SS.mmm
function Utility.GetFormattedTime()
    local clock = os.clock()
    local sec = math.floor(clock)
    local millis = math.floor((clock - sec) * 1000)
    local dateTable = os.date("*t")
    return string.format("%02d:%02d:%02d.%03d", dateTable.hour, dateTable.min, dateTable.sec, millis)
end

-- Formats a clean Lua access path for an instance
function Utility.GetInstancePath(inst)
    if not inst then return "nil" end
    local success, path = pcall(function()
        local current = inst
        local segments = {}
        while current and current ~= game do
            table.insert(segments, 1, current.Name)
            current = current.Parent
        end

        if #segments == 0 then
            return "game"
        end

        local serviceName = segments[1]
        local isKnownService = false
        pcall(function()
            if game:GetService(serviceName) then
                isKnownService = true
            end
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
        return inst.Name or "UnknownInstance"
    end
end

-- Get parent service name
function Utility.GetServiceRoot(inst)
    local current = inst
    while current and current.Parent and current.Parent ~= game do
        current = current.Parent
    end
    return current and current.Name or "UnknownService"
end

-- Memory usage in MB
function Utility.GetMemoryUsageMB()
    local mem = 0
    pcall(function()
        mem = Services.Stats:GetTotalMemoryUsageMb()
    end)
    return math.floor(mem * 10) / 10
end

-- Truncate string for compact table/list previews
function Utility.Truncate(str, maxLen)
    maxLen = maxLen or 40
    if not str then return "" end
    if #str > maxLen then
        return str:sub(1, maxLen - 3) .. "..."
    end
    return str
end

-- Simple table clone (shallow)
function Utility.ShallowClone(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

return Utility
