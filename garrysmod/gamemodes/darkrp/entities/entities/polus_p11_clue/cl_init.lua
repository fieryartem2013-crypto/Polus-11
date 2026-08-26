include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — УЛИКА (client): модель + парящая бирка «УЛИКА».
-- ============================================================

surface.CreateFont("P11.Clue3D", { font = "Roboto", size = 44, weight = 800, extended = true })
surface.CreateFont("P11.Clue3D.Small", { font = "Roboto", size = 30, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 900 * 900 then return end

    local kind = self:GetNWString("P11_ClueKind", "улика")
    local pos = self:GetPos() + Vector(0, 0, 16)
    local ang = Angle(0, me:EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.055)
        draw.SimpleText("УЛИКА", "P11.Clue3D", 0, 0, Color(255, 90, 80, 235),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(kind .. "  [E]", "P11.Clue3D.Small", 0, 44, Color(232, 238, 245, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
