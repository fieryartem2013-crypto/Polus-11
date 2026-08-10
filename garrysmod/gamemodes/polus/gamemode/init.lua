-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (server bootstrap)
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

-- клиенту нужны общие + клиентские модули
local send = {
    "modules/fw_sh_config.lua",
    "modules/fw_sh_jobs.lua",
    "modules/p11_sh_config.lua",
    "modules/p11_sh_core.lua",
    "modules/p11_sh_weapons.lua",  -- v4.8.0: арсенал EFT ARC9 + фолбэки
    "modules/fw_sh_factions.lua",
    "modules/fw_sh_ranks.lua",
    "modules/fw_sh_whitelist.lua",  -- v4.4.0: вайтлист должностей (shared)
    "modules/fw_cl_f4.lua",
    "modules/fw_cl_punish.lua",
    "modules/fw_cl_admin.lua",
    "modules/p11_cl_hud.lua",
    "modules/p11_cl_vitals.lua",
    "modules/p11_cl_admin.lua",
    "modules/p11_cl_board.lua",      -- v4.2.1: TAB v2 вместо старого scoreboard
    "modules/p11_cl_nametags.lua",
    "modules/p11_cl_tasks.lua",
    "modules/p11_cl_panic.lua",
    "modules/p11_cl_propmenu.lua",
    "modules/p11_cl_thinghud.lua",
    "modules/p11_cl_intro.lua",
    "modules/p11_cl_terminal.lua",
    "modules/p11_cl_uistyle.lua", -- v4.1: фирменный стиль UI
    "modules/p11_cl_help.lua",
    "modules/p11_cl_alerts.lua",
    "modules/p11_cl_view.lua",
    "modules/p11_cl_chat.lua",      -- v4.5.0: свой чат-UI (/ooc /looc /me /it /report)
    "modules/p11_cl_arrival.lua",   -- v4.5.0: заставка прибытия колонны
    "modules/p11_cl_cmenu.lua",
    "modules/p11_cl_models.lua",    -- v4.4.0: браузер внешности (с нуля)
    "modules/p11_cl_economy.lua",
    "modules/p11_cl_trade.lua",    -- окно обмена/запросов/выбора партнёра (v4.6.9)
    "modules/p11_cl_minigame.lua", -- v4.1
    "modules/p11_cl_duties2.lua",   -- v4.2
    "modules/p11_cl_mutations.lua", -- v4.2
    "modules/p11_cl_tutorial.lua",  -- v4.2
    "modules/p11_cl_chars.lua",     -- v4.3.0: анкета бойца (позывной+описание)
    "modules/p11_cl_donate.lua",    -- v4.8.0: F6 — донат-витрина (плейсхолдер)
    "modules/p11_cl_offer.lua",     -- v4.8.1: особая вакансия — маркер над кадровиком + баннер
    "modules/p11_cl_reports.lua",   -- v4.8.2 «ДОКЛАД»: окно репортов (принять/тп/закрыть)
    "modules/p11_cl_spawnviz.lua",  -- v4.8.4 «ВЫСАДКА»: куб-маркеры точек спавна
    "modules/p11_cl_disguise.lua",  -- v4.8.5 «КРАСНЫЙ ОРЁЛ»: окно кейса маскировки «ЛЕГАТ»
    "modules/p11_cl_thingoffer.lua",-- v4.8.8 «ЛИЧИНА»: красная плашка «особой вакансии» над кадровиком
    "modules/p11_cl_minigames2.lua",-- v4.9.1 «ИГЛА»: стрелка-ползунок — «КРОВЬ-2» и «УКОЛ-С» + окно вердикта
    "modules/p11_cl_chatsel.lua",   -- v4.9.2 «ПРИЁМ»: полоса выбора канала над BonChat (РЕЧЬ/OOC/РАЦИЯ/РЕПОРТ…)
    "modules/p11_sh_bonchatboot.lua", -- v4.8.6 «НАВОДКА»: готовый чат BonChat (MIT) — фронтенд эфира
    "modules/p11_cl_garage.lua",      -- v4.10.0 «ГАРАЖ»: витрина «ПОЛЮС-АВТО» (транспорт LVS)
    "modules/p11_cl_craft.lua",       -- v4.10.0 «ГАРАЖ»: кустарная мастерская (крафт)
    "modules/p11_cl_utility.lua",     -- v4.10.0 «ГАРАЖ»: утилиты выдачи ПОЛЮС-ФЛЮКСА (rank 4+)
    "modules/p11_cl_poi.lua",         -- v4.10.0 «ГАРАЖ»: маяки «куда идти» (подписи точек станции)
    "modules/p11_cl_thingkit.lua",    -- v4.10.0 «ГАРАЖ»: пульт тела Нечто «ЛИЧИНА 3.0» (заменяет меню мутаций)
    "modules/p11_cl_pchat.lua",       -- v4.14.2 «КАЗНА»: ПОЧИНКА — «СВЯЗЬ» теперь РЕАЛЬНО уезжает клиентам (была пропущена в send-листе!)
    "modules/p11_cl_kazna.lua",       -- v4.14.2 «КАЗНА»: окно-ростер казны (💠 ПФ/₽/⏱)
    "modules/p11_cl_capture.lua",     -- v4.16.0 «ЗАХВАТ»: HUD точки РККА↔Орёл (владелец/шкала/бой)
    "modules/p11_cl_medals.lua",       -- v4.19.4 «ПОЧЁТ»: медали — реестр, надголовье, ТАБ, вручение
    "modules/p11_cl_contracts.lua",    -- v4.19.4 «ПОЧЁТ»: окно нарядника + HUD-виджет контрактов
    "modules/p11_cl_clues.lua",        -- v4.20.0 «СЛЕД»: планшет-досье улик НКВД
    "modules/p11_cl_onboard.lua",      -- v4.20.0 «СЛЕД»: плашка онбординга «ПЕРВЫЙ ДЕНЬ»
    "modules/p11_cl_ops.lua",         -- v4.24.0 «РУБЕЖ»: операции — зов сторон/HUD/лидерборд
    "modules/p11_cl_stash.lua",       -- v4.24.0 «РУБЕЖ»: кладмен — маяк закладки
    "modules/p11_cl_raid.lua",        -- v4.24.0 «РУБЕЖ»: рейды — полоса «какие точки чьи»
    "modules/p11_cl_sbor.lua",        -- v5.0.0 «СБОР»: экстренный сбор — баннер причины + маркер места
    "modules/p11_cl_skilltree.lua",    -- v4.21.0 «ДРЕВО»: окно древа службы (C-меню)
    "modules/p11_cl_cuffs.lua",        -- v4.22.0 «ОКОВЫ»: плашка наручников + окно караула
}
for _, f in ipairs(send) do
    AddCSLuaFile(f)
end

include("shared.lua")

util.AddNetworkString("P11_IntroShow")

-- интро при ПЕРВОМ входе за сессию
local introShown = {}
hook.Add("PlayerInitialSpawn", "P11_IntroTrigger", function(ply)
    local sid = ply:SteamID()
    if introShown[sid] then return end
    introShown[sid] = true
    timer.Simple(4, function()
        if IsValid(ply) then
            net.Start("P11_IntroShow")
            net.Send(ply)
        end
    end)
end)

-- ============ СЕРВЕРНЫЕ МОДУЛИ ============

local sv = {
    "modules/p11_sv_anticheat.lua",  -- антиспам/античит: ПЕРВЫМ, оборачивает net.Receive (v4.2)
    "modules/fw_sv_jobs.lua",        -- логика профессий
    "modules/fw_sv_factions.lua",    -- фракции из админки (data/*.json)
    "modules/fw_sv_customjobs.lua",  -- профессии из админки (data/*.json)
    "modules/fw_sv_seed_rkka.lua",   -- v3.8.2: авто-сид пресетов РККА/Наука/Нечто
    "modules/fw_sv_npc.lua",         -- NPC-кадровик
    "modules/fw_sv_setup.lua",       -- точки спавна/ареста
    "modules/fw_sv_punish.lua",      -- арест / рабство / бан
    "modules/fw_sv_mod.lua",         -- варны / мут / кик + ворота прав рангов + журнал
    "modules/fw_sv_ranks.lua",       -- ранги + секретный ключ основателя
    "modules/fw_sv_whitelist.lua",   -- v4.4.0: вайтлист должностей (допуски)
    "modules/fw_sv_emotes.lua",      -- жесты C-меню + меню моделей админов
    "modules/p11_sv_infection.lua",  -- заражение Нечто
    "modules/p11_sv_power.lua",      -- генератор / топливо / блэкаут
    "modules/p11_sv_bloodtest.lua",  -- анализ крови
    "modules/p11_sv_tasks.lua",      -- сменные задачи
    "modules/p11_sv_admin.lua",      -- админ-пульт Нечто
    "modules/p11_sv_radio.lua",      -- рация
    "modules/p11_sv_persist.lua",    -- сохранение станции
    "modules/p11_sv_nechto.lua",     -- Нечто: классы, крик, формы
    "modules/p11_sv_build.lua",      -- строительство: призрачные пропы
    "modules/p11_sv_terminal.lua",   -- сменный терминал + доп-задачи
    "modules/p11_sv_shadowtasks.lua",-- ложные задачи маскировки Нечто
    "modules/p11_sv_command.lua",    -- приказы командира / розыск / репорты
    "modules/p11_sv_shift.lua",      -- распорядок смены + авто-буря
    "modules/p11_sv_cold.lua",       -- переохлаждение: тепло как ресурс (v3.7)
    "modules/p11_sv_thingoffer.lua", -- вакансия Нечто у кадровика, появляется/исчезает (v3.9)
    "modules/p11_sv_economy.lua",    -- рубли: кошелёк, награды, выдача (v4.0)
    "modules/p11_sv_inventory.lua",  -- инвентарь/ларёк/сейф/расстановка (v4.0; v4.6.9 — три пути к ларьку)
    "modules/p11_sv_trade.lua",      -- обмен игрок↔игрок: предметы и рубли лицом к лицу (v4.6.9)
    "modules/p11_sv_wage.lua",       -- оклад службы: казначейство платит по таймеру (v4.6.9)
    "modules/p11_sv_admincmds.lua",  -- /tp /goto /bring /return /cloak /heal /god /ранги (v4.0)
    "modules/p11_sv_activities.lua", -- сменные дела: миниигры/наука/ТО/грязь (v4.1; v4.19.5: патруль вырезан)
    "modules/p11_sv_duties2.lua",    -- повар/грузчик/снабжение/досье/скидка/итоги (v4.2)
    "modules/p11_sv_mutations.lua",  -- мутации Нечто за жертв (v4.2)
    "modules/p11_sv_chars.lua",      -- дело бойца: персонажи + сохранение (v4.3.0)
    "modules/p11_sv_models.lua",     -- выдача моделей: надеть/выдать (v4.4.0, с нуля)
    "modules/p11_sv_chat.lua",       -- чат: /ooc /looc /me /it /report + локальная речь (v4.5.0)
    "modules/p11_sv_spawncore.lua",  -- v4.8.9 «МАЯК»: ЯДРО СПАВНА — прямой GM-путь + страховка с логом
    "modules/p11_sv_arrival.lua",    -- зоны прибытия/точки спавна: хранилище + LVS-грузовик (v4.8.7)
    "modules/p11_sv_playtime.lua",   -- время игры → доступ к профам (v4.5.0; v4.8.0 — честные минуты)
    "modules/p11_sv_voice.lua",      -- 3D-голос + радио-эфир линком (v4.8.1 «ЭФИР»)
    "modules/p11_sv_reports.lua",    -- v4.8.2 «ДОКЛАД»: тикеты репортов (принять/тп/закрыть)
    "modules/p11_sv_announce.lua",   -- v4.18.0 «РЕПРОДУКТОР»: оповещение станции — плашка у всех наверху (net+вкладка F4)
    "modules/p11_sv_cmdlock.lua",    -- v4.8.2 «ДОКЛАД»: замок серверной консоли — только Глава (ранг 16)
    "modules/p11_sv_disguise.lua",   -- v4.8.5 «КРАСНЫЙ ОРЁЛ»: маскировка «ЛЕГАТ» (сервер)
    "modules/p11_sh_bonchatboot.lua", -- v4.8.6 «НАВОДКА»: готовый чат BonChat (MIT) — серверная база
    "modules/p11_sv_thingcore.lua",   -- v4.8.8 «ЛИЧИНА»: ядро Нечто — автомаскировка после убийства (с чистого листа)
    "modules/p11_sv_medics.lua",      -- v4.8.8 «ЛИЧИНА»: мед-регламент (шприц — только «Учёному»)
    "modules/p11_sv_killfeed.lua",    -- v4.8.8 «ЛИЧИНА»: киллфид выключен
    "modules/p11_sv_promo.lua",       -- v4.9.0 «ТАЛОН»: промокоды (F6/!промо/p11_promo), антиперебор, журнал
    "modules/p11_sv_donor.lua",       -- v4.9.2 «ПРИЁМ»: донат-мост магазина (p11_donorvip, оффлайн-очередь)
    "modules/p11_sv_garage.lua",      -- v4.10.0 «ГАРАЖ»: торговец транспортом LVS «ПОЛЮС-АВТО»
    "modules/p11_sv_craft.lua",       -- v4.10.0 «ГАРАЖ»: кустарная мастерская (крафт, 12 рецептов с v4.11.0)
    "modules/p11_sv_loot.lua",        -- v4.11.0 «КУЗНЯ»: лутабельные ящик/бочка/тайник + верстак + p11_lootspawn
    "modules/p11_sv_nogen.lua",       -- v4.12.0 «ОТБОЙ»: генератор ВЫРЕЗАН из игры наглухо (глушитель спавна)
    "modules/p11_sv_donate2.lua",     -- v4.10.0 «ГАРАЖ»: донат-валюта «ПОЛЮС-ФЛЮКС» + витрина + утилиты выдачи
    "modules/p11_sv_kazna.lua",       -- v4.14.2 «КАЗНА»: единая казна трёх валют (ПФ/₽/⏱) — ростер + оффлайн p11_kaznagive
    "modules/p11_sv_nospray.lua",     -- v4.14.3 «ЗАРЯД»: спреи на станции выключены наглухо (заявка «убери возможность ставить спрей»)
    "modules/p11_sv_thingkit.lua",    -- v4.10.0 «ГАРАЖ»: НЕЧТО «ЛИЧИНА 3.0» — подменяет ядра маскировки/поглощения
    "modules/p11_sv_medals.lua",      -- v4.19.4 «ПОЧЁТ»: медали — реестр, права выдачи, доска
    "modules/p11_sv_contracts.lua",   -- v4.19.4 «ПОЧЁТ»: НПС-нарядник — контракты часа (после цепи TaskEvent!)
    "modules/p11_sv_sinks.lua",       -- v4.20.0 «СЛЕД»: стоки экономики — штраф НКВД/аренда сейфа/ночной тариф
    "modules/p11_sv_clues.lua",       -- v4.20.0 «СЛЕД»: улики на месте поглощения → досье НКВД (!улики)
    "modules/p11_sv_onboard.lua",     -- v4.20.0 «СЛЕД»: онбординг «ПЕРВЫЙ ДЕНЬ» — 5 шагов новичку (после контрактов!)
    "modules/p11_sv_skilltree.lua",   -- v4.21.0 «ДРЕВО»: уровень за дела + древо РККА/Учёные (после цепи TaskEvent!)
    "modules/p11_sv_ops.lua",         -- v4.24.0 «РУБЕЖ»: ОПЕРАЦИИ — админ-ивент СССР/АМЕРИКА (после skilltree!)
    "modules/p11_sv_stash.lua",       -- v4.24.0 «РУБЕЖ»: криминал-кладмен (миниигра activities уже выше)
    "modules/p11_sv_raid.lua",        -- v4.24.0 «РУБЕЖ»: РЕЙДЫ — терминал, 3 точки прорыва (после операций!)
    "modules/p11_sv_sbor.lua",        -- v5.0.0 «СБОР»: экстренный сбор (/сбор <причина> — место, перекличка)
    "modules/p11_sv_cuffs.lua",       -- v4.22.0 «ОКОВЫ»: наручники, поводок конвоя, оформление у караула
    "modules/p11_sv_thingmind.lua",   -- v4.19.4 «ПОЧЁТ»: разум жертвы — навыки по профе жертвы
    -- v4.30.2 «ЯСНОСТЬ»: ПОГОДА ВРЕМЕННО ВЫРЕЗАНА по заявке владельца (модуль p11_sv_weather.lua
    -- изъят из сборки; вернуть = вернуть файл из истории Git (ветка v4.28.0 «МЕТЕО») + строку сюда)
    "modules/p11_sv_thingroot.lua",   -- v4.13.0 «КОРЕНЬ»: НЕЧТО неумирает до рестарта + полная маскировка — ВСЕГДА ПОСЛЕДНИЙ
}

local function Safe(f)
    local ok, err = pcall(include, f)
    if not ok then
        print("[POLUS][ERROR] " .. f .. " -> " .. tostring(err))
    end
    return ok
end

local loaded = 0
for _, f in ipairs(sv) do
    if Safe(f) then loaded = loaded + 1 end
end

-- ============ ИНИЦИАЛИЗАЦИЯ ============

function GM:Initialize()
    self.BaseClass:Initialize()
    print("============================================================")
    print("  POLUS-11 RP | сборка " .. tostring(POLUS_BUILD)
        .. " | P11FW v" .. tostring(P11FW.Version)
        .. " | POLUS11 v" .. tostring(POLUS11.Version))
    print("  Серверные модули: " .. loaded .. "/" .. #sv
        .. " | профессий: " .. (#(P11FW.JobIds or {})))
    print("============================================================")
end

-- баннер при входе игрока
hook.Add("PlayerInitialSpawn", "P11_Banner", function(ply)
    timer.Simple(8, function()
        if IsValid(ply) then
            ply:ChatPrint("[POLUS-11 v" .. tostring(POLUS11.Version) .. "] Станция активна. Админ: !пульт | /r — рация | F4 — должности")
        end
    end)
end)

-- статус-диагностика: polus_status (или старое polus11_status) в консоль
local function PrintStatus(ply)
    local out = {}
    out[#out + 1] = "== POLUS-11 RP | сборка " .. tostring(POLUS_BUILD) .. " =="
    out[#out + 1] = "  P11FW v" .. tostring(P11FW.Version) .. " / POLUS11 v" .. tostring(POLUS11.Version)
    out[#out + 1] = "  карта: " .. game.GetMap() .. " | игроков: " .. player.GetCount()
    for cls in pairs({
        polus11_generator = true, polus11_fuelbarrel = true,
        polus11_labtable = true, polus11_vial = true, polus11_acidspit = true,
        polus_fw_jobnpc = true, polus11_terminal = true,
    }) do
        out[#out + 1] = "  энтити " .. cls .. ": " .. #ents.FindByClass(cls)
    end
    for _, p in ipairs(player.GetAll()) do
        out[#out + 1] = "  • " .. p:Nick()
            .. " [" .. (P11FW.GetJobName and P11FW.GetJobName(p) or "?") .. "]"
            .. (p:GetNWBool("P11_Infected", false)
                and " [НЕЧТО" .. (p:GetNWBool("P11_InfActive", false) and "+актив" or ", инкубация") .. "]"
                or "")
    end
    local text = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end

concommand.Add("polus_status", function(ply) PrintStatus(ply) end)
concommand.Add("polus11_status", function(ply) PrintStatus(ply) end) -- совместимость

-- ============================================================
--  v4.8.9 «МАЯК»: ПРЯМОЙ ПУТЬ СПАВНА — оверрайд GM-функции.
--  Движок зовёт GM:PlayerSelectSpawn при КАЖДОМ спавне/респавне
--  и ставит бойца в координаты вернувшейся сущности. Точку
--  решает ядро (p11_sv_spawncore: POLUS11.SpawnResolve), а якорь
--  двигает POLUS11.SpawnAnchor. Своей точки нет — вежливо
--  отдаём выбор базовому (sandbox) коду.
-- ============================================================
function GM:PlayerSelectSpawn(ply, transition)
    if not transition and POLUS11 and POLUS11.SpawnResolve then
        local r = POLUS11.SpawnResolve(ply)
        if r then
            local pos = POLUS11.SpawnNudge and POLUS11.SpawnNudge(ply, r.pos) or r.pos
            local anchor = POLUS11.SpawnAnchor and POLUS11.SpawnAnchor(ply, pos, r.ang)
            if IsValid(anchor) then
                if P11FW and P11FW.Log then
                    P11FW.Log("СПАВН (GM-путь): " .. ply:Nick() .. " → " .. r.why)
                end
                return anchor
            end
        end
    end
    return self.BaseClass:PlayerSelectSpawn(ply, transition)
end
