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

    -- горит, потом гаснет (v4.8.3: короче + видимое угасание)
    self:SetDieTime(CurTime() + (POLUS11.Config.ChemlightTime or 300))
    -- финальные 60 секунд — мерцание/усадка (клиент читает GetDieTime)

    -- v4.8.3: ПОЛКА горящих — сверх лимита гасит самый старый,
    -- чтобы карта не зарастала вечными лампочками
    timer.Simple(0, function()
        if not IsValid(self) then return end
        local all = {}
        for _, e in ipairs(ents.FindByClass("polus11_chemlight")) do
            if IsValid(e) then all[#all + 1] = e end
        end
        table.sort(all, function(a, b) return a:GetCreationTime() < b:GetCreationTime() end)
        local cap = (POLUS11.Config and POLUS11.Config.ChemlightCap) or 14
        while #all > cap do
            local old = table.remove(all, 1)
            if IsValid(old) and old ~= self then old:Remove() end
        end
    end)
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
