include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 400 * 400 then return end

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 68), ang, 0.1)
        draw.RoundedBox(6, -140, -30, 280, 60, Color(0, 0, 0, 160))
        draw.SimpleText("ТОПЛИВО", "P11.Gen.Small", 0, -26, Color(255, 200, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("E у генератора — заправить", "P11.Gen.Small", 0, 2, Color(230, 230, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
