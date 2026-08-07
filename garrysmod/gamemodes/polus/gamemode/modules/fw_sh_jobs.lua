-- ============================================================
--  ПОЛЮС FRAMEWORK — ПРОФЕССИИ (shared)
--  Здесь определяются ВСЕ должности станции. Чтобы добавить
--  свою — скопируй блок и поменяй поля. Имена совпадают с
--  списками ScientistTeams/EngineerTeams в конфиге ПОЛЮС-11 —
--  механики станции (тест крови, заправка огнемёта) сами
--  привяжутся к профессиям.
-- ============================================================

P11FW = P11FW or {}

-- ============ КАТЕГОРИИ ============

P11FW.Categories = {
    { id = "science",   name = "УЧЁНЫЕ",         order = 2, color = Color(140, 200, 240) },
    { id = "personnel", name = "ПЕРСОНАЛ",       order = 3, color = Color(205, 180, 110) },
    { id = "vip",       name = "💎 VIP-СЛУЖБА",  order = 3.5, color = Color(235, 205, 100) }, -- v4.8.0
    { id = "misc",      name = "БЕЗ НАЗНАЧЕНИЯ", order = 4, color = Color(170, 170, 170) },
    -- v3.9: встроенный «ВОЕННЫЙ ГАРНИЗОН» УБРАН по заявке владельца.
    -- РККА / НКВД / НЕЧТО приезжают АВТО-СИДОМ (fw_sv_seed_rkka.lua)
    -- как кастомные фракции — с ними тот же порядок F4/ТАБа.
}

-- ============ ДОЛЖНОСТИ ============
--  max     = лимит мест (0 = без лимита)
--  weapons = выдаётся при вступлении/респавне (если класс существует)
--  ammo    = боеприпасы { {класс, кол-во}, ... }
--  models  = варианты внешности (игрок выберет в меню F4)

P11FW.Jobs = {

    recruit = {
        order = 1, category = "misc",
        name = "Новобранец",
        desc = "Ты только сошёл с транспорта на станцию «Полюс-11». Оформись у кадровика или через F4: в РККА — под ружьё, к учёным — в лабораторию, в обслугу — по хозяйству. Без назначения: ни оружия, ни допуска в отсеки.",
        models = {
            "models/player/Group03/male_01.mdl",
            "models/player/Group03/male_02.mdl",
            "models/player/Group03/male_03.mdl",
            "models/player/Group03/female_01.mdl",
            "models/player/Group03/female_02.mdl",
        },
        color = Color(170, 170, 170),
        weapons = {},
        max = 0,
    },

    -- ============ v4.6.2: НАЧАЛЬНИК КОМПЛЕКСА ============
    chief = {
        order = 7, category = "personnel", whitelist = true, -- только с ДОПУСКОМ
        time = 300, -- v4.6.6: 5 часов службы прежде чем вести комплекс
        name = "Начальник Комплекса",
        desc = "Глава станции «Полюс-11». Ему подчиняется ВЕСЬ комплекс: гарнизон РККА держит периметр по его приказу, учёные отчитываются о работах, обслуга — о снабжении. Последнее слово о судьбе станции — за ним. С НКВД он сотрудничает, но не подчиняется.",
        models = {
            "models/player/breen.mdl",
            "models/player/Group03m/male_04.mdl",
            "models/player/Group03m/male_05.mdl",
        },
        color = Color(255, 205, 100), -- станционная медь
        weapons = { "weapon_polus11_radio" },
        max = 1, -- v4.8.2: лимит 1 (заявка владельца: «создатель/глава = одно место»)
    },

    -- ============ v3.9: ОБСЛУЖИВАЮЩИЙ ПЕРСОНАЛ ============
    -- По заявке владельца из встроенных оставлен ТОЛЬКО персонал
    -- (уборщик / снабженец / грузчик / техник / медик / инженер).
    -- Военные РККА, госбезопасность НКВД и учёные — пресетами сида.

    janitor = {
        order = 8, category = "personnel",
        name = "Уборщик",
        desc = "Швабра, совок, ведро с мыльной водой. Ты везде — и тебя нигде не замечают: уборщик слышит разговоры, которые не для чужих ушей. Лом на случай «слипшихся» дверей и открытых вентилей.",
        models = {
            "models/player/Group01/male_01.mdl",
            "models/player/Group01/male_04.mdl",
            "models/player/Group01/female_01.mdl",
            "models/player/Group01/female_04.mdl",
        },
        color = Color(150, 175, 130),
        weapons = { "weapon_crowbar" },
        max = 0,
    },

    cook = {
        order = 9, category = "personnel",
        name = "Снабженец / Повар",
        desc = "Камбуз, склад, выдача снаряжения и талонов на пайки. Знает, где лежит каждая бочка с солярой для генератора. Без снабженца база голодная уже к вечеру.",
        models = {
            "models/player/Group01/male_07.mdl",
            "models/player/Group01/male_09.mdl",
        },
        color = Color(205, 150, 90),
        weapons = { "weapon_polus11_radio", "weapon_polus11_ration" },
        max = 2,
    },

    porter = {
        order = 10, category = "personnel",
        name = "Грузчик",
        desc = "Руки-лопаты и спина из железа. Перетаскивает бочки с соляркой к генераторам (E по бочке — на плечо, от генератора — заправка), волочёт грузы склада. Привык к весу — почти не сбавляет шаг. Пол станции держится на таких.",
        models = {
            "models/player/Group01/male_05.mdl",
            "models/player/Group01/male_06.mdl",
            "models/player/Group01/male_02.mdl",
        },
        color = Color(185, 160, 110),
        weapons = { "weapon_polus11_radio" },
        max = 2,
    },

    tech = {
        order = 11, category = "personnel", time = 30, -- v4.6.6
        name = "Техник-механик",
        desc = "Дежурный по машинному отделению. Его смена — генераторы: техосмотры (снимают износ), поломки (перегрев, утечки, стартер), переключение режимов ОСНОВНОЙ/РЕЗЕРВ. Работает на генераторе вдвое быстрее остальных.",
        models = {
            "models/player/barney.mdl",
            "models/player/Group01/male_03.mdl",
        },
        color = Color(120, 190, 235),
        weapons = { "weapon_polus11_radio" },
        max = 2,
    },

    medic = {
        order = 12, category = "personnel", time = 30, -- v4.6.6
        name = "Полевой медик",
        desc = "Санитар станции. Главное — ПОЛЕВОЙ МЕДКЕЙС: латает раненых лицом к лицу (ЛКМ +12, ПКМ — себя). Латать после стычек с Нечто — его хлеб и его крест. v4.8.8: шприц больше не его — тест крови делает только «Учёный».",
        models = {
            "models/player/Group03m/male_01.mdl",
            "models/player/Group03m/male_02.mdl",
            "models/player/Group03m/male_03.mdl",
        },
        color = Color(150, 230, 190),
        weapons = { "weapon_polus11_medkit", "weapon_polus11_radio" }, -- v4.8.8 «ЛИЧИНА»: медикам ванильный медкейс (шприц — только «Учёному»)
        max = 2,
    },

    engineer = {
        order = 13, category = "personnel", time = 60, -- v4.6.6
        name = "Инженер-изобретатель",
        desc = "Кустарные огнемёты — его рук дело. Чинит генератор, заправляет струи, следит за проводкой. Против Нечто огонь — единственный аргумент.",
        models = { "models/player/eli.mdl" },
        color = Color(255, 195, 95),
        weapons = { "weapon_polus11_flamethrower", "weapon_polus11_radio" },
        max = 2,
    },

    -- ============ v4.8.0: VIP-СЛУЖБА (доступ с ранга VIP) ============
    -- Флаг vip = true: берут только игроки с рангом VIP и старшим
    -- (P11FW.IsVIP в fw_sh_ranks). Оружие — списки КАНДИДАТОВ:
    -- первый класс из пака EFT ARC9, иначе стоковый аналог.

    vip_stalker = {
        order = 20, category = "vip", vip = true,
        name = "VIP · Следопыт-охотник",
        desc = "Погонщик твари. Знает лазы станции лучше вентиляции: читает следы, ведёт засады, первым идёт на крик в метели. Самозарядный карабин MP-153 в обрезанном ложе — билет в один конец для Нечто. Особая привилегия за поддержку станции.",
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_02.mdl",
            "models/player/Group01/male_03.mdl",
        },
        color = Color(235, 205, 100),
        weapons = {
            { "arc9_eft_mp153", "arc9_eft_mr43", "weapon_shotgun" },
            { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" },
            "weapon_polus11_radio",
        },
        hp = 110, armor = 60,
        max = 2,
    },

    vip_veteran = {
        order = 21, category = "vip", vip = true,
        name = "VIP · Ветеран Арктики",
        desc = "Прожжённый полярник с тремя зимовками за спиной. Мороз для него — дом родной, буря — погодка. Полноразмерный АКС-74, укреплённый бронежилет и право первого выстрела по любой тени без формы. Особая привилегия за поддержку станции.",
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_03.mdl",
            "models/player/Group01/male_05.mdl",
        },
        color = Color(240, 210, 110),
        weapons = {
            { "arc9_eft_aks74", "arc9_eft_ak74", "weapon_ar2" },
            { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" },
            "weapon_polus11_radio",
        },
        hp = 120, armor = 110,
        max = 2,
    },

    vip_voenvrach = {
        order = 22, category = "vip", vip = true,
        name = "VIP · Военврач",
        desc = "Хирург полевого госпиталя при полной выкладке. Шприц лечит раненых (+12 ХП), тест крови берёт как лаборант, а ПМ в кобуре напоминает, что спорить с ним о диагнозе — вредно. Особая привилегия за поддержку станции.",
        models = {
            "Models/UIF/scientists/UIF_scientist_8.mdl",
            "models/player/Group03m/male_01.mdl",
        },
        color = Color(225, 220, 160),
        weapons = {
            "weapon_polus11_syringe",
            { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" },
            "weapon_polus11_radio",
        },
        hp = 110, armor = 70,
        max = 2,
    },
}

-- ============ РЕГИСТРАЦИЯ КОМАНД (team) ============
-- Реальные GMod-команды: цвет в табе/неймтагах, team.GetName и т.д.

local TEAM_BASE = 100 -- индексы 100+, чтобы не задеть чужие

P11FW.JobIds = {}
for id, job in pairs(P11FW.Jobs) do
    P11FW.JobIds[#P11FW.JobIds + 1] = id
end
table.sort(P11FW.JobIds, function(a, b)
    return (P11FW.Jobs[a].order or 99) < (P11FW.Jobs[b].order or 99)
end)

P11FW.JobTeams = {} -- jobId -> team index
P11FW.TeamJobs = {} -- team index -> jobId

for i, id in ipairs(P11FW.JobIds) do
    local t = TEAM_BASE + i - 1
    P11FW.JobTeams[id] = t
    P11FW.TeamJobs[t] = id
    team.SetUp(t, P11FW.Jobs[id].name, P11FW.Jobs[id].color or Color(200, 200, 200), true)
end

-- категории отсортированные (для меню)
P11FW.CategoryList = table.Copy(P11FW.Categories)
table.sort(P11FW.CategoryList, function(a, b) return (a.order or 99) < (b.order or 99) end)

-- ============ ХЕЛПЕРЫ (shared) ============

function P11FW.GetJobId(ply)
    if not IsValid(ply) then return P11FW.Config.DefaultJob end
    return P11FW.TeamJobs[ply:Team()] or P11FW.Config.DefaultJob
end

function P11FW.GetJob(ply)
    return P11FW.Jobs[P11FW.GetJobId(ply)]
end

function P11FW.GetJobName(ply)
    local job = P11FW.GetJob(ply)
    return job and job.name or ""
end

-- сколько человек уже на должности
function P11FW.TeamCount(jobId, except)
    local t = P11FW.JobTeams[jobId]
    if not t then return 0 end
    local n = 0
    for _, p in ipairs(player.GetAll()) do
        if p ~= except and p:Team() == t then n = n + 1 end
    end
    return n
end

function P11FW.JobFull(jobId, except)
    local job = P11FW.Jobs[jobId]
    if not job then return true end
    if (job.max or 0) <= 0 then return false end
    return P11FW.TeamCount(jobId, except) >= job.max
end

-- v3.9 КРИТ-ФИКС «модельки не выдаются»: список НЕ режем по наличию файла.
-- Серверу модель не нужна физически: SetModel идёт строкой, а рендерит её
-- КЛИЕНТ (у кого воркшоп-пак стоит — тот и видит). Старая проверка file.Exists
-- сбрасывала ВСЕХ в male_01, если пака не было на сервере.
-- Фолбэк нужен только когда у должности ВООБЩЕ нет списка моделей.
function P11FW.ValidModels(job)
    local list = job.models or {}
    if #list == 0 then
        return { "models/player/Group01/male_01.mdl" }
    end
    return list
end

-- v4.8.0: выдать только РЕАЛЬНО существующие классы.
-- Запись может быть строкой ИЛИ списком кандидатов (арсенал EFT ARC9
-- + стоковые фолбэки — см. modules/p11_sh_weapons.lua). Дубли режем.
function P11FW.ValidWeapons(job)
    local ok, seen = {}, {}
    for _, entry in ipairs(job.weapons or {}) do
        local cls = nil
        if POLUS11 and POLUS11.ResolveWeaponClass then
            cls = POLUS11.ResolveWeaponClass(entry)
        elseif isstring(entry) and weapons.Get(entry) then
            cls = entry
        end
        if cls and not seen[cls] then
            seen[cls] = true
            ok[#ok + 1] = cls
        end
    end
    return ok
end

-- ============ КАСТОМНЫЕ ДОЛЖНОСТИ (созданные в игре админом) ============
-- Регистрируются из data-файла (сервер) или net-синка (клиент).
-- records = { {id, team, name, category, desc, color={r,g,b}, max, models, weapons, order}, ... }

function P11FW.RegisterCustomJobs(records)
    records = istable(records) and records or {}
    P11FW.BaseJobs = P11FW.BaseJobs or {} -- заводские копии для отката правок (v3.8.1)

    -- снести прежние кастомные
    for id, job in pairs(P11FW.Jobs) do
        if job.custom then
            local t = P11FW.JobTeams[id]
            if t then P11FW.TeamJobs[t] = nil end
            P11FW.JobTeams[id] = nil
            P11FW.Jobs[id] = nil
        end
    end

    -- v3.8.1: откат встроенных, чью ПРАВКУ убрали из records
    for id, job in pairs(P11FW.Jobs) do
        if job.overridden and not job.custom then
            local still = false
            for _, rec in ipairs(records) do
                if rec.override and rec.id == id then still = true break end
            end
            if not still and P11FW.BaseJobs[id] then
                P11FW.Jobs[id] = table.Copy(P11FW.BaseJobs[id])
                P11FW.BaseJobs[id] = nil
                local t = P11FW.JobTeams[id]
                if t then team.SetUp(t, P11FW.Jobs[id].name, P11FW.Jobs[id].color, true) end
            end
        end
    end

    for _, rec in ipairs(records) do
        if istable(rec) and isstring(rec.id) and isnumber(rec.team) and isstring(rec.name) then
            local c = istable(rec.color) and rec.color or {}

            -- v3.8.1: ПРАВКА ВСТРОЕННОЙ должности (переопределение вместо новой)
            if rec.override and P11FW.Jobs[rec.id] and not P11FW.Jobs[rec.id].custom then
                if not P11FW.BaseJobs[rec.id] then
                    P11FW.BaseJobs[rec.id] = table.Copy(P11FW.Jobs[rec.id])
                end
                local job = P11FW.Jobs[rec.id]
                job.name       = rec.name
                job.desc       = rec.desc or ""
                job.category   = isstring(rec.category) and rec.category or job.category
                job.models     = istable(rec.models) and rec.models or {}
                job.weapons    = istable(rec.weapons) and rec.weapons or {}
                job.max        = tonumber(rec.max) or 0
                job.terminal   = rec.terminal == true
                job.whitelist  = rec.whitelist == true -- v4.4.0
                job.time       = tonumber(rec.time) or 0 -- v4.5.0: минут игры для входа
                if rec.vip ~= nil then job.vip = rec.vip == true end -- v4.8.0
                job.color      = Color(tonumber(c.r) or 210, tonumber(c.g) or 170, tonumber(c.b) or 120)
                job.overridden = true
                team.SetUp(rec.team, job.name, job.color, true)
            elseif not rec.override then
            P11FW.Jobs[rec.id] = {
                custom   = true,
                terminal = rec.terminal == true,
                whitelist = rec.whitelist == true, -- v4.4.0: ВАЙТЛИСТ-галочка
                order    = tonumber(rec.order) or 100,
                category = isstring(rec.category) and rec.category or "misc",
                name     = rec.name,
                desc     = rec.desc or "",
                models   = istable(rec.models) and rec.models or {},
                weapons  = istable(rec.weapons) and rec.weapons or {},
                max      = tonumber(rec.max) or 0,
                color    = Color(tonumber(c.r) or 210, tonumber(c.g) or 170, tonumber(c.b) or 120),
                -- v3.8.2: характеристики, ивент-роль, командные полномочия (сид РККА)
                hp       = tonumber(rec.hp) or 100,
                armor    = tonumber(rec.armor) or 0,
                event    = rec.event == true,
                command  = rec.command == true,
                time     = tonumber(rec.time) or 0, -- v4.5.0: минут игры для входа
                vip      = rec.vip == true, -- v4.8.0: VIP-должность
            }
            P11FW.JobTeams[rec.id] = rec.team
            P11FW.TeamJobs[rec.team] = rec.id
            team.SetUp(rec.team, rec.name, P11FW.Jobs[rec.id].color, true)
            end
        end
    end

    -- пересобрать отсортированный список
    P11FW.JobIds = {}
    for id in pairs(P11FW.Jobs) do
        P11FW.JobIds[#P11FW.JobIds + 1] = id
    end
    table.sort(P11FW.JobIds, function(a, b)
        return (P11FW.Jobs[a].order or 99) < (P11FW.Jobs[b].order or 99)
    end)
end
