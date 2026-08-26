AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — О НАС / ПРОЕКТ АРЧИ v5.8.7 (служебная энтити)
--  «Курьер» клиентской части: кнопка «ℹ О НАС» в С-меню, окно
--  про общество «Проект Арчи» (Discord + коллекция), автопоказ
--  новичкам, команда !о нас. cl_init.lua раздаётся клиентам
--  ВСЕГДА (не зависит от sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_about_spawn_v587.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
