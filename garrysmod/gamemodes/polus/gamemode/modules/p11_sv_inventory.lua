-- ============================================================
--  ПОЛЮС-11 — ИНВЕНТАРЬ + МАГАЗИН + ЛИЧНЫЙ СЕЙФ (server) v4.0 → v4.6.9
--  v4.6.9 «ларёк не работает»: у части клиентов движковый Use по
--  anim-торговцу глохнет. Теперь ТРИ пути в ларёк (E / кнопка C-меню /
--  чат /ларёк) + самодиагностика p11_shopdiag + экспорт InvSaveNow.
--  • Каталог товаров (оружие EFT/DOI + станционный скарб);
--  • покупка у НПС-ларька → в ИНВЕНТАРЬ (копия переживает смерть/
--    рестарт), «Использовать» → оружие в руки, копия тратится;
--  • ЛИЧНЫЙ СЕЙФ (энтити полусняр): перекладка инвентарь↔сейф;
--  • админ-расстановка объектов через меню «📍 Расставить»:
--    генератор / ларёк / сейф / терминал — сохраняются на карту.
--  Всё в data/polus11/inventory.json (кошелёк — в p11_sv_economy).
-- ============================================================

util.AddNetworkString("P11_InvSync")
util.AddNetworkString("P11_InvAct")
util.AddNetworkString("P11_ShopOpen")
util.AddNetworkString("P11_StorageOpen")
util.AddNetworkString("P11_PlaceEnt")
util.AddNetworkString("P11_ShopTry") -- v4.6.9: запасной путь к ларьку

local FILE = "polus11/inventory.json"

-- ============ КАТАЛОГ ТОВАРОВ ============
-- id -> { name, price, class, desc }; class = класс свepа (kind=оружие)
-- Оружие EFT/DOI требует установленные паки ARC9 (как профы РККА).

POLUS11.Items = {
    -- ---- оружие из EFT/DOI (подбор владельца) ----
    aks74u   = { name = "АКС-74У",          price = 6000, class = "arc9_eft_aks74u",        desc = "Короткий караулер. Штат ствол постовых РККА. (цена v4.9.1)" },
    aks74    = { name = "АК-74",            price = 7500, class = "arc9_eft_aks74",         desc = "Полноразмерный армейский автомат. (цена v4.9.1)" },
    ppsh41   = { name = "ППШ-41",           price = 9500, class = "arc9_eft_ppsh41",        desc = "«Папаша» штурмовика, косит в упор. (цена v4.9.1)" },
    mosin    = { name = "Винтовка Мосина",  price = 8000, class = "arc9_eft_mosin_infantry",desc = "Разведывательная трёхлинейка, бьёт далеко. (цена v4.9.1)" },
    mr43     = { name = "МР-43 (двухств.)", price = 5000, class = "arc9_eft_mr43",          desc = "Двустволка: две причины не подходить. (цена v4.9.1)" },
    k98      = { name = "Mauser Kar98k",    price = 7500, class = "arc9_doi_k98",           desc = "Офицерский карабин особого отделa. (цена v4.9.1)" },
    rpd      = { name = "РПД (ручной пулемёт)", price = 12500, class = "arc9_eft_rpd", desc = "v4.14.3 «ЗАРЯД»: настоящий ARC9 EFT РПД (заявка владельца) — дисковый ручной пулемёт. Пока РПД говорит — Нечто не подходит." },
    -- ---- станционный скарб ----
    radio    = { name = "Рация",            price = 1800, class = "weapon_polus11_radio",   desc = "Эфир фракций: /r — текст, R — канал. (цена v4.9.1)" },
    ration   = { name = "Горячий паёк",     price = 400,  class = "weapon_polus11_ration",  desc = "Греет изнутри (+тепло, +немного ХП). (цена v4.9.1)" },
    syringe  = { name = "Полевой шприц",    price = 1200, class = "weapon_polus11_syringe", desc = "Забор крови (наука) / обработка ран (медики, ПКМ). (цена v4.9.1)" },
    medkit   = { name = "Полевой медкейс",  price = 1600, class = "weapon_polus11_medkit",  desc = "v4.9.1 «ИГЛА»: ванильный надёжный — ЛКМ +12 ХП, ПКМ +8. На ранах и обморожениях." },
    ukol     = { name = "Инъектор «УКОЛ-С»", price = 950, class = "polus11_ukol", ent = true, desc = "v4.9.1 «ИГЛА»: энтити-инъектор, 2 заряда — E: мини-игра лечения (+8/+25/+40 ХП по точности)." },
    chemlight= { name = "Химсвет (пачка)",  price = 250,  class = "weapon_polus11_chemlight",desc = "Кидай и размечай путь в облаке спор. (цена v4.9.1)" },
    scalpel  = { name = "Скальпель",        price = 900,  class = "weapon_polus11_scalpel", desc = "Хирургический. И не только хирургический. (цена v4.9.1)" },
    ampoule  = { name = "Ампула «Анальгин-С»", price = 450, class = "p11_ampoule",          desc = "Расходка медика для процедурной инъекции (+25 ХП). В руки не даётся. (цена v4.9.1)" },
    -- v4.19.4 «ПОЧЁТ»: лекарства РАССУДКА — купить может только медслужба (медсёстры/полевой медик/военврач), употребить — любой
    coffee   = { name = "Чашка горячего кофе",  price = 150, sanity = 30, medjob = true, desc = "Бодрит и греет: +30 рассудка. Продажа — только медслужбе. (v4.19.4)" },
    pills    = { name = "Таблетки «Аминазин-С»", price = 520, sanity = 70, medjob = true, desc = "Курс психиатра у полюса: +70 рассудка. Продажа — только медслужбе. (v4.19.4)" },
    -- ---- ПАТРОНЫ всех видов (v4.9.3 «ГРОШ», заявка «в дарке можно покупать патроны») ----
    ammo_pistol = { name = "Патроны пистолетные (x60)", price = 350, ammo = { type = "pistol", n = 60 }, desc = "К ПМ, TT-33 и любой пистолетной мелочи станции." },
    ammo_smg    = { name = "Патроны пистолет-пулемётные (x90)", price = 450, ammo = { type = "smg1", n = 90 }, desc = "К АКС-74У, ППШ и прочим быстрым стволам." },
    ammo_ar     = { name = "Патроны винтовочно-автоматные (x60)", price = 550, ammo = { type = "ar2", n = 60 }, desc = "К АК-74, РПД и винтовочным аргументам." },
    ammo_buck   = { name = "Картечь 12 калибра (x16)", price = 400, ammo = { type = "buckshot", n = 16 }, desc = "Двустволка МР-43 и помпы — короткий разговор." },
    ammo_dyn    = { name = "Боекомплект к оружию в руках", price = 600, dyn = true, desc = "УМНЫЙ: два магазина к ТОМУ стволу, что сейчас в руках — любой пак/ARC9, всегда в точку." },
    flamer   = { name = "Кустарный огнемёт", price = 11500, class = "weapon_polus11_flamethrower", desc = "Единственный надёжный аргумент против Нечто. (цена v4.9.1)" },
    -- ---- МАТЕРИАЛЫ МАСТЕРСКОЙ (v4.10.0 «ГАРАЖ»): крафт — !крафт / 🎒 → 🛠 ----
    scrap  = { name = "Металлолом",          price = 120, mat = true, desc = "Гнутый железный остов. Основа всех самоделок." },
    cloth  = { name = "Брезент",             price = 90,  mat = true, desc = "Плотная ткань: бинты, фитили, рукавицы." },
    spirit = { name = "Спирт технический",   price = 130, mat = true, desc = "Стерильность и горючее в одной бутыли." },
    fuel   = { name = "Канистра солярки",    price = 180, mat = true, desc = "Полярная валюта №2 после патронов." },
    parts  = { name = "Запчасти",            price = 220, mat = true, desc = "Шестерни, пружины, шприц-тюбики. Мелко — ценно." },
    cons   = { name = "Тушёнка (банка)",     price = 100, mat = true, desc = "Вторая половинка пайка. Первая — ты сам." },
}

-- ============ ДАННЫЕ ИГРОКОВ ============
-- POLUS11.Inv = { [steamid] = { items = {id=count}, storage = {id=count} } }
POLUS11.Inv = POLUS11.Inv or {}

local function LoadInv()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Inv = tbl end
end

local savePending = false
local function SaveInv()
    savePending = false
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Inv, true))
end
local function DebouncedSave()
    if savePending then return end
    savePending = true
    timer.Simple(8, SaveInv)
end

hook.Add("InitPostEntity", "P11.InvLoad", function()
    timer.Simple(1.4, LoadInv)
end)
hook.Add("PlayerDisconnected", "P11.InvBye", function() SaveInv() end)

local function InvOf(ply)
    local sid = ply:SteamID()
    POLUS11.Inv[sid] = POLUS11.Inv[sid] or { items = {}, storage = {} }
    POLUS11.Inv[sid].items = POLUS11.Inv[sid].items or {}
    POLUS11.Inv[sid].storage = POLUS11.Inv[sid].storage or {}
    return POLUS11.Inv[sid]
end

-- ============ СИНХРОНИЗАЦИЯ КЛИЕНТУ ============

function POLUS11.InvSync(ply)
    if not IsValid(ply) then return end
    -- v4.14.5 «ТИШИНА»: синк инвентаря заодно чинит клиентский кошелёк
    ply:SetNWInt("P11_Money", POLUS11.GetMoney(ply))
    local data = InvOf(ply)
    -- каталог шлём тоже (цены могут правиться без рестарта)
    local cat = {}
    for id, it in pairs(POLUS11.Items) do
        cat[id] = { name = it.name, price = it.price, desc = it.desc, class = it.class, medjob = it.medjob and true or nil }
        -- v4.2: скидка дня (актуальная цена + маркер)
        if POLUS11.SaleOfDay and POLUS11.SaleOfDay.id == id then
            cat[id].price = POLUS11.SalePrice and POLUS11.SalePrice(id) or it.price
            cat[id].sale  = true
        end
    end
    net.Start("P11_InvSync")
        net.WriteString(util.TableToJSON({
            items   = data.items,
            storage = data.storage,
            money   = POLUS11.GetMoney(ply),
            catalog = cat,
        }) or "{}")
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "P11.InvJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then POLUS11.InvSync(ply) end
    end)
end)

-- ============ ГРУДНЫЕ ДЕЙСТВИЯ ============

POLUS11.InvOf = InvOf -- v4.2: экспорт для добычи/ампул/проверок
POLUS11.InvSaveNow = SaveInv -- v4.6.9: обменник жмёт сейв сразу после сделки

function POLUS11.InvCanUse(class)
    return isstring(class) and weapons.Get(class) ~= nil
end

-- v4.16.0 «ЗАХВАТ» (заявка владельца: «верни то, что оружие даётся
-- в инвентарь, а не в руки сразу»): ветка GIVE_ON_BUY «купил — сразу
-- в руки» (v4.11.0 «КУЗНЯ») ВЫРЕЗАНА вместе с нечто-исключением.
-- Вся закупка — опять в инвентарь: достать в руки — 🎒 C-меню →
-- ИСПОЛЬЗОВАТЬ, сдать обратно — кнопка «⬇ В БАГАЖ» (укладка v4.14.4).

-- купить (зовёт ларёк)
function POLUS11.ShopBuy(ply, id)
    local it = POLUS11.Items[id]
    if not it then return end
    -- v4.19.4 «ПОЧЁТ»: лекарства рассудка продаются ТОЛЬКО медслужбе
    if it.medjob then
        local jid = P11FW and P11FW.GetJobId and P11FW.GetJobId(ply) or ""
        local ok = (POLUS11.MedJobs and POLUS11.MedJobs[jid]) or (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
        if not ok then
            POLUS11.Notify(ply, "«" .. it.name .. "» интендант отпускает только МЕДСЛУЖБЕ (медсёстры, полевой медик, военврач). Попроси медика сходить за лекарством.")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return
        end
    end
    if id ~= "ampoule" and not it.ent and not it.ammo and not it.dyn and not it.mat and not it.sanity and not POLUS11.InvCanUse(it.class) then -- v4.19.4 «ПОЧЁТ»: +it.sanity (кофе/аминазин — предметы без класса)
        POLUS11.Notify(ply, "«" .. it.name .. "» сейчас нет на складе (нет пака оружия на сервере).")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    local price = (POLUS11.SalePrice and POLUS11.SalePrice(id)) or it.price -- v4.2: скидка дня
    if not POLUS11.TakeMoney(ply, price, "покупка: " .. it.name .. ((POLUS11.SaleOfDay and POLUS11.SaleOfDay.id == id) and " [СКИДКА ДНЯ]" or "")) then
        POLUS11.Notify(ply, "Не хватает " .. (price - POLUS11.GetMoney(ply)) ..
            "₽. Цена: " .. price .. "₽, у тебя: " .. POLUS11.GetMoney(ply) .. "₽.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    -- v4.16.0 «ЗАХВАТ»: всё уходит в инвентарь (как до «КУЗНИ»)
    local data = InvOf(ply)
    data.items[id] = (data.items[id] or 0) + 1
    DebouncedSave()
    POLUS11.Notify(ply, "«" .. it.name .. "» — в твоём инвентаре, в руки НЕ даётся (🎒 C-меню → ИСПОЛЬЗОВАТЬ — достать, «⬇ В БАГАЖ» — сдать обратно).")
    ply:EmitSound("buttons/button15.wav", 60, 105)
    POLUS11.InvSync(ply)
    POLUS11.Log(ply:Nick() .. " купил " .. it.name .. " за " .. it.price .. "₽")
end

-- использовать предмет из инвентаря
function POLUS11.InvUse(ply, id)
    local data = InvOf(ply)
    if (data.items[id] or 0) <= 0 then return end
    local it = POLUS11.Items[id]
    if not it then return end
    if not ply:Alive() then
        POLUS11.Notify(ply, "Мёртвым не положено.")
        return
    end
    if id == "ampoule" then
        POLUS11.Notify(ply, "Ампула — расходка: шприц потратит её сам при процедурной инъекции.")
        return
    end
    if it.sanity then -- v4.19.4 «ПОЧЁТ»: кофе/аминазин — глоток рассудка
        if POLUS11.SanityAdd then
            POLUS11.SanityAdd(ply, it.sanity, "«" .. it.name .. "»")
        else
            POLUS11.Notify(ply, "Модуль рассудка молчит — скажи Главе.")
            return
        end
        data.items[id] = data.items[id] - 1
        if data.items[id] <= 0 then data.items[id] = nil end
        DebouncedSave()
        if id == "coffee" then
            ply:EmitSound("npc/barnacle/barnacle_gulp2.wav", 60, 110)
        else
            ply:EmitSound("items/smallmedkit1.wav", 65, 100)
        end
        POLUS11.InvSync(ply)
        return
    end
    if it.dyn == true then -- v4.9.3 «ГРОШ»: умный боекомплект — два магазина к стволу в руках
        local wep = ply:GetActiveWeapon()
        local stype, smag = -1, 0
        if IsValid(wep) then
            stype = wep.GetPrimaryAmmoType and wep:GetPrimaryAmmoType() or -1
            smag = wep.GetMaxClip1 and wep:GetMaxClip1() or 0
        end
        if not IsValid(wep) or (stype or -1) < 0 then
            POLUS11.Notify(ply, "В руках не огнестрел — боекомплект не к чему. Возьми ствол и повтори.")
            return
        end
        local n = math.max((smag or 0) > 0 and smag * 2 or 60, 60)
        ply:GiveAmmo(n, stype, true)
        data.items[id] = data.items[id] - 1
        if data.items[id] <= 0 then data.items[id] = nil end
        DebouncedSave()
        POLUS11.Notify(ply, "Боекомплект к «" .. wep.GetPrintName and wep:GetPrintName() or wep:GetClass() .. "»: +" .. n .. " патронов (2 магазина).")
        ply:EmitSound("items/ammo_pickup.wav", 65, 100)
        POLUS11.InvSync(ply)
        return
    end
    if it.ammo then -- v4.9.3 «ГРОШ»: патроны пачкой
        ply:GiveAmmo(it.ammo.n, it.ammo.type, true)
        data.items[id] = data.items[id] - 1
        if data.items[id] <= 0 then data.items[id] = nil end
        DebouncedSave()
        POLUS11.Notify(ply, "Выдал склад: «" .. it.name .. "» — патроны уже в подсумке.")
        ply:EmitSound("items/ammo_pickup.wav", 65, 105)
        POLUS11.InvSync(ply)
        return
    end
    if it.mat == true then -- v4.10.0 «ГАРАЖ»: материал мастерской — руками не применяется
        POLUS11.Notify(ply, "«" .. it.name .. "» — материал для кустарной мастерской: 🎒 инвентарь → 🛠 МАСТЕРСКАЯ (или чат !крафт).")
        return
    end
    if it.ent == true then -- v4.9.1 «ИГЛА»: предмет-ЭНТИТИ (инъектор «УКОЛ-С») — спавнится перед тобой
        local e = ents.Create(it.class)
        if not IsValid(e) then
            POLUS11.Notify(ply, "Склад ошибся упаковкой — «" .. it.name .. "» не собрался. Скажи Главе.")
            return
        end
        e:SetPos(ply:GetPos() + ply:GetForward() * 45 + Vector(0, 0, 12))
        e:Spawn()
        e:Activate()
        data.items[id] = data.items[id] - 1
        if data.items[id] <= 0 then data.items[id] = nil end
        DebouncedSave()
        POLUS11.Notify(ply, "«" .. it.name .. "» — на полу перед тобой (E — применить).")
        ply:EmitSound("buttons/button9.wav", 55, 110)
        POLUS11.InvSync(ply)
        return
    end
    if not POLUS11.InvCanUse(it.class) then
        POLUS11.Notify(ply, "Предмет битый/не распознан сервером — пока не выдать.")
        return
    end
    if ply:HasWeapon(it.class) then
        POLUS11.Notify(ply, "У тебя уже есть «" .. it.name .. "» в руках.")
        return
    end
    ply:Give(it.class)
    data.items[id] = data.items[id] - 1
    if data.items[id] <= 0 then data.items[id] = nil end
    DebouncedSave()
    POLUS11.Notify(ply, "Взял в руки: " .. it.name .. ".")
    ply:EmitSound("buttons/button9.wav", 55, 110)
    POLUS11.InvSync(ply)
end

-- перекладка инвентарь → сейф
function POLUS11.StoreToSafe(ply, id)
    local data = InvOf(ply)
    if (data.items[id] or 0) <= 0 then return end
    data.items[id] = data.items[id] - 1
    if data.items[id] <= 0 then data.items[id] = nil end
    data.storage[id] = (data.storage[id] or 0) + 1
    DebouncedSave()
    POLUS11.InvSync(ply)
end

-- перекладка сейф → инвентарь
function POLUS11.TakeFromSafe(ply, id)
    local data = InvOf(ply)
    if (data.storage[id] or 0) <= 0 then return end
    data.storage[id] = data.storage[id] - 1
    if data.storage[id] <= 0 then data.storage[id] = nil end
    data.items[id] = (data.items[id] or 0) + 1
    DebouncedSave()
    POLUS11.InvSync(ply)
end

-- v4.14.4 «БАГАЖ» (заявка: «через C-меню положить оружие в руках в багаж»):
-- активный ствол укладывается в инвентарь ячейкой каталога ларька.
-- Когти Нечто, физган/тулган и прочий непокупной инструмент — НЕ лезет
-- (их классов в каталоге нет, отказ честный).
local STOW_ALIAS = { -- наследие: старые классы → ячейки каталога
    weapon_polus11_rpd = "rpd", -- скриптовый РПД из «ИГЛЫ» складывается в ячейку ARC9-РПД
}
function POLUS11.InvStow(ply)
    if not (IsValid(ply) and ply:Alive()) then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then
        POLUS11.Notify(ply, "В руках пусто — убирать нечего.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    local class = wep:GetClass()
    local id = STOW_ALIAS[class]
    local it = id and POLUS11.Items[id] or nil
    if not it then
        for cid, cand in pairs(POLUS11.Items) do
            if cand.class == class then id = cid it = cand break end
        end
    end
    if not it then
        POLUS11.Notify(ply, "«" .. class .. "» в багаж не лезет — укладывается только то, что продаёт ларёк.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end
    ply:StripWeapon(class)
    local data = InvOf(ply)
    data.items[id] = (data.items[id] or 0) + 1
    DebouncedSave()
    POLUS11.InvSync(ply)
    POLUS11.Notify(ply, "«" .. it.name .. "» убран в багаж. Вернуть: 🎒 C-меню → ИСПОЛЬЗОВАТЬ.")
    ply:EmitSound("buttons/button9.wav", 55, 110)
    POLUS11.Log(ply:Nick() .. " убрал «" .. it.name .. "» (" .. class .. ") в багаж")
end

-- ============ NET: действия из UI ============

net.Receive("P11_InvAct", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11_InvNext = ply.P11_InvNext or 0
    if CurTime() < ply.P11_InvNext then return end
    ply.P11_InvNext = CurTime() + 0.25

    local act = net.ReadUInt(4)
    local id  = string.sub(net.ReadString() or "", 1, 32)

    if act == 1 then      -- использовать
        POLUS11.InvUse(ply, id)
    elseif act == 5 then  -- v4.14.4 «БАГАЖ»: ствол из рук — в инвентарь
        POLUS11.InvStow(ply)
    elseif act == 2 then  -- купить (доступ только через открытый ларёк!)
        if not ply.P11_ShopOpenEnt or not IsValid(ply.P11_ShopOpenEnt)
            or ply:GetPos():DistToSqr(ply.P11_ShopOpenEnt:GetPos()) > 300 * 300 then
            POLUS11.Notify(ply, "Ларёк далеко — подойди к нему.")
            return
        end
        POLUS11.ShopBuy(ply, id)
    elseif act == 3 then  -- в сейф
        if not ply.P11_SafeOpenEnt or not IsValid(ply.P11_SafeOpenEnt)
            or ply:GetPos():DistToSqr(ply.P11_SafeOpenEnt:GetPos()) > 300 * 300 then return end
        POLUS11.StoreToSafe(ply, id)
    elseif act == 4 then  -- из сейфа
        if not ply.P11_SafeOpenEnt or not IsValid(ply.P11_SafeOpenEnt)
            or ply:GetPos():DistToSqr(ply.P11_SafeOpenEnt:GetPos()) > 300 * 300 then return end
        POLUS11.TakeFromSafe(ply, id)
    elseif act == 9 then  -- просто обновить UI
        POLUS11.InvSync(ply)
    end
end)

-- ============ НПС-ЛАРЁК / СЕЙФ: ОТКРЫТИЕ ============

util.AddNetworkString("P11_InvOpenShop") -- entity -> this file

function POLUS11.OpenShopUI(ply, ent)
    if not IsValid(ply) then return end
    ply.P11_ShopOpenEnt = ent
    POLUS11.InvSync(ply)
    net.Start("P11_ShopOpen")
    net.Send(ply)
    ply:EmitSound("buttons/button9.wav", 50, 110)
end

function POLUS11.OpenStorageUI(ply, ent)
    if not IsValid(ply) then return end
    ply.P11_SafeOpenEnt = ent
    POLUS11.InvSync(ply)
    net.Start("P11_StorageOpen")
    net.Send(ply)
    ply:EmitSound("buttons/button9.wav", 50, 110)
end

-- ============ v4.6.9: ЗАПАСНЫЕ ПУТИ К ЛАРЬКУ ============
-- E по торговцу — движковый Use по anim-энтити, на части машин
-- он не доезжает (модель, контент, поворот). Поэтому ларёк
-- открывается ТРЕМЯ равноправными путями:
--   1) E по торговцу (как было);
--   2) кнопка «🏪 Ларёк рядом» в C-меню (net P11_ShopTry);
--   3) чат: /ларёк, /ларек, !shop, /shop, /магазин.
-- Пути 2-3: сервер сам ищет ближайшего торговца в радиусе.

local SHOP_REACH = 550 -- юн до ближайшего ларька

function POLUS11.ShopFor(ply, quiet)
    if not IsValid(ply) or not ply:Alive() then return false end
    local best, bestD = nil, SHOP_REACH * SHOP_REACH
    for _, e in ipairs(ents.FindByClass("polus_p11_shopnpc")) do
        if IsValid(e) then
            local d = ply:GetPos():DistToSqr(e:GetPos())
            if d < bestD then best, bestD = e, d end
        end
    end
    if best then
        POLUS11.OpenShopUI(ply, best)
        return true
    end
    if not quiet then
        POLUS11.Notify(ply, "🏪 Ларёк не в зоне досягаемости (подойди ближе " ..
            SHOP_REACH .. " юн) — торговец снабжения стоит поющим «ЛАРЁК» над головой.")
        ply:EmitSound("buttons/button10.wav", 60, 95)
    end
    return false
end

-- кнопка C-меню / клиентская команда p11_shop
net.Receive("P11_ShopTry", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11_ShopTryNext = ply.P11_ShopTryNext or 0
    if CurTime() < ply.P11_ShopTryNext then return end
    ply.P11_ShopTryNext = CurTime() + 0.8
    POLUS11.ShopFor(ply)
end)

-- чат-путь к ларьку
hook.Add("PlayerSay", "P11.ShopChat", function(ply, text)
    local t = string.lower(string.Trim(tostring(text or "")))
    if t == "/ларёк" or t == "/ларек" or t == "!ларёк" or t == "!ларек"
        or t == "/shop" or t == "!shop" or t == "/магазин" or t == "!магазин" then
        POLUS11.ShopFor(ply)
        return ""
    end
end)

-- диагностика владельца: p11_shopdiag (консоль сервера / админ)
concommand.Add("p11_shopdiag", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local out = { "== ЛАРЁК: ДИАГНОСТИКА v4.6.9 ==" }
    local n = 0
    for _, e in ipairs(ents.FindByClass("polus_p11_shopnpc")) do
        if IsValid(e) then
            n = n + 1
            local solid = IsValid(e:GetPhysicsObject()) or e:GetSolid() ~= SOLID_NONE
            out[#out + 1] = "  shopnpc #" .. n .. " @ " .. tostring(e:GetPos())
                .. " | модель: " .. tostring(e:GetModel())
                .. " | ТВЁРДОСТЬ: " .. (solid and "да ✔" or "НЕТ ⚠ (перепоставь объект)")
        end
    end
    if n == 0 then
        out[#out + 1] = "  ⚠ ТОРГОВЦЕВ НЕТ НА КАРТЕ — поставь: C-меню → 📍 Поставить → 🏪 Ларёк снабжения."
    end
    out[#out + 1] = "  OpenShopUI: " .. tostring(POLUS11.OpenShopUI ~= nil)
        .. " | ShopFor: " .. tostring(POLUS11.ShopFor ~= nil)
    out[#out + 1] = "  товаров в каталоге: " .. table.Count(POLUS11.Items or {})
        .. " | инвентарей в памяти: " .. table.Count(POLUS11.Inv or {})
    out[#out + 1] = "  если торговец стоит, а E молчит у игрока — это движок;"
    out[#out + 1] = "  скажи ему /ларёк в чат или кнопку «🏪 Ларёк рядом» в C-меню."
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[POLUS-11] ларёк v4.7.4: тело торговца самолечится (VPHYSICS→BBOX), три пути (E / C-меню / /ларёк), diag p11_shopdiag")

-- ============ РАССТАНОВКА ОБЪЕКТОВ (админ 📍) ============

-- класс -> файл с координафми на карте
local PLACEABLE = {
    generator = "polus11_generator",
    terminal  = "polus11_terminal",
    shopnpc   = "polus_p11_shopnpc",
    storage   = "polus_p11_storage",
    kitchen   = "polus_p11_kitchen", -- v4.2: полевая кухня повара
    avtosalon = "polus11_avtosalon", -- v4.10.0 «ГАРАЖ»: торговец транспортом LVS
    crafttable = "polus11_crafttable", -- v4.11.0 «КУЗНЯ»: верстак (стол крафтов)
    crate     = "polus11_lootcrate",  -- v4.11.0 «КУЗНЯ»: ящик лома (лут)
    barrel    = "polus11_lootbarrel", -- v4.11.0 «КУЗНЯ»: топливная бочка (лут)
    cache     = "polus11_lootcache",  -- v4.11.0 «КУЗНЯ»: тайник снабженца (лут)
    med       = "polus11_lootmed",    -- v4.12.0 «ОТБОЙ»: медшкаф (лут)
    mil       = "polus11_lootmil",    -- v4.12.0 «ОТБОЙ»: оружейный ящик (лут)
    tech      = "polus11_loottech",   -- v4.12.0 «ОТБОЙ»: груда лома (лут)
    bloodlab  = "polus11_bloodlab",   -- v4.12.0 «ОТБОЙ»: стол анализа крови «КРОВЬ-2» — снова расставляется и сохраняется
    labtable  = "polus11_labtable",   -- v4.12.0 «ОТБОЙ»: лабораторный стол (тест крови)
    food      = "polus11_lootfood",   -- v4.15.0 «УГЛИ»: продовольственный ящик (лут, восполняется)
    arm       = "polus11_lootarm",    -- v4.15.0 «УГЛИ»: армейский контейнер (лут, восполняется)
    hearth    = "polus11_hearth",     -- v4.15.0 «УГЛИ»: буржуйка — топливо из 🎒 → жар греет станцию
    flag      = "polus11_cappoint",   -- v4.16.0 «ЗАХВАТ»: точка захвата РККА ↔ Орёл (шкала/оклад)
    contract  = "polus_p11_contractnpc", -- v4.19.4 «ПОЧЁТ»: интендант-нарядник (контракты часа)
}

local function PlaceFile(role)
    return "polus_framework/place_" .. role .. "_" .. game.GetMap() .. ".json"
end

local function SavePlaced(role)
    local out = {}
    for _, e in ipairs(ents.FindByClass(PLACEABLE[role])) do
        if IsValid(e) then
            out[#out + 1] = { pos = e:GetPos(), ang = e:GetAngles() }
        end
    end
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    file.Write(PlaceFile(role), util.TableToJSON(out))
end

local function LoadPlaced(role)
    local raw = file.Read(PlaceFile(role), "DATA")
    if not raw then return end
    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then return end
    for _, e in ipairs(ents.FindByClass(PLACEABLE[role])) do e:Remove() end -- антидубль
    for _, d in ipairs(tbl) do
        if isvector and isvector(d.pos) then
            local e = ents.Create(PLACEABLE[role])
            if IsValid(e) then
                e:SetPos(d.pos)
                e:SetAngles(d.ang or Angle(0, 0, 0))
                e:Spawn()
                e:Activate()
            end
        end
    end
end

-- v4.11.0 «КУЗНЯ»: расстановку отдаём модулю лута (p11_lootspawn/p11_lootclear)
POLUS11.PLACEABLE = PLACEABLE
POLUS11.PlaceSave = SavePlaced
POLUS11.PlaceLoad = LoadPlaced

hook.Add("InitPostEntity", "P11.PlaceLoad", function()
    -- генератор/терминал грузит общий persist-станции; ларёк/сейф — свои файлы
    timer.Simple(2, function()
        LoadPlaced("shopnpc")
        LoadPlaced("storage")
        LoadPlaced("terminal")
        LoadPlaced("kitchen")
        LoadPlaced("avtosalon") -- v4.10.0 «ГАРАЖ»
        LoadPlaced("crafttable") -- v4.11.0 «КУЗНЯ»
        LoadPlaced("crate")
        LoadPlaced("barrel")
        LoadPlaced("cache")
        LoadPlaced("med")       -- v4.12.0 «ОТБОЙ»
        LoadPlaced("mil")
        LoadPlaced("tech")
        LoadPlaced("bloodlab")  -- v4.12.0 «ОТБОЙ»: стол крови возвращён
        LoadPlaced("labtable")
        LoadPlaced("contract")  -- v4.19.4 «ПОЧЁТ»: интендант-нарядник
        -- внимание: «generator» НЕ грузим — энергосистема выведена из игры (v4.12.0)
    end)
end)
hook.Add("PostCleanupMap", "P11.PlaceLoad2", function()
    timer.Simple(1, function()
        LoadPlaced("shopnpc")
        LoadPlaced("storage")
        LoadPlaced("terminal")
        LoadPlaced("patrol")
        LoadPlaced("kitchen")
        LoadPlaced("avtosalon") -- v4.10.0 «ГАРАЖ»
        LoadPlaced("crafttable") -- v4.11.0 «КУЗНЯ»
        LoadPlaced("crate")
        LoadPlaced("barrel")
        LoadPlaced("cache")
        LoadPlaced("med")       -- v4.12.0 «ОТБОЙ»
        LoadPlaced("mil")
        LoadPlaced("tech")
        LoadPlaced("bloodlab")  -- v4.12.0 «ОТБОЙ»: стол крови возвращён
        LoadPlaced("labtable")
        LoadPlaced("contract")  -- v4.19.4 «ПОЧЁТ»: интендант-нарядник
        -- внимание: «generator» НЕ грузим — энергосистема выведена из игры (v4.12.0)
    end)
end)

net.Receive("P11_PlaceEnt", function(len, ply)
    if not IsValid(ply) then return end
    if not P11FW.Config.Admin(ply) then return end

    ply.P11_PlaceNext = ply.P11_PlaceNext or 0
    if CurTime() < ply.P11_PlaceNext then return end
    ply.P11_PlaceNext = CurTime() + 0.7

    local role = string.sub(net.ReadString() or "", 1, 16)
    if role == "generator" then -- v4.12.0 «ОТБОЙ»: генератор вырезан из игры наглухо
        POLUS11.Notify(ply, "Генератор ВЫРЕЗАН из игры (v4.12.0 «ОТБОЙ»): ставить больше нечего. Свет горит всегда.")
        ply:ChatPrint("[СТАНЦИЯ] Энергосистема выведена из игры. Новые точки: верстак, ящики, медшкаф, стол крови.")
        return
    end
    local class = PLACEABLE[role]
    if not class then return end

    local tr = ply:GetEyeTrace()
    local pos = tr.HitPos + tr.HitNormal * 8
    local ang = Angle(0, ply:EyeAngles().y + 180, 0)

    local e = ents.Create(class)
    if not IsValid(e) then
        POLUS11.Notify(ply, "Энтити «" .. tostring(class) .. "» не создалась.")
        return
    end
    e:SetPos(pos)
    e:SetAngles(ang)
    e:Spawn()
    e:Activate()
    util.DropToFloor(e)

    -- сохранение: генератор/терминал — общий persist СТАНЦИИ (сам подхватит),
    -- ларёк/сейф — свои place-файлы
    if role ~= "generator" and role ~= "terminal" then
        SavePlaced(role)
    else
        if POLUS11.SaveStation then timer.Simple(1, POLUS11.SaveStation) end
        SavePlaced("terminal") -- и в свой файл, на случай отключённого StationPersist
    end

    POLUS11.Notify(ply, "Объект «" .. role .. "» размещён и сохранён на карте.")
    POLUS11.Log(ply:Nick() .. " разместил " .. role .. " @ " .. tostring(pos))
    ply:EmitSound("buttons/button15.wav", 55, 110)
end)
