include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 260 * 260 then return end

    local pos = self:GetPos() + Vector(0, 0, 58)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleTextOutlined("ПОЛЕВАЯ КУХНЯ — [ E ] (повар)", "P11FW.NPC.Small", 0, 0,
            Color(255, 200, 110, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 210))
    cam.End3D2D()
end
