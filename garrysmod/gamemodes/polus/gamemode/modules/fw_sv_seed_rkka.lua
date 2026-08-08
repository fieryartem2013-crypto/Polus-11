-- ============================================================
--  ПОЛЮС FRAMEWORK — АВТО-СИД ПРЕСЕТНЫХ ФРАКЦИЙ/ДОЛЖНОСТЕЙ (server) v4.8.0
--  Завозит готовый штат «чтобы было хоть что-то на альфа-тесте»:
--   • фракция РККА — 8 должностей по списку владельца сервера
--     (оружие ARC9 EFT v4.8.0 — кандидаты со стоковыми фолбэками,
--     модели hts/comradebear: pm0v3);
--   • фракция НКВД — 5 должностей v3.8.3 (особый отдел: охота
--     на Нечто = «шпион, который притворяется человеком»);
--   • научный блок — 6 должностей (модели UIF scientists);
--   • фракция НЕЧТО — 4 ИВЕНТОВЫЕ формы (выдаёт ТОЛЬКО администрация,
--     в F4 для обычных игроков кнопка «взять» ответит отказом);
--   • ОТРЯД «КРАСНЫЙ ОРЁЛ» — 3 шпионские должности ЦРУ (v4.8.5):
--     кейсы маскировки «ЛЕГАТ» + американское вооружение 1982.
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
        id = "eagle", name = "Отряд «Красный Орёл»", order = 7, -- v4.8.5 «КРАСНЫЙ ОРЁЛ»
        desc = "Диверсионно-разведывательная группа ЦРУ (США), 1982 год: проникла на «Полюс-11» под видом внештатного техперсонала — сбор данных по программе и заметание следов. Кейсы маскировки «ЛЕГАТ», американское оружие тех времён. Допуск — по вайтлисту.",
        color = Color(90, 130, 200), -- резидентская морская волна
    },
    {
        id = "crime", name = "Криминал станции", order = 8, -- v4.17.0 «КОНТРАБАНДА»
        desc = "Подполье «Полюса-11»: контрабанда, скупка краденого, чёрный рынок. Липовая внешность обслуги — кейс «ОБСЛУГА» (маскировка ТОЛЬКО под персонал). Старшие — по вайтлисту, курьер — открытая вакансия.",
        color = Color(150, 90, 170),
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
        id = "seed_rkka_novobranets", time = 0, category = "rkka", order = 30, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Новобранец РККА",
        desc = "Свежеприбывшее пополнение. Оружия не положено — держись постовых, слушай комиссара и не выходи в метель без приказа.",
        weapons = {}, hp = 100, armor = 0, max = 0,
        color = Color(160, 160, 120),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
        },
    },
    {
        id = "seed_rkka_postovoy", time = 30, category = "rkka", order = 31, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Постовой РККА",
        desc = "Стоит на посту: ворота, караулка, склад. АКС-74У — короткий и злой, для коридоров станции самое то. 100 ХП / 100 брони.",
        weapons = { { "arc9_eft_aks74u", "arc9_eft_aks74", "weapon_smg1" }, "weapon_polus11_radio" }, hp = 100, armor = 100, max = 4,
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
        id = "seed_rkka_soldat", time = 45, category = "rkka", order = 32, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Солдат РККА",
        desc = "Основной боец гарнизона. Полноразмерный АК-74, патрули и сопровождение учёных. 105 ХП / 105 брони.",
        weapons = { { "arc9_eft_aks74", "arc9_eft_ak74", "weapon_ar2" }, "weapon_polus11_radio" }, hp = 105, armor = 105, max = 6,
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
        id = "seed_rkka_shturmovik", time = 90, category = "rkka", order = 33, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Штурмовик РККА",
        desc = "Первым вламывается в заражённые отсеки. ППШ-41 косит всё в упор, тяжёлый бронежилет. 125 ХП / 145 брони.",
        weapons = { { "arc9_eft_ppsh41", "weapon_smg1" }, "weapon_polus11_radio" }, hp = 125, armor = 145, max = 3,
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
        -- v4.9.1 «ИГЛА»: НОВАЯ должность — пулемётчик с ручным РПД (заявка владельца)
        -- v4.14.3 «ЗАРЯД»: ствол сменён на arc9_eft_rpd (заявка: «поменяй РПД пулемётчика на этот»)
        id = "seed_rkka_pulemetchik", time = 90, category = "rkka", order = 33,
        name = "Пулемётчик РККА",
        desc = "Огневая точка гарнизона: ручной пулемёт РПД с диском на 75 патронов. Пока РПД говорит — Нечто не подходит. Два места. 130 ХП / 110 брони.",
        weapons = { "arc9_eft_rpd", "weapon_polus11_radio" }, hp = 130, armor = 110, max = 2, -- v4.14.3 «ЗАРЯД»: РПД заменён на ARC9 EFT (заявка владельца)
        color = Color(150, 130, 75),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_06.mdl",
        },
    },
    {
        -- v4.10.0 «ГАРАЖ»: НОВАЯ должность — Лётчик РККА (заявка владельца,
        -- модели из заявки: комбинезон m35jumpsuit + шинель m41coat).
        -- ЕДИНСТВЕННЫЙ штатный допуск в небо: Як-2 в «ПОЛЮС-АВТО» продаётся ему.
        id = "seed_rkka_letchik", time = 90, category = "rkka", order = 34,
        name = "Лётчик РККА",
        desc = "Связное крыло станции: небо, груз, разведка погоды. Только он поднимает самолёт Як-2 — небо доверяют профессионалам. 110 ХП / 60 брони.",
        weapons = { { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" },
        hp = 110, armor = 60, max = 2,
        color = Color(140, 165, 200),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/armored/en/m35jumpsuit_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/armored/co/m41coat_1941_s1_05.mdl",
        },
    },
    {
        -- v4.10.0 «ГАРАЖ»: НОВАЯ должность — Водитель (Персонал),
        -- заявка «Водитель (Пресонал)». Машины берутся у Гараж-мастера
        -- «ПОЛЮС-АВТО»: грузовики/тягач/санитарка; небо — у лётчиков.
        id = "seed_pers_voditel", time = 30, category = "personnel", order = 14,
        name = "Водитель",
        desc = "Колёса станции: колонны снабжения, санитарный разъезд, вывоз больных в бурю. Транспорт покупается в гараже «ПОЛЮС-АВТО» (грузовики, тягач, санитарка). 105 ХП.",
        weapons = { "weapon_polus11_radio", "weapon_crowbar" },
        hp = 105, armor = 0, max = 3,
        color = Color(200, 170, 100),
        models = {
            "models/player/Group01/male_03.mdl",
            "models/player/Group01/male_05.mdl",
            "models/player/Group01/male_06.mdl",
        },
    },
    {
        id = "seed_rkka_razvedchik", time = 60, category = "rkka", order = 34, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Разведчик РККА",
        desc = "Уходит в белую пустыню первым. Трёхлинейка бьёт точно и далеко — Нечто не любит одиночных выстрелов с вышки. 125 ХП / 115 брони. Штрафная рота — туда лучше не попадать.",
        weapons = { { "arc9_eft_mosin_infantry", "arc9_eft_mosin_sniper", "weapon_crossbow" }, "weapon_polus11_radio" }, hp = 125, armor = 115, max = 3,
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
        id = "seed_rkka_medsestra", time = 45, category = "rkka", order = 36, -- v4.9.1 «ИГЛА»: медсёстры подняты ВЫШЕ генералов (были 38/39 под командой); последними идут генералы
        name = "Медсестра РККА",
        desc = "Военная медсестра гарнизона: перевязки, обморожения, латание раненых (полевой медкейс + шприц в снаряге). Ни стыла, ни дрогнула. 90 ХП / 25 брони.",
        weapons = { "weapon_polus11_medkit", "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 90, armor = 25, max = 2,
        color = Color(200, 150, 150),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/medical/en/m35_1941_s1_01f.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/medical/en/m35_1941_s1_02f.mdl",
        },
    },
    {
        id = "seed_rkka_medglav", time = 120, category = "rkka", order = 37, -- v4.9.1 «ИГЛА»: была 39 под генералами — поднята выше в списке
        name = "Главная Медсестра РККА",
        desc = "Старший медик гарнизона: ведёт санчасть и медицинское дело каждого бойца. Доступ к терминалу, медкейс, шприц, рация. Одно место. 95 ХП / 50 брони.",
        weapons = { "weapon_polus11_medkit", "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 95, armor = 50, max = 1, terminal = true,
        color = Color(215, 140, 140),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/medical/nco/m35_1941_s1_04f.mdl",
        },
    },
    {
        id = "seed_rkka_komissar", time = 240, category = "rkka", order = 35, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Комиссар РККА",
        desc = "Политрук гарнизона. Дисциплина, допросы, трибунал. Трёхлинейка — за спиной, ордер на расстрел дезертиров — в кармане. Одно место. 100 ХП / 100 брони.",
        weapons = { { "arc9_eft_mosin_sniper", "arc9_eft_mosin_infantry", "weapon_crossbow" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 100, armor = 100, max = 1, terminal = true, command = true, -- v4.8.2: лимит 1, трибуналу — приказы/розыск
        color = Color(160, 90, 85),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_rkka_general", time = 300, category = "rkka", order = 38, -- v4.9.1 «ИГЛА»: генералы — САМЫЕ ПОСЛЕДНИЕ в блоке РККА (был 36); допуск v4.6.6
        name = "Генерал РККА",
        desc = "Командующий всем военным контингентом станции из генеральского штаба. Трёхлинейка и полная власть. Одно место. 125 ХП / 125 брони.",
        weapons = { { "arc9_eft_mosin_sniper", "arc9_eft_mosin_infantry", "weapon_crossbow" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 125, armor = 125, max = 1, terminal = true, command = true, -- v4.8.2: лимит 1
        color = Color(210, 185, 90),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/general_staff/gen/m40_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_rkka_generalpeh", time = 300, category = "rkka", order = 39, -- v4.9.1 «ИГЛА»: генералы — САМЫЕ ПОСЛЕДНИЕ в блоке РККА (был 37); допуск v4.6.6
        name = "Генерал РККА (Пехота)",
        desc = "Комбат пехотного звена: ближе к окопам, чем к штабу. Двустволка MR-43 для личной самообороны. Одно место. 100 ХП / 100 брони.",
        weapons = { { "arc9_eft_mr43", "weapon_shotgun" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 100, armor = 100, max = 1, terminal = true, -- v4.8.2: лимит 1
        color = Color(195, 175, 85),
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/gen/m40_1941_s1_02.mdl",
        },
    },

    -- Медсёстры РККА перенесены вверх блока (order 36/37), генералы стали последними (38/39) — v4.9.1 «ИГЛА»

    -- ================= ФРАКЦИЯ НКВД (v3.8.3) =================
    -- Модели: пока стоят комиссарские/штабные из пака pm0v3 — если найдёшь
    -- пак с «синими фуражками», смени пути тут или прямо в админке.
    {
        id = "seed_nkvd_convoy", time = 45, category = "nkvd", order = 50, whitelist = true, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Конвоир НКВД",
        desc = "Конвой и караул задержанных, охрана допросной и склада вещдоков. Двустволка MR-43 — уговаривать долго не приходится. 100 ХП / 100 брони.",
        weapons = { { "arc9_eft_mr43", "weapon_shotgun" }, "weapon_polus11_radio" }, hp = 100, armor = 100, max = 2,
        color = Color(105, 22, 26), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_04.mdl",
        },
    },
    {
        id = "seed_nkvd_oper", time = 90, category = "nkvd", order = 51, whitelist = true, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Оперуполномоченный НКВД",
        desc = "Оперативная работа: наружное наблюдение, агентурная сеть, тихие допросы «для протокола». АКС-74У под полой шинели. 100 ХП / 100 брони.",
        weapons = { { "arc9_eft_aks74u", "arc9_eft_aks74", "weapon_smg1" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 100, armor = 100, max = 3,
        color = Color(122, 25, 30), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_nkvd_sledovatel", time = 120, category = "nkvd", order = 52, whitelist = true, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Следователь НКВД",
        desc = "Протоколы, вещдоки, досье на каждого жителя станции. Имеет право ТРЕБОВАТЬ принудительный тест крови под своим надзором — забор делает штатный УЧЁНЫЙ по ордеру следователя. Трёхлинейка и ПМ на поясе. 100 ХП / 50 брони.",
        weapons = { { "arc9_eft_mosin_infantry", "arc9_eft_mosin_sniper", "weapon_crossbow" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 100, armor = 50, max = 2, terminal = true, -- v4.8.8: шприц снят (только «Учёный») { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 100, armor = 50, max = 2, terminal = true,
        color = Color(138, 28, 32), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
        },
    },
    {
        id = "seed_nkvd_osobist", time = 180, category = "nkvd", order = 53, whitelist = true, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Особист НКВД",
        desc = "Контрразведка станции. Может объявлять РОЗЫСК (!розыск) и отдавать ПРИКАЗЫ (!приказ) без санкции генерала, если подозревает Нечто. Одно место. 115 ХП / 100 брони.",
        weapons = { { "arc9_eft_aks74u", "arc9_eft_aks74", "weapon_smg1" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 115, armor = 100, max = 1, terminal = true, command = true, -- v4.8.2: лимит 1
        color = Color(154, 30, 30), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
        },
    },
    {
        id = "seed_nkvd_nachalnik", time = 240, category = "nkvd", order = 54, whitelist = true, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Начальник Особого Отдела НКВД",
        desc = "Высшее слово станции по вопросам внутренней безопасности. Его подпись в ордере на расстрел равна приговору Военного трибунала. Одно место. 125 ХП / 125 брони.",
        weapons = { { "arc9_eft_aks74u", "arc9_eft_aks74", "weapon_smg1" }, { "arc9_eft_pm", "arc9_eft_tt33", "weapon_pistol" }, "weapon_polus11_radio" }, hp = 125, armor = 125, max = 1, terminal = true, command = true, -- v4.8.2: лимит 1
        color = Color(170, 34, 34), -- v4.5.0 КРАСНО-ЧЁРНЫЙ,
        models = {
            "models/hts/comradebear/pm0v3/player/rkka/general_staff/gen/m40_1941_s1_05.mdl",
        },
    },

    -- ================= НАУЧНЫЙ БЛОК =================
    {
        id = "seed_sci_laborant", time = 0, category = "science", order = 40, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Лаборант (ЦНИИ)",
        desc = "Младший научный состав исследовательского блока. Мытьё пробирок, подносы, журналы опытов. 100 ХП / 100 брони.",
        weapons = { "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 100, armor = 100, max = 4, -- v4.9.2 «ПРИЁМ»: рация и науке — голосовой эфир для всех фракций
        color = Color(165, 205, 250),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_ucheniy", time = 30, category = "science", order = 41, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Учёный",
        desc = "Штатный исследователь комплекса. Шприц теста крови — рабочий инструмент всей науки; забор и стол «КРОВЬ-2» — его руки. 100 ХП / 100 брони.",
        weapons = { "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 100, armor = 100, max = 3, -- v4.9.2 «ПРИЁМ»: рация и науке — эфир для всех
        color = Color(170, 210, 255),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_biohim", time = 60, category = "science", order = 42, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Био-химик",
        desc = "Специалист по биохимическому анализу тканей. К его холодильнику с образцами лучше не подходить без перчаток. 100 ХП / 100 брони.",
        weapons = { "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 100, armor = 100, max = 2, -- v4.9.2 «ПРИЁМ»: рация и науке
        color = Color(145, 225, 210),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_vedushiy", time = 90, category = "science", order = 43, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Ведущий Учёный",
        desc = "Руководит экспериментами лично. Подписывает заключения по биологическим угрозам. 100 ХП / 100 брони.",
        weapons = { "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 100, armor = 100, max = 2, terminal = true, -- v4.9.2 «ПРИЁМ»: рация и науке
        color = Color(130, 200, 245),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_menedzher", time = 120, category = "science", order = 44, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Менеджер Научного Отдела",
        desc = "Отвечает за сметы, графики и допуски научного блока. Знает, кого и за что пускают в лаборатории. Одно место. 100 ХП / 100 брони.",
        weapons = { "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 100, armor = 100, max = 1, terminal = true, -- v4.9.2 «ПРИЁМ»: рация и науке
        color = Color(120, 190, 240),
        models = { "Models/UIF/scientists/UIF_scientist_7.mdl" },
    },
    {
        id = "seed_sci_sozdatel", time = 180, category = "science", order = 45, -- допуск v4.6.6; v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ были СЪЕДЕНЫ комментарием (профы стояли ОТКРЫТЫ) — восстановлены
        name = "Создатель Научного Комплекса",
        desc = "Легенда «Полюс-11»: главный конструктор научного блока. Имеет допуск во ВСЕ отсеки, включая те, о которых нет в документах. Одно место. 100 ХП / 100 брони.",
        weapons = { "weapon_polus11_syringe", "weapon_polus11_radio" }, hp = 100, armor = 100, max = 1, terminal = true, command = true, -- v4.9.2 «ПРИЁМ»: рация и науке
        color = Color(105, 180, 235),
        models = { "Models/UIF/scientists/UIF_scientist_8.mdl" },
    },

    -- ================= ФРАКЦИЯ ОТРЯД «КРАСНЫЙ ОРЁЛ» (v4.8.5 → v4.8.6) =================
    -- Шпионы ЦРУ с кейсом маскировки «ЛЕГАТ»: облик бойца РККА, липовые
    -- позывной/должность/документ. Оружие — АМЕРИКАНСКОЕ по аналитике 1982
    -- (см. README). v4.8.6: рота УСИЛЕНА (хп/броня), модели usarmy из пака
    -- pm0v3, Velociraptor диверсанту (единственное исключение Центра).
    -- Все В ВАЙТЛИСТЕ, кроме связного (без кейса — открытая вакансия).
    {
        id = "seed_eagle_agent", time = 90, category = "eagle", order = 60, whitelist = true,
        name = "Агент «Красного Орла»",
        desc = "Легат резидентуры: сбор данных, наблюдение, связь. Базовая легенда — солдат армии США по документам обмена. Кейс «ЛЕГАТ» одевает бойцом РККА с липовыми позывным, должностью и документом. MP5A3 под пальто + табельный M1911A1 (v4.16.0). 110 ХП / 50 брони.",
        weapons = { "weapon_polus11_disguise", { "arc9_eft_mp5", "weapon_smg1" }, { "arc9_eft_m1911a1", "weapon_pistol" }, "weapon_polus11_radio" },
        hp = 110, armor = 50, max = 3,
        color = Color(90, 130, 200),
        models = {
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_01.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_06.mdl",
        },
    },
    {
        id = "seed_eagle_saboteur", time = 240, category = "eagle", order = 61, whitelist = true,
        name = "Диверсант «Красного Орла»",
        desc = "Силовое прикрытие резидентуры: взлом, поджоги, тихая ликвидация свидетелей. ИСКЛЮЧЕНИЕ ЦЕНТРА: Velociraptor .300 BLK с интегральным глушителем (при наличии пака, иначе — помпа Rem 870). M1911A1, гранаты, снайперская M700 (v4.16.0). Кейс «ЛЕГАТ» в снаряге. 125 ХП / 100 брони.",
        weapons = { "weapon_polus11_disguise", { "arc9_eft_velociraptor", "arc9_eft_m870", "weapon_shotgun" }, { "arc9_eft_m700", "weapon_crossbow" }, { "arc9_eft_m1911a1", "weapon_pistol" }, "weapon_frag" },
        hp = 125, armor = 100, max = 2,
        color = Color(80, 118, 190),
        models = {
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_06.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_01.mdl",
        },
    },
    {
        id = "seed_eagle_operator", time = 150, category = "eagle", order = 62, whitelist = true,
        name = "Оператор «Красного Орла»",
        desc = "Младший командный состав резидентуры: водитель, радист полевого звена, «решала». Карабин M4 (v4.16.0), помповик Rem 870, M1911A1, кейс «ЛЕГАТ». 110 ХП / 75 брони.",
        weapons = { "weapon_polus11_disguise", { "arc9_eft_m4a1", "weapon_ar2" }, { "arc9_eft_m1911a1", "weapon_pistol" }, { "arc9_eft_m870", "weapon_shotgun" }, "weapon_polus11_radio" },
        hp = 110, armor = 75, max = 2,
        color = Color(100, 142, 210),
        models = {
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_01.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_06.mdl",
        },
    },
    {
        id = "seed_eagle_rezident", time = 360, category = "eagle", order = 63, whitelist = true,
        name = "Резидент «Красного Орла»",
        desc = "Глава резидентуры. Отдаёт волю агентам, выносит итоговые решения Центра. SA-58 OSW и Colt Python .357 — личная пара (v4.16.0), кейс «ЛЕГАТ» и рация. Одно место. 110 ХП / 75 брони.",
        weapons = { "weapon_polus11_disguise", { "arc9_eft_sa58", "arc9_eft_m1a", "weapon_ar2" }, "weapon_357", "weapon_polus11_radio" },
        hp = 110, armor = 75, max = 1,
        color = Color(120, 155, 225),
        models = {
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/co/m41_s1_06.mdl",
        },
    },
    {
        id = "seed_eagle_komandir", time = 480, category = "eagle", order = 64, whitelist = true,
        name = "Командир Отряда «Красный Орёл»",
        desc = "Старший состав ЦРУ: полевое командование всей резидентурой в Арктике. M1A SOCOM (v4.16.0), Python .357, кейс «ЛЕГАТ», рация. Одно место. 130 ХП / 100 брони.",
        weapons = { "weapon_polus11_disguise", { "arc9_eft_m1a", "arc9_eft_m4a1", "weapon_ar2" }, "weapon_357", "weapon_polus11_radio" },
        hp = 130, armor = 100, max = 1,
        color = Color(105, 140, 215),
        models = {
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/nco/m41_s1_01.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/nco/m41_s1_02.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/nco/m41_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/nco/m41_s1_05.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/nco/m41_s1_06.mdl",
        },
    },
    {
        id = "seed_eagle_svyaznoi", time = 0, category = "eagle", order = 59, -- БЕЗ вайтлиста, БЕЗ кейса: заявка владельца «одна профа без кейса и без вайтлиста»
        name = "Связной «Красного Орла»",
        desc = "Единственная ОТКРЫТАЯ вакансия отряда: радист-шифровальщик под негласной легендой тыловика. Кейса нет — работает прямым текстом, без маскировки. UMP-45 и M1911A1 (v4.16.0), рация с прослушкой эфира станции. 100 ХП / 25 брони.",
        weapons = { { "arc9_eft_ump45", "arc9_eft_ump", "weapon_smg1" }, { "arc9_eft_m1911a1", "weapon_pistol" }, "weapon_polus11_radio" },
        hp = 100, armor = 25, max = 2,
        color = Color(140, 165, 215),
        models = {
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_04.mdl",
            "models/hts/comradebear/pm0v3/player/usarmy/infantry/en/m41_s1_05.mdl",
        },
    },

    -- ================= ФРАКЦИЯ КРИМИНАЛ СТАНЦИИ (v4.17.0 «КОНТРАБАНДА») =================
    -- Заявка владельца: «добавь криминал станции: контрабандисты и т.д.,
    -- им кейс с маскировкой только под персонал — отдельным свепом».
    -- Кейс «ОБСЛУГА» (weapon_polus11_disguise2): щелчок — мгновенная
    -- липовая легенда обслуги (УБОРЩИК/повар/грузчик/техник/медик со
    -- СТОКОВЫМИ моделями HL2 — паков не просит). Позывной и документ —
    -- липовые, срыв — повторным щелчком; смерть/смена профы снимают сами.
    {
        id = "seed_crime_kurer", time = 0, category = "crime", order = 70,
        name = "Курьер контрабанды",
        desc = "Мелкая сошка подполья: переноска тайников, стукачество скупщику, прикрытие отходов. Кейс «ОБСЛУГА» прячет под обслугу по щелчку. ЕДИНСТВЕННАЯ ОТКРЫТАЯ вакансия криминала. 100 ХП.",
        weapons = { "weapon_polus11_disguise2", "weapon_polus11_fists" }, hp = 100, armor = 0, max = 2,
        color = Color(150, 95, 165),
        models = {
            "models/player/Group03/male_04.mdl",
            "models/player/Group03/male_06.mdl",
            "models/player/Group03/female_03.mdl",
        },
    },
    {
        id = "seed_crime_kontrband", time = 90, category = "crime", order = 71, whitelist = true,
        name = "Контрабандист",
        desc = "Провозит запрещёнку через периметр: патроны, спирт, ампулы — всё, кроме аффектов НКВД. Кейс «ОБСЛУГА», обрез двустволки ИЖ-43 (нет ARC9 — стоковая помпа), лом. 105 ХП / 50 брони.",
        weapons = { "weapon_polus11_disguise2", { "arc9_eft_mr43", "weapon_shotgun" }, "weapon_crowbar" },
        hp = 105, armor = 50, max = 3,
        color = Color(140, 85, 160),
        models = {
            "models/player/Group03/male_02.mdl",
            "models/player/Group03/male_05.mdl",
            "models/player/Group03/male_09.mdl",
        },
    },
    {
        id = "seed_crime_skupshik", time = 150, category = "crime", order = 72, whitelist = true,
        name = "Скупщик краденого",
        desc = "Чёрный рынок станции в одном лице: принимает краденое, прячет тайники, держит цены подполья. Кейс «ОБСЛУГА», M1911A1 и рация на воровской волне. 105 ХП / 50 брони. Одно место.",
        weapons = { "weapon_polus11_disguise2", { "arc9_eft_m1911a1", "weapon_pistol" }, "weapon_polus11_radio" },
        hp = 105, armor = 50, max = 1,
        color = Color(160, 100, 175),
        models = {
            "models/player/Group03m/male_03.mdl",
            "models/player/Group03/male_07.mdl",
        },
    },
    {
        id = "seed_crime_glavar", time = 360, category = "crime", order = 73, whitelist = true,
        name = "Главарь криминала станции",
        desc = "«Смотрящий» Полюса-11: контрабандные каналы, долги, крыша. Кейс «ОБСЛУГА», револьвер .357, рация. Одно место. 115 ХП / 75 брони.",
        weapons = { "weapon_polus11_disguise2", "weapon_357", "weapon_polus11_radio" },
        hp = 115, armor = 75, max = 1,
        color = Color(175, 110, 190),
        models = {
            "models/player/Group03m/male_04.mdl",
            "models/player/Group03m/male_06.mdl",
        },
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

    -- ---------- 0.8) v4.8.0 МИГРАЦИЯ: арсенал EFT ARC9 ----------
    -- Оружие пресетов переведено на КАНДИДАТЫ из пака ARC9 EFT
    -- (первый существующий класс) + стоковый фолбэк в хвосте.
    -- Трофейный Kar98 (засорял пак) заменён на трёхлинейку Мосина
    -- из того же EFT-пака. Старые сейвы доезжают одноразово по флагу.
    do
        local byId = {}
        for _, j in ipairs(SEED_JOBS) do byId[j.id] = j end
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs) do
            local def = rec and byId[rec.id]
            if def and rec.eftV480 ~= true then
                rec.weapons = table.Copy(def.weapons)
                rec.eftV480 = true
                changed = true
                if isstring(rec.desc) then
                    rec.desc = string.gsub(rec.desc, "Kar98", "Трёхлинейка")
                end
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.8.0: арсенал переведён на кандидаты EFT ARC9 (Kar98 -> трёхлинейка), сток — фолбэк")
        end
    end

    -- ---------- 0.9) v4.8.1 МИГРАЦИЯ: рация всем военным ----------
    -- Жалоба: «у штурмовика задача поговорить по рации, а рации в
    -- снаряге нет». Выдаём рацию всему военному блоку (РККА+НКВД):
    -- и в пресетах выше, и в уже живущих сейвах — одноразово.
    do
        local MILCAT = { rkka = true, nkvd = true }
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs) do
            if rec and MILCAT[rec.category] and rec.radioV481 ~= true then
                rec.weapons = istable(rec.weapons) and rec.weapons or {}
                local has = false
                for _, w in ipairs(rec.weapons) do
                    if w == "weapon_polus11_radio" then has = true break end
                end
                if not has then
                    rec.weapons[#rec.weapons + 1] = "weapon_polus11_radio"
                end
                rec.radioV481 = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.8.1: рация выдана всем военным (РККА/НКВД) — миграция radioV481")
        end
    end

    -- ---------- 1.0) v4.8.2 МИГРАЦИЯ: лидеры = одно место + шприцы науке ----------
    -- Заявка владельца: «у многих глав получил 2 места вместо 1»
    -- (генерал, глава комплекса, глава отдела и т.д.) и «учёным нужны
    -- шприцы». Одноразово доезжаем старые сейвы по флагам.
    do
        local LEADER1 = {
            seed_rkka_komissar = true, seed_rkka_general = true,
            seed_rkka_generalpeh = true, seed_nkvd_osobist = true,
            seed_nkvd_nachalnik = true, seed_sci_menedzher = true,
            seed_sci_sozdatel = true,
        }
        local SCI = {
            seed_sci_laborant = true, seed_sci_ucheniy = true,
            seed_sci_biohim = true, seed_sci_vedushiy = true,
            seed_sci_menedzher = true, seed_sci_sozdatel = true,
        }
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs) do
            if rec and rec.id then
                if LEADER1[rec.id] and rec.limV482 ~= true then
                    rec.max = 1
                    rec.limV482 = true
                    changed = true
                end
                if SCI[rec.id] and rec.sciV482 ~= true then
                    rec.weapons = istable(rec.weapons) and rec.weapons or {}
                    local has = false
                    for _, w in ipairs(rec.weapons) do
                        if w == "weapon_polus11_syringe" then has = true break end
                    end
                    if not has then
                        rec.weapons[#rec.weapons + 1] = "weapon_polus11_syringe"
                    end
                    rec.sciV482 = true
                    changed = true
                end
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.8.2: лидерам 1 место (limV482), науке выданы шприцы (sciV482)")
        end
    end

    -- ---------- v4.8.6 «НАВОДКА»: УСИЛЕНИЕ ОРЛА + NKVD fem-модель ----------
    -- Старые сейвы (профы из v4.8.5) доезжают до новых статов/моделей/
    -- вооружения из SEED_JOBS; шефу НКВД и особисту (заму) — женский вариант.
    do
        local seedById = {}
        for _, j in ipairs(SEED_JOBS) do seedById[j.id] = j end
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs or {}) do
            local upd = seedById[rec.id]
            if upd and (rec.id == "seed_eagle_agent" or rec.id == "seed_eagle_saboteur" or rec.id == "seed_eagle_rezident")
            and not rec.eagleV486 then
                rec.hp = upd.hp
                rec.armor = upd.armor
                rec.time = upd.time
                rec.weapons = upd.weapons
                rec.models = upd.models
                rec.desc = upd.desc
                rec.eagleV486 = true
                changed = true
            end
            if (rec.id == "seed_nkvd_nachalnik" or rec.id == "seed_nkvd_osobist")
            and not rec.femV486 then
                rec.models = rec.models or {}
                rec.models[#rec.models + 1] = "models/hts/comradebear/pm0v3/player/nkvd/border_guards/co/m35_1941_s1_02f.mdl" -- женская версия (заявка)
                rec.femV486 = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.8.6: Орёл усилен (хп/броня/модели usarmy/Velociraptor диверсанту, eagleV486), НКВД fem-модель шефу и заму (femV486)")
        end
    end

    -- ---------- v4.16.0 «ЗАХВАТ»: ОРЁЛ ПОЛУЧАЕТ ДЛИННЫЕ СТВОЛЫ ----------
    -- Заявка владельца: «дай больше вооружения американцам, чтобы воевать
    -- могли». Живой штат доезжает из SEED_JOBS одноразово (флаг eagleV416):
    -- MP5 агенту, UMP связному, M4 оператору, SA-58 резиденту, M1A
    -- командиру, M700 диверсанту. Кандидаты с фолбэками как раньше —
    -- пака нет: тихо возьмётся HL2-сток, профы не ломаются.
    do
        local seedById = {}
        for _, j in ipairs(SEED_JOBS) do seedById[j.id] = j end
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs or {}) do
            local upd = seedById[rec.id]
            if upd and string.StartWith(tostring(rec.id), "seed_eagle_") and not rec.eagleV416 then
                rec.weapons = upd.weapons
                rec.desc = upd.desc
                rec.eagleV416 = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.16.0 «ЗАХВАТ»: Орёл перевооружён — MP5/UMP/M4/SA-58/M1A/M700 в строй (eagleV416)")
        end
    end

    -- ---------- v4.8.8 «ЛИЧИНА» МИГРАЦИЯ: крит-фикс v4.6.6 + шприц только учёному + [ИВЕНТ] Нечто убран ----------
    -- КОРЕНЬ «ранги ниже допуска берут ранги выше»: v4.6.6 случайно
    -- втащил category/order/whitelist 20 сид-строк В КОММЕНТАРИЙ —
    -- вайтлист НКВД фактически отменялся, профы стояли ОТКРЫТЫ.
    -- Доезжаем СЕЙВЫ: поля копируются из (уже починенного) SEED_JOBS.
    do
        local seedFix = {}
        for _, sj in ipairs(SEED_JOBS) do seedFix[sj.id] = sj end

        local changed = false
        for i = #P11FW.CustomJobs, 1, -1 do
            local rec = P11FW.CustomJobs[i]
            if rec and rec.id then
                -- [ИВЕНТ] Нечто — больше НЕ должность: заражение только
                -- через вакансию у кадровика / укол / админ-пульт
                if rec.id == "seed_thing_filial" then
                    table.remove(P11FW.CustomJobs, i)
                    changed = true
                    P11FW.Log("Сид v4.8.8: должность [ИВЕНТ] Нечто СКРЫТА из штата (заражение: вакансия у кадровика/укол/админ)")
                else
                    -- 1) фикс v4.6.6: category/order/ВАЙТЛИСТ — из сида
                    local sj = seedFix[rec.id]
                    if sj and not rec.fixV488 then
                        rec.category = sj.category
                        rec.order    = sj.order
                        rec.whitelist = sj.whitelist == true
                        rec.fixV488 = true
                        changed = true
                    end
                    -- 2) шприц — ТОЛЬКО «Учёному»; медикам — медкейс
                    if not rec.syrV488 then
                        if rec.id ~= "seed_sci_ucheniy" and istable(rec.weapons) then
                            local w2 = {}
                            for _, w in ipairs(rec.weapons) do
                                if w ~= "weapon_polus11_syringe" then w2[#w2 + 1] = w end
                            end
                            rec.weapons = w2
                        end
                        if rec.id == "seed_rkka_medsestra" or rec.id == "seed_rkka_medglav" or rec.id == "medic" then
                            rec.weapons = istable(rec.weapons) and rec.weapons or {}
                            local has = false
                            for _, w in ipairs(rec.weapons) do
                                if w == "weapon_polus11_medkit" then has = true break end
                            end
                            if not has then rec.weapons[#rec.weapons + 1] = "weapon_polus11_medkit" end
                        end
                        rec.syrV488 = true
                        changed = true
                    end
                end
            end
        end

        -- бойцы на удалённой должности [ИВЕНТ] Нечто — в новобранцы
        for _, pl in ipairs(player.GetAll()) do
            if IsValid(pl) and P11FW.GetJobId and P11FW.GetJobId(pl) == "seed_thing_filial" then
                P11FW.SetJob(pl, P11FW.Config.DefaultJob, nil, true)
            end
        end

    -- ---------- v4.9.1 «ИГЛА» МИГРАЦИЯ: порядок РККА + шприцы науке и медикам ----------
    -- Заявка владельца: медсёстры выше, генералы — ПОСЛЕДНИЕ; вся научная
    -- фракция носит/пользует шприц; медсёстрам вернуть шприц рядом с медкейсом.
    do
        local ORD = {
            seed_rkka_medsestra = 36, seed_rkka_medglav = 37,
            seed_rkka_general = 38, seed_rkka_generalpeh = 39,
        }
        local SYR = {
            seed_sci_laborant = true, seed_sci_ucheniy = true,
            seed_sci_biohim = true, seed_sci_vedushiy = true,
            seed_sci_menedzher = true, seed_sci_sozdatel = true,
            seed_rkka_medsestra = true, seed_rkka_medglav = true,
        }
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs or {}) do
            if rec and rec.id and not rec.iglaV491 then
                if ORD[rec.id] then rec.order = ORD[rec.id] end
                if SYR[rec.id] then
                    rec.weapons = istable(rec.weapons) and rec.weapons or {}
                    local has = false
                    for _, w in ipairs(rec.weapons) do
                        if w == "weapon_polus11_syringe" then has = true break end
                    end
                    if not has then rec.weapons[#rec.weapons + 1] = "weapon_polus11_syringe" end
                end
                rec.iglaV491 = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.9.1 «ИГЛА»: порядок РККА (медсёстры выше, генералы последние, iglaV491); шприцы — вся наука + медсёстры")
        end
    end

    -- ---------- v4.9.2 «ПРИЁМ» МИГРАЦИЯ: РАЦИЯ ВСЕЙ НАУКЕ ----------
    -- Голосовой радио-линк работает только у носителей рации; у науки её
    -- раньше не было в снаряге — «эфир молчит» именно оттуда мёрзли связные.
    do
        local SCI = {
            seed_sci_laborant = true, seed_sci_ucheniy = true,
            seed_sci_biohim = true, seed_sci_vedushiy = true,
            seed_sci_menedzher = true, seed_sci_sozdatel = true,
        }
        local changed = false
        for _, rec in ipairs(P11FW.CustomJobs or {}) do
            if rec and rec.id and SCI[rec.id] and not rec.radioV492 then
                rec.weapons = istable(rec.weapons) and rec.weapons or {}
                local has = false
                for _, w in ipairs(rec.weapons) do
                    if w == "weapon_polus11_radio" then has = true break end
                end
                if not has then rec.weapons[#rec.weapons + 1] = "weapon_polus11_radio" end
                rec.radioV492 = true
                changed = true
            end
        end
        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.9.2 «ПРИЁМ»: рация выдана всей науке (radioV492) — голосовой эфир у всех фракций")
        end
    end

        if changed then
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Log("Сид v4.8.8 «ЛИЧИНА»: category/order/ВАЙТЛИСТ сид-проф восстановлены (фикс дыры допуска v4.6.6), шприц — ТОЛЬКО учёному, медикам медкейс, [ИВЕНТ] Нечто скрыт")
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
            " (РККА / Наука / Нечто / Красный Орёл — сменить: F4 → Админ)")
    end
end

-- ждём, пока fw_sv_factions/fw_sv_customjobs поднимут свои сейвы
hook.Add("InitPostEntity", "P11FW.SeedRkka", function()
    timer.Simple(2.0, SeedAll)
end)
