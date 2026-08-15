AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
-- Служебная энтити: нужна только чтобы её cl_init гарантированно ушёл
-- клиентам (файлы энтити раздаются ВСЕГДА, не зависят от sv_allowcslua).
-- Спавнится серверным autorun (p11_sv_fixboot_spawn_v564) под картой.
function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end
function ENT:Draw() return true end
function ENT:Think() return false end
