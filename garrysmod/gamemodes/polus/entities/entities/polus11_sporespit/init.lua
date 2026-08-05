-- ============================================================
--  ПОЛЮС-11 — снаряд спор (летит из Споровика, по касанию
--  превращается в polus11_sporecloud)
-- ============================================================

AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/misc/sphere075.mdl")
    self:SetMaterial("models/debug/debugwhite")
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(120, 220, 110, 210))
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))
    self:SetTrigger(true)
    self:PhysicsInitSphere(4)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self.DieAt = CurTime() + 4
end

function ENT:Burst()
    if self.Done then return end
    self.Done = true

    local cloud = ents.Create("polus11_sporecloud")
    if IsValid(cloud) then
        cloud:SetPos(self:GetPos())
        cloud:SetOwner(self:GetOwner())
        cloud:Spawn()
    end

    self:EmitSound("ambient/levels/canals/toxic_slime_sizzle2.wav", 75, 80)
    self:Remove()
end

function ENT:Touch(hit)
    if hit == self:GetOwner() then return end
    if IsValid(hit) then self:Burst() end
end

function ENT:PhysicsCollide(data)
    self:Burst()
end

function ENT:Think()
    if CurTime() > self.DieAt then
        self:Burst()
        return
    end
    self:NextThink(CurTime() + 0.5)
    return true
end
