-- ============================================================
--  ПОЛЮС-11 — КОНТРАКТНИК «НАРЯДНИК» (server) v4.19.4
--  Заявка владельца: «добавь НПС-контрактника с контрактами,
--  которые меняются с обновлением и каждый час на сервере; за
--  контракты много денег, но контракты сложные».
--
--  КАК ЖИВЁТ:
--   • НПС polus_p11_contractnpc (интендант) ставится из 📍 меню;
--   • v4.19.5 «ДОПРОС»: контракт «ОБХОД ПЕРИМЕТРА» вырезан вместе
--     с системой патруля (заявка владельца), пул теперь 7 шаблонов;
--   • ротация: 3 контракта из пула на час; ПЕРЕРОЛЛ и каждый
--     час (таймер), И на каждом старте карты («с обновлением»);
--   • контракт берётся у интенданта (E), прогресс идёт по
--     штатным событиям станции (TaskEvent: крафт/кровь/
--     лут/лечение/урон по Нечто) и по сдаче товара (лом/тушка);
--   • цель достигнута — деньги платятся САМИ, вести обратно
--     к стойке не надо; сдаваемый товар списывается из 🎒;
--   • прогресс+ротация переживают рестарт (polus11/contracts.json).
-- ============================================================

util.AddNetworkString("P11_ContractSync")
util.AddNetworkString("P11_ContractOpen")
util.AddNetworkString("P11_ContractAct")

local FILE  = "polus11/contracts.json"
local ROT_SEC   = 3600    -- жизнь одного набора нарядов
local ROT_COUNT = 3       -- контрактов в наборе

-- ============ ПУЛ КОНТРАКТОВ (сложные — деньги большие) ============
-- ev     = ключ штатного события станции (TaskEvent), add копит прогресс
-- item   = сдача товара из инвентаря (прогресс = сколько при тебе)
POLUS11.ContractPool = {
    lom     = { name = "ЖЕЛЕЗНЫЙ НАРЯД",          desc = "Сдай 8 металлолома снабжению (🎒 лом — ящики/груды по станции)", item = "scrap", need = 8,   pay = 2600 },
    prod    = { name = "ПРОДОВОЛЬСТВЕННЫЙ НАЛОГ", desc = "Сдай 6 банок тушёнки для блока зимовки",                         item = "cons",  need = 6,   pay = 2200 },
    verstak = { name = "РУКИ ИЗ ПЛЕЧ",            desc = "Собери 2 изделия на кустарном верстаке",                         ev = "craft_do",     need = 2, pay = 3500 },
    krovi   = { name = "КРОВЬ ДЛЯ НАУКИ",         desc = "Проведи 1 анализ крови на столе «КРОВЬ-2» (вердикт любой)",      ev = "blood_test",   need = 1, pay = 4000 },
    ohota   = { name = "ОХОТА НА ТВАРЬ",          desc = "Нанеси 600 урона активному Нечто. Огонь — твой аргумент",        ev = "damage_thing", need = 600, pay = 5000 },
    taynik  = { name = "ЛОМ ИЩЕТ ХОЗЯИНА",        desc = "Обыщи 6 ящиков/бочек/тайников по станции",                       ev = "loot_find",    need = 6, pay = 2800 },
    polevik = { name = "ПОЛЕВОЙ ГОСПИТАЛЬ",       desc = "Вылечи бойцов 3 раза (медкейс/шприц, ЛКМ по раненым)",           ev = "heal_player",  need = 3, pay = 3200 },
}

-- ротация: ids = текущие 3, endsAt = unix конца часа
-- players: [sid] = { [tplId] = { p = прогресс, done = bool } }
local ROT = { ids = {}, endsAt = 0, players = {} }

local function ContrSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(ROT, true) or "{}")
end

-- ============ СИНХРОНИЗАЦИЯ КЛИЕНТУ ============

local function PlayerState(ply)
    local sid = ply:SteamID()
    ROT.players[sid] = ROT.players[sid] or {}
    -- мусор прошлых ротаций выкинуть: оставляем только живые шаблоны
    for tplId in pairs(ROT.players[sid]) do
        local live = false
        for _, id in ipairs(ROT.ids) do
            if id == tplId then live = true break end
        end
        if not live then ROT.players[sid][tplId] = nil end
    end
    return ROT.players[sid]
end

function POLUS11.ContractSync(ply)
    if not IsValid(ply) then return end
    local st = PlayerState(ply)
    local defs = {}
    for _, id in ipairs(ROT.ids) do
        local t = POLUS11.ContractPool[id]
        if t then
            local mine = st[id]
            defs[#defs + 1] = {
                id = id, name = t.name, desc = t.desc, need = t.need, pay = t.pay,
                p    = mine and mine.p or 0,
                got  = mine and true or false,          -- взят
                done = mine and mine.done and true or false,
            }
        end
    end
    net.Start("P11_ContractSync")
        net.WriteString(util.TableToJSON({ list = defs, endsAt = ROT.endsAt }) or "{}")
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "P11.ContractJoin", function(ply)
    timer.Simple(7, function()
        if IsValid(ply) then POLUS11.ContractSync(ply) end
    end)
end)

-- ============ ОГЛАСКА ============

local function ContractAnnounce(txt)
    -- та же труба, что у «РЕПРОДУКТОРА» — плашка наверху у всех
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString("НАРЯДНИК")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[НАРЯД] " .. txt)
end

-- ============ РОТАЦИЯ ============

function POLUS11.ContractReroll(why)
    local keys = {}
    for id in pairs(POLUS11.ContractPool) do keys[#keys + 1] = id end
    local ids = {}
    while #ids < ROT_COUNT and #keys > 0 do
        local i = math.random(#keys)
        ids[#ids + 1] = table.remove(keys, i)
    end
    ROT.ids = ids
    ROT.endsAt = os.time() + ROT_SEC
    ROT.players = {} -- прогресс прошлого набора сгорает вместе с ним
    ContrSave()

    local names = {}
    for _, id in ipairs(ids) do
        names[#names + 1] = POLUS11.ContractPool[id].name
    end
    ContractAnnounce("СМЕНА НАРЯДОВ" .. (why and (" (" .. why .. ")") or "") .. ": " ..
        table.concat(names, " · ") .. ". Контракты — у интенданта, оплата большая.")
    POLUS11.Log("НАРЯДЫ: новый набор (" .. tostring(why or "час") .. "): " .. table.concat(ids, ", "))
    for _, p in ipairs(player.GetAll()) do POLUS11.ContractSync(p) end
end

hook.Add("InitPostEntity", "P11.ContractBoot", function()
    math.randomseed(os.time() + os.clock() * 1000)
    timer.Simple(3, function()
        -- «меняются С ОБНОВЛЕНИЕМ»: старт карты = всегда новый набор
        POLUS11.ContractReroll("обновление станции")
        -- «и каждый час на сервере»
        timer.Create("P11.ContractHour", ROT_SEC, 0, function()
            POLUS11.ContractReroll("час смены")
        end)
    end)
end)

-- консоль Главы: p11_contractroll — перекрутить набор досрочно
concommand.Add("p11_contractroll", function(ply)
    if IsValid(ply) then return end -- в консоли сервера; у игроков стоит замок 16
    POLUS11.ContractReroll("ручной перекрут")
    print("[НАРЯДЫ] набор перекручен вручную")
end)

-- ============ ЗАВЕРШЕНИЕ ============

local function ContractComplete(ply, tplId)
    local st = PlayerState(ply)
    local mine = st[tplId]
    local t = POLUS11.ContractPool[tplId]
    if not mine or mine.done or not t then return end

    -- сдачный контракт: списать товар при достижении цели
    if t.item then
        local data = POLUS11.InvOf and POLUS11.InvOf(ply)
        if not data then return end
        local have = tonumber(data.items[t.item]) or 0
        if have < t.need then return end
        data.items[t.item] = have - t.need
        if data.items[t.item] <= 0 then data.items[t.item] = nil end
        if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
        if POLUS11.InvSync then POLUS11.InvSync(ply) end
    end

    mine.done = true
    mine.p = t.need
    ContrSave()

    if POLUS11.AddMoney then
        POLUS11.AddMoney(ply, t.pay, "контракт: " .. t.name)
    else
        POLUS11.Notify(ply, "Казна молчит — деньги начислит Глава вручную!")
    end
    ply:EmitSound("buttons/button15.wav", 75, 100)
    ply:EmitSound("ambient/alarms/warningbell1.wav", 55, 130)
    ContractAnnounce(ply:Nick() .. " выполнил контракт «" .. t.name .. "» (+" .. t.pay .. "₽)")
    POLUS11.Log("НАРЯД ЗАКРЫТ: " .. ply:Nick() .. " «" .. t.name .. "» +" .. t.pay .. "₽")
    POLUS11.ContractSync(ply)
end

-- ============ СОБЫТИЯ СТАНЦИИ (одно звено в цепи TaskEvent) ============

function POLUS11.ContractEvent(ply, key, add)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    add = tonumber(add) or 1
    if add <= 0 then return end
    local st = PlayerState(ply)
    local changed = false
    for _, id in ipairs(ROT.ids) do
        local t = POLUS11.ContractPool[id]
        local mine = st[id]
        if t and t.ev == key and mine and not mine.done then
            mine.p = math.min((tonumber(mine.p) or 0) + add, t.need)
            changed = true
            POLUS11.Notify(ply, "«" .. t.name .. "»: " .. mine.p .. "/" .. t.need ..
                (mine.p >= t.need and " — НАРЯД ЗАКРЫТ!" or ""))
            if mine.p >= t.need then
                ContractComplete(ply, id)
            end
        end
    end
    if changed then
        ContrSave()
        POLUS11.ContractSync(ply)
    end
end

-- обёртка-звено поверх уже собранной цепи (задачи смены → наука →
-- итоги смены → …): наш модуль грузится последним, звено ставим здесь
do
    local base = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        if base then base(ply, key, add) end
        POLUS11.ContractEvent(ply, key, add)
    end
end

-- сдачные контракты («лом», «тушка»): прогресс = товар в 🎒.
-- проверка по таймеру — надёжнее, чем вешаться на все точки смены инвентаря
timer.Create("P11.ContractDeliver", 2, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            local st = PlayerState(ply)
            for _, id in ipairs(ROT.ids) do
                local t = POLUS11.ContractPool[id]
                local mine = st[id]
                if t and t.item and mine and not mine.done and POLUS11.InvOf then
                    local have = tonumber(POLUS11.InvOf(ply).items[t.item]) or 0
                    if have > (tonumber(mine.p) or 0) then
                        mine.p = math.min(have, t.need)
                    end
                    if mine.p >= t.need then
                        ContractComplete(ply, id)
                    end
                end
            end
        end
    end
end)

-- ============ НПС: ОКНО ============

function POLUS11.ContractsOpenUI(ply, ent)
    if not IsValid(ply) then return end
    ply.P11_ContractEnt = ent
    POLUS11.ContractSync(ply)
    net.Start("P11_ContractOpen")
    net.Send(ply)
    ply:EmitSound("buttons/button9.wav", 50, 110)
end

net.Receive("P11_ContractAct", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_ContractNext = ply.P11_ContractNext or 0
    if CurTime() < ply.P11_ContractNext then return end
    ply.P11_ContractNext = CurTime() + 0.4

    local act = net.ReadUInt(4)
    if act == 9 then
        POLUS11.ContractSync(ply)
        return
    end
    if act ~= 1 then return end

    local tplId = string.sub(net.ReadString() or "", 1, 16)
    -- взять можно только стоя у интенданта (честная явка)
    local ent = ply.P11_ContractEnt
    if not IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 300 * 300 then
        POLUS11.Notify(ply, "Наряд выдаёт интендант лично — подойди к стойке «НАРЯДНИК».")
        return
    end
    local live = false
    for _, id in ipairs(ROT.ids) do
        if id == tplId then live = true break end
    end
    local t = live and POLUS11.ContractPool[tplId]
    if not t then return end

    local st = PlayerState(ply)
    if st[tplId] then
        POLUS11.Notify(ply, "Этот наряд уже у тебя: " ..
            (st[tplId].done and "ЗАКРЫТ — жди новый набор." or (st[tplId].p .. "/" .. t.need)))
        return
    end

    st[tplId] = { p = 0, at = os.time() }
    ContrSave()
    POLUS11.Notify(ply, "НАРЯД ПРИНЯТ: «" .. t.name .. "» — " .. t.desc .. ". Оплата " .. t.pay .. "₽ по закрытии.")
    ply:EmitSound("buttons/button15.wav", 60, 105)
    POLUS11.Log("НАРЯД ВЗЯТ: " .. ply:Nick() .. " «" .. t.name .. "»")
    POLUS11.ContractSync(ply)
end)

print("[POLUS-11] контракты «НАРЯДНИК» v4.19.4: 8 сложных шаблонов, набор из 3 на час, оплата 2200–5000₽, НПС polus_p11_contractnpc")
