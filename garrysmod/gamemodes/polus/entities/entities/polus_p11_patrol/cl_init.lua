include("shared.lua")

-- кольцо поста + мягкая подсветка для тех, кто в патруле
function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local d2 = me:GetPos():DistToSqr(self:GetPos())
    if d2 > 900 * 900 then return end

    -- кольцо на земле вокруг столба
    local pos = self:GetPos()
    cam.Start3D2D(pos + Vector(0, 0, 2), Angle(0, 0, 0), 1)
        local r = 55 + math.sin(CurTime() * 2) * 4
        surface.SetDrawColor(120, 180, 255, 120)
        for i = 0, 23 do
            local a1 = math.rad(i / 24 * 360)
            local a2 = math.rad((i + 1) / 24 * 360)
            surface.DrawLine(math.cos(a1) * r, math.sin(a1) * r,
                             math.cos(a2) * r, math.sin(a2) * r)
        end
    cam.End3D2D()

    if d2 > 260 * 260 then return end
    local ang = Angle(0, (me:EyePos() - (pos + Vector(0, 0, 70))):Angle().y - 90, 90)
    cam.Start3D2D(pos + Vector(0, 0, 70), ang, 0.08)
        draw.SimpleTextOutlined("ПОСТ ПАТРУЛЯ №" .. (self:GetPatrolId() or 0), "P11FW.NPC.Small", 0, 0,
            Color(140, 200, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 210))
    cam.End3D2D()
end
