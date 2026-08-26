AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
-- Служебная энтити: cl_init (F4 с «закрыто древо») уходит клиентам.
function ENT:Initialize()
    self:SetNoDraw(true)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
end
function ENT:Draw() return true end
function ENT:Think() return false end
