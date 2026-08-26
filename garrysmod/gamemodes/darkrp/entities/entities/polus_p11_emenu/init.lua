AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — EMENU v5.8.21 (служебная энтити)
--  «Курьер» клиентского контекстного меню (удержание Е).
--  cl_init.lua раздаётся клиентам ВСЕГДА (не зависит от
--  sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_emenu_spawn_v5821.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
