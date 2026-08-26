ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Ящик снабжения"
ENT.Author      = "ПОЛЮС-11"
ENT.Category    = "ПОЛЮС-11"
ENT.Spawnable   = false
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "OpenProgress")
end
