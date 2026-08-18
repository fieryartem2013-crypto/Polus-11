-- ============================================================
--  ПОЛЮС-11 — ВРЕМЕННЫЙ VIP + СРОК ТАЛОНОВ v5.8.20 (server, autorun)
--  1) POLUS11.GrantTempVIP(ply, days) — выдаёт ранг VIP на N дней:
--     метка истечения хранится в data/polus11/tempvip.json, раз в
--     60 сек сервер снимает VIP у тех, у кого срок вышел (и при
--     заходе — тоже проверяет).
--  2) POLUS11.PromoExpireAt(code, days) — срок действия талона:
--     первый вызов запоминает «сейчас + N дней» в
--     data/polus11/promo_expire.json (переживает рестарты сервера).
--  3) POLUS11.PromoLeft(code) — сколько мест осталось у талона.
--  Новый талон STOLINOV11 (v5.8.20) использует всё это: 100 мест,
--  неделя, VIP 2 дня + 35 000₽ (поле в p11_sv_promo.lua).
--  Старые файлы не трогаем.
-- ============================================================

local TMP_FILE  = "polus11/tempvip.json"
local EXP_FILE  = "polus11/promo_expire.json"

P11TempVIP = P11TempVIP or {} -- [steamid] = unixtime истечения VIP
POLUS11.TempVIP = POLUS11.TempVIP or P11TempVIP

local function SaveTemp()
    file.Write(TMP_FILE, util.TableToJSON(P11TempVIP, true) or "{}")
end

local function LoadTemp()
    local raw = file.Read(TMP_FILE, "DATA")
    if raw then
        local ok, t = pcall(util.JSONToTable, raw)
        if ok and istable(t) then P11TempVIP = t; POLUS11.TempVIP = t end
    end
end

-- ============ 1) ВРЕМЕННЫЙ VIP ============

--- Выдать VIP на days дней. Возвращает true (активирован) или false (уже есть).
function POLUS11.GrantTempVIP(ply, days)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local sid = ply:SteamID()
    local until_t = os.time() + (days or 2) * 86400

    -- продлеваем, если уже есть временный
    local had = P11TempVIP[sid] and os.time() < P11TempVIP[sid]
    P11TempVIP[sid] = until_t
    SaveTemp()

    if not had then
        -- ранг vip ставим только если его ещё нет (не сбиваем донат/постоянный)
        if not (P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 1) then
            if P11FW.SetRank then P11FW.SetRank(ply, "vip", nil) end
        end
    end

    if POLUS11.Log then
        POLUS11.Log("ВРЕМЕННЫЙ VIP: " .. ply:Nick() .. " +" .. days .. " дн. (до " .. os.date("%d.%m %H:%M", until_t) .. ")")
    end
    return not had
end

-- снять VIP, если срок истёк
local function ExpireVIP(sid)
    local until_t = P11TempVIP[sid]
    if not until_t then return end
    if os.time() < until_t then return end -- ещё не истёк

    P11TempVIP[sid] = nil
    SaveTemp()

    local p = player.GetBySteamID(sid)
    if IsValid(p) and p:IsPlayer() then
        -- снимаем только если ранг всё ещё vip (не трогаем другие ранги)
        local r = P11FW.GetRank and P11FW.GetRank(p)
        if r and r.id == "vip" then
            P11FW.SetRank(p, "user", nil)
            p:ChatPrint("[ПОЛЮС-11] Твой временный VIP (по талону) истёк. Спасибо, что был с нами!")
            if POLUS11.Log then POLUS11.Log("ВРЕМЕННЫЙ VIP истёк: " .. p:Nick() .. " → user") end
        end
    end
end

-- таймер проверки раз в 60 сек
timer.Create("P11.TempVIP.Scan", 60, 0, function()
    for sid in pairs(P11TempVIP) do
        ExpireVIP(sid)
    end
end)

-- при заходе — тоже проверяем (срок мог выйти, пока игрок был оффлайн)
hook.Add("PlayerInitialSpawn", "P11.TempVIP.Join", function(ply)
    timer.Simple(8, function()
        if IsValid(ply) then ExpireVIP(ply:SteamID()) end
    end)
end)

-- ============ 2) СРОК ДЕЙСТВИЯ ТАЛОНА (переживает рестарты) ============

--- Вернуть unixtime, до которого действует талон code (N дней от первого запроса).
function POLUS11.PromoExpireAt(code, days)
    local tbl = {}
    local raw = file.Read(EXP_FILE, "DATA")
    if raw then
        local ok, t = pcall(util.JSONToTable, raw)
        if ok and istable(t) then tbl = t end
    end
    if not tbl[code] then
        tbl[code] = os.time() + (days or 7) * 86400
        file.Write(EXP_FILE, util.TableToJSON(tbl, true))
    end
    return tbl[code]
end

--- Сколько мест осталось у талона (для анонсов).
function POLUS11.PromoLeft(code)
    local tbl = POLUS11.PromoUsed and POLUS11.PromoUsed[code]
    if not istable(tbl) then return nil end
    local cnt = 0
    for _ in pairs(tbl) do cnt = cnt + 1 end
    return cnt
end

-- загрузка при старте
hook.Add("InitPostEntity", "P11.TempVIP.Load", function()
    timer.Simple(1.5, LoadTemp)
end)

print("[POLUS-11] v5.8.20: временный VIP + срок талонов готовы (STOLINOV11: 100 мест, неделя, VIP 2 дня + 35к)")
