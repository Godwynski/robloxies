--[[
    LuauLens/modules/Serializer.lua
    Safe recursive serialization of Luau primitives, complex Roblox data types,
    and DataModel Instance references with cycle protection and recursion depth limits.
]]

local Serializer = {}

-- String escaper for robust JSON encoding
local function escapeString(str)
    local s = str:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    s = s:gsub('[\0-\31]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end)
    return s
end

-- Resolve full hierarchy path of an instance safely
local function getInstancePath(inst)
    if not inst then return "nil" end
    local success, path = pcall(function()
        local segments = {}
        local current = inst
        while current and current ~= game do
            table.insert(segments, 1, current.Name)
            current = current.Parent
        end
        if #segments == 0 then return "game" end

        local service = segments[1]
        local isService = false
        pcall(function()
            if game:GetService(service) then isService = true end
        end)

        local result = isService and string.format('game:GetService("%s")', service) or string.format('game["%s"]', service)
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

    return success and path or (inst.Name or "UnknownInstance")
end

--[[
    Serializer.Serialize(data, maxDepth, currentDepth, visited)
    Recursively converts arbitrary Luau and Roblox objects into a clean, JSON-compatible
    data structure. Handles complex engine types, circular references, and recursion bounds.
]]
function Serializer.Serialize(data, maxDepth, currentDepth, visited)
    maxDepth = maxDepth or 5
    currentDepth = currentDepth or 0
    visited = visited or {}

    local valType = typeof(data)

    -- 1. Primitive types
    if valType == "nil" then
        return nil
    elseif valType == "number" then
        if data ~= data then return "NaN" end
        if data == math.huge then return "Infinity" end
        if data == -math.huge then return "-Infinity" end
        return data
    elseif valType == "string" or valType == "boolean" then
        return data

    -- 2. Roblox DataModel Instances
    elseif valType == "Instance" then
        return {
            __type = "Instance",
            ClassName = data.ClassName,
            Name = data.Name,
            Path = getInstancePath(data)
        }

    -- 3. Geometric & Spatial Types
    elseif valType == "Vector3" then
        return {
            __type = "Vector3",
            X = math.floor(data.X * 1000) / 1000,
            Y = math.floor(data.Y * 1000) / 1000,
            Z = math.floor(data.Z * 1000) / 1000
        }
    elseif valType == "Vector2" then
        return {
            __type = "Vector2",
            X = math.floor(data.X * 1000) / 1000,
            Y = math.floor(data.Y * 1000) / 1000
        }
    elseif valType == "CFrame" then
        local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = data:GetComponents()
        return {
            __type = "CFrame",
            Position = { X = x, Y = y, Z = z },
            Matrix = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
        }

    -- 4. Color & Appearance Types
    elseif valType == "Color3" then
        return {
            __type = "Color3",
            R = math.floor(data.R * 255),
            G = math.floor(data.G * 255),
            B = math.floor(data.B * 255),
            Hex = data:ToHex()
        }
    elseif valType == "BrickColor" then
        return {
            __type = "BrickColor",
            Name = data.Name,
            Number = data.Number
        }

    -- 5. UI Layout Types
    elseif valType == "UDim" then
        return {
            __type = "UDim",
            Scale = data.Scale,
            Offset = data.Offset
        }
    elseif valType == "UDim2" then
        return {
            __type = "UDim2",
            X = { Scale = data.X.Scale, Offset = data.X.Offset },
            Y = { Scale = data.Y.Scale, Offset = data.Y.Offset }
        }

    -- 6. Engine Enumerations & DateTime
    elseif valType == "EnumItem" then
        return {
            __type = "EnumItem",
            Enum = tostring(data.EnumType),
            Name = data.Name,
            Value = data.Value
        }
    elseif valType == "DateTime" then
        return {
            __type = "DateTime",
            IsoDate = data:ToIsoDate(),
            UnixTimestamp = data.UnixTimestamp
        }

    -- 7. Sequences and Ranges
    elseif valType == "ColorSequence" or valType == "NumberSequence" or valType == "NumberRange" then
        return {
            __type = valType,
            Value = tostring(data)
        }

    -- 8. Tables (Recursive array vs dictionary handling)
    elseif valType == "table" then
        -- Circular reference protection
        if visited[data] then
            return { __type = "CircularReference", Ref = tostring(data) }
        end

        -- Max recursion depth limit
        if currentDepth >= maxDepth then
            return { __type = "DepthLimitExceeded", Ref = tostring(data) }
        end

        visited[data] = true

        -- Determine if table is an array
        local isArray = true
        local count = 0
        for k, _ in pairs(data) do
            count = count + 1
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
            end
        end

        if isArray and count > 0 then
            for i = 1, count do
                if rawget(data, i) == nil then
                    isArray = false
                    break
                end
            end
        end

        if isArray and count > 0 then
            local arr = {}
            for i = 1, count do
                table.insert(arr, Serializer.Serialize(data[i], maxDepth, currentDepth + 1, visited))
            end
            visited[data] = nil
            return arr
        else
            local dict = {}
            for k, v in pairs(data) do
                dict[tostring(k)] = Serializer.Serialize(v, maxDepth, currentDepth + 1, visited)
            end
            visited[data] = nil
            return dict
        end

    -- 9. Functions & Other Types
    elseif valType == "function" then
        return { __type = "Function", Address = tostring(data) }
    else
        return tostring(data)
    end
end

--[[
    Serializer.ToJSON(data, indentLevel)
    Converts a serialized table structure into a formatted JSON string.
]]
function Serializer.ToJSON(data, indentLevel)
    indentLevel = indentLevel or 0
    local indentStr = string.rep("  ", indentLevel)
    local nextIndentStr = string.rep("  ", indentLevel + 1)
    local t = typeof(data)

    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return data and "true" or "false"
    elseif t == "number" then
        if data ~= data or data == math.huge or data == -math.huge then
            return "null"
        end
        return tostring(data)
    elseif t == "string" then
        return '"' .. escapeString(data) .. '"'
    elseif t == "table" then
        local isArray = true
        local maxIdx = 0
        local count = 0
        for k, _ in pairs(data) do
            count = count + 1
            if type(k) == "number" and k > 0 and math.floor(k) == k then
                if k > maxIdx then maxIdx = k end
            else
                isArray = false
            end
        end
        if isArray and maxIdx ~= count then isArray = false end

        if count == 0 then return "{}" end

        if isArray then
            if count <= 4 and indentLevel > 2 then
                local pieces = {}
                for i = 1, count do
                    table.insert(pieces, Serializer.ToJSON(data[i], 0))
                end
                return "[" .. table.concat(pieces, ", ") .. "]"
            end

            local lines = {}
            for i = 1, count do
                table.insert(lines, nextIndentStr .. Serializer.ToJSON(data[i], indentLevel + 1))
            end
            return "[\n" .. table.concat(lines, ",\n") .. "\n" .. indentStr .. "]"
        else
            local keys = {}
            for k, _ in pairs(data) do table.insert(keys, tostring(k)) end
            table.sort(keys)

            local lines = {}
            for _, k in ipairs(keys) do
                local val = data[k]
                local line = nextIndentStr .. '"' .. escapeString(k) .. '": ' .. Serializer.ToJSON(val, indentLevel + 1)
                table.insert(lines, line)
            end
            return "{\n" .. table.concat(lines, ",\n") .. "\n" .. indentStr .. "}"
        end
    else
        return '"' .. escapeString(tostring(data)) .. '"'
    end
end

--[[
    Serializer.FormatPreview(value)
    Returns a human-readable one-line preview of any value for UI inspector listings.
]]
function Serializer.FormatPreview(value)
    local t = typeof(value)
    if t == "nil" then
        return "nil"
    elseif t == "string" then
        if #value > 45 then
            return '"' .. value:sub(1, 42) .. '..."'
        end
        return '"' .. value .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "Instance" then
        return "[" .. value.ClassName .. "] " .. value.Name
    elseif t == "Vector3" then
        return string.format("Vector3(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
    elseif t == "CFrame" then
        local p = value.Position
        return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(value.R * 255), math.floor(value.G * 255), math.floor(value.B * 255))
    elseif t == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return "{...} (" .. count .. " items)"
    elseif t == "function" then
        return "function()"
    else
        return tostring(value)
    end
end

return Serializer
