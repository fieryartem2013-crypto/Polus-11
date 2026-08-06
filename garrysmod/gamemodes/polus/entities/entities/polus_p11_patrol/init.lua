AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ПОСТ ПАТРУЛЯ (v4.1)
--  Ставится админом через УТИЛИТЫ → Расстановка.
--  Боец подходит, жмёт E, держит 3 сек — точка засчитана.
--  Вся логика обхода/наград — в modules/p11_sv_activities.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_c17/signpole001.mdl",
        "models/props_trainstation/trainstation_column001.mdl",
        "models/props_borealis/bluebarrel001.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        phys:SetMass(70)
    end

    util.DropToFloor(self)
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.PatrolUse then
        POLUS11.PatrolUse(self, activator)
    end
end

-- запасной путь E (тот же нюанс движка, что у кадровика)
hook.Add("KeyPress", "P11.PatrolE", function(ply, key)
    if key ~= IN_USE then return end
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "polus_p11_patrol"
        and POLUS11 and POLUS11.PatrolUse then
        POLUS11.PatrolUse(ent, ply)
    end
end)
