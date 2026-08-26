AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  НАЧАЛЬНИК КАРАУЛА — сервер v4.22.0 «ОКОВЫ»
--  Тело по образцу интенданта (v4.19.4): честный VPHYSICS,
--  стойка idle, надзор последовательности. E → оформление
--  задержанного (логика в p11_sv_cuffs).
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/player/police.mdl",
        "models/player/combine_soldier_prisonguard.mdl",
        "models/player/barney.mdl",
        "models/player/eli.mdl",
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

    local seq = self:LookupSequence("idle_subtle")
    if seq < 0 then seq = self:LookupSequence("idle") end
    if seq >= 0 then self:ResetSequence(seq) end

    self.P11_IdleSeq = seq
    self:SetCycle(math.Rand(0, 1))
    self:SetPlaybackRate(1)
    self.AutomaticFrameAdvance = true
end

function ENT:Think()
    if self.P11_IdleSeq and self.P11_IdleSeq >= 0 and self:GetSequence() ~= self.P11_IdleSeq then
        self:ResetSequence(self.P11_IdleSeq)
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:Use(activator)
    if not (IsValid(activator) and activator:IsPlayer()) then return end
    self.P11_NextUse = self.P11_NextUse or 0
    if CurTime() < self.P11_NextUse then return end
    self.P11_NextUse = CurTime() + 0.7
    if activator:GetPos():DistToSqr(self:GetPos()) > 210 * 210 then return end
    if POLUS11 and POLUS11.JailNPCUse then
        POLUS11.JailNPCUse(self, activator)
    end
end
