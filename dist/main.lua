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
Core.Config = (function()
return function(Core)
    local Config = {
        -- Master Switch
        MasterAutoFarmEnabled = false,

        -- Restaurant Core Automation
        AutoSeatEnabled = false,
        AutoOrderEnabled = false,
        AutoCookEnabled = false,
        AutoServeEnabled = false,
        AutoCleanEnabled = false,
        AutoWashSinksEnabled = true,
        AutoCollectCashEnabled = false,
        HandCapacity = 1,
        StrictHandPriority = true,
        AutoFarmEnabled = false,
        AutoDeliveryEnabled = false,
        AutoRestockEnabled = false,
        AutoClaimQuestsEnabled = true,
        AutoDoQuestsEnabled = true,
        AutoClaimRewardsEnabled = true,

        -- Budget & Affordability Safety
        MinCashReserve = 2500,
        MaxItemPrice = 50000,
        AffordabilityBackoff = 30,

        -- Land & Floor Expansions (Strictly manual opt-in)
        AutoExpandEnabled = false,
        AutoBuyLand = false,
        AutoBuyFloors = false,

        -- Equipment & Furniture Auto-Buy Choices
        AutoBuyEnabled = false,
        AutoBuyStoves = true,
        AutoBuyGrills = true,
        AutoBuyTables = true,
        AutoBuyChairs = true,
        AutoBuyAppliances = true,
        AutoBuyCounters = true,
        AutoBuyFurniture = false,
        AutoBuyLighting = false,

        -- Staff Personnel Auto-Hire Choices
        AutoHireStaffEnabled = false,
        AutoHireCooks = true,
        AutoHireWaiters = true,
        AutoHireCleaners = true,

        -- Furniture Placement
        AutoPlaceEnabled = false,
        AutoPlaceTables = true,
        AutoPlaceChairs = true,
        AutoPlaceFurniture = true,
        VIPPriorityEnabled = true,
        InstantPromptEnabled = true,
        ActionDelay = 0.3,
        StationStayDelay = 0.22,
        StrictTaskCompletion = true,
        PostActionDelay = 0.18,
        MaxScanRadius = 120,

        -- Multi-Queue Pipeline & Concurrency
        ConcurrentExecutionEnabled = true,
        InterleavedPipelineEnabled = true,
        StationBatchSize = 3,
        RemotePromptBatching = true,

        -- Teleport & Navigation
        AutoTeleportEnabled = true,
        TeleportDelay = 0.15,
        PlotScopingEnabled = true,
        PreventSitting = true,
        MultiFloorSafeRaycast = true,

        -- AFK & Performance
        AntiAFKEnabled = true,
        AutoRejoinEnabled = false,
        GPUSaverEnabled = false,

        -- Movement Physics
        WalkSpeedEnabled = false,
        WalkSpeed = 32,
        JumpPowerEnabled = false,
        JumpPower = 70,
        InfiniteJumpEnabled = false,
        NoClipEnabled = false,

        -- UI & Themes
        Theme = "Violet",
        UISoundEnabled = false,

        -- Keybinds
        MenuKey = Enum.KeyCode.RightShift,
        ToggleNoClipKey = Enum.KeyCode.N,
        ToggleSpeedKey = Enum.KeyCode.None,
        ToggleJumpKey = Enum.KeyCode.None,
        ToggleInfJumpKey = Enum.KeyCode.None,
    }

    local HttpService = game:GetService("HttpService")
    local fileName = "Restaurant_Config.json"

    function Config:Save()
        if type(writefile) ~= "function" then return false end
        local saveTable = {}
        for k, v in pairs(self) do
            if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                saveTable[k] = v
            elseif typeof(v) == "EnumItem" then
                saveTable[k] = {Type = "EnumItem", EnumType = tostring(v.EnumType), Name = v.Name}
            end
        end
        local ok, _ = pcall(function()
            writefile(fileName, HttpService:JSONEncode(saveTable))
        end)
        return ok
    end

    function Config:Load()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local ok, data = pcall(function()
            if isfile(fileName) then
                return HttpService:JSONDecode(readfile(fileName))
            end
            return nil
        end)
        if not ok or type(data) ~= "table" then return false end

        for k, v in pairs(data) do
            if type(self[k]) ~= "function" then
                if type(v) == "table" and v.Type == "EnumItem" then
                    pcall(function()
                        local enumName = tostring(v.EnumType):gsub("^Enum%.", "")
                        if Enum[enumName] and Enum[enumName][v.Name] then
                            self[k] = Enum[enumName][v.Name]
                        end
                    end)
                else
                    self[k] = v
                end
            end
        end
        return true
    end

    return Config
end

end)()(Core)
Core.State = (function()
return function(Core)
    local State = {
        ActiveConnections = {},
        InFlightTasks = setmetatable({}, {__mode = "k"}),
        Running = true,
        StartTime = tick(),
        HoldingType = "None", -- "DirtyDishes", "Food", "None"
        HoldingCount = 0,
        HandsFull = false,
        HandsFullUntil = 0,
        SinksFull = false,
        SinksFullUntil = 0,
        InteractionBlockedUntil = 0,
        ActivePrompt = nil,
        LastActionType = nil,
        ActiveGoal = {
            Title = "None",
            Objective = "Monitoring...",
            Progress = "0%",
            Category = "None",
            TargetItem = nil,
            TargetRole = nil,
        },
        Stats = {
            CustomersSeated = 0,
            OrdersTaken = 0,
            DishesCooked = 0,
            DishesServed = 0,
            TablesCleaned = 0,
            DishesWashed = 0,
            CashCollected = 0,
            CropsHarvested = 0,
            DeliveriesCompleted = 0,
            StorageRestocked = 0,
            QuestsClaimed = 0,
            QuestsCompleted = 0,
            RewardsClaimed = 0,
            ExpansionsPurchased = 0,
            ItemsPurchased = 0,
            ItemsPlaced = 0,
            StaffHired = 0,
        },
    }
    return State
end

end)()(Core)
Core.Utility = (function()
return function(Core)
    local Utility = {}
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer
    local Config = Core.Config

    function Utility.RegisterConnection(conn)
        table.insert(Core.State.ActiveConnections, conn)
        return conn
    end

    function Utility.SafeDestroy(obj)
        if not obj then return end
        if typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        elseif type(obj) == "table" or type(obj) == "userdata" then
            pcall(function()
                if obj.Remove then
                    obj:Remove()
                elseif obj.Destroy then
                    obj:Destroy()
                end
            end)
        end
    end

    -- Downward raycasting helper with multi-floor height support
    function Utility.GetGroundPosition(targetPos, ignoreList)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local list = ignoreList or {}
        if LocalPlayer and LocalPlayer.Character then
            table.insert(list, LocalPlayer.Character)
        end
        raycastParams.FilterDescendantsInstances = list
        raycastParams.IgnoreWater = true

        -- Multi-floor support: Use tight bounded search (8 studs down) to avoid dropping to lower floors
        local downDistance = Config.MultiFloorSafeRaycast and -10 or -30
        local origin = targetPos + Vector3.new(0, 3, 0)
        local direction = Vector3.new(0, downDistance, 0)
        local result = workspace:Raycast(origin, direction, raycastParams)

        if result and result.Position then
            return result.Position + Vector3.new(0, 3, 0)
        end
        return targetPos + Vector3.new(0, 2.5, 0)
    end

    -- GPU Saver / 3D Rendering Toggle
    function Utility.SetGPUSaver(enabled)
        pcall(function()
            Services.RunService:Set3dRenderingEnabled(not enabled)
        end)
    end

    -- Parse string into numeric representation (supports commas, decimals, and k/m/b suffixes)
    function Utility.ParseNumber(str)
        if not str then return nil end
        if type(str) == "number" then return str end
        local cleaned = tostring(str):lower():gsub(",", ""):gsub("%$", ""):gsub("%s+", "")
        local numStr, suffix = cleaned:match("([%d%.]+)%s*([kmb]?)")
        if not numStr then return nil end
        local val = tonumber(numStr)
        if not val then return nil end
        if suffix == "k" then
            val = val * 1000
        elseif suffix == "m" then
            val = val * 1000000
        elseif suffix == "b" then
            val = val * 1000000000
        end
        return val
    end

    -- Multi-source player balance detector
    function Utility.GetPlayerBalance()
        local balance = 0

        -- 1. Check leaderstats (standard Roblox pattern)
        if LocalPlayer then
            local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
            if leaderstats then
                for _, name in ipairs({"Cash", "Money", "Coins", "Bucks", "Dollars", "Balance", "Currency", "Gems"}) do
                    local valObj = leaderstats:FindFirstChild(name)
                    if valObj and (valObj:IsA("NumberValue") or valObj:IsA("IntValue")) then
                        return valObj.Value
                    elseif valObj and valObj:IsA("StringValue") then
                        local parsed = Utility.ParseNumber(valObj.Value)
                        if parsed then return parsed end
                    end
                end
                for _, child in ipairs(leaderstats:GetChildren()) do
                    if child:IsA("NumberValue") or child:IsA("IntValue") then
                        return child.Value
                    end
                end
            end

            -- 2. Check player attributes
            for _, attrName in ipairs({"Cash", "Money", "Coins", "Bucks", "Dollars", "Balance", "Gems"}) do
                local attr = LocalPlayer:GetAttribute(attrName)
                if type(attr) == "number" then
                    return attr
                elseif type(attr) == "string" then
                    local p = Utility.ParseNumber(attr)
                    if p then return p end
                end
            end

            -- 3. Check custom Data / Stats folders
            for _, folderName in ipairs({"PlayerData", "Data", "Stats", "Currencies", "Values"}) do
                local folder = LocalPlayer:FindFirstChild(folderName)
                if folder then
                    for _, name in ipairs({"Cash", "Money", "Coins", "Bucks", "Balance"}) do
                        local v = folder:FindFirstChild(name)
                        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then
                            return v.Value
                        end
                    end
                end
            end

            -- 4. Check PlayerGui for top currency labels
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, lbl in ipairs(pg:GetDescendants()) do
                    if lbl:IsA("TextLabel") and lbl.Visible then
                        local txt = lbl.Text or ""
                        local lName = lbl.Name:lower()
                        if lName:find("cash") or lName:find("money") or lName:find("coin") or lName:find("balance") or lName:find("currency") then
                            local parsed = Utility.ParseNumber(txt)
                            if parsed and parsed > 0 then
                                return parsed
                            end
                        elseif txt:match("^%$%s*[%d%,%.]+%s*[kKmMbB]?$") then
                            local parsed = Utility.ParseNumber(txt)
                            if parsed and parsed > 0 then
                                return parsed
                            end
                        end
                    end
                end
            end
        end

        return balance
    end

    -- Intelligent price parser: extracts cost from prompts, UI buttons, billboard labels
    function Utility.ParsePrice(text, obj)
        local rawText = tostring(text or "")

        if obj then
            if obj:IsA("ProximityPrompt") then
                rawText = (obj.ActionText or "") .. " " .. (obj.ObjectText or "") .. " " .. rawText
                if obj.Parent then
                    rawText = rawText .. " " .. obj.Parent.Name
                    for _, child in ipairs(obj.Parent:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Visible then
                            rawText = rawText .. " " .. (child.Text or "")
                        end
                    end
                end
            elseif obj:IsA("TextButton") or obj:IsA("ImageButton") then
                if obj:IsA("TextButton") then
                    rawText = (obj.Text or "") .. " " .. rawText
                end
                rawText = rawText .. " " .. obj.Name
                if obj.Parent then
                    for _, sibling in ipairs(obj.Parent:GetChildren()) do
                        if sibling:IsA("TextLabel") and (sibling.Name:lower():find("price") or sibling.Name:lower():find("cost") or sibling.Text:find("%$")) then
                            rawText = rawText .. " " .. sibling.Text
                        end
                    end
                end
            end
        end

        local lower = rawText:lower()

        -- 1. "$ 1,500" or "$25k" or "$1.5M"
        local p1 = lower:match("%$%s*([%d%,%.]+%s*[kmb]?)")
        if p1 then
            local val = Utility.ParseNumber(p1)
            if val then return val end
        end

        -- 2. "Price: 5,000" or "Cost: $500" or "price: 25k"
        local p2 = lower:match("price%s*[:%-]?%s*%$?%s*([%d%,%.]+%s*[kmb]?)") or lower:match("cost%s*[:%-]?%s*%$?%s*([%d%,%.]+%s*[kmb]?)")
        if p2 then
            local val = Utility.ParseNumber(p2)
            if val then return val end
        end

        -- 3. "5,000 cash" or "500 coins" or "25k money"
        local p3 = lower:match("([%d%,%.]+%s*[kmb]?)%s*cash") or lower:match("([%d%,%.]+%s*[kmb]?)%s*coins") or lower:match("([%d%,%.]+%s*[kmb]?)%s*money")
        if p3 then
            local val = Utility.ParseNumber(p3)
            if val then return val end
        end

        -- 4. Isolated number in parentheses e.g. "Buy (15000)" or "Unlock (50k)"
        local p4 = lower:match("%(%s*%$?%s*([%d%,%.]+%s*[kmb]?)%s*%)")
        if p4 then
            local val = Utility.ParseNumber(p4)
            if val then return val end
        end

        return nil
    end

    -- Strict affordability evaluator
    function Utility.CanAfford(cost, reserve)
        if not cost or cost <= 0 then
            return true, 0, "Affordable"
        end

        local balance = Utility.GetPlayerBalance()
        local minReserve = reserve or (Config and Config.MinCashReserve) or 0
        local maxPrice = (Config and Config.MaxItemPrice) or 0

        -- 1. Max price ceiling check
        if maxPrice > 0 and cost > maxPrice then
            return false, cost - math.max(0, balance - minReserve), "Exceeds max item price limit"
        end

        -- 2. Balance vs cost + reserve check
        local affordable = (balance >= (cost + minReserve))
        local needed = (cost + minReserve) - balance

        return affordable, (needed > 0 and needed or 0), (affordable and "Affordable" or "Insufficient funds")
    end

    -- Auto-Claim all finished quests, goals, milestones, daily gifts, playtime rewards, and achievements
    function Utility.ClaimAllRewards()
        if not Config.AutoClaimRewardsEnabled and not Config.AutoClaimQuestsEnabled and not Config.MasterAutoFarmEnabled then return 0 end
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local claimed = 0

        -- 1. Scan PlayerGui for claim, reward, gift, daily, spin, milestone, quest, goal buttons
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local name = btn.Name:lower()
                    local parentName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local grandParentName = (btn.Parent and btn.Parent.Parent and btn.Parent.Parent.Name or ""):lower()
                    local fullContext = text .. " " .. name .. " " .. parentName .. " " .. grandParentName

                    local isClaimText = text == "claim" or text == "collect" or text == "reward" or text == "open" or text == "free" or text == "spin" or text == "redeem" or text == "complete" or text == "turn in" or text == "done"
                    local hasClaimWord = fullContext:find("claim") or fullContext:find("collect") or fullContext:find("reward") or fullContext:find("gift") or fullContext:find("milestone") or fullContext:find("goal") or fullContext:find("quest")

                    if not text:find("robux") and not text:find("buy") and not text:find("purchase") and not text:find("cancel") and not text:find("close") then
                        if isClaimText or (hasClaimWord and (text:find("claim") or text:find("collect") or text:find("reward") or text:find("free") or text:find("get"))) then
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                                claimed = claimed + 1
                            end)
                        end
                    end
                end
            end
        end

        -- 2. Check ReplicatedStorage reward claiming remotes
        local rs = game:GetService("ReplicatedStorage")
        local remoteNames = {
            "ClaimReward", "ClaimDaily", "ClaimDailyReward", "ClaimGift",
            "ClaimPlaytime", "ClaimQuest", "ClaimGoal", "GoalClaim", "ClaimAchievement",
            "ClaimMilestone", "MilestoneClaim", "ClaimPass", "ClaimFreeGift", "SpinWheel", "FreeSpin",
            "CompleteQuest", "CompleteGoal", "TurnInQuest", "FinishQuest", "RedeemQuest", "RedeemGoal", "Claim"
        }
        for _, rName in ipairs(remoteNames) do
            local remote = rs:FindFirstChild(rName, true)
            if remote and remote:IsA("RemoteEvent") then
                pcall(function()
                    remote:FireServer()
                    claimed = claimed + 1
                end)
            elseif remote and remote:IsA("RemoteFunction") then
                pcall(function()
                    remote:InvokeServer()
                    claimed = claimed + 1
                end)
            end
        end

        if claimed > 0 and Core.State and Core.State.Stats then
            Core.State.Stats.RewardsClaimed = (Core.State.Stats.RewardsClaimed or 0) + claimed
            Core.State.Stats.QuestsClaimed = (Core.State.Stats.QuestsClaimed or 0) + claimed
        end

        return claimed
    end
    Utility.ClaimQuestsAndGifts = Utility.ClaimAllRewards

    -- Auto-Accept and Auto-Do Quests / Goals
    function Utility.AcceptAndDoQuests()
        if not Config.AutoDoQuestsEnabled and not Config.MasterAutoFarmEnabled then return nil end
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local rs = game:GetService("ReplicatedStorage")

        -- 1. Auto-Accept new quests / goals from dialog popups, lists, or NPCs
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local name = btn.Name:lower()
                    local parentName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local fullContext = text .. " " .. name .. " " .. parentName

                    local isAccept = text == "accept" or text == "start" or text == "take quest" or text == "track" or text == "select" or text == "accept quest" or text == "accept goal" or text == "yes" or text == "continue"
                    local isQuestContext = fullContext:find("quest") or fullContext:find("goal") or fullContext:find("mission") or fullContext:find("task") or fullContext:find("bounty")

                    if (isAccept or (isQuestContext and (text:find("accept") or text:find("start") or text:find("take") or text:find("ok")))) and
                       not text:find("robux") and not text:find("buy") and not text:find("cancel") then
                        pcall(function()
                            if type(firesignal) == "function" and btn.Activated then
                                firesignal(btn.Activated)
                            elseif btn.Activate then
                                btn:Activate()
                            end
                        end)
                    end
                end
            end
        end

        -- 2. Trigger AcceptQuest / StartQuest / Goal remotes if available in ReplicatedStorage
        local acceptRemotes = {
            "AcceptQuest", "StartQuest", "TakeQuest", "TrackQuest", "SelectQuest", "AssignQuest",
            "AcceptGoal", "StartGoal", "TakeGoal"
        }
        for _, rName in ipairs(acceptRemotes) do
            local remote = rs:FindFirstChild(rName, true)
            if remote and remote:IsA("RemoteEvent") then
                pcall(function() remote:FireServer() end)
            elseif remote and remote:IsA("RemoteFunction") then
                pcall(function() remote:InvokeServer() end)
            end
        end

        -- 3. Parse active quest directives from PlayerGui labels
        local directives = {
            Cook = false,
            Serve = false,
            Order = false,
            Clean = false,
            Seat = false,
            Cash = false,
            Farm = false,
            Delivery = false,
            Buy = false,
            Place = false,
            Staff = false,
            Expand = false,
            TargetItem = nil,
            TargetRole = nil,
            TargetCrop = nil,
            Title = nil,
            Objective = nil,
            Progress = nil,
            Category = "None"
        }

        local candidateLabels = {}
        if pg then
            for _, lbl in ipairs(pg:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text and #lbl.Text > 1 then
                    local name = lbl.Name:lower()
                    local parentName = (lbl.Parent and lbl.Parent.Name or ""):lower()
                    local grandParentName = (lbl.Parent and lbl.Parent.Parent and lbl.Parent.Parent.Name or ""):lower()
                    local fullContext = name .. " " .. parentName .. " " .. grandParentName

                    local isGoalLabel = fullContext:find("goal") or fullContext:find("quest") or fullContext:find("mission")
                                     or fullContext:find("task") or fullContext:find("objective") or fullContext:find("tracker")
                    if isGoalLabel then
                        table.insert(candidateLabels, lbl)
                    end
                end
            end
        end

        local bestTitle = nil
        local bestObjective = nil
        local bestProgress = nil

        for _, lbl in ipairs(candidateLabels) do
            local rawText = lbl.Text:gsub("^%s+", ""):gsub("%s+$", "")
            local lowerText = rawText:lower()
            local name = lbl.Name:lower()

            -- Check for progress pattern e.g. (1/2), ($140/$200), (50%)
            local prog = rawText:match("(%d+/%d+)") or rawText:match("(%$?%d+[%d%,]*%s*/%s*%$?%d+[%d%,]*)") or rawText:match("(%d+%%)")
            if prog and not bestProgress then
                bestProgress = prog
            end

            -- Check if label is named title, header, or name
            if (name:find("title") or name:find("header") or name:find("name")) and not lowerText:find("!") and #rawText < 35 then
                bestTitle = rawText
            end

            -- Check for action verbs in objective text
            local isObjectiveText = lowerText:find("cook") or lowerText:find("serve") or lowerText:find("clean")
                                 or lowerText:find("order") or lowerText:find("seat") or lowerText:find("earn")
                                 or lowerText:find("buy") or lowerText:find("place") or lowerText:find("hire")
                                 or lowerText:find("harvest") or lowerText:find("expand") or lowerText:find("customer")
                                 or lowerText:find("dish") or lowerText:find("meal")
            if isObjectiveText and not bestObjective then
                bestObjective = rawText
            elseif not bestTitle and #rawText > 0 and #rawText < 30 and not isObjectiveText and not prog then
                bestTitle = rawText
            end
        end

        local objLower = (bestObjective or ""):lower()
        if #objLower == 0 and bestTitle then
            objLower = bestTitle:lower()
        end

        local targetItem = nil
        local targetRole = nil
        local targetCrop = nil
        local primaryCat = "None"

        if #objLower > 0 then
            -- 1. Cook
            if objLower:find("cook") or objLower:find("bake") or objLower:find("meal") then
                directives.Cook = true
                primaryCat = "Cook"
            end
            -- 2. Serve
            if objLower:find("serve") or objLower:find("deliver to table") then
                directives.Serve = true
                if primaryCat == "None" then primaryCat = "Serve" end
            end
            -- 3. Clean
            if objLower:find("clean") or objLower:find("wipe") or objLower:find("dish") or objLower:find("scrub") then
                directives.Clean = true
                if primaryCat == "None" then primaryCat = "Clean" end
            end
            -- 4. Order
            if objLower:find("order") or objLower:find("ticket") then
                directives.Order = true
                if primaryCat == "None" then primaryCat = "Order" end
            end
            -- 5. Seat
            if objLower:find("seat") or objLower:find("customer") or objLower:find("guest") then
                directives.Seat = true
                if primaryCat == "None" then primaryCat = "Seat" end
            end
            -- 6. Earn / Cash
            if objLower:find("earn") or objLower:find("cash") or objLower:find("coin") or objLower:find("tip") or objLower:find("money") then
                directives.Cash = true
                if primaryCat == "None" then primaryCat = "Cash" end
            end
            -- 7. Buy
            if objLower:find("buy") or objLower:find("purchase") then
                directives.Buy = true
                primaryCat = "Buy"
                -- Extract target item name (e.g. "Buy a Wooden Chair!", "Buy 3 Tomato Plant!", "Buy a Rusty Sink!")
                local item = objLower:match("buy%s+a?%s+(.-)[!%?%.%(]") or objLower:match("buy%s+%d*%s*(.-)[!%?%.%(]") or objLower:match("purchase%s+a?%s*(.-)[!%?%.%(]") or objLower:match("buy%s+a?%s+(.+)$")
                if item then
                    item = item:gsub("^a%s+", ""):gsub("^%d+%s*", ""):gsub("^the%s+", ""):gsub("[%!%?%.%)]", ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if #item > 2 then targetItem = item end
                end
            end
            -- 8. Place
            if objLower:find("place") or objLower:find("build") then
                directives.Place = true
                if primaryCat == "None" or primaryCat == "Buy" then primaryCat = "Place" end
                -- Extract target item name (e.g. "Place a Wooden Chair!", "Place 1 Wooden Table!")
                local item = objLower:match("place%s+a?%s+(.-)[!%?%.%(]") or objLower:match("place%s+%d*%s*(.-)[!%?%.%(]") or objLower:match("build%s+a?%s*(.-)[!%?%.%(]") or objLower:match("place%s+a?%s+(.+)$")
                if item then
                    item = item:gsub("^a%s+", ""):gsub("^%d+%s*", ""):gsub("^the%s+", ""):gsub("[%!%?%.%)]", ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if #item > 2 then targetItem = item end
                end
            end
            -- 9. Hire Staff
            if objLower:find("hire") or objLower:find("recruit") then
                directives.Staff = true
                primaryCat = "Staff"
                if objLower:find("cleaner") or objLower:find("dishwasher") then
                    targetRole = "Cleaner"
                elseif objLower:find("cook") or objLower:find("chef") then
                    targetRole = "Cook"
                elseif objLower:find("waiter") or objLower:find("server") then
                    targetRole = "Waiter"
                end
            end
            -- 10. Farm / Harvest
            if objLower:find("harvest") or objLower:find("crop") or objLower:find("farm") or objLower:find("wheat") or objLower:find("tomato") then
                directives.Farm = true
                if primaryCat == "None" then primaryCat = "Farm" end
                if objLower:find("wheat") then targetCrop = "Wheat"
                elseif objLower:find("tomato") then targetCrop = "Tomato"
                elseif objLower:find("carrot") then targetCrop = "Carrot"
                elseif objLower:find("corn") then targetCrop = "Corn"
                elseif objLower:find("potato") then targetCrop = "Potato"
                end
            end
            -- 11. Delivery
            if objLower:find("delivery") or objLower:find("package") or objLower:find("scooter") then
                directives.Delivery = true
                if primaryCat == "None" then primaryCat = "Delivery" end
            end
            -- 12. Expand
            if objLower:find("expand") or objLower:find("floor") or objLower:find("land") then
                directives.Expand = true
                if primaryCat == "None" then primaryCat = "Expand" end
            end
        end

        directives.TargetItem = targetItem
        directives.TargetRole = targetRole
        directives.TargetCrop = targetCrop
        directives.Category = primaryCat
        directives.Title = bestTitle
        directives.Objective = bestObjective
        directives.Progress = bestProgress

        if Core.State and Core.State.ActiveGoal then
            if bestTitle or bestObjective then
                Core.State.ActiveGoal.Title = bestTitle or (Core.State.ActiveGoal.Title ~= "None" and Core.State.ActiveGoal.Title or "Active Goal")
                Core.State.ActiveGoal.Objective = bestObjective or (bestTitle or "In Progress")
                Core.State.ActiveGoal.Progress = bestProgress or ""
                Core.State.ActiveGoal.Category = primaryCat
                Core.State.ActiveGoal.TargetItem = targetItem
                Core.State.ActiveGoal.TargetRole = targetRole
                Core.State.ActiveGoal.TargetCrop = targetCrop
            end
        end

        return directives
    end

    -- Redeem known active promotional codes automatically
    function Utility.RedeemKnownCodes()
        local codes = {"FISHIES", "RAR4EVER"}
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return 0 end
        local redeemed = 0

        for _, desc in ipairs(pg:GetDescendants()) do
            if desc:IsA("TextBox") then
                local boxName = desc.Name:lower()
                local parentName = (desc.Parent and desc.Parent.Name or ""):lower()
                local ph = (desc.PlaceholderText or ""):lower()

                if boxName:find("code") or parentName:find("code") or ph:find("code") then
                    local submitBtn = nil
                    for _, sibling in ipairs(desc.Parent:GetChildren()) do
                        if (sibling:IsA("TextButton") or sibling:IsA("ImageButton")) and sibling ~= desc then
                            local sName = sibling.Name:lower()
                            local sText = (sibling:IsA("TextButton") and sibling.Text or ""):lower()
                            if sName:find("submit") or sName:find("enter") or sName:find("redeem") or sText:find("submit") or sText:find("redeem") then
                                submitBtn = sibling
                                break
                            end
                        end
                    end

                    for _, code in ipairs(codes) do
                        desc.Text = code
                        if submitBtn then
                            pcall(function()
                                if type(firesignal) == "function" and submitBtn.Activated then
                                    firesignal(submitBtn.Activated)
                                elseif submitBtn.Activate then
                                    submitBtn:Activate()
                                end
                            end)
                        end
                        redeemed = redeemed + 1
                        task.wait(0.25)
                    end
                end
            end
        end
        return redeemed
    end

    -- Setup Anti-AFK Listener
    local VirtualUser = game:GetService("VirtualUser")
    if LocalPlayer then
        Utility.RegisterConnection(LocalPlayer.Idled:Connect(function()
            if Config.AntiAFKEnabled then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end))
    end

    -- Setup 24/7 Auto-Rejoin on Disconnect or Server Kick (Only on explicit ErrorPrompt)
    function Utility.SetupAutoRejoin()
        local TeleportService = game:GetService("TeleportService")

        pcall(function()
            local overlay = Services.CoreGui:WaitForChild("RobloxPromptGui", 5)
            if overlay then
                local prompt = overlay:WaitForChild("promptOverlay", 5)
                if prompt then
                    Utility.RegisterConnection(prompt.ChildAdded:Connect(function(child)
                        if Config.AutoRejoinEnabled and child.Name == "ErrorPrompt" then
                            task.wait(2.5)
                            pcall(function()
                                TeleportService:Teleport(game.PlaceId, LocalPlayer)
                            end)
                        end
                    end))
                end
            end
        end)
    end
    Utility.SetupAutoRejoin()

    function Utility.Terminate()
        local State = Core.State
        State.Running = false
        _G.__Movement_Running = false
        _G.__Restaurant_Running = false
        _G.__Movement_Terminate = nil
        _G.__Restaurant_Terminate = nil
        _G.loadModule = nil
        pcall(function()
            if getgenv then getgenv().loadModule = nil end
        end)

        -- Restore 3D rendering in case GPU saver was active
        pcall(function()
            Services.RunService:Set3dRenderingEnabled(true)
        end)

        -- Disconnect all event connections
        for _, conn in ipairs(State.ActiveConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                pcall(function() conn:Disconnect() end)
            end
        end
        table.clear(State.ActiveConnections)

        -- Clean up Restaurant module
        if Core.Restaurant and Core.Restaurant.Cleanup then
            pcall(Core.Restaurant.Cleanup)
        end

        -- Restore Movement physics if active
        if Core.Movement and Core.Movement.Cleanup then
            pcall(Core.Movement.Cleanup)
        end

        -- Clean up UI ScreenGui directly if cached
        pcall(function()
            if Core.UI and Core.UI.Window and Core.UI.Window.Library and Core.UI.Window.Library.Interface then
                Core.UI.Window.Library.Interface:Destroy()
            end
        end)

        -- Clean up all UI ScreenGui instances across all possible containers
        local containers = {
            (gethui and gethui()) or nil,
            Services.CoreGui,
            Services.Players.LocalPlayer and Services.Players.LocalPlayer:FindFirstChild("PlayerGui"),
        }
        for _, parent in ipairs(containers) do
            if parent then
                pcall(function()
                    for _, child in ipairs(parent:GetChildren()) do
                        if child.Name == "RestaurantUtilityPanel" or child.Name == "RobloxMovementPanel" or child.Name == "PureAutoAimPanel" then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end)
            end
        end

        print("🍽️ Run a Restaurant Utility has been completely unloaded.")
    end

    return Utility
end

end)()(Core)

-- 3. Load UI Director & Build Tabs
Core.UI = (function()
return function(Core)
    local UI = {}
    local Config = Core.Config
    local Utility = Core.Utility
    local State = Core.State

    function UI.Init()
        local UILibrary = (function()
return function(Core)
    local UILibrary = {}
    local Services = Core.Services
    local Utility = Core.Utility
    local TweenService = game:GetService("TweenService")
    local UserInputService = Services.UserInputService

    -- =========================================================================
    -- 1. PRODUCTION THEME ENGINE
    -- =========================================================================
    local Themes = {
        Violet = {
            Name = "Midnight Violet",
            Primary = Color3.fromRGB(130, 95, 255),
            PrimaryGradient = Color3.fromRGB(165, 125, 255),
            PrimaryDark = Color3.fromRGB(85, 55, 190),
            AccentGlow = Color3.fromRGB(130, 95, 255),
        },
        Emerald = {
            Name = "Emerald Cyber",
            Primary = Color3.fromRGB(16, 185, 129),
            PrimaryGradient = Color3.fromRGB(52, 211, 153),
            PrimaryDark = Color3.fromRGB(5, 120, 85),
            AccentGlow = Color3.fromRGB(16, 185, 129),
        },
        Sapphire = {
            Name = "Sapphire Ocean",
            Primary = Color3.fromRGB(59, 130, 246),
            PrimaryGradient = Color3.fromRGB(96, 165, 250),
            PrimaryDark = Color3.fromRGB(29, 78, 216),
            AccentGlow = Color3.fromRGB(59, 130, 246),
        },
        Amber = {
            Name = "Sunset Amber",
            Primary = Color3.fromRGB(245, 158, 11),
            PrimaryGradient = Color3.fromRGB(251, 191, 36),
            PrimaryDark = Color3.fromRGB(180, 83, 9),
            AccentGlow = Color3.fromRGB(245, 158, 11),
        },
        Carbon = {
            Name = "Obsidian Carbon",
            Primary = Color3.fromRGB(226, 232, 240),
            PrimaryGradient = Color3.fromRGB(248, 250, 252),
            PrimaryDark = Color3.fromRGB(100, 116, 139),
            AccentGlow = Color3.fromRGB(148, 163, 184),
        }
    }
    UILibrary.Themes = Themes

    local ActiveThemeName = (Core.Config and Core.Config.Theme) or "Violet"
    if not Themes[ActiveThemeName] then ActiveThemeName = "Violet" end

    local Theme = {
        CurrentName = ActiveThemeName,
        -- Base Glassmorphic Slate Palette
        Background = Color3.fromRGB(13, 15, 22),
        BackgroundGlow = Color3.fromRGB(18, 21, 32),
        Sidebar = Color3.fromRGB(10, 12, 17),
        Header = Color3.fromRGB(16, 19, 28),
        Card = Color3.fromRGB(21, 25, 36),
        CardHover = Color3.fromRGB(28, 33, 48),
        CardActive = Color3.fromRGB(32, 38, 56),
        CardBorder = Color3.fromRGB(38, 44, 64),
        CardBorderHover = Color3.fromRGB(62, 72, 102),
        CardInner = Color3.fromRGB(15, 18, 26),
        
        -- Text Palette
        TextPrimary = Color3.fromRGB(245, 247, 252),
        TextSecondary = Color3.fromRGB(150, 160, 180),
        TextMuted = Color3.fromRGB(100, 110, 130),
        
        -- Status Accents
        Success = Color3.fromRGB(34, 197, 94),
        Danger = Color3.fromRGB(239, 68, 68),
        Warning = Color3.fromRGB(245, 158, 11),
        Info = Color3.fromRGB(59, 130, 246),
        
        -- Dynamic Theme Accent
        Primary = Themes[ActiveThemeName].Primary,
        PrimaryGradient = Themes[ActiveThemeName].PrimaryGradient,
        PrimaryDark = Themes[ActiveThemeName].PrimaryDark,
        AccentGlow = Themes[ActiveThemeName].AccentGlow,
    }
    UILibrary.Theme = Theme

    -- Listeners for runtime theme updates
    local ThemeUpdateListeners = {}
    function UILibrary:RegisterThemeListener(callback)
        table.insert(ThemeUpdateListeners, callback)
    end

    function UILibrary:SetTheme(name)
        if not Themes[name] then return end
        Theme.CurrentName = name
        local pal = Themes[name]
        Theme.Primary = pal.Primary
        Theme.PrimaryGradient = pal.PrimaryGradient
        Theme.PrimaryDark = pal.PrimaryDark
        Theme.AccentGlow = pal.AccentGlow
        if Core.Config then Core.Config.Theme = name end
        for _, cb in ipairs(ThemeUpdateListeners) do
            pcall(cb, Theme)
        end
    end

    -- =========================================================================
    -- 2. AUDIO & ANIMATION HELPERS
    -- =========================================================================
    function UILibrary:PlaySound(soundType)
        if not Core.Config or not Core.Config.UISoundEnabled then return end
        task.spawn(function()
            local soundId = "rbxassetid://6895079853" -- default clean tick
            if soundType == "toggle" then soundId = "rbxassetid://6895079683"
            elseif soundType == "notify" then soundId = "rbxassetid://4590662766"
            elseif soundType == "tab" then soundId = "rbxassetid://6895079774"
            end
            local snd = Instance.new("Sound")
            snd.SoundId = soundId
            snd.Volume = 0.4
            snd.Parent = Services.CoreGui
            snd:Play()
            snd.Ended:Connect(function() snd:Destroy() end)
        end)
    end

    local function tween(object, properties, time, style, direction)
        time = time or 0.2
        style = style or Enum.EasingStyle.Quad
        direction = direction or Enum.EasingDirection.Out
        local tw = TweenService:Create(object, TweenInfo.new(time, style, direction), properties)
        tw:Play()
        return tw
    end
    UILibrary.Tween = tween

    -- Global drag/slider state
    local floatDragging, floatHasMoved, floatDragStart, floatStartPos
    local dragging, dragStart, startPos
    local resizing, resizeStart, sizeStart
    local activeSliderId = nil
    local sliderCallbacks = {}
    local sliderIdCounter = 0

    local activeKeybindBtn = nil
    local activeKeybindCb = nil

    local function getViewportSize()
        local ws = workspace or game:GetService("Workspace")
        local cam = ws and ws.CurrentCamera
        if cam and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
            return cam.ViewportSize
        end
        if UILibrary.Interface and UILibrary.Interface.AbsoluteSize.X > 0 and UILibrary.Interface.AbsoluteSize.Y > 0 then
            return UILibrary.Interface.AbsoluteSize
        end
        return Vector2.new(1920, 1080)
    end

    -- =========================================================================
    -- 3. GLOBAL INPUT DISPATCHER (Desktop & Touch)
    -- =========================================================================
    function UILibrary:InitInputDispatchers()
        Utility.RegisterConnection(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            
            if floatDragging and self.FloatingWidget then
                local delta = input.Position - floatDragStart
                if delta.Magnitude > 3 then
                    floatHasMoved = true
                    local vp = getViewportSize()
                    local pillW = self.FloatingWidget.AbsoluteSize.X > 0 and self.FloatingWidget.AbsoluteSize.X or 155
                    local pillH = self.FloatingWidget.AbsoluteSize.Y > 0 and self.FloatingWidget.AbsoluteSize.Y or 42
                    
                    local curLeft = vp.X * floatStartPos.X.Scale + floatStartPos.X.Offset + delta.X
                    local curTop = vp.Y * floatStartPos.Y.Scale + floatStartPos.Y.Offset + delta.Y
                    local clampedX = math.clamp(curLeft, 10, math.max(10, vp.X - pillW - 10))
                    local clampedY = math.clamp(curTop, 10, math.max(10, vp.Y - pillH - 10))
                    
                    self.FloatingWidget.Position = UDim2.new(0, clampedX, 0, clampedY)
                    self.FloatingSavedPos = self.FloatingWidget.Position
                end
            elseif dragging and self.MainContainer then
                local delta = input.Position - dragStart
                local vp = getViewportSize()
                local winW = self.MainContainer.AbsoluteSize.X > 0 and self.MainContainer.AbsoluteSize.X or 620
                local winH = self.MainContainer.AbsoluteSize.Y > 0 and self.MainContainer.AbsoluteSize.Y or 490

                local curLeft = vp.X * startPos.X.Scale + startPos.X.Offset + delta.X
                local curTop = vp.Y * startPos.Y.Scale + startPos.Y.Offset + delta.Y

                local clampLeft = math.clamp(curLeft, -winW + 80, math.max(0, vp.X - 80))
                local clampTop = math.clamp(curTop, 0, math.max(0, vp.Y - 50))

                local newOffsetX = clampLeft - (vp.X * startPos.X.Scale)
                local newOffsetY = clampTop - (vp.Y * startPos.Y.Scale)

                self.MainContainer.Position = UDim2.new(startPos.X.Scale, newOffsetX, startPos.Y.Scale, newOffsetY)
            elseif resizing and self.MainContainer then
                local delta = input.Position - resizeStart
                local vp = getViewportSize()
                local curX = self.MainContainer.AbsolutePosition.X
                local curY = self.MainContainer.AbsolutePosition.Y
                local maxW = math.max(480, vp.X - curX - 10)
                local maxH = math.max(380, vp.Y - curY - 10)
                local newW = math.clamp(sizeStart.X + delta.X, 480, math.min(1100, maxW))
                local newH = math.clamp(sizeStart.Y + delta.Y, 380, math.min(850, maxH))
                self.MainContainer.Size = UDim2.new(0, newW, 0, newH)
                self.SavedWindowSize = self.MainContainer.Size
            elseif activeSliderId then
                local cb = sliderCallbacks[activeSliderId]
                if cb then cb(input) end
            end
        end))

        Utility.RegisterConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if floatDragging and not floatHasMoved then
                    self:RestoreFromFloating()
                end
                if dragging and self.MainContainer then
                    self.SavedWindowPos = self.MainContainer.Position
                end
                floatDragging = false
                dragging = false
                resizing = false
                activeSliderId = nil
            end
        end))

        Utility.RegisterConnection(UserInputService.InputBegan:Connect(function(input)
            if activeKeybindBtn and input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if key == Enum.KeyCode.Escape then
                    activeKeybindBtn.Text = "None"
                    if activeKeybindCb then activeKeybindCb(Enum.KeyCode.None) end
                else
                    activeKeybindBtn.Text = key.Name
                    if activeKeybindCb then activeKeybindCb(key) end
                end
                tween(activeKeybindBtn, {BackgroundColor3 = Theme.CardInner})
                activeKeybindBtn = nil
                activeKeybindCb = nil
            end
        end))
    end

    -- =========================================================================
    -- 4. TOAST NOTIFICATION ENGINE
    -- =========================================================================
    function UILibrary:Notify(options)
        if not self.NotificationContainer then return end
        options = options or {}
        local title = options.Title or "Notification"
        local content = options.Content or ""
        local notifyType = options.Type or "Info" -- "Success", "Error", "Warning", "Info"
        local duration = options.Duration or 3.5

        local accentColor = Theme.Primary
        local iconSymbol = "ℹ"
        if notifyType == "Success" then
            accentColor = Theme.Success
            iconSymbol = "✓"
        elseif notifyType == "Error" then
            accentColor = Theme.Danger
            iconSymbol = "✕"
        elseif notifyType == "Warning" then
            accentColor = Theme.Warning
            iconSymbol = "⚠"
        end

        local toast = Instance.new("Frame")
        toast.Parent = self.NotificationContainer
        toast.Size = UDim2.new(1, 0, 0, 68)
        toast.Position = UDim2.new(1, 300, 0, 0)
        toast.BackgroundColor3 = Theme.Card
        toast.BorderSizePixel = 0
        toast.ClipsDescendants = true
        Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = toast
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local iconBg = Instance.new("Frame")
        iconBg.Parent = toast
        iconBg.Size = UDim2.new(0, 32, 0, 32)
        iconBg.Position = UDim2.new(0, 10, 0, 10)
        iconBg.BackgroundColor3 = accentColor
        iconBg.BackgroundTransparency = 0.85
        Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 6)

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Parent = iconBg
        iconLbl.Size = UDim2.new(1, 0, 1, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Text = iconSymbol
        iconLbl.TextColor3 = accentColor
        iconLbl.TextSize = 14

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = toast
        titleLbl.Size = UDim2.new(1, -75, 0, 18)
        titleLbl.Position = UDim2.new(0, 50, 0, 8)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = title
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 13
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local msgLbl = Instance.new("TextLabel")
        msgLbl.Parent = toast
        msgLbl.Size = UDim2.new(1, -75, 0, 32)
        msgLbl.Position = UDim2.new(0, 50, 0, 26)
        msgLbl.BackgroundTransparency = 1
        msgLbl.Font = Enum.Font.GothamMedium
        msgLbl.Text = content
        msgLbl.TextColor3 = Theme.TextSecondary
        msgLbl.TextSize = 11
        msgLbl.TextWrapped = true
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left
        msgLbl.TextYAlignment = Enum.TextYAlignment.Top

        -- Close cross button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Parent = toast
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -26, 0, 6)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Theme.TextMuted
        closeBtn.TextSize = 12

        -- Bottom Progress bar
        local progTrack = Instance.new("Frame")
        progTrack.Parent = toast
        progTrack.Size = UDim2.new(1, 0, 0, 3)
        progTrack.Position = UDim2.new(0, 0, 1, -3)
        progTrack.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
        progTrack.BorderSizePixel = 0

        local progFill = Instance.new("Frame")
        progFill.Parent = progTrack
        progFill.Size = UDim2.new(1, 0, 1, 0)
        progFill.BackgroundColor3 = accentColor
        progFill.BorderSizePixel = 0

        self:PlaySound("notify")

        -- Slide in
        tween(toast, {Position = UDim2.new(0, 0, 0, 0)}, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        tween(progFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

        local dismissed = false
        local function dismiss()
            if dismissed then return end
            dismissed = true
            local tw = tween(toast, {Position = UDim2.new(1, 300, 0, 0)}, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tw.Completed:Connect(function()
                toast:Destroy()
            end)
        end

        closeBtn.Activated:Connect(dismiss)
        task.delay(duration, dismiss)
    end

    -- =========================================================================
    -- 5. FLOATING WIDGET HUD (Compact Farming Pill)
    -- =========================================================================
    function UILibrary:CreateFloatingWidget()
        local pill = Instance.new("Frame")
        pill.Name = "RestaurantFloatingWidget"
        pill.Parent = self.Interface
        pill.Size = UDim2.new(0, 155, 0, 42)
        pill.Position = UDim2.new(0, 24, 0.5, -21)
        pill.BackgroundColor3 = Theme.Header
        pill.BorderSizePixel = 0
        pill.Active = true
        pill.Visible = false
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = pill
        stroke.Color = Theme.Primary
        stroke.Thickness = 1.5

        local icon = Instance.new("TextLabel")
        icon.Parent = pill
        icon.Size = UDim2.new(0, 30, 1, 0)
        icon.Position = UDim2.new(0, 10, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.Text = "🍽️"
        icon.TextSize = 18

        local dot = Instance.new("Frame")
        dot.Parent = pill
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.Position = UDim2.new(0, 44, 0.5, -4)
        dot.BackgroundColor3 = Theme.TextMuted
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local title = Instance.new("TextLabel")
        title.Parent = pill
        title.Size = UDim2.new(1, -60, 0, 16)
        title.Position = UDim2.new(0, 58, 0, 6)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "AUTO-FARM"
        title.TextColor3 = Theme.TextPrimary
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Left

        local sub = Instance.new("TextLabel")
        sub.Parent = pill
        sub.Size = UDim2.new(1, -60, 0, 14)
        sub.Position = UDim2.new(0, 58, 0, 22)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.GothamMedium
        sub.Text = "IDLE (Click to open)"
        sub.TextColor3 = Theme.TextSecondary
        sub.TextSize = 9
        sub.TextXAlignment = Enum.TextXAlignment.Left

        -- Dragging logic
        local function bindPillDrag(inst)
            inst.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    floatDragging = true
                    floatHasMoved = false
                    floatDragStart = input.Position
                    floatStartPos = pill.Position
                end
            end)
        end
        bindPillDrag(pill)
        bindPillDrag(icon)
        bindPillDrag(dot)
        bindPillDrag(title)
        bindPillDrag(sub)

        self.FloatingWidget = pill
        self.FloatingCircle = pill -- Alias for backward compatibility
        self.FloatingStatusDot = dot
        self.FloatingStatusSub = sub
        self.FloatingStroke = stroke

        self:RegisterThemeListener(function(t)
            stroke.Color = t.Primary
        end)
    end

    function UILibrary:UpdateFloatingStatus(isActive, statusText)
        if not self.FloatingWidget then return end
        if isActive then
            self.FloatingStatusDot.BackgroundColor3 = Theme.Success
            self.FloatingStatusSub.Text = statusText or "Farming Active"
            self.FloatingStatusSub.TextColor3 = Theme.Success
            self.FloatingStroke.Color = Theme.Primary
        else
            self.FloatingStatusDot.BackgroundColor3 = Theme.TextMuted
            self.FloatingStatusSub.Text = statusText or "IDLE (Click to open)"
            self.FloatingStatusSub.TextColor3 = Theme.TextSecondary
            self.FloatingStroke.Color = Theme.CardBorder
        end
    end

    function UILibrary:MinimizeToFloating()
        if not self.MainContainer or not self.FloatingWidget then return end
        self:PlaySound("toggle")
        self.SavedWindowSize = self.MainContainer.Size
        self.SavedWindowPos = self.MainContainer.Position
        local tw = tween(self.MainContainer, {
            Size = UDim2.new(0, self.MainContainer.Size.X.Offset * 0.7, 0, 0),
            Position = UDim2.new(self.MainContainer.Position.X.Scale, self.MainContainer.Position.X.Offset, self.MainContainer.Position.Y.Scale, self.MainContainer.Position.Y.Offset + 50)
        }, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        tw.Completed:Connect(function()
            self.MainContainer.Visible = false
            self.FloatingWidget.Visible = true
            if self.FloatingSavedPos then
                self.FloatingWidget.Position = self.FloatingSavedPos
            else
                self.FloatingWidget.Position = UDim2.new(0, 24, 0.5, -21)
            end
        end)
    end

    function UILibrary:RestoreFromFloating()
        if not self.MainContainer or not self.FloatingWidget then return end
        self:PlaySound("toggle")
        self.FloatingWidget.Visible = false
        self.MainContainer.Visible = true
        local targetSize = self.SavedWindowSize or UDim2.new(0, 620, 0, 490)
        local targetPos = self.SavedWindowPos or self.MainContainer.Position
        self.MainContainer.Position = targetPos
        self.MainContainer.Size = UDim2.new(0, targetSize.X.Offset * 0.8, 0, 0)
        tween(self.MainContainer, {Size = targetSize}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end

    function UILibrary:ToggleWindow()
        if not self.MainContainer then return end
        if self.MainContainer.Visible then
            self:MinimizeToFloating()
        else
            self:RestoreFromFloating()
        end
    end

    -- =========================================================================
    -- 6. MAIN WINDOW CREATION
    -- =========================================================================
    function UILibrary:CreateWindow(titleText)
        local Interface = Instance.new("ScreenGui")
        Interface.Name = "RestaurantUtilityPanel"
        Interface.ResetOnSpawn = false
        Interface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local hiddenContainer = (gethui and gethui()) or nil
        pcall(function()
            if hiddenContainer then
                Interface.Parent = hiddenContainer
            else
                Interface.Parent = Services.CoreGui
            end
        end)
        if not Interface.Parent then
            local localPlr = Services.Players.LocalPlayer
            if localPlr then
                Interface.Parent = localPlr:WaitForChild("PlayerGui", 5) or localPlr:FindFirstChild("PlayerGui")
            end
        end
        self.Interface = Interface

        -- Main Window Canvas
        local MainContainer = Instance.new("Frame")
        MainContainer.Name = "MainContainer"
        MainContainer.Parent = Interface
        MainContainer.Size = UDim2.new(0, 620, 0, 490)
        MainContainer.Position = UDim2.new(0.5, -310, 0.5, -245)
        MainContainer.BackgroundColor3 = Theme.Background
        MainContainer.BorderSizePixel = 0
        MainContainer.Active = true
        MainContainer.ClipsDescendants = false
        Instance.new("UICorner", MainContainer).CornerRadius = UDim.new(0, 10)
        self.MainContainer = MainContainer

        -- Subtle Outer Glow & Specular Border
        local UIStroke = Instance.new("UIStroke")
        UIStroke.Parent = MainContainer
        UIStroke.Color = Theme.CardBorder
        UIStroke.Thickness = 1.2
        self.WindowStroke = UIStroke

        -- Toast Notification Container (Bottom-Right)
        local NotificationContainer = Instance.new("Frame")
        NotificationContainer.Name = "NotificationContainer"
        NotificationContainer.Parent = Interface
        NotificationContainer.Size = UDim2.new(0, 270, 0, 360)
        NotificationContainer.Position = UDim2.new(1, -285, 1, -375)
        NotificationContainer.BackgroundTransparency = 1
        NotificationContainer.ClipsDescendants = false

        local notifyList = Instance.new("UIListLayout")
        notifyList.Parent = NotificationContainer
        notifyList.SortOrder = Enum.SortOrder.LayoutOrder
        notifyList.VerticalAlignment = Enum.VerticalAlignment.Bottom
        notifyList.Padding = UDim.new(0, 8)
        self.NotificationContainer = NotificationContainer

        -- =====================================================================
        -- 6A. HEADER BAR
        -- =====================================================================
        local Header = Instance.new("Frame")
        Header.Name = "Header"
        Header.Parent = MainContainer
        Header.Size = UDim2.new(1, 0, 0, 46)
        Header.BackgroundColor3 = Theme.Header
        Header.BorderSizePixel = 0
        Header.Active = true
        Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

        -- Bottom square filler to merge header seamlessly with body
        local HeaderSquare = Instance.new("Frame")
        HeaderSquare.Parent = Header
        HeaderSquare.Size = UDim2.new(1, 0, 0, 10)
        HeaderSquare.Position = UDim2.new(0, 0, 1, -10)
        HeaderSquare.BackgroundColor3 = Theme.Header
        HeaderSquare.BorderSizePixel = 0

        local HeaderBorderLine = Instance.new("Frame")
        HeaderBorderLine.Parent = Header
        HeaderBorderLine.Size = UDim2.new(1, 0, 0, 1)
        HeaderBorderLine.Position = UDim2.new(0, 0, 1, 0)
        HeaderBorderLine.BackgroundColor3 = Theme.CardBorder
        HeaderBorderLine.BorderSizePixel = 0

        -- App Branding (Icon + Title + Pro Badge)
        local BrandIcon = Instance.new("TextLabel")
        BrandIcon.Parent = Header
        BrandIcon.Size = UDim2.new(0, 26, 1, 0)
        BrandIcon.Position = UDim2.new(0, 14, 0, 0)
        BrandIcon.BackgroundTransparency = 1
        BrandIcon.Font = Enum.Font.GothamBold
        BrandIcon.Text = "🍽️"
        BrandIcon.TextSize = 18

        local TitleLbl = Instance.new("TextLabel")
        TitleLbl.Parent = Header
        TitleLbl.Size = UDim2.new(0, 150, 1, 0)
        TitleLbl.Position = UDim2.new(0, 42, 0, 0)
        TitleLbl.BackgroundTransparency = 1
        TitleLbl.Font = Enum.Font.GothamBold
        TitleLbl.Text = titleText
        TitleLbl.TextColor3 = Theme.TextPrimary
        TitleLbl.TextSize = 13
        TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local ProBadge = Instance.new("Frame")
        ProBadge.Parent = Header
        ProBadge.Size = UDim2.new(0, 52, 0, 18)
        ProBadge.Position = UDim2.new(0, 196, 0.5, -9)
        ProBadge.BackgroundColor3 = Theme.Primary
        ProBadge.BackgroundTransparency = 0.8
        Instance.new("UICorner", ProBadge).CornerRadius = UDim.new(0, 4)

        local ProBadgeStroke = Instance.new("UIStroke")
        ProBadgeStroke.Parent = ProBadge
        ProBadgeStroke.Color = Theme.Primary
        ProBadgeStroke.Thickness = 1

        local ProBadgeLbl = Instance.new("TextLabel")
        ProBadgeLbl.Parent = ProBadge
        ProBadgeLbl.Size = UDim2.new(1, 0, 1, 0)
        ProBadgeLbl.BackgroundTransparency = 1
        ProBadgeLbl.Font = Enum.Font.GothamBold
        ProBadgeLbl.Text = "PRO v2.0"
        ProBadgeLbl.TextColor3 = Theme.Primary
        ProBadgeLbl.TextSize = 9

        -- Global Live Status Dot & Text
        local StatusPill = Instance.new("Frame")
        StatusPill.Parent = Header
        StatusPill.Size = UDim2.new(0, 68, 0, 20)
        StatusPill.Position = UDim2.new(0, 256, 0.5, -10)
        StatusPill.BackgroundColor3 = Theme.CardInner
        Instance.new("UICorner", StatusPill).CornerRadius = UDim.new(1, 0)

        local StatusDot = Instance.new("Frame")
        StatusDot.Parent = StatusPill
        StatusDot.Size = UDim2.new(0, 6, 0, 6)
        StatusDot.Position = UDim2.new(0, 8, 0.5, -3)
        StatusDot.BackgroundColor3 = Theme.TextMuted
        Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

        local StatusText = Instance.new("TextLabel")
        StatusText.Parent = StatusPill
        StatusText.Size = UDim2.new(1, -20, 1, 0)
        StatusText.Position = UDim2.new(0, 18, 0, 0)
        StatusText.BackgroundTransparency = 1
        StatusText.Font = Enum.Font.GothamBold
        StatusText.Text = "IDLE"
        StatusText.TextColor3 = Theme.TextSecondary
        StatusText.TextSize = 9
        StatusText.TextXAlignment = Enum.TextXAlignment.Left

        self.HeaderStatusDot = StatusDot
        self.HeaderStatusText = StatusText

        -- Header Search Bar (Instant Filter)
        local SearchBoxFrame = Instance.new("Frame")
        SearchBoxFrame.Parent = Header
        SearchBoxFrame.Size = UDim2.new(0, 130, 0, 26)
        SearchBoxFrame.Position = UDim2.new(1, -230, 0.5, -13)
        SearchBoxFrame.BackgroundColor3 = Theme.CardInner
        Instance.new("UICorner", SearchBoxFrame).CornerRadius = UDim.new(0, 6)

        local SearchStroke = Instance.new("UIStroke")
        SearchStroke.Parent = SearchBoxFrame
        SearchStroke.Color = Theme.CardBorder
        SearchStroke.Thickness = 1

        local SearchIcon = Instance.new("TextLabel")
        SearchIcon.Parent = SearchBoxFrame
        SearchIcon.Size = UDim2.new(0, 22, 1, 0)
        SearchIcon.Position = UDim2.new(0, 4, 0, 0)
        SearchIcon.BackgroundTransparency = 1
        SearchIcon.Font = Enum.Font.GothamBold
        SearchIcon.Text = "🔍"
        SearchIcon.TextSize = 11

        local SearchInput = Instance.new("TextBox")
        SearchInput.Parent = SearchBoxFrame
        SearchInput.Size = UDim2.new(1, -28, 1, 0)
        SearchInput.Position = UDim2.new(0, 26, 0, 0)
        SearchInput.BackgroundTransparency = 1
        SearchInput.Font = Enum.Font.GothamMedium
        SearchInput.PlaceholderText = "Search options..."
        SearchInput.PlaceholderColor3 = Theme.TextMuted
        SearchInput.Text = ""
        SearchInput.TextColor3 = Theme.TextPrimary
        SearchInput.TextSize = 11
        SearchInput.TextXAlignment = Enum.TextXAlignment.Left
        SearchInput.ClearTextOnFocus = false

        SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
            self:FilterCards(SearchInput.Text)
        end)

        -- Window Controls (Reset Pos, Minimize, Close)
        local ControlsGroup = Instance.new("Frame")
        ControlsGroup.Parent = Header
        ControlsGroup.Size = UDim2.new(0, 88, 0, 28)
        ControlsGroup.Position = UDim2.new(1, -94, 0.5, -14)
        ControlsGroup.BackgroundTransparency = 1

        local function makeHeaderBtn(icon, posX, colorHover, onClick)
            local btn = Instance.new("TextButton")
            btn.Parent = ControlsGroup
            btn.Size = UDim2.new(0, 26, 0, 26)
            btn.Position = UDim2.new(0, posX, 0, 1)
            btn.BackgroundColor3 = Theme.CardInner
            btn.Text = icon
            btn.TextColor3 = Theme.TextSecondary
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

            local bStroke = Instance.new("UIStroke")
            bStroke.Parent = btn
            bStroke.Color = Theme.CardBorder
            bStroke.Thickness = 1

            btn.MouseEnter:Connect(function()
                tween(btn, {BackgroundColor3 = colorHover, TextColor3 = Theme.TextPrimary}, 0.15)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundColor3 = Theme.CardInner, TextColor3 = Theme.TextSecondary}, 0.15)
            end)
            btn.Activated:Connect(onClick)
            return btn
        end

        -- 1. Center Window Button
        makeHeaderBtn("⟲", 0, Theme.CardHover, function()
            self:PlaySound("click")
            local targetPos = UDim2.new(0.5, -MainContainer.AbsoluteSize.X * 0.5, 0.5, -MainContainer.AbsoluteSize.Y * 0.5)
            self.SavedWindowPos = targetPos
            tween(MainContainer, {Position = targetPos}, 0.3, Enum.EasingStyle.Back)
            self:Notify({Title = "Position Reset", Content = "Window centered on screen.", Type = "Info", Duration = 2})
        end)

        -- 2. Minimize Button
        makeHeaderBtn("—", 30, Color3.fromRGB(180, 130, 40), function()
            self:MinimizeToFloating()
        end)

        -- 3. Close / Unload Button
        makeHeaderBtn("✕", 60, Theme.Danger, function()
            self:PlaySound("click")
            Utility.Terminate()
        end)

        -- Header Dragging
        local function startWindowDrag(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = MainContainer.Position
            end
        end

        Header.Active = true
        Header.InputBegan:Connect(startWindowDrag)
        HeaderSquare.InputBegan:Connect(startWindowDrag)
        BrandIcon.InputBegan:Connect(startWindowDrag)
        TitleLbl.InputBegan:Connect(startWindowDrag)
        ProBadge.InputBegan:Connect(startWindowDrag)
        StatusPill.InputBegan:Connect(startWindowDrag)

        -- =====================================================================
        -- 6B. BODY LAYOUT (Left Sidebar + Right Tab View)
        -- =====================================================================
        local Sidebar = Instance.new("Frame")
        Sidebar.Name = "Sidebar"
        Sidebar.Parent = MainContainer
        Sidebar.Size = UDim2.new(0, 142, 1, -47)
        Sidebar.Position = UDim2.new(0, 0, 0, 47)
        Sidebar.BackgroundColor3 = Theme.Sidebar
        Sidebar.BorderSizePixel = 0
        Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

        -- Right border hairline for sidebar
        local SidebarRightLine = Instance.new("Frame")
        SidebarRightLine.Parent = Sidebar
        SidebarRightLine.Size = UDim2.new(0, 1, 1, 0)
        SidebarRightLine.Position = UDim2.new(1, -1, 0, 0)
        SidebarRightLine.BackgroundColor3 = Theme.CardBorder
        SidebarRightLine.BorderSizePixel = 0

        local SidebarScroll = Instance.new("ScrollingFrame")
        SidebarScroll.Parent = Sidebar
        SidebarScroll.Size = UDim2.new(1, 0, 1, -10)
        SidebarScroll.Position = UDim2.new(0, 0, 0, 6)
        SidebarScroll.BackgroundTransparency = 1
        SidebarScroll.BorderSizePixel = 0
        SidebarScroll.ScrollBarThickness = 2
        SidebarScroll.ScrollBarImageColor3 = Theme.CardBorder
        SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

        local SidebarList = Instance.new("UIListLayout")
        SidebarList.Parent = SidebarScroll
        SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
        SidebarList.Padding = UDim.new(0, 4)
        SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, SidebarList.AbsoluteContentSize.Y + 12)
        end)
        self.SidebarScroll = SidebarScroll

        -- Active Tab Indicator (Sliding accent bar)
        local ActiveIndicator = Instance.new("Frame")
        ActiveIndicator.Parent = Sidebar
        ActiveIndicator.Size = UDim2.new(0, 3, 0, 22)
        ActiveIndicator.Position = UDim2.new(0, 0, 0, 12)
        ActiveIndicator.BackgroundColor3 = Theme.Primary
        ActiveIndicator.BorderSizePixel = 0
        Instance.new("UICorner", ActiveIndicator).CornerRadius = UDim.new(1, 0)
        self.ActiveIndicator = ActiveIndicator

        -- Right Content Viewport
        local ContentViewport = Instance.new("Frame")
        ContentViewport.Name = "ContentViewport"
        ContentViewport.Parent = MainContainer
        ContentViewport.Size = UDim2.new(1, -143, 1, -47)
        ContentViewport.Position = UDim2.new(0, 143, 0, 47)
        ContentViewport.BackgroundTransparency = 1
        ContentViewport.ClipsDescendants = true
        self.ContentViewport = ContentViewport

        -- Resize Handle (Bottom-Right)
        local ResizeHandle = Instance.new("TextButton")
        ResizeHandle.Parent = MainContainer
        ResizeHandle.Size = UDim2.new(0, 24, 0, 24)
        ResizeHandle.Position = UDim2.new(1, -24, 1, -24)
        ResizeHandle.BackgroundTransparency = 1
        ResizeHandle.Font = Enum.Font.GothamBold
        ResizeHandle.Text = "⋱"
        ResizeHandle.TextColor3 = Theme.TextMuted
        ResizeHandle.TextSize = 14
        ResizeHandle.ZIndex = 50

        ResizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeStart = input.Position
                sizeStart = MainContainer.AbsoluteSize
            end
        end)

        -- Theme changes reactive updates
        self:RegisterThemeListener(function(t)
            ProBadge.BackgroundColor3 = t.Primary
            ProBadgeStroke.Color = t.Primary
            ProBadgeLbl.TextColor3 = t.Primary
            ActiveIndicator.BackgroundColor3 = t.Primary
        end)

        self.Tabs = {}
        self.TabFrames = {}
        self.TabButtons = {}
        self.TabCards = {} -- For search indexing
        self.TabCount = 0
        self.ActiveTab = nil

        self:CreateFloatingWidget()
        self:InitInputDispatchers()

        local Window = { Library = self }
        function Window:AddTab(name, icon) return self.Library:CreateTab(name, icon) end
        function Window:SelectTab(name) self.Library:SelectTab(name) end
        function Window:Notify(options) self.Library:Notify(options) end
        function Window:SetTheme(name) self.Library:SetTheme(name) end
        function Window:UpdateStatus(isActive, text) self.Library:UpdateStatus(isActive, text) end

        return Window
    end

    -- =========================================================================
    -- 7. TAB MANAGEMENT (Left Sidebar Items & Scrolling Containers)
    -- =========================================================================
    function UILibrary:CreateTab(name, icon)
        self.TabCount = self.TabCount + 1
        local tabIndex = self.TabCount
        icon = icon or "📁"

        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. name
        btn.Parent = self.SidebarScroll
        btn.Size = UDim2.new(0.92, 0, 0, 36)
        btn.BackgroundColor3 = Theme.Sidebar
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel = 0
        btn.LayoutOrder = tabIndex
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local tabIcon = Instance.new("TextLabel")
        tabIcon.Parent = btn
        tabIcon.Size = UDim2.new(0, 24, 1, 0)
        tabIcon.Position = UDim2.new(0, 8, 0, 0)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Font = Enum.Font.GothamBold
        tabIcon.Text = icon
        tabIcon.TextSize = 14

        local tabTitle = Instance.new("TextLabel")
        tabTitle.Parent = btn
        tabTitle.Size = UDim2.new(1, -38, 1, 0)
        tabTitle.Position = UDim2.new(0, 36, 0, 0)
        tabTitle.BackgroundTransparency = 1
        tabTitle.Font = Enum.Font.GothamMedium
        tabTitle.Text = name
        tabTitle.TextColor3 = Theme.TextSecondary
        tabTitle.TextSize = 12
        tabTitle.TextXAlignment = Enum.TextXAlignment.Left

        -- Hover state
        btn.MouseEnter:Connect(function()
            if self.ActiveTab ~= name then
                tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = Theme.CardHover})
                tween(tabTitle, {TextColor3 = Theme.TextPrimary})
            end
        end)
        btn.MouseLeave:Connect(function()
            if self.ActiveTab ~= name then
                tween(btn, {BackgroundTransparency = 1})
                tween(tabTitle, {TextColor3 = Theme.TextSecondary})
            end
        end)

        btn.Activated:Connect(function()
            self:SelectTab(name)
        end)

        self.TabButtons[name] = { Button = btn, Title = tabTitle, Icon = tabIcon }

        -- Content Frame for Tab
        local frame = Instance.new("ScrollingFrame")
        frame.Name = "TabFrame_" .. name
        frame.Parent = self.ContentViewport
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ScrollBarThickness = 4
        frame.ScrollBarImageColor3 = Theme.CardBorder
        frame.CanvasSize = UDim2.new(0, 0, 0, 0)
        frame.Visible = false

        local UIList = Instance.new("UIListLayout")
        UIList.Parent = frame
        UIList.SortOrder = Enum.SortOrder.LayoutOrder
        UIList.Padding = UDim.new(0, 8)
        UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local UIPad = Instance.new("UIPadding")
        UIPad.Parent = frame
        UIPad.PaddingTop = UDim.new(0, 10)
        UIPad.PaddingBottom = UDim.new(0, 14)
        UIPad.PaddingLeft = UDim.new(0, 8)
        UIPad.PaddingRight = UDim.new(0, 8)

        UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            frame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 24)
        end)

        self.TabFrames[name] = frame
        self.TabCards[name] = {}

        if self.TabCount == 1 then
            task.defer(function() self:SelectTab(name) end)
        end

        local TabObj = { Frame = frame, Name = name, Library = self }

        function TabObj:AddHeroCard(data) return self.Library:CreateHeroCard(self.Frame, self.Name, data) end
        function TabObj:AddMetricGrid() return self.Library:CreateMetricGrid(self.Frame, self.Name) end
        function TabObj:AddSection(text, secIcon) return self.Library:CreateSection(self.Frame, self.Name, text, secIcon) end
        function TabObj:AddToggle(title, desc, default, cb) return self.Library:CreateToggle(self.Frame, self.Name, title, desc, default, cb) end
        function TabObj:AddSlider(title, desc, default, min, max, precision, suffix, cb) return self.Library:CreateSlider(self.Frame, self.Name, title, desc, default, min, max, precision, suffix, cb) end
        function TabObj:AddDropdown(title, desc, options, default, cb) return self.Library:CreateDropdown(self.Frame, self.Name, title, desc, options, default, cb) end
        function TabObj:AddKeybind(title, desc, defaultKey, cb) return self.Library:CreateKeybind(self.Frame, self.Name, title, desc, defaultKey, cb) end
        function TabObj:AddButton(title, desc, variant, cb) return self.Library:CreateButton(self.Frame, self.Name, title, desc, variant, cb) end
        function TabObj:AddParagraph(title, content) return self.Library:CreateParagraph(self.Frame, self.Name, title, content) end

        return TabObj
    end

    function UILibrary:SelectTab(name)
        if not self.TabFrames[name] then return end
        self:PlaySound("tab")
        self.ActiveTab = name

        for tName, data in pairs(self.TabButtons) do
            local isSelected = (tName == name)
            if isSelected then
                tween(data.Button, {BackgroundTransparency = 0, BackgroundColor3 = Theme.Card})
                tween(data.Title, {TextColor3 = Theme.Primary})
                local posY = data.Button.Position.Y.Offset + data.Button.AbsolutePosition.Y - self.SidebarScroll.AbsolutePosition.Y
                tween(self.ActiveIndicator, {Position = UDim2.new(0, 0, 0, data.Button.Position.Y.Offset + 7)}, 0.25, Enum.EasingStyle.Quart)
            else
                tween(data.Button, {BackgroundTransparency = 1})
                tween(data.Title, {TextColor3 = Theme.TextSecondary})
            end
        end

        for tName, frame in pairs(self.TabFrames) do
            if tName == name then
                frame.Visible = true
                frame.Position = UDim2.new(0, 8, 0, 0)
                tween(frame, {Position = UDim2.new(0, 0, 0, 0)}, 0.2, Enum.EasingStyle.Quad)
            else
                frame.Visible = false
            end
        end
    end

    function UILibrary:UpdateStatus(isActive, text)
        if self.HeaderStatusDot and self.HeaderStatusText then
            if isActive then
                self.HeaderStatusDot.BackgroundColor3 = Theme.Success
                self.HeaderStatusText.Text = text or "ACTIVE"
                self.HeaderStatusText.TextColor3 = Theme.Success
            else
                self.HeaderStatusDot.BackgroundColor3 = Theme.TextMuted
                self.HeaderStatusText.Text = text or "IDLE"
                self.HeaderStatusText.TextColor3 = Theme.TextSecondary
            end
        end
        self:UpdateFloatingStatus(isActive, text)
    end

    -- =========================================================================
    -- 8. SEARCH & FILTERING ENGINE
    -- =========================================================================
    function UILibrary:FilterCards(query)
        if not self.ActiveTab or not self.TabCards[self.ActiveTab] then return end
        query = query and query:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""

        for _, item in ipairs(self.TabCards[self.ActiveTab]) do
            if query == "" then
                item.Card.Visible = true
            else
                local match = (item.Title and item.Title:lower():find(query, 1, true)) or
                              (item.Desc and item.Desc:lower():find(query, 1, true))
                item.Card.Visible = match and true or false
            end
        end
    end

    local function NextOrder(parent)
        local c = 0
        for _, v in ipairs(parent:GetChildren()) do if v:IsA("GuiObject") then c = c + 1 end end
        return c
    end

    -- =========================================================================
    -- 9. COMPONENT SUITE
    -- =========================================================================

    -- 9A. HERO DASHBOARD MASTER CARD
    function UILibrary:CreateHeroCard(parent, tabName, data)
        data = data or {}
        local card = Instance.new("Frame")
        card.Name = "HeroCard"
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, 80)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.Primary
        stroke.Thickness = 1.2

        local gradient = Instance.new("UIGradient")
        gradient.Parent = card
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Card),
            ColorSequenceKeypoint.new(1, Theme.CardHover)
        })
        gradient.Rotation = 45

        local icon = Instance.new("TextLabel")
        icon.Parent = card
        icon.Size = UDim2.new(0, 42, 0, 42)
        icon.Position = UDim2.new(0, 14, 0.5, -21)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.Text = data.Icon or "⚡"
        icon.TextSize = 26

        local title = Instance.new("TextLabel")
        title.Parent = card
        title.Size = UDim2.new(1, -160, 0, 20)
        title.Position = UDim2.new(0, 62, 0, 14)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = data.Title or "Master Auto-Farm"
        title.TextColor3 = Theme.TextPrimary
        title.TextSize = 15
        title.TextXAlignment = Enum.TextXAlignment.Left

        local sub = Instance.new("TextLabel")
        sub.Parent = card
        sub.Size = UDim2.new(1, -160, 0, 16)
        sub.Position = UDim2.new(0, 62, 0, 36)
        sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.GothamMedium
        sub.Text = data.Subtitle or "Synchronizes all seating, cooking, serving, and cash automation."
        sub.TextColor3 = Theme.TextSecondary
        sub.TextSize = 11
        sub.TextXAlignment = Enum.TextXAlignment.Left

        local extraInfo = Instance.new("TextLabel")
        extraInfo.Parent = card
        extraInfo.Size = UDim2.new(1, -160, 0, 14)
        extraInfo.Position = UDim2.new(0, 62, 0, 54)
        extraInfo.BackgroundTransparency = 1
        extraInfo.Font = Enum.Font.GothamBold
        extraInfo.Text = "⏱ Uptime: 00:00:00  •  Rate: +$0 / hr"
        extraInfo.TextColor3 = Theme.Primary
        extraInfo.TextSize = 10
        extraInfo.TextXAlignment = Enum.TextXAlignment.Left

        -- Master Toggle Switch
        local switchTrack = Instance.new("Frame")
        switchTrack.Parent = card
        switchTrack.Size = UDim2.new(0, 48, 0, 26)
        switchTrack.Position = UDim2.new(1, -64, 0.5, -13)
        switchTrack.BackgroundColor3 = data.InitialState and Theme.Success or Theme.CardInner
        Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

        local switchKnob = Instance.new("Frame")
        switchKnob.Parent = switchTrack
        switchKnob.Size = UDim2.new(0, 20, 0, 20)
        switchKnob.Position = data.InitialState and UDim2.new(0, 24, 0.5, -10) or UDim2.new(0, 4, 0.5, -10)
        switchKnob.BackgroundColor3 = Color3.fromRGB(250, 252, 255)
        Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

        local switchBtn = Instance.new("TextButton")
        switchBtn.Parent = switchTrack
        switchBtn.Size = UDim2.new(1, 0, 1, 0)
        switchBtn.BackgroundTransparency = 1
        switchBtn.Text = ""

        local isToggled = data.InitialState or false
        local function setHeroState(state)
            isToggled = state
            tween(switchTrack, {BackgroundColor3 = state and Theme.Success or Theme.CardInner}, 0.2)
            tween(switchKnob, {Position = state and UDim2.new(0, 24, 0.5, -10) or UDim2.new(0, 4, 0.5, -10)}, 0.2, Enum.EasingStyle.Quad)
            if data.OnToggle then data.OnToggle(state) end
        end

        switchBtn.Activated:Connect(function()
            self:PlaySound("toggle")
            setHeroState(not isToggled)
        end)

        self:RegisterThemeListener(function(t)
            stroke.Color = t.Primary
            extraInfo.TextColor3 = t.Primary
        end)

        return {
            Card = card,
            SetState = setHeroState,
            SetInfo = function(text) extraInfo.Text = text end
        }
    end

    -- 9B. LIVE METRIC TILES GRID
    function UILibrary:CreateMetricGrid(parent, tabName)
        local gridFrame = Instance.new("Frame")
        gridFrame.Name = "MetricGrid"
        gridFrame.Parent = parent
        gridFrame.Size = UDim2.new(0.96, 0, 0, 0)
        gridFrame.BackgroundTransparency = 1
        gridFrame.LayoutOrder = NextOrder(parent)

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.Parent = gridFrame
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.CellSize = UDim2.new(0.485, 0, 0, 58)
        gridLayout.CellPadding = UDim2.new(0.03, 0, 0, 8)

        gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            gridFrame.Size = UDim2.new(0.96, 0, 0, gridLayout.AbsoluteContentSize.Y)
        end)

        local metrics = {}
        local gridObj = { Frame = gridFrame }

        function gridObj:AddMetric(id, icon, titleText, initialVal, accentColor)
            accentColor = accentColor or Theme.Primary

            local tile = Instance.new("Frame")
            tile.Name = "Metric_" .. id
            tile.Parent = gridFrame
            tile.BackgroundColor3 = Theme.Card
            tile.BorderSizePixel = 0
            Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 8)

            local stroke = Instance.new("UIStroke")
            stroke.Parent = tile
            stroke.Color = Theme.CardBorder
            stroke.Thickness = 1

            local iconBox = Instance.new("Frame")
            iconBox.Parent = tile
            iconBox.Size = UDim2.new(0, 34, 0, 34)
            iconBox.Position = UDim2.new(0, 10, 0.5, -17)
            iconBox.BackgroundColor3 = accentColor
            iconBox.BackgroundTransparency = 0.85
            Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 6)

            local iconLbl = Instance.new("TextLabel")
            iconLbl.Parent = iconBox
            iconLbl.Size = UDim2.new(1, 0, 1, 0)
            iconLbl.BackgroundTransparency = 1
            iconLbl.Font = Enum.Font.GothamBold
            iconLbl.Text = icon
            iconLbl.TextSize = 16

            local tLbl = Instance.new("TextLabel")
            tLbl.Parent = tile
            tLbl.Size = UDim2.new(1, -54, 0, 16)
            tLbl.Position = UDim2.new(0, 50, 0, 8)
            tLbl.BackgroundTransparency = 1
            tLbl.Font = Enum.Font.GothamMedium
            tLbl.Text = titleText
            tLbl.TextColor3 = Theme.TextSecondary
            tLbl.TextSize = 10
            tLbl.TextXAlignment = Enum.TextXAlignment.Left

            local vLbl = Instance.new("TextLabel")
            vLbl.Parent = tile
            vLbl.Size = UDim2.new(1, -54, 0, 24)
            vLbl.Position = UDim2.new(0, 50, 0, 24)
            vLbl.BackgroundTransparency = 1
            vLbl.Font = Enum.Font.GothamBold
            vLbl.Text = tostring(initialVal or 0)
            vLbl.TextColor3 = Theme.TextPrimary
            vLbl.TextSize = 15
            vLbl.TextXAlignment = Enum.TextXAlignment.Left

            metrics[id] = { ValueLabel = vLbl, Tile = tile }

            tile.MouseEnter:Connect(function()
                tween(tile, {BackgroundColor3 = Theme.CardHover})
                tween(stroke, {Color = accentColor})
            end)
            tile.MouseLeave:Connect(function()
                tween(tile, {BackgroundColor3 = Theme.Card})
                tween(stroke, {Color = Theme.CardBorder})
            end)
        end

        function gridObj:UpdateMetric(id, newVal)
            if metrics[id] then
                metrics[id].ValueLabel.Text = tostring(newVal)
            end
        end

        return gridObj
    end

    -- 9C. SECTION DIVIDER
    function UILibrary:CreateSection(parent, tabName, text, icon)
        icon = icon or "◆"
        local secFrame = Instance.new("Frame")
        secFrame.Name = "Section_" .. text
        secFrame.Parent = parent
        secFrame.Size = UDim2.new(0.96, 0, 0, 28)
        secFrame.BackgroundTransparency = 1
        secFrame.LayoutOrder = NextOrder(parent)

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Parent = secFrame
        iconLbl.Size = UDim2.new(0, 16, 1, 0)
        iconLbl.Position = UDim2.new(0, 2, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Text = icon
        iconLbl.TextColor3 = Theme.Primary
        iconLbl.TextSize = 11

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = secFrame
        titleLbl.Size = UDim2.new(0, 200, 1, 0)
        titleLbl.Position = UDim2.new(0, 20, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = text:upper()
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 11
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local dividerLine = Instance.new("Frame")
        dividerLine.Parent = secFrame
        dividerLine.Size = UDim2.new(1, -225, 0, 1)
        dividerLine.Position = UDim2.new(0, 225, 0.5, 0)
        dividerLine.BackgroundColor3 = Theme.CardBorder
        dividerLine.BorderSizePixel = 0

        self:RegisterThemeListener(function(t)
            iconLbl.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = secFrame, Title = text, Desc = "" })
        return secFrame
    end

    -- 9D. MODERN TOGGLE WITH SUBTEXT
    function UILibrary:CreateToggle(parent, tabName, titleText, descText, initialState, callback)
        local hasDesc = descText and #descText > 0
        local cardHeight = hasDesc and 48 or 38

        local card = Instance.new("Frame")
        card.Name = "Toggle_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, cardHeight)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(1, -70, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -70, 0, 16)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local track = Instance.new("Frame")
        track.Parent = card
        track.Size = UDim2.new(0, 42, 0, 22)
        track.Position = UDim2.new(1, -54, 0.5, -11)
        track.BackgroundColor3 = initialState and Theme.Success or Theme.CardInner
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Parent = track
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initialState and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(245, 247, 252)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""

        local isToggled = initialState or false
        local function updateToggle(state)
            isToggled = state
            tween(track, {BackgroundColor3 = state and Theme.Success or Theme.CardInner}, 0.2)
            tween(knob, {Position = state and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, 0.2, Enum.EasingStyle.Quad)
        end

        btn.MouseEnter:Connect(function()
            tween(card, {BackgroundColor3 = Theme.CardHover})
        end)
        btn.MouseLeave:Connect(function()
            tween(card, {BackgroundColor3 = Theme.Card})
        end)

        btn.Activated:Connect(function()
            self:PlaySound("toggle")
            isToggled = not isToggled
            updateToggle(isToggled)
            if callback then callback(isToggled) end
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })

        return {
            Card = card,
            SetState = function(selfObj, val)
                updateToggle(val)
            end
        }
    end

    -- 9E. MODERN SLIDER WITH INTERACTIVE TEXT INPUT BADGE
    function UILibrary:CreateSlider(parent, tabName, titleText, descText, default, min, max, precision, suffix, callback)
        min = min or 0
        max = max or 100
        precision = precision or 0
        suffix = suffix or ""
        default = math.clamp(default or min, min, max)

        sliderIdCounter = sliderIdCounter + 1
        local sliderId = sliderIdCounter

        local hasDesc = descText and #descText > 0
        local cardHeight = hasDesc and 58 or 48

        local card = Instance.new("Frame")
        card.Name = "Slider_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, cardHeight)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(0.65, 0, 0, 18)
        titleLbl.Position = UDim2.new(0, 12, 0, 5)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(0.65, 0, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 21)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        -- Numeric Editable Input Badge
        local badge = Instance.new("Frame")
        badge.Parent = card
        badge.Size = UDim2.new(0, 60, 0, 20)
        badge.Position = UDim2.new(1, -72, 0, 6)
        badge.BackgroundColor3 = Theme.CardInner
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)

        local bStroke = Instance.new("UIStroke")
        bStroke.Parent = badge
        bStroke.Color = Theme.CardBorder
        bStroke.Thickness = 1

        local valBox = Instance.new("TextBox")
        valBox.Parent = badge
        valBox.Size = UDim2.new(1, 0, 1, 0)
        valBox.BackgroundTransparency = 1
        valBox.Font = Enum.Font.GothamBold
        valBox.Text = tostring(default) .. suffix
        valBox.TextColor3 = Theme.Primary
        valBox.TextSize = 11
        valBox.ClearTextOnFocus = false

        -- Draggable Slider Track
        local track = Instance.new("TextButton")
        track.Parent = card
        track.Size = UDim2.new(1, -24, 0, 6)
        track.Position = UDim2.new(0, 12, 1, -12)
        track.BackgroundColor3 = Theme.CardInner
        track.Text = ""
        track.AutoButtonColor = false
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Parent = track
        fill.Size = UDim2.new((default - min) / math.max(1, max - min), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Primary
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local currentVal = default
        local function setSliderVal(newVal, fireCb)
            newVal = math.clamp(newVal, min, max)
            if precision == 0 then
                newVal = math.floor(newVal + 0.5)
            else
                local mult = 10 ^ precision
                newVal = math.floor(newVal * mult + 0.5) / mult
            end
            currentVal = newVal
            local pct = (newVal - min) / math.max(1, max - min)
            tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
            valBox.Text = tostring(newVal) .. suffix
            if fireCb and callback then callback(newVal) end
        end

        local function updateFromInput(input)
            local width = math.max(1, track.AbsoluteSize.X)
            local posX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, width)
            local pct = posX / width
            local rawVal = min + (max - min) * pct
            setSliderVal(rawVal, true)
        end

        sliderCallbacks[sliderId] = updateFromInput

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                activeSliderId = sliderId
                updateFromInput(input)
            end
        end)

        valBox.FocusLost:Connect(function()
            local num = tonumber(valBox.Text:gsub("[^%d.-]", ""))
            if num then
                setSliderVal(num, true)
            else
                valBox.Text = tostring(currentVal) .. suffix
            end
        end)

        self:RegisterThemeListener(function(t)
            fill.BackgroundColor3 = t.Primary
            valBox.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })

        return {
            Card = card,
            SetValue = function(selfObj, v) setSliderVal(v, false) end
        }
    end

    -- 9F. MODERN SELECT DROPDOWN
    function UILibrary:CreateDropdown(parent, tabName, titleText, descText, options, default, callback)
        options = options or {}
        default = default or options[1] or ""
        local hasDesc = descText and #descText > 0

        local card = Instance.new("Frame")
        card.Name = "Dropdown_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, hasDesc and 48 or 40)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        card.ClipsDescendants = true
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(0.5, 0, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(0.5, 0, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local selectBtn = Instance.new("TextButton")
        selectBtn.Parent = card
        selectBtn.Size = UDim2.new(0, 120, 0, 26)
        selectBtn.Position = UDim2.new(1, -132, 0, hasDesc and 11 or 7)
        selectBtn.BackgroundColor3 = Theme.CardInner
        selectBtn.Font = Enum.Font.GothamBold
        selectBtn.Text = default .. " ▼"
        selectBtn.TextColor3 = Theme.Primary
        selectBtn.TextSize = 11
        Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 6)

        local sStroke = Instance.new("UIStroke")
        sStroke.Parent = selectBtn
        sStroke.Color = Theme.CardBorder
        sStroke.Thickness = 1

        -- Options Dropdown Box (Collapsible Frame)
        local optionsFrame = Instance.new("Frame")
        optionsFrame.Parent = card
        optionsFrame.Size = UDim2.new(1, -24, 0, #options * 26 + 6)
        optionsFrame.Position = UDim2.new(0, 12, 0, hasDesc and 52 or 44)
        optionsFrame.BackgroundColor3 = Theme.CardInner
        optionsFrame.BorderSizePixel = 0
        Instance.new("UICorner", optionsFrame).CornerRadius = UDim.new(0, 6)

        local oList = Instance.new("UIListLayout")
        oList.Parent = optionsFrame
        oList.SortOrder = Enum.SortOrder.LayoutOrder
        oList.Padding = UDim.new(0, 2)

        local isExpanded = false
        local function toggleDropdown()
            isExpanded = not isExpanded
            selectBtn.Text = default .. (isExpanded and " ▲" or " ▼")
            local targetH = isExpanded and ((hasDesc and 56 or 48) + #options * 28) or (hasDesc and 48 or 40)
            tween(card, {Size = UDim2.new(0.96, 0, 0, targetH)}, 0.25, Enum.EasingStyle.Quart)
        end

        selectBtn.Activated:Connect(function()
            self:PlaySound("click")
            toggleDropdown()
        end)

        for i, opt in ipairs(options) do
            local oBtn = Instance.new("TextButton")
            oBtn.Parent = optionsFrame
            oBtn.Size = UDim2.new(1, 0, 0, 24)
            oBtn.BackgroundTransparency = 1
            oBtn.Font = Enum.Font.GothamMedium
            oBtn.Text = "   " .. opt
            oBtn.TextColor3 = (opt == default) and Theme.Primary or Theme.TextSecondary
            oBtn.TextSize = 11
            oBtn.TextXAlignment = Enum.TextXAlignment.Left

            oBtn.MouseEnter:Connect(function()
                tween(oBtn, {BackgroundTransparency = 0, BackgroundColor3 = Theme.CardHover})
            end)
            oBtn.MouseLeave:Connect(function()
                tween(oBtn, {BackgroundTransparency = 1})
            end)

            oBtn.Activated:Connect(function()
                self:PlaySound("click")
                default = opt
                toggleDropdown()
                for _, child in ipairs(optionsFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.TextColor3 = (child.Text:find(opt, 1, true)) and Theme.Primary or Theme.TextSecondary
                    end
                end
                if callback then callback(opt) end
            end)
        end

        self:RegisterThemeListener(function(t)
            selectBtn.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })

        return { Card = card }
    end

    -- 9G. MODERN KEYBIND CHIP
    function UILibrary:CreateKeybind(parent, tabName, titleText, descText, defaultKey, callback)
        local hasDesc = descText and #descText > 0
        local card = Instance.new("Frame")
        card.Name = "Keybind_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, hasDesc and 48 or 38)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(1, -110, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -110, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(0, 84, 0, 24)
        btn.Position = UDim2.new(1, -96, 0.5, -12)
        btn.BackgroundColor3 = Theme.CardInner
        btn.Font = Enum.Font.GothamBold
        btn.Text = (defaultKey and defaultKey.Name) or "None"
        btn.TextColor3 = Theme.Primary
        btn.TextSize = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local bStroke = Instance.new("UIStroke")
        bStroke.Parent = btn
        bStroke.Color = Theme.CardBorder
        bStroke.Thickness = 1

        btn.Activated:Connect(function()
            self:PlaySound("click")
            if activeKeybindBtn then
                activeKeybindBtn.Text = "None"
                tween(activeKeybindBtn, {BackgroundColor3 = Theme.CardInner})
            end
            activeKeybindBtn = btn
            activeKeybindCb = callback
            btn.Text = "Press Key..."
            tween(btn, {BackgroundColor3 = Theme.PrimaryDark})
        end)

        self:RegisterThemeListener(function(t)
            btn.TextColor3 = t.Primary
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })
        return { Card = card }
    end

    -- 9H. MODERN BUTTON
    function UILibrary:CreateButton(parent, tabName, titleText, descText, variant, onClick)
        variant = variant or "Secondary" -- "Primary", "Secondary", "Danger"
        local hasDesc = descText and #descText > 0
        local card = Instance.new("Frame")
        card.Name = "Button_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, hasDesc and 48 or 36)
        card.BackgroundColor3 = (variant == "Primary") and Theme.Primary or Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = (variant == "Danger") and Theme.Danger or Theme.CardBorder
        stroke.Thickness = 1

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Parent = card
        titleLbl.Size = UDim2.new(1, -24, 0, 18)
        titleLbl.Position = hasDesc and UDim2.new(0, 12, 0, 6) or UDim2.new(0, 12, 0.5, -9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = titleText
        titleLbl.TextColor3 = (variant == "Danger") and Theme.Danger or Theme.TextPrimary
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = hasDesc and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center

        if hasDesc then
            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -24, 0, 14)
            descLbl.Position = UDim2.new(0, 12, 0, 24)
            descLbl.BackgroundTransparency = 1
            descLbl.Font = Enum.Font.GothamMedium
            descLbl.Text = descText
            descLbl.TextColor3 = Theme.TextSecondary
            descLbl.TextSize = 10
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        local btn = Instance.new("TextButton")
        btn.Parent = card
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""

        btn.MouseEnter:Connect(function()
            if variant == "Primary" then
                tween(card, {BackgroundColor3 = Theme.PrimaryGradient})
            elseif variant == "Danger" then
                tween(card, {BackgroundColor3 = Color3.fromRGB(60, 20, 24)})
            else
                tween(card, {BackgroundColor3 = Theme.CardHover})
            end
        end)
        btn.MouseLeave:Connect(function()
            if variant == "Primary" then
                tween(card, {BackgroundColor3 = Theme.Primary})
            elseif variant == "Danger" then
                tween(card, {BackgroundColor3 = Theme.Card})
            else
                tween(card, {BackgroundColor3 = Theme.Card})
            end
        end)

        btn.Activated:Connect(function()
            self:PlaySound("click")
            if onClick then onClick(titleLbl) end
        end)

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = descText or "" })
        return {
            Card = card,
            SetText = function(selfObj, text) titleLbl.Text = text end
        }
    end

    -- 9I. MODERN PARAGRAPH CARD
    function UILibrary:CreateParagraph(parent, tabName, titleText, content)
        local card = Instance.new("Frame")
        card.Name = "Paragraph_" .. titleText
        card.Parent = parent
        card.Size = UDim2.new(0.96, 0, 0, 56)
        card.BackgroundColor3 = Theme.Card
        card.BorderSizePixel = 0
        card.LayoutOrder = NextOrder(parent)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Parent = card
        stroke.Color = Theme.CardBorder
        stroke.Thickness = 1

        local tLbl = Instance.new("TextLabel")
        tLbl.Parent = card
        tLbl.Size = UDim2.new(1, -24, 0, 18)
        tLbl.Position = UDim2.new(0, 12, 0, 6)
        tLbl.BackgroundTransparency = 1
        tLbl.Font = Enum.Font.GothamBold
        tLbl.Text = titleText
        tLbl.TextColor3 = Theme.TextPrimary
        tLbl.TextSize = 12
        tLbl.TextXAlignment = Enum.TextXAlignment.Left

        local cLbl = Instance.new("TextLabel")
        cLbl.Parent = card
        cLbl.Size = UDim2.new(1, -24, 0, 26)
        cLbl.Position = UDim2.new(0, 12, 0, 24)
        cLbl.BackgroundTransparency = 1
        cLbl.Font = Enum.Font.GothamMedium
        cLbl.Text = content
        cLbl.TextColor3 = Theme.TextSecondary
        cLbl.TextSize = 10
        cLbl.TextWrapped = true
        cLbl.TextXAlignment = Enum.TextXAlignment.Left
        cLbl.TextYAlignment = Enum.TextYAlignment.Top

        table.insert(self.TabCards[tabName], { Card = card, Title = titleText, Desc = content })

        local function updateSize(text)
            task.defer(function()
                pcall(function()
                    local width = math.max(200, card.AbsoluteSize.X - 24)
                    local boundsY = Services.TextService:GetTextSize(text, 10, Enum.Font.GothamMedium, Vector2.new(width, 3000)).Y
                    local targetH = math.max(56, boundsY + 34)
                    card.Size = UDim2.new(0.96, 0, 0, targetH)
                    cLbl.Size = UDim2.new(1, -24, 0, boundsY + 8)
                end)
            end)
        end

        if content and #content > 0 then
            updateSize(content)
        end

        return {
            Card = card,
            SetTitle = function(selfObj, newTitle)
                tLbl.Text = newTitle
            end,
            SetContent = function(selfObj, newContent)
                cLbl.Text = newContent
                updateSize(newContent)
            end
        }
    end

    return UILibrary
end

end)()(Core)
        UI.Library = UILibrary

        -- Create main production window
        local Window = UILibrary:CreateWindow("Run a Restaurant")
        UI.Window = Window

        function UI.UpdateStatus()
            local active = Config.MasterAutoFarmEnabled or Config.AutoSeatEnabled or Config.AutoOrderEnabled or
                           Config.AutoCookEnabled or Config.AutoServeEnabled or Config.AutoCleanEnabled or
                           Config.AutoWashSinksEnabled or Config.AutoCollectCashEnabled or Config.AutoFarmEnabled or
                           Config.AutoDeliveryEnabled or Config.AutoRestockEnabled or Config.AutoDoQuestsEnabled or
                           Config.AutoClaimQuestsEnabled or Config.WalkSpeedEnabled or Config.JumpPowerEnabled or
                           Config.NoClipEnabled or Config.InfiniteJumpEnabled

            local text = "IDLE"
            if Config.MasterAutoFarmEnabled then
                if State.ActiveGoal and State.ActiveGoal.Title and State.ActiveGoal.Title ~= "None" then
                    text = "GOAL: " .. State.ActiveGoal.Title:upper():sub(1, 10)
                else
                    text = "FARMING"
                end
            elseif active then
                text = "ACTIVE"
            end
            Window:UpdateStatus(active, text)
        end

        -- =====================================================================
        -- 1. DASHBOARD & LIVE ANALYTICS TAB
        -- =====================================================================
        function UI.BuildDashboardTab()
            local DashTab = Window:AddTab("Dashboard", "📊")

            -- Hero Master Automation Card
            local heroCard = DashTab:AddHeroCard({
                Icon = "⚡",
                Title = "Master Restaurant Auto-Farm",
                Subtitle = "Synchronizes seating, ordering, cooking, serving, cleaning, cash sweeping, and auto doing & claiming quests.",
                InitialState = Config.MasterAutoFarmEnabled,
                OnToggle = function(state)
                    Config.MasterAutoFarmEnabled = state
                    if state then
                        Config.AutoDoQuestsEnabled = true
                        Config.AutoClaimQuestsEnabled = true
                    end
                    UI.UpdateStatus()
                    Window:Notify({
                        Title = state and "Auto-Farm Activated" or "Auto-Farm Paused",
                        Content = state and "All kitchen, dining, quest completion, and reward claiming workflows are running." or "All restaurant tasks paused.",
                        Type = state and "Success" or "Info",
                        Duration = 3.5
                    })
                end
            })

            -- Active Progressive Goal Tracker Card
            local goalCard = DashTab:AddParagraph("📜 ACTIVE GOAL: MONITORING...", "Synchronizing with game progression. Objectives will be tracked and auto-completed here.")

            -- Live Analytics Metric Grid
            DashTab:AddSection("LIVE RESTAURANT ANALYTICS", "📈")
            local metricGrid = DashTab:AddMetricGrid()

            metricGrid:AddMetric("Cash", "💵", "Cash Swept", 0, Color3.fromRGB(34, 197, 94))
            metricGrid:AddMetric("Rewards", "🎁", "Rewards Claimed", 0, Color3.fromRGB(245, 158, 11))
            metricGrid:AddMetric("Quests", "📜", "Quests Done", 0, Color3.fromRGB(168, 85, 247))
            metricGrid:AddMetric("Seated", "👥", "Guests Seated", 0, Color3.fromRGB(59, 130, 246))
            metricGrid:AddMetric("Orders", "📋", "Orders Processed", 0, Color3.fromRGB(217, 70, 239))
            metricGrid:AddMetric("Cooked", "🍳", "Dishes Cooked", 0, Color3.fromRGB(249, 115, 22))
            metricGrid:AddMetric("Served", "🍽️", "Dishes Served", 0, Color3.fromRGB(16, 185, 129))
            metricGrid:AddMetric("Cleaned", "🧼", "Tables Cleaned", 0, Color3.fromRGB(6, 182, 212))
            metricGrid:AddMetric("Washed", "🧽", "Dishes Washed", 0, Color3.fromRGB(45, 212, 191))
            metricGrid:AddMetric("Deliveries", "📦", "Deliveries Done", 0, Color3.fromRGB(234, 179, 8))
            metricGrid:AddMetric("Harvested", "🌾", "Crops Harvested", 0, Color3.fromRGB(132, 204, 22))
            metricGrid:AddMetric("Restocked", "🧊", "Storage Restocked", 0, Color3.fromRGB(14, 165, 233))
            metricGrid:AddMetric("Expansions", "🏰", "Expansions", 0, Color3.fromRGB(139, 92, 246))
            metricGrid:AddMetric("Purchased", "🛒", "Items Bought", 0, Color3.fromRGB(236, 72, 153))
            metricGrid:AddMetric("Placed", "🔨", "Items Placed", 0, Color3.fromRGB(20, 184, 166))
            metricGrid:AddMetric("Staff", "👨‍🍳", "Staff Hired", 0, Color3.fromRGB(244, 63, 94))

            -- Background Loop for Live Telemetry (Uptime, Rate, Metric counters)
            task.spawn(function()
                local startTime = State.StartTime or tick()
                while State.Running do
                    pcall(function()
                        local s = State.Stats
                        local elapsed = math.max(1, tick() - startTime)
                        local hours = math.floor(elapsed / 3600)
                        local mins = math.floor((elapsed % 3600) / 60)
                        local secs = math.floor(elapsed % 60)
                        local uptimeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

                        -- Rate estimation: items swept per hour
                        local ratePerHour = math.floor(((s.CashCollected or 0) / elapsed) * 3600)
                        heroCard.SetInfo(string.format("⏱ Uptime: %s  •  Rate: ~%d items/hr", uptimeStr, ratePerHour))

                        -- Update active goal status
                        if State.ActiveGoal and State.ActiveGoal.Title and State.ActiveGoal.Title ~= "None" then
                            local g = State.ActiveGoal
                            local progStr = (g.Progress and #g.Progress > 0) and (" [" .. g.Progress .. "]") or ""
                            local objStr = string.format("🎯 %s%s\n⚡ Auto-Farm Directive: %s", g.Objective or "In Progress", progStr, g.Category or "Automated")
                            if goalCard and goalCard.SetContent then
                                if goalCard.SetTitle then goalCard:SetTitle("📜 ACTIVE GOAL: " .. g.Title:upper()) end
                                goalCard:SetContent(objStr)
                            end
                            if UI.RestGoalCard and UI.RestGoalCard.SetContent then
                                if UI.RestGoalCard.SetTitle then UI.RestGoalCard:SetTitle("📜 ACTIVE GOAL: " .. g.Title:upper()) end
                                UI.RestGoalCard:SetContent(objStr)
                            end
                        end

                        -- Update metrics
                        local totalRewards = (s.RewardsClaimed or 0) + (s.QuestsClaimed or 0)
                        metricGrid:UpdateMetric("Cash", string.format("%d items", s.CashCollected or 0))
                        metricGrid:UpdateMetric("Rewards", totalRewards)
                        metricGrid:UpdateMetric("Quests", s.QuestsCompleted or 0)
                        metricGrid:UpdateMetric("Seated", s.CustomersSeated or 0)
                        metricGrid:UpdateMetric("Orders", s.OrdersTaken or 0)
                        metricGrid:UpdateMetric("Cooked", s.DishesCooked or 0)
                        metricGrid:UpdateMetric("Served", s.DishesServed or 0)
                        metricGrid:UpdateMetric("Cleaned", s.TablesCleaned or 0)
                        metricGrid:UpdateMetric("Washed", s.DishesWashed or 0)
                        metricGrid:UpdateMetric("Deliveries", s.DeliveriesCompleted or 0)
                        metricGrid:UpdateMetric("Harvested", s.CropsHarvested or 0)
                        metricGrid:UpdateMetric("Restocked", s.StorageRestocked or 0)
                        metricGrid:UpdateMetric("Expansions", s.ExpansionsPurchased or 0)
                        metricGrid:UpdateMetric("Purchased", s.ItemsPurchased or 0)
                        metricGrid:UpdateMetric("Placed", s.ItemsPlaced or 0)
                        metricGrid:UpdateMetric("Staff", s.StaffHired or 0)
                    end)
                    task.wait(0.6)
                end
            end)

            -- Quick Dispatch Actions
            DashTab:AddSection("QUICK COMMANDS", "⚡")
            DashTab:AddButton("⚡ Trigger All Workstations Now", "Immediately dispatches all cooking, serving, cleaning, and seating routines.", "Primary", function()
                if Core.Restaurant then
                    pcall(Core.Restaurant.HandleRestock)
                    pcall(Core.Restaurant.HandleFarming)
                    pcall(Core.Restaurant.HandleDelivery)
                    pcall(Core.Restaurant.HandleCashCollection)
                    pcall(Core.Restaurant.HandleCleaning)
                    pcall(Core.Restaurant.HandleSeating)
                    pcall(Core.Restaurant.HandleOrdering)
                    pcall(Core.Restaurant.HandleCooking)
                    pcall(Core.Restaurant.HandleServing)
                    Window:Notify({Title = "Workstations Dispatched", Content = "Triggered all active station queues.", Type = "Success", Duration = 2.5})
                end
            end)

            DashTab:AddButton("📍 Set Restaurant Anchor Here", "Calibrates your plot center to avatar position, preventing cross-plot drift.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.RecalibrateAnchor then
                    local ok = Core.Restaurant.RecalibrateAnchor()
                    Window:Notify({
                        Title = ok and "Anchor Calibrated" or "Calibration Failed",
                        Content = ok and "Restaurant anchor successfully locked." or "Could not calibrate plot anchor.",
                        Type = ok and "Success" or "Error",
                        Duration = 3
                    })
                end
            end)

            DashTab:AddButton("🎁 Claim All Rewards & Gifts Now", "Claims pending daily gifts, playtime rewards, and quest achievements.", "Secondary", function()
                local count = Utility.ClaimAllRewards()
                Window:Notify({
                    Title = "Rewards Claimed",
                    Content = (count and count > 0) and string.format("Successfully redeemed %d rewards!", count) or "All rewards already claimed.",
                    Type = "Success",
                    Duration = 3
                })
            end)
        end

        -- =====================================================================
        -- 2. RESTAURANT OPERATIONS TAB
        -- =====================================================================
        function UI.BuildRestaurantTab()
            local RestTab = Window:AddTab("Restaurant", "🍳")

            -- Kitchen & Dining Operations
            RestTab:AddSection("KITCHEN & DINING OPERATIONS", "🍽️")
            RestTab:AddToggle("Auto-Seat Customers", "Detects waiting guests at host stand and escorts them to vacant tables.", Config.AutoSeatEnabled, function(val)
                Config.AutoSeatEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Take Orders", "Takes food orders from seated tables the moment they are ready.", Config.AutoOrderEnabled, function(val)
                Config.AutoOrderEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Cook Food", "Operates cooking stoves, grills, and ovens to prepare customer food tickets.", Config.AutoCookEnabled, function(val)
                Config.AutoCookEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Serve Dishes", "Delivers finished meals from the kitchen counter directly to tables.", Config.AutoServeEnabled, function(val)
                Config.AutoServeEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Clean Tables", "Clears dirty dishes and sanitizes tables immediately after guests depart.", Config.AutoCleanEnabled, function(val)
                Config.AutoCleanEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Wash Dishes & Manage Sinks", "Deposits dirty dishes into sinks/dishwashers and scrubs dishes clean.", Config.AutoWashSinksEnabled, function(val)
                Config.AutoWashSinksEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Collect Cash & Tips", "Continuously sweeps dropped coins, tip jars, and register earnings.", Config.AutoCollectCashEnabled, function(val)
                Config.AutoCollectCashEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("VIP & Celebrity Customer Priority", "Sorts and attends to VIP and gold customers first for massive tip multipliers.", Config.VIPPriorityEnabled, function(val)
                Config.VIPPriorityEnabled = val
            end)

            -- Supply & Extra Revenue
            RestTab:AddSection("SUPPLY & EXTRA REVENUE", "📦")
            RestTab:AddToggle("Auto-Fulfill Delivery Orders", "Packages delivery meals and loads scooters for high cash multipliers.", Config.AutoDeliveryEnabled, function(val)
                Config.AutoDeliveryEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Restock Kitchen Storage", "Deposits harvested produce into fridges and pantries for chefs.", Config.AutoRestockEnabled, function(val)
                Config.AutoRestockEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Harvest Farm & Ranch", "Gathers wheat, tomatoes, and animal goods from your farm plot.", Config.AutoFarmEnabled, function(val)
                Config.AutoFarmEnabled = val
                UI.UpdateStatus()
            end)

            -- Quests & Tasks Automation
            RestTab:AddSection("QUESTS & TASKS AUTOMATION", "📜")
            UI.RestGoalCard = RestTab:AddParagraph("📜 ACTIVE GOAL: MONITORING...", "Synchronizing with game progression. Objectives will be tracked and auto-completed here.")
            RestTab:AddToggle("Auto-Do Quests", "Automatically fulfills active quest objectives, talks to quest NPCs, and prioritizes quest tasks.", Config.AutoDoQuestsEnabled, function(val)
                Config.AutoDoQuestsEnabled = val
                UI.UpdateStatus()
            end)
            RestTab:AddToggle("Auto-Claim Quests & Goals", "Automatically claims completed quests, daily tasks, and milestone rewards.", Config.AutoClaimQuestsEnabled, function(val)
                Config.AutoClaimQuestsEnabled = val
                UI.UpdateStatus()
            end)

            -- Workstation Actions
            RestTab:AddSection("WORKSTATION ACTIONS", "📍")
            RestTab:AddButton("Teleport to Restaurant Center", "Safely moves avatar to calibrated center with floor raycasting.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.RestaurantCenter then
                    local char = Core.Services.Players.LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(Core.Restaurant.RestaurantCenter + Vector3.new(0, 3, 0))
                        Window:Notify({Title = "Teleported", Content = "Arrived at restaurant center.", Type = "Info", Duration = 2})
                    end
                end
            end)
        end

        -- =====================================================================
        -- 3. BUILD & STAFF MANAGEMENT TAB
        -- =====================================================================
        -- 3. BUILD, EXPANSION & STAFF TAB
        -- =====================================================================
        function UI.BuildBuildTab()
            local BuildTab = Window:AddTab("Build/Staff", "🏗️")

            -- Budget & Affordability Safety
            BuildTab:AddSection("BUDGET & AFFORDABILITY SAFETY", "🛡️")
            local balancePara = BuildTab:AddParagraph("💵 Detected Balance & Safety Buffer", "Loading financial status...")

            BuildTab:AddSlider("Minimum Cash Reserve", "Keeps this minimum cash untouched so you never go bankrupt.", Config.MinCashReserve, 0, 100000, 0, "$", function(val)
                Config.MinCashReserve = val
            end)
            BuildTab:AddSlider("Max Single Item Price", "Maximum price allowed for a single purchase (0 = no limit).", Config.MaxItemPrice, 0, 250000, 0, "$", function(val)
                Config.MaxItemPrice = val
            end)

            -- What I Can Buy (Catalog Inspector)
            BuildTab:AddSection("WHAT I CAN BUY (CATALOG INSPECTOR)", "📋")
            local catalogPara = BuildTab:AddParagraph("📋 Available Upgrades by Category", "Press 'Scan Available Purchases' below to inspect.")

            local function updateCatalogView()
                local bal = Core.Utility.GetPlayerBalance()
                local reserve = Config.MinCashReserve or 0
                local usable = math.max(0, bal - reserve)
                local balFormatted = "$" .. tostring(bal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                local resFormatted = "$" .. tostring(reserve):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                local useFormatted = "$" .. tostring(usable):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

                balancePara:SetContent(string.format("Current Balance: %s  |  Safety Reserve: %s  |  Usable Budget: %s", balFormatted, resFormatted, useFormatted))

                if Core.Restaurant and Core.Restaurant.ScanAvailablePurchases then
                    local data = Core.Restaurant.ScanAvailablePurchases()
                    local lines = {}
                    local totalFound = #data.All
                    local affordableCount = 0

                    for _, item in ipairs(data.All) do
                        if item.CanAfford then affordableCount = affordableCount + 1 end
                    end

                    table.insert(lines, string.format("Found %d upgrades in world/shop (%d affordable right now):\n", totalFound, affordableCount))

                    local function formatCategory(catKey, catTitle)
                        local items = data[catKey]
                        if items and #items > 0 then
                            table.insert(lines, catTitle .. ":")
                            for _, it in ipairs(items) do
                                local status = it.CanAfford and "✓ AFFORDABLE" or (it.Needed > 0 and ("✗ Need +$" .. tostring(it.Needed):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or "✗ Unaffordable")
                                table.insert(lines, string.format("  • %s — %s [%s]", it.Title, it.PriceText, status))
                            end
                        end
                    end

                    formatCategory("LandFloors", "🏰 Land & Floors")
                    formatCategory("Cooking", "🍳 Cooking Appliances")
                    formatCategory("Dining", "🪑 Dining Furniture")
                    formatCategory("Kitchen", "🍽️ Kitchen Equipment")
                    formatCategory("Staff", "👨‍🍳 Staff Personnel")
                    formatCategory("Decor", "🌿 Decor & Aesthetics")

                    if totalFound == 0 then
                        table.insert(lines, "No shop prompts or UI items detected currently in range. Step near the shop or open the catalog.")
                    end

                    catalogPara:SetContent(table.concat(lines, "\n"))
                end
            end

            BuildTab:AddButton("🔄 Scan Available Purchases Now", "Inspects restaurant plot and shop to list all buyable items and prices.", "Secondary", function()
                updateCatalogView()
                Window:Notify({Title = "Catalog Scanned", Content = "Updated list of available items and affordability status.", Type = "Info", Duration = 2.5})
            end)
            BuildTab:AddButton("🛒 Auto-Buy Next Affordable Upgrade", "Instantly checks the shop and buys affordable upgrades.", "Primary", function()
                if Core.Restaurant and Core.Restaurant.HandleAutoBuy then
                    Config.AutoBuyEnabled = true
                    pcall(Core.Restaurant.HandleAutoBuy)
                    updateCatalogView()
                    Window:Notify({Title = "Shop Checked", Content = "Evaluated catalog and purchased available upgrades.", Type = "Success", Duration = 2.5})
                end
            end)

            -- Land & Floor Expansions (Strictly manual opt-in)
            BuildTab:AddSection("LAND & PROPERTY EXPANSIONS", "🏰")
            BuildTab:AddToggle("Auto-Expand Land & Floors (Master)", "Master toggle for buying land and multi-story floor unlocks as cash allows.", Config.AutoExpandEnabled, function(val)
                Config.AutoExpandEnabled = val
            end)
            BuildTab:AddToggle("Expand Plot Land Footprint", "Allows purchasing plot acreage and property boundaries.", Config.AutoBuyLand, function(val)
                Config.AutoBuyLand = val
            end)
            BuildTab:AddToggle("Unlock Upper Floors", "Allows purchasing 2nd Floor, 3rd Floor, etc.", Config.AutoBuyFloors, function(val)
                Config.AutoBuyFloors = val
            end)

            -- Cooking Appliances
            BuildTab:AddSection("COOKING APPLIANCES & UPGRADES", "🍳")
            BuildTab:AddToggle("Auto-Buy Upgrades (Master)", "Enables automatic equipment purchasing according to choices below.", Config.AutoBuyEnabled, function(val)
                Config.AutoBuyEnabled = val
            end)
            BuildTab:AddToggle("Buy Cooking Stoves & Ovens", "Purchases higher-tier stoves to cook meals faster.", Config.AutoBuyStoves, function(val)
                Config.AutoBuyStoves = val
            end)
            BuildTab:AddToggle("Buy Grills, Smokers & Fryers", "Purchases BBQ grills, smokers, and deep fryers.", Config.AutoBuyGrills, function(val)
                Config.AutoBuyGrills = val
            end)

            -- Dining Furniture
            BuildTab:AddSection("DINING ROOM FURNITURE", "🪑")
            BuildTab:AddToggle("Buy Dining Tables", "Purchases 2-seater and 4-seater dining tables.", Config.AutoBuyTables, function(val)
                Config.AutoBuyTables = val
            end)
            BuildTab:AddToggle("Buy Dining Chairs & Seating", "Purchases chairs, bar stools, and comfortable booths.", Config.AutoBuyChairs, function(val)
                Config.AutoBuyChairs = val
            end)

            -- Kitchen Equipment
            BuildTab:AddSection("KITCHEN EQUIPMENT & STORAGE", "🍽️")
            BuildTab:AddToggle("Buy Kitchen Appliances & Sinks", "Purchases dishwashers, fridges, coolers, and prep sinks.", Config.AutoBuyAppliances, function(val)
                Config.AutoBuyAppliances = val
            end)
            BuildTab:AddToggle("Buy Prep Counters & Stations", "Purchases food prep stations and kitchen counters.", Config.AutoBuyCounters, function(val)
                Config.AutoBuyCounters = val
            end)

            -- Decor & Aesthetics
            BuildTab:AddSection("DECOR & AMBIENCE", "🌿")
            BuildTab:AddToggle("Buy Decor & Aesthetic Plants", "Purchases indoor plants, trees, and decorative art.", Config.AutoBuyFurniture, function(val)
                Config.AutoBuyFurniture = val
            end)
            BuildTab:AddToggle("Buy Ambient Lighting & Lamps", "Purchases chandeliers, ceiling lights, and lamps.", Config.AutoBuyLighting, function(val)
                Config.AutoBuyLighting = val
            end)

            -- Staff Personnel Management
            BuildTab:AddSection("STAFF PERSONNEL MANAGEMENT", "👨‍🍳")
            BuildTab:AddToggle("Auto-Hire & Upgrade Staff (Master)", "Hires and levels up Cooks, Waiters, and Cleaners from Manage menu.", Config.AutoHireStaffEnabled, function(val)
                Config.AutoHireStaffEnabled = val
            end)
            BuildTab:AddToggle("Hire Cooks & Chefs", "Recruits and levels up kitchen cooks.", Config.AutoHireCooks, function(val)
                Config.AutoHireCooks = val
            end)
            BuildTab:AddToggle("Hire Waiters & Servers", "Recruits and levels up dining servers.", Config.AutoHireWaiters, function(val)
                Config.AutoHireWaiters = val
            end)
            BuildTab:AddToggle("Hire Cleaners & Janitors", "Recruits and levels up dishwashers and bussers.", Config.AutoHireCleaners, function(val)
                Config.AutoHireCleaners = val
            end)
            BuildTab:AddButton("👨‍🍳 Auto-Hire Available Staff Now", "Checks employee limits and hires available kitchen staff.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.HandleStaffManage then
                    Config.AutoHireStaffEnabled = true
                    pcall(Core.Restaurant.HandleStaffManage)
                    Window:Notify({Title = "Staff Managed", Content = "Hired and leveled up restaurant staff.", Type = "Success", Duration = 2.5})
                end
            end)

            -- Auto-Place Furniture & Seating
            BuildTab:AddSection("AUTO-PLACE STORED FURNITURE", "🔨")
            BuildTab:AddToggle("Auto-Place Stored Items (Master)", "Scans build inventory and places unplaced items on open floor grid.", Config.AutoPlaceEnabled, function(val)
                Config.AutoPlaceEnabled = val
            end)
            BuildTab:AddToggle("Place Dining Tables", "Automatically places stored tables on open floor positions.", Config.AutoPlaceTables, function(val)
                Config.AutoPlaceTables = val
            end)
            BuildTab:AddToggle("Place Dining Chairs", "Automatically positions stored chairs neatly around tables.", Config.AutoPlaceChairs, function(val)
                Config.AutoPlaceChairs = val
            end)
            BuildTab:AddToggle("Place General Furniture", "Places counters, sinks, and decor onto available floor tiles.", Config.AutoPlaceFurniture, function(val)
                Config.AutoPlaceFurniture = val
            end)
            BuildTab:AddButton("🔨 Auto-Place Stored Items Now", "Immediately places any inventory furniture onto the restaurant layout.", "Secondary", function()
                if Core.Restaurant and Core.Restaurant.HandleAutoPlace then
                    Config.AutoPlaceEnabled = true
                    pcall(Core.Restaurant.HandleAutoPlace)
                    Window:Notify({Title = "Furniture Placed", Content = "Placed unassigned inventory items on the floor grid.", Type = "Success", Duration = 2.5})
                end
            end)

            -- Auto-refresh catalog view after tab creation
            task.delay(1.0, function()
                pcall(updateCatalogView)
            end)
        end

        -- =====================================================================
        -- 4. AUTOMATION & NAVIGATION ENGINE TAB
        -- =====================================================================
        function UI.BuildAutomationTab()
            local AutoTab = Window:AddTab("Automation", "⚙️")

            -- Task Completion & Sequencing
            AutoTab:AddSection("TASK COMPLETION & TIMING", "⏱️")
            AutoTab:AddToggle("Strict Task Completion Guard", "Guarantees server prompt destruction before moving avatar to avoid dropped actions.", Config.StrictTaskCompletion, function(val)
                Config.StrictTaskCompletion = val
            end)
            AutoTab:AddSlider("Station Stay Delay", "Wait duration at cooking/dining stations for server registration.", Config.StationStayDelay or 0.22, 0.08, 1.0, 2, "s", function(val)
                Config.StationStayDelay = val
            end)
            AutoTab:AddSlider("Post-Action Settling Delay", "Micro-settling pause after finishing a task before next teleport.", Config.PostActionDelay or 0.18, 0.05, 0.8, 2, "s", function(val)
                Config.PostActionDelay = val
            end)
            AutoTab:AddSlider("Cycle Speed Delay", "Delay between global scheduler dispatch iterations.", Config.ActionDelay or 0.3, 0.1, 2.5, 2, "s", function(val)
                Config.ActionDelay = val
            end)

            -- Pipeline & Concurrency
            AutoTab:AddSection("PIPELINE & CONCURRENCY", "🔄")
            AutoTab:AddToggle("Simultaneous Multi-Queue Pipeline", "Interleaves cooking, serving, ordering, and cleaning to prevent starvation.", Config.InterleavedPipelineEnabled, function(val)
                Config.InterleavedPipelineEnabled = val
            end)
            AutoTab:AddToggle("Concurrent Workstation Batching", "Processes multiple ready prompts within 14 studs sequentially in one visit.", Config.ConcurrentExecutionEnabled, function(val)
                Config.ConcurrentExecutionEnabled = val
            end)
            AutoTab:AddSlider("Station Batch Size", "Maximum number of prompts to resolve per workstation visit.", Config.StationBatchSize or 3, 1, 5, 0, "", function(val)
                Config.StationBatchSize = val
            end)
            AutoTab:AddToggle("Opportunistic Nearby Batching", "Concurrently fires nearby ready prompts across all categories near station.", Config.RemotePromptBatching, function(val)
                Config.RemotePromptBatching = val
            end)

            -- Teleportation & Navigation
            AutoTab:AddSection("TELEPORTATION & NAVIGATION", "📍")
            AutoTab:AddToggle("Auto-Teleport to Stations", "Smooth floor raycast navigation directly to active tasks.", Config.AutoTeleportEnabled, function(val)
                Config.AutoTeleportEnabled = val
            end)
            AutoTab:AddSlider("Restaurant Scan Radius", "Maximum stud distance from plot anchor to search for tasks.", Config.MaxScanRadius or 120, 40, 300, 0, " studs", function(val)
                Config.MaxScanRadius = val
            end)
            AutoTab:AddToggle("Scope to Own Plot Only", "Filters all prompts exclusively to your own restaurant plot.", Config.PlotScopingEnabled, function(val)
                Config.PlotScopingEnabled = val
            end)
            AutoTab:AddToggle("Prevent Sitting in Chairs", "Prevents avatar from getting stuck sitting in dining chairs.", Config.PreventSitting, function(val)
                Config.PreventSitting = val
            end)
            AutoTab:AddToggle("Multi-Floor Safe Raycast", "Bounded vertical raycasting to prevent falling through floor expansions.", Config.MultiFloorSafeRaycast, function(val)
                Config.MultiFloorSafeRaycast = val
            end)

            -- AFK & Performance
            AutoTab:AddSection("AFK & PERFORMANCE", "🛡️")
            AutoTab:AddToggle("Instant Proximity Prompts", "Removes hold duration and line-of-sight checks for instant interaction.", Config.InstantPromptEnabled, function(val)
                Config.InstantPromptEnabled = val
            end)
            AutoTab:AddToggle("Anti-AFK Disconnect Guard", "Prevents Roblox's 20-minute idle disconnect kick.", Config.AntiAFKEnabled, function(val)
                Config.AntiAFKEnabled = val
            end)
            AutoTab:AddToggle("24/7 Auto-Rejoin on Disconnect", "Automatically reconnects into the server if disconnected.", Config.AutoRejoinEnabled, function(val)
                Config.AutoRejoinEnabled = val
            end)
            AutoTab:AddToggle("GPU Saver / Performance Mode", "Disables 3D viewport rendering for ultra-low power overnight farming.", Config.GPUSaverEnabled, function(val)
                Config.GPUSaverEnabled = val
                Utility.SetGPUSaver(val)
            end)
        end

        -- =====================================================================
        -- 5. SETTINGS & UTILITIES TAB
        -- =====================================================================
        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings", "🛠️")

            -- Appearance & Sound
            SettingsTab:AddSection("APPEARANCE & SOUND", "🎨")
            local themeOptions = {"Midnight Violet", "Emerald Cyber", "Sapphire Ocean", "Sunset Amber", "Obsidian Carbon"}
            local themeMap = {
                ["Midnight Violet"] = "Violet",
                ["Emerald Cyber"] = "Emerald",
                ["Sapphire Ocean"] = "Sapphire",
                ["Sunset Amber"] = "Amber",
                ["Obsidian Carbon"] = "Carbon"
            }
            local currentDisplayTheme = "Midnight Violet"
            for disp, internal in pairs(themeMap) do
                if internal == Config.Theme then currentDisplayTheme = disp; break end
            end

            SettingsTab:AddDropdown("Theme Preset", "Switch between glassmorphic dark theme color palettes.", themeOptions, currentDisplayTheme, function(selected)
                local themeKey = themeMap[selected] or "Violet"
                Config.Theme = themeKey
                Window:SetTheme(themeKey)
                Window:Notify({Title = "Theme Applied", Content = "Switched to " .. selected .. ".", Type = "Success", Duration = 2.5})
            end)

            SettingsTab:AddToggle("UI Sound Effects", "Subtle audio clicks and feedback on toggles and tabs.", Config.UISoundEnabled, function(val)
                Config.UISoundEnabled = val
            end)

            -- Keybinds
            SettingsTab:AddSection("KEYBOARD SHORTCUTS", "⌨️")
            SettingsTab:AddKeybind("Toggle Menu Key", "Keyboard shortcut to show/hide this interface.", Config.MenuKey, function(key)
                Config.MenuKey = key
                Window:Notify({Title = "Keybind Updated", Content = "Menu key set to " .. (key and key.Name or "None") .. ".", Type = "Info", Duration = 2})
            end)
            SettingsTab:AddKeybind("Toggle No-Clip", "Shortcut to toggle walking through walls and furniture.", Config.ToggleNoClipKey, function(key)
                Config.ToggleNoClipKey = key
            end)
            SettingsTab:AddKeybind("Toggle Speed Hack", "Shortcut to toggle sprint speed override.", Config.ToggleSpeedKey, function(key)
                Config.ToggleSpeedKey = key
            end)
            SettingsTab:AddKeybind("Toggle Jump Hack", "Shortcut to toggle jump launch override.", Config.ToggleJumpKey, function(key)
                Config.ToggleJumpKey = key
            end)
            SettingsTab:AddKeybind("Toggle Infinite Jump", "Shortcut to toggle infinite mid-air jumps.", Config.ToggleInfJumpKey, function(key)
                Config.ToggleInfJumpKey = key
            end)

            -- Profile Configuration
            SettingsTab:AddSection("CONFIGURATION PROFILES", "💾")
            SettingsTab:AddButton("Save Configuration Profile", "Saves all current toggle and slider settings to disk.", "Primary", function()
                if Core.Config.Save then
                    local ok = Core.Config:Save()
                    Window:Notify({
                        Title = ok and "Config Saved" or "Save Failed",
                        Content = ok and "Settings saved to Restaurant_Config.json." or "Could not write config file.",
                        Type = ok and "Success" or "Error",
                        Duration = 3
                    })
                end
            end)
            SettingsTab:AddButton("Load Configuration Profile", "Restores previously saved settings from disk.", "Secondary", function()
                if Core.Config.Load then
                    local ok = Core.Config:Load()
                    Window:Notify({
                        Title = ok and "Config Loaded" or "Load Failed",
                        Content = ok and "Restored saved configuration settings." or "No saved config file found.",
                        Type = ok and "Success" or "Error",
                        Duration = 3
                    })
                end
            end)

            -- Promo Code Redeemer
            SettingsTab:AddSection("PROMOTIONAL CODES", "🎟️")
            SettingsTab:AddButton("🎟️ Redeem Active Promo Codes", "Submits active event codes (FISHIES, RAR4EVER) for free exclusive items.", "Secondary", function()
                local count = Utility.RedeemKnownCodes()
                Window:Notify({
                    Title = "Codes Submitted",
                    Content = (count and count > 0) and string.format("Redeemed %d active codes!", count) or "Promo codes submitted to server.",
                    Type = "Success",
                    Duration = 3
                })
            end)

            -- Complete Unload
            SettingsTab:AddSection("UNLOAD SCRIPT", "🔴")
            SettingsTab:AddButton("🔴 Unload & Terminate Script Cleanly", "Disconnects all listeners, restores character physics, and destroys GUI.", "Danger", function()
                Window:Notify({Title = "Terminating...", Content = "Restoring player character and unloading.", Type = "Warning", Duration = 2})
                task.wait(0.5)
                Utility.Terminate()
            end)
        end
    end

    return UI
end

end)()(Core)
Core.UI.Init()
Core.UI.BuildDashboardTab()
Core.UI.BuildRestaurantTab()
Core.UI.BuildBuildTab()
Core.UI.BuildAutomationTab()

-- 4. Load Automation & Movement Modules
Core.Restaurant = (function()
return function(Core)
    local Restaurant = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services
    local LocalPlayer = Services.Players.LocalPlayer
    local State = Core.State

    -- Plot & Anchor references
    local cachedPlot = nil
    local lastPlotSearch = 0
    local lastMemoryClean = os.clock()
    local lastQuestCheck = 0
    Restaurant.RestaurantCenter = nil

    -- Per-prompt cooldown tracker
    local promptCooldowns = setmetatable({}, {__mode = "k"})
    -- Unaffordable prompt backoff tracker (prevents spamming unaffordable land/items)
    local unaffordableBackoff = setmetatable({}, {__mode = "k"})

    local function isPromptReady(prompt)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end
        if State.InteractionBlockedUntil and os.clock() < State.InteractionBlockedUntil then return false end
        local exp = promptCooldowns[prompt]
        if exp and os.clock() < exp then return false end
        return true
    end

    local function isPromptAffordable(prompt)
        if not prompt or not prompt.Parent then return false end
        local backoff = unaffordableBackoff[prompt]
        if backoff and os.clock() < backoff then return false end

        local price = Utility.ParsePrice(nil, prompt)
        if price and price > 0 then
            local canAfford, needed = Utility.CanAfford(price)
            if not canAfford then
                unaffordableBackoff[prompt] = os.clock() + (Config.AffordabilityBackoff or 30)
                return false
            end
        end
        return true
    end

    local function setPromptCooldown(prompt, duration)
        if prompt then
            promptCooldowns[prompt] = os.clock() + (duration or 2.5)
        end
    end

    -- =========================================================================
    -- HAND INVENTORY & CARRIED ITEMS DETECTOR
    -- =========================================================================
    function Restaurant.GetHoldingState()
        local char = LocalPlayer and LocalPlayer.Character
        if not char then return "None", 0, false end

        local now = os.clock()
        local handsFullFromNotification = (State.HandsFull and now < (State.HandsFullUntil or 0))
        if not handsFullFromNotification then
            State.HandsFull = false
        end

        local holdingType = "None"
        local count = 0

        -- 1. Inspect Character children (Equipped Tools, welded models, or plates)
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") or child:IsA("Model") or child:IsA("BasePart") then
                local name = child.Name:lower()
                local isBodyPart = (name == "humanoidrootpart" or name == "head" or name:find("torso") or name:find("arm") or name:find("leg") or name:find("hand") or name:find("foot") or name:find("accessory") or name:find("hair"))
                if not isBodyPart then
                    if name:find("dirty") or name:find("dish") or name:find("plate") or name:find("bowl") or name:find("cup") or name:find("trash") or name:find("tray") then
                        if not name:find("food") and not name:find("burger") and not name:find("meal") and not name:find("cooked") and not name:find("pizza") then
                            holdingType = "DirtyDishes"
                            count = count + 1
                        end
                    elseif name:find("food") or name:find("meal") or name:find("burger") or name:find("pizza") or name:find("steak") or name:find("pasta") or name:find("sushi") or name:find("drink") or name:find("cooked") then
                        holdingType = "Food"
                        count = count + 1
                    end
                end
            end
        end

        -- 2. Inspect Player & Character Attributes (standard pattern in restaurant engines)
        local attrHolding = char:GetAttribute("Holding") or char:GetAttribute("Carrying") or (LocalPlayer and (LocalPlayer:GetAttribute("Holding") or LocalPlayer:GetAttribute("Carrying")))
        if attrHolding and type(attrHolding) == "string" then
            local lower = attrHolding:lower()
            if lower:find("dirty") or lower:find("dish") or lower:find("plate") then
                holdingType = "DirtyDishes"
                count = math.max(count, 1)
            elseif lower:find("food") or lower:find("meal") or lower:find("cook") then
                holdingType = "Food"
                count = math.max(count, 1)
            end
        end

        local dishCountAttr = char:GetAttribute("Dishes") or char:GetAttribute("DishCount")
        if dishCountAttr and type(dishCountAttr) == "number" and dishCountAttr > 0 then
            count = math.max(count, dishCountAttr)
            if holdingType == "None" then holdingType = "DirtyDishes" end
        end

        -- 3. If notification marked hands full, inherit from recent action context
        if handsFullFromNotification and holdingType == "None" then
            if State.HoldingType and State.HoldingType ~= "None" then
                holdingType = State.HoldingType
            elseif State.LastActionType == "Clean" then
                holdingType = "DirtyDishes"
            elseif State.LastActionType == "Serve" or State.LastActionType == "Cook" then
                holdingType = "Food"
            else
                holdingType = "DirtyDishes"
            end
            count = math.max(count, 1)
        end

        State.HoldingType = holdingType
        State.HoldingCount = count
        local isFull = handsFullFromNotification or (count >= (Config.HandCapacity or 1))

        return holdingType, count, isFull
    end

    -- =========================================================================
    -- REACTIVE GAME NOTIFICATION & TOAST INTERCEPTOR
    -- =========================================================================
    local listenerHooked = false
    function Restaurant.SetupGameNotificationListener()
        if listenerHooked then return end
        listenerHooked = true

        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        local function checkMessage(text)
            if not text or type(text) ~= "string" or #text < 3 then return end
            local lower = text:lower()

            -- 1. Hands Full Alert ("your hands are full rn")
            if lower:find("hands are full") or lower:find("hand is full") or lower:find("carrying too much") or lower:find("cannot carry") or lower:find("inventory full") then
                State.HandsFull = true
                State.HandsFullUntil = os.clock() + 7.5
                if State.LastActionType == "Clean" or State.HoldingType == "DirtyDishes" then
                    State.HoldingType = "DirtyDishes"
                elseif State.LastActionType == "Serve" or State.LastActionType == "Cook" then
                    State.HoldingType = "Food"
                end
                if State.ActivePrompt then
                    setPromptCooldown(State.ActivePrompt, 4.5)
                end

            -- 2. Sinks Full Alert ("sinks are full buy more in shop")
            elseif lower:find("sink") and (lower:find("full") or lower:find("shop") or lower:find("buy")) then
                State.SinksFull = true
                State.SinksFullUntil = os.clock() + 10.0
                if State.ActivePrompt then
                    setPromptCooldown(State.ActivePrompt, 5.0)
                end
                -- Attempt automatic purchase of sink if appliance auto-buy is enabled
                if Config.AutoBuyAppliances or Config.AutoBuyEnabled then
                    task.spawn(function()
                        pcall(Restaurant.HandleAutoBuy)
                    end)
                end

            -- 3. You can't do that right now ("you cant do that rn" / "already in use" / "busy")
            elseif lower:find("cant do that") or lower:find("can't do that") or lower:find("cannot do that") or lower:find("not right now") or lower:find("already in use") or lower:find("station in use") or lower:find("station busy") or lower:find("someone is using") then
                if State.ActivePrompt then
                    setPromptCooldown(State.ActivePrompt, 4.0)
                end
                State.InteractionBlockedUntil = os.clock() + 0.5

            -- 4. Not enough money / Cannot afford
            elseif lower:find("not enough money") or lower:find("cannot afford") or lower:find("need more cash") then
                if State.ActivePrompt then
                    unaffordableBackoff[State.ActivePrompt] = os.clock() + (Config.AffordabilityBackoff or 30)
                end
            end
        end

        -- Observe all newly created toast/hint labels in PlayerGui
        Utility.RegisterConnection(pg.DescendantAdded:Connect(function(desc)
            if desc:IsA("TextLabel") or desc:IsA("TextBox") then
                checkMessage(desc.Text)
                Utility.RegisterConnection(desc:GetPropertyChangedSignal("Text"):Connect(function()
                    checkMessage(desc.Text)
                end))
            end
        end))

        -- Inspect all currently existing labels in PlayerGui
        for _, desc in ipairs(pg:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextBox") then
                checkMessage(desc.Text)
                Utility.RegisterConnection(desc:GetPropertyChangedSignal("Text"):Connect(function()
                    checkMessage(desc.Text)
                end))
            end
        end
    end

    -- Periodic memory cleanup
    local function cleanExpiredCooldowns()
        local now = os.clock()
        if now - lastMemoryClean > 300 then
            lastMemoryClean = now
            for p, exp in pairs(promptCooldowns) do
                if now >= exp or not p or not p.Parent then
                    promptCooldowns[p] = nil
                end
            end
            for p, exp in pairs(unaffordableBackoff) do
                if now >= exp or not p or not p.Parent then
                    unaffordableBackoff[p] = nil
                end
            end
        end
    end

    -- Safe character resolver
    local function getAliveCharacter()
        local char = LocalPlayer and LocalPlayer.Character
        if not char then return nil, nil, nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return nil, nil, nil end
        return char, root, hum
    end

    -- Safely unseat character without breaking physics
    local function releaseSeat(hum, char)
        if not hum then return end
        if hum.Sit then
            hum.Sit = false
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, child in ipairs(root:GetChildren()) do
                        if child:IsA("Weld") and child.Name == "SeatWeld" then
                            pcall(function() child:Destroy() end)
                        end
                    end
                end
            end
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(0.05)
        end
    end

    -- Extract target world position safely
    local function getTargetPosition(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then
            return inst.Position
        elseif inst:IsA("Model") then
            if inst.PrimaryPart then return inst.PrimaryPart.Position end
            return inst:GetPivot().Position
        elseif inst:IsA("ProximityPrompt") then
            local p = inst.Parent
            if p and p:IsA("BasePart") then
                return p.Position
            elseif p and p:IsA("Model") then
                return p:GetPivot().Position
            elseif p and p.Parent and p.Parent:IsA("BasePart") then
                return p.Parent.Position
            end
        end
        return nil
    end

    -- Recalibrate the center of the restaurant to current avatar position
    function Restaurant.RecalibrateAnchor()
        local _, root = getAliveCharacter()
        if root then
            Restaurant.RestaurantCenter = root.Position
            cachedPlot = nil
            return true
        end
        return false
    end

    -- Locate player's designated restaurant / farm plot
    function Restaurant.GetPlayerPlot()
        if not Config.PlotScopingEnabled then return workspace end
        local now = os.clock()
        if cachedPlot and cachedPlot.Parent and (now - lastPlotSearch < 15) then
            return cachedPlot
        end
        lastPlotSearch = now

        local playerName = LocalPlayer.Name:lower()
        local displayName = LocalPlayer.DisplayName:lower()
        local userId = tostring(LocalPlayer.UserId)

        -- 1. Direct LocalPlayer plot references
        local plotVal = LocalPlayer:FindFirstChild("Plot") or LocalPlayer:FindFirstChild("Restaurant") or LocalPlayer:FindFirstChild("Tycoon")
        if plotVal and plotVal:IsA("ObjectValue") and plotVal.Value then
            cachedPlot = plotVal.Value
            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
            return cachedPlot
        end
        local plotAttr = LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("Restaurant")
        if typeof(plotAttr) == "Instance" then
            cachedPlot = plotAttr
            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
            return cachedPlot
        end

        -- 2. Search common plot containers in workspace
        local map = workspace:FindFirstChild("Map")
        local searchContainers = {
            workspace:FindFirstChild("Plots"),
            workspace:FindFirstChild("Restaurants"),
            workspace:FindFirstChild("PlayerRestaurants"),
            workspace:FindFirstChild("PlayerPlots"),
            workspace:FindFirstChild("Tycoons"),
            workspace:FindFirstChild("Farms"),
            map and map:FindFirstChild("Plots"),
            map and map:FindFirstChild("Restaurants"),
        }

        for _, container in ipairs(searchContainers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Model") or item:IsA("Folder") then
                        -- Check Owner value or attribute
                        local ownerObj = item:FindFirstChild("Owner") or item:FindFirstChild("Player") or item:FindFirstChild("OwnerId")
                        if ownerObj then
                            local val = tostring(ownerObj.Value):lower()
                            if val == playerName or val == userId or val == displayName then
                                cachedPlot = item
                                Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                                return item
                            end
                        end
                        if item:GetAttribute("Owner") == LocalPlayer.UserId or tostring(item:GetAttribute("Owner")):lower() == playerName then
                            cachedPlot = item
                            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                            return item
                        end

                        -- Check item name
                        local itemName = item.Name:lower()
                        if itemName:find(playerName, 1, true) or itemName:find(userId, 1, true) then
                            cachedPlot = item
                            Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                            return item
                        end

                        -- Check billboard text
                        for _, desc in ipairs(item:GetDescendants()) do
                            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                local txt = (desc.Text or ""):lower()
                                if (txt:find(playerName, 1, true) or txt:find(displayName, 1, true)) and 
                                   (txt:find("restaurant", 1, true) or txt:find("plot", 1, true) or txt:find("farm", 1, true)) then
                                    cachedPlot = item
                                    Restaurant.RestaurantCenter = getTargetPosition(cachedPlot)
                                    return item
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 3. Fallback: Find closest plot model to player or anchor to player position
        local _, root = getAliveCharacter()
        if root then
            if not Restaurant.RestaurantCenter then
                Restaurant.RestaurantCenter = root.Position
            end
        end

        return cachedPlot or workspace
    end

    -- Teleport player safely to a target workstation (Zero-NaN safe)
    function Restaurant.TeleportTo(targetInstance)
        local char, root, hum = getAliveCharacter()
        if not char or not root or not hum then return false end

        local targetPos = getTargetPosition(targetInstance)
        if not targetPos then return false end

        -- Prevent accidental sitting in customer chairs
        if Config.PreventSitting and hum.Sit then
            releaseSeat(hum, char)
        end

        -- Stand offset from workstation part (2.5 studs back)
        local standOffset = Vector3.new(0, 0, 2.5)
        if targetInstance:IsA("BasePart") then
            standOffset = targetInstance.CFrame.LookVector * 2.5
        elseif targetInstance:IsA("ProximityPrompt") and targetInstance.Parent and targetInstance.Parent:IsA("BasePart") then
            standOffset = targetInstance.Parent.CFrame.LookVector * 2.5
        end
        if standOffset.Magnitude < 0.5 then
            standOffset = Vector3.new(0, 0, 2.5)
        end

        local standPos = targetPos + Vector3.new(standOffset.X, 0, standOffset.Z)
        local safePos = Utility.GetGroundPosition(standPos, {char})

        -- Orient avatar toward the target position safely (Prevents NaN flings)
        local lookPos = Vector3.new(targetPos.X, safePos.Y, targetPos.Z)
        local targetCFrame
        if (lookPos - safePos).Magnitude > 0.5 then
            targetCFrame = CFrame.lookAt(safePos, lookPos)
        else
            targetCFrame = CFrame.new(safePos)
        end

        root.CFrame = targetCFrame

        -- Zero out velocity to prevent flinging
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        return true
    end

    -- Trigger a ProximityPrompt safely
    local function triggerPrompt(prompt, debounceTime, actionType)
        if not prompt or not prompt.Parent or not prompt.Enabled then return false end

        State.ActivePrompt = prompt
        State.LastActionType = actionType
        setPromptCooldown(prompt, debounceTime or 2.5)

        if Config.InstantPromptEnabled then
            pcall(function()
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance or 10, 24)
            end)
        end

        local holdTime = prompt.HoldDuration or 0

        -- 1. Try executor native fireproximityprompt
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function()
                fireproximityprompt(prompt)
            end)
            if not ok then
                pcall(function()
                    fireproximityprompt(prompt, 1)
                end)
            end
            if holdTime > 0 and not Config.InstantPromptEnabled then
                task.wait(holdTime + 0.05)
            else
                task.wait(0.08)
            end
            return true
        end

        -- 2. Fallback input simulation with safe duration to avoid server rejection
        local simulatedHold = holdTime
        if Config.InstantPromptEnabled and holdTime > 0 then
            simulatedHold = math.min(holdTime, 0.28)
        end

        pcall(function()
            if prompt.InputHoldBegin then
                prompt:InputHoldBegin()
                if simulatedHold > 0 then
                    task.wait(simulatedHold)
                else
                    task.wait(0.05)
                end
                if prompt.InputHoldEnd then
                    prompt:InputHoldEnd()
                end
            end
        end)
        return true
    end

    -- Single-pass prompt aggregator (High-speed, zero-lag, no full workspace spam)
    function Restaurant.ScanPrompts()
        local container = Restaurant.GetPlayerPlot()
        local _, root = getAliveCharacter()
        local center = Restaurant.RestaurantCenter or (root and root.Position)
        local maxDist = Config.MaxScanRadius or 120

        local categorized = {
            Cash = {},
            Order = {},
            Cook = {},
            Serve = {},
            Clean = {},
            Sink = {},
            Seat = {},
            Delivery = {},
            Restock = {},
            Farm = {},
            Expand = {},
            Buy = {},
            Place = {},
            Quest = {},
        }

        local searchList = {}
        if container and container ~= workspace then
            searchList = container:GetDescendants()
        else
            -- Proximity scoped: Only search models within maxDist to prevent scanning 50,000 objects
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model") or obj:IsA("Folder") then
                    local pos = getTargetPosition(obj)
                    if not center or not pos or (pos - center).Magnitude <= (maxDist + 35) then
                        for _, d in ipairs(obj:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then
                                table.insert(searchList, d)
                            end
                        end
                    end
                elseif obj:IsA("ProximityPrompt") then
                    table.insert(searchList, obj)
                end
            end
        end

        for _, obj in ipairs(searchList) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and isPromptReady(obj) then
                local pos = getTargetPosition(obj)
                if not center or not pos or (pos - center).Magnitude <= maxDist then
                    local act = (obj.ActionText or ""):lower()
                    local objTxt = (obj.ObjectText or obj.Name or (obj.Parent and obj.Parent.Name or "")):lower()
                    local combined = act .. " " .. objTxt

                    -- 1. Cash, Tips & Free Reward Chests
                    if combined:find("tip") or combined:find("cash") or combined:find("register") or combined:find("collect") or combined:find("money") or combined:find("gift") or combined:find("reward") or combined:find("chest") then
                        table.insert(categorized.Cash, obj)

                    -- 2. Customer Orders
                    elseif (combined:find("order") or combined:find("menu") or combined:find("ticket") or combined:find("take order")) and not combined:find("delivery") then
                        table.insert(categorized.Order, obj)

                    -- 3. Cook Food
                    elseif combined:find("cook") or combined:find("prepare") or combined:find("bake") or combined:find("grill") or combined:find("stove") or combined:find("oven") then
                        table.insert(categorized.Cook, obj)

                    -- 4. Serve Prepared Dishes
                    elseif combined:find("serve") or combined:find("bring") or combined:find("plate") or (combined:find("dish") and not (combined:find("sink") or combined:find("wash") or combined:find("clean") or combined:find("dirty"))) then
                        table.insert(categorized.Serve, obj)

                    -- 5A. Sinks, Dishwashers & Washing Stations (Separated from dining tables)
                    elseif combined:find("sink") or combined:find("dishwasher") or combined:find("dish washer") or combined:find("rinse") or combined:find("scrub") or combined:find("clean dish") or combined:find("deposit dish") or combined:find("empty sink") or (combined:find("wash") and not combined:find("hand")) then
                        table.insert(categorized.Sink, obj)

                    -- 5B. Clean Dirty Dining Tables (Bussing Tables)
                    elseif (combined:find("clean") or combined:find("wipe") or combined:find("dirty") or combined:find("bus") or combined:find("trash") or combined:find("clear")) and not (combined:find("sink") or combined:find("wash") or combined:find("dishwasher")) then
                        table.insert(categorized.Clean, obj)

                    -- 6. Add / Place Furniture, Chairs & Tables (BEFORE Customer Seating)
                    elseif combined:find("place") or combined:find("build") or combined:find("assemble") or combined:find("put down") or
                           combined:find("add table") or combined:find("add chair") or combined:find("add seat") or combined:find("add furniture") or
                           combined:find("new table") or combined:find("new chair") or combined:find("new seat") or
                           (combined:find("add") and (combined:find("table") or combined:find("chair") or combined:find("furniture") or combined:find("seat"))) then
                        table.insert(categorized.Place, obj)

                    -- 7. Customer Seating (Host / Welcome)
                    elseif combined:find("seat") or combined:find("host") or combined:find("welcome") or combined:find("customer") or combined:find("guest") or combined:find("party") then
                        table.insert(categorized.Seat, obj)

                    -- 8. Delivery Orders
                    elseif combined:find("package") or combined:find("box") or combined:find("scooter") or combined:find("takeout") or combined:find("delivery") then
                        table.insert(categorized.Delivery, obj)

                    -- 9. Restock Storage
                    elseif combined:find("restock") or combined:find("deposit") or combined:find("fridge") or combined:find("cooler") or combined:find("pantry") then
                        table.insert(categorized.Restock, obj)

                    -- 10. Farm Harvest
                    elseif combined:find("harvest") or combined:find("crop") or combined:find("wheat") or combined:find("plant") or combined:find("gather") or combined:find("pick") then
                        table.insert(categorized.Farm, obj)

                    -- 11. Buy Furniture & Equipment
                    elseif (combined:find("buy") or combined:find("purchase")) and not combined:find("floor") and not combined:find("expand") then
                        if isPromptAffordable(obj) then
                            table.insert(categorized.Buy, obj)
                        end

                    -- 12. Expand Land & Floors
                    elseif combined:find("expand") or combined:find("unlock") or (combined:find("floor") and (combined:find("buy") or combined:find("unlock") or combined:find("purchase"))) then
                        if isPromptAffordable(obj) then
                            table.insert(categorized.Expand, obj)
                        end

                    -- 13. Quest NPCs, Quest Boards, Bounty Givers & Turn-Ins
                    elseif combined:find("quest") or combined:find("mission") or combined:find("bounty") or combined:find("board") or combined:find("contract") or (combined:find("talk") and not combined:find("seat")) then
                        table.insert(categorized.Quest, obj)
                    end
                end
            end
        end

        -- VIP Customer Priority: Sort VIP patrons to front of queue
        if Config.VIPPriorityEnabled then
            local function sortVip(list)
                if #list > 1 then
                    table.sort(list, function(a, b)
                        local aTxt = ((a.ObjectText or "") .. " " .. (a.Parent and a.Parent.Name or "")):lower()
                        local bTxt = ((b.ObjectText or "") .. " " .. (b.Parent and b.Parent.Name or "")):lower()
                        local aVip = aTxt:find("vip") or aTxt:find("gold") or aTxt:find("celebrity") or aTxt:find("star") or aTxt:find("rich")
                        local bVip = bTxt:find("vip") or bTxt:find("gold") or bTxt:find("celebrity") or bTxt:find("star") or bTxt:find("rich")
                        if aVip and not bVip then return true end
                        return false
                    end)
                end
            end
            sortVip(categorized.Seat)
            sortVip(categorized.Order)
        end

        return categorized
    end

    -- Spatial clustering: Find ready prompts in the same category within radius studs
    function Restaurant.GetNearbyCluster(primaryPrompt, promptsList, radius, maxCount)
        local cluster = {}
        if not primaryPrompt or not promptsList then return cluster end
        local primaryPos = getTargetPosition(primaryPrompt)
        if not primaryPos then return cluster end

        radius = radius or 14
        maxCount = maxCount or (Config.StationBatchSize or 3)

        for _, prompt in ipairs(promptsList) do
            if prompt ~= primaryPrompt and isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                local pos = getTargetPosition(prompt)
                if pos and (pos - primaryPos).Magnitude <= radius then
                    table.insert(cluster, prompt)
                    if #cluster >= (maxCount - 1) then
                        break
                    end
                end
            end
        end
        return cluster
    end

    -- Trigger nearby prompts across ANY enabled category opportunistically (same room/station)
    function Restaurant.TriggerOpportunisticNearby(centerPos, allPrompts, radius)
        if not Config.RemotePromptBatching or not centerPos or not allPrompts then return 0 end
        if State.InteractionBlockedUntil and os.clock() < State.InteractionBlockedUntil then return 0 end
        radius = radius or 14
        local triggeredCount = 0
        local isMaster = Config.MasterAutoFarmEnabled

        local categoryConfigs = {
            Cash = { enabled = isMaster or Config.AutoCollectCashEnabled, stat = "CashCollected", cooldown = 3.0 },
            Order = { enabled = isMaster or Config.AutoOrderEnabled, stat = "OrdersTaken", cooldown = 2.5 },
            Cook = { enabled = isMaster or Config.AutoCookEnabled, stat = "DishesCooked", cooldown = 2.5 },
            Serve = { enabled = isMaster or Config.AutoServeEnabled, stat = "DishesServed", cooldown = 2.5 },
            Clean = { enabled = isMaster or Config.AutoCleanEnabled, stat = "TablesCleaned", cooldown = 3.0 },
            Sink = { enabled = isMaster or Config.AutoWashSinksEnabled, stat = "DishesWashed", cooldown = 2.5 },
            Seat = { enabled = isMaster or Config.AutoSeatEnabled, stat = "CustomersSeated", cooldown = 3.0 },
            Delivery = { enabled = isMaster or Config.AutoDeliveryEnabled, stat = "DeliveriesCompleted", cooldown = 4.0 },
            Restock = { enabled = isMaster or Config.AutoRestockEnabled, stat = "StorageRestocked", cooldown = 3.5 },
            Farm = { enabled = isMaster or Config.AutoFarmEnabled, stat = "CropsHarvested", cooldown = 3.0 },
        }

        for catName, catInfo in pairs(categoryConfigs) do
            if catInfo.enabled and allPrompts[catName] then
                for _, prompt in ipairs(allPrompts[catName]) do
                    if isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                        local pos = getTargetPosition(prompt)
                        if pos and (pos - centerPos).Magnitude <= radius then
                            State.InFlightTasks[prompt] = true
                            pcall(function()
                                triggerPrompt(prompt, catInfo.cooldown, catName)
                                task.wait(0.18)
                                if prompt and prompt.Parent and not prompt.Enabled then
                                    if State.Stats[catInfo.stat] ~= nil then
                                        State.Stats[catInfo.stat] = State.Stats[catInfo.stat] + 1
                                    end
                                end
                            end)
                            State.InFlightTasks[prompt] = nil
                            triggeredCount = triggeredCount + 1
                            if triggeredCount >= 1 then break end
                        end
                    end
                end
            end
            if triggeredCount >= 1 then break end
        end
        return triggeredCount
    end

    -- Wait until the active prompt/task is confirmed done before allowing subsequent tasks
    local function waitForTaskCompletion(prompt, maxTimeout)
        if not prompt then return true end
        local timeout = maxTimeout or 1.6
        local hold = prompt.HoldDuration or 0
        if hold > 0 and not Config.InstantPromptEnabled then
            timeout = math.max(timeout, hold + 0.4)
        end

        local start = os.clock()
        local completed = false
        while (os.clock() - start) < timeout do
            -- 1. Prompt or parent was destroyed (e.g., dirty dishes cleaned, meal picked up, customer seated)
            if not prompt or not prompt.Parent then
                completed = true
                break
            end
            -- 2. Prompt disabled by game logic (e.g., stove began cooking, customer order accepted)
            if not prompt.Enabled then
                completed = true
                break
            end
            -- 3. Check if server reported blocked action
            if State.InteractionBlockedUntil and os.clock() < State.InteractionBlockedUntil then
                completed = false
                break
            end
            task.wait(0.04)
        end

        if not completed and prompt and prompt.Parent and prompt.Enabled then
            -- Interaction failed or rejected on server -> apply cooldown to prevent spamming
            setPromptCooldown(prompt, 3.5)
        else
            completed = true
        end

        State.ActivePrompt = nil

        -- Post-action settling delay to guarantee server replication before moving avatar
        local settle = math.clamp(Config.PostActionDelay or 0.18, 0.05, 1.0)
        task.wait(settle)
        return completed
    end

    -- Execute a single action cleanly with strict task completion and mutex safety
    local function executeAction(prompt, cooldown, statKey, actionType)
        if not prompt or not prompt.Parent then return false end
        if State.InFlightTasks[prompt] then return false end
        if State.InteractionBlockedUntil and os.clock() < State.InteractionBlockedUntil then return false end

        State.InFlightTasks[prompt] = true
        State.ActivePrompt = prompt
        State.LastActionType = actionType

        local success = false
        pcall(function()
            -- 1. Teleport safely if enabled
            if Config.AutoTeleportEnabled then
                local ok = Restaurant.TeleportTo(prompt)
                if ok then
                    task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
                end
            end

            -- 2. Trigger prompt
            triggerPrompt(prompt, cooldown or 2.5, actionType)

            -- 3. STRICT TASK COMPLETION: Wait until task finishes before proceeding
            local ok = true
            if Config.StrictTaskCompletion then
                ok = waitForTaskCompletion(prompt, 1.6)
            else
                task.wait(0.08)
                State.ActivePrompt = nil
            end

            -- 4. Increment statistics only if action succeeded
            if ok and statKey and State.Stats[statKey] ~= nil then
                State.Stats[statKey] = State.Stats[statKey] + 1
            end

            -- 5. Refresh holding state
            Restaurant.GetHoldingState()

            success = ok
        end)

        State.InFlightTasks[prompt] = nil
        State.ActivePrompt = nil
        return success
    end

    -- Execute a workstation cluster cleanly with sequential completion at the station
    local function executeCluster(primaryPrompt, cluster, cooldown, statKey, allPrompts, actionType)
        if not primaryPrompt or not primaryPrompt.Parent then return false end
        if State.InFlightTasks[primaryPrompt] then return false end
        if State.InteractionBlockedUntil and os.clock() < State.InteractionBlockedUntil then return false end

        State.InFlightTasks[primaryPrompt] = true
        State.ActivePrompt = primaryPrompt
        State.LastActionType = actionType

        for _, p in ipairs(cluster) do
            State.InFlightTasks[p] = true
        end

        local success = false
        pcall(function()
            -- 1. Teleport safely to primary prompt once
            if Config.AutoTeleportEnabled then
                local ok = Restaurant.TeleportTo(primaryPrompt)
                if ok then
                    task.wait(math.clamp(Config.StationStayDelay or 0.22, 0.08, 1))
                end
            end

            -- 2. Trigger primary prompt and ensure it is completed
            triggerPrompt(primaryPrompt, cooldown or 2.5, actionType)
            local ok = true
            if Config.StrictTaskCompletion then
                ok = waitForTaskCompletion(primaryPrompt, 1.6)
            else
                task.wait(0.08)
                State.ActivePrompt = nil
            end
            if ok and statKey and State.Stats[statKey] ~= nil then
                State.Stats[statKey] = State.Stats[statKey] + 1
            end
            State.InFlightTasks[primaryPrompt] = nil

            -- 3. Complete each cluster prompt sequentially while standing at the station
            for _, prompt in ipairs(cluster) do
                if prompt and prompt.Parent and prompt.Enabled and isPromptReady(prompt) then
                    -- Verify holding state: stop picking up more if hands full!
                    local _, _, handsFull = Restaurant.GetHoldingState()
                    if handsFull and (actionType == "Clean" or actionType == "Serve") then
                        break
                    end

                    triggerPrompt(prompt, cooldown or 2.5, actionType)
                    local cOk = true
                    if Config.StrictTaskCompletion then
                        cOk = waitForTaskCompletion(prompt, 1.6)
                    else
                        task.wait(0.08)
                        State.ActivePrompt = nil
                    end
                    if cOk and statKey and State.Stats[statKey] ~= nil then
                        State.Stats[statKey] = State.Stats[statKey] + 1
                    end
                end
                State.InFlightTasks[prompt] = nil
            end

            -- 4. Opportunistic cross-category batching for ready prompts within 14 studs
            local primaryPos = getTargetPosition(primaryPrompt)
            if primaryPos and allPrompts and Config.RemotePromptBatching then
                Restaurant.TriggerOpportunisticNearby(primaryPos, allPrompts, 14)
            end

            Restaurant.GetHoldingState()
            success = true
        end)

        State.InFlightTasks[primaryPrompt] = nil
        State.ActivePrompt = nil
        for _, p in ipairs(cluster) do
            State.InFlightTasks[p] = nil
        end
        return success
    end

    -- Sweep dropped physical coins/cash parts remotely without teleport flinging
    function Restaurant.SweepFloorCash()
        local char, root = getAliveCharacter()
        if not root then return end

        local hasFireTouch = (type(firetouchinterest) == "function")
        local center = Restaurant.RestaurantCenter or root.Position
        local maxDist = Config.MaxScanRadius or 120

        local container = Restaurant.GetPlayerPlot()
        local searchParts = (container and container ~= workspace) and container:GetDescendants() or workspace:GetChildren()

        local count = 0
        for _, item in ipairs(searchParts) do
            if item:IsA("BasePart") and not item.Anchored and item.Parent ~= char then
                local name = item.Name:lower()
                if (name:find("coin") or name:find("cash") or name:find("money") or name:find("tip")) then
                    if (item.Position - center).Magnitude <= maxDist then
                        if hasFireTouch then
                            pcall(function()
                                firetouchinterest(root, item, 0)
                                task.wait()
                                firetouchinterest(root, item, 1)
                            end)
                            count = count + 1
                            if count >= 12 then break end
                        end
                    end
                end
            end
        end
        if count > 0 then
            State.Stats.CashCollected = State.Stats.CashCollected + count
        end
    end

    -- Individual handlers for manual button triggering
    function Restaurant.HandleCashCollection()
        local p = Restaurant.ScanPrompts()
        if #p.Cash > 0 then
            local primary = p.Cash[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Cash, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CashCollected", p)
        end
        Restaurant.SweepFloorCash()
    end
    function Restaurant.HandleOrdering()
        local p = Restaurant.ScanPrompts()
        if #p.Order > 0 then
            local primary = p.Order[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Order, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "OrdersTaken", p)
        end
    end
    function Restaurant.HandleCooking()
        local p = Restaurant.ScanPrompts()
        if #p.Cook > 0 then
            local primary = p.Cook[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Cook, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesCooked", p)
        end
    end
    function Restaurant.HandleServing()
        local p = Restaurant.ScanPrompts()
        if #p.Serve > 0 then
            local primary = p.Serve[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Serve, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesServed", p)
        end
    end
    function Restaurant.HandleCleaning()
        local p = Restaurant.ScanPrompts()
        local holdingType, _, handsFull = Restaurant.GetHoldingState()
        local sinksFull = State.SinksFull and (os.clock() < (State.SinksFullUntil or 0))

        -- If holding dirty dishes or hands are full, route to Sink first!
        if holdingType == "DirtyDishes" or handsFull then
            if #p.Sink > 0 then
                local primary = p.Sink[1]
                executeAction(primary, 2.5, "DishesWashed", "Sink")
                return
            end
        end

        -- If sinks are full, do not pick up more dishes from tables
        if sinksFull then return end

        if #p.Clean > 0 then
            local primary = p.Clean[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Clean, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "TablesCleaned", p, "Clean")
        end
    end

    function Restaurant.HandleSinkWashing()
        local p = Restaurant.ScanPrompts()
        if #p.Sink > 0 then
            local primary = p.Sink[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Sink, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 2.5, "DishesWashed", p, "Sink")
        end
    end
    function Restaurant.HandleSeating()
        local p = Restaurant.ScanPrompts()
        if #p.Seat > 0 then
            local primary = p.Seat[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Seat, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CustomersSeated", p)
        end
    end
    function Restaurant.HandleDelivery()
        local p = Restaurant.ScanPrompts()
        if #p.Delivery > 0 then
            local primary = p.Delivery[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Delivery, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 4.0, "DeliveriesCompleted", p)
        end
    end
    function Restaurant.HandleRestock()
        local p = Restaurant.ScanPrompts()
        if #p.Restock > 0 then
            local primary = p.Restock[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Restock, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.5, "StorageRestocked", p)
        end
    end
    function Restaurant.HandleFarming()
        local p = Restaurant.ScanPrompts()
        if #p.Farm > 0 then
            local primary = p.Farm[1]
            local cluster = Restaurant.GetNearbyCluster(primary, p.Farm, 14, Config.StationBatchSize or 3)
            executeCluster(primary, cluster, 3.0, "CropsHarvested", p)
        end
    end
    function Restaurant.HandleExpansion()
        if not Config.AutoExpandEnabled then return false end
        local p = Restaurant.ScanPrompts()
        if #p.Expand == 0 then return false end

        for _, prompt in ipairs(p.Expand) do
            if isPromptReady(prompt) and not State.InFlightTasks[prompt] then
                local combined = ((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "") .. " " .. (prompt.Parent and prompt.Parent.Name or "")):lower()
                local isFloor = combined:find("floor")
                local isLand = combined:find("land") or combined:find("plot") or combined:find("expand")

                local allowed = (isFloor and Config.AutoBuyFloors) or (isLand and Config.AutoBuyLand) or (not isFloor and not isLand and (Config.AutoBuyLand or Config.AutoBuyFloors))

                if allowed then
                    local price = Utility.ParsePrice(combined, prompt)
                    local canAfford, needed = Utility.CanAfford(price)
                    if canAfford then
                        local ok = executeAction(prompt, 6.0, "ExpansionsPurchased")
                        if ok then return true end
                    else
                        unaffordableBackoff[prompt] = os.clock() + (Config.AffordabilityBackoff or 30)
                    end
                end
            end
        end
        return false
    end

    local lastBuyCheck = 0
    function Restaurant.HandleAutoBuy(targetItemName)
        local isQuestBuy = (targetItemName ~= nil and type(targetItemName) == "string" and #targetItemName > 0)
        if not isQuestBuy and not Config.AutoBuyEnabled and not Config.MasterAutoFarmEnabled then return false end
        local now = os.clock()
        if now - lastBuyCheck < 2.5 then return false end
        lastBuyCheck = now

        local targetItemLower = isQuestBuy and targetItemName:lower() or nil

        -- 1. Check in-world shop prompts
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Buy > 0 then
            for _, p in ipairs(prompts.Buy) do
                if isPromptReady(p) and not State.InFlightTasks[p] then
                    local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                    
                    local shouldBuy = false
                    if isQuestBuy and targetItemLower then
                        shouldBuy = text:find(targetItemLower, 1, true) ~= nil
                    else
                        local isStove = text:find("stove") or text:find("oven")
                        local isGrill = text:find("grill") or text:find("fryer") or text:find("smoker")
                        local isTable = text:find("table") and not text:find("chair")
                        local isChair = text:find("chair") or text:find("seat") or text:find("stool") or text:find("booth") or text:find("bench")
                        local isAppliance = text:find("sink") or text:find("dish") or text:find("fridge") or text:find("cooler") or text:find("appliance")
                        local isCounter = text:find("counter") or text:find("prep") or text:find("station")
                        local isLighting = text:find("light") or text:find("lamp") or text:find("chandelier")
                        local isFurniture = text:find("furniture") or text:find("decor") or text:find("shelf") or text:find("plant") or text:find("tree") or text:find("painting")

                        shouldBuy = (Config.AutoBuyStoves and isStove)
                                       or (Config.AutoBuyGrills and isGrill)
                                       or (Config.AutoBuyTables and isTable)
                                       or (Config.AutoBuyChairs and isChair)
                                       or (Config.AutoBuyAppliances and isAppliance)
                                       or (Config.AutoBuyCounters and isCounter)
                                       or (Config.AutoBuyLighting and isLighting)
                                       or (Config.AutoBuyFurniture and isFurniture)
                    end

                    if shouldBuy then
                        local price = Utility.ParsePrice(text, p)
                        local canAfford, needed = Utility.CanAfford(price)
                        if canAfford then
                            local ok = executeAction(p, 4.0, "ItemsPurchased")
                            if ok then
                                if isQuestBuy then
                                    State.Stats.QuestsCompleted = (State.Stats.QuestsCompleted or 0) + 1
                                end
                                return true
                            end
                        else
                            unaffordableBackoff[p] = os.clock() + (Config.AffordabilityBackoff or 30)
                        end
                    end
                end
            end
        end

        -- 2. Check Shop GUI in PlayerGui
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local gpName = (btn.Parent and btn.Parent.Parent and btn.Parent.Parent.Name or ""):lower()

                    if (bText:find("buy") or bText:find("purchase") or bName:find("buy") or bName:find("purchase")) and not bText:find("robux") then
                        local combined = (bText .. " " .. bName .. " " .. pName .. " " .. gpName):lower()
                        
                        local shouldBuy = false
                        if isQuestBuy and targetItemLower then
                            shouldBuy = combined:find(targetItemLower, 1, true) ~= nil
                        else
                            local isStove = combined:find("stove") or combined:find("oven")
                            local isGrill = combined:find("grill") or combined:find("fryer") or combined:find("smoker")
                            local isTable = combined:find("table") and not combined:find("chair")
                            local isChair = combined:find("chair") or combined:find("seat") or combined:find("stool") or combined:find("booth") or combined:find("bench")
                            local isAppliance = combined:find("sink") or combined:find("dish") or combined:find("fridge") or combined:find("cooler")
                            local isCounter = combined:find("counter") or combined:find("prep") or combined:find("station")
                            local isLighting = combined:find("light") or combined:find("lamp")
                            local isFurniture = combined:find("furniture") or combined:find("decor") or combined:find("plant") or combined:find("tree")

                            shouldBuy = (Config.AutoBuyStoves and isStove)
                                           or (Config.AutoBuyGrills and isGrill)
                                           or (Config.AutoBuyTables and isTable)
                                           or (Config.AutoBuyChairs and isChair)
                                           or (Config.AutoBuyAppliances and isAppliance)
                                           or (Config.AutoBuyCounters and isCounter)
                                           or (Config.AutoBuyLighting and isLighting)
                                           or (Config.AutoBuyFurniture and isFurniture)
                        end

                        if shouldBuy then
                            local price = Utility.ParsePrice(combined, btn)
                            local canAfford, needed = Utility.CanAfford(price)
                            if canAfford then
                                pcall(function()
                                    if type(firesignal) == "function" and btn.Activated then
                                        firesignal(btn.Activated)
                                    elseif btn.Activate then
                                        btn:Activate()
                                    end
                                end)
                                State.Stats.ItemsPurchased = (State.Stats.ItemsPurchased or 0) + 1
                                if isQuestBuy then
                                    State.Stats.QuestsCompleted = (State.Stats.QuestsCompleted or 0) + 1
                                end
                                task.wait(Config.PostActionDelay or 0.2)
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    local lastStaffCheck = 0
    function Restaurant.HandleStaffManage(targetRole)
        local isQuestHire = (targetRole ~= nil and type(targetRole) == "string" and #targetRole > 0)
        if not isQuestHire and not Config.AutoHireStaffEnabled and not Config.MasterAutoFarmEnabled then return false end
        local now = os.clock()
        if now - lastStaffCheck < 3.5 then return false end
        lastStaffCheck = now

        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return false end

        for _, btn in ipairs(pg:GetDescendants()) do
            if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                local bName = btn.Name:lower()
                local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                local combined = (bText .. " " .. bName .. " " .. pName):lower()

                local isHire = (combined:find("hire") or combined:find("upgrade") or combined:find("recruit") or combined:find("level up")) and not combined:find("robux")
                if isHire then
                    local shouldHire = false
                    if isQuestHire then
                        shouldHire = combined:find(targetRole:lower(), 1, true) ~= nil
                    else
                        local isCook = combined:find("cook") or combined:find("chef")
                        local isWaiter = combined:find("waiter") or combined:find("server")
                        local isCleaner = combined:find("clean") or combined:find("busser") or combined:find("janitor")

                        shouldHire = (Config.AutoHireCooks and isCook)
                                        or (Config.AutoHireWaiters and isWaiter)
                                        or (Config.AutoHireCleaners and isCleaner)
                                        or (not isCook and not isWaiter and not isCleaner and (Config.AutoHireCooks or Config.AutoHireWaiters or Config.AutoHireCleaners))
                    end

                    if shouldHire then
                        local price = Utility.ParsePrice(combined, btn)
                        local canAfford, needed = Utility.CanAfford(price)
                        if canAfford then
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)
                            if State.Stats.StaffHired ~= nil then
                                State.Stats.StaffHired = State.Stats.StaffHired + 1
                            end
                            if isQuestHire then
                                State.Stats.QuestsCompleted = (State.Stats.QuestsCompleted or 0) + 1
                            end
                            task.wait(Config.PostActionDelay or 0.2)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- Scan and group all currently available purchasable items & upgrades across world prompts and UI catalog
    function Restaurant.ScanAvailablePurchases()
        local results = {
            LandFloors = {},
            Cooking = {},
            Dining = {},
            Kitchen = {},
            Decor = {},
            Staff = {},
            All = {}
        }

        local seenNames = {}

        -- 1. Scan in-world Prompts (Expansion & Buy)
        local prompts = Restaurant.ScanPrompts()
        local candidatePrompts = {}
        for _, p in ipairs(prompts.Expand) do table.insert(candidatePrompts, { Prompt = p, Type = "Expand" }) end
        for _, p in ipairs(prompts.Buy) do table.insert(candidatePrompts, { Prompt = p, Type = "Buy" }) end

        for _, item in ipairs(candidatePrompts) do
            local p = item.Prompt
            local act = (p.ActionText or ""):lower()
            local obj = (p.ObjectText or p.Name or (p.Parent and p.Parent.Name or "")):lower()
            local combined = act .. " " .. obj
            local cleanTitle = (p.ObjectText and #p.ObjectText > 0) and p.ObjectText or (p.Parent and p.Parent.Name or "Item")
            if not seenNames[cleanTitle] then
                seenNames[cleanTitle] = true
                local price = Utility.ParsePrice(combined, p) or 0
                local canAfford, needed = Utility.CanAfford(price)
                local category = "Kitchen"
                local catLabel = "🍽️ Kitchen Equipment"

                if item.Type == "Expand" or combined:find("floor") or combined:find("land") or combined:find("expand") then
                    category = "LandFloors"
                    catLabel = "🏰 Land & Floors"
                elseif combined:find("stove") or combined:find("oven") or combined:find("grill") or combined:find("fryer") then
                    category = "Cooking"
                    catLabel = "🍳 Cooking Appliances"
                elseif combined:find("table") or combined:find("chair") or combined:find("stool") or combined:find("booth") then
                    category = "Dining"
                    catLabel = "🪑 Dining Furniture"
                elseif combined:find("decor") or combined:find("plant") or combined:find("light") or combined:find("paint") then
                    category = "Decor"
                    catLabel = "🌿 Decor & Aesthetics"
                end

                local entry = {
                    Title = cleanTitle,
                    Category = category,
                    CategoryLabel = catLabel,
                    Price = price,
                    PriceText = price > 0 and ("$" .. tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or "Free / Unknown",
                    CanAfford = canAfford,
                    Needed = needed,
                    Prompt = p,
                    Type = "Prompt"
                }

                table.insert(results[category], entry)
                table.insert(results.All, entry)
            end
        end

        -- 2. Scan PlayerGui Shop and Staff buttons
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local combined = (bText .. " " .. bName .. " " .. pName):lower()

                    local isBuy = (combined:find("buy") or combined:find("purchase")) and not combined:find("robux")
                    local isHire = (combined:find("hire") or combined:find("upgrade") or combined:find("recruit")) and not combined:find("robux")

                    if isBuy or isHire then
                        local rawText = btn:IsA("TextButton") and btn.Text or btn.Name
                        local cleanTitle = rawText:gsub("%$%s*[%d%,%.]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
                        if #cleanTitle > 2 and not seenNames[cleanTitle] then
                            seenNames[cleanTitle] = true
                            local price = Utility.ParsePrice(combined, btn) or 0
                            local canAfford, needed = Utility.CanAfford(price)
                            local category = "Kitchen"
                            local catLabel = "🍽️ Kitchen Equipment"

                            if isHire or combined:find("cook") or combined:find("waiter") or combined:find("cleaner") or combined:find("staff") then
                                category = "Staff"
                                catLabel = "👨‍🍳 Staff Personnel"
                            elseif combined:find("floor") or combined:find("land") or combined:find("expand") then
                                category = "LandFloors"
                                catLabel = "🏰 Land & Floors"
                            elseif combined:find("stove") or combined:find("oven") or combined:find("grill") or combined:find("fryer") then
                                category = "Cooking"
                                catLabel = "🍳 Cooking Appliances"
                            elseif combined:find("table") or combined:find("chair") or combined:find("stool") or combined:find("booth") then
                                category = "Dining"
                                catLabel = "🪑 Dining Furniture"
                            elseif combined:find("decor") or combined:find("plant") or combined:find("light") then
                                category = "Decor"
                                catLabel = "🌿 Decor & Aesthetics"
                            end

                            local entry = {
                                Title = cleanTitle,
                                Category = category,
                                CategoryLabel = catLabel,
                                Price = price,
                                PriceText = price > 0 and ("$" .. tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or "Free / In-Store",
                                CanAfford = canAfford,
                                Needed = needed,
                                Button = btn,
                                Type = "Button"
                            }

                            table.insert(results[category], entry)
                            table.insert(results.All, entry)
                        end
                    end
                end
            end
        end

        return results
    end

    local lastPlaceCheck = 0
    local placeGridIndex = 0
    function Restaurant.HandleAutoPlace(targetItemName)
        local isQuestPlace = (targetItemName ~= nil and type(targetItemName) == "string" and #targetItemName > 0)
        if not isQuestPlace and not Config.AutoPlaceEnabled and not Config.MasterAutoFarmEnabled then return false end
        local now = os.clock()
        if now - lastPlaceCheck < 1.8 then return false end
        lastPlaceCheck = now

        local targetItemLower = isQuestPlace and targetItemName:lower() or nil

        -- 1. Check in-world "Place" / "Build" prompts on player's plot
        local prompts = Restaurant.ScanPrompts()
        if #prompts.Place > 0 then
            for _, p in ipairs(prompts.Place) do
                if isPromptReady(p) and not State.InFlightTasks[p] then
                    local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "") .. " " .. (p.Parent and p.Parent.Name or "")):lower()
                    
                    local shouldPlace = false
                    if isQuestPlace and targetItemLower then
                        shouldPlace = text:find(targetItemLower, 1, true) ~= nil
                    else
                        local isTable = text:find("table")
                        local isChair = text:find("chair") or text:find("seat")
                        local isFurniture = text:find("furniture") or text:find("decor")

                        shouldPlace = (Config.AutoPlaceTables and isTable)
                                         or (Config.AutoPlaceChairs and isChair)
                                         or (Config.AutoPlaceFurniture and isFurniture)
                                         or (not isTable and not isChair and not isFurniture)
                    end

                    if shouldPlace then
                        local ok = executeAction(p, 3.0, "ItemsPlaced")
                        if ok then
                            if isQuestPlace then
                                State.Stats.QuestsCompleted = (State.Stats.QuestsCompleted or 0) + 1
                            end
                            return true
                        end
                    end
                end
            end
        end

        -- 2. Check Build / Inventory GUI in PlayerGui for unplaced items
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local char, root = getAliveCharacter()
        local center = Restaurant.RestaurantCenter or (root and root.Position)
        if pg and center and char then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local bName = btn.Name:lower()
                    local pName = (btn.Parent and btn.Parent.Name or ""):lower()

                    local isPlaceBtn = (bText == "place" or bText:find("place") or bName:find("place") or bText == "deploy" or bText == "build" or bText == "add") and not bText:find("cancel") and not bName:find("close")
                    if isPlaceBtn then
                        local combined = (bText .. " " .. bName .. " " .. pName):lower()
                        
                        local shouldPlace = false
                        if isQuestPlace and targetItemLower then
                            shouldPlace = combined:find(targetItemLower, 1, true) ~= nil
                        else
                            local isTable = combined:find("table")
                            local isChair = combined:find("chair") or combined:find("seat")
                            local isFurniture = combined:find("furniture") or combined:find("decor")

                            shouldPlace = (Config.AutoPlaceTables and isTable)
                                             or (Config.AutoPlaceChairs and isChair)
                                             or (Config.AutoPlaceFurniture and isFurniture)
                                             or (not isTable and not isChair and not isFurniture)
                        end

                        if shouldPlace then
                            -- Trigger place button on item
                            pcall(function()
                                if type(firesignal) == "function" and btn.Activated then
                                    firesignal(btn.Activated)
                                elseif btn.Activate then
                                    btn:Activate()
                                end
                            end)

                            -- Calculate open floor grid coordinate near restaurant center
                            placeGridIndex = (placeGridIndex + 1) % 48
                            local ring = math.floor(placeGridIndex / 8) + 1
                            local angle = (placeGridIndex % 8) * (math.pi / 4)
                            local dist = ring * 6.5
                            local targetGridPos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
                            local safeFloor = Utility.GetGroundPosition(targetGridPos, {char})

                            -- Teleport near position so placement raycasts succeed
                            if Config.AutoTeleportEnabled and root then
                                root.CFrame = CFrame.new(safeFloor + Vector3.new(0, 3, 0))
                                task.wait(0.15)
                            end

                            -- Check for placement confirm button in UI
                            for _, confirmBtn in ipairs(pg:GetDescendants()) do
                                if (confirmBtn:IsA("TextButton") or confirmBtn:IsA("ImageButton")) and confirmBtn.Visible then
                                    local cText = (confirmBtn:IsA("TextButton") and confirmBtn.Text or ""):lower()
                                    local cName = confirmBtn.Name:lower()
                                    if cText == "confirm" or cText == "✓" or cText:find("confirm") or cName:find("confirm") or cText == "place" then
                                        pcall(function()
                                            if type(firesignal) == "function" and confirmBtn.Activated then
                                                firesignal(confirmBtn.Activated)
                                            elseif confirmBtn.Activate then
                                                confirmBtn:Activate()
                                            end
                                        end)
                                        break
                                    end
                                end
                            end

                            -- Check ReplicatedStorage placement remote
                            local rs = game:GetService("ReplicatedStorage")
                            local placeRemote = rs:FindFirstChild("PlaceItem", true) or rs:FindFirstChild("PlaceObject", true) or rs:FindFirstChild("PlaceFurniture", true) or rs:FindFirstChild("BuildItem", true)
                            if placeRemote and placeRemote:IsA("RemoteEvent") then
                                pcall(function()
                                    placeRemote:FireServer(bName, CFrame.new(safeFloor))
                                end)
                            end

                            State.Stats.ItemsPlaced = (State.Stats.ItemsPlaced or 0) + 1
                            if isQuestPlace then
                                State.Stats.QuestsCompleted = (State.Stats.QuestsCompleted or 0) + 1
                            end
                            task.wait(Config.PostActionDelay or 0.2)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- Auto-do and auto-claim quests, tasks, and daily objectives
    local lastQuestAutomation = 0
    function Restaurant.HandleQuestAutomation()
        if not Config.MasterAutoFarmEnabled and not Config.AutoClaimQuestsEnabled and not Config.AutoDoQuestsEnabled then
            return false
        end

        local now = os.clock()
        if now - lastQuestAutomation < 2.5 then return false end
        lastQuestAutomation = now

        -- 1. Auto-claim all finished quests, goals, milestones, and playtime rewards
        if Config.MasterAutoFarmEnabled or Config.AutoClaimQuestsEnabled then
            pcall(function()
                local claimed = Utility.ClaimAllRewards()
                if claimed and claimed > 0 then
                    State.Stats.QuestsClaimed = (State.Stats.QuestsClaimed or 0) + claimed
                end
            end)
        end

        -- 2. Auto-accept new quests and parse active quest directives
        if Config.MasterAutoFarmEnabled or Config.AutoDoQuestsEnabled then
            pcall(function()
                local directives = Utility.AcceptAndDoQuests()
                if directives then
                    if directives.Buy then pcall(Restaurant.HandleAutoBuy, directives.TargetItem) end
                    if directives.Place then pcall(Restaurant.HandleAutoPlace, directives.TargetItem) end
                    if directives.Staff then pcall(Restaurant.HandleStaffManage, directives.TargetRole) end
                    if directives.Farm and Restaurant.HandleFarming then pcall(Restaurant.HandleFarming) end
                end
            end)
        end

        return true
    end

    -- Interleaved multi-queue pipeline categories definition
    local pipelineCategories = {
        { name = "Sink", configKey = "AutoWashSinksEnabled", stat = "DishesWashed", cooldown = 2.5 },
        { name = "Serve", configKey = "AutoServeEnabled", stat = "DishesServed", cooldown = 2.5 },
        { name = "Cook", configKey = "AutoCookEnabled", stat = "DishesCooked", cooldown = 2.5 },
        { name = "Order", configKey = "AutoOrderEnabled", stat = "OrdersTaken", cooldown = 2.5 },
        { name = "Clean", configKey = "AutoCleanEnabled", stat = "TablesCleaned", cooldown = 3.0 },
        { name = "Seat", configKey = "AutoSeatEnabled", stat = "CustomersSeated", cooldown = 3.0 },
        { name = "Cash", configKey = "AutoCollectCashEnabled", stat = "CashCollected", cooldown = 3.0 },
        { name = "Quest", configKey = "AutoDoQuestsEnabled", stat = "QuestsCompleted", cooldown = 3.0 },
        { name = "Delivery", configKey = "AutoDeliveryEnabled", stat = "DeliveriesCompleted", cooldown = 4.0 },
        { name = "Restock", configKey = "AutoRestockEnabled", stat = "StorageRestocked", cooldown = 3.5 },
        { name = "Farm", configKey = "AutoFarmEnabled", stat = "CropsHarvested", cooldown = 3.0 },
        { name = "Expand", configKey = "AutoExpandEnabled", stat = "ExpansionsPurchased", cooldown = 6.0, requireExplicit = true },
    }
    local pipelineCursor = 1

    -- Interleaved multi-queue scheduler: Dispatches next ready category round-robin to eliminate starvation
    function Restaurant.DispatchInterleavedPipeline(prompts)
        local isMaster = Config.MasterAutoFarmEnabled
        local holdingType, holdingCount, handsFull = Restaurant.GetHoldingState()
        local sinksFull = State.SinksFull and (os.clock() < (State.SinksFullUntil or 0))

        -- =====================================================================
        -- CRITICAL HAND STATE GATING (Solves "hands are full" & "you cant do that rn")
        -- =====================================================================
        -- Priority Override 1: Holding Dirty Dishes -> MUST go to Sink / Dishwasher
        if holdingType == "DirtyDishes" or (handsFull and State.LastActionType == "Clean") then
            if prompts.Sink and #prompts.Sink > 0 then
                for _, p in ipairs(prompts.Sink) do
                    if isPromptReady(p) and not State.InFlightTasks[p] then
                        return executeAction(p, 2.5, "DishesWashed", "Sink")
                    end
                end
            end
            if sinksFull and (Config.AutoBuyAppliances or Config.AutoBuyEnabled) then
                pcall(Restaurant.HandleAutoBuy)
            end
        end

        -- Priority Override 2: Holding Food -> MUST Serve to customer table
        if holdingType == "Food" or (handsFull and (State.LastActionType == "Serve" or State.LastActionType == "Cook")) then
            if prompts.Serve and #prompts.Serve > 0 then
                for _, p in ipairs(prompts.Serve) do
                    if isPromptReady(p) and not State.InFlightTasks[p] then
                        return executeAction(p, 2.5, "DishesServed", "Serve")
                    end
                end
            end
        end

        -- Priority Override 3: Sinks are Full -> Wash existing dishes in sink
        if sinksFull and prompts.Sink and #prompts.Sink > 0 then
            for _, p in ipairs(prompts.Sink) do
                if isPromptReady(p) and not State.InFlightTasks[p] then
                    local text = ((p.ActionText or "") .. " " .. (p.ObjectText or "")):lower()
                    if text:find("wash") or text:find("clean") or text:find("scrub") or text:find("start") then
                        return executeAction(p, 3.0, "DishesWashed", "Sink")
                    end
                end
            end
        end

        -- Priority Override 4: Active Goal Accelerated Station Priority
        -- If current Goal requires Cook, Clean, Serve, Seat, Order, Farm, or Delivery, prioritize it!
        local activeCat = State.ActiveGoal and State.ActiveGoal.Category
        if (isMaster or Config.AutoDoQuestsEnabled) and activeCat and activeCat ~= "None" and prompts[activeCat] and #prompts[activeCat] > 0 then
            local canRunGoalCat = true
            if activeCat == "Clean" and (handsFull or holdingType == "DirtyDishes" or sinksFull) then canRunGoalCat = false end
            if activeCat == "Cook" and (holdingType ~= "None" or handsFull) then canRunGoalCat = false end
            if (activeCat == "Seat" or activeCat == "Order") and (holdingType == "DirtyDishes" or handsFull) then canRunGoalCat = false end
            if activeCat == "Serve" and holdingType == "DirtyDishes" then canRunGoalCat = false end

            if canRunGoalCat then
                for _, p in ipairs(prompts[activeCat]) do
                    if isPromptReady(p) and not State.InFlightTasks[p] then
                        if Config.ConcurrentExecutionEnabled then
                            local cluster = Restaurant.GetNearbyCluster(p, prompts[activeCat], 14, Config.StationBatchSize or 3)
                            executeCluster(p, cluster, 2.5, "QuestsCompleted", prompts, activeCat)
                        else
                            executeAction(p, 2.5, "QuestsCompleted", activeCat)
                        end
                        return true
                    end
                end
            end
        end

        local totalCategories = #pipelineCategories

        for i = 0, totalCategories - 1 do
            local idx = ((pipelineCursor - 1 + i) % totalCategories) + 1
            local cat = pipelineCategories[idx]

            -- State filtering per category:
            -- Do not pick up more dirty dishes if hands full or holding dirty dishes or sinks are full
            local canRun = true
            if cat.name == "Clean" then
                if handsFull or holdingType == "DirtyDishes" or sinksFull then
                    canRun = false
                end
            elseif cat.name == "Cook" then
                if holdingType ~= "None" or handsFull then
                    canRun = false
                end
            elseif cat.name == "Seat" or cat.name == "Order" then
                if holdingType == "DirtyDishes" or handsFull then
                    canRun = false
                end
            elseif cat.name == "Serve" then
                if holdingType == "DirtyDishes" then
                    canRun = false
                end
            end

            local isCategoryEnabled = cat.requireExplicit and Config[cat.configKey] or (isMaster or Config[cat.configKey])

            if canRun and isCategoryEnabled and prompts[cat.name] and #prompts[cat.name] > 0 then
                local primaryPrompt = nil
                for _, p in ipairs(prompts[cat.name]) do
                    if isPromptReady(p) and not State.InFlightTasks[p] then
                        if cat.name == "Expand" or cat.name == "Buy" then
                            if isPromptAffordable(p) then
                                primaryPrompt = p
                                break
                            end
                        else
                            primaryPrompt = p
                            break
                        end
                    end
                end

                if primaryPrompt then
                    if Config.ConcurrentExecutionEnabled then
                        local cluster = Restaurant.GetNearbyCluster(primaryPrompt, prompts[cat.name], 14, Config.StationBatchSize or 3)
                        executeCluster(primaryPrompt, cluster, cat.cooldown, cat.stat, prompts, cat.name)
                    else
                        executeAction(primaryPrompt, cat.cooldown, cat.stat, cat.name)
                    end

                    -- If Quest NPC/Board prompt was triggered, auto-dismiss/accept dialog popup
                    if cat.name == "Quest" then
                        task.delay(0.4, function()
                            pcall(function()
                                Utility.ClaimAllRewards()
                                Utility.AcceptAndDoQuests()
                            end)
                        end)
                    end

                    -- Advance cursor to next category for balanced progression
                    pipelineCursor = (idx % totalCategories) + 1
                    return true
                end
            end
        end

        return false
    end

    -- Master Autonomous Dispatcher & Parallel Workers
    local runningLoop = false
    function Restaurant.StartLoop()
        if runningLoop then return end
        runningLoop = true

        -- Decoupled Worker 1: Parallel Floor Cash Sweeper (Continuous remote pickup via firetouchinterest)
        task.spawn(function()
            while Core.State.Running and runningLoop do
                if Config.MasterAutoFarmEnabled or Config.AutoCollectCashEnabled then
                    pcall(function()
                        Restaurant.SweepFloorCash()
                    end)
                end
                task.wait(0.35)
            end
        end)

        -- Decoupled Worker 2: Parallel Background UI Manager (Quests, Daily Gifts, Staff, UI Catalog)
        task.spawn(function()
            while Core.State.Running and runningLoop do
                -- Auto-claim all quests, gifts, daily rewards, and auto-do quest actions
                local now = os.clock()
                if (Config.MasterAutoFarmEnabled or Config.AutoClaimRewardsEnabled or Config.AutoClaimQuestsEnabled or Config.AutoDoQuestsEnabled) and (now - lastQuestCheck > 3) then
                    lastQuestCheck = now
                    pcall(function()
                        Restaurant.HandleQuestAutomation()
                    end)
                end

                -- Auto-hire / upgrade staff in background without interrupting kitchen
                if Config.AutoHireStaffEnabled then
                    pcall(function()
                        Restaurant.HandleStaffManage()
                    end)
                end

                -- Auto-buy catalog items if enabled
                if Config.AutoBuyEnabled then
                    pcall(function()
                        Restaurant.HandleAutoBuy()
                    end)
                end

                task.wait(2.5)
            end
        end)

        -- Master Worker 3: Physical Workstation Automation Loop
        task.spawn(function()
            while Core.State.Running and runningLoop do
                local delayTime = math.clamp(Config.ActionDelay or 0.3, 0.05, 5)

                -- Run memory sanitation
                cleanExpiredCooldowns()

                local char, _, hum = getAliveCharacter()
                if char and hum and hum.Health > 0 then
                    local prompts = Restaurant.ScanPrompts()
                    local dispatched = false

                    if Config.InterleavedPipelineEnabled then
                        dispatched = Restaurant.DispatchInterleavedPipeline(prompts)
                    else
                        -- Fallback: Classical single/cluster prioritized ladder with Hand State Gating
                        local isMaster = Config.MasterAutoFarmEnabled
                        local holdingType, holdingCount, handsFull = Restaurant.GetHoldingState()
                        local sinksFull = State.SinksFull and (os.clock() < (State.SinksFullUntil or 0))

                        local function dispatchCategory(list, cooldown, statKey, catType)
                            for _, p in ipairs(list) do
                                if isPromptReady(p) and not State.InFlightTasks[p] then
                                    if Config.ConcurrentExecutionEnabled then
                                        local cluster = Restaurant.GetNearbyCluster(p, list, 14, Config.StationBatchSize or 3)
                                        return executeCluster(p, cluster, cooldown, statKey, prompts, catType)
                                    else
                                        return executeAction(p, cooldown, statKey, catType)
                                    end
                                end
                            end
                            return false
                        end

                        -- Hand State Overrides in Fallback Ladder
                        if (holdingType == "DirtyDishes" or (handsFull and State.LastActionType == "Clean")) and #prompts.Sink > 0 then
                            dispatched = dispatchCategory(prompts.Sink, 2.5, "DishesWashed", "Sink")
                        elseif (holdingType == "Food" or (handsFull and (State.LastActionType == "Serve" or State.LastActionType == "Cook"))) and #prompts.Serve > 0 then
                            dispatched = dispatchCategory(prompts.Serve, 2.5, "DishesServed", "Serve")
                        elseif (isMaster or Config.AutoWashSinksEnabled) and #prompts.Sink > 0 and (holdingType == "DirtyDishes" or sinksFull) then
                            dispatched = dispatchCategory(prompts.Sink, 2.5, "DishesWashed", "Sink")
                        elseif (isMaster or Config.AutoCollectCashEnabled) and #prompts.Cash > 0 then
                            dispatched = dispatchCategory(prompts.Cash, 3.0, "CashCollected", "Cash")
                        elseif (isMaster or Config.AutoOrderEnabled) and #prompts.Order > 0 and holdingType == "None" then
                            dispatched = dispatchCategory(prompts.Order, 2.5, "OrdersTaken", "Order")
                        elseif (isMaster or Config.AutoServeEnabled) and #prompts.Serve > 0 and holdingType ~= "DirtyDishes" then
                            dispatched = dispatchCategory(prompts.Serve, 2.5, "DishesServed", "Serve")
                        elseif (isMaster or Config.AutoCookEnabled) and #prompts.Cook > 0 and holdingType == "None" then
                            dispatched = dispatchCategory(prompts.Cook, 2.5, "DishesCooked", "Cook")
                        elseif (isMaster or Config.AutoCleanEnabled) and #prompts.Clean > 0 and not handsFull and holdingType ~= "DirtyDishes" and not sinksFull then
                            dispatched = dispatchCategory(prompts.Clean, 3.0, "TablesCleaned", "Clean")
                        elseif (isMaster or Config.AutoWashSinksEnabled) and #prompts.Sink > 0 then
                            dispatched = dispatchCategory(prompts.Sink, 2.5, "DishesWashed", "Sink")
                        elseif (isMaster or Config.AutoSeatEnabled) and #prompts.Seat > 0 and holdingType == "None" then
                            dispatched = dispatchCategory(prompts.Seat, 3.0, "CustomersSeated", "Seat")
                        elseif (isMaster or Config.AutoDoQuestsEnabled) and #prompts.Quest > 0 then
                            dispatched = dispatchCategory(prompts.Quest, 3.0, "QuestsCompleted", "Quest")
                        elseif (isMaster or Config.AutoDeliveryEnabled) and #prompts.Delivery > 0 then
                            dispatched = dispatchCategory(prompts.Delivery, 4.0, "DeliveriesCompleted", "Delivery")
                        elseif (isMaster or Config.AutoRestockEnabled) and #prompts.Restock > 0 then
                            dispatched = dispatchCategory(prompts.Restock, 3.5, "StorageRestocked", "Restock")
                        elseif (isMaster or Config.AutoFarmEnabled) and #prompts.Farm > 0 then
                            dispatched = dispatchCategory(prompts.Farm, 3.0, "CropsHarvested", "Farm")
                        elseif (isMaster or Config.AutoPlaceEnabled) and Restaurant.HandleAutoPlace() then
                            dispatched = true
                        elseif Config.AutoExpandEnabled and #prompts.Expand > 0 then
                            for _, p in ipairs(prompts.Expand) do
                                if isPromptAffordable(p) then
                                    dispatched = dispatchCategory({p}, 6.0, "ExpansionsPurchased", "Expand")
                                    if dispatched then break end
                                end
                            end
                        end
                    end

                    -- Auto-place check if not already handled
                    if not dispatched and (Config.MasterAutoFarmEnabled or Config.AutoPlaceEnabled) then
                        pcall(function()
                            Restaurant.HandleAutoPlace()
                        end)
                    end
                end

                task.wait(delayTime)
            end
            runningLoop = false
        end)
    end

    function Restaurant.Init()
        Restaurant.GetPlayerPlot()
        Restaurant.SetupGameNotificationListener()
        Restaurant.GetHoldingState()
        Restaurant.StartLoop()
        print("🍽️ Run a Restaurant autonomous engine initialized successfully with Hand & Sink Intelligence.")
    end

    function Restaurant.Cleanup()
        runningLoop = false
        cachedPlot = nil
        Restaurant.RestaurantCenter = nil
        table.clear(promptCooldowns)
        table.clear(State.InFlightTasks)
        State.HoldingType = "None"
        State.HoldingCount = 0
        State.HandsFull = false
        State.SinksFull = false
        State.ActivePrompt = nil
        State.InteractionBlockedUntil = 0
        cachedPlot = nil
        Restaurant.RestaurantCenter = nil
        table.clear(promptCooldowns)
        table.clear(State.InFlightTasks)

        local _, root = getAliveCharacter()
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    return Restaurant
end

end)()(Core)
Core.Restaurant.Init()

Core.Movement = (function()
return function(Core)
    local Movement = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local LocalPlayer = Core.Services.Players.LocalPlayer
    local RunService = Core.Services.RunService
    local UserInputService = Core.Services.UserInputService

    -- Cache original WalkSpeed/JumpPower so we can restore them when disabled (#7)
    local originalWalkSpeed = nil
    local originalJumpPower = nil
    local originalJumpHeight = nil

    -- Cache of parts whose CanCollide was changed by NoClip, for restoration (#6)
    local noClipCache = setmetatable({}, {__mode = "k"})

    function Movement.Cleanup()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = (originalWalkSpeed ~= nil) and originalWalkSpeed or 16
            originalWalkSpeed = nil

            hum.JumpPower = (originalJumpPower ~= nil) and originalJumpPower or 50
            originalJumpPower = nil

            hum.JumpHeight = (originalJumpHeight ~= nil) and originalJumpHeight or 7.2
            originalJumpHeight = nil
        end

        if next(noClipCache) then
            for part, _ in pairs(noClipCache) do
                if part and part.Parent then
                    part.CanCollide = true
                end
            end
            table.clear(noClipCache)
        end
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end

    local speedToggleHandle = nil
    local jumpToggleHandle = nil
    local noClipToggleHandle = nil
    local infJumpToggleHandle = nil

    function Movement.SyncToggles()
        if speedToggleHandle and speedToggleHandle.SetState then
            speedToggleHandle:SetState(Config.WalkSpeedEnabled)
        end
        if jumpToggleHandle and jumpToggleHandle.SetState then
            jumpToggleHandle:SetState(Config.JumpPowerEnabled)
        end
        if noClipToggleHandle and noClipToggleHandle.SetState then
            noClipToggleHandle:SetState(Config.NoClipEnabled)
        end
        if infJumpToggleHandle and infJumpToggleHandle.SetState then
            infJumpToggleHandle:SetState(Config.InfiniteJumpEnabled)
        end
    end

    function Movement.Init()
        if Core.UI and Core.UI.Window then
            local MoveTab = Core.UI.Window:AddTab("Movement", "🏃")
            MoveTab:AddSection("PHYSICS OVERRIDES", "⚡")
            
            speedToggleHandle = MoveTab:AddToggle("Speed Hack", "Overrides character walk speed for swift travel.", Config.WalkSpeedEnabled, function(val)
                Config.WalkSpeedEnabled = val
                if Core.UI.UpdateStatus then Core.UI.UpdateStatus() end
            end)
            MoveTab:AddSlider("Walk Speed", "Adjust sprinting movement speed.", Config.WalkSpeed, 16, 250, 0, " studs/s", function(val)
                Config.WalkSpeed = val
            end)
            
            jumpToggleHandle = MoveTab:AddToggle("Jump Hack", "Overrides character jump power.", Config.JumpPowerEnabled, function(val)
                Config.JumpPowerEnabled = val
                if Core.UI.UpdateStatus then Core.UI.UpdateStatus() end
            end)
            MoveTab:AddSlider("Jump Power", "Adjust jumping launch power.", Config.JumpPower, 50, 350, 0, "", function(val)
                Config.JumpPower = val
            end)
            
            MoveTab:AddSection("UTILITY", "🛡️")
            noClipToggleHandle = MoveTab:AddToggle("No-Clip", "Walk freely through walls, furniture, and NPCs.", Config.NoClipEnabled, function(val)
                Config.NoClipEnabled = val
                if Core.UI.UpdateStatus then Core.UI.UpdateStatus() end
            end)
            infJumpToggleHandle = MoveTab:AddToggle("Infinite Jump", "Allows jumping continuously in mid-air.", Config.InfiniteJumpEnabled, function(val)
                Config.InfiniteJumpEnabled = val
                if Core.UI.UpdateStatus then Core.UI.UpdateStatus() end
            end)
        end

        -- Infinite Jump Logic
        Utility.RegisterConnection(UserInputService.JumpRequest:Connect(function()
            if Config.InfiniteJumpEnabled then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and not hum.Sit then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end))

        -- NoClip Logic (Stepped runs before physics simulation)
        Utility.RegisterConnection(RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end

            if Config.NoClipEnabled then
                -- Disable collision and remember which parts we touched
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if part.CanCollide then
                            -- Store original value only once per part
                            if noClipCache[part] == nil then
                                noClipCache[part] = true
                            end
                            part.CanCollide = false
                        end
                    end
                end
            else
                -- Restore CanCollide for all parts we previously disabled (#6)
                if next(noClipCache) then
                    for part, _ in pairs(noClipCache) do
                        if part and part.Parent then
                            part.CanCollide = true
                        end
                    end
                    table.clear(noClipCache)
                end
            end
        end))

        -- WalkSpeed & JumpPower Enforcement (Heartbeat is better for physics)
        Utility.RegisterConnection(RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end

            -- Capture originals once before we override anything (#7)
            if Config.WalkSpeedEnabled then
                if originalWalkSpeed == nil then
                    originalWalkSpeed = (hum.WalkSpeed ~= Config.WalkSpeed and hum.WalkSpeed > 0) and hum.WalkSpeed or 16
                end
                if hum.WalkSpeed ~= Config.WalkSpeed then
                    hum.WalkSpeed = Config.WalkSpeed
                end
            else
                -- Restore original WalkSpeed when disabled (#7)
                if originalWalkSpeed ~= nil then
                    hum.WalkSpeed = originalWalkSpeed
                    originalWalkSpeed = nil
                end
            end

            if Config.JumpPowerEnabled then
                if hum.UseJumpPower then
                    if originalJumpPower == nil then
                        originalJumpPower = (hum.JumpPower ~= Config.JumpPower and hum.JumpPower > 0) and hum.JumpPower or 50
                    end
                    if hum.JumpPower ~= Config.JumpPower then
                        hum.JumpPower = Config.JumpPower
                    end
                else
                    -- Fix #19: use workspace.Gravity instead of hardcoded constant
                    -- Correct formula: JumpHeight = JumpPower² / (2 * gravity)
                    local gravity = workspace.Gravity > 0 and workspace.Gravity or 196.2
                    local targetHeight = (Config.JumpPower * Config.JumpPower) / (2 * gravity)
                    if originalJumpHeight == nil then
                        originalJumpHeight = hum.JumpHeight
                    end
                    if math.abs(hum.JumpHeight - targetHeight) > 0.1 then
                        hum.JumpHeight = targetHeight
                    end
                end
            else
                -- Restore original JumpPower/JumpHeight when disabled (#7)
                if originalJumpPower ~= nil then
                    hum.JumpPower = originalJumpPower
                    originalJumpPower = nil
                end
                if originalJumpHeight ~= nil then
                    hum.JumpHeight = originalJumpHeight
                    originalJumpHeight = nil
                end
            end
        end))

        -- Reset caches on respawn so originals are re-captured from fresh character
        Utility.RegisterConnection(LocalPlayer.CharacterAdded:Connect(function()
            originalWalkSpeed = nil
            originalJumpPower = nil
            originalJumpHeight = nil
            table.clear(noClipCache)
        end))
    end

    return Movement
end

end)()(Core)
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
Core.MainLoop = (function()
return function(Core)
    local MainLoop = {}

    local Config = Core.Config
    local Utility = Core.Utility
    local Services = Core.Services

    local function isValidKey(key)
        return key ~= nil and key ~= Enum.KeyCode.None and key ~= Enum.KeyCode.Unknown
    end

    local function matchesKey(boundKey, inputKey)
        return isValidKey(boundKey) and inputKey == boundKey
    end

    function MainLoop.Init()
        -- Keybind handling
        Utility.RegisterConnection(Services.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            -- Only process keyboard inputs; ignore mouse clicks, touches, and non-keyboard events
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if not isValidKey(input.KeyCode) then return end

            -- Toggle Menu
            if matchesKey(Config.MenuKey, input.KeyCode) then
                if Core.UI and Core.UI.Window and Core.UI.Window.Library then
                    local lib = Core.UI.Window.Library
                    if lib.ToggleWindow then
                        lib:ToggleWindow()
                    elseif lib.MainContainer then
                        lib.MainContainer.Visible = not lib.MainContainer.Visible
                    end
                end

            -- Toggle No-Clip
            elseif matchesKey(Config.ToggleNoClipKey, input.KeyCode) then
                Config.NoClipEnabled = not Config.NoClipEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "No-Clip",
                        Content = Config.NoClipEnabled and "Collision disabled (Walking through walls)" or "Collision restored to normal",
                        Type = Config.NoClipEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end

            -- Toggle Speed Hack
            elseif matchesKey(Config.ToggleSpeedKey, input.KeyCode) then
                Config.WalkSpeedEnabled = not Config.WalkSpeedEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "Speed Hack",
                        Content = Config.WalkSpeedEnabled and ("Sprint speed set to " .. tostring(Config.WalkSpeed)) or "WalkSpeed restored to normal",
                        Type = Config.WalkSpeedEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end

            -- Toggle Jump Hack
            elseif matchesKey(Config.ToggleJumpKey, input.KeyCode) then
                Config.JumpPowerEnabled = not Config.JumpPowerEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "Jump Hack",
                        Content = Config.JumpPowerEnabled and ("Jump power set to " .. tostring(Config.JumpPower)) or "JumpPower restored to normal",
                        Type = Config.JumpPowerEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end

            -- Toggle Infinite Jump
            elseif matchesKey(Config.ToggleInfJumpKey, input.KeyCode) then
                Config.InfiniteJumpEnabled = not Config.InfiniteJumpEnabled
                if Core.Movement and Core.Movement.SyncToggles then Core.Movement.SyncToggles() end
                if Core.UI and Core.UI.UpdateStatus then pcall(Core.UI.UpdateStatus) end
                if Core.UI and Core.UI.Window and Core.UI.Window.Notify then
                    Core.UI.Window:Notify({
                        Title = "Infinite Jump",
                        Content = Config.InfiniteJumpEnabled and "Mid-air jumping active" or "Infinite jump disabled",
                        Type = Config.InfiniteJumpEnabled and "Success" or "Info",
                        Duration = 2
                    })
                end
            end
        end))

        print("🏃 Movement Utility Loaded. RightShift = toggle UI | N = toggle No-Clip")
    end

    return MainLoop
end

end)()(Core)
Core.MainLoop.Init()

print("🍽️ Run a Restaurant Utility loaded successfully!")
_G.__Restaurant_Terminate = Core.Utility.Terminate
