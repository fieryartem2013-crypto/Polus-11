AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("P11FW_OpenMenu")

function ENT:Initialize()
    local cfg = (P11FW and P11FW.Config) or {}
    local model = cfg.NPCModel or "models/player/barney.mdl"
    if not file.Exists(model, "GAME") then
        model = "models/player/barney.mdl"
    end
    self:SetModel(model)

    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    -- v4.0 ФИКС: был MOVETYPE_NONE + SOLID_BBOX — «фантомная» коробка,
    -- из-за неё Use/клики местами проходили насквозь. Хул обязателен для
    -- поворота головы, но тело делаем честным VPHYSICS (как генератор).
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        -- глазеть и поворачиваться может, а вот упасть/уехать — нет
        phys:SetMass(90)
    end

    util.DropToFloor(self)

    -- спокойная стойка, если анимация есть
    local seq = self:LookupSequence("idle_subtle")
    if seq < 0 then seq = self:LookupSequence("idle") end
    if seq >= 0 then
        self:ResetSequence(seq)
        self:SetCycle(math.Rand(0, 1))
    end

    self.NextGaze = 0
end

-- поворачиваемся к ближайшему игроку (без NPC-капабилити, чистая геометрия)
function ENT:Think()
    -- v1.5 fix: при воскрешении/дубле энтитя может оказаться без Initialize
    -- (поле NextGaze = nil -> краш "compare nil with number" в строке ниже).
    -- Лечим самовосстановлением.
    self.NextGaze = tonumber(self.NextGaze) or 0

    if CurTime() >= self.NextGaze then
        self.NextGaze = CurTime() + 0.25

        local best, dist
        local cfg = (P11FW and P11FW.Config) or {}
        local maxD = (cfg.NPCGazeDistance or 260) ^ 2
        for _, ply in ipairs(player.GetAll()) do
            if ply:Alive() then
                local d = ply:GetPos():DistToSqr(self:GetPos())
                if d < maxD and (not dist or d < dist) then
                    best, dist = ply, d
                end
            end
        end

        if IsValid(best) then
            local want = ((best:GetPos() - self:GetPos()):Angle()).y
            local cur = self:GetAngles().y
            local newY = math.ApproachAngle(cur, want, 4)
            self:SetAngles(Angle(0, newY, 0))
        end
    end

    self:NextThink(CurTime() + 0.25)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 130 * 130 then return end

    net.Start("P11FW_OpenMenu")
    net.Send(activator)

    self:EmitSound("buttons/button9.wav", 55, 100)
end
