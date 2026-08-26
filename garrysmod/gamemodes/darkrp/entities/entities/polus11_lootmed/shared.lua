ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Медшкаф"
ENT.Author      = "ПОЛЮС-11"
ENT.Category    = "ПОЛЮС-11"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "LootReadyAt") -- серверный CurTime(), когда шкаф снова полон (0 = полон)
end
