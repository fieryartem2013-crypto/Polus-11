ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Инъектор «УКОЛ-С» (мини-игра лечения)"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Charges")
end
