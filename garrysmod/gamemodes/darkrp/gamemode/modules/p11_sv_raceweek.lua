-- ============================================================
--  ПОЛЮС-11 — «ЛЕДОКОЛ»: НЕДЕЛЬНАЯ ГОНКА РККА vs ОРЁЛ (server)
--  v4.20.0 «СЛЕД». Заявка владельца (банк аналитики №12):
--  «РККА vs Орёл: недельная гонка поставок/точек, бафф победителю».
--
--  КАК ЖИВЁТ:
--   • очки капают из штатных дел (звено в цепи TaskEvent):
--     груз (haul) +5, закрытый наряд интенданта (contract_done) +3,
--     арест +2, анализ крови / крафт / урон по Нечто +1;
--   • очки пишет ТА фракция, чья должность на бойце
--     (category фракции: rkka — РККА, eagle — Красный Орёл);
--   • неделя с понедельника: при смене недели счёт обнуляется,
--     ПОБЕДИТЕЛЬ получает бафф на всю следующую неделю:
--     +20% к оплате нарядов интенданта (читают контракты через
--     POLUS11.RaceBuffMult); ничья — баффа нет;
--   • сводка летит клиентам глобал-строкой P11_Race
--     ("неделя|ркка|орёл|бафф") → полоска на HUD справа вверху;
--   • переживает рестарт (data/polus11/raceweek.json).
-- ============================================================

local FILE = "polus11/raceweek.json"

POLUS11.Race = POLUS11.Race or { week = "", rkka = 0, oryol = 0, buff = "" }

-- ручной номер недели: %V есть не в каждом strftime (LuaJIT/Win)
local function WeekKey()
    local yday = tonumber(os.date("%j")) or 1
    return os.date("%Y") .. "-W" .. string.format("%02d", math.ceil(yday / 7))
end

local function RaceSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Race, true) or "{}")
end

local function RaceLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then
        for k in pairs(POLUS11.Race) do POLUS11.Race[k] = nil end
        for k, v in pairs(tbl) do POLUS11.Race[k] = v end
    end
end

-- ============ СВОДКА КЛИЕНТАМ ============
local raceDirty = true
timer.Create("P11.RacePush", 1, 0, function()
    if not raceDirty then return end
    raceDirty = false
    SetGlobalString("P11_Race", table.concat({
        tostring(POLUS11.Race.week or ""),
        tostring(POLUS11.Race.rkka or 0),
        tostring(POLUS11.Race.oryol or 0),
        tostring(POLUS11.Race.buff or ""),
    }, "|"))
end)

-- ============ ФРАКЦИЯ БОЙЦА ============
function POLUS11.RaceFaction(ply)
    if not IsValid(ply) then return nil end
    local j = P11FW and P11FW.GetJob and P11FW.GetJob(ply)
    local c = j and (j.category or j.faction)
    if c == "rkka" then return "rkka" end
    if c == "eagle" then return "oryol" end
    return nil
end

-- бафф победителя недели (+20% к оплате нарядов; зовут контракты)
function POLUS11.RaceBuffMult(ply)
    local f = POLUS11.RaceFaction(ply)
    if f and POLUS11.Race.buff == f then return 1.2 end
    return 1
end

-- ============ ФИНАЛ НЕДЕЛИ ============
local function RaceAnnounce(txt)
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString("ЛЕДОКОЛ")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[ЛЕДОКОЛ] " .. txt)
end

local function RaceFinalize()
    local r, o = tonumber(POLUS11.Race.rkka) or 0, tonumber(POLUS11.Race.oryol) or 0
    local winner = ""
    if r > o then winner = "rkka" elseif o > r then winner = "oryol" end
    local wname = (winner == "rkka" and "РККА") or (winner == "oryol" and "ОРЁЛ") or nil
    if wname then
        RaceAnnounce("ГОНКА НЕДЕЛИ ЗАВЕРШЕНА: " .. wname .. " побеждает " .. math.max(r, o) ..
            " : " .. math.min(r, o) .. "! Бафф недели: +20% к оплате нарядов у интенданта. ЛЕДОКОЛ выходит на новый круг!")
    else
        RaceAnnounce("ГОНКА НЕДЕЛИ ЗАВЕРШЕНА: сухая ничья " .. r .. " : " .. o ..
            ". Баффа нет. ЛЕДОКОЛ выходит на новый круг!")
    end
    POLUS11.Log("ЛЕДОКОЛ: неделя " .. tostring(POLUS11.Race.week) .. " закрыта: РККА " .. r ..
        " — ОРЁЛ " .. o .. ", победитель: " .. (wname or "нет"))
    POLUS11.Race.week  = WeekKey()
    POLUS11.Race.rkka  = 0
    POLUS11.Race.oryol = 0
    POLUS11.Race.buff  = winner
    RaceSave()
    raceDirty = true
end

local function RaceCheckWeek()
    local wk = WeekKey()
    if POLUS11.Race.week ~= wk then
        if (POLUS11.Race.week or "") ~= "" then
            RaceFinalize()
        else
            POLUS11.Race.week = wk
            RaceSave()
        end
    end
end

hook.Add("InitPostEntity", "P11.RaceBoot", function()
    RaceLoad()
    timer.Simple(2, function()
        RaceCheckWeek()
        raceDirty = true
    end)
end)
timer.Create("P11.RaceWeek", 30, 0, RaceCheckWeek)

-- ============ ОЧКИ (звено в цепи TaskEvent) ============
local PTS = {
    haul          = 5,  -- колонна снабжения доехала
    contract_done = 3,  -- наряд интенданта закрыт
    arrest        = 2,  -- арест по делу
    blood_test    = 1,  -- анализ крови
    craft_do      = 1,  -- изделие на верстаке
    damage_thing  = 1,  -- урон по Нечто (за событие)
}

function POLUS11.RaceEvent(ply, key)
    local add = PTS[key]
    if not add then return end
    local f = POLUS11.RaceFaction(ply)
    if not f then return end
    POLUS11.Race[f] = (tonumber(POLUS11.Race[f]) or 0) + add
    raceDirty = true
end

do
    local base = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        if base then base(ply, key, add) end
        POLUS11.RaceEvent(ply, key)
    end
end

print("[POLUS-11] «ЛЕДОКОЛ» v4.20.0: недельная гонка РККА vs ОРЁЛ (+20% к нарядам победителю), полоска на HUD")
