-- ============================================================================
--  ПОЛЮС-11 | ПАК ПРОФЕССИЙ И ФРАКЦИЙ ДЛЯ DARKRP  (запросил владелец сервера)
-- ----------------------------------------------------------------------------
--  УСТАНОВКА:
--   1. Этот файл положить в:
--      garrysmod/addons/darkrpmodification-master/lua/darkrp_customthings/jobs_p11.lua
--      (или целиком заменить им jobs.lua, подняв содержимое туда)
--   2. Оружие: классы arc9_eft_* требуют [ARC9] Base + пак EFT-оружия из воркшопа,
--      arc9_doi_k98 — пак ARC9 DOI. Без них оружие просто не выдастся.
--   3. Модели: пути models/hts/comradebear/... и models/uif/scientists/...
--      должны быть на сервере (скачай паки из воркшопа в коллекцию сервера,
--      иначе игроки будут ERROR/гигантами).
--   4. Свepы Нечто живут в гейммоде POLUS-11 (gamemodes/polus/entities/weapons).
--      Чтобы использовать их на DarkRP, скопируй папки из
--      polus/entities/weapons/weapon_polus11_thing* и weapon_polus11_hands
--      в garrysmod/addons/polus_things/lua/weapons/ .
--   5. Числа ХП/брони выставляются в PlayerSpawn каждой профы (по спецификации).
--     ВСЕМ профам выдаются «руки» DarkRP (keys/pocket идут стандартом)
--      + weapon_fists, если класс есть.
-- ============================================================================

-- ============================== ФРАКЦИИ (категории) ==============================

DarkRP.createCategory{
    name = "РККА",
    categorises = "jobs",
    startExpanded = true,
    color = Color(175, 165, 95),
    sortOrder = 10,
}

DarkRP.createCategory{
    name = "НАУКА",
    categorises = "jobs",
    startExpanded = true,
    color = Color(140, 200, 240),
    sortOrder = 11,
}

DarkRP.createCategory{
    name = "НЕЧТО",
    categorises = "jobs",
    startExpanded = false,
    color = Color(150, 55, 60),
    sortOrder = 99,
}

-- ---------- шаблонные модельные пути ----------
local RKKA_M35 = {
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_03.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_04.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_05.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_06.mdl",
}
local RKKA_M43 = {
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_02.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_03.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_04.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_05.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m43_s1_06.mdl",
}
local RKKA_SHTRAF = {
    "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_02.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_03.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_04.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_05.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/infantry/shtrafniki/m35_1941_s1_06.mdl",
}
local RKKA_KOMISSAR = {
    "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_02.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_03.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_04.mdl",
    "models/hts/comradebear/pm0v3/player/rkka/commissar/co/m35_1941_s1_05.mdl",
}
local SCI7 = { "Models/UIF/scientists/UIF_scientist_7.mdl" }
local SCI8 = { "Models/UIF/scientists/UIF_scientist_8.mdl" }
local THING_MDL = { "models/player/corpse1.mdl" }

-- ---------- помощник: ХП/броня по спецификации ----------
local function Stats(hp, armor)
    return function(ply)
        ply:SetMaxHealth(hp)
        ply:SetHealth(hp)
        ply:SetArmor(armor)
        -- «руки» на всех (если класс существует)
        if weapons.Get and weapons.Get("weapon_fists") and not ply:HasWeapon("weapon_fists") then
            ply:Give("weapon_fists")
        end
    end
end

-- ============================== ФРАКЦИЯ «РККА» ==============================

TEAM_RKKA_NOVOBRANETS = DarkRP.createJob("Новобранец РККА", {
    color = Color(160, 160, 120),
    model = { "models/hts/comradebear/pm0v3/player/rkka/infantry/en/m35_1941_s1_02.mdl" },
    description = [[Свежеприбывшее пополнение. Оружия не положено — держись постовых, слушай комиссара и не выходи в метель без приказа.]],
    weapons = {},
    command = "rkka_novobranets",
    max = 0, salary = 30, admin = 0, vote = false, hasLicense = false,
    category = "РККА",
    PlayerSpawn = Stats(100, 0),
})

TEAM_RKKA_POSTOVOY = DarkRP.createJob("Постовой РККА", {
    color = Color(175, 165, 95),
    model = RKKA_M35,
    description = [[Стоит на посту: ворота, караулка, склад. АКС-74У — короткий и злой, для коридоров станции самое то. 100 ХП / 100 брони.]],
    weapons = { "arc9_eft_aks74u" },
    command = "rkka_postovoy",
    max = 4, salary = 45, admin = 0, vote = false, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_RKKA_SOLDAT = DarkRP.createJob("Солдат РККА", {
    color = Color(185, 170, 90),
    model = RKKA_M35,
    description = [[Основной боец гарнизона. Полноразмерный АК-74, патрули и сопровождение учёных. 105 ХП / 105 брони.]],
    weapons = { "arc9_eft_aks74" },
    command = "rkka_soldat",
    max = 6, salary = 50, admin = 0, vote = false, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(105, 105),
})

TEAM_RKKA_SHTURMOVIK = DarkRP.createJob("Штурмовик РККА", {
    color = Color(200, 160, 80),
    model = RKKA_M43,
    description = [[Первым вламывается в заражённые отсеки. ППШ-41 косит всё в упор, тяжёлый бронежилет. 125 ХП / 145 брони.]],
    weapons = { "arc9_eft_ppsh41" },
    command = "rkka_shturmovik",
    max = 3, salary = 65, admin = 0, vote = true, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(125, 145),
})

TEAM_RKKA_RAZVEDCHIK = DarkRP.createJob("Разведчик РККА", {
    color = Color(165, 145, 85),
    model = RKKA_SHTRAF,
    description = [[Уходит в белую пустыню первым. Трёхлинейка бьёт точно и далеко. 125 ХП / 115 брони. Штрафная рота — туда лучше не попадать.]],
    weapons = { "arc9_eft_mosin_infantry" },
    command = "rkka_razvedchik",
    max = 3, salary = 60, admin = 0, vote = true, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(125, 115),
})

TEAM_RKKA_KOMISSAR = DarkRP.createJob("Комиссар РККА", {
    color = Color(160, 90, 85),
    model = RKKA_KOMISSAR,
    description = [[Политрук гарнизона. Дисциплина, допросы, трибунал. Kar98 — за спиной, ордер на расстрел дезертиров — в кармане. Одно место. 100 ХП / 100 брони.]],
    weapons = { "arc9_doi_k98" },
    command = "rkka_komissar",
    max = 1, salary = 90, admin = 0, vote = true, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_RKKA_GENERAL = DarkRP.createJob("Генерал РККА", {
    color = Color(210, 185, 90),
    model = { "models/hts/comradebear/pm0v3/player/rkka/general_staff/gen/m40_1941_s1_05.mdl" },
    description = [[Командующий всем военным контингентом станции из генеральского штаба. Kar98 и полная власть. Одно место. 125 ХП / 125 брони.]],
    weapons = { "arc9_doi_k98" },
    command = "rkka_general",
    max = 1, salary = 120, admin = 0, vote = true, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(125, 125),
})

TEAM_RKKA_GENERALPEH = DarkRP.createJob("Генерал РККА (Пехота)", {
    color = Color(195, 175, 85),
    model = { "models/hts/comradebear/pm0v3/player/rkka/infantry/gen/m40_1941_s1_02.mdl" },
    description = [[Комбат пехотного звена: ближе к окопам, чем к штабу. Двустволка MR-43 для личной самообороны. Одно место. 100 ХП / 100 брони.]],
    weapons = { "arc9_eft_mr43" },
    command = "rkka_generalpeh",
    max = 1, salary = 100, admin = 0, vote = true, hasLicense = true,
    category = "РККА",
    PlayerSpawn = Stats(100, 100),
})

-- ============================== НАУКА ==============================

TEAM_SCI_LABORANT = DarkRP.createJob("Лаборант", {
    color = Color(165, 205, 250),
    model = SCI7,
    description = [[Младший научный состав. Мытьё пробирок, подносы, журналы опытов. 100 ХП / 100 брони.]],
    weapons = {},
    command = "sci_laborant",
    max = 4, salary = 40, admin = 0, vote = false, hasLicense = false,
    category = "НАУКА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_SCI_UCHENIY = DarkRP.createJob("Учёный", {
    color = Color(170, 210, 255),
    model = SCI7,
    description = [[Штатный исследователь комплекса. Доступ к образцам и лабораторным стендам. 100 ХП / 100 брони.]],
    weapons = {},
    command = "sci_ucheniy",
    max = 3, salary = 55, admin = 0, vote = false, hasLicense = false,
    category = "НАУКА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_SCI_BIOHIM = DarkRP.createJob("Био-химик", {
    color = Color(145, 225, 210),
    model = SCI7,
    description = [[Специалист по биохимическому анализу тканей. К его холодильнику с образцами лучше не подходить без перчаток. 100 ХП / 100 брони.]],
    weapons = {},
    command = "sci_biohim",
    max = 2, salary = 65, admin = 0, vote = false, hasLicense = false,
    category = "НАУКА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_SCI_VEDUSHIY = DarkRP.createJob("Ведущий Учёный", {
    color = Color(130, 200, 245),
    model = SCI7,
    description = [[Руководит экспериментами лично. Подписывает заключения по биологическим угрозам. 100 ХП / 100 брони.]],
    weapons = {},
    command = "sci_vedushiy",
    max = 2, salary = 80, admin = 0, vote = false, hasLicense = false,
    category = "НАУКА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_SCI_MENEDZHER = DarkRP.createJob("Менеджер Научного Отдела", {
    color = Color(120, 190, 240),
    model = SCI7,
    description = [[Отвечает за сметы, графики и допуски научного блока. Знает, кого и за что пускают в лаборатории. Одно место. 100 ХП / 100 брони.]],
    weapons = {},
    command = "sci_menedzher",
    max = 1, salary = 100, admin = 0, vote = true, hasLicense = false,
    category = "НАУКА",
    PlayerSpawn = Stats(100, 100),
})

TEAM_SCI_SOZDATEL = DarkRP.createJob("Создатель Научного Комплекса", {
    color = Color(105, 180, 235),
    model = SCI8,
    description = [[Легенда «Полюс-11»: главный конструктор научного блока. Допуск во ВСЕ отсеки, включая те, о которых нет в документах. Одно место. 100 ХП / 100 брони.]],
    weapons = {},
    command = "sci_sozdatel",
    max = 1, salary = 150, admin = 0, vote = true, hasLicense = false,
    category = "НАУКА",
    PlayerSpawn = Stats(100, 100),
})

-- ============================== НЕЧТО (ивенты) ==============================
--
--  Эти профы ТОЛЬКО для админ-ивентов: из F4 их можно выбрать, но без
--  админ-прав customCheck их не пустит. Свepы weapon_polus11_thing* — из
--  гейммода POLUS-11, переложенного в addon (см. пункт 4 шапки).

local function OnlyAdminCheck(ply)
    return ply:IsAdmin()
end

TEAM_THING_BASE = DarkRP.createJob("[ИВЕНТ] Нечто", {
    color = Color(150, 55, 60),
    model = THING_MDL,
    description = [[Базовая форма. Личинка-хамелеон, крадущая тела и лица. ТОЛЬКО админ-ивенты. 400 ХП.]],
    weapons = { "weapon_polus11_thing" },
    command = "thing_base",
    max = 1, salary = 0, admin = 0, vote = false, hasLicense = false,
    customCheck = OnlyAdminCheck,
    CustomCheckFailMsg = "Только администрация выдаёт формы Нечто.",
    category = "НЕЧТО",
    PlayerSpawn = Stats(400, 0),
})

TEAM_THING_SPLIT = DarkRP.createJob("[ИВЕНТ] Нечто-Распад", {
    color = Color(160, 60, 70),
    model = THING_MDL,
    description = [[Форма распада: тело делится на множество мелких тварей. ТОЛЬКО админ-ивенты. 250 ХП.]],
    weapons = { "weapon_polus11_thing_split" },
    command = "thing_split",
    max = 1, salary = 0, admin = 0, vote = false, hasLicense = false,
    customCheck = OnlyAdminCheck,
    CustomCheckFailMsg = "Только администрация выдаёт формы Нечто.",
    category = "НЕЧТО",
    PlayerSpawn = Stats(250, 0),
})

TEAM_THING_BRUTE = DarkRP.createJob("[ИВЕНТ] Нечто-Громила", {
    color = Color(170, 65, 60),
    model = THING_MDL,
    description = [[Тяжёлая боевой форма: стены ей — что картон. ТОЛЬКО админ-ивенты. 900 ХП / 200 брони.]],
    weapons = { "weapon_polus11_thing_brute" },
    command = "thing_brute",
    max = 1, salary = 0, admin = 0, vote = false, hasLicense = false,
    customCheck = OnlyAdminCheck,
    CustomCheckFailMsg = "Только администрация выдаёт формы Нечто.",
    category = "НЕЧТО",
    PlayerSpawn = Stats(900, 200),
})

TEAM_THING_SPORE = DarkRP.createJob("[ИВЕНТ] Нечто-Споровик", {
    color = Color(145, 70, 85),
    model = THING_MDL,
    description = [[Форма-распылитель спорного облака: заражает без укуса. ТОЛЬКО админ-ивенты. 350 ХП.]],
    weapons = { "weapon_polus11_thing_spore" },
    command = "thing_spore",
    max = 1, salary = 0, admin = 0, vote = false, hasLicense = false,
    customCheck = OnlyAdminCheck,
    CustomCheckFailMsg = "Только администрация выдаёт формы Нечто.",
    category = "НЕЧТО",
    PlayerSpawn = Stats(350, 0),
})
