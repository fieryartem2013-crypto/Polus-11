-- ============================================================
--  ПОЛЮС FRAMEWORK — конфигурация
-- ============================================================

P11FW = P11FW or {}

P11FW.Config = {

    -- Кто админ (для команд выдачи/снятия должностей и спавна кадровика)
    Admin = function(ply)
        return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsAdmin())
    end,

    -- Должность по умолчанию (все заходят ей, «увольнение» тоже сюда)
    DefaultJob = "recruit",

    -- Снимать ВСЁ оружие при смене должности (потом выдаётся базовый набор + должностное)
    StripOnJobChange = true,

    -- Базовый набор, который выдаётся КАЖДОМУ (в гейммод-издании пусто:
    -- полный голый RP, инструменты — только админам, см. AdminLoadout)
    BaseLoadout = {},

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
