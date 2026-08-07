-- ============================================================
--  ПОЛЮС-11 — ДОНАТ-МОСТ ДЛЯ МАГАЗИНА (server) v4.9.2 «ПРИЁМ»
--  Заявка владельца: «инструкция подключить краут (CraftedStore)
--  к игре, чтобы можно было оплатить випку».
--  ЭТО серверная сторона: магазин (CraftedStore/EasyDonate/любой
--  другой) по факту оплаты выполняет КОНСОЛЬНУЮ КОМАНДУ на сервере:
--
--      p11_donorvip <SteamID или SteamID64>
--
--  Игрок ONLINE → VIP выдаётся СРАЗУ. Не в сети → покупка ложится
--  в очередь (polus11/donor_queue.json) и выдаётся при его входе.
--  Только консоль сервера/RCON (магазин) и Глава (ранг 16).
--  Шаблон для поля «команда сервера» в настройках пакета магазина:
--      p11_donorvip {steamid64}     (если есть вариант — и {steamid} тоже принимаем)
--  Пошаговая инструкция CraftedStore: docs/DONATE.md.
--  ПРИМЕЧАНИЕ: ручной путь «p11_rank <nick> vip» работает как всегда.
-- ============================================================

local FILE = "polus11/donor_queue.json" -- [steamid64] = { at = unixtime }
POLUS11.DonorQueue = POLUS11.DonorQueue or {}

local function DLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.DonorQueue = tbl end
end
local function DSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.DonorQueue, true))
end
hook.Add("InitPostEntity", "P11.DonorLoad", function()
    timer.Simple(1.8, DLoad)
end)

-- сама выдача VIP (эффекты + лог + объявление)
local function DonorGiveVIP(ply, how)
    if not IsValid(ply) then return end
    if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 2 then
        -- старший стафф уже выше VIP: просто сказка и лог
        POLUS11.Notify(ply, "Магазин: оплата VIP дошла, но твой ранг уже выше — зачислилось благодарением станции ✔")
        if POLUS11.Log then POLUS11.Log("ДОНОР: «" .. ply:Nick() .. "» уже стафф — VIP-оплата зачтена благодарением (" .. how .. ")") end
        return
    end
    if P11FW.SetRank then P11FW.SetRank(ply, "vip", nil) end
    POLUS11.Notify(ply, "💎 Оплата дошла! Статус VIP активен — F4 → 💎 VIP-СЛУЖБА открыта. Спасибо за поддержку станции!")
    PrintMessage(HUD_PRINTTALK, "💎 МАГАЗИН: боец " .. ply:Nick() .. " поддержал станцию — статус VIP выдан автоматом.")
    if POLUS11.Log then POLUS11.Log("ДОНОР: «" .. ply:Nick() .. "» («" .. ply:SteamID() .. "») получил VIP через магазин (" .. how .. ")") end
end

-- найти онлайн-игрока по SteamID или SteamID64
local function FindBySid(sid)
    sid = tostring(sid or "")
    if sid == "" then return nil end
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == sid or p:SteamID64() == sid then return p end
    end
    return nil
end

-- обработка очереди при входе
hook.Add("PlayerInitialSpawn", "P11.DonorQueueJoin", function(ply)
    timer.Simple(6, function()
        if not IsValid(ply) then return end
        local k = ply:SteamID64()
        if POLUS11.DonorQueue[k] then
            POLUS11.DonorQueue[k] = nil
            DSave()
            DonorGiveVIP(ply, "очередь магазина — оплата пришла раньше тебя")
        end
    end)
end)

concommand.Add("p11_donorvip", function(ply, _, args)
    -- из серверной консоли/RCON (магазин) — всегда; из клиента — только Глава
    if IsValid(ply) and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) < 16 then
        POLUS11.Notify(ply, "Донат-мост — только консоль сервера и Глава (ранг 16).")
        return
    end
    local sid = tostring(args and args[1] or "")
    if sid == "list" then
        local tell = IsValid(ply) and function(s) ply:PrintMessage(HUD_PRINTCONSOLE, s) end or print
        local n = 0
        tell("== ДОНОР-ОЧЕРЕДЬ VIP (offline-покупки) ==")
        for k, d in pairs(POLUS11.DonorQueue) do
            n = n + 1
            tell("  • " .. k .. " — оплачено " .. os.date("%d.%m %H:%M", d.at or 0))
        end
        tell(n == 0 and "  пусто" or ("  всего: " .. n))
        return
    end
    if sid == "" then
        local out = "p11_donorvip <SteamID|SteamID64> — выдать VIP по оплате магазина (offline → очередь до входа) • p11_donorvip list"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, out) else print(out) end
        return
    end
    local target = FindBySid(sid)
    if IsValid(target) then
        DonorGiveVIP(target, "магазин, онлайн-выдача")
    else
        local k64 = sid
        if string.sub(sid, 1, 5) == "STEAM" then
            k64 = util.SteamIDTo64(sid)
        end
        POLUS11.DonorQueue[k64] = { at = os.time() }
        DSave()
        local msg = "ДОНОР: игрок " .. sid .. " оффлайн — VIP уйдёт при входе (очередь: polus11/donor_queue.json)"
        print("[POLUS-11] " .. msg)
        if IsValid(ply) then POLUS11.Notify(ply, msg) end
    end
end)

print("[POLUS-11] донат-мост v4.9.2 «ПРИЁМ» загружен: p11_donorvip <SteamID> — шаблон для магазина (docs/DONATE.md)")
