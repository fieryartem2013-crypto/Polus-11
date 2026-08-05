AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_c17/oildrum001.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(90)
    end
end

-- E по бочке рядом с генератором = заправить генератор
function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local gen = nil
    local best = 230 * 230
    for _, e in ipairs(ents.FindByClass("polus11_generator")) do
        local d = e:GetPos():DistToSqr(self:GetPos())
        if d < best then
            best = d
            gen = e
        end
    end

    if IsValid(gen) then
        gen:AddFuelBarrel(1)
        if POLUS11.TaskEvent then POLUS11.TaskEvent(activator, "refuel_gen") end -- задача инженера/повара
        POLUS11.Notify(activator, "Генератор заправлен!")
        gen:EmitSound("ambient/water/drip4.wav", 70, 70)
        self:EmitSound("ambient/levels/canals/toxic_slime_gurgle4.wav", 70, 90)
        self:Remove()
    else
        POLUS11.Notify(activator, "Поднесите бочку к генератору и нажмите E.")
    end
end
