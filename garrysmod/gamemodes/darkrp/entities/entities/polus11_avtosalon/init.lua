AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ГАРАЖ-МАСТЕР «ПОЛЮС-АВТО» — сервер (v4.10.0 «ГАРАЖ», С НУЛЯ)
--  НПС, у которого покупается ТРАНСПОРТ (LVS). Заявка владельца:
--  «сделай с чистого листа НПС, у которого покупаются транспорты».
--  Тело: VPHYSICS по модели, самолечение BBOX-коробкой (терминал-
--  паттерн) — торговец ТВЁРДЫЙ и E по нему работает всегда.
--  АНИМАЦИЯ: заявка «отсутствуют анимации у нпс» — тут ТРИ слоя
--  защиты: AutomaticFrameAdvance (движок сам крутит секвенс) +
--  серверный надзор за стойкой + клиентский FrameAdvance.
-- ============================================================

local IDLE_ACTS = { ACT_IDLE, ACT_IDLE_ANGRY, ACT_IDLE_STIMULATED, ACT_IDLE_RELAXED }
local IDLE_SEQS = { "idle_all_01", "idle_all_02", "idle_subtle", "idle", "LineIdle01" }

local function ResolveIdleSeq(self)
    for _, act in ipairs(IDLE_ACTS) do
        local ok, seq = pcall(self.SelectWeightedSequence, self, act)
        if ok and seq and seq > 0 then return seq end
    end
    for _, name in ipairs(IDLE_SEQS) do
        local ok, seq = pcall(self.LookupSequence, self, name)
        if ok and seq and seq >= 0 then return seq end
    end
    return 0
end

function ENT:Initialize()
    -- модель: механик-снабженец → запасные человечки → ящик
    local models = {
        "models/player/odessa.mdl",
        "models/player/barney.mdl",
        "models/player/eli.mdl",
        "models/player/kleiner.mdl",
        "models/props_junk/wood_crate002a.mdl",
        "models/error.mdl",
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
        phys:EnableMotion(false) -- прибит к месту, но физичен
        phys:SetMass(90)
    else
        -- САМОЛЕЧЕНИЕ: VPHYSICS не встал (нет коллизии у модели) — статик-коробка.
        -- Торговец всё равно ТВЁРДЫЙ: трейсы (+use) по нему работают.
        self:PhysicsDestroy()
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        local mins, maxs = self:OBBMins(), self:OBBMaxs()
        if not mins or not maxs or (maxs.z - mins.z) < 8 then
            mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 72)
        end
        self:SetCollisionBounds(mins, maxs)
    end

    util.DropToFloor(self)
    self:ApplyIdle()
end

function ENT:ApplyIdle()
    local seq = ResolveIdleSeq(self)
    self.P11_IdleSeq = seq
    self:ResetSequence(seq)
    self:SetCycle(math.Rand(0, 1))
    self:SetPlaybackRate(1)
    self.AutomaticFrameAdvance = true -- движок САМ крутит анимацию (не T-pose)
end

function ENT:Think()
    -- надзор: что бы ни сбило стойку — вернуть (ни одного кадра T-pose)
    self.P11_NextGuard = self.P11_NextGuard or 0
    if CurTime() >= self.P11_NextGuard then
        self.P11_NextGuard = CurTime() + 0.5
        if self.GetSequence and self.P11_IdleSeq ~= nil then
            local ok, cur = pcall(self.GetSequence, self)
            if ok and cur ~= self.P11_IdleSeq then
                self:ResetSequence(self.P11_IdleSeq)
                self:SetPlaybackRate(1)
                self.AutomaticFrameAdvance = true
            end
        end
    end
    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end
    self.NextUseT = self.NextUseT or 0
    if CurTime() < self.NextUseT then return end
    self.NextUseT = CurTime() + 0.6
    if POLUS11.OpenGarageUI then
        POLUS11.OpenGarageUI(activator, self)
    else
        activator:ChatPrint("[ПОЛЮС-АВТО] Гаражный модуль не проснулся — смотри [POLUS][ERROR] в консоли сервера.")
    end
end
