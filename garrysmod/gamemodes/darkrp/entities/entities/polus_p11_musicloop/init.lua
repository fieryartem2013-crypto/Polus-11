AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — MUSICLOOP v5.8.4 (служебная энтити)
--  «Курьер» клиентского плеера v2: sound.PlayFile играет трек
--  ОДИН раз (не эмбиент), громкость и повтор — из сервера.
--  cl_init.lua раздаётся клиентам ВСЕГДА (не зависит от
--  sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_musicvol_spawn_v584.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
