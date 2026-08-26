ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Тайник снабженца"
ENT.Author      = "ПОЛЮС-11"
ENT.Category    = "ПОЛЮС-11"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "LootReadyAt") -- серверный CurTime(), когда тайник снова набит (0 = набит)
end
