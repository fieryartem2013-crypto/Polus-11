-- ============================================================
--  ПОЛЮС-11 — ГАРАЖ «ПОЛЮС-АВТО» (server) v4.10.0 «ГАРАЖ»
--  Заявка владельца: «сделай с чистого листа НПС, у которого
--  покупаются транспорты: lvs_wheeldrive_pz1bison, lvs_plane_yak2
--  (самолёт), lvs_vorosh, lvs_gaz_med, lvs_gaz_supe».
--
--  КАК РАБОТАЕТ:
--   • торговец — энтити polus11_avtosalon (ставится из C-меню
--     админа «📍 Расставить → 🚗 Гараж», живёт на карте постоянно);
--   • E по торговцу (или !гараж / кнопка-команда p11_garage рядом)
--     → окно-каталог: цена → «КУПИТЬ» → транспорт выезжает
--     из-за торговца на свободную площадку;
--   • транспорт — классы LVS (нужен [LVS] Lua Vehicle System
--     и паки с этими машинами; если класса нет — гараж честно
--     скажет, чего не хватает, и денег не возьмёт);
--   • САМОЛЁТ Як-2 — для должностей «Лётчик РККА» и «Лётчик Красного Орла» (v4.31.0)
--     (или ключа «ПОЛЮС-ФЛЮКС» из витрины поддержки, штрафной
--     каратель — Глава, ранг 16);
--   • у игрока — ОДИН транспорт: новая покупка утилизирует старую,
--     при выходе с сервера его машина убирается с площадки.
-- ============================================================

util.AddNetworkString("P11_GarageOpen")
util.AddNetworkString("P11_GarageBuy")
util.AddNetworkString("P11_GarageTry")

local NPC_CLASS = "polus11_avtosalon"
-- v4.31.0 «КРЫЛО»: ВТОРОЙ ТОРГОВЕЦ — транспортник американцев «ЯНКИ-АВТО»
-- (заявка владельца «НПС транспортник для американцев; список транспортов
-- скину позже — пока что-то из пака LVS на плейсхолдер»). Своя лавка, свой
-- каталог, покупать могут ТОЛЬКО бойцы стороны США (+ Глава для проверки).
local NPC_USA = "polus_p11_usasalon"

local function IsDealerClass(cls)
    return cls == NPC_CLASS or cls == NPC_USA
end
local function DealerSide(ent)
    return (IsValid(ent) and ent:GetClass() == NPC_USA) and "usa" or "ussr"
end
-- янки-лавка — только американской стороне
local function IsYankee(ply)
    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 16 then return true end -- Главе — на проверку
    if POLUS11.Op and POLUS11.Op.side and POLUS11.Op.side[ply] == "eagle" then return true end
    local jid = P11FW.GetJobId and P11FW.GetJobId(ply) or ""
    local job = (jid ~= "" and P11FW.Jobs) and P11FW.Jobs[jid] or nil
    local cat = job and (job.faction or job.category) or ""
    return cat == "eagle" or cat == "op_usa"
end

-- ============ КАТАЛОГ ТРАНСПОРТА ============
-- r — радиус корпуса (для поиска свободной площадки выдачи)
POLUS11.Garage = {
    {
        id = "bison", class = "lvs_wheeldrive_pz1bison",
        name = "Бронеавтомобиль «Бизон» (танк)", price = 65000, r = 130, -- v4.17.0 «КОНТРАБАНДА» (заявка «танк увеличить цену до 65к»): 9500 → 65000₽
        desc = "Колёсный броневик сопровождения. Бурая корка снега не проблема.",
    },
    {
        id = "vorosh", class = "lvs_vorosh",
        name = "Тяжёлый тягач «Ворошиловец»", price = 15000, r = 170,
        desc = "Гусеничный трамвай полярной зимы: волочёт что угодно и куда угодно.",
    },
    {
        id = "gazmed", class = "lvs_gaz_med",
        name = "ГАЗ «Санитарка»", price = 8500, r = 110,
        desc = "Красный крест на дверце. Возить раненых — её прямая служба.",
    },
    {
        id = "gazsup", class = "lvs_gaz_supe",
        name = "ГАЗ «Снабжение»", price = 8500, r = 110,
        desc = "Бортовая «полуторка» склада: бочки с солярой и ящики с тушёнкой — сюда.",
    },
    {
        -- v4.15.1 «ТРЁХТОНКА»: новый транспорт по заявке владельца (lvs_zis5_41)
        id = "zis5", class = "lvs_zis5_41",
        name = "ЗиС-5 «Трёхтонка» (1941)", price = 11000, r = 155,
        desc = "Легендарная трёхтонка: простой, как лопата, везёт три тонны туда, где нет дорог. Год 41-го — деды знают.",
    },
    {
        id = "yak2", class = "lvs_plane_yak2",
        name = "Самолёт Як-2", price = 45000, r = 430, pilot = true,
        desc = "Двухмоторный связной Центра. НЕБО — ТОЛЬКО ДЛЯ ЛЁТЧИКА РККА (или ключа ФЛЮКСА).",
    },
}

-- v4.31.0 «КРЫЛО»: КАТАЛОГ ЯНКИ-АВТО — ПЛЕЙСХОЛДЕРЫ на классах LVS
-- (владелец пришлёт настоящий список позже). Имена помечены ▶замена◀.
POLUS11.GarageUS = {
    {
        id = "us_jeep", class = "lvs_gaz_supe",
        name = "«Уиллис MB» (плейсхолдер)", price = 8000, r = 110,
        desc = "▶ПЛЕЙСХОЛДЕР◀ Американский лёгкий разъездной. Заменю по списку владельца.",
    },
    {
        id = "us_dodge", class = "lvs_gaz_med",
        name = "«Додж WC-54» санитарный (плейсхолдер)", price = 9000, r = 110,
        desc = "▶ПЛЕЙСХОЛДЕР◀ Санитарный фургон армии США. Заменю по списку владельца.",
    },
    {
        id = "us_stude", class = "lvs_zis5_41",
        name = "«Студебеккер US6» (плейсхолдер)", price = 12000, r = 155,
        desc = "▶ПЛЕЙСХОЛДЕР◀ Ленд-лизовская трёхтонка союзников. Заменю по списку владельца.",
    },
}

local function GarageEntry(id, side)
    local cat = (side == "usa") and POLUS11.GarageUS or POLUS11.Garage
    for _, it in ipairs(cat) do
        if it.id == id then return it end
    end
    return nil
end

-- класс машины действительно стоит на сервере?
local function LvsHas(class)
    return scripted_ents.GetStored(class) ~= nil
end

-- есть ли допуск в небо (лётчик РККА / лётчик Орла / Глава / ключ ФЛЮКСА)
local function HasSkyClearance(ply)
    local skjid = P11FW.GetJobId and P11FW.GetJobId(ply) or ""
    if skjid == "seed_rkka_letchik" or skjid == "seed_eagle_letchik" then return true end -- v4.31.0 «КРЫЛО»
    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 16 then return true end
    if ply.P11_FluxYak == true then return true end -- ключ из витрины поддержки
    return false
end

-- ============ ОКНО-КАТАЛОГ ============

function POLUS11.OpenGarageUI(ply, ent)
    if not IsValid(ply) then return end
    local side = DealerSide(ent)
    if side == "usa" and not IsYankee(ply) then -- v4.31.0 «КРЫЛО»: янки-лавка не для советских
        POLUS11.Notify(ply, "🦅 «ЯНКИ-АВТО» — транспорт только для американской стороны (Орёл / США операции).")
        ply:EmitSound("buttons/button10.wav", 60, 92)
        return
    end
    ply.P11_GarageEnt = ent
    local list = (side == "usa") and POLUS11.GarageUS or POLUS11.Garage
    local cat = {}
    for _, it in ipairs(list) do
        cat[#cat + 1] = {
            id = it.id, name = it.name, price = it.price, desc = it.desc,
            pilot = it.pilot == true,
            ok = LvsHas(it.class),
            skyok = (not it.pilot) or HasSkyClearance(ply),
            fluxkey = ply.P11_FluxYak == true,
        }
    end
    net.Start("P11_GarageOpen")
        net.WriteString(util.TableToJSON({ -- v4.31.0: объектом — с именем лавки
            shop = (side == "usa") and "🦅 ЯНКИ-АВТО (США)" or "🚗 ГАРАЖ «ПОЛЮС-АВТО»",
            sub  = (side == "usa") and "транспорт американской стороны — плейсхолдеры до списка командования"
                                     or "транспорт с конвейера — выдача на площадке у торговца",
            items = cat,
        }) or "{}")
    net.Send(ply)
    ply:EmitSound("buttons/button9.wav", 50, 110)
end

-- ============ ПЛОЩАДКА ВЫДАЧИ ============
-- Свободный круг рядом с торговцем: кольцо проб по возрастающей
-- дистанции; без сущностей внутри и без геометрии мира в корпусе.

local function SpotFree(pos, r)
    if not util.IsInWorld(pos) then return false end
    for _, e in ipairs(ents.FindInSphere(pos, r)) do
        if IsValid(e) then
            local cls = e:GetClass() or ""
            if e:IsPlayer() or e:IsNPC() or e:IsVehicle()
                or string.StartWith(cls, "lvs_")
                or cls == "prop_physics" or cls == "prop_ragdoll" then
                return false
            end
        end
    end
    local tr = util.TraceHull({
        start  = pos + Vector(0, 0, 90),
        endpos = pos + Vector(0, 0, 30),
        mins   = Vector(-r, -r, -4),
        maxs   = Vector(r, r, 60),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return not tr.Hit
end

local function FindVehicleSpot(npc, r)
    local base = npc:GetPos()
    -- 1) прямая траектория перед торговцем
    for i = 1, 6 do
        local pos = base + npc:GetForward() * (140 + r + i * 90)
        pos.z = base.z
        if SpotFree(pos, r * 0.85) then return pos, npc:GetAngles() end
    end
    -- 2) кольцо вокруг
    local rays = 10
    for ring = 1, 4 do
        local dist = 180 + r + ring * 110
        for k = 0, rays - 1 do
            local a = npc:GetAngles().y + (360 / rays) * k
            local rad = math.rad(a)
            local pos = base + Vector(math.cos(rad), math.sin(rad), 0) * dist
            pos.z = base.z
            if SpotFree(pos, r * 0.85) then
                return pos, Angle(0, a + 180, 0)
            end
        end
    end
    return nil, nil
end

-- ============ ПОКУПКА ============

function POLUS11.GarageBuy(ply, id)
    if not ply:Alive() then
        POLUS11.Notify(ply, "Мёртвому транспорт без надобности.")
        return
    end
    local ent = ply.P11_GarageEnt
    if not IsValid(ent) or not IsDealerClass(ent:GetClass())
        or ply:GetPos():DistToSqr(ent:GetPos()) > 400 * 400 then
        POLUS11.Notify(ply, "Гараж далеко — подойди к торговцу транспортом.")
        return
    end
    local side = DealerSide(ent) -- v4.31.0 «КРЫЛО»
    if side == "usa" and not IsYankee(ply) then
        POLUS11.Notify(ply, "🦅 «ЯНКИ-АВТО» — транспорт только для американской стороны.")
        ply:EmitSound("buttons/button10.wav", 60, 92)
        return
    end
    local it = GarageEntry(id, side)
    if not it then return end

    -- LVS-пак установлен?
    if not LvsHas(it.class) then
        POLUS11.Notify(ply, "«" .. it.name .. "» — пустой бокс: на сервере НЕТ пака LVS с классом «" ..
            it.class .. "». Главе: поставь [LVS] Base + пак этой техники из воркшопа.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end

    -- небо — только лётчикам (или ключу ФЛЮКСА/Главе)
    local useFluxKey = false
    if it.pilot and not HasSkyClearance(ply) then
        POLUS11.Notify(ply, "✋ " .. it.name .. " — не детская бабочка: допуск в небо есть у должностей «Лётчик РККА» и «Лётчик Красного Орла» (F4).")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end

    -- цена: ключ ФЛЮКСА на Як-2 = разовый бесплатный борт
    local price = it.price
    if it.pilot and ply.P11_FluxYak == true and P11FW.GetJobId and P11FW.GetJobId(ply) ~= "seed_rkka_letchik"
        and P11FW.GetJobId(ply) ~= "seed_eagle_letchik" then -- v4.31.0 «КРЫЛО»: у орловского лётчика своего ключа нет — он по должности
        price = 0
        useFluxKey = true
    end

    -- площадка ищется ДО списания
    local pos, ang = FindVehicleSpot(ent, it.r)
    if not pos then
        POLUS11.Notify(ply, "Площадка забита: вокруг гаража нет " ..
            math.ceil(it.r * 2 / 52) .. " метров свободного места. Разгони толпу/машины и повтори.")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return
    end

    if price > 0 then
        -- v4.14.5 «ТИШИНА»: перед «нет денег» — авто-лечение кошелька из сейва
        if POLUS11.MoneyResync then POLUS11.MoneyResync(ply) end
        if not POLUS11.TakeMoney(ply, price, "гараж: " .. it.name) then
            POLUS11.Notify(ply, "Не хватает " .. (price - POLUS11.GetMoney(ply)) ..
                "₽. Цена: " .. price .. "₽, у тебя: " .. POLUS11.GetMoney(ply) .. "₽.")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return
        end
    else
        ply.P11_FluxYak = false
        POLUS11.Notify(ply, "🔑 Ключ ФЛЮКСА погашен: «" .. it.name .. "» — за счёт покровителей.")
    end

    -- старый транспорт — в утиль (одно авто на бойца)
    local old = ply.P11_GarageVeh
    if IsValid(old) then
        old:Remove()
        POLUS11.Notify(ply, "Старый транспорт утилизирован (правило: одна машина на бойца).")
    end

    local veh = ents.Create(it.class)
    if not IsValid(veh) then
        -- класс был, а объект не собрался — вернуть деньги
        if price > 0 then POLUS11.AddMoney(ply, price, "гараж: откат (не собрался)") end
        if useFluxKey then ply.P11_FluxYak = true end
        POLUS11.Notify(ply, "Конвейер дал сбой — транспорт не собрался. Деньги вернули.")
        return
    end
    veh:SetPos(pos + Vector(0, 0, 8))
    veh:SetAngles(ang or Angle(0, 0, 0))
    veh:Spawn()
    veh:Activate()
    veh.P11_GarageOwner = ply:SteamID()
    ply.P11_GarageVeh = veh
    util.DropToFloor(veh)

    ply:EmitSound("items/ammo_pickup.wav", 70, 100, 100)
    ply:ChatPrint("[ПОЛЮС-АВТО] 🚗 «" .. it.name .. "\" выдан за " .. price ..
        "₽. Сесть за штурвал: [E] у дверцы. Утилизация — при новой покупке или выходе со смены.")
    POLUS11.Notify(ply, "🚗 «" .. it.name .. "» ждёт на площадке!")
    POLUS11.Log("ГАРАЖ: " .. ply:Nick() .. " (" .. ply:SteamID() .. ") купил " ..
        it.class .. " за " .. price .. "₽" .. (useFluxKey and " [ключ ФЛЮКСА]" or ""))
end

net.Receive("P11_GarageBuy", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_GarageNext = ply.P11_GarageNext or 0
    if CurTime() < ply.P11_GarageNext then return end
    ply.P11_GarageNext = CurTime() + 0.5
    local id = string.sub(net.ReadString() or "", 1, 24)
    POLUS11.GarageBuy(ply, id)
end)

-- ============ ЗАПАСНЫЕ ДВЕРИ В ГАРАЖ ============

local GARAGE_REACH = 650

function POLUS11.GarageFor(ply, quiet)
    if not IsValid(ply) or not ply:Alive() then return false end
    local best, bestD = nil, GARAGE_REACH * GARAGE_REACH
    for _, cls in ipairs({ NPC_CLASS, NPC_USA }) do -- v4.31.0 «КРЫЛО»: обе лавки
        for _, e in ipairs(ents.FindByClass(cls)) do
            if IsValid(e) then
                local d = ply:GetPos():DistToSqr(e:GetPos())
                if d < bestD then best, bestD = e, d end
            end
        end
    end
    if best then
        POLUS11.OpenGarageUI(ply, best)
        return true
    end
    if not quiet then
        POLUS11.Notify(ply, "🚗 Гараж не в зоне досягаемости (подойди к «ПОЛЮС-АВТО», " ..
            GARAGE_REACH .. " юн). Нет торговца? Глава ставит: C-меню → 📍 → 🚗 Гараж.")
        ply:EmitSound("buttons/button10.wav", 60, 95)
    end
    return false
end

net.Receive("P11_GarageTry", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_GarageTryNext = ply.P11_GarageTryNext or 0
    if CurTime() < ply.P11_GarageTryNext then return end
    ply.P11_GarageTryNext = CurTime() + 0.8
    POLUS11.GarageFor(ply)
end)

-- KeyPress-страховка (если движковый Use по торговцу тонет)
hook.Add("KeyPress", "P11.GarageKey", function(ply, key)
    if key ~= IN_USE then return end
    local tr = ply:GetEyeTrace()
    if not (tr and IsValid(tr.Entity) and IsDealerClass(tr.Entity:GetClass()) -- v4.31.0 «КРЫЛО»: любой из торговцев
        and tr.HitPos:DistToSqr(ply:GetPos()) < 220 * 220) then return end
    POLUS11.OpenGarageUI(ply, tr.Entity)
end)

-- чат-дверь: !гараж
hook.Add("PlayerSay", "P11.GarageChat", function(ply, text)
    local t = string.lower(string.Trim(tostring(text or "")))
    if t == "!гараж" or t == "!garage" or t == "!авто" or t == "!машина"
        or t == "/гараж" or t == "/garage" or t == "/авто" or t == "/машина" then
        POLUS11.GarageFor(ply)
        return ""
    end
end)

-- уборка: машина бойца пропадает вместе с боцом со смены
hook.Add("PlayerDisconnected", "P11.GarageBye", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID()
    for _, e in ipairs(ents.GetAll()) do
        if IsValid(e) and e.P11_GarageOwner == sid then
            e:Remove()
        end
    end
end)

-- ============ ДИАГНОСТИКА ============

concommand.Add("p11_garagediag", function(ply)
    if IsValid(ply) and (P11FW.Config.Admin and not P11FW.Config.Admin(ply)) then return end
    local out = { "== ГАРАЖ «ПОЛЮС-АВТО»: ДИАГНОСТИКА v4.10.0 ==" }
    local n = 0
    for _, e in ipairs(ents.FindByClass(NPC_CLASS)) do
        if IsValid(e) then
            n = n + 1
            out[#out + 1] = "  торговец #" .. n .. " @ " .. tostring(e:GetPos())
        end
    end
    if n == 0 then
        out[#out + 1] = "  ⚠ ТОРГОВЦЕВ НЕТ: C-меню → 📍 Расставить → 🚗 Гараж (сохранится на карте)."
    end
    for _, it in ipairs(POLUS11.Garage) do
        out[#out + 1] = "  " .. it.id .. " («" .. it.class .. "»): " ..
            (LvsHas(it.class) and "пак СТОИТ ✔" or "ПАКА НЕТ ✖ — поставь LVS-пак из воркшопа")
    end
    out[#out + 1] = "  допуск в небо: «Лётчик РККА» / «Лётчик Красного Орла» (F4) / ключ ФЛЮКСА / Глава"
    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[POLUS-11] гараж «ПОЛЮС-АВТО» v4.10.0 загружен: LVS-каталог (" ..
    table.Count(POLUS11.Garage) .. " машин), допуск в небо — лётчики, diag p11_garagediag")
