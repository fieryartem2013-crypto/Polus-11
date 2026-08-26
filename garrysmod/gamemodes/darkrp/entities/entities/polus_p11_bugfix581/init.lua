AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — BUGFIX v5.8.1 (служебная энтити)
--  «Курьер» клиентских фиксов: кнопка «Багаж» (слившийся текст),
--  окно документа (нечитаемый текст), подсказка рации.
--  cl_init.lua раздаётся клиентам ВСЕГДА (не зависит от
--  sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_radiofix_spawn_v581.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
