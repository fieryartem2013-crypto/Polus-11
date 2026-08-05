include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 450 * 450 then return end

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 80), ang, 0.12)
        draw.RoundedBox(6, -200, -26, 400, 52, Color(0, 0, 0, 160))
        local txt = self:GetTesting() and "ИДЁТ ТЕСТ КРОВИ..." or "ЛАБОРАТОРНЫЙ СТОЛ"
        local col = self:GetTesting() and Color(255, 210, 100) or Color(150, 200, 255)
        draw.SimpleText(txt, "P11.Gen.Small", 0, -24, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
