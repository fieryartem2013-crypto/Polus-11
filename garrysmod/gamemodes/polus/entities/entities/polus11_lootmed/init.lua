AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — МЕДШКАФ (лутабельный) v4.12.0 «ОТБОЙ»
--  Обыск за E: бинт(брезент)/спирт/ампулы, редко шприц/медкейс.
--  Логика лута — в модуле p11_sv_loot.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_wasteland/controlroom_filecabinet002a.mdl", -- аптечный шкафчик (HL2)
        "models/props_wasteland/controlroom_filecabinet001a.mdl",
        "models/props_c17/FurnitureShelf001b.mdl",
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
        phys:SetMass(400)
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
        self:EmitSound("items/suitchargeok1.wav", 48, 92)
    end
    self:NextThink(CurTime() + 1)
    return true
end
