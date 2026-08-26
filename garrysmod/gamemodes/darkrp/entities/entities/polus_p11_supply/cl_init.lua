include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local d2 = me:GetPos():DistToSqr(self:GetPos())
    if d2 > 1500 * 1500 then return end

    -- маяк: столб света вверх
    local pos = self:GetPos()
    render.SetColorMaterial()
    render.DrawBeam(pos, pos + Vector(0, 0, 500), 8, 0, 1,
        Color(255, 190, 90, 120 + 80 * math.abs(math.sin(CurTime() * 4))))

    if d2 > 300 * 300 then return end
    local top = pos + Vector(0, 0, 66)
    local ang = Angle(0, (me:EyePos() - top):Angle().y - 90, 90)
    cam.Start3D2D(top, ang, 0.09)
        draw.SimpleTextOutlined("ЯЩИК СНАБЖЕНИЯ", "P11FW.NPC.Big", 0, 0,
            Color(255, 200, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        local p = self:GetOpenProgress() or 0
        draw.SimpleTextOutlined(p > 0 and ("вскрывается… " .. math.floor(p * 100) .. "%") or "[ E ] — вскрыть (держать)",
            "P11FW.NPC.Small", 0, 46, Color(200, 230, 255, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end
