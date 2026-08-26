ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Анализатор крови «КРОВЬ-2»"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Testing")
end
