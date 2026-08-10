-- ============================================================
--  ПОЛЮС-11 — РЕЙДЫ (сервер) v4.24.0 «РУБЕЖ»
--  Заявка владельца: «сделай систему рейда — терминал рейда,
--  чтобы можно было рейдить фракции; только командиры могут
--  рейд объявить; при рейде спавнятся точки рейда и меню
--  наверху рейда — какие точки чьи».
--  «■ ТЕРМИНАЛ РЕЙДА» (📍 «Расставить» → роль raidterm): E —
--  только КОМАНДИР фракции (комиссар/генералы РККА, командир/
--  резидент Орла) объявляет РЕЙД на вражескую сторону:
--  на карте случайно встают 2 точки прорыва (энтити «ФЛАГ» — v4.33.0
--  «ПАТРОН»: было 3, стало 2 по заявке владельца; те же правила:
--  толпа жмёт быстрее, враг в круге — стоп).
--  Бой 10 минут. Полоса наверху показывает, чья каждая точка.
--  Итог — суммарное время контроля точек: победа атакующих —
--  каждому онлайн-бойцу стороны +2500₽, оборона устояла —
--  +1500₽. Кулдаун стороны 20 минут. Админ-стоп: p11_raidstop.
--  Во время ОПЕРАЦИИ «РУБЕЖ» рейды молчат.
-- ============================================================

local RAID_T   = 10 * 60       -- бой
local POINTS_N = 2             -- точек прорыва (v4.33.0 «ПАТРОН»: было 3 — заявка владельца)
local CD_T     = 20 * 60       -- кулдаун стороны между своими рейдами
local WIN_PAY  = 2500          -- каждому бойцу стороны (атака взяла точки)
local DEF_PAY  = 1500          -- каждому бойцу стороны (оборона устояла)

POLUS11.Raid = POLUS11.Raid or {}
local R = POLUS11.Raid

local function RaidResetState()
    R.phase  = "idle"
    R.att    = nil
    R.def    = nil
    R.points = {}
    R.hold   = { rkka = 0, eagle = 0 }
    R.endT   = 0
end
RaidResetState()
R.nextAt = R.nextAt or { rkka = 0, eagle = 0 }  -- кулдауны сторон

local FACT_NAME = { rkka = "РККА", eagle = "ОТРЯД «КРАСНЫЙ ОРЁЛ»" }

-- должности, которым дано объявлять рейд — командиры сторон
local COMMANDERS = {
    seed_rkka_komissar   = true,
    seed_rkka_general    = true,
    seed_rkka_generalpeh = true,
    seed_eagle_komandir  = true,
    seed_eagle_rezident  = true,
}

-- v4.25.0 «ЭМАЛЬ»: командные профы операций играют за родительские стороны
local OP_FAC = { op_sssr = "rkka", op_usa = "eagle" }

local function RaidFactOf(ply)
    if not (P11FW and P11FW.GetJob) then return nil end
    local job = P11FW.GetJob(ply)
    local id = istable(job) and (job.faction or job.category) or nil
    if id == "rkka" or id == "eagle" then return id end
    if OP_FAC[id] then return OP_FAC[id] end
    return nil
end

local function RaidIsCommander(ply)
    local id = P11FW and P11FW.GetJobId and P11FW.GetJobId(ply) or nil
    return id ~= nil and COMMANDERS[id] == true
end

local function RaidAnnounce(txt)
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString("РЕЙД")
    net.Broadcast()
end

-- случайные площадки: живые объекты станции + стартовые точки
local ANCHOR_CLASSES = {
    "polus_p11_shopnpc", "polus_p11_contractnpc", "polus_p11_jailnpc",
    "polus11_hearth", "polus_p11_kitchen", "polus11_terminal",
    "polus11_labtable", "polus11_bloodlab", "polus11_avtosalon",
    "polus_p11_storage", "polus11_crafttable", "polus_fw_jobnpc",
    "polus_p11_stashnpc",
}

local function RaidAnchorSpots()
    local out, seen = {}, {}
    local function push(p)
        local k = math.floor(p.x / 96) .. "_" .. math.floor(p.y / 96)
        if seen[k] then return end
        seen[k] = true
        out[#out + 1] = Vector(p.x, p.y, p.z + 2)
    end
    for _, cls in ipairs(ANCHOR_CLASSES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) and not e.P11_OpPoint and not e.P11_RaidPoint then
                push(e:GetPos())
            end
        end
    end
    for _, e in ipairs(ents.FindByClass("info_player_start")) do
        if IsValid(e) then push(e:GetPos()) end
    end
    return out
end

local function RaidPickSpots(n)
    local pool = RaidAnchorSpots()
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local picked = {}
    local minD = 1200
    local guard = 0
    while #picked < n and guard < 60 do
        guard = guard + 1
        for _, p in ipairs(pool) do
            if #picked >= n then break end
            local ok = true
            for _, q in ipairs(picked) do
                if p:DistToSqr(q) < minD * minD then ok = false break end
            end
            if ok then picked[#picked + 1] = p end
        end
        minD = minD - 240
        if minD < 400 and #picked < n then break end
    end
    while #picked < n do
        local base = pool[1] or Vector(0, 0, 0)
        picked[#picked + 1] = Vector(base.x + math.random(-700, 700),
            base.y + math.random(-700, 700), base.z + 4)
    end
    return picked
end

local function RaidPointsSpawn()
    R.points = {}
    for _, p in ipairs(RaidPickSpots(POINTS_N)) do
        local e = ents.Create("polus11_cappoint")
        if IsValid(e) then
            e:SetPos(p)
            e:SetAngles(Angle(0, math.random(0, 359), 0))
            e:Spawn()
            e:Activate()
            e.P11_RaidPoint = true
            e:SetNWBool("P11_RaidPoint", true)  -- клиентской полосе «какие точки чьи»
            R.points[#R.points + 1] = e
        end
    end
end

local function RaidPointsClear()
    for _, e in ipairs(R.points or {}) do
        if IsValid(e) then e:Remove() end
    end
    R.points = {}
end

-- ============ СТАРТ / ФИНАЛ ============

function POLUS11.RaidStart(ply)
    local att = RaidFactOf(ply)
    if not att then return false end
    R.phase = "raid"
    R.att = att
    R.def = (att == "rkka") and "eagle" or "rkka"
    R.hold = { rkka = 0, eagle = 0 }
    R.endT = CurTime() + RAID_T
    RaidPointsSpawn()
    RaidAnnounce("⚔ РЕЙД! " .. FACT_NAME[att] .. " объявляет рейд: на карте " ..
        #R.points .. " точек прорыва (" .. math.floor(RAID_T / 60) ..
        " мин). Полоса наверху показывает, чья точка — удерживай дольше врага!")
    SetGlobalString("P11_Raid", "raid|" .. math.ceil(RAID_T) .. "|" .. att .. "|" .. R.def)
    POLUS11.Log("РЕЙД: объявил " .. (IsValid(ply) and ply:Nick() or "?") ..
        " (" .. FACT_NAME[att] .. "), точек: " .. #R.points)
    return true
end

local function RaidFinish(abort, by)
    local att, def = R.att, R.def
    local holdAtt = att and R.hold[att] or 0
    local holdDef = def and R.hold[def] or 0
    RaidPointsClear()
    SetGlobalString("P11_Raid", "")

    if abort then
        RaidAnnounce("РЕЙД ОТМЕНЁН командованием — точки прорыва сняты.")
        POLUS11.Log("РЕЙД: отменён (" .. (IsValid(by) and by:Nick() or "консоль") .. ")")
        RaidResetState()
        return
    end

    -- исход: чья сторона дольше суммарно держала точки
    local winAtt = holdAtt > holdDef
    local winner = winAtt and att or def
    local pay = winAtt and WIN_PAY or DEF_PAY
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and RaidFactOf(p) == winner then
            if POLUS11.AddMoney then
                POLUS11.AddMoney(p, pay,
                    "Рейд: " .. (winAtt and "прорыв удался" or "оборона устояла"))
            end
        end
    end

    RaidAnnounce("РЕЙД ЗАВЕРШЁН — победа " .. FACT_NAME[winner] .. "! Контроль точек: " ..
        math.floor(holdAtt) .. "с против " .. math.floor(holdDef) .. "с. " ..
        (winAtt and ("Атакующим +" .. WIN_PAY .. "₽.") or ("Обороне +" .. DEF_PAY .. "₽.")))
    POLUS11.Log("РЕЙД: финал — " .. FACT_NAME[winner] ..
        " (контроль " .. math.floor(holdAtt) .. "с/" .. math.floor(holdDef) .. "с)")
    if att then R.nextAt[att] = CurTime() + CD_T end
    RaidResetState()
end

-- ============ ТИК ============

timer.Create("P11.RaidTick", 2, 0, function()
    if R.phase ~= "raid" then return end
    for _, e in ipairs(R.points) do
        if IsValid(e) then
            local ow = e.GetOwnerFact and e:GetOwnerFact() or ""
            if R.hold[ow] then R.hold[ow] = R.hold[ow] + 2 end
        end
    end
    if CurTime() >= R.endT then
        RaidFinish(false)
        return
    end
    local left = math.max(0, R.endT - CurTime())
    SetGlobalString("P11_Raid", "raid|" .. math.ceil(left) .. "|" .. R.att .. "|" .. R.def)
end)

-- ============ ТЕРМИНАЛ: E ============

function POLUS11.RaidTermUse(ent, ply)
    if not (IsValid(ply) and ply:Alive()) then return end

    if not RaidIsCommander(ply) then
        POLUS11.Notify(ply, "Терминал глухо гудит: рейд объявляют только КОМАНДИРЫ —" ..
            " комиссар/генералы РККА, командир/резидент Орла.")
        ply:EmitSound("buttons/button10.wav", 55, 100)
        return
    end

    local fac = RaidFactOf(ply)
    if not fac then return end

    if R.phase ~= "idle" then
        local left = math.max(1, math.ceil((R.endT - CurTime()) / 60))
        POLUS11.Notify(ply, "Рейд уже идёт: осталось ~" .. left ..
            " мин. Полоса наверху показывает, чьи точки.")
        return
    end

    local cdLeft = (R.nextAt[fac] or 0) - CurTime()
    if cdLeft > 0 then
        POLUS11.Notify(ply, "Дозорные не вернулись: новый рейд твоей стороны через " ..
            math.ceil(cdLeft / 60) .. " мин.")
        ply:EmitSound("buttons/button10.wav", 55, 100)
        return
    end

    if POLUS11.Op and POLUS11.Op.phase and POLUS11.Op.phase ~= "idle" then
        POLUS11.Notify(ply, "Идёт ОПЕРАЦИЯ — рейды молчат до её конца.")
        return
    end

    POLUS11.RaidStart(ply)
    ply:EmitSound("buttons/button15.wav", 70, 100)
end

-- ============ АДМИН-СТОП ============

concommand.Add("p11_raidstop", function(ply)
    if IsValid(ply) and not (P11FW and P11FW.Config and P11FW.Config.Admin(ply)) then
        return
    end
    if R.phase == "idle" then
        local msg = "[РЕЙД] сейчас рейда нет."
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    RaidFinish(true, ply)
end)

print("[POLUS-11] РЕЙДЫ v4.33.0 «ПАТРОН»: терминал рейда · только командиры · 2 точки прорыва · " ..
    math.floor(RAID_T / 60) .. " мин · победа +" .. WIN_PAY .. "₽/оборона +" .. DEF_PAY .. "₽ · кд " ..
    math.floor(CD_T / 60) .. " мин · стоп p11_raidstop")
