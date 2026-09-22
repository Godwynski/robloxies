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
Core.Config = require("modules.Config")(Core)
Core.State = require("modules.State")(Core)
Core.Utility = require("modules.Utility")(Core)

-- 3. Load UI Director
Core.UI = require("modules.UI")(Core)
Core.UI.Init()

-- 4. Load Automation & Movement Modules
Core.Restaurant = require("modules.Restaurant")(Core)
Core.Restaurant.Init()

Core.Movement = require("modules.Movement")(Core)
Core.Movement.Init()

-- 5. Build Tabs & Select Restaurant Tab
Core.UI.BuildRestaurantTab()
Core.UI.BuildSettingsTab()
if Core.UI and Core.UI.Window then
    pcall(function() Core.UI.Window:SelectTab("Restaurant") end)
end

-- 6. Start Keybind & Event Loop
Core.MainLoop = require("modules.MainLoop")(Core)
Core.MainLoop.Init()

print("🍽️ Run a Restaurant Utility loaded successfully!")
_G.__Restaurant_Terminate = Core.Utility.Terminate
