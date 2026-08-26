include("shared.lua")

-- ============================================================
--  ТРАНСПОРТНИК «ЯНКИ-АВТО» (США) — клиент (v4.31.0 «КРЫЛО»)
--  Вывеска 3D2D + ПОЧИНКА АНИМАЦИИ: клиентский FrameAdvance —
--  даже если двигательский авто-проигрыш где-то тонет, торговец
--  дышит, а не стоит T-pose'ом (заявка «нет анимаций у нпс»).
-- ============================================================

surface.CreateFont("P11.Garage.Big",   { font = "Roboto", size = 36, weight = 800, extended = true })
surface.CreateFont("P11.Garage.Small", { font = "Roboto", size = 22, weight = 500, extended = true })

function ENT:Initialize()
    -- клиентский тик уже пошёл: плавно крутим стойку
    self:SetNextClientThink(CurTime())
end

function ENT:Think()
    -- страховка анимации на клиенте (главное — AutomaticFrameAdvance на сервере)
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
    if me:GetPos():DistToSqr(self:GetPos()) > 550 * 550 then return end

    local pos = self:GetPos() + Vector(0, 0, 86)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleTextOutlined("🦅 ЯНКИ-АВТО (США)", "P11.Garage.Big", 0, 0,
            Color(120, 175, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — транспорт американской стороны", "P11.Garage.Small", 0, 42,
            Color(215, 230, 245, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end
