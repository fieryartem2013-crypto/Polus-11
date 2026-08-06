-- ============================================================
--  ПОЛЮС FRAMEWORK — АВТО-СИД ПРЕСЕТНЫХ ФРАКЦИЙ/ДОЛЖНОСТЕЙ (server) v3.8.4
--  Завозит готовый штат «чтобы было хоть что-то на альфа-тесте»:
--   • фракция РККА — 8 должностей по списку владельца сервера
--     (оружие ARC9/DOI, модели hts/comradebear: pm0v3);
--   • фракция НКВД — 5 должностей v3.8.3 (особый отдел: охота
--     на Нечто = «шпион, который притворяется человеком»);
--   • научный блок — 6 должностей (модели UIF scientists);
--   • фракция НЕЧТО — 4 ИВЕНТОВЫЕ формы (выдаёт ТОЛЬКО администрация,
--     в F4 для обычных игроков кнопка «взять» ответит отказом).
--  Пресеты — обычные КАСТОМНЫЕ должности: правятся/сносятся из
--  админ-меню (F4 → Админ → Профы), переживают рестарт. Повторный
--  запуск сервера дубликатов не создаёт (проверка по id), а новые
--  пресеты (как НКВД) доедут при любом рестарте.
--  Отключение: P11FW.Config.SeedRkkaPresets = false (fw_sh_config.lua).
--  Редактирование пресетов — таблицы ниже; после правки удали
--  data/polus_framework/jobs_custom.json, чтобы сид прошёл заново.
-- ============================================================

if not P11FW then return end

-- ============ ДАННЫЕ ПРЕСЕТОВ ============
-- Модели/оружие могут отсутствовать на сервере (нет воркшоп-паков):
-- система сама заменит модель на стоковую, а несуществующее оружие
-- просто не выдаст — сервер не упадёт, профы останутся и «оживут»,
-- как только паки доустановишь (воркшоп-id впиши в WorkshopAddons).

local SEED_FACTIONS = {
    {
        id = "rkka", name = "РККА", order = 5,
        desc = "Гарнизон станции от Рабоче-Крестьянской Красной Армии: от новобранца до генерала. Держит периметр, посты и дисциплину.",
        color = Color(175, 165, 95),
    },
    {
        id = "nkvd", name = "НКВД", order = 6,
        desc = "Народный комиссариат внутренних дел. Особый отдел станции: госбезопасность, допросы, контрразведка — охота на того, кто притворяется человеком.",
        color = Color(120, 20, 24), -- v4.5.0: КРАСНО-ЧЁРНОЕ НКВД (по заявке владельца)
    },
    {
        id = "nechto", name = "НЕЧТО", order = 99,
        desc = "Ивентовые формы Нечто. ВЫДАЮТСЯ ТОЛЬКО АДМИНИСТРАЦИЕЙ. Если ты это читаешь — штаб знает о твоей находке слишком много.",
        color = Color(150, 55, 60),
    },
}

-- ХП/броня берутся из полей hp/armor; всем авто-выдаются «руки».
local SEED_JOBS = {
    -- ================= ФРАКЦИЯ РККА =================
    {
        id = "seed_rkka_novobranets", time = 0, -- v4.6.6: минуты для доступа category = "rkka", order = 30,
        name = "Новобранец РККА",
        desc = "Свежеприбывшее пополнение. Оружия не положено — держись постовых, слушай комиссара и не выходи в метель без приказа.",
        weapons = {}, hp = 100, armor = 0, max = 0,
        color = Color(160, 160, 120),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
        },
    },
    {
        id = "seed_rkka_postovoy", time = 30, -- v4.6.6: минуты для доступа category = "rkka", order = 31,
        name = "Постовой РККА",
        desc = "Стоит на посту: ворота, караулка, склад. АКС-74У — короткий и злой, для коридоров станции самое то. 100 ХП / 100 брони.",
        weapons = { "arc9_eft_aks74u" }, hp = 100, armor = 100, max = 4,
        color = Color(175, 165, 95),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_06.mdl",
        },
    },
    {
        id = "seed_rkka_soldat", time = 45, -- v4.6.6: минуты для доступа category = "rkka", order = 32,
        name = "Солдат РККА",
        desc = "Основной боец гарнизона. Полноразмерный АК-74, патрули и сопровождение учёных. 105 ХП / 105 брони.",
        weapons = { "arc9_eft_aks74" }, hp = 105, armor = 105, max = 6,
        color = Color(185, 170, 90),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_06.mdl",
        },
    },
    {
        id = "seed_rkka_shturmovik", time = 90, -- v4.6.6: минуты для доступа category = "rkka", order = 33,
        name = "Штурмовик РККА",
        desc = "Первым вламывается в заражённые отсеки. ППШ-41 косит всё в упор, тяжёлый бронежилет. 125 ХП / 145 брони.",
        weapons = { "arc9_eft_ppsh41" }, hp = 125, armor = 145, max = 3,
        color = Color(200, 160, 80),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_06.mdl",
        },
    },
    {
        id = "seed_rkka_razvedchik", time = 60, -- v4.6.6: минуты для доступа category = "rkka", order = 34,
        name = "Разведчик РККА",
        desc = "Уходит в белую пустыню первым. Трёхлинейка бьёт точно и далеко — Нечто не любит одиночных выстрелов с вышки. 125 ХП / 115 брони. Штрафная рота — туда лучше не попадать.",
        weapons = { "arc9_eft_mosin_infantry" }, hp = 125, armor = 115, max = 3,
        color = Color(165, 145, 85),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_06.mdl",
        },
    },
    {
        id = "seed_rkka_komissar", time = 240, -- v4.6.6: минуты для доступа category = "rkka", order = 35,
        name = "Комиссар РККА",
        desc = "Политрук гарнизона. Дисциплина, допросы, трибунал. Kar98 — за спиной, ордер на расстрел дезертиров — в кармане. Одно место. 100 ХП / 100 брони.",
        weapons = { "arc9_doi_k98" }, hp = 100, armor = 100, max = 2, terminal = true, -- v4.6.6: лимит 2
        color = Color(160, 90, 85),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_rkka_general", time = 300, -- v4.6.6: минуты для доступа category = "rkka", order = 36,
        name = "Генерал РККА",
        desc = "Командующий всем военным контингентом станции из генеральского штаба. Kar98 и полная власть. Одно место. 125 ХП / 125 брони.",
        weapons = { "arc9_doi_k98" }, hp = 125, armor = 125, max = 2, terminal = true, command = true, -- v4.6.6: лимит 2,
        color = Color(210, 185, 90),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/general_staff/gen/m40_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_rkka_generalpeh", time = 300, -- v4.6.6: минуты для доступа category = "rkka", order = 37,
        name = "Генерал РККА (Пехота)",
        desc = "Комбат пехотного звена: ближе к окопам, чем к штабу. Двустволка MR-43 для личной самообороны. Одно место. 100 ХП / 100 брони.",
        weapons = { "arc9_eft_mr43" }, hp = 100, armor = 100, max = 2, terminal = true, -- v4.6.6: лимит 2
        color = Color(195, 175, 85),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/gen/m40_1941_s1_02.mdl",
        },
    },

    -- ================= ФРАКЦИЯ НКВД (v3.8.3) =================
    -- Модели: пока стоят комиссарские/штабные из пака pm0v3 — если найдёшь
    -- пак с «синими фуражками», смени пути тут или прямо в админке.
    {
        id = "seed_nkvd_convoy", time = 45, -- v4.6.6: минуты для доступа category = "nkvd", order = 50, whitelist = true, -- v4.4.0: ВАЙТЛИСТ
        name = "Конвоир НКВД",
        desc = "Конвой и караул задержанных, охрана допросной и склада вещдоков. Двустволка MR-43 — уговаривать долго не приходится. 100 ХП / 100 брони.",
        weapons = { "arc9_eft_mr43" }, hp = 100, armor = 100, max = 2,
        color = Color(105, 22, 26), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_04.mdl",
        },
    },
    {
        id = "seed_nkvd_oper", time = 90, -- v4.6.6: минуты для доступа category = "nkvd", order = 51, whitelist = true, -- v4.4.0: ВАЙТЛИСТ
        name = "Оперуполномоченный НКВД",
        desc = "Оперативная работа: наружное наблюдение, агентурная сеть, тихие допросы «для протокола». АКС-74У под полой шинели. 100 ХП / 100 брони.",
        weapons = { "arc9_eft_aks74u" }, hp = 100, armor = 100, max = 3,
        color = Color(122, 25, 30), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_nkvd_sledovatel", time = 120, -- v4.6.6: минуты для доступа category = "nkvd", order = 52, whitelist = true, -- v4.4.0: ВАЙТЛИСТ
        name = "Следователь НКВД",
        desc = "Протоколы, вещдоки, досье на каждого жителя станции. Имеет право требовать принудительный тест крови ПОД СВОИМ НАДЗОРОМ — шприц в сейфе следопера. 100 ХП / 50 брони.",
        weapons = { "weapon_polus11_syringe", "arc9_doi_k98" }, hp = 100, armor = 50, max = 2, terminal = true,
        color = Color(138, 28, 32), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_nkvd_osobist", time = 180, -- v4.6.6: минуты для доступа category = "nkvd", order = 53, whitelist = true, -- v4.4.0: ВАЙТЛИСТ
        name = "Особист НКВД",
        desc = "Контрразведка станции. Может объявлять РОЗЫСК (!розыск) и отдавать ПРИКАЗЫ (!приказ) без санкции генерала, если подозревает Нечто. Одно место. 115 ХП / 100 брони.",
        weapons = { "arc9_doi_k98" }, hp = 115, armor = 100, max = 2, terminal = true, command = true, -- v4.6.6: лимит 2,
        color = Color(154, 30, 30), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
        },
    },
    {
        id = "seed_nkvd_nachalnik", time = 240, -- v4.6.6: минуты для доступа category = "nkvd", order = 54, whitelist = true, -- v4.4.0: ВАЙТЛИСТ
        name = "Начальник Особого Отдела НКВД",
        desc = "Высшее слово станции по вопросам внутренней безопасности. Его подпись в ордере на расстрел равна приговору Военного трибунала. Одно место. 125 ХП / 125 брони.",
        weapons = { "arc9_doi_k98" }, hp = 125, armor = 125, max = 2, terminal = true, command = true, -- v4.6.6: лимит 2,
        color = Color(170, 34, 34), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/general_staff/gen/m40_1941_s1_05.mdl",
        },
    },

    -- ================= НАУЧНЫЙ БЛОК =================
    {
        id = "seed_sci_laborant", time = 0, -- v4.6.6: минуты для доступа category = "science", order = 40,
        name = "Лаборант (ЦНИИ)",
        desc = "Младший научный состав исследовательского блока. Мытьё пробирок, подносы, журналы опытов. 100 ХП / 100 брони.",
        weapons = {}, hp = 100, armor = 100, max = 4,
        color = Color(165, 205, 250),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_ucheniy", time = 30, -- v4.6.6: минуты для доступа category = "science", order = 41,
        name = "Учёный",
        desc = "Штатный исследователь комплекса. Доступ к образцам и лабораторным стендам. 100 ХП / 100 брони.",
        weapons = {}, hp = 100, armor = 100, max = 3,
        color = Color(170, 210, 255),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_biohim", time = 60, -- v4.6.6: минуты для доступа category = "science", order = 42,
        name = "Био-химик",
        desc = "Специалист по биохимическому анализу тканей. К его холодильнику с образцами лучше не подходить без перчаток. 100 ХП / 100 брони.",
        weapons = {}, hp = 100, armor = 100, max = 2,
        color = Color(145, 225, 210),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_vedushiy", time = 90, -- v4.6.6: минуты для доступа category = "science", order = 43,
        name = "Ведущий Учёный",
        desc = "Руководит экспериментами лично. Подписывает заключения по биологическим угрозам. 100 ХП / 100 брони.",
        weapons = {}, hp = 100, armor = 100, max = 2, terminal = true,
        color = Color(130, 200, 245),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_menedzher", time = 120, -- v4.6.6: минуты для доступа category = "science", order = 44,
        name = "Менеджер Научного Отдела",
        desc = "Отвечает за сметы, графики и допуски научного блока. Знает, кого и за что пускают в лаборатории. Одно место. 100 ХП / 100 брони.",
        weapons = {}, hp = 100, armor = 100, max = 2, terminal = true, -- v4.6.6: лимит 2
        color = Color(120, 190, 240),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_sozdatel", time = 180, -- v4.6.6: минуты для доступа category = "science", order = 45,
        name = "Создатель Научного Комплекса",
        desc = "Легенда «Полюс-11»: главный конструктор научного блока. Имеет допуск во ВСЕ отсеки, включая те, о которых нет в документах. Одно место. 100 ХП / 100 брони.",
        weapons = {}, hp = 100, armor = 100, max = 2, terminal = true, command = true, -- v4.6.6: лимит 2,
        color = Color(105, 180, 235),
        models = { "Models/UIF/scientists/UIF_scientist_8.mdl" },
    },

    -- ================= НЕЧТО (ИВЕНТ, только для админов) =================
    -- v4.2: ОДНА профессия. Форма меняется командой !форма (имитатор/
    -- поглотитель/разделённый/споровик), за жертв копятся МУТАЦИИ:
    -- 3 — Регенерация, 5 — Мясогигант, 10 — Арахна (паучья форма).
    {
        id = "seed_thing_filial", time = 0, -- v4.6.6: минуты для доступа category = "nechto", order = 90,
        name = "[ИВЕНТ] Нечто",
        desc = "Личинка-хамелеон, крадущая тела и лица. !форма — смена формы; мутации за жертв (3/5/10). Только для админ-ивентов. 400 ХП.",
        weapons = { "weapon_polus11_thing" }, hp = 400, armor = 0, max = 2, event = true,
        color = Color(150, 55, 60),
        models = { "models/player/corpse1.mdl" },
    },
}

-- ============ МЕХАНИКА СИДА ============

local TEAM_SEED_BASE = 200 -- как TEAM_CUSTOM_BASE в fw_sv_customjobs

-- свободный team-индекс с учётом уже занятых кастомными профами
local function NextFreeTeamForSeed()
    for t = TEAM_SEED_BASE, TEAM_SEED_BASE + 95 do
        if not P11FW.TeamJobs[t] then
            local used = false
            for _, rec in ipairs(P11FW.CustomJobs or {}) do
                if rec.team == t then used = true break end
            end
            if not used then return t end
        end
    end
    return nil
end

local function HasCustomJob(id)
    for _, rec in ipairs(P11FW.CustomJobs or {}) do
        if rec.id == id then return true end
    end
    return false
end

-- сериализация текущего набора фракций (формат fw_sv_factions/FactionsToRecords)
local function FactionRecordsNow()
    local out = {}
    for id, cat in pairs(P11FW.CustomFactions or {}) do
        out[#out + 1] = {
            id = id, name = cat.name, desc = cat.desc or "",
            order = cat.order or 50,
            override = (cat.override == true) or (cat.overridden == true),
            color = { r = cat.color.r, g = cat.color.g, b = cat.color.b },
        }
    end
    return out
end

local function SaveFactionRecords(records)
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    file.Write("polus_framework/factions.json", util.TableToJSON(records, true))
end

-- v4.2: устаревшие сид-айдишники (старые формы Нечто) — зачистка,
-- чтобы в штате осталась ОДНА профессия Нечто.
local LEGACY_IDS = { seed_thing_split = true, seed_thing_brute = true, seed_thing_spore = true }

local function SeedAll()
    if P11FW.Config.SeedRkkaPresets == false then return end

    -- ---------- 0) ЗАЧИСТКА УСТАРЕВШИХ ----------
    do
        local removed = 0
        for i = #P11FW.CustomJobs, 1, -1 do
            local rec = P11FW.CustomJobs[i]
            if rec and LEGACY_IDS[rec.id] then
                table.remove(P11FW.CustomJobs, i)
                removed = removed + 1
            end
        end
        if removed > 0 then
            P11FW.SaveCustomJobs()
            P11FW.Log("Сид: зачищено устаревших форм Нечто: " .. removed ..
                " (теперь одна профессия — формы через !форма + мутации)")
        end
    end

    -- ---------- 0.5) v4.4.0 МИГРАЦИЯ: ВАЙТЛИСТ всему НКВД ----------
    -- На серверах, где НКВД завезено раньше, в сейве нет поля whitelist —
    -- включаем принудительно и пересохраняем (один раз, потом поле уже есть).
    do
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs) do
            if rec and rec.category == "nkvd" and rec.whitelist == nil then
                rec.whitelist = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.4.0: ВАЙТЛИСТ 🔒 включён всем должностям НКВД (миграция)")
        end
    end

    -- ---------- 0.6) v4.5.0 МИГРАЦИЯ: красно-чёрное НКВД ----------
    -- На старых сейвах НКВД сидит с СИНИМИ цветами — перекрашиваем
    -- ровно preset-профы (кастомные правки админа не трогаем без флага).
    do
        local NKVD_V45 = {
            seed_nkvd_convoy     = { 105, 22, 26 },
            seed_nkvd_oper       = { 122, 25, 30 },
            seed_nkvd_sledovatel = { 138, 28, 32 },
            seed_nkvd_osobist    = { 154, 30, 30 },
            seed_nkvd_nachalnik  = { 170, 34, 34 },
        }
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs) do
            local ncol = rec and NKVD_V45[rec.id]
            if ncol and not rec.nkvdRedV45 then
                rec.color = { r = ncol[1], g = ncol[2], b = ncol[3] }
                rec.nkvdRedV45 = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.5.0: НКВД перекрашено в КРАСНО-ЧЁРНОЕ (миграция)")
        end

        -- и саму фракцию: старый синий (b > r) → тёмно-красный
        local facs = FactionRecordsNow()
        local fchanged = false
        for _, fr in ipairs(facs) do
            if fr.id == "nkvd" and istable(fr.color) and (fr.color.b or 0) > (fr.color.r or 0) then
                fr.color = { r = 120, g = 20, b = 24 }
                fchanged = true
            end
        end
        if fchanged then
            P11FW.RegisterCustomFactions(facs)
            SaveFactionRecords(facs)
            P11FW.SyncFactions()
            P11FW.Log("Сид v4.5.0: фракция НКВД перекрашена в красно-чёрный")
        end
    end

    -- ---------- 0.7) v4.6.6 МИГРАЦИЯ: время открывает профы + лимит 2 ----------
    do
        local byId = {}
        for _, j in ipairs(SEED_JOBS) do byId[j.id] = j end
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs) do
            local def = rec and byId[rec.id]
            if def then
                if rec.time == nil then
                    rec.time = tonumber(def.time) or 0
                    changed = true
                end
                if (tonumber(rec.max) or 0) == 1 and (tonumber(def.max) or 0) >= 2 then
                    rec.max = def.max
                    changed = true
                end
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.6.6: минуты доступа проставлены, лимитки 1 -> 2 (миграция)")
        end
    end

    -- ---------- 1) ФРАКЦИИ ----------
    local records = FactionRecordsNow()
    local facAdded = 0
    for _, f in ipairs(SEED_FACTIONS) do
        local exists = false
        if P11FW.GetCategory and P11FW.GetCategory(f.id) then
            -- GetCategory отдаёт misc-фолбэк на неизвестные id — проверяем точное совпадение
            local cat = P11FW.GetCategory(f.id)
            if cat and cat.id == f.id then exists = true end
        end
        if not exists then
            records[#records + 1] = {
                id = f.id, name = f.name, desc = f.desc,
                order = f.order or 50, override = false,
                color = { r = f.color.r, g = f.color.g, b = f.color.b },
            }
            facAdded = facAdded + 1
        end
    end
    if facAdded > 0 then
        P11FW.RegisterCustomFactions(records)
        SaveFactionRecords(records)
        P11FW.SyncFactions()
        P11FW.Log("Сид: добавлено фракций-пресетов: " .. facAdded)
    end

    -- ---------- 2) ДОЛЖНОСТИ ----------
    local jobAdded = 0
    for _, j in ipairs(SEED_JOBS) do
        if not HasCustomJob(j.id) then
            local t = NextFreeTeamForSeed()
            if not t then
                P11FW.Log("Сид: лимит слотов кастомных должностей исчерпан, пропускаю " .. j.id)
                break
            end
            P11FW.CustomJobs[#P11FW.CustomJobs + 1] = {
                id       = j.id,
                team     = t,
                name     = j.name,
                category = j.category,
                desc     = j.desc or "",
                terminal = j.terminal == true,
                max      = tonumber(j.max) or 0,
                color    = { r = j.color.r, g = j.color.g, b = j.color.b },
                models   = j.models or {},
                weapons  = j.weapons or {},
                hp       = tonumber(j.hp) or 100,
                armor    = tonumber(j.armor) or 0,
                event    = j.event == true,
                command  = j.command == true, -- !приказ/!розыск для генералов
                whitelist = j.whitelist == true, -- v4.4.0: ВАЙТЛИСТ (напр. всё НКВД)
                time     = tonumber(j.time) or 0,  -- v4.6.6: минуты игры для доступа
                order    = j.order or 100,
            }
            jobAdded = jobAdded + 1
        end
    end
    if jobAdded > 0 then
        P11FW.SaveCustomJobs()
        P11FW.RegisterCustomJobs(P11FW.CustomJobs)
        P11FW.SyncCustomJobs()
        P11FW.Log("Сид: завезено должностей-пресетов: " .. jobAdded ..
            " (РККА / Наука / Нечто — сменить: F4 → Админ)")
    end
end

-- ждём, пока fw_sv_factions/fw_sv_customjobs поднимут свои сейвы
hook.Add("InitPostEntity", "P11FW.SeedRkka", function()
    timer.Simple(2.0, SeedAll)
end)
