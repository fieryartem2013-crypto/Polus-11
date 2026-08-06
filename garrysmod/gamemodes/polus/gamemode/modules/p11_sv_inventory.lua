-- ============================================================
--  ПОЛЮС-11 — ИНВЕНТАРЬ + МАГАЗИН + ЛИЧНЫЙ СЕЙФ (server) v4.0
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

local FILE = "polus11/inventory.json"

-- ============ КАТАЛОГ ТОВАРОВ ============
-- id -> { name, price, class, desc }; class = класс свepа (kind=оружие)
-- Оружие EFT/DOI требует установленные паки ARC9 (как профы РККА).

POLUS11.Items = {
    -- ---- оружие из EFT/DOI (подбор владельца) ----
    aks74u   = { name = "АКС-74У",          price = 4000, class = "arc9_eft_aks74u",        desc = "Короткий караулер. Штат ствол постовых РККА." },
    aks74    = { name = "АК-74",            price = 5000, class = "arc9_eft_aks74",         desc = "Полноразмерный армейский автомат." },
    ppsh41   = { name = "ППШ-41",           price = 6500, class = "arc9_eft_ppsh41",        desc = "«Папаша» штурмовика, косит в упор.", },
    mosin    = { name = "Винтовка Мосина",  price = 5500, class = "arc9_eft_mosin_infantry",desc = "Разведывательная трёхлинейка, бьёт далеко." },
    mr43     = { name = "МР-43 (двухств.)", price = 3500, class = "arc9_eft_mr43",          desc = "Двустволка: две причины не подходить." },
    k98      = { name = "Mauser Kar98k",    price = 5000, class = "arc9_doi_k98",           desc = "Офицерский карабин особого отделa." },
    -- ---- станционный скарб ----
    radio    = { name = "Рация",            price = 1200, class = "weapon_polus11_radio",   desc = "Эфир фракций: /r — текст, R — канал." },
    ration   = { name = "Горячий паёк",     price = 250,  class = "weapon_polus11_ration",  desc = "Греет изнутри (+тепло, +немного ХП)." },
    syringe  = { name = "Полевой шприц",    price = 800,  class = "weapon_polus11_syringe", desc = "Забор крови / экстренная обработка." },
    chemlight= { name = "Химсвет (пачка)",  price = 150,  class = "weapon_polus11_chemlight",desc = "Кидай и размечай путь в облаке спор." },
    scalpel  = { name = "Скальпель",        price = 600,  class = "weapon_polus11_scalpel", desc = "Хирургический. И не только хирургический." },
    ampoule  = { name = "Ампула «Анальгин-С»", price = 300, class = "p11_ampoule",          desc = "Расходка медика для процедурной инъекции (+25 ХП). В руки не даётся." },
    flamer   = { name = "Кустарный огнемёт",price = 7500, class = "weapon_polus11_flamethrower", desc = "Единственный надёжный аргумент против Нечто." },
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
    local data = InvOf(ply)
    -- каталог шлём тоже (цены могут правиться без рестарта)
    local cat = {}
    for id, it in pairs(POLUS11.Items) do
        cat[id] = { name = it.name, price = it.price, desc = it.desc, class = it.class }
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

function POLUS11.InvCanUse(class)
    return isstring(class) and weapons.Get(class) ~= nil
end

-- купить (зовёт ларёк)
function POLUS11.ShopBuy(ply, id)
    local it = POLUS11.Items[id]
    if not it then return end
    if id ~= "ampoule" and not POLUS11.InvCanUse(it.class) then
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
    local data = InvOf(ply)
    data.items[id] = (data.items[id] or 0) + 1
    DebouncedSave()
    POLUS11.Notify(ply, "«" .. it.name .. "» — в твоём инвентаре (🎒 в C-меню).")
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

-- ============ РАССТАНОВКА ОБЪЕКТОВ (админ 📍) ============

-- класс -> файл с координафми на карте
local PLACEABLE = {
    generator = "polus11_generator",
    terminal  = "polus11_terminal",
    shopnpc   = "polus_p11_shopnpc",
    storage   = "polus_p11_storage",
    patrol    = "polus_p11_patrol", -- v4.1: посты патруля
    kitchen   = "polus_p11_kitchen", -- v4.2: полевая кухня повара
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

hook.Add("InitPostEntity", "P11.PlaceLoad", function()
    -- генератор/терминал грузит общий persist-станции; ларёк/сейф — свои файлы
    timer.Simple(2, function()
        LoadPlaced("shopnpc")
        LoadPlaced("storage")
        LoadPlaced("terminal")
        LoadPlaced("patrol")
        LoadPlaced("kitchen")
        if POLUS11.PatrolSyncAll then timer.Simple(2.5, function() POLUS11.PatrolSyncAll(nil) end) end
    end)
end)
hook.Add("PostCleanupMap", "P11.PlaceLoad2", function()
    timer.Simple(1, function()
        LoadPlaced("shopnpc")
        LoadPlaced("storage")
        LoadPlaced("terminal")
        LoadPlaced("patrol")
        LoadPlaced("kitchen")
        if POLUS11.PatrolSyncAll then timer.Simple(1.5, function() POLUS11.PatrolSyncAll(nil) end) end
    end)
end)

net.Receive("P11_PlaceEnt", function(len, ply)
    if not IsValid(ply) then return end
    if not P11FW.Config.Admin(ply) then return end

    ply.P11_PlaceNext = ply.P11_PlaceNext or 0
    if CurTime() < ply.P11_PlaceNext then return end
    ply.P11_PlaceNext = CurTime() + 0.7

    local role = string.sub(net.ReadString() or "", 1, 16)
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
        if role == "patrol" and POLUS11.PatrolSyncAll then
            timer.Simple(0.5, function() POLUS11.PatrolSyncAll(nil) end)
        end
    else
        if POLUS11.SaveStation then timer.Simple(1, POLUS11.SaveStation) end
        SavePlaced("terminal") -- и в свой файл, на случай отключённого StationPersist
    end

    POLUS11.Notify(ply, "Объект «" .. role .. "» размещён и сохранён на карте.")
    POLUS11.Log(ply:Nick() .. " разместил " .. role .. " @ " .. tostring(pos))
    ply:EmitSound("buttons/button15.wav", 55, 110)
end)
