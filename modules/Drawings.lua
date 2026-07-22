return function(Core)
    local Drawings = {}

    Drawings.FOVCircle = Drawing.new("Circle")
    Drawings.FOVCircle.Visible = false
    Drawings.FOVCircle.Thickness = 1.5
    Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    Drawings.FOVCircle.Filled = false
    Drawings.FOVCircle.NumSides = 64

    Drawings.DiagnosticText = Drawing.new("Text")
    Drawings.DiagnosticText.Visible = false
    Drawings.DiagnosticText.Size = 16
    Drawings.DiagnosticText.Color = Color3.new(0, 1, 0)
    Drawings.DiagnosticText.Outline = true
    Drawings.DiagnosticText.Text = ""

    Drawings.TargetInfoText = Drawing.new("Text")
    Drawings.TargetInfoText.Visible = false
    Drawings.TargetInfoText.Size = 14
    Drawings.TargetInfoText.Color = Color3.fromRGB(255, 200, 50)
    Drawings.TargetInfoText.Outline = true
    Drawings.TargetInfoText.Center = true
    Drawings.TargetInfoText.Text = ""

    Drawings.TargetHealthBG = Drawing.new("Square")
    Drawings.TargetHealthBG.Visible = false
    Drawings.TargetHealthBG.Color = Color3.fromRGB(30, 30, 30)
    Drawings.TargetHealthBG.Filled = true
    Drawings.TargetHealthBG.Transparency = 0.4

    Drawings.TargetHealthFill = Drawing.new("Square")
    Drawings.TargetHealthFill.Visible = false
    Drawings.TargetHealthFill.Color = Color3.fromRGB(50, 200, 50)
    Drawings.TargetHealthFill.Filled = true

    Drawings.HitMarker = Drawing.new("Text")
    Drawings.HitMarker.Visible = false
    Drawings.HitMarker.Size = 30
    Drawings.HitMarker.Color = Color3.fromRGB(255, 60, 60)
    Drawings.HitMarker.Outline = true
    Drawings.HitMarker.Center = true
    Drawings.HitMarker.Text = "×"

    Drawings.LockIndicator = Drawing.new("Circle")
    Drawings.LockIndicator.Visible = false
    Drawings.LockIndicator.Thickness = 2
    Drawings.LockIndicator.Color = Color3.fromRGB(255, 50, 50)
    Drawings.LockIndicator.Filled = false
    Drawings.LockIndicator.NumSides = 4
    Drawings.LockIndicator.Radius = 12

    -- Pre-allocate kill feed slots at a safe max; actual count is read live from Config (#16)
    local KILLFEED_MAX_SLOTS = 12
    Drawings.GetMaxKillFeed = function() return Core.Config.MaxKillFeed or 6 end
    Drawings.MAX_KILLFEED = KILLFEED_MAX_SLOTS -- kept for backwards compat; use GetMaxKillFeed() for live value
    Drawings.KillFeedDrawings = {}
    for i = 1, KILLFEED_MAX_SLOTS do
        local txt = Drawing.new("Text")
        txt.Visible = false
        txt.Size = 14
        txt.Color = Color3.new(1, 1, 1)
        txt.Outline = true
        txt.Center = false
        txt.Text = ""
        -- In some executors, there isn't a direct TextXAlignment for Drawings.Text
        -- But for those that support it or custom wrappers, we could set it. 
        -- However, Drawing API usually expects us to calculate text bounds ourselves if we want true right-align.
        -- For now we just position it by its top-left and let it flow right. To right align, we need to subtract TextBounds.X from the position later in the render loop.
        Drawings.KillFeedDrawings[i] = txt
    end

    function Drawings.Init()
        Core.EventManager:Subscribe("OnRender", "HUDRender", function(ctx)
            local Config = Core.Config
            local State = Core.State
            local viewport = ctx.ViewportSize

            -- ==================== DIAGNOSTICS OVERLAY ====================
            if Config.DiagnosticsEnabled then
                Drawings.DiagnosticText.Visible = true
                Drawings.DiagnosticText.Position = Vector2.new(10, 10)
                local diagLines = {
                    string.format("FPS: %d | Ping: %dms", ctx.FPS, ctx.NetworkPing),
                    "Aim: " .. (Config.AutoAimEnabled and "ON" or "OFF") .. " | State: " .. tostring(State.AimState),
                    "Method: " .. Config.TrackingMethod .. " | Focus: " .. Config.FocusPoint,
                    string.format("Smooth: %.2f | FOV: %d", Config.Smoothing, Config.ViewAngle),
                    string.format("K: %d  D: %d  A: %d", State.KillCount, State.DeathCount, State.AssistCount),
                }
                Drawings.DiagnosticText.Text = table.concat(diagLines, "\n")
            else
                Drawings.DiagnosticText.Visible = false
            end

            -- ==================== TARGET INFO OVERLAY ====================
            if Config.TargetInfoEnabled and State.CurrentTarget and State.CurrentTarget.Parent and ctx.Camera then
                local target = State.CurrentTarget
                local char = target.Parent
                local sp, onScreen = ctx.Camera:WorldToScreenPoint(target.Position)

                if onScreen then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hp = hum and hum.Health or 0
                    local maxHp = hum and hum.MaxHealth or 100

                    -- Clamp position within viewport bounds
                    local clampedX = math.clamp(sp.X, 40, viewport.X - 40)
                    local clampedY = math.clamp(sp.Y, 50, viewport.Y - 20)

                    -- Target name text
                    Drawings.TargetInfoText.Text = char.Name
                    Drawings.TargetInfoText.Position = Vector2.new(clampedX, clampedY - 50)
                    Drawings.TargetInfoText.Visible = true

                    -- Health bar background
                    local barW = 60
                    local barH = 5
                    Drawings.TargetHealthBG.Size = Vector2.new(barW, barH)
                    Drawings.TargetHealthBG.Position = Vector2.new(clampedX - barW / 2, clampedY - 38)
                    Drawings.TargetHealthBG.Visible = true

                    -- Health bar fill
                    local hpPct = math.clamp(hp / math.max(maxHp, 1), 0, 1)
                    Drawings.TargetHealthFill.Size = Vector2.new(barW * hpPct, barH)
                    Drawings.TargetHealthFill.Position = Vector2.new(clampedX - barW / 2, clampedY - 38)
                    if hpPct > 0.6 then
                        Drawings.TargetHealthFill.Color = Color3.fromRGB(50, 200, 50)
                    elseif hpPct > 0.3 then
                        Drawings.TargetHealthFill.Color = Color3.fromRGB(255, 200, 50)
                    else
                        Drawings.TargetHealthFill.Color = Color3.fromRGB(255, 60, 60)
                    end
                    Drawings.TargetHealthFill.Visible = true

                    -- Lock indicator (diamond around target)
                    Drawings.LockIndicator.Position = Vector2.new(clampedX, clampedY)
                    Drawings.LockIndicator.Visible = true
                else
                    Drawings.TargetInfoText.Visible = false
                    Drawings.TargetHealthBG.Visible = false
                    Drawings.TargetHealthFill.Visible = false
                    Drawings.LockIndicator.Visible = false
                end
            else
                Drawings.TargetInfoText.Visible = false
                Drawings.TargetHealthBG.Visible = false
                Drawings.TargetHealthFill.Visible = false
                Drawings.LockIndicator.Visible = false
            end

            -- ==================== HIT MARKER ====================
            local hitAge = os.clock() - State.HitMarkerTime
            if hitAge < 0.3 then
                Drawings.HitMarker.Position = Vector2.new(viewport.X / 2, viewport.Y / 2)
                Drawings.HitMarker.Visible = true
                -- Fade out based on age
                Drawings.HitMarker.Transparency = math.clamp(1 - (hitAge / 0.3), 0, 1)
            else
                Drawings.HitMarker.Visible = false
            end

            -- ==================== KILL FEED ====================
            if Config.KillFeedEnabled then
                local maxFeed = Drawings.GetMaxKillFeed()
                local now = os.clock()
                for i = 1, KILLFEED_MAX_SLOTS do
                    local entry = State.KillFeedEntries[i]
                    local drawing = Drawings.KillFeedDrawings[i]
                    if entry and i <= maxFeed then
                        local age = now - entry.time
                        if age < 5 then
                            drawing.Text = entry.text
                            drawing.Color = entry.color
                            drawing.Position = Vector2.new(viewport.X - 10 - drawing.TextBounds.X, 10 + (i - 1) * 18)
                            drawing.Visible = true
                            -- Fade out in last second
                            if age > 4 then
                                drawing.Transparency = math.clamp(1 - (age - 4), 0, 1)
                            else
                                drawing.Transparency = 1
                            end
                        else
                            drawing.Visible = false
                        end
                    else
                        drawing.Visible = false
                    end
                end
            else
                for i = 1, KILLFEED_MAX_SLOTS do
                    Drawings.KillFeedDrawings[i].Visible = false
                end
            end
        end)
    end

    return Drawings
end
