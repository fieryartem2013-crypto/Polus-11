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

-- ============ НАРЯД СУТОК (v4.20.0 «СЛЕД», дэйли-прокачка) ============
-- 1 суточный шаблон × 3 сложности; стрик 5 дней подряд = ЗОЛОТОЙ (×2).
local DAY_TIERS = {
    [1] = { tag = "Л", name = "ЛЁГКИЙ",      kmul = 1, pmul = 1 },
    [2] = { tag = "Т", name = "ТЯЖЁЛЫЙ",     kmul = 2, pmul = 2.2 },
    [3] = { tag = "С", name = "СМЕРТЕЛЬНЫЙ", kmul = 3, pmul = 3.5 },
}
POLUS11.ContractTiers = DAY_TIERS

POLUS11.DailyPool = {
    zharkiy  = { name = "ЖАРКИЙ ДЕНЬ",       desc = "Нанеси урон активному Нечто — оно должно гореть ежесуточно", ev = "damage_thing", baseNeed = 1000, basePay = 4800 },
    stakan   = { name = "СТАКАН КРОВИ",      desc = "Проведи анализы крови на столе «КРОВЬ-2» (вердикт любой)",       ev = "blood_test",   baseNeed = 3,    basePay = 4000 },
    kuznitsa = { name = "КУЗНИЦА СУТОК",     desc = "Собери изделия на кустарном верстаке",                          ev = "craft_do",     baseNeed = 4,    basePay = 4200 },
    obysk    = { name = "БОЛЬШОЙ ОБЫСК",     desc = "Обыщи ящики/бочки/тайники по станции",                          ev = "loot_find",    baseNeed = 12,   basePay = 3600 },
    gospital = { name = "САНИТАРНЫЕ СУТКИ",  desc = "Вылечи бойцов (медкейс/шприц, ЛКМ по раненым)",                 ev = "heal_player",  baseNeed = 5,    basePay = 4200 },
    ogolov   = { name = "ЖЕЛЕЗО ДЛЯ ФРОНТА", desc = "Сдай металлолом снабжению (🎒 лом списывается сам)",            item = "scrap",      baseNeed = 10,   basePay = 4000 },
    paekd    = { name = "ПРОДНАБОР",         desc = "Сдай банки тушёнки для блока зимовки (🎒 списывается сам)",     item = "cons",       baseNeed = 9,    basePay = 3800 },
}

-- DAILY = { day = "YYYY-MM-DD", tpl = id, players = { [sid] = { tier, p, done, streak, lastDone } } }
local DAILY = { day = "", tpl = "", players = {} }

local function TodayKey() return os.date("%Y-%m-%d") end
local function DailyT() return POLUS11.DailyPool[DAILY.tpl] end
local function DailyNeed(tier)
    local t = DailyT()
    if not t then return 1 end
    local tr = DAY_TIERS[math.floor(tonumber(tier) or 1)] or DAY_TIERS[1]
    return math.max(1, math.floor((tonumber(t.baseNeed) or 1) * tr.kmul))
end
local function DailyPay(tier)
    local t = DailyT()
    if not t then return 0 end
    local tr = DAY_TIERS[math.floor(tonumber(tier) or 1)] or DAY_TIERS[1]
    return math.floor((tonumber(t.basePay) or 0) * tr.pmul)
end
local function DailyState(ply)
    local sid = ply:SteamID()
    DAILY.players[sid] = DAILY.players[sid] or {}
    return DAILY.players[sid]
end

local function ContrSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON({ rot = ROT, daily = DAILY }, true) or "{}")
end

-- v4.20.0 «СЛЕД»: раньше сейв вообще не читался (дэйли исправила
-- это заодно); старый формат (голый ROT) тоже распознаём.
local function ContrLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if not ok or not istable(tbl) then return end
    if istable(tbl.rot) then
        ROT.ids     = istable(tbl.rot.ids) and tbl.rot.ids or {}
        ROT.endsAt  = tonumber(tbl.rot.endsAt) or 0
        ROT.players = istable(tbl.rot.players) and tbl.rot.players or {}
        if istable(tbl.daily) then
            DAILY.day     = tostring(tbl.daily.day or "")
            DAILY.tpl     = tostring(tbl.daily.tpl or "")
            DAILY.players = istable(tbl.daily.players) and tbl.daily.players or {}
        end
    elseif istable(tbl.ids) then -- legacy: файл держал сам ROT
        ROT.ids     = tbl.ids
        ROT.endsAt  = tonumber(tbl.endsAt) or 0
        ROT.players = istable(tbl.players) and tbl.players or {}
    end
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
    -- v4.20.0 «СЛЕД»: наряд суток едет в том же пакете
    local dPayload = false
    local dt = DailyT()
    if dt then
        local ds = DAILY.players[ply:SteamID()]
        local streak = ds and (tonumber(ds.streak) or 0) or 0
        dPayload = {
            name  = dt.name, desc = dt.desc,
            needs = { DailyNeed(1), DailyNeed(2), DailyNeed(3) },
            pays  = { DailyPay(1), DailyPay(2), DailyPay(3) },
            got   = (ds and ds.tier ~= nil and not ds.done) and true or false,
            tier  = ds and (tonumber(ds.tier) or 0) or 0,
            p     = ds and math.floor(tonumber(ds.p) or 0) or 0,
            need  = (ds and ds.tier) and DailyNeed(ds.tier) or 0,
            done  = ds and ds.done and true or false,
            streak   = streak,
            goldNext = ((streak + 1) % 5 == 0),
        }
    end
    net.Start("P11_ContractSync")
        net.WriteString(util.TableToJSON({ list = defs, endsAt = ROT.endsAt, daily = dPayload }) or "{}")
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
        ContrLoad() -- v4.20.0: сутки/стрики переживают рестарт (часовой набор всё равно перекручиваем)
        -- «меняются С ОБНОВЛЕНИЕМ»: старт карты = всегда новый набор
        POLUS11.ContractReroll("обновление станции")
        -- «наряд суток»: новый день — новый шаблон; тот же день — продолжаем
        if DAILY.day ~= TodayKey() or not POLUS11.DailyPool[DAILY.tpl] then
            POLUS11.DailyReroll("начало суток")
        else
            local dt = POLUS11.DailyPool[DAILY.tpl]
            ContractAnnounce("НАРЯД СУТОК: «" .. dt.name .. "» действует до полуночи. Три сложности — у интенданта.")
        end
        -- «и каждый час на сервере»
        timer.Create("P11.ContractHour", ROT_SEC, 0, function()
            POLUS11.ContractReroll("час смены")
        end)
        timer.Create("P11.DailyDay", 30, 0, function()
            if DAILY.day ~= TodayKey() then POLUS11.DailyReroll("новые сутки") end
        end)
    end)
end)

-- консоль Главы: p11_contractroll — перекрутить набор досрочно
concommand.Add("p11_contractroll", function(ply)
    if IsValid(ply) then return end -- в консоли сервера; у игроков стоит замок 16
    POLUS11.ContractReroll("ручной перекрут")
    print("[НАРЯДЫ] набор перекручен вручную")
end)

-- ============ РОТАЦИЯ И ЖИЗНЬ СУТОК (v4.20.0 «СЛЕД») ============

function POLUS11.DailyReroll(why)
    local keys = {}
    for id in pairs(POLUS11.DailyPool) do keys[#keys + 1] = id end
    local tpl = keys[math.random(#keys)]
    DAILY.day = TodayKey()
    DAILY.tpl = tpl
    for _, st in pairs(DAILY.players) do
        st.tier, st.p, st.done = nil, 0, false -- стрик/lastDone живут через дни
    end
    ContrSave()
    local t = POLUS11.DailyPool[tpl]
    ContractAnnounce("НАРЯД СУТОК" .. (why and (" (" .. why .. ")") or "") .. ": «" .. t.name ..
        "». Сложности Л/Т/С, стрик 5 дней = ЗОЛОТОЙ (×2). У интенданта, до полуночи.")
    POLUS11.Log("НАРЯД СУТОК: " .. DAILY.day .. " — «" .. t.name .. "»")
    for _, p in ipairs(player.GetAll()) do POLUS11.ContractSync(p) end
end

local function DailyConsumeItem(ply, t, need)
    if not t.item then return true end
    local data = POLUS11.InvOf and POLUS11.InvOf(ply)
    if not data then return false end
    local have = tonumber(data.items[t.item]) or 0
    if have < need then return false end
    data.items[t.item] = have - need
    if data.items[t.item] <= 0 then data.items[t.item] = nil end
    if POLUS11.InvSaveNow then POLUS11.InvSaveNow() end
    if POLUS11.InvSync then POLUS11.InvSync(ply) end
    return true
end

local function DailyComplete(ply)
    local t = DailyT()
    if not t then return end
    local ds = DailyState(ply)
    local tier = tonumber(ds.tier) or 1
    if ds.done then return end
    local need = DailyNeed(tier)
    if not DailyConsumeItem(ply, t, need) then return end

    -- стрик: дни подряд без пропуска
    local yest = os.date("%Y-%m-%d", os.time() - 86400)
    local newStreak = (ds.lastDone == yest) and ((tonumber(ds.streak) or 0) + 1) or 1
    local gold = (newStreak % 5 == 0)
    local pay = DailyPay(tier)
    if gold then pay = pay * 2 end
    local mult = (POLUS11.RaceBuffMult and POLUS11.RaceBuffMult(ply)) or 1
    if mult > 1 then pay = math.floor(pay * mult) end

    ds.done = true
    ds.p = need
    ds.streak = newStreak
    ds.lastDone = TodayKey()
    ContrSave()

    if POLUS11.AddMoney then POLUS11.AddMoney(ply, pay, "наряд суток: " .. t.name) end
    ply:EmitSound("buttons/button15.wav", 75, 100)
    ply:EmitSound("ambient/alarms/warningbell1.wav", 55, 130)
    local tr = DAY_TIERS[tier] or DAY_TIERS[1]
    local extra = (gold and " · ЗОЛОТОЙ ×2" or "") .. (mult > 1 and " · ЛЕДОКОЛ +20%" or "")
    ContractAnnounce(ply:Nick() .. " закрыл НАРЯД СУТОК «" .. t.name .. "» [" .. tr.name .. "] +" ..
        pay .. "₽ (стрик " .. newStreak .. extra .. ")")
    POLUS11.Log("НАРЯД СУТОК ЗАКРЫТ: " .. ply:Nick() .. " «" .. t.name .. "» [" .. tr.tag .. "] +" ..
        pay .. "₽, стрик " .. newStreak)
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "contract_done") end -- ЛЕДОКОЛ/онбординг
    POLUS11.ContractSync(ply)
end

function POLUS11.DailyTake(ply, tier)
    local t = DailyT()
    if not t then return end
    tier = math.Clamp(math.floor(tonumber(tier) or 1), 1, 3)
    local ds = DailyState(ply)
    if ds.done then
        POLUS11.Notify(ply, "Наряд суток уже ЗАКРЫТ тобой сегодня. Новый — после полуночи.")
        return
    end
    if ds.tier then
        POLUS11.Notify(ply, "Наряд суток уже у тебя: «" .. t.name .. "» — " ..
            math.floor(tonumber(ds.p) or 0) .. "/" .. DailyNeed(ds.tier) .. ".")
        return
    end
    ds.tier = tier
    ds.p = 0
    ContrSave()
    local tr = DAY_TIERS[tier]
    local streak = tonumber(ds.streak) or 0
    POLUS11.Notify(ply, "НАРЯД СУТОК ПРИНЯТ: «" .. t.name .. "» [" .. tr.name .. "] — цель " ..
        DailyNeed(tier) .. ", оплата " .. DailyPay(tier) .. "₽" ..
        (((streak + 1) % 5 == 0) and " · ЗАКРОЕШЬ — ЗОЛОТОЙ ×2!" or "") ..
        ". До полуночи успеешь.")
    ply:EmitSound("buttons/button15.wav", 60, 105)
    POLUS11.Log("НАРЯД СУТОК ВЗЯТ: " .. ply:Nick() .. " «" .. t.name .. "» [" .. tr.tag .. "]")
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "contract_take") end
    POLUS11.ContractSync(ply)
end

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

    -- v4.20.0 «СЛЕД»: бафф ЛЕДОКОЛА (+20% фракции-победителю недели)
    local pay = tonumber(t.pay) or 0
    local mult = (POLUS11.RaceBuffMult and POLUS11.RaceBuffMult(ply)) or 1
    if mult > 1 then pay = math.floor(pay * mult) end
    if POLUS11.AddMoney then
        POLUS11.AddMoney(ply, pay, "контракт: " .. t.name .. (mult > 1 and " [ЛЕДОКОЛ +20%]" or ""))
    else
        POLUS11.Notify(ply, "Казна молчит — деньги начислит Глава вручную!")
    end
    ply:EmitSound("buttons/button15.wav", 75, 100)
    ply:EmitSound("ambient/alarms/warningbell1.wav", 55, 130)
    ContractAnnounce(ply:Nick() .. " выполнил контракт «" .. t.name .. "» (+" .. pay .. "₽" ..
        (mult > 1 and ", ЛЕДОКОЛ ×1.2" or "") .. ")")
    POLUS11.Log("НАРЯД ЗАКРЫТ: " .. ply:Nick() .. " «" .. t.name .. "» +" .. pay .. "₽")
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "contract_done") end -- v4.20.0: ЛЕДОКОЛ/онбординг
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

    -- v4.20.0 «СЛЕД»: наряд суток движется тем же событием
    local dt = DailyT()
    if dt and dt.ev == key then
        local ds = DailyState(ply)
        if ds.tier and not ds.done then
            local need = DailyNeed(ds.tier)
            ds.p = math.min((tonumber(ds.p) or 0) + add, need)
            changed = true
            if ds.p >= need then
                DailyComplete(ply)
            else
                POLUS11.Notify(ply, "Наряд суток «" .. dt.name .. "»: " ..
                    math.floor(ds.p) .. "/" .. need)
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

            -- v4.20.0 «СЛЕД»: сдачный наряд суток — тоже из 🎒
            local dt = DailyT()
            if dt and dt.item then
                local ds = DAILY.players[ply:SteamID()]
                if ds and ds.tier and not ds.done and POLUS11.InvOf then
                    local need = DailyNeed(ds.tier)
                    local have = tonumber(POLUS11.InvOf(ply).items[dt.item]) or 0
                    if have > (tonumber(ds.p) or 0) then
                        ds.p = math.min(have, need)
                    end
                    if ds.p >= need then
                        DailyComplete(ply)
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
    if act == 2 then -- v4.20.0 «СЛЕД»: взять НАРЯД СУТОК выбранной сложности
        local tier = net.ReadUInt(2)
        local ent = ply.P11_ContractEnt
        if not IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 300 * 300 then
            POLUS11.Notify(ply, "Наряд суток выдаёт интендант лично — подойди к стойке «НАРЯДНИК».")
            return
        end
        POLUS11.DailyTake(ply, tier)
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
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "contract_take") end -- v4.20.0: шаг «ПЕРВЫЙ ДЕНЬ»
    POLUS11.Notify(ply, "НАРЯД ПРИНЯТ: «" .. t.name .. "» — " .. t.desc .. ". Оплата " .. t.pay .. "₽ по закрытии.")
    ply:EmitSound("buttons/button15.wav", 60, 105)
    POLUS11.Log("НАРЯД ВЗЯТ: " .. ply:Nick() .. " «" .. t.name .. "»")
    POLUS11.ContractSync(ply)
end)

print("[POLUS-11] контракты «НАРЯДНИК» v4.20.0 «СЛЕД»: 7 часовых + НАРЯД СУТОК (Л/Т/С, стрик 5 дней = ЗОЛОТОЙ ×2), бафф ЛЕДОКОЛА +20%, сейв читается")
