-- ============================================================
--  ПОЛЮС FRAMEWORK — конфигурация
-- ============================================================

P11FW = P11FW or {}

P11FW.Config = {

    -- Кто админ (команды, админ-меню, спавны и т.п.).
    -- v1.5: уровень считается по РАНГУ (fw_sh_ranks): нужен level >= AdminLevel,
    -- плюс старый дедовский GMod-флаг admin/superadmin тоже принимается.
    AdminLevel = 2, -- 0=User 1=VIP 2=Хелпер 3=Модератор 4=Админ (см. P11FW.Ranks)
    Admin = function(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() or ply:IsAdmin() then return true end
        if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= (P11FW.Config.AdminLevel or 2) then
            return true
        end
        return false
    end,

    -- СЕКРЕТНЫЙ КЛЮЧ ОСНОВАТЕЛЯ: p11_access <ключ> в консоли (от лица
    -- своего игрока, НЕ через rcon) → ранг «Глава Полюса-11» + superadmin.
    -- ЗНАЧЕНИЕ ХРАНИ В ТАЙНЕ. Сменить можно здесь же, в любой момент.
    FounderKey = "АрчиславКрутойПарень2013",

    -- с какого ранга можно выдавать ранги другим (и открывать меню выдачи,
    -- вкладку АДМИНКИ, чат-команду /ранги):
    -- v4.5.0 по заявке владельца — «Глава и все ВЫШЕ/С Куратора»: 12 = Curator+.
    -- Хочешь «строго выше Куратора» — поставь 13.
    RankManageLevel = 12,
    -- v4.6.7: вайтлист-профы (НКВД и др.) ПОЛНОСТЬЮ скрыты из F4 у
    -- игроков без допуска. false = показывать карточку с замком 🔒.
    HideWhitelistJobs = true,

    -- v3.8.2: с какого ранга разрешено БРАТЬ ивентовые должности
    -- (event=true, напр. формы Нечто из авто-сида fw_sv_seed_rkka).
    EventJobRankLevel = 4, -- Administrator+

    -- после скольких ВАРНОВ игрока автоматически КИКАЕТ с сервера
    AutoKickWarns = 3,

    -- v3.8.2: при первом запуске завезти ПРЕСЕТНЫЕ фракции/должности
    -- (РККА по списку владельца + научный блок + ивентовые Нечто-формы).
    -- Лежат в modules/fw_sv_seed_rkka.lua, меняются из админки (ПРАВКА).
    -- false — не завозить (уже завезённые НЕ удаляются — снеси в админке).
    SeedRkkaPresets = true,

    -- Должность по умолчанию (все заходят ей, «увольнение» тоже сюда)
    DefaultJob = "recruit",

    -- Снимать ВСЁ оружие при смене должности (потом выдаётся базовый набор + должностное)
    StripOnJobChange = true,

    -- Базовый набор, который выдаётся КАЖДОМУ:
    -- v1.6: ПУСТЫЕ РУКИ (знак мира) + ДОКУМЕНТЫ с уникальным кодом.
    -- v1.5: кулаки (самооборона) + физган (только свои призрачные пропы).
    BaseLoadout = {
        "weapon_polus11_hands",
        "weapon_polus11_docs",
        "weapon_polus11_fists",
        "weapon_physgun",
    },

    -- Инструменты настройки карты — выдаются ТОЛЬКО админам
    AdminLoadout = {
        "weapon_physgun",
        "gmod_tool",
        "weapon_physcannon",
        "gmod_camera",
    },

    -- Показывать текущую должность справа сверху на экране
    ShowJobHud = true,

    -- ============ ВОРКШОП-ПАКИ МОДЕЛЕЙ (v3.8) ============
    -- Если модели отображаются розовыми ERROR — у игроков нет этих
    -- файлов. Впиши сюда ID паков мастерской Steam Workhop (числа
    -- из конца ссылки пака) — сервер сам отошлёт всем клиентам:
    -- НАПРИМЕР: WorkshopAddons = { "2844920846", "2857618770" },
    WorkshopAddons = {
        -- "1234567890", -- пак плеер-моделей lt_c (укажи его ID!)
    },

    -- Чат-команды: !работа / !job / !f4 — открыть меню профессий
    ChatMenuCommands = true,

    -- ============ NPC-КАДРОВИК ============
    NPCModel       = "models/player/barney.mdl",
    NPCName        = "ДЕЖУРНЫЙ ПО ЛИЧНОМУ СОСТАВУ",
    NPCPersist     = true,  -- сохранять NPC на карту (переживает рестарт)
    NPCGazeDistance = 260,  -- с какой дистанции NPC поворачивается к игроку
}

-- Тихий вывод сообщений (использует DarkRP.notify, если вдруг он стоит)
function P11FW.Notify(ply, msg)
    if not IsValid(ply) then return end
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, 1, 4, msg)
    else
        ply:ChatPrint("[Личный состав] " .. msg)
    end
end

function P11FW.Log(msg)
    print("[P11FW] " .. msg)
end
