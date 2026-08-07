-- ============================================================
--  ПОЛЮС-11 — ЗАМОК СЕРВЕРНОЙ КОНСОЛИ (server) v4.8.2 «ДОКЛАД»
--  Заявка владельца: «консолькой могут пользоваться Узеры —
--  только Глава может, должен».
--
--  ЧТО ДЕЛАЕТ: когда p11_cmdlock 1 (ПО УМОЛЧАНИЮ ВКЛ.), все
--  серверные консольные команды сборки (p11_* и polus_*) требуют
--  ранг 16 — «Глава Полюса-11». Хозяйка сервера (сама srcds-
--  консоль, IsValid(ply)=false) пускается всегда.
--
--  ПУБЛИЧНЫЕ (открыты всем сознательно — иначе сервер встанет):
--   p11_access    — вход основателя по секретному слову
--   p11_playtime  — кадровая книжка (своё время)
--   p11_report    — отправка жалобы
--   p11_reports   — окно жалоб
--   p11_promo     — погашение талона-промокода (v4.9.0)
--   polus_fw_jobs — список профессий
--   polus_status / polus11_status — технический статус
--
--  Это ВНЕШНИЙ замок поверх внутренних проверок модулей: они
--  продолжают работать и при p11_cmdlock 0 (например, p11_rank
--  по-прежнему требует CanManageRank, телепорты — свой порог).
--  Выключить замок: p11_cmdlock 0 в консоли сервера.
-- ============================================================

local cvLock = CreateConVar("p11_cmdlock", "1", FCVAR_ARCHIVE,
    "1 = серверные команды p11_*/polus_* (кроме публичных) только с ранга 16 (Глава Полюса-11)")

local PUBLIC = {
    ["p11_access"] = true,
    ["p11_playtime"] = true,
    ["p11_report"] = true,
    ["p11_reports"] = true,
    ["polus_fw_jobs"] = true,
    ["polus_status"] = true,
    ["polus11_status"] = true,
    ["p11_promo"] = true, -- v4.9.0 «ТАЛОН»: погашение промокода — открыто всем игрокам
    ["p11_voiceradio"] = true, -- v4.9.2 «ПРИЁМ»: самопроверка рации — открыта всем
    ["p11_takeoffer"] = true, -- v4.9.3 «ГРОШ»: взятие особой вакансии Нечто — игрокам разрешено
    ["p11_thingtest"] = true, -- v4.10.0 «ГАРАЖ»: самодиагностика Нечто «почему маскировка молчит» — игрокам разрешена
}

local function RankOf(ply)
    if P11FW.GetRankLevel then return P11FW.GetRankLevel(ply) end
    return 0
end

local function Gated(orig)
    return function(ply, cmd, args, argStr)
        if IsValid(ply) and cvLock:GetBool() and RankOf(ply) < 16 then
            if POLUS11.Notify then
                POLUS11.Notify(ply, "Консоль станции — только для Главы Полюса-11 (ранг 16).")
            end
            if P11FW.ModLog then
                P11FW.ModLog("cmdlock", ply, nil, "попытка: " .. tostring(cmd))
            end
            return
        end
        return orig(ply, cmd, args, argStr)
    end
end

local function WrapAll()
    local wrapped = 0
    local tab = concommand.GetTable()
    for name, val in pairs(tab) do
        if (string.StartWith(name, "p11_") or string.StartWith(name, "polus_"))
            and not PUBLIC[name] then
            local cb = isfunction(val) and val
                or (istable(val) and (val.Callback or val[1]))
            if isfunction(cb) and not (istable(val) and val.P11CmdLocked) then
                concommand.Add(name, Gated(cb))
                wrapped = wrapped + 1
            end
        end
    end
    print("[POLUS-11] p11_cmdlock: замок на серверной консоли (заперто команд: "
        .. wrapped .. ") — доступ с ранга 16; выкл: p11_cmdlock 0")
end

-- когда все модули встали на ноги
hook.Add("InitPostEntity", "P11.CmdLock", function()
    timer.Simple(1, WrapAll)
end)
hook.Add("PostGamemodeLoaded", "P11.CmdLockLate", function()
    timer.Simple(2, WrapAll)
end)
