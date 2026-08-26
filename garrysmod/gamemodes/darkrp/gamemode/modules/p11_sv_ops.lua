-- ============================================================
--  ПОЛЮС-11 — ОПЕРАЦИИ «РУБЕЖ» (сервер) v4.24.0
--  Админский ивент (реворк «ЛЕДОКОЛА», заявка владельца):
--  админ жмёт «НАЧАТЬ» у себя во вкладке ОПЕРАЦИИ (C-меню) →
--  у ВСЕХ бойцов профы слетают на новобранца → окно выбора
--  фракции «СССР / АМЕРИКА» → выбравшие автоматом становятся
--  солдатами своей стороны → на карте СЛУЧАЙНО встают точки
--  захвата (энтити «ФЛАГ») → 30 минут РДМ-ивента: удержать
--  ВСЕ точки 3 минуты подряд — досрочная победа (v4.28.0). Финал —
--  лидерборд и деньги: победителям 5000₽, проигравшим 1000₽
--  (ничья — по 2500₽), только участникам онлайн.
--  v4.24.2 «ЗНАМЯ»: выбор стороны выдаёт КОМАНДНЫЕ профы «Солдат
--  СССР»/«Солдат США» (скрыты из F4 — только система или команда
--  p11_opjob), рация сама садится на личный канал стороны
--  ★ СССР / ★ США (закреплён до финала), в глобал-строке — живой
--  счёт записи сторон.
-- ============================================================

util.AddNetworkString("P11_OpUI")    -- сервер→клиент: зов (recruit/battle) / статус
util.AddNetworkString("P11_OpPick")  -- клиент→сервер: выбор фракции / админ-команды
util.AddNetworkString("P11_OpBoard") -- сервер→клиент: лидерборд (JSON)

local RECRUIT_T = 45          -- запись сторон
local BATTLE_T  = 30 * 60     -- бой
local HOLD_WIN  = 3 * 60      -- держать ВСЕ точки столько подряд (v4.28.0 «МЕТЕО»: 3 мин по заявке)
local POINTS_N  = 4           -- точек на карте (v5.0.2: РУБЕЖ — 4 точки по заявке владельца)
-- v4.31.0 «КРЫЛО»: комплект строго из набора + страховка «ровно N» (баг
-- владельца «может быть меньше точек, что всё руинет») + спавны НЕ у флагов
-- v5.0.2: точек 4 (А–Г) по заявке владельца
local OP_LETTERS = { "А", "Б", "В", "Г" }
local WIN_PAY, LOSE_PAY, DRAW_PAY = 5000, 1000, 2500

POLUS11.Op = POLUS11.Op or {}
local Op = POLUS11.Op

local function OpResetAll()
    Op.phase  = "idle"
    Op.side   = {}   -- [ply] = "rkka"|"eagle"
    Op.hold   = { rkka = 0, eagle = 0 }
    Op.kills  = { rkka = 0, eagle = 0 }
    Op.pkills = {}   -- [ply] = { name, fac, k }
    Op.points = {}
    Op.endT   = 0
    Op.recruitEnd = 0
    Op.endUntil = 0
    Op.healT  = 0   -- v4.31.0 «КРЫЛО»: антиспам самолечения точек
end
OpResetAll()

local FACT_NAME = { rkka = "СССР", eagle = "АМЕРИКА" }

-- v4.24.2 «ЗНАМЯ»: личные каналы рации сторон (садятся автоматом при записи)
if POLUS11.RadioChannels then
    POLUS11.RadioChannels.op_sssr = "★ СССР"
    POLUS11.RadioChannels.op_usa  = "★ США"
end

local function OpAnnounce(txt)
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString("ОПЕРАЦИЯ «РУБЕЖ»")
    net.Broadcast()
end

local function OpReset(ply)
    P11FW.SetJob(ply, (P11FW.Config and P11FW.Config.DefaultJob) or "recruit", nil, true)
end

-- участникам в ходе операции профы не меняют (ворота fw_sv_jobs)
function POLUS11.OpJobBlock(ply)
    return IsValid(ply) and Op.phase ~= "idle" and Op.side[ply] ~= nil
end

-- ============ ТОЧКИ НА КАРТЕ (случайные) ============

local ANCHOR_CLASSES = {
    "polus_p11_shopnpc", "polus_p11_contractnpc", "polus_p11_jailnpc",
    "polus11_hearth", "polus_p11_kitchen", "polus11_terminal",
    "polus11_labtable", "polus11_bloodlab", "polus11_avtosalon",
    "polus_p11_storage", "polus11_crafttable", "polus_fw_jobnpc",
    "polus11_cappoint",
}

local function AnchorSpots()
    local out, seen = {}, {}
    local function push(p)
        local k = math.floor(p.x / 96) .. "_" .. math.floor(p.y / 96)
        if seen[k] then return end
        seen[k] = true
        out[#out + 1] = Vector(p.x, p.y, p.z + 2)
    end
    for _, cls in ipairs(ANCHOR_CLASSES) do
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) and not e.P11_OpPoint then push(e:GetPos()) end
        end
    end
    for _, e in ipairs(ents.FindByClass("info_player_start")) do
        if IsValid(e) then push(e:GetPos()) end
    end
    return out
end

-- ============================================================
--  v5.0.1 «БЕТА»: НАСТОЯЩИЙ СЛУЧАЙНЫЙ СПАВН ПО ВСЕЙ КАРТЕ
--  Якоря (НПС/объекты) могли быть редкими — точки и спавны
--  падали в одно место. Теперь пул = якоря + СЛУЧАЙНЫЕ точки
--  по границам карты (трассировка сверху вниз — точка встаёт
--  НА ЗЕМЛЮ, а не в стену/воздух/воду).
-- ============================================================

local MAP_MINS, MAP_MAXS = Vector(0, 0, 0), Vector(0, 0, 0)
local MAP_READY = false

local function MapBounds()
    if not MAP_READY then
        MAP_READY = true
        local ok, mn, mx = pcall(ents.GetMapBounds)
        if ok and mn and mx then
            MAP_MINS, MAP_MAXS = mn, mx
        end
    end
    return MAP_MINS, MAP_MAXS
end

-- случайная точка по карте: падает на твёрдую поверхность (пол/землю)
local function RandomMapSpot()
    local mn, mx = MapBounds()
    local cx = (mn.x + mx.x) / 2
    local cy = (mn.y + mx.y) / 2
    local hw = math.max(800, (mx.x - mn.x) / 2 - 300)   -- с отступом от краёв
    local hh = math.max(800, (mx.y - mn.y) / 2 - 300)
    for _ = 1, 12 do -- 12 попыток найти чистую площадку
        local x = cx + math.random(-hw, hw)
        local y = cy + math.random(-hh, hh)
        local top = mn.z + (mx.z - mn.z) * 0.9
        local tr = util.TraceLine({
            start = Vector(x, y, top),
            endpos = Vector(x, y, mn.z - 200),
            mask = MASK_SOLID,
        })
        if tr.Hit and tr.HitPos then
            local p = tr.HitPos + Vector(0, 0, 6)
            -- не в воде (поверхность ниже уровня воды — грубая проверка)
            if p.z > mn.z + 40 then
                return p
            end
        end
    end
    return nil
end

-- общий пул: якоря + случайные точки карты (доля случайных растёт)
local function MixedPool(randomFrac)
    local pool = AnchorSpots()
    local nRand = math.max(2, math.floor((#pool + 2) * (randomFrac or 0.5)))
    for i = 1, nRand do
        local p = RandomMapSpot()
        if p then pool[#pool + 1] = p end
    end
    return pool
end

-- v5.0.1 «БЕТА»: экспорт для рейда (модуль грузится позже, локальные не видны)
POLUS11.RandomMapSpot = RandomMapSpot
POLUS11.MixedPool = MixedPool
POLUS11.MapBounds = MapBounds

local function PickOpSpots(n)
    -- v5.0.1 «БЕТА»: точки из СМЕШАННОГО пула — якоря + случайные по карте
    local pool = MixedPool(0.6)
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local picked = {}
    local minD = 1300
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
        if minD < 420 and #picked < n then break end
    end
    while #picked < n do
        -- v5.0.1 «БЕТА»: добивка — случайные точки карты (не вокруг Vector(0,0,0))
        local rp = RandomMapSpot()
        if rp then
            picked[#picked + 1] = rp
        else
            local base = pool[1] or Vector(0, 0, 0)
            picked[#picked + 1] = Vector(base.x + math.random(-700, 700), base.y + math.random(-700, 700), base.z + 4)
        end
    end
    return picked
end

-- v4.31.0 «КРЫЛО»: фабрика флага (буква — строго из комплекта); v5.0.2: А–Г
local function OpPointMake(p, name)
    local e = ents.Create("polus11_cappoint")
    if not IsValid(e) then return nil end
    e:SetPos(p)
    e:SetAngles(Angle(0, math.random(0, 359), 0))
    e:Spawn()
    e:Activate()
    e.P11_OpPoint = true
    e:SetNWBool("P11_OpPoint", true)  -- v4.24.1 «МАЯК»: маяки мест точек на HUD
    if name and e.SetPointName then e:SetPointName(name) end
    return e
end

-- свободная площадка: не ближе 700 к уже стоящим флагам опы
local function OpFarEnough(p)
    for _, e in ipairs(Op.points or {}) do
        if IsValid(e) and p:DistToSqr(e:GetPos()) < 700 * 700 then return false end
    end
    return true
end

local function OpPointsSpawn()
    Op.points = {}
    for i, p in ipairs(PickOpSpots(POINTS_N)) do
        local e = OpPointMake(p, OP_LETTERS[i])
        if IsValid(e) then Op.points[#Op.points + 1] = e end
    end
    -- v4.31.0 «КРЫЛО»: страховка «РОВНО 4» — энтити не встала → добиваем добором
    local guard = 0
    while #Op.points < POINTS_N and guard < 8 do
        guard = guard + 1
        for _, p2 in ipairs(PickOpSpots(POINTS_N)) do
            if #Op.points >= POINTS_N then break end
            if OpFarEnough(p2) then
                local e2 = OpPointMake(p2, OP_LETTERS[#Op.points + 1])
                if IsValid(e2) then Op.points[#Op.points + 1] = e2 end
            end
        end
    end
    if POLUS11.Log then
        POLUS11.Log("ОПЕРАЦИЯ: точек встало " .. #Op.points .. "/" .. POINTS_N)
    end
end

local function OpPointsClear()
    for _, e in ipairs(Op.points or {}) do
        if IsValid(e) then e:Remove() end
    end
    Op.points = {}
end

-- ============ СТОРОНЫ ============

-- ============ v4.31.0 «КРЫЛО»: СПАВНЫ НА ОПЕРАЦИИ — СЛУЧАЙНЫЕ, НЕ У ФЛАГОВ ============
-- Заявка владельца: «спавны должны быть случайные, а не у точек, а то анлак
-- последнюю захватить». Боец встаёт на СЛУЧАЙНОМ якоре станции (объект/спавн
-- карты), но дальше 650 юн от ЛЮБОГО флага (и опы, и карточного): точки
-- берутся боем, а не респавном на них. Пусто — кольцо 500–800 вокруг
-- случайного флага опы (не на нём самом).
local function OpRandomSpawnPos(ply)
    local flags = {}
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) then flags[#flags + 1] = e:GetPos() end
    end
    -- v5.0.1 «БЕТА»: пул = якоря + случайные точки карты (спавн по всей станции)
    local pool = MixedPool(0.7)
    for i = #pool, 2, -1 do -- тасуем якоря
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    for _, p in ipairs(pool) do
        local ok = true
        for _, q in ipairs(flags) do
            if p:DistToSqr(q) < 650 * 650 then ok = false break end
        end
        if ok then
            return p + Vector(math.random(-120, 120), math.random(-120, 120), 6)
        end
    end
    local ops = {}
    for _, e in ipairs(Op.points or {}) do
        if IsValid(e) then ops[#ops + 1] = e:GetPos() end
    end
    if #ops > 0 then
        local b = ops[math.random(#ops)]
        local a = math.random() * math.pi * 2
        local r = 500 + math.random() * 300
        return b + Vector(math.cos(a) * r, math.sin(a) * r, 10)
    end
    return nil
end

local function OpTeleportRandom(ply, delay)
    timer.Simple(delay, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local pos = OpRandomSpawnPos(ply)
        if pos then
            ply:SetPos(pos)
            ply:SetEyeAngles(Angle(0, math.random(0, 359), 0))
        end
    end)
end

local function OpAssign(ply, fac)
    if not (IsValid(ply) and ply:Alive()) then return end
    if fac ~= "rkka" and fac ~= "eagle" then return end
    Op.side[ply] = fac
    ply:SetNWString("P11_OpSide", fac)
    -- v4.24.2 «ЗНАМЯ»: командные профы сторон (скрыты из F4, только система/команда)
    local jobId = (fac == "eagle") and "seed_op_usa" or "seed_op_sssr"
    if not (P11FW.Jobs and P11FW.Jobs[jobId]) then
        jobId = (fac == "eagle") and "seed_eagle_svyaznoi" or "seed_rkka_soldat" -- страховка
    end
    P11FW.SetJob(ply, jobId, nil, true)
    -- рация стороны: ★ СССР / ★ США — закреплена до финала
    local ch = (fac == "eagle") and "op_usa" or "op_sssr"
    ply:SetNWString("P11_RadioCh", ch)
    -- v4.31.0 «КРЫЛО»: вступил в горячий бой — в случайном месте (не у флага)
    if Op.phase == "battle" then
        OpTeleportRandom(ply, 0.8)
    end
    POLUS11.Notify(ply, "Ты солдат стороны «" .. FACT_NAME[fac] ..
        "»! Рация закреплена на канале «" .. (POLUS11.RadioChannels[ch] or ch) ..
        "». Оружие к бою — точки решат всё!")
end

-- живой счёт записи сторон (для HUD и окна выбора)
local function OpSideCounts()
    local a, b = 0, 0
    for ply, f in pairs(Op.side) do
        if IsValid(ply) then
            if f == "rkka" then a = a + 1 elseif f == "eagle" then b = b + 1 end
        end
    end
    return a, b
end

local function OpAutoBalance(ply)
    local a, b = 0, 0
    for _, f in pairs(Op.side) do
        if f == "rkka" then a = a + 1 elseif f == "eagle" then b = b + 1 end
    end
    OpAssign(ply, (a <= b) and "rkka" or "eagle")
end

-- ============ ХОД ОПЕРАЦИИ ============

function POLUS11.OpStart(by)
    if Op.phase ~= "idle" then
        if IsValid(by) then POLUS11.Notify(by, "Операция уже идёт: фаза «" .. Op.phase .. "».") end
        return
    end
    -- v4.24.1 «МАЯК»: два ивента сразу не идут — во время рейда операции молчат
    if POLUS11.Raid and POLUS11.Raid.phase and POLUS11.Raid.phase ~= "idle" then
        if IsValid(by) then POLUS11.Notify(by, "Идёт РЕЙД — операцию объявишь после его финала.") end
        return
    end
    -- v4.31.0 «КРЫЛО»: сносим ошмётки прошлых операций (после краша могли
    -- остаться «лишние» флаги — отсюда счёт 5/3 вместо ровно N)
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) and (e.P11_OpPoint or e:GetNWBool("P11_OpPoint", false)) then e:Remove() end
    end
    OpResetAll()
    Op.phase = "recruit"
    Op.recruitEnd = CurTime() + RECRUIT_T
    -- «кик с проф на новобранца» у всей станции
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then OpReset(ply) end
    end
    OpAnnounce("ОПЕРАЦИЯ «РУБЕЖ» ОБЪЯВЛЕНА: вахты сброшены! Выбери сторону — СССР или АМЕРИКА. Запись " .. RECRUIT_T .. " сек.")
    net.Start("P11_OpUI")
        net.WriteString("call")
    net.Broadcast()
    SetGlobalString("P11_Op", "recruit|" .. RECRUIT_T .. "|0|0")
    POLUS11.Log("ОПЕРАЦИЯ: старт от " .. (IsValid(by) and by:Nick() or "консоли"))
end

function POLUS11.OpAbort(by)
    if Op.phase == "idle" then return end
    OpPointsClear()
    for ply in pairs(Op.side) do
        if IsValid(ply) then
            ply:SetNWString("P11_OpSide", "")
            ply:SetNWString("P11_RadioCh", "all") -- v4.24.2: канал стороны снят
            OpReset(ply)
        end
    end
    OpAnnounce("ОПЕРАЦИЯ ОТМЕНЕНА командованием. Вахты свободны — выбери должность в F4.")
    SetGlobalString("P11_Op", "")
    POLUS11.Log("ОПЕРАЦИЯ: отменена (" .. (IsValid(by) and by:Nick() or "консоль") .. ")")
    OpResetAll()
end

local function OpBattleStart()
    Op.phase = "battle"
    Op.endT = CurTime() + BATTLE_T
    -- нерешившиеся — автобаланс в меньшую сторону
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and not Op.side[ply] then
            OpAutoBalance(ply)
        end
    end
    OpPointsSpawn()
    -- v4.31.0 «КРЫЛО»: стороны разбросаны по СЛУЧАЙНЫМ местам карты (не у флагов)
    for ply2 in pairs(Op.side) do
        OpTeleportRandom(ply2, 1.0 + math.random() * 1.5)
    end
    OpAnnounce("БОЙ НАЧАЛСЯ: на станции " .. #Op.points ..
        " точек захвата! Удерживайте ВСЕ сразу 3 минуты — или больше по итогу 30 минут. Огонь по чужой стороне разрешён.")
    net.Start("P11_OpUI")
        net.WriteString("battle")
    net.Broadcast()
end

local function OpFinish(result)
    Op.phase = "end"
    Op.endUntil = CurTime() + 25

    -- награды активным (участникам онлайн)
    for ply in pairs(Op.side) do
        if IsValid(ply) then
            local mine = Op.side[ply]
            local pay = (result == "draw") and DRAW_PAY
                or (mine == result and WIN_PAY or LOSE_PAY)
            if POLUS11.AddMoney then
                POLUS11.AddMoney(ply, pay, "Операция «РУБЕЖ»: " ..
                    (result == "draw" and "ничья" or (mine == result and "победа стороны" or "проигрыш стороны")))
            end
        end
    end

    local tname = (result == "draw") and "НИЧЬЯ" or ("ПОБЕДА: " .. (FACT_NAME[result] or "?"))
    OpAnnounce("ОПЕРАЦИЯ ЗАВЕРШЕНА — " .. tname .. "! Победителям 5000₽, проигравшим 1000₽ (участникам). Лидерборд на экране.")

    -- лидерборд
    local top = {}
    for _, rec in pairs(Op.pkills) do
        top[#top + 1] = rec
    end
    table.sort(top, function(a, b) return (a.k or 0) > (b.k or 0) end)
    while #top > 8 do top[#top] = nil end
    net.Start("P11_OpBoard")
        net.WriteString(util.TableToJSON({
            winner = result, wname = tname,
            holdA = math.floor(Op.hold.rkka), holdB = math.floor(Op.hold.eagle),
            killsA = Op.kills.rkka, killsB = Op.kills.eagle,
            top = top, winPay = WIN_PAY, losePay = LOSE_PAY, drawPay = DRAW_PAY,
        }) or "{}")
    net.Broadcast()
    POLUS11.Log("ОПЕРАЦИЯ: финал — " .. tname ..
        " (держали " .. math.floor(Op.hold.rkka) .. "с/" .. math.floor(Op.hold.eagle) ..
        "с, фраги " .. Op.kills.rkka .. "/" .. Op.kills.eagle .. ")")
end

local function OpCleanup()
    OpPointsClear()
    for ply in pairs(Op.side) do
        if IsValid(ply) then
            ply:SetNWString("P11_OpSide", "")
            ply:SetNWString("P11_RadioCh", "all") -- v4.24.2: канал стороны снят
            OpReset(ply)
            POLUS11.Notify(ply, "Операция окончена. Вахта свободна — выбери должность в F4.")
        end
    end
    SetGlobalString("P11_Op", "")
    OpResetAll()
end

-- ============ ТИК ============

timer.Create("P11.OpTick", 2, 0, function()
    if Op.phase == "recruit" then
        local left = math.max(0, Op.recruitEnd - CurTime())
        local nA, nB = OpSideCounts()
        SetGlobalString("P11_Op", "recruit|" .. math.ceil(left) .. "|" .. nA .. "|" .. nB)
        if left <= 0 then OpBattleStart() end
        return
    end

    if Op.phase == "battle" then
        -- владение точками
        local own = { rkka = 0, eagle = 0 }
        local alivePts = 0
        for _, e in ipairs(Op.points) do
            if IsValid(e) then
                alivePts = alivePts + 1
                local ow = e.GetOwnerFact and e:GetOwnerFact() or ""
                if own[ow] then own[ow] = own[ow] + 1 end
            end
        end
        -- v4.31.0 «КРЫЛО»: САМОЛЕЧЕНИЕ комплекта — точку снесло (клинап карты,
        -- команда), добиваем до 4 (не чаще раза в 20 сек, держание не сбрасываем)
        if alivePts < POINTS_N and CurTime() >= (Op.healT or 0) then
            Op.healT = CurTime() + 20
            local used = {}
            for _, e2 in ipairs(Op.points) do
                if IsValid(e2) then used[e2.GetPointName and e2:GetPointName() or ""] = true end
            end
            local freeNames = {}
            for _, L in ipairs(OP_LETTERS) do
                if not used[L] then freeNames[#freeNames + 1] = L end
            end
            local added = 0
            for _, p3 in ipairs(PickOpSpots(POINTS_N)) do
                if alivePts + added >= POINTS_N then break end
                if OpFarEnough(p3) and freeNames[added + 1] then
                    local e3 = OpPointMake(p3, freeNames[added + 1])
                    if IsValid(e3) then
                        Op.points[#Op.points + 1] = e3
                        added = added + 1
                    end
                end
            end
            if added > 0 then
                if POLUS11.Log then
                    POLUS11.Log("ОПЕРАЦИЯ: самолечение — было " .. alivePts .. "/" .. POINTS_N .. ", добито +" .. added)
                end
                OpAnnounce("Связь с потерянной точкой восстановлена: на карте снова " .. POINTS_N .. " флага. Бой продолжается!")
            end
        end

        -- держим ВСЕ сразу?
        if alivePts > 0 and own.rkka == alivePts then
            Op.hold.rkka = Op.hold.rkka + 2
        end
        if alivePts > 0 and own.eagle == alivePts then
            Op.hold.eagle = Op.hold.eagle + 2
        end

        -- досрочная победа удержанием
        if Op.hold.rkka >= HOLD_WIN or Op.hold.eagle >= HOLD_WIN then
            OpFinish(Op.hold.rkka >= HOLD_WIN and "rkka" or "eagle")
            return
        end

        -- таймер вышел — по итогам
        if CurTime() >= Op.endT then
            local res = "draw"
            if Op.hold.rkka ~= Op.hold.eagle then
                res = (Op.hold.rkka > Op.hold.eagle) and "rkka" or "eagle"
            elseif own.rkka ~= own.eagle then
                res = (own.rkka > own.eagle) and "rkka" or "eagle"
            elseif Op.kills.rkka ~= Op.kills.eagle then
                res = (Op.kills.rkka > Op.kills.eagle) and "rkka" or "eagle"
            end
            OpFinish(res)
            return
        end

        local left = math.max(0, Op.endT - CurTime())
        local nA, nB = OpSideCounts()
        SetGlobalString("P11_Op", "battle|" .. math.ceil(left) .. "|" ..
            math.floor(Op.hold.rkka) .. "|" .. math.floor(Op.hold.eagle) ..
            "|" .. own.rkka .. "|" .. own.eagle .. "|" .. alivePts ..
            "|" .. nA .. "|" .. nB)
        return
    end

    if Op.phase == "end" and CurTime() >= Op.endUntil then
        OpCleanup()
    end
end)

-- фраги противоположной стороны — в счёт
hook.Add("PlayerDeath", "P11.OpFrag", function(vic, inf, att)
    if Op.phase ~= "battle" then return end
    local fv = IsValid(vic) and Op.side[vic] or nil
    local fa = IsValid(att) and att:IsPlayer() and Op.side[att] or nil
    if fv and fa and fv ~= fa then
        Op.kills[fa] = Op.kills[fa] + 1
        local rec = Op.pkills[att]
        if not rec then
            rec = { name = att:Nick(), fac = fa, k = 0 }
            Op.pkills[att] = rec
        end
        rec.k = rec.k + 1
        rec.name = att:Nick()
    end
end)

-- v4.31.0 «КРЫЛО»: респавн бойца операции — случайное место, не у флага
hook.Add("PlayerSpawn", "P11.OpRandSpawn", function(ply)
    if Op.phase ~= "battle" then return end
    if not (Op.side and Op.side[ply]) then return end
    OpTeleportRandom(ply, 0.4)
end)

-- поздний вход в горячую точку
hook.Add("PlayerInitialSpawn", "P11.OpJoin", function(ply)
    timer.Simple(9, function()
        if not IsValid(ply) then return end
        if (Op.phase == "recruit" or Op.phase == "battle") and not Op.side[ply] then
            net.Start("P11_OpUI")
                net.WriteString("call")
            net.Send(ply)
        end
    end)
end)

hook.Add("PlayerDisconnected", "P11.OpBye", function(ply)
    if Op.side and Op.side[ply] then
        Op.side[ply] = nil -- вознаграждение только онлайн-участникам
        Op.pkills[ply] = nil
    end
end)

-- ============ СЕТЬ: выбор фракции / админ ============

net.Receive("P11_OpPick", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_OpNext = ply.P11_OpNext or 0
    if CurTime() < ply.P11_OpNext then return end
    ply.P11_OpNext = CurTime() + 0.5

    local msg = string.sub(net.ReadString() or "", 1, 16)

    if msg == "adm_start" or msg == "adm_stop" then
        if not (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply)) then return end
        if msg == "adm_start" then POLUS11.OpStart(ply) else POLUS11.OpAbort(ply) end
        return
    end

    if Op.phase ~= "recruit" and Op.phase ~= "battle" then return end
    if Op.side[ply] then
        POLUS11.Notify(ply, "Сторона уже выбрана: «" .. (FACT_NAME[Op.side[ply]] or "?") .. "». За Родину!")
        return
    end
    OpAssign(ply, msg)
    net.Start("P11_OpUI")
        net.WriteString("joined|" .. msg)
    net.Send(ply)
end)

-- v4.24.2 «ЗНАМЯ»: командные профы операции вручную — только админам (ранг 4+)
concommand.Add("p11_opjob", function(ply, _, args)
    if IsValid(ply) and not (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply)) then
        POLUS11.Notify(ply, "Командные профы операции выдают только админы (ранг 4+).")
        return
    end
    local side = string.lower(tostring(args and args[1] or ""))
    if side ~= "sssr" and side ~= "usa" then
        local msg = "[ОП] p11_opjob <sssr|usa> [ник] — выдать «Солдат СССР» / «Солдат США»"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    local target = ply
    if args and args[2] then
        local pat = string.lower(tostring(args[2]))
        target = nil
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and string.find(string.lower(p:Nick()), pat, 1, true) then
                target = p break
            end
        end
    end
    if not IsValid(target) then
        local msg = "[ОП] Боец не найден — живой ник подстрокой."
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    local jobId = (side == "usa") and "seed_op_usa" or "seed_op_sssr"
    if not (P11FW.Jobs and P11FW.Jobs[jobId]) then
        local msg = "[ОП] Командная профа «" .. jobId .. "» не завезена — сид доезжает при рестарте."
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    P11FW.SetJob(target, jobId, nil, true)
    local ch = (side == "usa") and "op_usa" or "op_sssr"
    target:SetNWString("P11_RadioCh", ch)
    local jn = (P11FW.Jobs[jobId] and P11FW.Jobs[jobId].name) or jobId
    POLUS11.Notify(target, "Командование выдало тебе должность «" .. jn ..
        "» — рация на канале «" .. (POLUS11.RadioChannels[ch] or ch) .. "».")
    POLUS11.Log("ОП: " .. (IsValid(ply) and ply:Nick() or "консоль") ..
        " выдал " .. target:Nick() .. " → " .. jobId)
end)

print("[POLUS-11] ОПЕРАЦИИ «РУБЕЖ» v4.24.2 «ЗНАМЯ»: админ-старт, командные профы СССР/США, ★-каналы, точки, 5к/1к, p11_opjob")
