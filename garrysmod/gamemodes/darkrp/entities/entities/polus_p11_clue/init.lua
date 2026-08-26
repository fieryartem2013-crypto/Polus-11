AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — УЛИКА (v4.20.0 «СЛЕД»): след на месте поглощения.
--  Спавнит modules/p11_sv_clues.lua (hook Polus11.ThingDevoured).
-- ============================================================

function ENT:Initialize()
    local m = "models/props_c17/paper01.mdl"
    if file.Exists(m, "GAME") then self:SetModel(m) end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    util.DropToFloor(self)
    self.P11_SpawnT = self.P11_SpawnT or CurTime()
end

-- серверный модуль меняет «вещь» после спавна
function ENT:P11ApplyLook()
    local m = self.P11_Model
    if isstring(m) and file.Exists(m, "GAME") then
        self:SetModel(m)
        self:PhysicsInit(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        util.DropToFloor(self)
    end
end

function ENT:Think()
    if self.P11_DieT and CurTime() > self.P11_DieT then
        self:Remove()
        return
    end
    self:NextThink(CurTime() + 5)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 140 * 140 then return end
    self.NextUseT = self.NextUseT or 0
    if CurTime() < self.NextUseT then return end
    self.NextUseT = CurTime() + 0.6
    if POLUS11.ClueCollect then
        POLUS11.ClueCollect(activator, self)
    end
end
