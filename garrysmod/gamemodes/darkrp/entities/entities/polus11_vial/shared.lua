ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Колба с кровью"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "DonorName")
end
