-- ============================================================
--  ПОЛЮС-11 — ЗОНА ПРИБЫТИЯ + ТРАНСПОРТ (server) v4.5.0
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

local function ArFile()
    return "polus_framework/arrival_" .. game.GetMap() .. ".json"
end

POLUS11.Arrivals = POLUS11.Arrivals or {} -- facId -> { pos=Vector, ang=Angle }
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
    local out = { factions = {}, truck = nil }
    for id, a in pairs(POLUS11.Arrivals) do
        out.factions[id] = {
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

    local n = 0
    for _ in pairs(POLUS11.Arrivals) do n = n + 1 end
    P11FW.Log("Прибытие: зон фракций = " .. n .. (TruckSave and (", грузовик: " .. TruckSave.class) or ""))
end

hook.Add("InitPostEntity", "P11.ArrivalLoad", function()
    timer.Simple(1.6, ArLoad)
end)
hook.Add("PostCleanupMap", "P11.ArrivalLoad2", function()
    timer.Simple(1.6, ArLoad)
end)

-- ============ API ДЛЯ АДМИН-МЕНЮ ============

function POLUS11.ArrivalSet(ply, facId)
    local ok = false
    for _, c in ipairs(P11FW.CategoryList) do
        if c.id == facId then ok = true break end
    end
    if not ok then P11FW.Notify(ply, "Нет такой фракции: " .. tostring(facId)) return end

    local tr = ply:GetEyeTrace()
    POLUS11.Arrivals[facId] = {
        pos = tr.HitPos + Vector(0, 0, 4),
        ang = Angle(0, ply:EyeAngles().y, 0),
    }
    ArSave()
    P11FW.Notify(ply, "Зона прибытия фракции «" .. facId .. "» поставлена здесь (переживает рестарт).")
    P11FW.Log("Прибытие: " .. ply:Nick() .. " поставил зону для " .. facId)
end

function POLUS11.ArrivalClear(ply, facId)
    POLUS11.Arrivals[facId] = nil
    ArSave()
    P11FW.Notify(ply, "Зона прибытия фракции «" .. facId .. "» убрана.")
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

-- ============ СПАВН: ОЧЕРЕДЬ ТОЧЕК ============
-- приоритет: зона прибытия МОЕЙ фракции > общий спавн-поинт > карта

hook.Add("PlayerSpawn", "P11.ArrivalSpawn", function(ply)
    timer.Simple(0.09, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local job = P11FW.GetJob and P11FW.GetJob(ply)
        local fac = job and (job.faction or job.category)
        local a = fac and POLUS11.Arrivals[fac]
        if not a then return end
        ply:SetPos(a.pos)
        ply:SetEyeAngles(a.ang)
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
    elseif args[1] and args[1] ~= "" then
        POLUS11.ArrivalSet(ply, args[1]) -- p11_arrival rkka
    else
        local out = "p11_arrival <facId> — поставить зону прибытия здесь • p11_arrival truck/untruck — грузовик"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, out) else print(out) end
    end
end)

print("[POLUS-11] зона прибытия/транспорт загружен (LVS: опционально)")
