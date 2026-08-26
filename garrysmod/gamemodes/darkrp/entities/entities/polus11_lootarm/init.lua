AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — АРМЕЙСКИЙ КОНТЕЙНЕР (лутабельный) v4.15.0 «УГЛИ»
--  Заявка «добавь лутабельные вещи, со временем восполняются».
--  Обыск за E: патронные пачки всех видов, иногда умный
--  боекомплект, редко медкейс/скальпель, немного рублей.
--  Восполняется на таймере (420 сек — задаёт p11_sv_loot.lua).
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/items/item_item_crate.mdl", -- армейский саплай-ящик HL2
        "models/props_junk/wood_crate001a.mdl",
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
        self:EmitSound("items/ammo_pickup.wav", 50, 90)
    end
    self:NextThink(CurTime() + 1)
    return true
end
