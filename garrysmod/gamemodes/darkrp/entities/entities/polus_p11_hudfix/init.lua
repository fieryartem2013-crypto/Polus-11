AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — HUDFIX v5.8.14 (служебная энтити)
--  «Курьер» клиентского фикса порядка HUD: основной HUD поверх
--  HUD Нечто. cl_init.lua раздаётся клиентам ВСЕГДА (не зависит
--  от sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_zz_fixes_v5814.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
