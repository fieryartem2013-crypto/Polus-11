include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 450 * 450 then return end

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 80), ang, 0.12)
        draw.RoundedBox(6, -210, -26, 420, 52, Color(0, 0, 0, 165))
        local txt = self:GetTesting() and "КАЛИБРОВКА АНАЛИЗАТОРА..." or "АНАЛИЗАТОР «КРОВЬ-2»"
        local col = self:GetTesting() and Color(255, 210, 100) or Color(160, 215, 255)
        draw.SimpleText(txt, "P11.Gen.Small", 0, -24, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(self:GetTesting() and "" or "E с колбой в руках — анализ (мини-игра)", "P11.Gen.Tiny", 0, 2, Color(140, 155, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
