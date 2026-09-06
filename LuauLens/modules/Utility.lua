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

-- Module dependency resolver (handles bundles, Studio script hierarchy, and direct paths)
local function resolveModule(modName)
    if type(__require) == "function" then
        local ok, mod = pcall(__require, modName)
        if ok and mod then return mod end
    end
    local success, res = pcall(function()
        if script and script:FindFirstChild("modules") and script.modules:FindFirstChild(modName) then
            return require(script.modules[modName])
        end
        if script and script.Parent and script.Parent:FindFirstChild(modName) then
            return require(script.Parent[modName])
        end
    end)
    if success and res then return res end
    local ok, resMod = pcall(function()
        local r = require
        return r(modName)
    end)
    if ok and resMod then return resMod end
    return nil
end

--[[
    Utility.Export(data, filename)
    Handles saving data. Uses writefile if available, and setclipboard as a graceful fallback.
    Automatically serializes tables to JSON if passed a table.
    Returns (success: boolean, message: string).
]]
function Utility.Export(data, filename)
    filename = filename or ("LuauLens_Export_" .. tostring(os.time()) .. ".txt")
    local strContent = ""
    if type(data) == "table" then
        local Serializer = resolveModule("Serializer")
        if Serializer and type(Serializer.ToJSON) == "function" then
            local ok, json = pcall(function()
                return Serializer.ToJSON(Serializer.Serialize(data, 5), 0)
            end)
            if ok and json then strContent = json end
        end
        if #strContent == 0 then
            local ok, json = pcall(function()
                return game:GetService("HttpService"):JSONEncode(data)
            end)
            strContent = (ok and json) or tostring(data)
        end
    else
        strContent = tostring(data)
    end

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
    local ok, formatted = pcall(function()
        return DateTime.now():FormatLocalTime("HH:mm:ss.SSS", "en-us")
    end)
    if ok and formatted then return formatted end

    local clock = os.clock()
    local millis = math.floor((clock % 1) * 1000)
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
