-- init.lua
local repoURL = "https://raw.githubusercontent.com/Godwynski/robloxies/main/"

-- Duplicate instance protection: clean up any previous run
if _G.__PureAutoAim_Running then
    pcall(function() _G.__PureAutoAim_Terminate() end)
end
_G.__PureAutoAim_Running = true

for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
    if gui.Name == "PureAutoAimPanel" then pcall(function() gui:Destroy() end) end
end
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name == "PureAutoAimPanel" then gui:Destroy() end
        end
    end
end)

local function loadModule(fileName)
    local success, result = pcall(function()
        -- Local execution fallback for testing in an executor before pushing to GitHub
        if isfile and isfile("modules/" .. fileName) then
            return loadstring(readfile("modules/" .. fileName))()
        end
        -- Production GitHub fetch
        local noCache = "?nocache=" .. tostring(tick())
        return loadstring(game:HttpGet(repoURL .. "modules/" .. fileName .. noCache))()
    end)
    
    if not success then
        error("Failed to load module: " .. fileName .. " | Error: " .. tostring(result))
    end
    if result == nil then
        error("Module loaded but returned nil: " .. fileName .. " (check the module returns a value)")
    end
    return result
end

print("Initializing project...")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- 1. Construct Core System
local Core = {
    Services = {
        Players = game:GetService("Players"),
        RunService = game:GetService("RunService"),
        UserInputService = game:GetService("UserInputService"),
        CoreGui = game:GetService("CoreGui"),
        Stats = game:GetService("Stats"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        CollectionService = game:GetService("CollectionService"),
    }
}

-- 2. Load and Inject State / Config
Core.Config = loadModule("Config.lua")(Core)
Core.State = loadModule("State.lua")(Core)
Core.Utility = loadModule("Utility.lua")(Core)
Core.Drawings = loadModule("Drawings.lua")(Core)
Core.Scanners = loadModule("Scanners.lua")(Core)

-- 3. Load Logic Modules
Core.Aim = loadModule("Aim.lua")(Core)
Core.ESP = loadModule("ESP.lua")(Core)
Core.Movement = loadModule("Movement.lua")(Core)
Core.Hooks = loadModule("Hooks.lua")(Core)
Core.UI = loadModule("UI.lua")(Core)
Core.MainLoop = loadModule("MainLoop.lua")(Core)

-- 4. Load Game Preset (must be before UI so buttons spawn with correct state)
Core.Preset = loadModule("GameIdentifier.lua")(Core, loadModule)

-- 5. Initialize Sub-Systems
Core.Movement.Init()
Core.Hooks.Init()
if Core.Preset and Core.Preset.Init then
    Core.Preset.Init()
end
Core.UI.Init()
Core.MainLoop.Init()

print("Project loaded successfully!")
_G.__PureAutoAim_Terminate = Core.Utility.Terminate

