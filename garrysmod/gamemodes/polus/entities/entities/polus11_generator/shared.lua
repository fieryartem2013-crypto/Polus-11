ENT.Type      = "anim"
ENT.Base      = "base_anim"

ENT.PrintName = "Дизель-генератор"
ENT.Author    = "POLUS-11"
ENT.Category  = "ПОЛЮС-11"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Fuel")        -- секунд топлива осталось
    self:NetworkVar("Bool", 0, "Damaged")
    self:NetworkVar("Float", 1, "UseProgress") -- прогресс действия E 0..1
    self:NetworkVar("String", 0, "UseAction")  -- "repair" / "sabotage" / ""
end
