AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ЯЩИК ЛОМА (лутабельный) v4.11.0 «КУЗНЯ»
--  Обыск за E: металлолом/брезент/тушёнка, иногда паёк/запчасти.
--  Сама энтити — только тело + таймер восполнения;
--  логика лута (что выпало) живёт в модуле p11_sv_loot.lua.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_junk/wood_crate001a.mdl", -- основной (HL2, всегда есть)
        "models/props_junk/wood_crate002a.mdl",
        "models/props_c17/oildrum001.mdl",
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
        phys:EnableMotion(false) -- ящик прикован к месту: не раскидывать по станции
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

-- самовосполнение: пришло время — снова полный и светлый
function ENT:Think()
    if self.LootReady == false and CurTime() >= (self:GetLootReadyAt() or 0) then
        self.LootReady = true
        self:SetColor(Color(255, 255, 255, 255))
        self:EmitSound("physics/wood/wood_crate_impact_soft1.wav", 50, 90)
    end
    self:NextThink(CurTime() + 1)
    return true
end
