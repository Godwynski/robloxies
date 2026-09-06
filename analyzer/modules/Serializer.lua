-- analyzer/modules/Serializer.lua
-- Robust serialization of Luau & Roblox DataModel types for inspection and export

local Serializer = {}

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

-- Convert any Roblox or Luau value into a plain JSON-safe primitive or dictionary
function Serializer.Serialize(value, maxDepth, currentDepth, visited)
    maxDepth = maxDepth or 5
    currentDepth = currentDepth or 0
    visited = visited or {}

    local valType = typeof(value)

    if valType == "nil" then
        return nil
    elseif valType == "number" then
        if value ~= value then -- NaN
            return "NaN"
        elseif value == math.huge then
            return "Infinity"
        elseif value == -math.huge then
            return "-Infinity"
        end
        return value
    elseif valType == "string" or valType == "boolean" then
        return value
    elseif valType == "Instance" then
        local fullName = "UnknownInstance"
        pcall(function()
            fullName = value:GetFullName()
        end)
        return {
            __type = "Instance",
            ClassName = value.ClassName,
            Name = value.Name,
            FullName = fullName,
        }
    elseif valType == "Vector3" then
        return { __type = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
    elseif valType == "Vector2" then
        return { __type = "Vector2", X = value.X, Y = value.Y }
    elseif valType == "CFrame" then
        local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
        return {
            __type = "CFrame",
            Position = { X = x, Y = y, Z = z },
            Matrix = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
        }
    elseif valType == "Color3" then
        return {
            __type = "Color3",
            R = math.floor(value.R * 255),
            G = math.floor(value.G * 255),
            B = math.floor(value.B * 255),
            Hex = value:ToHex()
        }
    elseif valType == "BrickColor" then
        return { __type = "BrickColor", Name = value.Name, Number = value.Number }
    elseif valType == "UDim" then
        return { __type = "UDim", Scale = value.Scale, Offset = value.Offset }
    elseif valType == "UDim2" then
        return {
            __type = "UDim2",
            X = { Scale = value.X.Scale, Offset = value.X.Offset },
            Y = { Scale = value.Y.Scale, Offset = value.Y.Offset }
        }
    elseif valType == "EnumItem" then
        return { __type = "EnumItem", Enum = tostring(value.EnumType), Name = value.Name, Value = value.Value }
    elseif valType == "DateTime" then
        return { __type = "DateTime", IsoDate = value:ToIsoDate(), UnixTimestamp = value.UnixTimestamp }
    elseif valType == "ColorSequence" or valType == "NumberSequence" or valType == "NumberRange" then
        return { __type = valType, Value = tostring(value) }
    elseif valType == "table" then
        if visited[value] then
            return { __type = "CircularReference", Ref = tostring(value) }
        end

        if currentDepth >= maxDepth then
            return { __type = "TruncatedTable", Ref = tostring(value) }
        end

        visited[value] = true
        local result = {}
        local isArray = true
        local count = 0

        for k, v in pairs(value) do
            count = count + 1
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
            end
        end

        if isArray and count > 0 then
            -- Verify sequential array keys
            for i = 1, count do
                if rawget(value, i) == nil then
                    isArray = false
                    break
                end
            end
        end

        if isArray and count > 0 then
            local arr = {}
            for i = 1, count do
                table.insert(arr, Serializer.Serialize(value[i], maxDepth, currentDepth + 1, visited))
            end
            visited[value] = nil
            return arr
        else
            local dict = {}
            for k, v in pairs(value) do
                local keyStr = tostring(k)
                dict[keyStr] = Serializer.Serialize(v, maxDepth, currentDepth + 1, visited)
            end
            visited[value] = nil
            return dict
        end
    elseif valType == "function" then
        return { __type = "Function", Address = tostring(value) }
    else
        return tostring(value)
    end
end

-- Convert serialized table structure to formatted JSON string
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
        -- Check if it's an array
        local isArray = true
        local maxIndex = 0
        local count = 0
        for k, _ in pairs(data) do
            count = count + 1
            if type(k) == "number" and k > 0 and math.floor(k) == k then
                if k > maxIndex then maxIndex = k end
            else
                isArray = false
            end
        end
        if isArray and maxIndex ~= count then
            isArray = false
        end

        if count == 0 then
            return "{}"
        end

        if isArray then
            if count <= 4 and indentLevel > 2 then
                -- Compact inline array for small tuples
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
            for k, _ in pairs(data) do
                table.insert(keys, tostring(k))
            end
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

-- Formats a value for quick readable display in the UI console / inspector
function Serializer.FormatPreview(value)
    local t = typeof(value)
    if t == "nil" then
        return "nil"
    elseif t == "string" then
        if #value > 60 then
            return '"' .. value:sub(1, 57) .. '..."'
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
