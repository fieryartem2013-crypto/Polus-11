ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Точка захвата «ФЛАГ»"
ENT.Author      = "ПОЛЮС-11"
ENT.Category    = "ПОЛЮС-11"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    -- имя точки: «А», «Б», «В»… (ставится сервером при спавне)
    self:NetworkVar("String", 0, "PointName")
    -- владелец: "" | "rkka" | "eagle"
    self:NetworkVar("String", 1, "OwnerFact")
    -- кто сейчас жмёт шкалу: "" | "rkka" | "eagle"
    self:NetworkVar("String", 2, "CapFact")
    -- прогресс захвата 0..1
    self:NetworkVar("Float",  0, "CapFrac")
end
