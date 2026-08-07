-- ============================================================
--  ПОЛЮС-11 — АНАЛИЗАТОР КРОВИ «КРОВЬ-2» (server) v4.9.1 «ИГЛА»
--  Заявка владельца: «добавь стол для проверки крови, сделай его
--  с нуля, с мини-игрой». Стол новый, список для Энтити-меню.
--  ХОД: учёный (вся научная фракция) несёт колбу (шприц) → E по
--  столу → у него открывается миниигра калибровки (3 цикла):
--  попал в зелень ≥60% — результат ЧЕСТНЫЙ и виден только ему;
--  смазал — «анализ испорчен», колба возвращается (без потери).
--  Заражённый тестировщик может ПОДМЕНИТЬ вердикт (как в кино).
--  Стол-ветеран polus11_labtable остаётся на месте, живёт своё.
-- ============================================================

AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("P11_BL_MG")   -- s→c открыть миниигру {rounds, donor}; c→s float средний балл
util.AddNetworkString("P11_BL_VER")  -- s→c вердикт {заражён, donor, можноПодменить}; c→s bool «подменить»

local Pending = {} -- ply -> { ent, vial, donor, infected, stage, deadline }

local function CarriedVial(ply)
    for _, e in ipairs(ents.FindByClass("polus11_vial")) do
        if e:GetParent() == ply then return e end
    end
    return nil
end

function ENT:Initialize()
    local models = {
        "models/lt_c/sci_fi/counter.mdl",
        "models/props_wasteland/controlroom_desk001a.mdl",
        "models/props_c17/FurnitureTable001a.mdl",
        "models/props_combine/breendesk.mdl",
    }
    for _, m in ipairs(models) do
        if file.Exists(m, "GAME") then self:SetModel(m) break end
    end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:SetMass(280) end
    self:SetTesting(false)
end

local function DropPending(ply)
    local p = Pending[ply]
    if p then
        if IsValid(p.ent) then p.ent:SetTesting(false) end
        Pending[ply] = nil
    end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    if self:GetTesting() then
        POLUS11.Notify(activator, "Анализатор занят — идёт калибровка.")
        return
    end
    if not (POLUS11.IsScienceFaction and POLUS11.IsScienceFaction(activator)) then
        POLUS11.Notify(activator, "«КРОВЬ-2» слушается только научную фракцию.")
        return
    end
    if Pending[activator] then DropPending(activator) end

    local vial = CarriedVial(activator)
    if not IsValid(vial) then
        POLUS11.Notify(activator, "Возьмите в руки колбу с кровью (шприцом — забор, колбу нести к столу).")
        return
    end

    -- колба на стол
    vial:SetParent(nil)
    vial:SetMoveType(MOVETYPE_NONE)
    vial:SetSolid(SOLID_NONE)
    vial:SetPos(self:GetPos() + self:GetUp() * 30 + self:GetForward() * 10)
    vial:SetAngles(Angle(0, 0, 0))

    self:SetTesting(true)
    self:EmitSound("ambient/energy/weld1.wav", 65, 105)

    Pending[activator] = {
        ent = self, vial = vial,
        donor = vial.GetDonorName and vial:GetDonorName() or "?",
        infected = vial.DonorInfected == true,
        stage = "mg", deadline = CurTime() + 60,
    }

    net.Start("P11_BL_MG")
        net.WriteUInt(3, 4)
        net.WriteString(vial.GetDonorName and vial:GetDonorName() or "?")
    net.Send(activator)

    if POLUS11.Log then POLUS11.Log("КРОВЬ-2: " .. activator:Nick() .. " начал анализ крови") end
end

-- ============ ШАГ 1: миниигра калибровки пройдена (или нет) ============

net.Receive("P11_BL_MG", function(_, ply)
    local score = net.ReadFloat() or 0
    local p = Pending[ply]
    if not p or p.stage ~= "mg" then return end
    if not IsValid(p.ent) then DropPending(ply) return end

    if score < 60 then
        -- анализ испорчен: колба ЦЕЛА, возвращаем в руки — учёный попробует снова
        if IsValid(p.vial) and p.vial.PickUp then p.vial:PickUp(ply) end
        p.ent:SetTesting(false)
        p.ent:EmitSound("buttons/button10.wav", 70, 90)
        Pending[ply] = nil
        POLUS11.Notify(ply, "Анализ испорчен (" .. math.floor(score) .. "% от калибровки — нужно 60%). Колба вернулась в руки — попробуй внимательнее.")
        net.Start("P11_BL_VER")
            net.WriteUInt(0, 2) -- вердикт: 0 испорчено / 1 чист / 2 НЕЧТО
            net.WriteString(p.donor)
            net.WriteBool(false) -- подменять испорченное нечего
        net.Send(ply)
        return
    end

    -- честный вердикт готовится: если тестирующий — Нечто, дадим подменить
    p.stage = "ver"
    p.deadline = CurTime() + 25
    local canFal = (POLUS11.IsInfected and POLUS11.IsInfected(ply)) and true or false

    -- искры в процессе вывода вердикта
    timer.Create("P11_BL_Spark_" .. p.ent:EntIndex(), 0.4, 4, function()
        if not IsValid(p.ent) then return end
        local ed = EffectData()
        ed:SetOrigin(p.ent:GetPos() + Vector(0, 0, 42))
        util.Effect("sparks", ed, true, true)
    end)

    net.Start("P11_BL_VER")
        net.WriteUInt(p.infected and 2 or 1, 2) -- вердикт: 1 чист / 2 НЕЧТО
        net.WriteString(p.donor)
        net.WriteBool(canFal)
    net.Send(ply)
end)

-- ============ ШАГ 2: вердикт зафиксирован (или подменён Нечто) ============

local function FinishVerdict(ply, falsify)
    local p = Pending[ply]
    if not p or p.stage ~= "ver" then return end
    Pending[ply] = nil
    local ent = p.ent
    if not IsValid(ent) then return end

    ent:SetTesting(false)

    local shown = p.infected
    if falsify then shown = not shown end
    local pos = ent:GetPos() + Vector(0, 0, 40)

    if shown then
        -- КРОВЬ КИПИТ: колба пляшет
        ent:EmitSound("npc/zombie_poison/pz_alert1.wav", 90, 95)
        ent:EmitSound("npc/zombie_poison/pz_alert2.wav", 80, 120)
        if IsValid(p.vial) then
            local startPos = p.vial:GetPos()
            for i = 1, 10 do
                timer.Simple(i * 0.08, function()
                    if IsValid(p.vial) then
                        p.vial:SetPos(startPos + Vector(math.random(-8, 8), math.random(-8, 8), 6 + math.abs(math.sin(i)) * 18))
                    end
                end)
            end
            timer.Simple(0.9, function()
                if IsValid(p.vial) then p.vial:SetPos(startPos) end
            end)
        end
        for i = 1, 4 do
            local ed = EffectData()
            ed:SetOrigin(pos + Vector(math.random(-6, 6), math.random(-6, 6), i * 5))
            util.Effect("sparks", ed, true, true)
        end
    else
        ent:EmitSound("ambient/levels/canals/toxic_slime_sizzle2.wav", 60, 100)
        local ed = EffectData()
        ed:SetOrigin(pos)
        util.Effect("smoke_trail", ed, true, true)
    end

    if POLUS11.Log then
        POLUS11.Log("КРОВЬ-2 [" .. p.donor .. "]: " .. (p.infected and "НЕЧТО" or "чист")
            .. (falsify and (" (ПОДМЕНЁН → показано «" .. (shown and "НЕЧТО" or "чист") .. "»)") or "")
            .. " | тестировал: " .. ply:Nick())
    end
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "blood_test") end
end

net.Receive("P11_BL_VER", function(_, ply)
    local falsify = net.ReadBool()
    local p = Pending[ply]
    if not p or p.stage ~= "ver" then return end
    -- подменить может ТОЛЬКО заражённый (страховка от читерской подмены с чистыми руками)
    if falsify and not (POLUS11.IsInfected and POLUS11.IsInfected(ply)) then
        falsify = false
    end
    FinishVerdict(ply, falsify)
end)

-- ============ СТРАХОВКИ: дедлайны и дисконект ============

timer.Create("P11_BL_Watchdog", 2, 0, function()
    for ply, p in pairs(Pending) do
        if not IsValid(ply) or CurTime() > (p.deadline or 0) then
            if IsValid(p.ent) then p.ent:SetTesting(false) end
            if p.stage == "mg" and IsValid(p.vial) and IsValid(ply) then
                if p.vial.PickUp then p.vial:PickUp(ply) end -- не потерять колбу при обрыве окна
            end
            Pending[ply] = nil
        end
    end
end)

hook.Add("PlayerDisconnected", "P11_BL_Disconnect", function(ply)
    local p = Pending[ply]
    if p and IsValid(p.ent) then p.ent:SetTesting(false) end
    Pending[ply] = nil
end)

print("[POLUS-11] анализатор «КРОВЬ-2» v4.9.1 «ИГЛА» загружен (стол с миниигрой калибровки, вердикт — только тестирующему)")
