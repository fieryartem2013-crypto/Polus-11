include("shared.lua")

surface.CreateFont("P11.ConNPC.Big",   { font = "Roboto", size = 34, weight = 800, extended = true })
surface.CreateFont("P11.ConNPC.Small", { font = "Roboto", size = 20, weight = 500, extended = true })

-- страховка анимации на клиенте (паттерн ларька v4.10.0)
function ENT:Initialize()
    self:SetNextClientThink(CurTime())
end

function ENT:Think()
    if self.GetSequence and self.GetPlaybackRate then
        pcall(function()
            if self:GetPlaybackRate() == 0 then self:SetPlaybackRate(1) end
            self:FrameAdvance()
        end)
    end
    self:SetNextClientThink(CurTime() + 0.05)
    return true
end

function ENT:Draw()
    self:DrawModel()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 500 * 500 then return end

    local pos = self:GetPos() + Vector(0, 0, 84)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleTextOutlined("ИНТЕНДАНТ — НАРЯДНИК", "P11.ConNPC.Big", 0, 0,
            Color(255, 205, 100, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — контракты часа за большие деньги", "P11.ConNPC.Small", 0, 40,
            Color(180, 210, 240, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end
