include("shared.lua")

-- Медшкаф: табличка, у пустого — обратный отсчёт до снабжения медблока.

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local d2 = me:GetPos():DistToSqr(self:GetPos())
    if d2 > 320 * 320 then return end

    local ready = (self:GetLootReadyAt() or 0) <= CurTime()
    local top = self:GetPos() + Vector(0, 0, 64)
    local ang = Angle(0, (me:EyePos() - top):Angle().y - 90, 90)
    cam.Start3D2D(top, ang, 0.09)
        draw.SimpleTextOutlined("МЕДШКАФ", "P11FW.NPC.Big", 0, 0,
            Color(170, 235, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        if ready then
            draw.SimpleTextOutlined("[ E ] — рыться в лекарствах", "P11FW.NPC.Small", 0, 46,
                Color(150, 235, 160, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        else
            local left = math.max(0, math.ceil((self:GetLootReadyAt() or 0) - CurTime()))
            draw.SimpleTextOutlined("пусто · снабжение через ~" .. left .. " сек", "P11FW.NPC.Small", 0, 46,
                Color(160, 165, 175, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        end
    cam.End3D2D()
end
