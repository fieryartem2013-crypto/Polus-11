AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ПОЛЕВАЯ КУХНЯ (v4.2): дело повара.
--  Повар жмёт E → миниигра в 3 клавиши → на плите появляется
--  горячий паёк (polus_p11_meal). Логика — p11_sv_duties2.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_c17/furniturestove001a.mdl",
        "models/props_wasteland/kitchen_stove001a.mdl",
        "models/props_interiors/stove02.mdl",
        "models/props_wasteland/controlroom_filecabinet002a.mdl",
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
        phys:SetMass(250)
    end
    util.DropToFloor(self)
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.KitchenUse then
        POLUS11.KitchenUse(self, activator)
    end
end

hook.Add("KeyPress", "P11.KitchenE", function(ply, key)
    if key ~= IN_USE then return end
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "polus_p11_kitchen"
        and POLUS11 and POLUS11.KitchenUse then
        POLUS11.KitchenUse(ent, ply)
    end
end)
