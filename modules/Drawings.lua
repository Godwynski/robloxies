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

    Drawings.MAX_KILLFEED = 6
    Drawings.KillFeedDrawings = {}
    for i = 1, Drawings.MAX_KILLFEED do
        local txt = Drawing.new("Text")
        txt.Visible = false
        txt.Size = 14
        txt.Color = Color3.new(1, 1, 1)
        txt.Outline = true
        txt.Text = ""
        Drawings.KillFeedDrawings[i] = txt
    end

    return Drawings
end
