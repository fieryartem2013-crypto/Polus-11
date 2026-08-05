AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/hunter/misc/sphere075.mdl")
    self:SetMaterial("models/debug/debugwhite")
    self:SetRenderMode(RENDERMODE_TRANSALPHA) -- иначе альфа цвета не работает
    self:SetColor(Color(80, 255, 80, 200))
    self:SetMoveType(MOVETYPE_VPHYSICS) -- полёт по физике: дуга с гравитацией
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))
    self:SetTrigger(true)
    self:PhysicsInitSphere(4)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self.DieAt = CurTime() + 4
end

function ENT:Think()
    if CurTime() > self.DieAt then
        self:Remove()
        return
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:Touch(hit)
    if hit == self:GetOwner() then return end
    if self.Done then return end
    self.Done = true

    local pos = self:GetPos()

    -- кислотный всплеск
    for _, ent in ipairs(ents.FindInSphere(pos, 90)) do
        if ent:IsPlayer() or ent:IsNPC() then
            local dmg = DamageInfo()
            dmg:SetDamage(22)
            dmg:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_ACID)
            dmg:SetDamagePosition(ent:GetPos() + Vector(0, 0, 30))
            ent:TakeDamageInfo(dmg)
        end
    end

    local ed = EffectData()
    ed:SetOrigin(pos)
    util.Effect("sparks", ed, true, true)
    util.Effect("smoke_trail", ed, true, true)

    self:EmitSound("ambient/levels/canals/toxic_slime_sizzle3.wav", 70, 100)
    self:Remove()
end
