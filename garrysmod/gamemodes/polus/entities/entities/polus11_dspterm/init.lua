AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ТЕРМИНАЛ ДИСПЕТЧЕРА «ГЛАЗ» (v4.19.0 «ГЛАЗ»,
--  заявка владельца: «и энтити — его терминал, через который
--  он и может это всё»).
--  E — сесть за пульт (Диспетчер «Красного Орла» / админ 4+;
--  сама логика допуска — модуль p11_sv_dispatch:
--  POLUS11.DispatchUse / DispatchClose).
--  Ставится 📍 «Расставить» (роль dspterm), хранится на карте.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_combine/breenconsole.mdl",  -- пульт-консоль (HL2)
        "models/props_lab/citizenradio.mdl",      -- запасной облик
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    self:SetUseType(SIMPLE_USE)
end

function ENT:Use(activator)
    if not (IsValid(activator) and activator:IsPlayer()) then return end
    if POLUS11 and POLUS11.DispatchUse then
        POLUS11.DispatchUse(activator, self)
    end
end
