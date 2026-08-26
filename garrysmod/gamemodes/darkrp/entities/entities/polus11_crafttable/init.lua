AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — КУСТАРНЫЙ ВЕРСТАК v4.11.0 «КУЗНЯ»
--  Стол крафтов: E — открывает мастерскую со ВСЕМИ рецептами.
--  Логика открытия — POLUS11.CraftTableUse (модуль p11_sv_loot.lua),
--  сами рецепты — p11_sv_craft.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_wasteland/controlroom_table001a.mdl", -- металлический рабочий стол (HL2)
        "models/props_c17/FurnitureTable002a.mdl",
        "models/props_junk/wood_crate001a.mdl",
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
        phys:SetMass(500)
    end
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.CraftTableUse then
        POLUS11.CraftTableUse(self, activator)
    end
end
