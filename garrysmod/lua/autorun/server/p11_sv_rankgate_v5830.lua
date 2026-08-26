-- ============================================================
--  ПОЛЮС-11 — ЗАДАЧА 1 ИЗ ТЗ: ПРАВА НА ВЫДАЧУ РАНГОВ
--  v5.8.30 (НОВЫЙ ФАЙЛ, autorun/server)
-- ============================================================
--  ТЗ: Staff Leader выдаёт ТОЛЬКО явно разрешённые ранги; ранг
--  «Администратор» исключён; попытка = блок + сообщение
--  «У вас нет прав для выдачи этого ранга» + запись в лог
--  (дата, время, SteamID нарушителя, запрашиваемый ранг).
--  Список разрешённых рангов — в конфиге/файле, НЕ в коде.
--
--  ЧЕМ ЭТО ОТЛИЧАЕТСЯ ОТ v5.8.28 (p11_sv_rankgrant_v5828.lua):
--    1) не зависит от «меток на функциях» (в Lua 5.1 индексация функции
--       = ошибка, из-за этого обёртка v5.8.28 могла не вставать вообще);
--    2) закрывает ВСЕ пути выдачи: P11FW.SetRank (её зовут и /menu act=22,
--       и консоль p11_rank) + P11FW.CanManageRank;
--    3) список прав — файл data/polus_framework/rank_grant.json
--       (формат с разделами allow / deny / min_level);
--    4) «Администратор» нельзя выдать, даже если его дописать в allow —
--       он в жёстком deny и требует уровень не ниже RankGrantMinLevel.admin.
--
--  Откат: удалить этот файл.
-- ============================================================

local DIR = "polus_framework"
local CFG = "polus_framework/rank_grant.json"
local LOG = "polus_framework/rank_grant.log"

-- ============ КОНФИГ ПРАВ (значения по умолчанию) ============
P11FW.RankGate = P11FW.RankGate or {}

local DEFAULTS = {
    -- кому что разрешено выдавать (явный список)
    allow = {
        staff_leader = {
            "user", "vip", "faction_officer", "faction_leader", "helper", "moderator",
        },
    },
    -- жёсткий запрет: не сработает, даже если ранг дописать в allow
    deny = {
        staff_leader = { "admin" },
    },
    -- минимальный уровень выдающего для «чувствительных» рангов.
    -- ТЗ: «выдача ранга Администратор привязана только к ролям с повышенными
    -- привилегиями». В нашей таблице прав выдавать ранги может Куратор (12)+,
    -- а Administrator поднимаем до Chief Curator (13)+ — даже если кто-то
    -- уберёт его из deny, выдача останется у верхнего эшелона.
    min_level = {
        admin      = 13,
        head_admin = 14,
        glava      = 16,
    },
}

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = DeepCopy(v) end
    return out
end

local function ListToSet(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[tostring(v)] = true end
    return s
end

--- DEFAULTS хранит deny СПИСКОМ (так удобнее писать в JSON),
--- а проверка работает с МНОЖЕСТВОМ — приводим здесь, иначе
--- deny.staff_leader["admin"] был бы nil и запрет не срабатывал.
local function ResetToDefaults()
    P11FW.RankGate = DeepCopy(DEFAULTS)
    local deny = {}
    for granter, list in pairs(P11FW.RankGate.deny or {}) do
        deny[granter] = ListToSet(list)
    end
    P11FW.RankGate.deny = deny
end
ResetToDefaults()

-- ============ ФАЙЛ КОНФИГА ============
local function SaveCfg()
    if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    local dump = {
        allow     = P11FW.RankGate.allow,
        deny      = {},
        min_level = P11FW.RankGate.min_level,
    }
    for granter, set in pairs(P11FW.RankGate.deny or {}) do
        local arr = {}
        for id in pairs(set) do arr[#arr + 1] = id end
        table.sort(arr)
        dump.deny[granter] = arr
    end
    file.Write(CFG, util.TableToJSON(dump, true) or "{}")
end

local function LoadCfg()
    if not file.Exists(CFG, "DATA") then
        SaveCfg()
        print("[POLUS-11] v5.8.30: создан конфиг выдачи рангов data/" .. CFG)
        return true
    end
    local raw = file.Read(CFG, "DATA")
    if not raw or raw == "" then return false end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if not (ok and istable(tbl)) then
        print("[POLUS-11][WARN] v5.8.30: " .. CFG .. " не читается — работаем на значениях по умолчанию")
        return false
    end

    -- раздел allow (или плоский формат v5.8.28: { "staff_leader": [...] })
    local allow = istable(tbl.allow) and tbl.allow or tbl
    for granter, list in pairs(allow) do
        if istable(list) and granter ~= "deny" and granter ~= "min_level" then
            P11FW.RankGate.allow[tostring(granter)] = list
        end
    end
    if istable(tbl.deny) then
        for granter, list in pairs(tbl.deny) do
            if istable(list) then
                P11FW.RankGate.deny[tostring(granter)] = ListToSet(list)
            end
        end
    end
    if istable(tbl.min_level) then
        for rankId, lvl in pairs(tbl.min_level) do
            P11FW.RankGate.min_level[tostring(rankId)] = tonumber(lvl) or 0
        end
    end

    -- «Администратор» в жёстком deny для Staff Leader — всегда
    P11FW.RankGate.deny.staff_leader = P11FW.RankGate.deny.staff_leader or {}
    P11FW.RankGate.deny.staff_leader["admin"] = true
    P11FW.RankGate.min_level["admin"] = P11FW.RankGate.min_level["admin"] or 13

    print("[POLUS-11] v5.8.30: конфиг выдачи рангов прочитан из data/" .. CFG)
    return true
end

-- ============ ЖУРНАЛ ============
local function GateLog(line)
    if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    local stamp = os.date("%Y-%m-%d %H:%M:%S")
    file.Append(LOG, "[" .. stamp .. "] " .. tostring(line) .. "\n")
    print("[P11FW][RANKGATE] " .. stamp .. " " .. tostring(line))
    if P11FW.Log then P11FW.Log("RANKGATE: " .. tostring(line)) end
end

local function Notify(ply, msg)
    if not IsValid(ply) then return end
    if P11FW.Notify then P11FW.Notify(ply, msg) end
    ply:ChatPrint("[ПОЛЮС-11] " .. msg)
end

-- ============ ПРОВЕРКА ПРАВ ============
local DENY_MSG = "У вас нет прав для выдачи этого ранга"

local function GranterId(by)
    if not IsValid(by) then return "" end
    if P11FW.GetRank then
        local ok, rec = pcall(P11FW.GetRank, by)
        if ok and istable(rec) and rec.id then return tostring(rec.id) end
    end
    return tostring(by:GetNWString("P11FW_Rank", "user") or "user")
end

local function GranterLevel(by)
    if not IsValid(by) then return 0 end
    if P11FW.GetRankLevel then
        local ok, lvl = pcall(P11FW.GetRankLevel, by)
        if ok and isnumber(lvl) then return lvl end
    end
    return 0
end

local function RankTitle(rankId)
    local rec = P11FW.RankById and P11FW.RankById[tostring(rankId or "")]
    return (rec and rec.name) or tostring(rankId)
end

--- Главная проверка. Возвращает true либо false + причину.
function P11FW.RankGateCheck(by, rankId)
    if not IsValid(by) then return true end           -- консоль/система (донат, промо)
    rankId = tostring(rankId or "")
    if rankId == "" then return false, "нет такого ранга" end

    local gid = GranterId(by)
    local lvl = GranterLevel(by)

    -- 1) жёсткий запрет (нельзя обойти правкой конфига)
    local deny = P11FW.RankGate.deny and P11FW.RankGate.deny[gid]
    if deny and deny[rankId] then
        return false, DENY_MSG
    end

    -- 2) минимальный уровень выдающего для чувствительных рангов
    local need = P11FW.RankGate.min_level and P11FW.RankGate.min_level[rankId]
    if need and lvl < need then
        return false, DENY_MSG
    end

    -- 3) явный белый список (если для ранга выдающего он задан)
    local allow = P11FW.RankGate.allow and P11FW.RankGate.allow[gid]
    if istable(allow) then
        for _, id in ipairs(allow) do
            if tostring(id) == rankId then return true end
        end
        return false, DENY_MSG
    end

    return true   -- для остальных рангов действует старое правило «не выше своего»
end

-- ============ ОБЁРТКИ (без меток на функциях) ============
-- В Lua 5.1 / LuaJIT table.unpack НЕТ — есть глобальный unpack.
local tunpack = table.unpack or unpack

-- «уже обернули» держим флагом модуля, а не меткой на функции:
-- Boot() дёргается несколькими таймерами, и поверх нашей обёртки может
-- встать чужая (v5.8.28) — повторная установка не нужна.
local Installed = { setRank = false, canManage = false }

local function LogAttempt(by, rankId, target, allowed, why)
    local who = IsValid(by) and (by:Nick() .. " [" .. by:SteamID() .. "]") or "КОНСОЛЬ"
    local to = IsValid(target) and target:Nick() or "?"
    if allowed then
        GateLog(string.format("ALLOW %s -> %s: '%s' (%s)", who, to, tostring(rankId), RankTitle(rankId)))
    else
        GateLog(string.format("DENY  %s -> %s: '%s' (%s) — %s",
            who, to, tostring(rankId), RankTitle(rankId), tostring(why or DENY_MSG)))
    end
end

local function WrapSetRank()
    if not (P11FW and P11FW.SetRank) then return false end
    if Installed.setRank then return true end
    local orig = P11FW.SetRank
    local wrap = function(target, rankId, by, ...)
        local ok, why = P11FW.RankGateCheck(by, rankId)
        if not ok then
            LogAttempt(by, rankId, target, false, why)
            Notify(by, why or DENY_MSG)
            return false, why or DENY_MSG
        end
        local res = { orig(target, rankId, by, ...) }
        if res[1] then
            -- успех логируем только для чувствительных рангов, чтобы не спамить
            local sensitive = P11FW.RankGate.min_level and P11FW.RankGate.min_level[tostring(rankId or "")]
            if sensitive then LogAttempt(by, rankId, target, true) end
        end
        return tunpack(res)
    end
    Installed.setRank = true
    P11FW.SetRank = wrap
    return true
end

local function WrapCanManage()
    if not (P11FW and P11FW.CanManageRank) then return false end
    if Installed.canManage then return true end
    local orig = P11FW.CanManageRank
    local wrap = function(ply, targetLevel, ...)
        local ok = orig(ply, targetLevel, ...)
        if not ok then return false end
        -- Staff Leader не менеджит ранги уровня Administrator (4) и выше
        if GranterId(ply) == "staff_leader" and tonumber(targetLevel or 0) >= 4 then
            return false
        end
        return ok
    end
    Installed.canManage = true
    P11FW.CanManageRank = wrap
    return true
end

local function Boot()
    LoadCfg()
    local a, b = WrapSetRank(), WrapCanManage()
    if a and b then
        print("[POLUS-11] v5.8.30: ЗАДАЧА 1 ТЗ — выдача рангов по белому списку, "
            .. "«Administrator» для Staff Leader закрыт")
    end
    return a and b
end

hook.Add("PostGamemodeLoaded", "P11.RankGate.v5830", function() timer.Simple(0, Boot) end)
hook.Add("InitPostEntity", "P11.RankGate.v5830", function()
    timer.Simple(0.4, Boot)
    timer.Simple(3, Boot)
    timer.Simple(10, Boot)
end)
timer.Simple(0.2, Boot)

-- ============ КОМАНДЫ ВЛАДЕЛЬЦА ============
concommand.Add("p11_rankgate_reload", function(ply)
    if IsValid(ply) and not (P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 16) then
        Notify(ply, "Перечитывать конфиг выдачи рангов может только Глава Проекта (или консоль сервера).")
        return
    end
    ResetToDefaults()
    LoadCfg()
    Boot()
    if IsValid(ply) then Notify(ply, "Конфиг выдачи рангов перечитан: data/" .. CFG) end
end)

concommand.Add("p11_rankgate_show", function(ply)
    if IsValid(ply) and not (P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 4) then return end
    local lines = { "[RANKGATE] правила выдачи рангов:" }
    for granter, list in pairs(P11FW.RankGate.allow or {}) do
        lines[#lines + 1] = "  allow " .. granter .. ": " .. table.concat(list, ", ")
    end
    for granter, set in pairs(P11FW.RankGate.deny or {}) do
        local arr = {}
        for id in pairs(set) do arr[#arr + 1] = id end
        table.sort(arr)
        lines[#lines + 1] = "  deny  " .. granter .. ": " .. table.concat(arr, ", ")
    end
    for rankId, lvl in pairs(P11FW.RankGate.min_level or {}) do
        lines[#lines + 1] = "  min_level " .. rankId .. ": " .. tostring(lvl)
    end
    lines[#lines + 1] = "  журнал: data/" .. LOG
    local txt = table.concat(lines, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)
