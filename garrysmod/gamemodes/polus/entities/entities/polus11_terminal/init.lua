AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    -- v4.0: модель терминала — монитор лаборатории (по заявке владельца).
    -- Фолбэки — если вдруг карта/пак переопределил контент.
    local models = {
        "models/props_lab/monitor01a.mdl",
        "models/lt_c/holo_rails.mdl",
        "models/props_c17/consolebox01a.mdl",
        "models/props_lab/heatplate.mdl",
    }
    local model = "models/props_lab/monitor01a.mdl"
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then model = m break end
    end
    self:SetModel(model)

    -- v4.0 ФИКС «терминал не физичен»: был HULL + SOLID_BBOX +
    -- MOVETYPE_NONE (коробка невидимой оболочки, могла парить/плыть).
    -- Теперь честный VPHYSICS по модели, как у генератора, — твёрдый,
    -- стоит ровно, по нему работают Use/трейсы.
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(120)
        phys:EnableMotion(false) -- прибит к полу, но физичен
    end

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
