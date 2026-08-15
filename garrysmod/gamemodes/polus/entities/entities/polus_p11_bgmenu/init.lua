AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — БОДИГРУППЫ v5.7.7 (служебная энтити)
--  Нужна ТОЛЬКО как «курьер»: её cl_init.lua (клиентская часть —
--  кнопка «Внешность» в С-меню + окно бодигрупп) раздаётся
--  клиентам ВСЕГДА, не зависит от sv_allowcslua.
--  Спавнится под картой lua/autorun/server/p11_sv_bgmenu_spawn_v577.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
