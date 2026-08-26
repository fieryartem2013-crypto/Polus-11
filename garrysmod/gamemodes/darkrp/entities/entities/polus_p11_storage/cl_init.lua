include("shared.lua")

surface.CreateFont("P11.SafeNPC.Big",   { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11.SafeNPC.Small", { font = "Roboto", size = 20, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 450 * 450 then return end

    local pos = self:GetPos() + Vector(0, 0, 62)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleTextOutlined("ЛИЧНЫЙ СЕЙФ", "P11.SafeNPC.Big", 0, 0,
            Color(140, 200, 250, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — положить или забрать предметы", "P11.SafeNPC.Small", 0, 34,
            Color(190, 220, 245, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end
