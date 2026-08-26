include("shared.lua")

-- Кустарный верстак: табличка + подсказка E.

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local d2 = me:GetPos():DistToSqr(self:GetPos())
    if d2 > 340 * 340 then return end

    local top = self:GetPos() + Vector(0, 0, 62)
    local ang = Angle(0, (me:EyePos() - top):Angle().y - 90, 90)
    cam.Start3D2D(top, ang, 0.09)
        draw.SimpleTextOutlined("КУСТАРНЫЙ ВЕРСТАК", "P11FW.NPC.Big", 0, 0,
            Color(185, 220, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — мастерская: все рецепты станции", "P11FW.NPC.Small", 0, 46,
            Color(150, 235, 160, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end
