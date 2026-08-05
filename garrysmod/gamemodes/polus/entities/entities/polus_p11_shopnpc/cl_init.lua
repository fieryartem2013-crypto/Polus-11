include("shared.lua")

surface.CreateFont("P11.ShopNPC.Big",   { font = "Roboto", size = 34, weight = 800, extended = true })
surface.CreateFont("P11.ShopNPC.Small", { font = "Roboto", size = 22, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 500 * 500 then return end

    local pos = self:GetPos() + Vector(0, 0, 84)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleTextOutlined("ЛАРЁК СНАБЖЕНИЯ", "P11.ShopNPC.Big", 0, 0,
            Color(255, 200, 90, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — приобрести снаряжение и пайки", "P11.ShopNPC.Small", 0, 40,
            Color(210, 235, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end
