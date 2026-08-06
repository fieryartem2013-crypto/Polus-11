AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local models = {
        "models/player/eli.mdl",
        "models/player/barney.mdl",
        "models/player/kleiner.mdl",
    }
    local found = false
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) found = true break end
    end
    if not found then
        -- v4.6.9: без HL2-персонажей в контенте торговец раньше
        -- оставался БЕЗ модели: невидим, без физики, E не работал.
        -- Ставим хотя бы ящик (есть у всех) — Use и физика живут.
        self:SetModel("models/props_junk/wood_crate002a.mdl")
    end

    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
    util.DropToFloor(self)

    local seq = self:LookupSequence("idle_subtle")
    if seq < 0 then seq = self:LookupSequence("idle") end
    if seq >= 0 then self:ResetSequence(seq) end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 160 * 160 then return end
    self.NextUseT = self.NextUseT or 0
    if CurTime() < self.NextUseT then return end
    self.NextUseT = CurTime() + 0.6
    if POLUS11.OpenShopUI then
        POLUS11.OpenShopUI(activator, self)
    else
        -- v4.6.9: складской модуль не загрузился — сказать, а не молчать
        activator:ChatPrint("[ПОЛЮС-11] Складской модуль не проснулся — смотри [POLUS][ERROR] в консоли сервера.")
    end
end
