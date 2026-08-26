include("shared.lua")

-- Буржуйка «УГЛИ»: табличка + янтарный свет, когда горит.

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local d2 = me:GetPos():DistToSqr(self:GetPos())

    local left = math.max(0, (self:GetBurnUntil() or 0) - CurTime())

    -- жар светит на округу
    if left > 0 then
        local dl = DynamicLight(self:EntIndex())
        if dl then
            dl.pos      = self:GetPos() + Vector(0, 0, 26)
            dl.r        = 255
            dl.g        = 150
            dl.b        = 70
            dl.brightness = 2 + math.sin(CurTime() * 9) * 0.6
            dl.size     = 300
            dl.decay    = 1000
            dl.dietime  = CurTime() + 0.2
        end
    end

    if d2 > 340 * 340 then return end
    local top = self:GetPos() + Vector(0, 0, 62)
    local ang = Angle(0, (me:EyePos() - top):Angle().y - 90, 90)
    cam.Start3D2D(top, ang, 0.09)
        draw.SimpleTextOutlined("БУРЖУЙКА «УГЛИ»", "P11FW.NPC.Big", 0, 0,
            Color(255, 190, 120, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        if left > 0 then
            draw.SimpleTextOutlined("🔥 горит · жар ещё ~" .. math.ceil(left) .. " сек", "P11FW.NPC.Small", 0, 46,
                Color(255, 170, 90, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
            draw.SimpleTextOutlined("[ E ] — подкинуть: солярка +4 мин / спирт +1.5 мин", "P11FW.NPC.Small", 0, 72,
                Color(235, 220, 190, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        else
            draw.SimpleTextOutlined("холодная · [ E ] — кинуть топливо (солярка/спирт из 🎒)", "P11FW.NPC.Small", 0, 46,
                Color(160, 165, 175, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        end
    cam.End3D2D()
end
