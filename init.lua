-- init.lua
local repoURL = "https://raw.githubusercontent.com/Godwynski/robloxies/run-a-restaurant/"

-- Terminate previous instance if running
if _G.__Restaurant_Running then
    pcall(function() _G.__Restaurant_Terminate() end)
end
if _G.__Movement_Running then
    pcall(function() _G.__Movement_Terminate() end)
end
if _G.__PureAutoAim_Running then
    pcall(function() _G.__PureAutoAim_Terminate() end)
end
_G.__Restaurant_Running = true

-- Clean up any lingering GUI instances
local hiddenUI = (gethui and gethui()) or game:GetService("CoreGui")
for _, gui in ipairs(hiddenUI:GetChildren()) do
    if gui.Name == "RestaurantUtilityPanel" or gui.Name == "RobloxMovementPanel" or gui.Name == "PureAutoAimPanel" then
        pcall(function() gui:Destroy() end)
    end
end
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name == "RestaurantUtilityPanel" or gui.Name == "RobloxMovementPanel" or gui.Name == "PureAutoAimPanel" then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end)

-- Helper loader supporting both modular HttpGet and bundled execution
local loadModule
loadModule = function(modulePath)
    local ok, res = pcall(require, modulePath)
    if ok and res then return res end

    local filePath = modulePath:gsub("%.", "/") .. ".lua"
    local url = repoURL .. filePath
    local success, src = pcall(game.HttpGet, game, url)
    if not success or not src or #src == 0 then
        error("Failed to download module '" .. modulePath .. "' from " .. url)
    end
    local fn, err = loadstring(src)
    if not fn then
        error("Failed to compile module '" .. modulePath .. "': " .. tostring(err))
    end
    return fn()
end
_G.loadModule = loadModule
if getgenv then getgenv().loadModule = loadModule end

print("Initializing Run a Restaurant Utility...")

if not game:IsLoaded() then game.Loaded:Wait() end

-- 1. Construct Core System
local Core = {
    Services = {
        Players = game:GetService("Players"),
        RunService = game:GetService("RunService"),
        UserInputService = game:GetService("UserInputService"),
        CoreGui = game:GetService("CoreGui"),
    }
}

-- 2. Load Core Data & Utility
Core.Config = loadModule("modules.Config")(Core)
Core.State = loadModule("modules.State")(Core)
Core.Utility = loadModule("modules.Utility")(Core)

-- 3. Load UI Director & Build Tabs
Core.UI = loadModule("modules.UI")(Core)
Core.UI.Init()
Core.UI.BuildDashboardTab()
Core.UI.BuildRestaurantTab()
Core.UI.BuildBuildTab()
Core.UI.BuildAutomationTab()

-- 4. Load Automation & Movement Modules
Core.Restaurant = loadModule("modules.Restaurant")(Core)
Core.Restaurant.Init()

Core.Movement = loadModule("modules.Movement")(Core)
Core.Movement.Init()

-- 5. Build Settings Tab & Select Dashboard Tab
Core.UI.BuildSettingsTab()
if Core.UI and Core.UI.Window then
    pcall(function()
        Core.UI.Window:SelectTab("Dashboard")
        Core.UI.Window:Notify({
            Title = "Run a Restaurant PRO",
            Content = "v2.0 loaded successfully. All systems nominal.",
            Type = "Success",
            Duration = 4
        })
    end)
end

-- 6. Start Keybind & Event Loop
Core.MainLoop = loadModule("modules.MainLoop")(Core)
Core.MainLoop.Init()

print("🍽️ Run a Restaurant Utility loaded successfully!")
_G.__Restaurant_Terminate = Core.Utility.Terminate
