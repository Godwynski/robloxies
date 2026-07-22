return function(Core)
    local UI = {}
    local Config = Core.Config

    function UI.Init()
        -- Load the UI Library
        local UILibrary
        if isfile and isfile("modules/UILibrary.lua") then
            UILibrary = loadstring(readfile("modules/UILibrary.lua"))()(Core)
        else
            UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/Godwynski/robloxies/main/modules/UILibrary.lua?nocache=" .. tostring(tick())))()(Core)
        end

        local Theme = UILibrary.Theme or {}

        -- Create the main window
        local Window = UILibrary:CreateWindow("⚡ Pure Auto-Aim v3.0.0 (Premium)")
        UI.Window = Window

        -- Expose a method to update the floating circle color
        function UI.UpdateFloatStatus()
            if not UILibrary.FloatingCircle.Visible then return end
            if Config.AutoAimEnabled then
                UILibrary.FloatStroke.Color = Theme.TextAccent
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(28, 22, 54)
            elseif Config.ESPEnabled then
                UILibrary.FloatStroke.Color = Color3.fromRGB(160, 140, 255)
                UILibrary.FloatingCircle.BackgroundColor3 = Color3.fromRGB(34, 28, 66)
            else
                UILibrary.FloatStroke.Color = Theme.Stroke
                UILibrary.FloatingCircle.BackgroundColor3 = Theme.ElementIdle
            end
        end

        -- ================== INFO / SCANNERS TAB ==================
        local InfoTab = Window:AddTab("Info")
        local InfoFrame = InfoTab.Frame

        local ScannersList = Instance.new("ScrollingFrame")
        ScannersList.Parent = InfoFrame
        ScannersList.Size = UDim2.new(0, 150, 1, -10)
        ScannersList.Position = UDim2.new(0, 10, 0, 5)
        ScannersList.BackgroundTransparency = 1
        ScannersList.ScrollBarThickness = 3
        ScannersList.ScrollBarImageColor3 = Theme.ElementActive
        ScannersList.BorderSizePixel = 0

        local SListLayout = Instance.new("UIListLayout")
        SListLayout.Parent = ScannersList
        SListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        SListLayout.Padding = UDim.new(0, 6)

        Core.Utility.RegisterConnection(SListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ScannersList.CanvasSize = UDim2.new(0, 0, 0, SListLayout.AbsoluteContentSize.Y + 10)
        end))

        local OutputFrame = Instance.new("Frame")
        OutputFrame.Parent = InfoFrame
        OutputFrame.Size = UDim2.new(1, -180, 1, -10)
        OutputFrame.Position = UDim2.new(0, 170, 0, 5)
        OutputFrame.BackgroundColor3 = Theme.Header
        Instance.new("UICorner", OutputFrame).CornerRadius = UDim.new(0, 6)

        local OutputScroll = Instance.new("ScrollingFrame")
        OutputScroll.Parent = OutputFrame
        OutputScroll.Size = UDim2.new(1, -16, 1, -46)
        OutputScroll.Position = UDim2.new(0, 8, 0, 8)
        OutputScroll.BackgroundTransparency = 1
        OutputScroll.ScrollBarThickness = 4
        OutputScroll.ScrollBarImageColor3 = Theme.ElementActive
        OutputScroll.BorderSizePixel = 0

        local OutputBox = Instance.new("TextBox")
        OutputBox.Parent = OutputScroll
        OutputBox.Size = UDim2.new(1, -8, 0, 500)
        OutputBox.BackgroundTransparency = 1
        OutputBox.ClearTextOnFocus = false
        OutputBox.TextEditable = true
        OutputBox.MultiLine = true
        OutputBox.TextWrapped = true
        OutputBox.TextXAlignment = Enum.TextXAlignment.Left
        OutputBox.TextYAlignment = Enum.TextYAlignment.Top
        OutputBox.Font = Enum.Font.RobotoMono
        OutputBox.TextSize = 12
        OutputBox.TextColor3 = Theme.TextPrimary
        OutputBox.Text = "Select a scanner from the left to view output here.\n\nYou can click the button below to copy the text."

        local function updateScroll()
            local y = OutputBox.TextBounds.Y
            if y < OutputScroll.AbsoluteSize.Y then y = OutputScroll.AbsoluteSize.Y end
            OutputBox.Size = UDim2.new(1, -8, 0, y + 20)
            OutputScroll.CanvasSize = UDim2.new(0, 0, 0, y + 30)
        end
        Core.Utility.RegisterConnection(OutputBox:GetPropertyChangedSignal("TextBounds"):Connect(updateScroll))
        Core.Utility.RegisterConnection(OutputBox:GetPropertyChangedSignal("Text"):Connect(updateScroll))

        local CopyBtn = Instance.new("TextButton")
        CopyBtn.Parent = OutputFrame
        CopyBtn.Size = UDim2.new(1, -16, 0, 30)
        CopyBtn.Position = UDim2.new(0, 8, 1, -38)
        CopyBtn.BackgroundColor3 = Theme.ElementActive
        CopyBtn.Font = Enum.Font.GothamBold
        CopyBtn.Text = "📋 Copy Output to Clipboard"
        CopyBtn.TextColor3 = Theme.TextPrimary
        CopyBtn.TextSize = 13
        Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 6)

        Core.Utility.RegisterConnection(CopyBtn.MouseEnter:Connect(function() UILibrary.Tween(CopyBtn, {BackgroundColor3 = Theme.ElementHover}) end))
        Core.Utility.RegisterConnection(CopyBtn.MouseLeave:Connect(function() UILibrary.Tween(CopyBtn, {BackgroundColor3 = Theme.ElementActive}) end))

        Core.Utility.RegisterConnection(CopyBtn.Activated:Connect(function()
            if type(setclipboard) == "function" then
                setclipboard(OutputBox.Text)
                local oldText = CopyBtn.Text
                CopyBtn.Text = "✔ Copied!"
                task.delay(1.5, function() CopyBtn.Text = oldText end)
            else
                local oldText = CopyBtn.Text
                CopyBtn.Text = "✘ Executor doesn't support clipboard"
                task.delay(2, function() CopyBtn.Text = oldText end)
            end
        end))

        local activeScannerBtn = nil
        local function CreateScannerButton(name, scannerFunc)
            local btn = Instance.new("TextButton")
            btn.Parent = ScannersList
            btn.Size = UDim2.new(1, -8, 0, 32)
            btn.BackgroundColor3 = Theme.ElementIdle
            btn.Font = Enum.Font.GothamBold
            btn.Text = name
            btn.TextColor3 = Theme.TextSecondary
            btn.TextSize = 11
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            Core.Utility.RegisterConnection(btn.MouseEnter:Connect(function()
                if btn ~= activeScannerBtn then UILibrary.Tween(btn, {BackgroundColor3 = Theme.ElementHover}) end
            end))
            Core.Utility.RegisterConnection(btn.MouseLeave:Connect(function()
                if btn ~= activeScannerBtn then UILibrary.Tween(btn, {BackgroundColor3 = Theme.ElementIdle}) end
            end))

            Core.Utility.RegisterConnection(btn.Activated:Connect(function()
                if activeScannerBtn then
                    UILibrary.Tween(activeScannerBtn, {BackgroundColor3 = Theme.ElementIdle, TextColor3 = Theme.TextSecondary})
                end
                activeScannerBtn = btn
                UILibrary.Tween(btn, {BackgroundColor3 = Theme.ElementActive, TextColor3 = Theme.TextPrimary})

                OutputBox.Text = "Scanning...\n"
                task.wait()
                local ok, res = pcall(scannerFunc)
                if ok then 
                    OutputBox.Text = res
                    if type(setclipboard) == "function" then
                        pcall(function() setclipboard(res) end)
                        local old = CopyBtn.Text
                        CopyBtn.Text = "📋 Auto-copied to clipboard!"
                        task.delay(2, function() CopyBtn.Text = old end)
                    end
                else 
                    OutputBox.Text = "Error during scan:\n" .. tostring(res) 
                end
            end))
        end

        local Scanners = Core.Scanners
        CreateScannerButton("Mega Scan", Scanners.MegaScan)
        CreateScannerButton("Game Data", Scanners.GameData)
        CreateScannerButton("Targeting Debug", Scanners.TargetDebug)
        CreateScannerButton("Network Remotes", Scanners.ScanRemotes)
        CreateScannerButton("Modules & Configs", Scanners.ScanConfigs)
        CreateScannerButton("Environment Map", Scanners.ScanEnvironment)
        CreateScannerButton("PlayerGui Scan", Scanners.ScanPlayerGui)
        CreateScannerButton("Team Services", Scanners.ScanTeams)
        CreateScannerButton("View Remote Log", Scanners.RemoteLog)

        -- To be called by MainLoop to build the generic settings UI
        function UI.BuildSettingsTab()
            local SettingsTab = Window:AddTab("Settings")
            SettingsTab:AddSection("SYSTEM FEATURES")
            SettingsTab:AddToggle("Auto-Respawn", Config.AutoRespawn, function(val) Config.AutoRespawn = val end)
            SettingsTab:AddToggle("Kill Feed", Config.KillFeedEnabled, function(val) Config.KillFeedEnabled = val end)
            SettingsTab:AddToggle("Target Info Overlay", Config.TargetInfoEnabled, function(val) Config.TargetInfoEnabled = val end)
            SettingsTab:AddToggle("Diagnostics Overlay", Config.DiagnosticsEnabled, function(val)
                Config.DiagnosticsEnabled = val
                if Core.Drawings and Core.Drawings.DiagnosticText then
                    Core.Drawings.DiagnosticText.Visible = val
                end
            end)
            SettingsTab:AddToggle("Remote Logger", Config.RemoteLogEnabled, function(val) Config.RemoteLogEnabled = val end)
            
            SettingsTab:AddSection("KEYBINDS")
            SettingsTab:AddKeybind("Toggle Menu", Config.MenuKey, function(key) Config.MenuKey = key end)
            SettingsTab:AddKeybind("Toggle Auto-Aim", Config.AimKey, function(key) Config.AimKey = key end)
            SettingsTab:AddKeybind("Snap to Nearest Target", Config.NearestTargetKey, function(key) Config.NearestTargetKey = key end)
            
            SettingsTab:AddSection("CONFIG")
            SettingsTab:AddButton("Save Config", function(btn)
                if Core.Config.Save then
                    local success = Core.Config:Save()
                    local oldText = btn.Text
                    btn.Text = success and "Saved!" or "Error Saving"
                    task.delay(1.5, function() btn.Text = oldText end)
                end
            end)
            SettingsTab:AddButton("Load Config", function(btn)
                if Core.Config.Load then
                    local success = Core.Config:Load()
                    local oldText = btn.Text
                    btn.Text = success and "Loaded!" or "Error Loading"
                    task.delay(1.5, function() btn.Text = oldText end)
                end
            end)
        end
    end

    return UI
end
