AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    -- v3.7: модель пульта станции + фолбэки без пака lt_c
    local models = {
        "models/lt_c/holo_rails.mdl",
        "models/props_c17/consolebox01a.mdl",
        "models/props_lab/heatplate.mdl",
    }
    local model = "models/props_c17/consolebox01a.mdl"
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then model = m break end
    end
    self:SetModel(model)

    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetMoveType(MOVETYPE_NONE)
    self:PhysicsInit(SOLID_BBOX)
    self:SetSolid(SOLID_BBOX)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    util.DropToFloor(self)
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 140 * 140 then return end

    self.NextUseT = self.NextUseT or 0
    if CurTime() < self.NextUseT then return end
    self.NextUseT = CurTime() + 0.5

    if POLUS11.CanUseTerminal and POLUS11.CanUseTerminal(activator) then
        POLUS11.OpenTerminal(activator)
        self:EmitSound("buttons/button9.wav", 55, 120)
    else
        activator:ChatPrint("[ТЕРМИНАЛ] Доступ закрыт: нужна должность с допуском к терминалу.")
        self:EmitSound("buttons/button10.wav", 55, 90)
    end
end
