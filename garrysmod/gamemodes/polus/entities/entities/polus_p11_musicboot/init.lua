AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — MUSICBOOT v5.8.2 (служебная энтити)
--  «Курьер» клиентского плеера станции: net-приёмники
--  P11_MusicPlay / P11_MusicStop + HUD-индикатор «♪ МУЗЫКА».
--  cl_init.lua раздаётся клиентам ВСЕГДА (не зависит от
--  sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_music_spawn_v582.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
