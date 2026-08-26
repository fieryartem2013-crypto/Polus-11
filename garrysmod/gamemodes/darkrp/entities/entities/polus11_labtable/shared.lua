ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Лабораторный стол (тест крови)"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = true
ENT.AdminOnly = false -- v4.8.8: стол виден всем в Энтити-меню (заявка «нету стола»)
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Testing")
end
