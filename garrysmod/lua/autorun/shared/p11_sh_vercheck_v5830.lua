-- ============================================================
--  ПОЛЮС-11 — ДИАГНОСТИКА ВЕРСИИ v5.8.30 (НОВЫЙ ФАЙЛ, autorun/shared)
-- ============================================================
--  ЗАЧЕМ: в консоли сервера при загрузке по-прежнему печатаются строки
--  СТАРЫХ файлов — «v5.8.28: ХП профы…», «v5.8.20: временный VIP…»,
--  «v5.8.14: !профа…». Старые файлы по правилу владельца не удаляются,
--  поэтому по таким строкам НЕЛЬЗЯ понять, какая сборка стоит.
--  Единственный источник правды — POLUS_BUILD и наличие новых модулей.
--
--  КОМАНДА:  p11_ver   (консоль сервера или консоль клиента, ~)
--  Показывает: версию, гейммод, какие модули v5.8.29/v5.8.30 реально
--  загружены, жив ли замок версии, права на ранги, файл конфига.
--
--  Откат: удалить этот файл.
-- ============================================================

local BUILD = "5.8.30"

-- файлы, которые должны быть на сервере (путь от garrysmod/)
local FILES = {
    ["v5.8.29  сбор (сервер)"]        = "gamemodes/darkrp/gamemode/modules/p11_sv_sbor_v2.lua",
    ["v5.8.29  ключ основателя"]      = "lua/autorun/server/p11_sv_founderkey_v5829.lua",
    ["v5.8.29  метки на функциях"]    = "lua/autorun/server/p11_sv_funcmeta_v5829.lua",
    ["v5.8.29  !профа"]               = "lua/autorun/server/p11_sv_profa_lock_v5829.lua",
    ["v5.8.29  дежурство/АФК"]        = "lua/autorun/server/p11_sv_duty_afk_v5829.lua",
    ["v5.8.29  версия"]               = "lua/autorun/shared/p11_sh_version_v5829.lua",
    ["v5.8.30  Задача 1 (ранги)"]     = "lua/autorun/server/p11_sv_rankgate_v5830.lua",
    ["v5.8.30  Задача 2 (Esc)"]       = "lua/autorun/client/p11_cl_escfix2_v5830.lua",
    ["v5.8.30  версия"]               = "lua/autorun/shared/p11_sh_version_v5830.lua",
    ["v5.8.30  замок версии"]         = "lua/autorun/shared/p11_sh_versionlock_v5830.lua",
}

local function Line(t) return t end

local function Report(ply)
    local out = {}
    out[#out + 1] = "================ ПОЛЮС-11 · ДИАГНОСТИКА ================"
    out[#out + 1] = "  POLUS_BUILD ................ " .. tostring(POLUS_BUILD)
    out[#out + 1] = "  ожидание пакета ............ " .. BUILD
    out[#out + 1] = "  гейммод .................... " ..
        tostring(engine and engine.ActiveGamemode and engine.ActiveGamemode() or "?")
    out[#out + 1] = "  realm ...................... " .. (SERVER and "СЕРВЕР" or "КЛИЕНТ")

    -- итог замка версии: смотрим на РЕЗУЛЬТАТ, а не на наличие таймера
    -- (таймер замка живёт 30 секунд и потом честно disappears)
    out[#out + 1] = "  версия совпадает с пакетом . " .. tostring(tostring(POLUS_BUILD) == BUILD)

    if SERVER then
        -- файлы на диске
        out[#out + 1] = "  --- файлы пакета ---"
        for label, path in pairs(FILES) do
            out[#out + 1] = string.format("    %-28s %s", label,
                file.Exists(path, "GAME") and "ЕСТЬ" or "НЕТ")
        end

        -- Задача 1: права на ранги
        out[#out + 1] = "  --- Задача 1: выдача рангов ---"
        out[#out + 1] = "    P11FW.RankGateCheck ...... " .. tostring(P11FW and P11FW.RankGateCheck ~= nil)
        local allow = P11FW and P11FW.RankGate and P11FW.RankGate.allow
            and P11FW.RankGate.allow.staff_leader
        out[#out + 1] = "    разрешено Staff Leader ... " ..
            (istable(allow) and table.concat(allow, ", ") or "СПИСОК НЕ ЗАГРУЖЕН")
        local deny = P11FW and P11FW.RankGate and P11FW.RankGate.deny
            and P11FW.RankGate.deny.staff_leader
        out[#out + 1] = "    admin в жёстком deny ..... " .. tostring(deny and deny["admin"] == true)
        out[#out + 1] = "    min_level для admin ...... " ..
            tostring(P11FW and P11FW.RankGate and P11FW.RankGate.min_level
                and P11FW.RankGate.min_level["admin"])
        out[#out + 1] = "    конфиг rank_grant.json ... " ..
            tostring(file.Exists("polus_framework/rank_grant.json", "DATA"))
        out[#out + 1] = "    журнал rank_grant.log .... " ..
            tostring(file.Exists("polus_framework/rank_grant.log", "DATA"))
        out[#out + 1] = "    ключ основателя .......... " ..
            tostring(file.Exists("polus11/founder.key", "DATA") and "с сервера (data/)" or "НЕ СОЗДАН")

        -- Задача 2 (клиентская часть видна только с клиента, но хук снятия — здесь)
        out[#out + 1] = "  --- Задача 2: Esc/E-меню ---"
        out[#out + 1] = "    блокиратор v5.8.28 снят .. " ..
            tostring(not (hook.GetTable().OnPauseMenuShow
                and hook.GetTable().OnPauseMenuShow["P11.EscFix.v5828"]))
    else
        out[#out + 1] = "  --- Задача 2: Esc/E-меню (клиент) ---"
        local th = hook.GetTable().Think or {}
        out[#out + 1] = "    сторож ввода v5.8.30 ..... " ..
            tostring(th["P11.EscFix2.Watchdog.v5830"] ~= nil)
        out[#out + 1] = "    хук меню паузы v5.8.30 ... " ..
            tostring((hook.GetTable().OnPauseMenuShow or {})["P11.EscFix2.Pause.v5830"] ~= nil)
        out[#out + 1] = "    блокиратор v5.8.28 снят .. " ..
            tostring(not (hook.GetTable().OnPauseMenuShow or {})["P11.EscFix.v5828"])
        out[#out + 1] = "    курсор сейчас ............ " ..
            tostring(vgui and vgui.CursorVisible and vgui.CursorVisible())
    end

    -- вердикт
    local ok = tostring(POLUS_BUILD) == BUILD
    out[#out + 1] = "  ----------------------------------------------------"
    out[#out + 1] = ok
        and "  ВЕРДИКТ: стоит сборка " .. BUILD
        or "  ВЕРДИКТ: стоит НЕ " .. BUILD .. " (POLUS_BUILD = " .. tostring(POLUS_BUILD) .. ")"
    out[#out + 1] = "========================================================"

    local txt = table.concat(out, "\n")
    print(txt)
    if IsValid(ply) and ply.PrintMessage then
        ply:PrintMessage(HUD_PRINTCONSOLE, txt)
        ply:ChatPrint("[ПОЛЮС-11] " .. (ok and ("сборка " .. BUILD)
            or ("ВНИМАНИЕ: стоит " .. tostring(POLUS_BUILD) .. ", а не " .. BUILD))
            .. " — подробности в консоли (p11_ver)")
    end
    return txt
end

concommand.Add("p11_ver", function(ply)
    if IsValid(ply) and P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) < 2 then
        ply:ChatPrint("[ПОЛЮС-11] Диагностика доступна с ранга Helper и выше (или из консоли сервера).")
        return
    end
    Report(ply)
end)

-- поздний баннер: чтобы ПОСЛЕ всех старых «v5.8.xx» строк в консоли
-- последней была текущая сборка
local function Banner()
    print("========================================================")
    print("[POLUS-11] СБОРКА " .. tostring(POLUS_BUILD) .. "  (ожидалось " .. BUILD .. ")")
    print("[POLUS-11] строки «v5.8.28 …» выше — это СТАРЫЕ файлы, они не")
    print("[POLUS-11] удалены по правилу владельца и на версию не влияют.")
    print("[POLUS-11] диагностика: p11_ver")
    print("========================================================")
end

hook.Add("InitPostEntity", "P11.VerBanner.v5830", function()
    timer.Simple(14, Banner)
    timer.Simple(21, Banner)
end)
timer.Simple(0, function()
    if tostring(POLUS_BUILD) ~= BUILD then return end
end)
