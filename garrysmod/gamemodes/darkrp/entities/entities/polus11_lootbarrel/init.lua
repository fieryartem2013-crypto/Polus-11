AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ТОПЛИВНАЯ БОЧКА (лутабельная) v4.11.0 «КУЗНЯ»
--  Обыск за E: канистра солярки/спирт, иногда лом/химсвет.
--  Логика лута — в модуле p11_sv_loot.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_c17/oildrum001.mdl", -- основная (HL2, всегда есть)
        "models/props_c17/oildrum001_explosive.mdl",
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
        phys:SetMass(420)
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
        self:EmitSound("physics/metal/metal_barrel_impact_soft1.wav", 50, 85)
    end
    self:NextThink(CurTime() + 1)
    return true
end
