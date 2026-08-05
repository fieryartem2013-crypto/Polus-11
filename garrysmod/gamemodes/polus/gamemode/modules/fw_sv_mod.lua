-- ============================================================
--  ПОЛЮС FRAMEWORK — МОДЕРАЦИЯ (server) v1.6
--  Варны (с авто-киком), мут чата, кик, централизованная
--  проверка прав/лимитов наказаний по рангам (fw_sh_ranks.lua),
--  журнал всех действий админов в data/polus_framework/modlog.txt.
--  Сами арест/рабство/бан живут в fw_sv_punish.lua — этот модуль
--  является «воротами» P11FW.RequestPunish(...) для них.
-- ============================================================

local WARNS_FILE = "polus_framework/warns.json"
local MUTES_FILE = "polus_framework/mutes.json"
local LOG_FILE   = "polus_framework/modlog.txt"

P11FW.Warns = P11FW.Warns or {} -- sid -> { {reason=..., by=..., at=...}, ... }
P11FW.Mutes = P11FW.Mutes or {} -- sid -> { Until=..., reason=..., by=..., nick=... }

util.AddNetworkString("P11FW_ModToast")

-- ============ ФАЙЛЫ ============

local function EnsureDir()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
end

local function SaveWarns() EnsureDir() file.Write(WARNS_FILE, util.TableToJSON(P11FW.Warns, true)) end
local function SaveMutes() EnsureDir() file.Write(MUTES_FILE, util.TableToJSON(P11FW.Mutes, true)) end

local function LoadAll()
    local raw = file.Read(WARNS_FILE, "DATA")
    P11FW.Warns = (raw and util.JSONToTable(raw)) or {}
    if not istable(P11FW.Warns) then P11FW.Warns = {} end

    local raw2 = file.Read(MUTES_FILE, "DATA")
    P11FW.Mutes = (raw2 and util.JSONToTable(raw2)) or {}
    if not istable(P11FW.Mutes) then P11FW.Mutes = {} end
end

hook.Add("InitPostEntity", "P11FW.ModLoad", function()
    timer.Simple(0.35, LoadAll)
end)

local function SidOf(ply)
    local s = ply:SteamID64()
    return (s and s ~= "0") and s or ply:SteamID()
end

-- ============ ЖУРНАЛ МОДЕРАЦИИ ============

function P11FW.ModLog(action, by, target, extra)
    local byName = IsValid(by) and (by:Nick() .. " [" .. by:SteamID() .. "]") or "СЕРВЕР/КОНСОЛЬ"
    local tgName = IsValid(target) and (target:Nick() .. " [" .. SidOf(target) .. "]") or tostring(target or "?")
    local line = os.date("[%d.%m.%Y %H:%M:%S] ")
        .. string.upper(tostring(action)) .. " | кто: " .. byName
        .. " | цель: " .. tgName
        .. (extra and (" | " .. tostring(extra)) or "")
    EnsureDir()
    file.Append(LOG_FILE, line .. "\n")
    print("[P11FW][MOD] " .. line)
end

-- ============ ТОСТ ИГРОКУ (красная плашка по центру) ============

function P11FW.ModToast(ply, text, kind)
    if not IsValid(ply) then return end
    net.Start("P11FW_ModToast")
        net.WriteString(string.sub(tostring(text), 1, 240))
        net.WriteString(kind or "warn") -- warn / mute / kick / ban / info
    net.Send(ply)
end

local function BroadcastMod(text)
    for _, p in ipairs(player.GetAll()) do
        p:ChatPrint("[ПОЛЮС-11] " .. text)
    end
end

-- ============ ЦЕНТРАЛЬНЫЕ ВОРОТА НАКАЗАНИЙ ============
-- Возвращает true, reason/применённый_срок — или false, причина отказа.
-- by = nil → консоль (безлимит). ptype: arrest/slavery/ban.

function P11FW.RequestPunish(by, target, ptype, minutes, reason)
    if not (IsValid(target) and target:IsPlayer()) then
        return false, "игрок не найден"
    end
    minutes = math.max(0, math.floor(tonumber(minutes) or 0))
    reason = (reason and string.Trim(reason) ~= "") and string.Trim(reason) or "без причины"

    -- консоль сервера — бог
    if not IsValid(by) then
        P11FW.Punish(target, ptype, minutes, reason, nil)
        P11FW.ModLog(ptype, nil, target, reason .. " | срок: " .. P11FW.FmtMinutes(minutes))
        return true, "применено (консоль)", minutes
    end

    local kind = (ptype == "ban") and "ban" or "arrest"

    -- право на действие
    if not P11FW.CanMod(by, kind) then
        local need = P11FW.PermLevel[kind] or 99
        local needName = "?"
        for _, r in ipairs(P11FW.Ranks) do
            if r.level == need then needName = r.name break end
        end
        return false, "нужен ранг " .. needName .. "+ (действие: " .. kind .. ")"
    end

    -- иерархия: нельзя трогать равных/выше
    if not P11FW.CanTarget(by, target) then
        return false, "этого человека тронуть нельзя (его ранг не ниже твоего)"
    end

    -- лимит срока
    local lim = P11FW.PunishLimit(by, kind) -- nil не пройдёт выше; 0 = безлимит
    if lim and lim > 0 then
        if minutes == 0 then
            return false, "перманент тебе недоступен (лимит: " .. P11FW.FmtMinutes(lim) .. ")"
        elseif minutes > lim then
            minutes = lim
            P11FW.Notify(by, "Срок урезан до лимита твоего ранга: " .. P11FW.FmtMinutes(lim))
        end
    end

    if ptype ~= "ban" and minutes < 1 then minutes = 5 end

    P11FW.Punish(target, ptype, minutes, reason, by)
    P11FW.ModLog(ptype, by, target, reason .. " | срок: " .. P11FW.FmtMinutes(minutes)
        .. (ptype == "ban" and "" or " | до: " .. os.date("%d.%m %H:%M", os.time() + minutes * 60)))
    return true, "применено", minutes
end

-- ============ ВАРНЫ ============

function P11FW.WarnCountBySid(sid)
    local t = P11FW.Warns[sid]
    return istable(t) and #t or 0
end

function P11FW.Warn(by, target, reason)
    if not (IsValid(target) and target:IsPlayer()) then return false, "игрок не найден" end
    reason = (reason and string.Trim(reason) ~= "") and string.Trim(reason) or "без причины"

    if IsValid(by) then
        if not P11FW.CanMod(by, "warn") then return false, "варн выдаёт Хелпер+" end
        if not P11FW.CanTarget(by, target) then return false, "его ранг не ниже твоего" end
    end

    local sid = SidOf(target)
    P11FW.Warns[sid] = P11FW.Warns[sid] or {}
    P11FW.Warns[sid][#P11FW.Warns[sid] + 1] = {
        reason = string.sub(reason, 1, 120),
        by     = IsValid(by) and by:Nick() or "СЕРВЕР",
        at     = os.time(),
    }
    SaveWarns()

    local n = #P11FW.Warns[sid]
    P11FW.ModToast(target, "ВАРН " .. n .. "/" .. (P11FW.Config.AutoKickWarns or 3) .. ": " .. reason, "warn")
    target:EmitSound("ambient/alarms/warningbell1.wav", 70, 100)
    P11FW.ModLog("warn", by, target, reason .. " | итого варнов: " .. n)
    BroadcastMod(target:Nick() .. " получил варн " .. n .. " (" .. reason .. ")")

    -- авто-кик за набор варнов
    local cap = P11FW.Config.AutoKickWarns or 3
    if n >= cap then
        P11FW.ModLog("autokick", by, target, "накоплено " .. n .. " варнов")
        BroadcastMod(target:Nick() .. " КИКНУТ автоматически: " .. n .. " варнов.")
        P11FW.Warns[sid] = {}
        SaveWarns()
        timer.Simple(1.2, function()
            if IsValid(target) then
                target:Kick("[P11FW] Автоматический кик: " .. n .. " предупреждения. Последний: " .. reason)
            end
        end)
    end
    return true, "варн " .. n .. " выдан"
end

function P11FW.ClearWarns(by, target)
    if not (IsValid(target) and target:IsPlayer()) then return false, "игрок не найден" end
    if IsValid(by) and not P11FW.CanMod(by, "warn") then return false, "вары чистит Хелпер+" end
    local sid = SidOf(target)
    P11FW.Warns[sid] = {}
    SaveWarns()
    P11FW.ModLog("warn_clear", by, target, nil)
    return true, "варны очищены"
end

-- ============ МУТ ЧАТА ============

local function ApplyMuteNW(ply)
    local sid = SidOf(ply)
    local m = P11FW.Mutes[sid]
    if m then
        ply:SetNWBool("P11FW_Muted", true)
        ply:SetNWString("P11FW_MuteReason", m.reason or "")
        ply:SetNWInt("P11FW_MuteLeftMin", math.max(0, math.ceil((m.Until - os.time()) / 60)))
    else
        ply:SetNWBool("P11FW_Muted", false)
        ply:SetNWString("P11FW_MuteReason", "")
        ply:SetNWInt("P11FW_MuteLeftMin", 0)
    end
end

function P11FW.Mute(by, target, minutes, reason)
    if not (IsValid(target) and target:IsPlayer()) then return false, "игрок не найден" end
    reason = (reason and string.Trim(reason) ~= "") and string.Trim(reason) or "без причины"
    minutes = math.max(1, math.floor(tonumber(minutes) or 5))

    if IsValid(by) then
        if not P11FW.CanMod(by, "mute") then return false, "мут выдаёт Хелпер+" end
        if not P11FW.CanTarget(by, target) then return false, "его ранг не ниже твоего" end
        local lim = P11FW.PunishLimit(by, "mute")
        if lim and lim > 0 and minutes > lim then
            minutes = lim
            P11FW.Notify(by, "Мут урезан до лимита твоего ранга: " .. P11FW.FmtMinutes(lim))
        end
    end

    local sid = SidOf(target)
    P11FW.Mutes[sid] = {
        Until  = os.time() + minutes * 60,
        reason = reason,
        by     = IsValid(by) and by:Nick() or "СЕРВЕР",
        nick   = target:Nick(),
    }
    SaveMutes()
    ApplyMuteNW(target)

    P11FW.ModToast(target, "МУТ " .. P11FW.FmtMinutes(minutes) .. ": " .. reason, "mute")
    P11FW.ModLog("mute", by, target, reason .. " | срок: " .. P11FW.FmtMinutes(minutes))
    if IsValid(by) then P11FW.Notify(by, "Заглушен: " .. target:Nick() .. " на " .. P11FW.FmtMinutes(minutes)) end
    return true, "мут " .. P11FW.FmtMinutes(minutes)
end

function P11FW.Unmute(by, target)
    if not (IsValid(target) and target:IsPlayer()) then return false, "игрок не найден" end
    if IsValid(by) and not P11FW.CanMod(by, "mute") then return false, "мут снимает Хелпер+" end
    local sid = SidOf(target)
    if not P11FW.Mutes[sid] then return false, "он и так не в муте" end
    P11FW.Mutes[sid] = nil
    SaveMutes()
    ApplyMuteNW(target)
    P11FW.ModLog("unmute", by, target, nil)
    target:ChatPrint("[ПОЛЮС-11] Мут снят. Чат снова доступен.")
    return true, "мут снят"
end

function P11FW.IsMuted(ply)
    if not IsValid(ply) then return false end
    return P11FW.Mutes[SidOf(ply)] ~= nil
end

function P11FW.MuteLeftMin(ply)
    local m = IsValid(ply) and P11FW.Mutes[SidOf(ply)] or nil
    if not m then return 0 end
    return math.max(0, math.ceil((m.Until - os.time()) / 60))
end

-- блокировка чата замученного
hook.Add("PlayerSay", "P11FW.MuteGate", function(ply, text)
    if not P11FW.IsMuted(ply) then return end
    local sid = SidOf(ply)
    local m = P11FW.Mutes[sid]
    if (m.Until - os.time()) <= 0 then
        P11FW.Mutes[sid] = nil
        SaveMutes()
        ApplyMuteNW(ply)
        return
    end
    ply.P11FW_MuteNote = ply.P11FW_MuteNote or 0
    if CurTime() >= ply.P11FW_MuteNote then
        ply.P11FW_MuteNote = CurTime() + 4
        ply:ChatPrint("[ПОЛЮС-11] Ты в муте ещё " .. P11FW.FmtMinutes(P11FW.MuteLeftMin(ply))
            .. " — " .. (m.reason or ""))
    end
    return ""
end)

-- реапплай мута при входе
hook.Add("PlayerInitialSpawn", "P11FW.MuteJoin", function(ply)
    timer.Simple(2.5, function()
        if IsValid(ply) then ApplyMuteNW(ply) end
    end)
end)

-- авто-снятие просроченного мута + обновление счётчика на HUD
timer.Create("P11FW.MuteTick", 5, 0, function()
    local changed = false
    for sid, m in pairs(P11FW.Mutes) do
        if (m.Until - os.time()) <= 0 then
            P11FW.Mutes[sid] = nil
            changed = true
            for _, p in ipairs(player.GetAll()) do
                if SidOf(p) == sid then
                    ApplyMuteNW(p)
                    p:ChatPrint("[ПОЛЮС-11] Мут истёк. Пиши, но держи порядок.")
                end
            end
        else
            for _, p in ipairs(player.GetAll()) do
                if SidOf(p) == sid then
                    p:SetNWInt("P11FW_MuteLeftMin", math.max(0, math.ceil((m.Until - os.time()) / 60)))
                end
            end
        end
    end
    if changed then SaveMutes() end
end)

-- ============ КИК ============

function P11FW.Kick(by, target, reason)
    if not (IsValid(target) and target:IsPlayer()) then return false, "игрок не найден" end
    reason = (reason and string.Trim(reason) ~= "") and string.Trim(reason) or "без причины"
    if IsValid(by) then
        if not P11FW.CanMod(by, "kick") then return false, "кик доступен Модератору+" end
        if not P11FW.CanTarget(by, target) then return false, "его ранг не ниже твоего" end
    end
    P11FW.ModToast(target, "ВЫ КИКНУТЫ: " .. reason, "kick")
    P11FW.ModLog("kick", by, target, reason)
    BroadcastMod(target:Nick() .. " кикнут (" .. reason .. ")")
    timer.Simple(0.8, function()
        if IsValid(target) then target:Kick("[P11FW] Кикнут. Причина: " .. reason) end
    end)
    return true, "кикнут"
end

-- ============ ПОИСК ИГРОКА (общий, для консольных команд) ============

function P11FW.FindPlayer(arg)
    if not arg or arg == "" then return nil end
    local byId = player.GetByID(tonumber(arg) or -1)
    if IsValid(byId) then return byId end
    local low = string.lower(arg)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then return p end
        if p:SteamID() == arg or p:SteamID64() == arg then return p end
    end
    return nil
end

-- ============ КОНСОЛЬНЫЕ КОМАНДЫ (паритет с меню) ============
-- p11_mod_ban <игрок> <минуты 0=перма> [причина] / p11_mod_warn <игрок> [причина]
-- p11_mod_mute <игрок> <мин> [причина] / p11_mod_unmute <игрок> / p11_mod_kick <игрок> [причина]
-- p11_mod_warns <игрок> — показать варны / p11_mod_unwarn <игрок> — очистить / p11_mod_unban <sid>

concommand.Add("p11_mod_ban", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then print("[P11FW] игрок не найден: " .. tostring(args[1])) return end
    local ok, err = P11FW.RequestPunish(ply, t, "ban", tonumber(args[2]) or 0, table.concat(args, " ", 3))
    if IsValid(ply) then P11FW.Notify(ply, ok and "Бан применён" or ("Отказ: " .. tostring(err))) end
    print("[P11FW] ban " .. t:Nick() .. " -> " .. tostring(ok) .. " " .. tostring(err))
end)

concommand.Add("p11_mod_warn", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then print("[P11FW] игрок не найден") return end
    local ok, err = P11FW.Warn(ply, t, table.concat(args, " ", 2))
    if IsValid(ply) then P11FW.Notify(ply, ok and "Варн выдан" or ("Отказ: " .. tostring(err))) end
end)

concommand.Add("p11_mod_mute", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then print("[P11FW] игрок не найден") return end
    local ok, err = P11FW.Mute(ply, t, tonumber(args[2]) or 5, table.concat(args, " ", 3))
    if IsValid(ply) then P11FW.Notify(ply, ok and "Мут применён" or ("Отказ: " .. tostring(err))) end
end)

concommand.Add("p11_mod_unmute", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then return end
    local ok, err = P11FW.Unmute(ply, t)
    if IsValid(ply) then P11FW.Notify(ply, ok and "Мут снят" or ("Отказ: " .. tostring(err))) end
end)

concommand.Add("p11_mod_kick", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then print("[P11FW] игрок не найден") return end
    local ok, err = P11FW.Kick(ply, t, table.concat(args, " ", 2))
    if IsValid(ply) then P11FW.Notify(ply, ok and "Кикнут" or ("Отказ: " .. tostring(err))) end
end)

concommand.Add("p11_mod_warns", function(ply, cmd, args)
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then print("[P11FW] игрок не найден") return end
    local sid = SidOf(t)
    local list = P11FW.Warns[sid] or {}
    local out = "[P11FW] Варны " .. t:Nick() .. " (" .. #list .. "):"
    print(out)
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, out) end
    for i, w in ipairs(list) do
        local line = "  " .. i .. ". [" .. os.date("%d.%m %H:%M", w.at or 0) .. "] "
            .. tostring(w.reason) .. " — от " .. tostring(w.by)
        print(line)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, line) end
    end
end)

concommand.Add("p11_mod_unwarn", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local t = P11FW.FindPlayer(args[1])
    if not IsValid(t) then return end
    local ok, err = P11FW.ClearWarns(ply, t)
    if IsValid(ply) then P11FW.Notify(ply, ok and "Варны очищены" or ("Отказ: " .. tostring(err))) end
end)

concommand.Add("p11_mod_unban", function(ply, cmd, args)
    if IsValid(ply) then
        if not P11FW.CanMod(ply, "unban") then
            P11FW.Notify(ply, "Разбан доступен Суперадмину+")
            return
        end
    end
    if args[1] and args[1] ~= "" then
        P11FW.Unban(args[1])
        P11FW.ModLog("unban", ply, args[1], nil)
        print("[P11FW] Разбанен: " .. args[1])
        if IsValid(ply) then P11FW.Notify(ply, "Разбанен: " .. args[1]) end
    end
end)
