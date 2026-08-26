include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local dist = ply:GetPos():DistToSqr(self:GetPos())
    if dist > 300 * 300 then return end

    local ang = self:GetAngles()
    local pos = self:GetPos() + Vector(0, 0, 74)

    cam.Start3D2D(pos, Angle(0, ang.y + 90, 90), 0.11)
        draw.SimpleText("СМЕННЫЙ ТЕРМИНАЛ", "P11.Terminal3D", 0, 0, Color(120, 210, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if dist < 140 * 140 then
            draw.SimpleText("E — доп. задачи экипажу (нужен допуск)", "P11.Terminal3D.S", 0, 24, Color(170, 190, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

surface.CreateFont("P11.Terminal3D",   { font = "Roboto", size = 42, weight = 800, extended = true })
surface.CreateFont("P11.Terminal3D.S", { font = "Roboto", size = 24, weight = 400, extended = true })
