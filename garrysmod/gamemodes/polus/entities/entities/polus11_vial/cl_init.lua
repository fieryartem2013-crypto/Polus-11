include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 350 * 350 then return end

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 16), ang, 0.06)
        draw.RoundedBox(6, -150, -26, 300, 52, Color(0, 0, 0, 170))
        draw.SimpleText("Кровь: " .. self:GetDonorName(), "P11.Gen.Small", 0, -24, Color(255, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
