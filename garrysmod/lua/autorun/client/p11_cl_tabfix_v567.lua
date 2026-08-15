-- ============================================================
--  ПОЛЮС-11 — ФИКС TAB (состав станции) v5.6.7 (client, autorun)
--  Владелец: «в TAB не видно игроков (я вижу других нет)».
--
--  ПРИЧИНА: оригинальный ScoreboardShow-хук "P11.Board" при открытии
--  TAB вызывает net.Start("P11_MedalAct") + net.SendToServer() —
--  запрос пересинка МЕДАЛЕЙ. Но медали ВЫРЕЗАНЫ, канал не
--  зарегистрирован на клиенте → net.Start бросает ошибку →
--  ScoreboardShow падает → TAB не открывается / пустой.
--
--  РЕШЕНИЕ: переопределяем хук "P11.Board" на нашу версию —
--  тот же код, НО без медального net-запроса. Старые файлы не
--  трогаем (обёртка поверх hook.GetTable).
-- ============================================================

local ok, err = pcall(function()
    -- наш новый обработчик ScoreboardShow
    local function NewBoard()
        if DarkRP then return end
        if POLUS11 and POLUS11.Config and POLUS11.Config.CustomScoreboard == false then return end
        P11B.open   = true
        -- v5.6.7: медальный пересинк ВЫРЕЗАН (медали вырезаны — канал мёртв)
        P11B.fails  = 0
        P11B.scroll = 0
        P11B.openT  = CurTime()
        P11B.t      = 0 -- форсировать снимок на первом же кадре
        POLUS11.Scoreboard = nil
        gui.EnableScreenClicker(true)
        surface.PlaySound("ui/buttonclickrelease.wav")
    end

    -- заменяем хук в таблице (не трогая файл гейммода)
    local t = hook.GetTable()
    local sb = t and t["ScoreboardShow"]
    if sb then
        sb["P11.Board"] = NewBoard
        print("[POLUS-11] ФИКС TAB v5.6.7: медальный net-запрос при открытии убран — TAB работает")
    else
        print("[POLUS-11][TAB] ScoreboardShow-хуки не найдены")
    end
end)
if not ok then
    print("[POLUS-11][TAB] ошибка: " .. tostring(err))
end
