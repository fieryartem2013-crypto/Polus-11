-- ============================================================
--  ПОЛЮС-11 — конфигурация станции
-- ============================================================

POLUS11 = POLUS11 or {}

POLUS11.Config = {

    -- Админ / ивент-мастер
    Admin = function(ply)
        return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsAdmin())
    end,

    -- ============ ЗАРАЖЕНИЕ ============
    IncubationMin = 150,      -- минимум сек до активации Нечто
    IncubationMax = 280,      -- максимум
    InfectionPersists = true, -- заражение сохраняется после смерти/респавна
    CrackleEveryMin = 45,     -- как часто рядом с носителем трещат хрящи (сек)
    CrackleEveryMax = 90,
    CrackleRadius = 500,
    AutoGiveThing = true,     -- при активации заражённый получает когти (weapon_polus11_thing)

    -- защита Нечто: пули слабо, ОГОНЬ x3
    BulletMulVsThing = 0.35,
    FireMulVsThing   = 3.0,
    FireMulVsBoss    = 5.0,

    -- бафф Нечто в темноте
    DarkSpeedMul = 1.25,
    DarkRegenHP  = 3,
    DarkRegenTick = 2,

    -- ============ ГЕНЕРАТОР ============
    FuelPerBarrel   = 600,    -- секунд работы за бочку
    GeneratorMaxFuel = 900,
    FlickerAt       = 120,    -- ниже этого остатка — мерцание ламп
    SabotageTime    = 8,      -- сек удержания на саботаж (Нечто)
    RepairTime      = 6,      -- сек на ремонт

    -- ============ v3.7: ПЕРЕОХЛАЖДЕНИЕ ============
    ColdEnabled = true,   -- система тепла (улица морозит, генератор и паёк греют); false — отключить
    -- v3.8.2: Альфа-баланс — игрок жаловался «получаю урон просто так».
    -- 150 сек передышки после (ре)спавна + мягкий дренаж: успеешь понять
    -- механику прежде, чем станция начнёт тебя убивать.
    ColdGraceSec    = 150,  -- после (ре)спавна холод тебя НЕ трогает
    ColdDrainOut    = 0.6,  -- тепла/сек на улице (без бури)  [было 1.4]
    ColdDrainStorm  = 2.2,  -- тепла/сек на улице в бурю      [было 3.0]
    ColdDamagePer   = 2,    -- урона за тик обморожения (тепло < 12)
    ColdDamageTick  = 4,    -- сек между тиками урона          [было 2]
    ColdWarn        = true, -- кричать-подсказывать в чат при морозе/уроне

    -- ============ v3.9: ОСОБАЯ ВАКАНСИЯ НЕЧТО У КАДРОВИКА ============
    ThingOfferEnabled = true,  -- периодические окна «вакансии Нечто»; false — отключить модуль
    ThingOfferGapMin  = 240,   -- мин. сек между окнами (4 мин)
    ThingOfferGapMax  = 480,   -- макс. сек между окнами (8 мин)
    ThingOfferWindow  = 90,    -- сколько сек висит открытое окно; не успели — схлопнулось

    -- ============ v4.0: ЭКОНОМИКА (рубли) ============
    MoneyStart      = 500,   -- стартовый кошелёк новичка
    MoneyTaskAll    = 2000,  -- за ВЫПОЛНЕНИЕ ВСЕХ сменных задач
    MoneyTaskExtra  = 500,   -- за каждую ДОП-задачу с терминала
    MoneyMax        = 100000,-- потолок кошелька

    -- ============ v4.1: СМЕННЫЕ ДЕЛА (миниигры) ============
    ScienceGrant    = 250,   -- ₽ грант ЦНИИ за каждые 5 очков науки (RP)
    CalibratePay    = 60,    -- ₽ за калибровку анализатора
    GenServicePay   = 100,   -- ₽ за ТО генератора миниигрой (техник)
    CleanPay        = 35,    -- ₽ за убранное пятно грязи (уборщик)
    PatrolPointPay  = 25,    -- ₽ за каждый осмотренный пост (РККА)
    PatrolCyclePay  = 150,   -- ₽ премия за ПОЛНЫЙ обход всех постов
    PatrolFactions  = { rkka = true }, -- каким фракциям доступен обход

    -- ============ v4.2: ДЕЛА ВТОРОЙ ВОЛНЫ / ЭВЕНТЫ ============
    CookPay         = 40,    -- ₽ за готовый горячий паёк
    MealCommission  = 15,    -- ₽ повару за каждую съеденную порцию
    MealWarmth      = 60,    -- тепла от горячего пайка (сек)
    InjectPay       = 40,    -- ₽ медику за процедурную инъекцию
    PorterBonus     = 120,   -- ₽ максимум за мгновенную заявку (тает за 240 сек)
    SupplyGapMin    = 900,   -- сек до первого/между сбросами снабжения
    SupplyGapMax    = 1500,
    SalePct         = 0.4,   -- скидка дня в ларьке (доля)
    AwardPay        = 300,   -- ₽ бонус за звание смены (каждое из трёх)

    -- ============ v3.8.1: ТЕМП ПЕРЕДВИЖЕНИЯ ============
    -- Бег медленнее, прыжок ниже, анти-баннихоп. Грузчик/коварное
    -- перенос грузов считает замедление от этих базовых величин.
    Movement = {
        walk     = 170,    -- шаг (было 200)
        run      = 330,    -- разбег (было 400)
        jump     = 120,    -- высота прыжка (было 160)
        antiBhop = true,   -- гасить импульс при приземлении (цепочки прыжков не ускоряют)
    },

    -- ============ ОГНЕМЁТ ============
    FT_MaxFuel      = 200,    -- единиц струи
    FT_DPS          = 10,     -- прямой урон струи (дохи через Ignite)
    FT_Range        = 320,
    FT_IgniteTime   = 3,
    FT_RefillCost   = 3,      -- сек топлива генератора за 1 единицу огнемёта

    -- ============ ТЕСТ КРОВИ ============
    BloodTestTime   = 4,      -- секунд теста
    BloodPerTargetCooldown = 30, -- нельзя брать кровь у одного чаще
    SyringeCooldown = 6,

    -- ============ РАЦИИ ============
    RadioGarble      = 0.10,  -- доля "съеденных" букв в тексте
    RadioStormGarble = 0.5,   -- во время бури
    StormBlocksRadio = true,

    -- ============ ГОТОВНОСТЬ К АЛЬФЕ ============
    CustomScoreboard = true,  -- свой ТАБ с подменой ников (Sandbox)
    FakeOnline = true,        -- v3.5: в TAB обычные игроки видят онлайн «±» (паранойя: не вычислить пропавших); админы — точное число
    HideKillFeed     = false, -- true = скрыть килл-ленту (палит настоящие ники)
    StationPersist   = true,  -- генератор/бочки/стол переживают рестарт карты
    Nametags         = true,  -- таблички-imena над головами (вор = жертва)

    -- ============ АВТОСМЕНА ============
    -- УДАЛЕНО в v2.2 по запросу: раунд идёт вручную через админ-пульт (?пульт).

    -- ============ v2.3: АНТИ-СКУКА И НЕЧТО-РЕВОРК ============
    Tasks           = true,   -- задачи смены по профессиям (HUD слева)
    ChemlightGive   = 2,      -- химсветов выдаётся каждому при спавне
    ChemlightTime   = 600,    -- сколько горит химсвет (сек)
    PanicFX         = true,   -- стресс-эффекты при виде формы монстра
    AutopsyTime     = 5,      -- секунд на вскрытие трупа скальпелем
    RationCooldown  = 12,     -- паёк: кулдаун раздачи
    RationHeal      = 15,     -- паёк: лечение
    SirenCooldown   = 90,     -- сирена построения: общий кулдаун

    -- Нечто-реворк
    ScreamCooldown   = 45,    -- крик ужаса: кулдаун
    ScreamRadius     = 700,   -- радиус крика
    ClassSwitchCooldown = 60, -- смена формы (!форма): кулдаун
    SporeRadius      = 130,   -- радиус спорового облака
    SporeCloudTime   = 15,    -- жизнь облака (сек)
    SporeInfectAt    = 100,   -- при этой «дозе спор» человек заражается
    ExposureDecay    = 8,     -- спад «дозы спор» в 2 сек вне облака

    -- ============ ПРОФЕССИИ (ПОЛЮС FRAMEWORK / DarkRP) ============
    RestrictJobs = true,      -- ограничения по профессиям (тест крови — учёным, огнемёт — инженеру/учёному)
                              -- если фреймворк и DarkRP НЕ установлены — ограничения сами отключаются
    ScientistTeams = {"Вирусолог", "Лаборант", "Полевой медик", "Учёный", "Scientist", "Virologist"},
    EngineerTeams  = {"Инженер-изобретатель", "Техник-механик", "Инженер", "Engineer"},

    -- ============ ФАЗЫ СМЕНЫ ============
    Phases = {"Спокойствие", "Первое исчезновение", "Паника", "Прорыв"},

    -- ============ v2.5: СТРОИТЕЛЬСТВО ИЗ ПРОПОВ (для всех игроков) ============
    -- Не-админам доступна только вкладка «Пропы» и только модели из списка.
    -- Свежий проп — ПРИЗРАК (прозрачный, без коллизий с игроками).
    -- E — взять/поставить. Окаменеет (станет физичным), только когда
    -- в радиусе SolidifyRadius НЕТ НИ ОДНОГО игрока SolidityTime секунд.
    Building = {
        Enabled         = true,
        MaxPerPlayer    = 8,    -- сколько пропов может держать один игрок
        SolidifyRadius  = 130,  -- радиус «чистой зоны» для окаменения
        SolidityTime    = 2,    -- секунд чистой зоны до окаменения
        CarryDistance   = 90,   -- дистанция переноски перед лицом
        GhostAlpha      = 120,  -- прозрачность призрака (0-255)

        -- Вайтлист моделей (станционный реквизит; список можно расширять)
        AllowedProps    = {
            -- мебель и жилое
            ["models/props_c17/furniturebed001a.mdl"] = true,             -- койка
            ["models/props_c17/furniturechair001a.mdl"] = true,           -- стул
            ["models/props_c17/furnituretable001a.mdl"] = true,           -- стол
            ["models/props_c17/furnituretable002a.mdl"] = true,           -- стол кухонный
            ["models/props_c17/furniturecouch001a.mdl"] = true,           -- диван
            ["models/props_c17/furnituredrawer001a.mdl"] = true,          -- тумба
            ["models/props_c17/furnituredresser001a.mdl"] = true,         -- комод
            ["models/props_c17/furnitureshelf001b.mdl"] = true,           -- полка
            ["models/props_c17/furniturefridge001a.mdl"] = true,          -- холодильник
            ["models/props_c17/furniturewashingmachine001a.mdl"] = true,  -- стиралка
            ["models/props_c17/bench01a.mdl"] = true,                     -- скамейка
            -- склад и снабжение
            ["models/props_junk/wood_crate001a.mdl"] = true,              -- ящик малый
            ["models/props_junk/wood_crate002a.mdl"] = true,              -- ящик большой
            ["models/props_junk/wood_pallet001a.mdl"] = true,             -- паллета
            ["models/props_junk/cardboard_box001a.mdl"] = true,           -- коробка
            ["models/props_junk/cardboard_box002a.mdl"] = true,
            ["models/props_junk/cardboard_box003a.mdl"] = true,
            ["models/props_junk/cardboard_box004a.mdl"] = true,
            ["models/props_c17/oildrum001.mdl"] = true,                   -- бочка
            ["models/props_borealis/bluebarrel001.mdl"] = true,           -- бочка синяя
            ["models/props_c17/canister01a.mdl"] = true,                  -- канистра
            ["models/props_c17/canister_propane01a.mdl"] = true,          -- баллон пропановый
            ["models/props_junk/propane_tank001a.mdl"] = true,            -- газовый баллон
            ["models/props_junk/metalgascan.mdl"] = true,                 -- канистра с бензином
            ["models/props_c17/longwood01a.mdl"] = true,                  -- доска-длинная
            -- хозобих и атмосфера
            ["models/props_junk/plasticbucket001a.mdl"] = true,           -- ведро
            ["models/props_junk/trafficcone001a.mdl"] = true,             -- конус
            ["models/props_junk/shovel01a.mdl"] = true,                   -- лопата (снег!)
            ["models/props_junk/garbage_bag001a.mdl"] = true,             -- мешок мусора
            ["models/props_junk/garbage_newspaper001a.mdl"] = true,       -- газета
            ["models/props_junk/glassjug01.mdl"] = true,                  -- бутыль
            ["models/props_junk/watermelon01.mdl"] = true,                -- арбуз (юмор)
            ["models/props_c17/metalpot001a.mdl"] = true,                 -- кастрюля
            ["models/props_junk/meathook001a.mdl"] = true,                -- мясной крюк
            -- инструменты и лаборатория
            ["models/props_c17/tools_wrench01a.mdl"] = true,              -- гаечный ключ
            ["models/props_c17/tools_pliers01a.mdl"] = true,              -- пассатижи
            ["models/props_c17/tools_hammer01.mdl"] = true,               -- молоток
            ["models/props_lab/citizenradio.mdl"] = true,                 -- радиоприёмник
            ["models/props_lab/desklamp01.mdl"] = true,                   -- настольная лампа
            ["models/props_lab/clipboard.mdl"] = true,                    -- планшет с бумагами
            ["models/props_lab/heatplate.mdl"] = true,                    -- плитка лабораторная
            ["models/props_c17/consolebox01a.mdl"] = true,                -- консоль/компьютер
            -- личное
            ["models/props_c17/suitcase_passenger_physics.mdl"] = true,   -- чемодан
            ["models/props_interiors/radiator01a.mdl"] = true,            -- батарея (тепло!)
            ["models/props_interiors/vendingmachinesoda01a.mdl"] = true,  -- торговый автомат
        },
    },

    -- ============ v4.6.9: ОКЛАД + ОБМЕН ============
    WageEvery         = 420,  -- сек между начислениями оклада (7 минут)
    WageBase          = 150,  -- ₽ базовый оклад живому служащему
    WageTerminalBonus = 80,   -- ₽ доплата терминальным (руководящим) должностям
}
