AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("P11FW_OpenMenu")

-- ============================================================
--  v4.1 КАДРОВИК: починка «T-pose / крутится всем телом / нет E»
--  • анимация ищется через ACTIVITY (SelectWeightedSequence),
--    а не по имени — на Workshop-плейермоделях "idle_subtle"
--    просто нет, отсюда T-pose.
--  • тело ЗАМОРОЖЕНО на спавн-угле; за игроком следит ГОЛОВА
--    (клиентские pose-параметры head_yaw/head_pitch).
--  • Use продублирован KeyPress-хуком: движковый E на
--    VPHYSICS-энтити местами теряется, теперь не потеряется.
-- ============================================================

function ENT:Initialize()
    local cfg = (P11FW and P11FW.Config) or {}
    local model = cfg.NPCModel or "models/player/barney.mdl"
    if not file.Exists(model, "GAME") then
        model = "models/player/barney.mdl"
    end
    self:SetModel(model)

    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        phys:SetMass(90)
    end

    util.DropToFloor(self)

    -- тело держим ровно как поставили (крутится только голова — клиент)
    self.P11_BaseYaw = self:GetAngles().y

    -- стойка: через ACTIVITY — вернёт реально существующую секвенцию модели
    local seq = self:SelectWeightedSequence(ACT_IDLE)
    if (not seq or seq <= 0) and self.SelectWeightedSequence then
        seq = self:SelectWeightedSequence(ACT_IDLE_ANGRY)
    end
    if (not seq or seq <= 0) and self.LookupSequence then
        seq = self:LookupSequence("idle_all_01")
        if (not seq or seq < 0) then seq = self:LookupSequence("idle") end
        if (not seq or seq < 0) then seq = 0 end
    end
    self:ResetSequence(seq or 0)
    self:SetCycle(math.Rand(0, 1))
    self.AutomaticFrameAdvance = true -- анимация играет сама (без T-pose)

    self.NextGaze = 0
end

-- предиктивная анимация + звуки шагов не нужны: он стоит
function ENT:Think()
    self.NextGaze = tonumber(self.NextGaze) or 0
    if CurTime() >= self.NextGaze then
        self.NextGaze = CurTime() + 0.5
        -- держим корпус на базовом угле (клиент крутит только голову)
        local a = self:GetAngles()
        if math.abs(math.AngleDifference(a.y, self.P11_BaseYaw or a.y)) > 0.5 then
            self:SetAngles(Angle(0, self.P11_BaseYaw or a.y, 0))
        end
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

local function OpenJobMenu(self, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 150 * 150 then return end
    if (ply.P11_NpcUse or 0) > CurTime() then return end
    ply.P11_NpcUse = CurTime() + 1

    net.Start("P11FW_OpenMenu")
    net.Send(ply)
    self:EmitSound("buttons/button9.wav", 55, 100)
end

function ENT:Use(activator)
    OpenJobMenu(self, activator)
end

-- ЗАПАСНОЙ ПУТЬ: E при прицеле на кадровика (если движковый Use молчит)
hook.Add("KeyPress", "P11FW.JobNpcE", function(ply, key)
    if key ~= IN_USE then return end
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "polus_fw_jobnpc" then return end
    OpenJobMenu(ent, ply)
end)
