include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 300 * 300 then return end

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 22), ang, 0.08)
        draw.RoundedBox(6, -170, -26, 340, 52, Color(0, 0, 0, 170))
        draw.SimpleText("«УКОЛ-С» — инъектор (E: мини-игра лечения)", "P11.Gen.Small", 0, -24, Color(160, 235, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("зарядов: " .. self:GetCharges(), "P11.Gen.Tiny", 0, 0, Color(140, 155, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
