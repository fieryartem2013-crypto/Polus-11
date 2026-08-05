include("shared.lua")

surface.CreateFont("P11FW.NPC.Big",   { font = "Roboto", size = 40, weight = 800, extended = true })
surface.CreateFont("P11FW.NPC.Small", { font = "Roboto", size = 26, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 550 * 550 then return end

    -- табличка над головой, всегда лицом к игроку
    local pos = self:GetPos() + Vector(0, 0, 84)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleTextOutlined(P11FW.Config.NPCName, "P11FW.NPC.Big", 0, 0,
            Color(255, 210, 110, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — устроиться на должность", "P11FW.NPC.Small", 0, 46,
            Color(200, 230, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        -- v3.9: «ОСОБАЯ ВАКАНСИЯ» — пульсирующая строка, пока окно открыто
        if GetGlobalFloat("P11_ThingOfferUntil", 0) > CurTime() then
            local k = 0.6 + math.sin(CurTime() * 6) * 0.4
            draw.SimpleTextOutlined("⚠ ОСОБАЯ ВАКАНСИЯ — успей нажать [ E ]", "P11FW.NPC.Small", 0, 92,
                Color(255, 80 + 60 * k, 60 + 40 * k, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 230))
        end
    cam.End3D2D()
end
