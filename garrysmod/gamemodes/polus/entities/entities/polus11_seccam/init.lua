AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — КАМЕРА НАБЛЮДЕНИЯ «ГЛАЗ» (v4.19.0 «ГЛАЗ»)
--  Глаз сети диспетчера «Красного Орла»: куда повёрнута —
--  туда и смотрит (взгляд = Angles энтити при расстановке 📍).
--  Вид с камеры открывается у диспетчера с терминала
--  polus11_dspterm (модуль p11_sv/p11_cl_dispatch).
--  Ставится 📍 «Расставить» (роль cam), хранится на карте.
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/combine_camera/combine_camera.mdl",   -- камера-смотритель (HL2)
        "models/props_lab/citizenradio.mdl",          -- запасной облик
        "models/props_c17/consolebox03a.mdl",         -- последний фолбэк
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
    if IsValid(activator) and activator:IsPlayer() then
        activator:ChatPrint("[ГЛАЗ] Камера сети станции. Сигнал уходит на терминал диспетчера.")
    end
end
