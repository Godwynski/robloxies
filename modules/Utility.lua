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

    -- Auto-Claim all finished quests, daily gifts, playtime rewards, spin wheels, and achievements
    function Utility.ClaimAllRewards()
        if not Config.AutoClaimRewardsEnabled and not Config.AutoClaimQuestsEnabled and not Config.MasterAutoFarmEnabled then return 0 end
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local claimed = 0

        -- 1. Scan PlayerGui for claim, reward, gift, daily, spin, milestone, quest buttons
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local name = btn.Name:lower()
                    local parentName = (btn.Parent and btn.Parent.Name or ""):lower()
                    local grandParentName = (btn.Parent and btn.Parent.Parent and btn.Parent.Parent.Name or ""):lower()

                    local isClaimText = text == "claim" or text == "collect" or text == "reward" or text == "open" or text == "free" or text == "spin" or text == "redeem" or text == "complete" or text == "turn in"
                    local hasClaimWord = text:find("claim") or text:find("collect") or text:find("reward") or text:find("free gift") or text:find("daily") or text:find("spin") or text:find("quest")
                    local hasRewardName = name:find("claim") or name:find("reward") or name:find("collect") or name:find("gift") or name:find("spin") or name:find("daily") or name:find("quest")
                    local isRewardContainer = parentName:find("quest") or parentName:find("gift") or parentName:find("reward") or parentName:find("daily") or parentName:find("milestone") or grandParentName:find("reward") or grandParentName:find("quest")

                    if not text:find("robux") and not text:find("buy") and not text:find("purchase") and not text:find("cancel") and not text:find("close") then
                        if isClaimText or hasClaimWord or (hasRewardName and (isRewardContainer or text ~= "")) then
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
            "ClaimPlaytime", "ClaimQuest", "ClaimGoal", "ClaimAchievement",
            "ClaimMilestone", "ClaimPass", "ClaimFreeGift", "SpinWheel", "FreeSpin",
            "CompleteQuest", "TurnInQuest", "FinishQuest", "RedeemQuest"
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

    -- Auto-Accept and Auto-Do Quests
    function Utility.AcceptAndDoQuests()
        if not Config.AutoDoQuestsEnabled and not Config.MasterAutoFarmEnabled then return nil end
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        local rs = game:GetService("ReplicatedStorage")

        -- 1. Auto-Accept new quests from UI dialogs or lists
        if pg then
            for _, btn in ipairs(pg:GetDescendants()) do
                if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()
                    local name = btn.Name:lower()
                    local parentName = (btn.Parent and btn.Parent.Name or ""):lower()

                    local isAccept = text == "accept" or text == "start" or text == "take quest" or text == "track" or text == "select" or text == "accept quest"
                    local isQuestContext = parentName:find("quest") or parentName:find("mission") or parentName:find("task") or name:find("quest") or name:find("accept")

                    if (isAccept or (isQuestContext and (text:find("accept") or text:find("start") or text:find("take")))) and
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

        -- 2. Trigger AcceptQuest / StartQuest remotes if available in ReplicatedStorage
        local acceptRemotes = {
            "AcceptQuest", "StartQuest", "TakeQuest", "TrackQuest", "SelectQuest", "AssignQuest"
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
            Expand = false
        }

        if pg then
            for _, lbl in ipairs(pg:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible then
                    local parentName = (lbl.Parent and lbl.Parent.Name or ""):lower()
                    local isQuestLabel = parentName:find("quest") or parentName:find("task") or parentName:find("mission") or parentName:find("goal") or lbl.Name:lower():find("quest") or lbl.Name:lower():find("task")
                    if isQuestLabel then
                        local t = (lbl.Text or ""):lower()
                        if t:find("cook") or t:find("dish") or t:find("meal") or t:find("bake") then directives.Cook = true end
                        if t:find("serve") or t:find("deliver to table") then directives.Serve = true end
                        if t:find("order") or t:find("ticket") then directives.Order = true end
                        if t:find("clean") or t:find("wipe") or t:find("table") or t:find("trash") then directives.Clean = true end
                        if t:find("seat") or t:find("customer") or t:find("guest") then directives.Seat = true end
                        if t:find("cash") or t:find("coin") or t:find("tip") or t:find("money") or t:find("earn") then directives.Cash = true end
                        if t:find("harvest") or t:find("crop") or t:find("wheat") or t:find("farm") then directives.Farm = true end
                        if t:find("delivery") or t:find("package") or t:find("box") or t:find("scooter") then directives.Delivery = true end
                        if t:find("buy") or t:find("purchase") or t:find("stove") or t:find("chair") then directives.Buy = true end
                        if t:find("place") or t:find("furniture") or t:find("build") then directives.Place = true end
                        if t:find("hire") or t:find("staff") or t:find("waiter") or t:find("chef") then directives.Staff = true end
                        if t:find("expand") or t:find("floor") or t:find("land") then directives.Expand = true end
                    end
                end
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
