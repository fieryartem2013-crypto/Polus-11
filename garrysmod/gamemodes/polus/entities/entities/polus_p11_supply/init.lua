AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ЯЩИК СНАБЖЕНИЯ (v4.2): эвент «сброс в метель».
--  Падает с неба, внутри — добыча. Открытие: держать E 8 сек.
--  Логика спавна/лута — p11_sv_duties2.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_junk/wood_crate001a.mdl",
        "models/props_junk/wood_crate002a.mdl",
        "models/props_vehicles/carparts_wheel01a.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end
    self:SetModelScale(1.4, 0)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        phys:SetMass(500)
    end
    self:SetOpenProgress(0)

    -- маяк: слышно треск рации-приводывателя
    self:EmitSound("ambient/explosions/explode_4.wav", 70, 70)
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.SupplyUse then
        POLUS11.SupplyUse(self, activator)
    end
end

hook.Add("KeyPress", "P11.SupplyE", function(ply, key)
    if key ~= IN_USE then return end
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "polus_p11_supply"
        and POLUS11 and POLUS11.SupplyUse then
        POLUS11.SupplyUse(ent, ply)
    end
end)
