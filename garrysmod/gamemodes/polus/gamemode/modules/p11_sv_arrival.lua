-- ============================================================
--  ПОЛЮС-11 — ЗОНА ПРИБЫТИЯ + ТРАНСПОРТ (server) v4.5.0 → v4.8.4
--  v4.8.4 «ВЫСАДКА»: точки ставятся ГДЕ СТОИШЬ (раньше — по прицелу с
--  открытым меню → «случайно и сломано»), КУБ-МАРКЕР места на 5 сек всем,
--  анти-застревание телепорта, смена профы → спавн профы/фракции/ОБЩИЙ.
--  v4.7.3: ЕДИНЫЙ резолвер спавна ArrivalFor (профа > фракция),
--  телепорт на точку СРАЗУ при смене должности, общий спавн больше
--  не драчуется с точками фракций, арестованных не двигаем.
--  «Система спавна через НПС-транспорт»: точка прибытия колонной —
--  сюда встаёт грузовик (LVS Soviet Pack, классы ниже) и сюда же
--  ИГРОКИ СПАВНЯТСЯ. Зону назначаешь КОНКРЕТНОЙ фракции:
--  РККА прибывают к своему капониру, наука — к санпропускнику,
--  misc (новобранцы) — к воротам станции. Нет зоны у фракции —
--  работает общая точка спавна из УТИЛИТ. Зона переживает рестарт.
--  Поставить: /menu → УТИЛИТЫ → «ЗОНА ПРИБЫТИЯ ФРАКЦИИ» +
--  «ГРУЗОВИК КОЛОННЫ». Кадровик-НПС ставится туда же отдельной
--  кнопкой — вот тебе и «спавн через НПС у транспорта».
--  В ТРАНСПОРТЕ (грузовик/любой транспорт) ХОЛОД НЕ КУСАЕТ —
--  см. p11_sv_cold.lua v4.5.0.
-- ============================================================

util.AddNetworkString("P11_ArrivalFX")
util.AddNetworkString("P11_SpawnMark")

-- ============ v4.8.4: КУБ-МАРКЕР ТОЧКИ (всем клиентам) ============
-- заявка владельца: «чтобы спавн ставился виде кубиков на 5 сек,
-- чтобы было видно, где будет спавн». kind: 1 профа, 2 фракция,
-- 3 общий, 4 арест, 5 грузовик. dur — секунд на экране.
function POLUS11.SpawnMark(pos, ang, kind, label, dur)
    if not pos then return end
    net.Start("P11_SpawnMark")
        net.WriteVector(pos)
        net.WriteFloat((ang and ang.y) or 0)
        net.WriteUInt(kind or 1, 3)
        net.WriteString(string.sub(tostring(label or "СПАВН"), 1, 80))
        net.WriteFloat(tonumber(dur) or 5)
    net.Broadcast()
end

local function ArFile()
    return "polus_framework/arrival_" .. game.GetMap() .. ".json"
end

POLUS11.Arrivals = POLUS11.Arrivals or {} -- facId -> { pos=Vector, ang=Angle }
POLUS11.JobArrivals = POLUS11.JobArrivals or {} -- v4.6.1: jobId -> { pos=Vector, ang=Angle } (точка спавна ПРОФЫ)
local TruckSave = nil -- { pos, ang, class }

-- ============ КЛАССЫ ГРУЗОВИКА (LVS Soviet Pack) ============
-- Первый существующий класс из списка и спавнится. Нет пака —
-- зона работает и без машины (НПС+точка), сервер не упадёт.
-- СВОЙ класс впиши сюда первой строкой (смотри в меню спавна LVS).
local TRUCK_CLASSES = {
    "lvs_wheeldrive_gaz66",
    "lvs_wheeldrive_zil131",
    "lvs_wheeldrive_kraz255",
    "lvs_wheeldrive_ural4320",
    "lvs_wheeldrive_gaz52",
}

-- ============ ФАЙЛ ============

local function ArSave()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    local out = { factions = {}, jobs = {}, truck = nil }
    for id, a in pairs(POLUS11.Arrivals) do
        out.factions[id] = {
            x = a.pos.x, y = a.pos.y, z = a.pos.z,
            yaw = a.ang.y or 0,
        }
    end
    for id, a in pairs(POLUS11.JobArrivals or {}) do
        out.jobs[id] = {
            x = a.pos.x, y = a.pos.y, z = a.pos.z,
            yaw = a.ang.y or 0,
        }
    end
    if TruckSave then
        out.truck = {
            x = TruckSave.pos.x, y = TruckSave.pos.y, z = TruckSave.pos.z,
            yaw = TruckSave.ang.y or 0,
            class = TruckSave.class,
        }
    end
    file.Write(ArFile(), util.TableToJSON(out, true))
end

local function SpawnTruck(class, pos, ang)
    local e = ents.Create(class)
    if not IsValid(e) then return nil end
    e:SetPos(pos)
    e:SetAngles(ang)
    e:Spawn()
    e:Activate()
    e.P11_ArrivalTruck = true
    return e
end

local function ArLoad()
    POLUS11.Arrivals = {}
    POLUS11.JobArrivals = {}
    TruckSave = nil
    local raw = file.Read(ArFile(), "DATA")
    if not raw then return end
    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then return end

    for id, d in pairs(tbl.factions or {}) do
        if istable(d) then
            POLUS11.Arrivals[id] = {
                pos = Vector(d.x or 0, d.y or 0, d.z or 0),
                ang = Angle(0, d.yaw or 0, 0),
            }
        end
    end

    for id, d in pairs(tbl.jobs or {}) do
        if istable(d) then
            POLUS11.JobArrivals[id] = {
                pos = Vector(d.x or 0, d.y or 0, d.z or 0),
                ang = Angle(0, d.yaw or 0, 0),
            }
        end
    end

    if istable(tbl.truck) and isstring(tbl.truck.class) then
        TruckSave = {
            pos = Vector(tbl.truck.x or 0, tbl.truck.y or 0, tbl.truck.z or 0),
            ang = Angle(0, tbl.truck.yaw or 0, 0),
            class = tbl.truck.class,
        }
        local e = SpawnTruck(TruckSave.class, TruckSave.pos, TruckSave.ang)
        if not e then
            P11FW.Log("Прибытие: грузовик " .. TruckSave.class .. " не создан (нет LVS Soviet Pack?) — зона работает и без него")
            TruckSave = nil
        end
    end

    local n, nj = 0, 0
    for _ in pairs(POLUS11.Arrivals) do n = n + 1 end
    for _ in pairs(POLUS11.JobArrivals) do nj = nj + 1 end
    P11FW.Log("Прибытие: зон фракций = " .. n .. ", зон проф = " .. nj .. (TruckSave and (", грузовик: " .. TruckSave.class) or ""))
end

hook.Add("InitPostEntity", "P11.ArrivalLoad", function()
    timer.Simple(1.6, ArLoad)
end)
hook.Add("PostCleanupMap", "P11.ArrivalLoad2", function()
    timer.Simple(1.6, ArLoad)
end)

-- ============ API ДЛЯ АДМИН-МЕНЮ ============

function POLUS11.ArrivalSet(ply, facId)
    local ok, facName = false, facId
    for _, c in ipairs(P11FW.CategoryList) do
        if c.id == facId then ok = true facName = c.name or facId break end
    end
    if not ok then P11FW.Notify(ply, "Нет такой фракции: " .. tostring(facId)) return end

    -- v4.8.4 «ВЫСАДКА»: точка — ГДЕ СТОИШЬ ТЫ. Раньше брали прицел
    -- (GetEyeTrace): кнопка жмётся с ОТКРЫТЫМ меню — взгляд в случайную
    -- сторону → точка улетала «случайно и сломано» в стену/за карту.
    POLUS11.Arrivals[facId] = {
        pos = ply:GetPos(),
        ang = Angle(0, ply:EyeAngles().y, 0),
    }
    ArSave()
    P11FW.Notify(ply, "Зона прибытия фракции «" .. facName .. "» поставлена ЗДЕСЬ (куб-ориентир на 5 сек, переживает рестарт).")
    POLUS11.SpawnMark(POLUS11.Arrivals[facId].pos, POLUS11.Arrivals[facId].ang,
        2, "ФРАКЦИЯ: " .. facName .. " (" .. facId .. ")", 5)
    P11FW.Log("Прибытие: " .. ply:Nick() .. " поставил зону для " .. facId)
end

function POLUS11.ArrivalClear(ply, facId)
    POLUS11.Arrivals[facId] = nil
    ArSave()
    P11FW.Notify(ply, "Зона прибытия фракции «" .. facId .. "» убрана.")
end

-- ============ v4.6.1: СПАВН ПРОФЫ (jobId) ============

function POLUS11.ArrivalJobSet(ply, jobId)
    local job = P11FW.Jobs and P11FW.Jobs[jobId]
    if not job then P11FW.Notify(ply, "Нет такой должности: " .. tostring(jobId)) return end

    -- v4.8.4 «ВЫСАДКА»: точка — ГДЕ СТОИШЬ (прицел с открытым меню
    -- разбрасывал точки случайно — вот откуда «спавн сломан»)
    POLUS11.JobArrivals[jobId] = {
        pos = ply:GetPos(),
        ang = Angle(0, ply:EyeAngles().y, 0),
    }
    ArSave()
    P11FW.Notify(ply, "Точка спавна профы «" .. job.name .. "» поставлена ЗДЕСЬ (куб-ориентир на 5 сек, переживает рестарт).")
    POLUS11.SpawnMark(POLUS11.JobArrivals[jobId].pos, POLUS11.JobArrivals[jobId].ang,
        1, "ПРОФА: " .. job.name, 5)
    P11FW.Log("Прибытие: " .. ply:Nick() .. " поставил зону профы " .. jobId)
end

function POLUS11.ArrivalJobClear(ply, jobId)
    POLUS11.JobArrivals[jobId] = nil
    ArSave()
    P11FW.Notify(ply, "Точка спавна профы «" .. tostring(jobId) .. "» убрана.")
end

-- показать админу, какие точки уже расставлены
function POLUS11.ArrivalList(ply)
    local lines = { "=== СПАВНЫ СТАНЦИИ (ты стоишь → ставишь точку туда) ===" }
    local sp = P11FW.GetPoint and P11FW.GetPoint("spawn")
    lines[#lines + 1] = "общий спавн гарнизона: " .. (sp and "ЕСТЬ" or "нет (спавн карты)")
    local nf, nj = 0, 0
    for _ in pairs(POLUS11.Arrivals or {}) do nf = nf + 1 end
    for _ in pairs(POLUS11.JobArrivals or {}) do nj = nj + 1 end
    lines[#lines + 1] = "зон фракций: " .. nf
    for id in pairs(POLUS11.Arrivals or {}) do
        local nm = id
        for _, c in ipairs(P11FW.CategoryList or {}) do if c.id == id then nm = c.name break end end
        lines[#lines + 1] = "  • фракция «" .. nm .. "» (" .. id .. ")"
    end
    lines[#lines + 1] = "зон проф: " .. nj
    for id in pairs(POLUS11.JobArrivals or {}) do
        local job = P11FW.Jobs and P11FW.Jobs[id]
        lines[#lines + 1] = "  • профа «" .. (job and job.name or id) .. "» (" .. id .. ")"
    end
    lines[#lines + 1] = "приоритет: спавн профы > спавн фракции > общая точка > карта"
    lines[#lines + 1] = "🧊 ВСЕ точки показаны кубиками на 8 сек — оглянись вокруг!"
    for _, l in ipairs(lines) do P11FW.Notify(ply, l) end

    -- v4.8.4 «ВЫСАДКА»: и ЗРИМО показать каждую точку куб-маркером
    if POLUS11.SpawnMark then
        local sp = P11FW.GetPoint and P11FW.GetPoint("spawn")
        if sp then POLUS11.SpawnMark(sp.pos, sp.ang, 3, "ОБЩИЙ СПАВН ГАРНИЗОНА", 8) end
        local jl = P11FW.GetPoint and P11FW.GetPoint("jail")
        if jl then POLUS11.SpawnMark(jl.pos, jl.ang, 4, "КАМЕРА АРЕСТА", 8) end
        for id, a in pairs(POLUS11.JobArrivals or {}) do
            local job = P11FW.Jobs and P11FW.Jobs[id]
            POLUS11.SpawnMark(a.pos, a.ang, 1, "ПРОФА: " .. (job and job.name or id), 8)
        end
        for id, a in pairs(POLUS11.Arrivals or {}) do
            local nm = id
            for _, c in ipairs(P11FW.CategoryList or {}) do
                if c.id == id then nm = c.name break end
            end
            POLUS11.SpawnMark(a.pos, a.ang, 2, "ФРАКЦИЯ: " .. nm, 8)
        end
        if TruckSave then
            POLUS11.SpawnMark(TruckSave.pos, TruckSave.ang, 5, "ГРУЗОВИК КОЛОННЫ", 8)
        end
    end
end

local function RemoveArrivalTrucks()
    local n = 0
    for _, e in ipairs(ents.GetAll()) do
        if IsValid(e) and e.P11_ArrivalTruck then e:Remove() n = n + 1 end
    end
    return n
end

function POLUS11.ArrivalTruckPut(ply)
    local tr = ply:GetEyeTrace()
    RemoveArrivalTrucks()

    local cls = nil
    for _, c in ipairs(TRUCK_CLASSES) do
        cls = c
        local probe = ents.Create(c)
        if IsValid(probe) then probe:Remove() break end
        cls = nil
    end

    if not cls then
        P11FW.Notify(ply, "LVS-грузовик не найден: поставь аддон «LVS Soviet Pack» или впиши его класс в TRUCK_CLASSES (p11_sv_arrival.lua). Зона прибытия работает и без машины.")
        return
    end

    local ang = (ply:GetPos() - tr.HitPos):Angle()
    ang.p, ang.r = 0, 0
    local e = SpawnTruck(cls, tr.HitPos + Vector(0, 0, 8), ang + Angle(0, 180, 0))
    if IsValid(e) then
        TruckSave = { pos = tr.HitPos + Vector(0, 0, 8), ang = ang + Angle(0, 180, 0), class = cls }
        ArSave()
        P11FW.Notify(ply, "Грузовик колонны (" .. cls .. ") стоит и сохранён на карте.")
        if POLUS11.SpawnMark then
            POLUS11.SpawnMark(TruckSave.pos, TruckSave.ang, 5, "ГРУЗОВИК КОЛОННЫ", 5)
        end
    else
        P11FW.Notify(ply, "Не смог создать " .. cls)
    end
end

function POLUS11.ArrivalTruckRemove(ply)
    local n = RemoveArrivalTrucks()
    TruckSave = nil
    ArSave()
    P11FW.Notify(ply, n > 0 and "Грузовик колонны убран (после рестарта не воскреснет)." or "Грузовика не было.")
end

-- ============ СПАВН: ЕДИНАЯ ОЧЕРЕДЬ ТОЧЕК (v4.7.3) ============
-- приоритет: точка МОЕЙ ПРОФЫ > зона МОЕЙ фракции
-- (общий спавн-поинт и карта — запасные, их обслуживает fw_sv_setup)

-- единый резолвер: куда ЭТОГО игрока вести (nil = нет своих точек)
function POLUS11.ArrivalFor(ply)
    if not IsValid(ply) then return nil end
    local jobId = P11FW.GetJobId and P11FW.GetJobId(ply)
    local job = P11FW.GetJob and P11FW.GetJob(ply)
    local fac = job and (job.faction or job.category)
    return (jobId and POLUS11.JobArrivals[jobId]) or (fac and POLUS11.Arrivals[fac]) or nil
end

-- v4.8.4: АНТИ-ЗАСТРЕВАНИЕ. Если точка оказалась в стене/в пропе —
-- аккуратно поднимаем бойца вверх до свободного места (до ~96u).
-- Раньше «спавн сломан» выглядел так: телепорт есть, но ты в текстурах.
local function SafeLand(ply)
    if not (IsValid(ply) and ply:Alive()) then return end
    local mins, maxs = ply:GetHull()
    local start = ply:GetPos()
    local tr = util.TraceHull({
        start = start, endpos = start,
        mins = mins, maxs = maxs,
        filter = ply, mask = MASK_PLAYERSOLID,
    })
    if not tr.Hit then return end
    for dz = 8, 96, 8 do
        local p2 = start + Vector(0, 0, dz)
        local tr2 = util.TraceHull({
            start = p2, endpos = p2,
            mins = mins, maxs = maxs,
            filter = ply, mask = MASK_PLAYERSOLID,
        })
        if not tr2.Hit then
            ply:SetPos(p2)
            return
        end
    end
end

-- встать на точку (с античит-пропуском телепорта)
local function ArrivalApply(ply, a, why)
    if not (IsValid(ply) and ply:Alive() and a) then return end
    ply:SetPos(a.pos)
    ply:SetEyeAngles(a.ang)
    SafeLand(ply)
    if POLUS11.ACMarkTeleport then POLUS11.ACMarkTeleport(ply) end
end

-- арестованных/рабов спавн-системой не таскаем (их ведёт fw_sv_punish)
local function PunishedSkip(ply)
    return IsValid(ply) and (ply:GetNWString("P11FW_Punish", "") ~= "")
end

hook.Add("PlayerSpawn", "P11.ArrivalSpawn", function(ply)
    timer.Simple(0.09, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if PunishedSkip(ply) then return end
        ArrivalApply(ply, POLUS11.ArrivalFor(ply))
    end)
end)

-- v4.7.3: ТЕЛЕПОРТ СРАЗУ ПРИ СМЕНЕ ДОЛЖНОСТИ (вкл/выкл — конфиг
-- JobTeleportOnChange в p11_sh_config). Багрепорт: «был поваром,
-- стал РККА — положение не меняется вообще».
hook.Add("P11FW.JobChanged", "P11.ArrivalJobTP", function(ply, jobId, oldId)
    if POLUS11.Config and POLUS11.Config.JobTeleportOnChange == false then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if PunishedSkip(ply) then return end
    timer.Simple(0.15, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if P11FW.GetJobId(ply) ~= jobId then return end -- успел сменить ещё раз
        if PunishedSkip(ply) then return end
        local a = POLUS11.ArrivalFor(ply)
        -- v4.8.4: нет точки профы/фракции — увести хотя бы на ОБЩИЙ
        -- спавн (заявка: «при выборе профы ты не спавнишься на спавне»)
        if not a and P11FW.GetPoint then a = P11FW.GetPoint("spawn") end
        if not a then return end
        ArrivalApply(ply, a)
        ply:EmitSound("buttons/button15.wav", 60, 105)
        local job = P11FW.Jobs[jobId]
        POLUS11.Notify(ply, "📍 Ты прибыл на место службы: " .. (job and job.name or jobId) .. ".")
    end)
end)

-- кинематографическое «прибыл» при ПЕРВОМ заходе (если зона есть)
hook.Add("PlayerInitialSpawn", "P11.ArrivalFXJoin", function(ply)
    timer.Simple(7, function()
        if not IsValid(ply) then return end
        local job = P11FW.GetJob and P11FW.GetJob(ply)
        local fac = job and (job.faction or job.category)
        if fac and POLUS11.Arrivals[fac] then
            net.Start("P11_ArrivalFX")
                net.WriteString(fac)
            net.Send(ply)
        end
    end)
end)

-- ============ КОНСОЛЬ ============

concommand.Add("p11_arrival", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local sub = tostring(args[1] or "")
    if sub == "truck" then
        POLUS11.ArrivalTruckPut(ply)
    elseif sub == "untruck" then
        POLUS11.ArrivalTruckRemove(ply)
    elseif sub == "job" and args[2] then
        POLUS11.ArrivalJobSet(ply, args[2])      -- p11_arrival job nkvd_oper
    elseif sub == "unjob" and args[2] then
        POLUS11.ArrivalJobClear(ply, args[2])
    elseif sub == "list" or sub == "marks" then
        POLUS11.ArrivalList(ply) -- печатает и заодно показывает кубики
    elseif sub == "untruck_legacy" then
        POLUS11.ArrivalTruckRemove(ply)
    elseif args[1] and args[1] ~= "" then
        POLUS11.ArrivalSet(ply, args[1]) -- p11_arrival rkka
    else
        local out = "p11_arrival <facId> — поставить зону прибытия здесь • p11_arrival truck/untruck — грузовик"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, out) else print(out) end
    end
end)

-- ============ v4.7.3: диагностика очереди спавна ============
concommand.Add("p11_spawndiag", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local out = { "== СПАВН СТАНЦИИ: ДИАГНОСТИКА v4.7.3 ==" }
    local nf, nj = 0, 0
    for _ in pairs(POLUS11.Arrivals or {}) do nf = nf + 1 end
    for _ in pairs(POLUS11.JobArrivals or {}) do nj = nj + 1 end
    out[#out + 1] = "  точек фракций: " .. nf .. " | точек проф: " .. nj
    out[#out + 1] = "  общий спавн: " .. ((P11FW.GetPoint and P11FW.GetPoint("spawn")) and "ЕСТЬ (применяется ТОЛЬКО при отсутствии точек профы/фракции)" or "нет")
    out[#out + 1] = "  телепорт при смене должности: "
        .. ((POLUS11.Config and POLUS11.Config.JobTeleportOnChange ~= false) and "ВКЛ" or "ВЫКЛ (JobTeleportOnChange=false)")
    out[#out + 1] = "  -- разбор по игрокам (куда станет при спавне):"
    for _, p in ipairs(player.GetAll()) do
        local jobId = P11FW.GetJobId and P11FW.GetJobId(p) or "?"
        local job = P11FW.Jobs and P11FW.Jobs[jobId]
        local fac = job and (job.faction or job.category) or "?"
        local how = "карта/общая"
        if POLUS11.JobArrivals[jobId] then how = "ТОЧКА ПРОФЫ (" .. jobId .. ")"
        elseif POLUS11.Arrivals[fac] then how = "зона фракции (" .. fac .. ")"
        elseif P11FW.GetPoint and P11FW.GetPoint("spawn") then how = "ОБЩИЙ спавн" end
        local pun = p:GetNWString("P11FW_Punish", "")
        out[#out + 1] = string.format("     %-20s %-28s → %s%s",
            p:Nick(), job and job.name or jobId, how,
            pun ~= "" and ("  [НАКАЗАН: ведёт пенальти-система]") or "")
    end
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[POLUS-11] спавн v4.8.4 «ВЫСАДКА»: точка ГДЕ СТОИШЬ (не прицел), куб-маркер 5с, анти-застревание, смена профы → спавн профы > фракции > ОБЩИЙ спавн; p11_arrival marks / p11_spawndiag")
