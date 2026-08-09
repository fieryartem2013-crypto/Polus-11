-- ============================================================
--  ПОЛЮС-11 — ДЕЖУРНЫЙ ПОГОДЫ GWeather (server) v4.28.0 «МЕТЕО»
--  Автономное расписание поверх аддона gWeather (workshop
--  3322707383): его погоды — спавнящиеся энтити классов gw_t*.
--  Распорядок станции:
--   • СНЕГ   gw_t2_heavysnow      — НА ПОСТОЯНКЕ, полосы 30–40 мин;
--   • БУРЯ   gw_t3_blizzard       — РЕДКО, 5–10 мин, потом снег;
--   • СИЯНИЕ gw_t1_auroraborealis — ОЧЕНЬ РЕДКО (раз в 5–10
--     погодных ивентов), 5–10 минут.
--  Админ-форс: p11_weather <snow|blizzard|aurora|stop> [мин] (ранг 4+).
--  Без аддона модуль просто молчит — игра не ломается.
-- ============================================================

P11 = P11 or {}

local T_SNOW_MIN, T_SNOW_MAX = 30 * 60, 40 * 60  -- полоса снега
local T_RARE_MIN, T_RARE_MAX =  5 * 60, 10 * 60  -- буря/сияние
local RARE_P = 0.06                              -- шанс редкого ивента за тик (≈раз в 17 мин снега)
local TICK_T = 30                                -- период дежурного тика

local GW_CLASS = {
    snow     = "gw_t2_heavysnow",
    blizzard = "gw_t3_blizzard",
    aurora   = "gw_t1_auroraborealis",
}

local M = {
    ent = nil, kind = "", till = 0,
    rareLeft = math.random(5, 10), -- через столько погодных ивентов — сияние
    missing = false, forced = false,
}

local function GW_Stop()
    if IsValid(M.ent) then M.ent:Remove() end
    M.ent, M.kind, M.till = nil, "", 0
end

local function GW_Start(kind, dur)
    local class = GW_CLASS[kind]
    if not class then return false end
    local ok, e = pcall(function()
        local en = ents.Create(class)
        if not IsValid(en) then return nil end
        en:SetPos(Vector(0, 0, 0)) -- погодные энтити gWeather зональные — позиция не важна
        en:Spawn()
        en:Activate()
        return en
    end)
    if ok and IsValid(e) then
        GW_Stop()
        M.ent, M.kind, M.till = e, kind, CurTime() + dur
        POLUS11.Log("Погода: «" .. class .. "» на " .. math.ceil(dur / 60) .. " мин")
        return true
    end
    if not M.missing then
        M.missing = true
        POLUS11.Log("Погода: аддон gWeather НЕ найден (классы gw_t* отсутствуют) — метеодежурный спит")
    end
    return false
end

-- ============ ДЕЖУРНЫЙ ТИК ============

timer.Create("P11.WeatherTick", TICK_T, 0, function()
    -- форс админом действует до конца своего срока
    if M.forced then
        if M.till > 0 and CurTime() >= M.till then M.forced = false end
        return
    end
    -- нет действующей погоды (или полоса кончилась) → НОВАЯ ПОЛОСА СНЕГА
    if not IsValid(M.ent) or (M.till > 0 and CurTime() >= M.till) then
        GW_Start("snow", math.random(T_SNOW_MIN, T_SNOW_MAX))
        return
    end
    -- идёт БУРЯ или СИЯНИЕ — ждём конца полосы, дальше вернётся снег
    if M.kind ~= "snow" then return end
    -- идёт СНЕГ — редкий бросок на ивент
    if math.random() >= RARE_P then return end
    -- сияние выпадает раз в 5–10 погодных ивентов
    if M.rareLeft <= 1 then
        M.rareLeft = math.random(5, 10)
        if GW_Start("aurora", math.random(T_RARE_MIN, T_RARE_MAX)) then
            PrintMessage(HUD_PRINTTALK, "[ПОГОДА] Небо вспыхнуло — СЕВЕРНОЕ СИЯНИЕ над «Полюсом-11».")
        end
    else
        M.rareLeft = M.rareLeft - 1
        if GW_Start("blizzard", math.random(T_RARE_MIN, T_RARE_MAX)) then
            PrintMessage(HUD_PRINTTALK, "[ПОГОДА] Надвигается БУРЯ — видимость падает, держитесь станции.")
        end
    end
end)

-- ============ АДМИН-КОМАНДА ============

concommand.Add("p11_weather", function(ply, _, args)
    if IsValid(ply) then
        local okRank = P11FW and P11FW.Config and P11FW.Config.Admin
            and P11FW.Config.Admin(ply)
        if not okRank then
            if POLUS11.Notify then POLUS11.Notify(ply, "p11_weather: нужен ранг Админ+") end
            return
        end
    end
    local what = tostring(args[1] or "")
    local mins = tonumber(args[2] or "") or 0
    if what == "stop" then
        GW_Stop()
        M.forced = false
        POLUS11.Log("Погода: ручная остановка администрацией")
        return
    end
    if not GW_CLASS[what] then
        local msg = "p11_weather <snow|blizzard|aurora|stop> [мин] — форс погоды gWeather"
        if IsValid(ply) and POLUS11.Notify then POLUS11.Notify(ply, msg) else print(msg) end
        return
    end
    local dur
    if what == "snow" and mins <= 0 then
        dur = math.random(T_SNOW_MIN, T_SNOW_MAX)
    elseif mins > 0 then
        dur = mins * 60
    else
        dur = math.random(T_RARE_MIN, T_RARE_MAX)
    end
    if GW_Start(what, dur) then
        M.forced = true
        PrintMessage(HUD_PRINTTALK, "[ПОГОДА] Администрация включила «" .. what ..
            "» на " .. math.ceil(dur / 60) .. " мин.")
    end
end)

print("[POLUS-11] ПОГОДА GWeather (server) v4.28.0 «МЕТЕО»: снег постоянно по 30-40 мин · редко буря 5-10 мин · очень редко сияние 5-10 мин · p11_weather")
