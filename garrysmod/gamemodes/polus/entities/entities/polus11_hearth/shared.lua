ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Буржуйка «УГЛИ»"
ENT.Author      = "ПОЛЮС-11"
ENT.Category    = "ПОЛЮС-11"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    -- серверный CurTime(), до которого очаг горит (0/прошлое = не горит)
    self:NetworkVar("Float", 0, "BurnUntil")
end
