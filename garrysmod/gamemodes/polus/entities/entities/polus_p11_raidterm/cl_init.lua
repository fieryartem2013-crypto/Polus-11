include("shared.lua")

-- ============================================================
--  ТЕРМИНАЛ РЕЙДА — клиент v4.24.0 «РУБЕЖ»
--  Модель консоли + плавающая вывеска (3D2D), дальность 900 юн.
-- ============================================================

surface.CreateFont("P11.RaidTerm.Name", { font = "Roboto", size = 40, weight = 700, extended = true })
surface.CreateFont("P11.RaidTerm.Sub",  { font = "Roboto", size = 22, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:GetPos():DistToSqr(self:GetPos()) > 900 * 900 then return end

    local ang = lp:EyeAngles()
    ang = Angle(0, ang.y - 90, 90)
    cam.Start3D2D(self:GetPos() + Vector(0, 0, 64), ang, 0.09)
        draw.SimpleText("■ ТЕРМИНАЛ РЕЙДА", "P11.RaidTerm.Name", 0, -24,
            Color(255, 150, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("командир объявляет рейд — E", "P11.RaidTerm.Sub", 0, 18,
            Color(240, 220, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
