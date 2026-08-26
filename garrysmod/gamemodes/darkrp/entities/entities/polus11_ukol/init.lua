-- ============================================================
--  ПОЛЮС-11 — ИНЪЕКТОР «УКОЛ-С» (server) v4.9.1 «ИГЛА»
--  Заявка владельца: «добавь мне в Энтити мини-игру при лечении».
--  Энтити-инъектор, 2 заряда. E по инъектору: цель — кто прямо
--  перед тобой (≤120 юнитов), иначе ты сам. У медика открывается
--  миниигра: стрелка зашла в вену — доза максимальная (+40 ХП),
--  рядом +25, мимо: +8 ХП и синяк (анекдот прилагается).
--  На один заряд одного пациента — интервал 15 сек (анальгин должен
--  подействовать). Заряды кончились — инъектор сам утилизируется.
-- ============================================================

AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("P11_UK_MG") -- s→c открыть миниигру {rounds}; c→s float балл

local Pending = {} -- ply -> { ent, target, deadline }

function ENT:Initialize()
    self:SetModel("models/props_lab/jar01a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:SetMass(6) end
    self:SetCharges(2)
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    if self:GetCharges() <= 0 then
        POLUS11.Notify(activator, "Инъектор пуст — только грохот деталей внутри.")
        return
    end
    if Pending[activator] then return end -- окно уже открыто

    -- цель: игрок в прицеле до 120 юнитов, иначе САМ медик
    local tr = util.TraceLine({
        start = activator:GetShootPos(),
        endpos = activator:GetShootPos() + activator:GetAimVector() * 120,
        filter = activator,
    })
    local target = tr.Entity
    if not (IsValid(target) and target:IsPlayer() and target:Alive()) then
        target = activator
    end

    target.P11_UkolCd = target.P11_UkolCd or 0
    if CurTime() - target.P11_UkolCd < 15 then
        POLUS11.Notify(activator, "«" .. target:Nick() .. "» уже под анальгином — дай 15 секунд отойти.")
        return
    end
    local maxhp = target:GetMaxHealth() > 0 and target:GetMaxHealth() or 100
    if target:Health() >= maxhp then
        POLUS11.Notify(activator, target:Nick() .. " здоров — дозу тратить не будем.")
        return
    end

    Pending[activator] = { ent = self, target = target, deadline = CurTime() + 30 }
    net.Start("P11_UK_MG")
        net.WriteUInt(1, 4)
        net.WriteString(target:Nick())
    net.Send(activator)
end

-- ============ результат миниигры ============

net.Receive("P11_UK_MG", function(_, ply)
    local score = net.ReadFloat() or 0
    local p = Pending[ply]
    Pending[ply] = nil
    if not p or p.deadline < CurTime() then return end

    local ent = p.ent
    if not IsValid(ent) then return end
    local target = p.target

    -- потратить заряд в любом исходе — препарат вышел из ампулы
    local left = ent:GetCharges() - 1
    ent:SetCharges(left)

    if not (IsValid(target) and target:Alive()) then
        POLUS11.Notify(ply, "Пациент «ушёл» — доза ушла в снег.")
    else
        target.P11_UkolCd = CurTime()
        local heal, msg = 8, "Мимо вены… будет синяк, но +8 ХП полегчало."
        if score >= 85 then
            heal, msg = 40, "В САМУЮ ВЕНУ! Анальгин-С работает как надо: +40 ХП."
        elseif score >= 55 then
            heal, msg = 25, "Попал в вену: доза честная, +25 ХП."
        end
        local maxhp = target:GetMaxHealth() > 0 and target:GetMaxHealth() or 100
        target:SetHealth(math.min(maxhp, target:Health() + heal))
        target:EmitSound("items/medshot4.wav", 70, 105)
        target:ViewPunch(Angle(-2, 0, 0))
        ply:EmitSound("items/smallmedkit1.wav", 65, 108)
        POLUS11.Notify(ply, msg .. " (" .. math.floor(score) .. "% точности, пациент: " .. target:Nick() .. ")")
        POLUS11.Notify(target, "Медицинский укол от " .. ply:Nick() .. ": +" .. heal .. " ХП. " .. msg)
        if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "heal_player") end
    end

    if left <= 0 then
        ent:EmitSound("physics/glass/glass_impact_bullet4.wav", 65, 110)
        ent:Remove()
    end
end)

-- страховка: дисконект/протухшее окно
timer.Create("P11_UK_Watchdog", 2, 0, function()
    for ply, p in pairs(Pending) do
        if not IsValid(ply) or CurTime() > (p.deadline or 0) then Pending[ply] = nil end
    end
end)

hook.Add("PlayerDisconnected", "P11_UK_Disconnect", function(ply)
    Pending[ply] = nil
end)

print("[POLUS-11] инъектор «УКОЛ-С» v4.9.1 «ИГЛА» загружен (энтити, мини-игра лечения, 2 заряда)")
