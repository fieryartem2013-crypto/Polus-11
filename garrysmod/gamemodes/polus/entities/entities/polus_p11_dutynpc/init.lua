AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  НПС «ДЕЖУРНЫЙ ГЛАВЫ» (v5.2.3)
--  E → меню поста: КПП 2 / КПП · Приезжая часть / Поверхность /
--  Комплекс за Сотрудником. Логика: p11_sv_duty.lua.
--  Паттерн копирует рабочий ларёк (polus_p11_shopnpc):
--  VPHYSICS-тело с самолечением в BBOX-коробку, стойка с
--  надзором, честный +use.
-- ============================================================

function ENT:Initialize()
    -- модель: человек → ящик (есть у всех) → error
    local models = {
        "models/player/eli.mdl",
        "models/player/barney.mdl",
        "models/player/kleiner.mdl",
        "models/props_junk/wood_crate002a.mdl",
        "models/error.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    else
        self:PhysicsDestroy()
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        local mins, maxs = self:OBBMins(), self:OBBMaxs()
        if not mins or not maxs or (maxs.z - mins.z) < 8 then
            mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 72)
        end
        self:SetCollisionBounds(mins, maxs)
    end

    util.DropToFloor(self)

    -- беззвучная стойка, если модель её поддерживает
    local seq = self:LookupSequence("idle_subtle")
    if seq < 0 then seq = self:LookupSequence("idle") end
    if seq >= 0 then self:ResetSequence(seq) end
    self.P11_IdleSeq = seq
    self:SetCycle(math.Rand(0, 1))
    self:SetPlaybackRate(1)
    self.AutomaticFrameAdvance = true
end

function ENT:Think()
    self.P11_NextGuard = self.P11_NextGuard or 0
    if CurTime() >= self.P11_NextGuard then
        self.P11_NextGuard = CurTime() + 0.5
        if self.GetSequence and self.P11_IdleSeq ~= nil and self.P11_IdleSeq >= 0 then
            local ok, cur = pcall(self.GetSequence, self)
            if ok and cur ~= self.P11_IdleSeq then
                self:ResetSequence(self.P11_IdleSeq)
                self:SetPlaybackRate(1)
                self.AutomaticFrameAdvance = true
            end
        end
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 180 * 180 then return end
    self.NextUseT = self.NextUseT or 0
    if CurTime() < self.NextUseT then return end
    self.NextUseT = CurTime() + 0.6
    if POLUS11 and POLUS11.OpenDutyUI then
        POLUS11.OpenDutyUI(activator, self)
    else
        activator:ChatPrint("[ПОЛЮС-11] Модуль дежурств не проснулся — смотри [POLUS][ERROR] в консоли сервера.")
    end
end
