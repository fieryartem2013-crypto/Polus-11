AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ТАЙНИК СНАБЖЕНЦА (лутабельный, редкий) v4.11.0 «КУЗНЯ»
--  Обыск за E: рубли + запчасти; редко — ампула, УКОЛ-С, рация,
--  очень редко — 5 ПФ ПОЛЮС-ФЛЮКСА. Долгое восполнение.
--  Логика лута — в модуле p11_sv_loot.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_c17/BriefCase001a.mdl", -- «чемоданчик» (HL2)
        "models/props_c17/suitcase001a.mdl",
        "models/props_junk/wood_crate001a.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end
    self:SetModelScale(2, 0) -- чемоданчик мелкий — делаем заметным

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        phys:SetMass(300)
    end

    self.LootReady = true
    self:SetLootReadyAt(0)
    self:NextThink(CurTime() + 1)
end

function ENT:Use(activator)
    if POLUS11 and POLUS11.LootUse then
        POLUS11.LootUse(self, activator)
    end
end

function ENT:Think()
    if self.LootReady == false and CurTime() >= (self:GetLootReadyAt() or 0) then
        self.LootReady = true
        self:SetColor(Color(255, 255, 255, 255))
        self:EmitSound("items/suitchargeok1.wav", 48, 90)
    end
    self:NextThink(CurTime() + 1)
    return true
end
