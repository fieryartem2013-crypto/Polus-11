AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ПЯТНО ГРЯЗИ (v4.1): дело уборщика.
--  Спавнит modules/p11_sv_activities.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_junk/garbage_bag001a.mdl",
        "models/props_junk/garbage128_composite001a.mdl",
        "models/props_junk/watermelon01.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end
    self:SetModelScale(0.7, 0)
    self:SetColor(Color(60, 50, 45, 255))

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end

    util.DropToFloor(self)
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.DirtUse then
        POLUS11.DirtUse(self, activator)
    end
end

hook.Add("KeyPress", "P11.DirtE", function(ply, key)
    if key ~= IN_USE then return end
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "polus_p11_dirt"
        and POLUS11 and POLUS11.DirtUse then
        POLUS11.DirtUse(ent, ply)
    end
end)
