AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_c17/oildrum001.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(90)
    end
end

-- v3.7: ПЕРЕНОСКА ГРУЗОВ (работа грузчика/снабженца: бармен склада,
-- носильщик). Бочку можно нести: E — поднять, ещё раз E — поставить;
-- у генератора E — сразу заправляет его.
function ENT:Think()
    local ply = self.P11_Carrier
    if ply and IsValid(ply) and ply:Alive() then
        local pos = ply:GetShootPos() + ply:GetAimVector() * 46 - Vector(0, 0, 26)
        self:SetPos(pos)
        self:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        -- накопим пройденный путь (засчитаем «переноску» при постановке)
        self.P11_CarryPath = (self.P11_CarryPath or 0) + self:GetPos():DistToSqr(self.P11_LastPos or self:GetPos())
        self.P11_LastPos = self:GetPos()
        self:NextThink(CurTime())
        return true
    elseif ply then
        -- несущий умер/вышел — уронить
        self.P11_Carrier = nil
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_NONE)
        local ph = self:GetPhysicsObject()
        if IsValid(ph) then ph:Wake() end
    end
end

local function NearestGen(pos)
    local gen, best = nil, 260 * 260
    for _, e in ipairs(ents.FindByClass("polus11_generator")) do
        local d = e:GetPos():DistToSqr(pos)
        if d < best then
            best = d
            gen = e
        end
    end
    return gen
end

-- грузчик/снабженец/повар могут таскать тяжести
local function CanCarry(ply)
    if P11FW and P11FW.GetJobId then
        local id = P11FW.GetJobId(ply)
        if id == "porter" or id == "cook" then return true end
    end
    return POLUS11.Config.Admin(ply) -- админ — да, для стройки/сейва
end

function ENT:StartCarry(ply)
    self.P11_Carrier = ply
    self.P11_CarryAt = CurTime()
    self.P11_CarryPath = 0
    self.P11_LastPos = self:GetPos()
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- сквозь игроков
    self:NextThink(CurTime())

    -- ноша: грузчик привычный, остальные еле идут
    local heavy = P11FW and P11FW.GetJobId and P11FW.GetJobId(ply) ~= "porter"
    ply.P11_CarrySlow = heavy and 0.7 or 0.88
    -- v3.8.1: базовые скорости — из POLUS11.Config.Movement (станция медленнее)
    local mv = POLUS11.Config.Movement or {}
    ply:SetWalkSpeed((mv.walk or 170) * ply.P11_CarrySlow)
    ply:SetRunSpeed((mv.run or 330) * ply.P11_CarrySlow)
    POLUS11.Notify(ply, heavy
        and "Тяжело! Вы еле плетётесь с бочкой. Ещё раз E — поставить."
        or  "Вы вскинули бочку на плечо. Ещё раз E — поставить, E у генератора — заправить.")
end

function ENT:StopCarry(ply)
    self.P11_Carrier = nil
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetPos(self:GetPos() + Vector(0, 0, 2))
    local ph = self:GetPhysicsObject()
    if IsValid(ph) then ph:Wake() end

    if IsValid(ply) then
        -- вернуть скорость
        if ply.P11_CarrySlow then
            if POLUS11.ApplyMoveSpeeds then POLUS11.ApplyMoveSpeeds(ply) end -- v3.8.1
            ply.P11_CarrySlow = nil
        end
        -- засчитать переноску грузчику (груз = пройденный путь + время)
        local path = math.sqrt(self.P11_CarryPath or 0)
        if POLUS11.TaskEvent and (CurTime() - (self.P11_CarryAt or CurTime())) > 4 and path > 8 then
            POLUS11.TaskEvent(ply, "haul")
        end
        POLUS11.Notify(ply, "Бочка поставлена.")
    end
    self.P11_CarryPath = 0
end

-- E по бочке
function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- генератор рядом с БОЧКОЙ или с ИГРОКОМ — это заправка
    local gen = NearestGen(self:GetPos()) or NearestGen(activator:GetPos())
    if IsValid(gen) then
        gen:AddFuelBarrel(1)
        if IsValid(self.P11_Carrier) then
            -- заправили прямо с плеча: скорость назад
            local c = self.P11_Carrier
            if c.P11_CarrySlow then
                if POLUS11.ApplyMoveSpeeds then POLUS11.ApplyMoveSpeeds(c) end -- v3.8.1
                c.P11_CarrySlow = nil
            end
            self.P11_Carrier = nil
            if POLUS11.TaskEvent then POLUS11.TaskEvent(c, "haul") end
        end
        if POLUS11.TaskEvent then POLUS11.TaskEvent(activator, "refuel_gen") end -- задача инженера/повара
        POLUS11.Notify(activator, "Генератор заправлен!")
        gen:EmitSound("ambient/water/drip4.wav", 70, 70)
        self:EmitSound("ambient/levels/canals/toxic_slime_gurgle4.wav", 70, 90)
        self:Remove()
        return
    end

    -- постановка бочки, которую несём
    if IsValid(self.P11_Carrier) then
        if self.P11_Carrier == activator then
            self:StopCarry(activator)
        else
            POLUS11.Notify(activator, "Бочку уже несёт " .. self.P11_Carrier:Nick())
        end
        return
    end

    -- подъём
    if not CanCarry(activator) then
        POLUS11.Notify(activator, "Слишком тяжело — это работа грузчика или снабженца. Подвиньте бочку плечом к генератору.")
        return
    end
    self:StartCarry(activator)
end
