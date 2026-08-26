-- ============================================================
--  ПОЛЮС-11 — ВРЕМЯ ИГРЫ → ДОСТУП К ПРОФАМ (server) v4.8.0
--  У должности поле time (минуты игры для входа, ставится в
--  редакторе ДОЛЖНОСТИ рядом с лимитом мест). 0 = без требования.
--  Счётчик копится по минутам на сервере и пишется в
--  data/polus11/playtime.json (переживает рестарты).
--  ОБХОД: с ранга Super Admin (уровень 6) и выше ВСЕ профы
--  доступны без учёта времени.
--
--  ███ v4.8.0: ПОЧИНЕН «ДВОЙНОЙ СЧЁТ» (багрепорт владельца:
--  «у чела 24 мин, хотя он их не наиграл») ███
--  КОРЕНЬ: каждый 60-сек тик писал минуту ВДВОЙНЕ — и в сейв
--  (Playtime[sid] +1), и в сессию (PlaySession +60), а показ
--  GetPlayMin СКЛАДЫВАЛ обе части: base + sess/60. Итог: за час
--  реальной игры человеку рисовалось ДВА часа (12 → 24 и т.д.).
--  ТЕПЕРЬ: ОДИН авторитетный счётчик (Playtime[sid] в минутах),
--  сессионная переменная упразднена совсем.
--  + две честности сверху:
--   1) ЧЕЛОВЕК В ЗАГРУЗКЕ минут не получает — счёт начинается
--      только ПОСЛЕ первого реального спавна на станции
--      (PlayerSpawn), а не с момента коннекта.
--   2) АФК-ФРИЗ (POLUS11.Config.AFKStopMinutes, по умолчанию 4):
--      без ввода дольше N минут (ни клавиш, ни чата, ни E) —
--      счётчик встаёт на паузу до пробуждения. 0 = отключить.
--  Ретро-поправки накрученных цифр нет (назад их не отличить):
--  кривые значения правь руками — p11_settime <ник> <мин>.
-- ============================================================

local FILE = "polus11/playtime.json"

POLUS11.Playtime = POLUS11.Playtime or {} -- sid -> минут (integer)

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

-- v4.6.5: SteamID64-ключи JSON-To-Table ломает (числа без разрядов) —
-- поэтому минуты могли не сохраняться. Основной ключ — STEAM_0:x:y.
local function SidOf(ply)
    local sid = ply:SteamID()
    if not sid or sid == "" then sid = ply:SteamID64() end
    return sid
end

-- минуты игрока (единый авторитетный счётчик — БЕЗ сессионной добавки)
function POLUS11.GetPlayMin(ply)
    if not IsValid(ply) then return 0 end
    return math.floor(tonumber(POLUS11.Playtime[SidOf(ply)]) or 0)
end

-- NW для клиента (F4)
local function PushNW(ply)
    ply:SetNWInt("P11_PlayMin", POLUS11.GetPlayMin(ply))
end

local function AFKMin()
    return (POLUS11.Config and tonumber(POLUS11.Config.AFKStopMinutes)) or 4
end

-- активность игрока (любой ввод сбрасывает АФК-таймер)
local function Touch(ply)
    if IsValid(ply) then ply.P11_PlayLast = CurTime() end
end
hook.Add("KeyPress",  "P11.PlaytimeKeys", function(ply) Touch(ply) end)
hook.Add("PlayerSay", "P11.PlaytimeChat", function(ply) Touch(ply) end)
hook.Add("PlayerUse", "P11.PlaytimeUse",  function(ply) Touch(ply) end)

hook.Add("PlayerInitialSpawn", "P11.PlaytimeJoin", function(ply)
    ply.P11_PlayIn = false -- в станцию ЕЩЁ НЕ вошёл (загрузка/лобби)
    ply.P11_PlayLast = CurTime()
    timer.Simple(3, function() if IsValid(ply) then PushNW(ply) end end)
end)

-- первый (и каждый) реальный спавн: человек на станции — считаем
hook.Add("PlayerSpawn", "P11.PlaytimeEnter", function(ply)
    ply.P11_PlayIn = true
    Touch(ply)
end)

-- каждые 60 сек: +1 минута ТОЛЬКО вошедшим и не-АФК, в сейв раз в 5 мин
local saveTick = 0
timer.Create("P11.PlaytimeTick", 60, 0, function()
    saveTick = saveTick + 1
    for _, ply in ipairs(player.GetAll()) do
        -- v4.8.0: только реально вошедшие на станцию (не серые в загрузке)
        if IsValid(ply) and ply.P11_PlayIn then
            -- АФК-фриз: давно без ввода — минуты на паузе
            local afk = AFKMin()
            local idle = CurTime() - (ply.P11_PlayLast or CurTime())
            if afk <= 0 or idle <= afk * 60 then
                local sid = SidOf(ply)
                POLUS11.Playtime[sid] = (POLUS11.Playtime[sid] or 0) + 1
            end
            PushNW(ply)
            -- v4.6.6: фанфары открытия — профа ровно с этой минуты
            local now = POLUS11.GetPlayMin(ply)
            for jid, job in pairs(P11FW.Jobs or {}) do
                local need = tonumber(job.time) or 0
                if need == now and need > 0 then
                    P11FW.Notify(ply, "⏳ " .. need .. " мин службы — тебе ОТКРЫЛАСЬ должность: «" .. job.name .. "»!")
                    ply:EmitSound("buttons/button15.wav", 70, 105)
                end
            end
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
    local idle = CurTime() - (target.P11_PlayLast or CurTime())
    local msg = "[POLUS-11] " .. target:Nick() .. ": " .. POLUS11.GetPlayMin(target) .. " мин. игры"
        .. " | на станции: " .. tostring(target.P11_PlayIn == true)
        .. " | без ввода: " .. math.floor(idle) .. " сек (фриз с " .. AFKMin() .. " мин АФК)"
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
        local msg = "p11_settime <часть ника> <минуты>  (исправление вручную после двойного счёта до v4.8.0)"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    POLUS11.Playtime[SidOf(target)] = mins
    PushNW(target)
    SaveTime()
    local msg = "OK: " .. target:Nick() .. " → " .. mins .. " мин."
    if IsValid(ply) then P11FW.Notify(ply, msg) else print("[POLUS-11] " .. msg) end
end)

print("[POLUS-11] система времени игры v4.8.0: честные минуты (двойной счёт убит, АФК-фриз " .. AFKMin() .. " мин)")
