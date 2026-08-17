-- ============================================================
--  ПОЛЮС-11 — v5.8.15 «ООН/ГОК + ЧИСТКА» (server, autorun)
--  Четыре задачи владельца:
--   1) УБРАТЬ HIDE-CHAT (вернуть чат) — аддон удалён из сборки;
--   2) УБРАТЬ НЕМЕЦКОЕ ОРУЖИЕ ИЗ ЛАРЬКА: k98, stg44, mp40, g43, p08;
--   3) ВЫРЕЗАТЬ ФРАКЦИЮ «КРЕПОСТЬ ОСОВЕЦ» (прошлая ивентовая):
--      профы seed_oso_* + категория osowiec;
--   4) НОВАЯ ИВЕНТ-ФРАКЦИЯ «ООН / ГОК» (9 проф с моделями cheddar,
--      оружием ARC9 EFT, у Шпиона — кейс маскировки «ЛЕГАТ»,
--      у Командира — вайтлист).
--
--  Старые файлы НЕ трогаем: Осовец и немецкое оружие режем
--  ПОСЛЕ загрузки (наши профы регистрируем как кастомные и
--  синкаем клиентам). Работаем после сида (таймер 4 сек).
-- ============================================================

-- ============ ХЕЛПЕРЫ ============
local function Log(txt)
    if P11FW.Log then P11FW.Log(txt) else print("[POLUS-11][v5.8.15] " .. txt) end
end

local function IsOsovecJob(id)
    return isstring(id) and (
        id == "seed_oso_pioner" or id == "seed_oso_strelok" or id == "seed_oso_medik"
        or id == "seed_oso_nco" or id == "seed_oso_vermacht" or id == "seed_oso_oficer"
        or id == "seed_oso_general"
    )
end

-- ============ 2) НЕМЕЦКОЕ ОРУЖИЕ ИЗ ЛАРЬКА ============
local GERMAN_ITEMS = { "k98", "stg44", "mp40", "g43", "p08" }

local function CutGermanShop()
    if not POLUS11.Items then return 0 end
    local n = 0
    for _, id in ipairs(GERMAN_ITEMS) do
        if POLUS11.Items[id] then
            POLUS11.Items[id] = nil
            n = n + 1
        end
    end
    return n
end

-- ============ 3) ВЫРЕЗАТЬ ОСОВЕЦ ============
local function CutOsovec()
    local cut = 0

    -- 3.1) убрать профы из CustomJobs (сид кладёт их туда) и из Jobs/JobTeams/TeamJobs
    if P11FW.CustomJobs then
        local keep = {}
        for _, rec in ipairs(P11FW.CustomJobs) do
            if not (rec and IsOsovecJob(rec.id)) then
                keep[#keep + 1] = rec
            else
                cut = cut + 1
            end
        end
        P11FW.CustomJobs = keep
    end

    if P11FW.Jobs then
        for id in pairs(P11FW.Jobs) do
            if IsOsovecJob(id) then
                local t = P11FW.JobTeams and P11FW.JobTeams[id]
                if t then
                    P11FW.TeamJobs[t] = nil
                    P11FW.JobTeams[id] = nil
                end
                P11FW.Jobs[id] = nil
            end
        end
    end

    -- 3.2) убрать категорию osowiec
    if P11FW.Categories then
        local keep = {}
        for _, c in ipairs(P11FW.Categories) do
            if not (c and c.id == "osowiec") then keep[#keep + 1] = c end
        end
        P11FW.Categories = keep
    end
    if P11FW.CategoryList then
        local keep = {}
        for _, c in ipairs(P11FW.CategoryList) do
            if not (c and c.id == "osowiec") then keep[#keep + 1] = c end
        end
        P11FW.CategoryList = keep
    end
    if P11FW.CustomFactions and P11FW.CustomFactions.osowiec then
        P11FW.CustomFactions.osowiec = nil
    end

    -- 3.3) игроки, сидящие на профах Осовца — на дефолт
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local jid = P11FW.GetJobId and P11FW.GetJobId(p)
            if jid and IsOsovecJob(jid) then
                local def = P11FW.Config and P11FW.Config.DefaultJob
                if def and P11FW.SetJob then
                    P11FW.SetJob(p, def, 1, true)
                end
            end
        end
    end

    if cut > 0 then
        Log("v5.8.15: вырезано проф Осовца: " .. cut)
    end
    return cut
end

-- ============ 4) НОВАЯ ФРАКЦИЯ «ООН / ГОК» ============
local UN_CAT = "ungoc"

local UN_JOBS = {
    { id = "ev_un_rekrut",  name = "Рекрут ООН",      desc = "Новобранец сил ООН: первая форма, первый ствол. Учись у старших, держись группы. 100 ХП / 55 брони.",
      category = UN_CAT, order = 60, time = 0, max = 4, hp = 100, armor = 55,
      models = { "models/player/cheddar/assessment_team/assessment_09.mdl" },
      weapons = { { "arc9_eft_mp9", "weapon_smg1" } },
      color = { r = 70, g = 130, b = 190 } },
    { id = "ev_un_soldat",  name = "Солдат ООН",       desc = "Пехотинец сил ООН: дисциплина, SCAR-H, приказ. 115 ХП / 100 брони.",
      category = UN_CAT, order = 61, time = 30, max = 4, hp = 115, armor = 100,
      models = { "models/player/cheddar/goc_soldier/goc_field_operative.mdl" },
      weapons = { { "arc9_eft_scarh", "weapon_ar2" } },
      color = { r = 70, g = 130, b = 190 } },
    { id = "ev_un_shturm",  name = "Штурмовик ООН",    desc = "Тяжёлый штурмовик: SCAR-X17, пробивает стены и Нечто. 135 ХП / 125 брони.",
      category = UN_CAT, order = 62, time = 60, max = 2, hp = 135, armor = 125,
      models = { "models/player/cheddar/goc_soldier/goc_soldier.mdl" },
      weapons = { { "arc9_eft_scarx17", "weapon_ar2" } },
      color = { r = 60, g = 110, b = 170 } },
    { id = "ev_un_shpion",  name = "Шпион ООН",        desc = "Тихий наблюдатель: MP5K под курткой и кейс маскировки «ЛЕГАТ» — переоденься кем угодно. 125 ХП / 100 брони.",
      category = UN_CAT, order = 63, time = 90, max = 2, hp = 125, armor = 100,
      models = { "models/player/cheddar/goc/strike_team_soldier2/goc_striker_team.mdl" },
      weapons = { "weapon_polus11_disguise", { "arc9_eft_mp5k", "weapon_smg1" } },
      color = { r = 90, g = 90, b = 170 } },
    { id = "ev_un_ucheniy", name = "Учёный ООН",       desc = "Гражданский специалист ГОК: UZI PRO для защиты, аналитика для дела. 100 ХП / 100 брони.",
      category = UN_CAT, order = 64, time = 30, max = 2, hp = 100, armor = 100,
      models = { "models/player/cheddar/goc_soldier/goc_hazmat.mdl" },
      weapons = { { "arc9_eft_uzi_pro", "weapon_smg1" } },
      color = { r = 140, g = 190, b = 140 } },
    { id = "ev_un_titan",   name = "Титан ГОК",        desc = "Живая крепость: оранжевый костюм, M60E4, 200 ХП / 185 брони. Идёт медленно, ломает всё.",
      category = UN_CAT, order = 65, time = 120, max = 1, hp = 200, armor = 185,
      models = { "models/player/cheddar/suit/orange_suit/orangesuit.mdl" },
      weapons = { { "arc9_eft_m60e4", "weapon_ar2" } },
      color = { r = 220, g = 140, b = 60 } },
    { id = "ev_un_oficer",  name = "Офицер ООН/ГОК",   desc = "Командное звено: АС «Вал», координация, решения. 145 ХП / 115 брони.",
      category = UN_CAT, order = 66, time = 90, max = 2, hp = 145, armor = 115,
      models = { "models/player/cheddar/goc_soldier/goc_officer.mdl" },
      weapons = { { "arc9_eft_asval", "weapon_smg1" } },
      color = { r = 210, g = 170, b = 80 } },
    { id = "ev_un_komandir", name = "Командир ГОК (вайтлист)", desc = "Голова миссии: Vector 9, полный доступ, вайтлист. 145 ХП / 145 брони.",
      category = UN_CAT, order = 67, time = 120, max = 1, hp = 145, armor = 145,
      whitelist = true,
      models = { "models/player/cheddar/goc_soldier/goc_commander.mdl" },
      weapons = { { "arc9_eft_vector9", "weapon_smg1" } },
      color = { r = 230, g = 190, b = 90 } },
    { id = "ev_un_diplomat", name = "Дипломат ООН",    desc = "Без оружия — только слово. Переговоры, документы, статус. 100 ХП / 50 брони.",
      category = UN_CAT, order = 68, time = 30, max = 2, hp = 100, armor = 50,
      models = { "models/player/cheddar/ambassador/goc_male_07.mdl" },
      weapons = {},
      color = { r = 150, g = 170, b = 200 } },
}

-- фолбэки для EFT-оружия ООН (если пака нет — стоковые аналоги)
local UN_FALLBACK = {
    arc9_eft_mp9      = "weapon_smg1",
    arc9_eft_scarh    = "weapon_ar2",
    arc9_eft_scarx17  = "weapon_ar2",
    arc9_eft_mp5k     = "weapon_smg1",
    arc9_eft_uzi_pro  = "weapon_smg1",
    arc9_eft_m60e4    = "weapon_ar2",
    arc9_eft_vector9  = "weapon_smg1",
}

local function RegisterUN()
    -- фолбэки
    if POLUS11 and POLUS11.WepFallback then
        for k, v in pairs(UN_FALLBACK) do
            POLUS11.WepFallback[k] = POLUS11.WepFallback[k] or v
        end
    end

    -- фракция
    if P11FW.RegisterCustomFactions then
        P11FW.RegisterCustomFactions({
            { id = UN_CAT, name = "ООН / ГОК",
              desc = "Ивентовая фракция: силы ООН и ГОК (Глобальная Оккультная Коалиция). Пришли разобраться с тем, что на станции. Современное оружие, тяжёлая броня.",
              order = 10, color = { r = 70, g = 130, b = 190 } },
        })
    end

    -- профы (кастомные, как сид)
    if P11FW.CustomJobs then
        for _, j in ipairs(UN_JOBS) do
            local exists = false
            for _, r in ipairs(P11FW.CustomJobs) do
                if r.id == j.id then exists = true break end
            end
            if not exists then
                local t = nil
                -- свободный слот team
                if P11FW.JobTeams then
                    local used = {}
                    for _, r in ipairs(P11FW.CustomJobs) do
                        if r.team then used[r.team] = true end
                    end
                    for tIdx = 200, 400 do
                        if not used[tIdx] and not P11FW.JobTeams[j.id] then
                            t = tIdx break
                        end
                    end
                end
                if not t then t = 300 + #P11FW.CustomJobs end
                P11FW.CustomJobs[#P11FW.CustomJobs + 1] = {
                    id = j.id, team = t, name = j.name, category = j.category,
                    desc = j.desc, max = j.max or 0, models = j.models or {},
                    weapons = j.weapons or {}, hp = j.hp or 100, armor = j.armor or 0,
                    color = j.color or { r = 200, g = 160, b = 110 },
                    whitelist = j.whitelist == true, time = j.time or 0, order = j.order or 100,
                }
            end
        end
    end

    if P11FW.RegisterCustomJobs then P11FW.RegisterCustomJobs(P11FW.CustomJobs) end
    if P11FW.SaveCustomJobs then P11FW.SaveCustomJobs() end
    if P11FW.SyncCustomJobs then P11FW.SyncCustomJobs() end
    if P11FW.SyncFactions then P11FW.SyncFactions() end
    Log("v5.8.15: фракция «ООН / ГОК» — проф: " .. #UN_JOBS)
end

-- ============ ЗАПУСК ПОСЛЕ СИДА ============
hook.Add("InitPostEntity", "P11.V5815.Run", function()
    timer.Simple(4, function()
        local nGerman = CutGermanShop()
        local nOsovec = CutOsovec()
        RegisterUN()
        Log("v5.8.15: готово. Немецкое оружие из ларька: -" .. nGerman
            .. ", Осовец вырезан: -" .. nOsovec .. " проф, ООН/ГОК добавлен")
    end)
end)
hook.Add("PostCleanupMap", "P11.V5815.Map", function()
    timer.Simple(4, function()
        CutGermanShop()
        CutOsovec()
    end)
end)

-- страховка: при спавне, если кто-то всё ещё в профе Осовца — сбросить
hook.Add("PlayerSpawn", "P11.V5815.Spawn", function(ply)
    timer.Simple(0.3, function()
        if not IsValid(ply) then return end
        local jid = P11FW.GetJobId and P11FW.GetJobId(ply)
        if jid and IsOsovecJob(jid) then
            local def = P11FW.Config and P11FW.Config.DefaultJob
            if def and P11FW.SetJob then P11FW.SetJob(ply, def, 1, true) end
        end
    end)
end)

print("[POLUS-11] v5.8.15: hide-chat убран, немецкое оружие из ларька вырезано, Осовец удалён, ООН/ГОК добавлен")
