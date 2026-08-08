include("shared.lua")

-- Терминал диспетчера «ГЛАЗ»: модель + табличка с допуском.

surface.CreateFont("P11.Dsp.TermTag",  { font = "Arial", size = 64, weight = 900, extended = true })
surface.CreateFont("P11.Dsp.TermSub",  { font = "Arial", size = 40, weight = 700, extended = true })

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:GetPos():DistToSqr(self:GetPos()) > 460 * 460 then return end

    local pos = self:GetPos() + Vector(0, 0, 118)
    local ang = lp:EyeAngles()
    ang = Angle(0, ang.y - 90, 90)

    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleText("ТЕРМИНАЛ ДИСПЕТЧЕРА «ГЛАЗ»", "P11.Dsp.TermTag", 0, 0,
            Color(160, 195, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("E — сесть за пульт (допуск: ДИСПЕТЧЕР / администрация)", "P11.Dsp.TermSub", 0, 78,
            Color(130, 150, 175, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
