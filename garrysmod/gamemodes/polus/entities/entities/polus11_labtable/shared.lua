ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Лабораторный стол (тест крови)"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Testing")
end
