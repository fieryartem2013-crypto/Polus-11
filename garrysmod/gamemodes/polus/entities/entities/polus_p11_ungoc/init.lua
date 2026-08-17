AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — UNGOC v5.8.15 (служебная энтити)
--  «Курьер» клиентской чистки: убирает категорию «osowiec»
--  из F4 (Осовец вырезан). cl_init.lua раздаётся клиентам
--  ВСЕГДА (не зависит от sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_ungoc_spawn_v5815.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
