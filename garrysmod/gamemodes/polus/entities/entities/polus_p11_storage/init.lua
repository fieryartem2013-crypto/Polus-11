AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local models = {
        "models/props_c17/lockersingle.mdl",
        "models/props_lab/filecabinet02.mdl",
        "models/props_c17/suitcase001a.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:SetMass(200) phys:EnableMotion(false) end
    util.DropToFloor(self)
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 160 * 160 then return end
    self.NextUseT = self.NextUseT or 0
    if CurTime() < self.NextUseT then return end
    self.NextUseT = CurTime() + 0.6
    if POLUS11.OpenStorageUI then
        POLUS11.OpenStorageUI(activator, self)
    end
end
