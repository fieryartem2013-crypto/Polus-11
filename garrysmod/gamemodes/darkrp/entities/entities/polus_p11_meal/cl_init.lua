include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 220 * 220 then return end

    -- «парит» от горячего
    local pos = self:GetPos() + Vector(0, 0, 24 + math.sin(CurTime() * 3) * 2)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.07)
        draw.SimpleTextOutlined("ГОРЯЧИЙ ПАЁК — [ E ] съесть", "P11FW.NPC.Small", 0, 0,
            Color(255, 220, 140, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 210))
    cam.End3D2D()
end
