-- ============================================================
--  ПОЛЮС-11 — ВРЕМЯ ИГРЫ → ДОСТУП К ПРОФАМ (server) v4.5.0
--  У должности появилось поле time (минуты игры для входа,
--  ставится в редакторе ДОЛЖНОСТИ рядом с лимитом мест).
--  0 = без требования. Счётчик копится по минутам на сервере
--  и пишется в data/polus11/playtime.json (переживает рестарты).
--  ОБХОД: с ранга Super Admin (уровень 6) и выше ВСЕ профы
--  доступны без учёта времени (вплоть до «Главы Проекта»),
--  а «Глава Проекта» (ур.16) — см. также обход всех вайтлистов
--  в fw_sv_jobs.lua.
--  Игрок видит своё время: NWInt P11_PlayMin, в F4 — чип ⏳.
--  Консоль: p11_playtime [ник] — посмотреть; p11_settime <ник> <мин> — выдать.
-- ============================================================

local FILE = "polus11/playtime.json"

POLUS11.Playtime = POLUS11.Playtime or {} -- sid64 -> минут (integer)

local function SaveTime()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Playtime))
end

local function LoadTime()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Playtime = tbl end
end

LoadTime()

local function SidOf(ply)
    local sid = ply:SteamID64()
    if not sid or sid == "0" then sid = ply:SteamID() end
    return sid
end

-- минуты игрока (сейв + текущая сессия)
function POLUS11.GetPlayMin(ply)
    if not IsValid(ply) then return 0 end
    local base = POLUS11.Playtime[SidOf(ply)] or 0
    local sess = ply.P11_PlaySession or 0
    return math.floor((base * 60 + sess) / 60)
end

-- NW для клиента (F4)
local function PushNW(ply)
    ply:SetNWInt("P11_PlayMin", POLUS11.GetPlayMin(ply))
end

hook.Add("PlayerInitialSpawn", "P11.PlaytimeJoin", function(ply)
    ply.P11_PlaySession = 0
    timer.Simple(3, function() if IsValid(ply) then PushNW(ply) end end)
end)

-- каждые 60 сек: +1 минута всем живым, в сейв раз в 5 мин
local saveTick = 0
timer.Create("P11.PlaytimeTick", 60, 0, function()
    saveTick = saveTick + 1
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply.P11_PlaySession = (ply.P11_PlaySession or 0) + 60
            local sid = SidOf(ply)
            POLUS11.Playtime[sid] = (POLUS11.Playtime[sid] or 0) + 1
            PushNW(ply)
        end
    end
    if saveTick % 5 == 0 then SaveTime() end
end)

hook.Add("PlayerDisconnected", "P11.PlaytimeQuit", function(ply)
    -- минуты уже посчитаны тиками — просто фиксируем
    SaveTime()
end)
hook.Add("ShutDown", "P11.PlaytimeOff", SaveTime)

-- ============================================================
--  ГЕЙТ ВЫБОРА ПРОФЫ (используется из fw_sv_jobs.SetJob):
--  возвращает true или false+причину — но реализуем как
--  отдельный хук, чтобы проф гейт читался из одного места.
-- ============================================================

--- true — пускать; false, причина — отказ
function POLUS11.TimeGate(ply, job)
    local need = tonumber(job and job.time) or 0
    if need <= 0 then return true end
    -- с Super Admin (6) и выше — все профы открыты (по заявке владельца)
    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 6 then return true end
    local have = POLUS11.GetPlayMin(ply)
    if have >= need then return true end
    local left = need - have
    return false, "профа открывается со временем игры: нужно " .. need ..
        " мин., у тебя " .. have .. " (осталось " .. left .. " мин.)"
end

-- ============ КОНСОЛЬ ============

concommand.Add("p11_playtime", function(ply, cmd, args)
    local target = ply
    if IsValid(ply) and args[1] and P11FW.Config.Admin(ply) then
        local low = string.lower(tostring(args[1]))
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), low, 1, true) then target = p break end
        end
    elseif not IsValid(ply) and args[1] then
        local low = string.lower(tostring(args[1]))
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), low, 1, true) then target = p break end
        end
    end
    if not IsValid(target) then return end
    local msg = "[POLUS-11] " .. target:Nick() .. ": " .. POLUS11.GetPlayMin(target) .. " мин. игры"
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("p11_settime", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then
        P11FW.Notify(ply, "Только для администрации.")
        return
    end
    local low = string.lower(tostring(args[1] or ""))
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then target = p break end
    end
    local mins = math.floor(tonumber(args[2]) or -1)
    if not IsValid(target) or mins < 0 then
        local msg = "p11_settime <часть ника> <минуты>"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    POLUS11.Playtime[SidOf(target)] = mins
    target.P11_PlaySession = 0
    PushNW(target)
    SaveTime()
    local msg = "OK: " .. target:Nick() .. " → " .. mins .. " мин."
    if IsValid(ply) then P11FW.Notify(ply, msg) else print("[POLUS-11] " .. msg) end
end)

print("[POLUS-11] система времени для проф загружена")
