-- init.lua
local repoURL = "https://raw.githubusercontent.com/Godwynski/robloxies/main/"

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
        if type(isfile) == "function" and type(readfile) == "function" and isfile("modules/" .. fileName) then
            return loadstring(readfile("modules/" .. fileName))()
        end
        local noCache = "?nocache=" .. tostring(tick())
        return loadstring(game:HttpGet(repoURL .. "modules/" .. fileName .. noCache))()
    end)
    
    if not success then error("Failed to load module: " .. fileName .. " | Error: " .. tostring(result)) end
    if result == nil then error("Module loaded but returned nil: " .. fileName) end
    return result
end

print("Initializing project...")

if not game:IsLoaded() then game.Loaded:Wait() end

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

-- 2. Load Core Data & Events
Core.Config = loadModule("Config.lua")(Core)
Core.State = loadModule("State.lua")(Core)
Core.Utility = loadModule("Utility.lua")(Core)
Core.EventManager = loadModule("EventManager.lua")(Core)
Core.Drawings = loadModule("Drawings.lua")(Core)
Core.Scanners = loadModule("Scanners.lua")(Core)

-- 3. Load UI Director (must load early so modules can inject tabs)
Core.UI = loadModule("UI.lua")(Core)
Core.UI.Init()

-- 4. Load Logic Modules (These should subscribe to events & register UI)
Core.Aim = loadModule("Aim.lua")(Core)
Core.ESP = loadModule("ESP.lua")(Core)
Core.Movement = loadModule("Movement.lua")(Core)
Core.Hooks = loadModule("Hooks.lua")(Core)
Core.MainLoop = loadModule("MainLoop.lua")(Core)

-- Call Init on modules that need base initialization
Core.Aim.Init()
Core.ESP.Init()
Core.Movement.Init()
Core.Hooks.Init()
Core.Drawings.Init()

-- 5. Load Game Preset as a Plugin
-- This merges configs, injects UI tabs, and sets up custom event hooks
Core.Preset = loadModule("GameIdentifier.lua")(Core, loadModule)

-- 6. Build final UI Tabs (Settings goes last)
Core.UI.BuildSettingsTab()

-- 7. Start the Main Event Loop
Core.MainLoop.Init()

print("Project loaded successfully!")
_G.__PureAutoAim_Terminate = Core.Utility.Terminate
