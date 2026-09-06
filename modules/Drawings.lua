return function(Core)
    local Drawings = {}

    local function safeDrawingNew(drawingType)
        if type(Drawing) == "table" and type(Drawing.new) == "function" then
            local ok, obj = pcall(Drawing.new, drawingType)
            if ok and obj then return obj end
        end
        return {
            Visible = false,
            Transparency = 1,
            Color = Color3.new(1, 1, 1),
            Thickness = 1,
            Position = Vector2.zero,
            Size = Vector2.zero,
            Radius = 0,
            Filled = false,
            Text = "",
            Center = false,
            Outline = false,
            From = Vector2.zero,
            To = Vector2.zero,
            TextBounds = Vector2.new(50, 14),
            Destroy = function() end,
            Remove = function() end,
        }
    end

    Drawings.FOVCircle = safeDrawingNew("Circle")
    Drawings.FOVCircle.Visible = false
    Drawings.FOVCircle.Thickness = 1.5
    Drawings.FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    Drawings.FOVCircle.Filled = false

    Drawings.TargetInfoText = safeDrawingNew("Text")
    Drawings.TargetInfoText.Visible = false
    Drawings.TargetInfoText.Size = 14
    Drawings.TargetInfoText.Color = Color3.fromRGB(255, 200, 50)
    Drawings.TargetInfoText.Outline = true
    Drawings.TargetInfoText.Center = true
    Drawings.TargetInfoText.Text = ""

    Drawings.TargetHealthBG = safeDrawingNew("Square")
    Drawings.TargetHealthBG.Visible = false
    Drawings.TargetHealthBG.Color = Color3.fromRGB(30, 30, 30)
    Drawings.TargetHealthBG.Filled = true
    Drawings.TargetHealthBG.Transparency = 0.4

    Drawings.TargetHealthFill = safeDrawingNew("Square")
    Drawings.TargetHealthFill.Visible = false
    Drawings.TargetHealthFill.Color = Color3.fromRGB(50, 200, 50)
    Drawings.TargetHealthFill.Filled = true

    Drawings.HitMarker = safeDrawingNew("Text")
    Drawings.HitMarker.Visible = false
    Drawings.HitMarker.Size = 30
    Drawings.HitMarker.Color = Color3.fromRGB(255, 60, 60)
    Drawings.HitMarker.Outline = true
    Drawings.HitMarker.Center = true
    Drawings.HitMarker.Text = "×"

    Drawings.LockIndicator = safeDrawingNew("Circle")
    Drawings.LockIndicator.Visible = false
    Drawings.LockIndicator.Thickness = 2
    Drawings.LockIndicator.Color = Color3.fromRGB(255, 50, 50)
    Drawings.LockIndicator.Filled = false
    Drawings.LockIndicator.Radius = 12

    -- Pre-allocate kill feed slots at a safe max; actual count is read live from Config (#16)
    local KILLFEED_MAX_SLOTS = 12
    Drawings.GetMaxKillFeed = function() return Core.Config.MaxKillFeed or 6 end
    Drawings.MAX_KILLFEED = KILLFEED_MAX_SLOTS -- kept for backwards compat; use GetMaxKillFeed() for live value
    Drawings.KillFeedDrawings = {}
    for i = 1, KILLFEED_MAX_SLOTS do
        local txt = safeDrawingNew("Text")
        txt.Visible = false
        txt.Size = 14
        txt.Color = Color3.new(1, 1, 1)
        txt.Outline = true
        txt.Center = false
        txt.Text = ""
        Drawings.KillFeedDrawings[i] = txt
    end

    function Drawings.Init()
        Core.EventManager:Subscribe("OnRender", "HUDRender", function(ctx)
            local Config = Core.Config
            local State = Core.State
            local viewport = ctx.ViewportSize



            -- ==================== TARGET INFO OVERLAY ====================
            if Config.TargetInfoEnabled and State.CurrentTarget and State.CurrentTarget.Parent and ctx.Camera then
                local target = State.CurrentTarget
                local char = target.Parent
                local sp, onScreen = ctx.Camera:WorldToScreenPoint(target.Position)

                local hum = char:FindFirstChildOfClass("Humanoid")
                local hp = hum and hum.Health or 0
                local maxHp = hum and hum.MaxHealth or 100

                if onScreen and hp > 0 then
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
                            local textWidth = (drawing.TextBounds and drawing.TextBounds.X) or (#entry.text * 7)
                            drawing.Position = Vector2.new(viewport.X - 10 - textWidth, 10 + (i - 1) * 18)
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
