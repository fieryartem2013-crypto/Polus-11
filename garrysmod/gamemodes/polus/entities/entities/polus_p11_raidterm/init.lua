AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ТЕРМИНАЛ РЕЙДА — сервер v4.24.0 «РУБЕЖ»
--  Консоль-пост на полу (📍 «Расставить» → ⚔). E — командир
--  фракции объявляет рейд на вражескую сторону (логика и
--  права — в p11_sv_raid: POLUS11.RaidTermUse).
-- ============================================================

function ENT:Initialize()
    local models = {
        "models/props_lab/reciever01a.mdl",
        "models/props_lab/citizenradio.mdl",
        "models/props_c17/oildrum001.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false) -- пост не катается
    else
        self:PhysicsDestroy()
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 48))
    end

    util.DropToFloor(self)
end

function ENT:Use(activator)
    if not (IsValid(activator) and activator:IsPlayer()) then return end
    self.P11_NextUse = self.P11_NextUse or 0
    if CurTime() < self.P11_NextUse then return end
    self.P11_NextUse = CurTime() + 0.7
    if activator:GetPos():DistToSqr(self:GetPos()) > 210 * 210 then return end
    if POLUS11 and POLUS11.RaidTermUse then
        POLUS11.RaidTermUse(self, activator)
    end
end
