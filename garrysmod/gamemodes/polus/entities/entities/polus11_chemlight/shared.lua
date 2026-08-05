ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Горящий химсвет"

ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "DieTime")
end
