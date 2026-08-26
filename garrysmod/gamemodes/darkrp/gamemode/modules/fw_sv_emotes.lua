-- ============================================================
--  ПОЛЮС FRAMEWORK — ЖЕСТЫ И АНИМАЦИИ (server) v1.7
--  C-меню игроков шлёт id жеста → движковая анимация всем видна.
--  Здесь же: админская смена себе модели (меню моделей из C-меню).
-- ============================================================

util.AddNetworkString("P11_Emote")
util.AddNetworkString("P11_AdminModel")

-- соответствие id (как на клиенте) → движковый жест
local EMOTES = {
    [1] = { act = ACT_GMOD_GESTURE_WAVE,      name = "машет рукой" },
    [2] = { act = ACT_GMOD_GESTURE_SALUTE,    name = "отдаёт салют" },
    [3] = { act = ACT_GMOD_GESTURE_AGREE,     name = "кивает «да»" },
    [4] = { act = ACT_GMOD_GESTURE_DISAGREE,  name = "мотает головой «нет»" },
    [5] = { act = ACT_GMOD_GESTURE_BECON,     name = "зовёт «сюда!»" },
    [6] = { act = ACT_GMOD_TAUNT_CHEER,       name = "ликует" },
    [7] = { act = ACT_GMOD_GESTURE_ITEM_GIVE, name = "протягивает предмет" },
    [8] = { act = ACT_GMOD_GESTURE_ITEM_PLACE, name = "укладывает предмет" },
}
P11FW.Emotes = EMOTES

net.Receive("P11_Emote", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local id = net.ReadUInt(4)
    local em = EMOTES[id]
    if not em then return end

    -- арестованный/раб жестами не размахивает
    if P11FW.IsPunished and P11FW.IsPunished(ply) then return end

    ply.P11_EmoteNext = ply.P11_EmoteNext or 0
    if CurTime() < ply.P11_EmoteNext then return end
    ply.P11_EmoteNext = CurTime() + 1.4

    ply:DoAnimationEvent(em.act)
end)

-- ============ АДМИН: СМЕНИТЬ СЕБЕ МОДЕЛЬ (меню «моделек») ============

net.Receive("P11_AdminModel", function(len, ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end
    local mdl = string.lower(string.sub(string.Trim(net.ReadString() or ""), 1, 80))
    if mdl == "" then return end

    ply.P11_ModelNext = ply.P11_ModelNext or 0
    if CurTime() < ply.P11_ModelNext then return end
    ply.P11_ModelNext = CurTime() + 0.8

    -- только плеер-модели (без анимационных странностей пропов)
    if not string.find(mdl, "models/player/", 1, true) then
        P11FW.Notify(ply, "Только модели из models/player/.")
        return
    end
    -- v3.9: серверу файл не обязателен (воркшоп-модель видят клиенты с паком).
    -- Если файла нет — ставим всё равно, но честно предупреждаем про ERROR
    -- у игроков без пака.
    local serverHas = file.Exists(mdl, "GAME")
    if serverHas then util.PrecacheModel(mdl) end
    ply:SetModel(mdl)
    if serverHas then
        P11FW.Notify(ply, "Внешность изменена (до смены должности/респавна).")
    else
        P11FW.Notify(ply, "Внешность изменена. ВНИМАНИЕ: файла на сервере нет — игроки без пака видят ERROR!")
    end
    if P11FW.ModLog then P11FW.ModLog("model", ply, ply, mdl) end
end)

-- сброс обратно к модели должности
concommand.Add("p11_wt_modelreset", function(ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end
    if GAMEMODE and GAMEMODE.PlayerSetModel then
        GAMEMODE:PlayerSetModel(ply)
    end
    P11FW.Notify(ply, "Внешность возвращена к модели должности.")
end)
