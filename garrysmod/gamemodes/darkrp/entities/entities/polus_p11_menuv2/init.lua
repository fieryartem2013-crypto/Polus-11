AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — MENUV2 v5.7.8 (служебная энтити)
--  «Красота» клиентских меню: полировка С-меню, новое меню
--  персонажа, мини-интро в стиле Хелиса. Нужна как «курьер»:
--  её cl_init.lua раздаётся клиентам ВСЕГДА (не зависит от
--  sv_allowcslua). Спавнится под картой
--  lua/autorun/server/p11_sv_menuv2_spawn_v578.lua.
-- ============================================================

function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Draw() return true end
function ENT:Think() return false end
