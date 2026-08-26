include("shared.lua")

-- ============================================================
--  НАЧАЛЬНИК КАРАУЛА — клиент v4.22.0 «ОКОВЫ»
--  Модель + плавающая вывеска (3D2D), дальность 900 юн.
-- ============================================================

surface.CreateFont("P11.JailNPC.Name", { font = "Roboto", size = 42, weight = 700, extended = true })
surface.CreateFont("P11.JailNPC.Sub",  { font = "Roboto", size = 24, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:GetPos():DistToSqr(self:GetPos()) > 900 * 900 then return end

    local ang = lp:EyeAngles()
    ang = Angle(0, ang.y - 90, 90)
    cam.Start3D2D(self:GetPos() + Vector(0, 0, 82), ang, 0.09)
        draw.SimpleText("■ НАЧАЛЬНИК КАРАУЛА", "P11.JailNPC.Name", 0, -24,
            Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("веди задержанного — оформит камеру", "P11.JailNPC.Sub", 0, 18,
            Color(235, 235, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
