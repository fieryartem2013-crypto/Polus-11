AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — MUSICV3 v5.8.9 (служебная энтити)
--  «Курьер» клиентского плеера v3 (канал P11_MusicPlayV3).
--  cl_init.lua раздаётся клиентам ВСЕГДА (не зависит от
--  sv_allowcslua). Спавнится под картой серверным autorun
--  p11_sv_musicbg_spawn_v589.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
