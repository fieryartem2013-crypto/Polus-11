AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ГОРЯЧИЙ ПАЁК (v4.2): порция от повара.
--  E — съесть: +15 HP, тепло; повару капает комиссия.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_junk/garbage_metalcan001a.mdl",
        "models/props_junk/watermelon01.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end
    self:SetModelScale(0.8, 0)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    -- остывает за 3 минуты
    timer.Simple(180, function()
        if IsValid(self) then self:Remove() end
    end)
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.MealEat then
        POLUS11.MealEat(self, activator)
    end
end

hook.Add("KeyPress", "P11.MealE", function(ply, key)
    if key ~= IN_USE then return end
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "polus_p11_meal"
        and POLUS11 and POLUS11.MealEat then
        POLUS11.MealEat(ent, ply)
    end
end)
