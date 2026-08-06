include("shared.lua")

surface.CreateFont("P11FW.NPC.Big",   { font = "Roboto", size = 40, weight = 800, extended = true })
surface.CreateFont("P11FW.NPC.Small", { font = "Roboto", size = 26, weight = 500, extended = true })

-- ============================================================
--  v4.1: ГОЛОВА СЛЕДИТ ЗА ИГРОКОМ (pose-параметры), тело стоит.
--  head_yaw/head_pitch есть у всех ValveBiped-моделей.
-- ============================================================

local HEAD_BONE = "ValveBiped.Bip01_Head1"

function ENT:Think()
    local me = LocalPlayer()
    if not IsValid(me) then return end

    local yawId  = self:GetPoseParameterIndex("head_yaw")
    local pitId  = self:GetPoseParameterIndex("head_pitch")

    local wantYaw, wantPit = 0, 0
    if me:Alive() and me:GetPos():DistToSqr(self:GetPos()) < 420 * 420 then
        -- вектор от головы к глазам игрока в локальных координатах энтити
        local bone = self:LookupBone(HEAD_BONE)
        local headPos = (bone and self:GetBonePosition(bone)) or (self:GetPos() + Vector(0, 0, 64))
        local worldAng = (me:EyePos() - headPos):Angle()
        local localAng = self:WorldToLocalAngles(worldAng)
        wantYaw = math.Clamp(math.NormalizeAngle(localAng.y), -75, 75)
        wantPit = math.Clamp(math.NormalizeAngle(localAng.p), -40, 40)
    end

    -- плавное наведение; вне радиуса — возврат в нейтраль
    self.P11_HeadY = Lerp(FrameTime() * 5, self.P11_HeadY or 0, wantYaw)
    self.P11_HeadP = Lerp(FrameTime() * 5, self.P11_HeadP or 0, wantPit)

    if yawId and yawId >= 0 then self:SetPoseParameter("head_yaw",   self.P11_HeadY) end
    if pitId and pitId >= 0 then self:SetPoseParameter("head_pitch", self.P11_HeadP) end
    self:InvalidateBoneCache()

    self:SetNextClientThink(CurTime() + 0.03)
    return true
end

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    if me:GetPos():DistToSqr(self:GetPos()) > 550 * 550 then return end

    -- табличка над головой, всегда лицом к игроку
    local pos = self:GetPos() + Vector(0, 0, 84)
    local ang = Angle(0, (me:EyePos() - pos):Angle().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleTextOutlined(P11FW.Config.NPCName, "P11FW.NPC.Big", 0, 0,
            Color(255, 210, 110, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("[ E ] — устроиться на должность", "P11FW.NPC.Small", 0, 46,
            Color(200, 230, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        -- v3.9: «ОСОБАЯ ВАКАНСИЯ» — пульсирующая строка, пока окно открыто
        if GetGlobalFloat("P11_ThingOfferUntil", 0) > CurTime() then
            local k = 0.6 + math.sin(CurTime() * 6) * 0.4
            draw.SimpleTextOutlined("⚠ ОСОБАЯ ВАКАНСИЯ — успей нажать [ E ]", "P11FW.NPC.Small", 0, 92,
                Color(255, 80 + 60 * k, 60 + 40 * k, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 230))
        end
    cam.End3D2D()
end
