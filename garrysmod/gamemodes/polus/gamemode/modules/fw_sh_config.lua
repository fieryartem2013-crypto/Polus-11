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

    -- с какого ранга можно выдавать ранги другим (и открывать меню выдачи)
    RankManageLevel = 5, -- Куратор+

    -- после скольких ВАРНОВ игрока автоматически КИКАЕТ с сервера
    AutoKickWarns = 3,

    -- Должность по умолчанию (все заходят ей, «увольнение» тоже сюда)
    DefaultJob = "recruit",

    -- Снимать ВСЁ оружие при смене должности (потом выдаётся базовый набор + должностное)
    StripOnJobChange = true,

    -- Базовый набор, который выдаётся КАЖДОМУ:
    -- v1.5: кулаки (самооборона) + физган (крутить СВОИ призрачные пропы;
    -- чужое/мировое не-админу не поднять — режет GM:PhysgunPickup)
    BaseLoadout = {
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
