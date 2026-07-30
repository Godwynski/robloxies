-- init.lua
local repoURL = "https://raw.githubusercontent.com/Godwynski/robloxies/main/"

if _G.__PureAutoAim_Running then
    pcall(function() _G.__PureAutoAim_Terminate() end)
end
_G.__PureAutoAim_Running = true

local hiddenUI = (gethui and gethui()) or game:GetService("CoreGui")
for _, gui in ipairs(hiddenUI:GetChildren()) do
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
Core.Config = require("modules.Config")(Core)
Core.State = require("modules.State")(Core)
Core.Utility = require("modules.Utility")(Core)
Core.EventManager = require("modules.EventManager")(Core)
Core.Drawings = require("modules.Drawings")(Core)


-- 3. Load UI Director (must load early so modules can inject tabs)
Core.UI = require("modules.UI")(Core)
Core.UI.Init()

-- 4. Load Logic Modules (These should subscribe to events & register UI)
Core.Aim = require("modules.Aim")(Core)
Core.ESP = require("modules.ESP")(Core)
Core.Movement = require("modules.Movement")(Core)
Core.Hooks = require("modules.Hooks")(Core)
Core.MainLoop = require("modules.MainLoop")(Core)

-- Call Init on modules that need base initialization
Core.Aim.Init()
Core.ESP.Init()
Core.Movement.Init()
Core.Hooks.Init()
Core.Drawings.Init()

-- 5. Load Game Preset as a Plugin
-- This merges configs, injects UI tabs, and sets up custom event hooks
Core.Preset = require("modules.GameIdentifier")(Core)

-- 6. Build final UI Tabs (Settings goes last)
Core.UI.BuildSettingsTab()

-- 7. Start the Main Event Loop
Core.MainLoop.Init()

print("Project loaded successfully!")
_G.__PureAutoAim_Terminate = Core.Utility.Terminate
