AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — PLATES v5.8.22 (служебная энтити)
--  «Курьер» патча двусторонних 3D2D-плашек. cl_init.lua
--  раздаётся клиентам ВСЕГДА. Спавнится под картой
--  lua/autorun/server/p11_sv_plates_spawn_v5822.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
