AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/flare.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    -- горит, потом гаснет
    self:SetDieTime(CurTime() + (POLUS11.Config.ChemlightTime or 600))
    -- финальные 30 секунд — мерцание (клиент читает GetDieTime)
end

function ENT:PhysicsCollide(data)
    if data.Speed > 60 then
        self:EmitSound("ambient/energy/zap1.wav", 45, 140)
    end
end

function ENT:Think()
    if CurTime() > self:GetDieTime() then
        self:Remove()
        return
    end
    self:NextThink(CurTime() + 1)
    return true
end
