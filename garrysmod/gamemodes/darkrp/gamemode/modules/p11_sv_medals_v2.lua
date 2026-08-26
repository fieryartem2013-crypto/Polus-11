-- ============================================================
--  ПОЛЮС-11 — МЕДАЛИ «ПОЧЁТ» (server) v5.2.3 → v2 (НОВЫЙ ФАЙЛ)
--  ПЕРЕПИСАНЫ С НУЛЯ. Простая и надёжная версия: реестр знаков,
--  выдача/снятие, синк клиентам через net.WriteString (паттерн
--  фракций/профов), страховочная рассылка раз в 2 минуты,
--  автонаграды по счётчикам, файлы создаются сами при старте.
--  Публичный API сохранён: POLUS11.MedalPush / MedalAward /
--  MedalRevoke / MedalScope / MedalStatEvent / MedalAutoGrant.
--  Старый p11_sv_medals.lua ОТКЛЮЧЁН (не загружается).
-- ============================================================

util.AddNetworkString("P11_MedalSync")
util.AddNetworkString("P11_MedalAct")

local FILE = "polus11/medals.json"
local STAT_FILE = "polus11/autostats.json"
local MAX_MEDALS = 8

POLUS11.MedalDefs = {
    -- ведомственные (Faction Leader + Developer)
    zorkiy   = { glyph = "○", name = "Зоркий Глаз",       dept = true,  desc = "за бдительность и вовремя поднятую тревогу" },
    obhod    = { glyph = "▲", name = "Честная Вахта",     dept = true,  desc = "постовая дисциплина: вахта ни разу не брошена" },
    sluzhba  = { glyph = "■", name = "Верная Служба",     dept = true,  desc = "верность станции, уставу и смене" },
    -- штабные (Developer+)
    geroy    = { glyph = "★", name = "Герой Полюса",      dept = false, desc = "высшая отметка: подвиг во имя гарнизона" },
    mercy    = { glyph = "♥", name = "Милосердие",        dept = false, desc = "за спасённые жизни бойцов" },
    poriadok = { glyph = "♦", name = "Хранитель Порядка", dept = false, desc = "порядок на станции — его рук дело" },
    veteran  = { glyph = "◆", name = "Ветеран Станции",   dept = false, desc = "долгие смены, пережитые бури и Нечто" },
    legenda  = { glyph = "☆", name = "Легенда Полюса",    dept = false, desc = "о таком расскажут следующим зимовкам" },
    -- автонаграды станции (вручает сам сервер)
    glaz     = { glyph = "●", name = "Глазной",           dept = false, auto = true, desc = "50 анализов крови — автонаграда лаборатории" },
    dezin    = { glyph = "♠", name = "Дезинфектор",       dept = false, auto = true, desc = "5000 урона по Нечто — автонаграда гарнизона" },
    sanitar  = { glyph = "◇", name = "Санитар Полюса",    dept = false, auto = true, desc = "10 бойцов подняты на ноги — автонаграда медслужбы" },
}

POLUS11.Medals = POLUS11.Medals or {}       -- sid64 -> { { id, by, at }, ... }
POLUS11.AutoStats = POLUS11.AutoStats or {} -- sid64 -> { tests, dmg, heals }
POLUS11.AutoMedals = {
    glaz    = { stat = "tests", need = 50 },
    dezin   = { stat = "dmg",   need = 5000 },
    sanitar = { stat = "heals", need = 10 },
}

local statDirty = false

local function EnsureDir()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
end

local function MedalSave()
    EnsureDir()
    file.Write(FILE, util.TableToJSON(POLUS11.Medals, true) or "{}")
end

local function StatSave()
    if not statDirty then return end
    statDirty = false
    EnsureDir()
    file.Write(STAT_FILE, util.TableToJSON(POLUS11.AutoStats, true) or "{}")
end

local function MedalLoad()
    -- v5.2.3: файлы создаются САМИ при первом старте (всегда лежат на диске)
    if not file.Exists(FILE, "DATA") then
        EnsureDir()
        file.Write(FILE, "{}")
    end
    if not file.Exists(STAT_FILE, "DATA") then
        EnsureDir()
        file.Write(STAT_FILE, "{}")
    end
    local raw = file.Read(FILE, "DATA")
    if raw then
        local ok, tbl = pcall(util.JSONToTable, raw)
        if ok and istable(tbl) then POLUS11.Medals = tbl end
    end
    local raw2 = file.Read(STAT_FILE, "DATA")
    if raw2 then
        local ok, tbl = pcall(util.JSONToTable, raw2)
        if ok and istable(tbl) then POLUS11.AutoStats = tbl end
    end
    -- после загрузки — разослать реестр всем, кто уже на сервере
    timer.Simple(1, function() POLUS11.MedalPush(nil) end)
end

hook.Add("InitPostEntity", "P11.MedalLoad", function() timer.Simple(1.2, MedalLoad) end)
hook.Add("PlayerDisconnected", "P11.MedalSave", function() MedalSave() StatSave() end)
timer.Create("P11.MedalStatFlush", 15, 0, StatSave)

-- ============ КТО МОЖЕТ ВЫДАВАТЬ ============

function POLUS11.MedalScope(ply)
    if not IsValid(ply) then return nil end
    if ply:IsListenServerHost() then return "full" end
    if ply:IsSuperAdmin() then return "full" end
    if P11FW and P11FW.GetRankLevel then
        local lvl = tonumber(P11FW.GetRankLevel(ply)) or 0
        if lvl >= 9 then return "full" end
        local r = P11FW.GetRank and P11FW.GetRank(ply)
        if r and r.id == "faction_leader" then return "dept" end
    end
    return nil
end

-- ============ СИНК (простой и надёжный) ============

local function MedalPacket()
    local defs = {}
    for id, d in pairs(POLUS11.MedalDefs) do
        defs[id] = { g = d.glyph, n = d.name, d = d.desc, dept = d.dept and 1 or 0 }
    end
    local list = {}
    for sid64, arr in pairs(POLUS11.Medals) do
        local ids = {}
        for _, m in ipairs(arr) do
            if POLUS11.MedalDefs[m.id] then ids[#ids + 1] = m.id end
        end
        if #ids > 0 then list[sid64] = ids end
    end
    return util.TableToJSON({ defs = defs, list = list }) or "{}"
end

function POLUS11.MedalPush(ply)
    local json = MedalPacket()
    net.Start("P11_MedalSync")
        net.WriteString(json)
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "P11.MedalJoin", function(ply)
    timer.Simple(4, function()
        if IsValid(ply) then POLUS11.MedalPush(ply) end
    end)
end)

-- страховка: раз в 2 минуты реестр уходит всем клиентам
timer.Create("P11.MedalSyncLoop", 120, 0, function()
    POLUS11.MedalPush(nil)
end)

-- ============ ВЫДАЧА / СНЯТИЕ ============

local function MedalNick(sid64)
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID64() == sid64 then return p:Nick() end
    end
    return sid64
end

function POLUS11.MedalAward(ply, sid64, medId)
    local scope = POLUS11.MedalScope(ply)
    if not scope then
        POLUS11.Notify(ply, "Медали выдают: Faction Leader (ведомственные) и ранг Developer+ (все).")
        return false
    end
    local def = POLUS11.MedalDefs[tostring(medId or "")]
    if not def then return false end
    sid64 = string.sub(tostring(sid64 or ""), 1, 24)
    if sid64 == "" then return false end

    if scope == "dept" and not def.dept then
        POLUS11.Notify(ply, "Faction Leader вручает только ВЕДОМСТВЕННЫЕ медали (○ ▲ ■).")
        return false
    end

    local arr = POLUS11.Medals[sid64] or {}
    POLUS11.Medals[sid64] = arr
    if #arr >= MAX_MEDALS then
        POLUS11.Notify(ply, "У бойца уже " .. MAX_MEDALS .. " медалей — грудь закончилась.")
        return false
    end
    for _, m in ipairs(arr) do
        if m.id == medId then
            POLUS11.Notify(ply, "У этого бойца УЖЕ есть «" .. def.name .. "».")
            return false
        end
    end

    arr[#arr + 1] = { id = medId, by = ply:Nick(), at = os.time() }
    MedalSave()
    POLUS11.MedalPush(nil)

    local tn = MedalNick(sid64)
    net.Start("P11_Announce")
        net.WriteString(def.glyph .. " " .. tn .. " награждён медалью «" .. def.name .. "»")
        net.WriteString("НАГРАЖДЕНИЕ")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[ПОЧЁТ] " .. tn .. " награждён медалью «" .. def.name .. "» — " .. ply:Nick() .. ".")
    POLUS11.Log("МЕДАЛЬ: " .. ply:Nick() .. " → " .. tn .. " «" .. def.name .. "»")
    return true
end

function POLUS11.MedalRevoke(ply, sid64, idx)
    local scope = POLUS11.MedalScope(ply)
    if scope ~= "full" then
        POLUS11.Notify(ply, "Снимать медали может только Developer+.")
        return false
    end
    sid64 = string.sub(tostring(sid64 or ""), 1, 24)
    local arr = POLUS11.Medals[sid64]
    if not arr then return false end
    idx = math.floor(tonumber(idx) or 0)
    if idx < 1 or idx > #arr then return false end
    table.remove(arr, idx)
    if #arr == 0 then POLUS11.Medals[sid64] = nil end
    MedalSave()
    POLUS11.MedalPush(nil)
    POLUS11.Notify(ply, "Медаль снята.")
    return true
end

-- ============ АВТОНАГРАДЫ (сервер вручает сам) ============

function POLUS11.MedalAutoGrant(ply, medId)
    if not IsValid(ply) then return false end
    local def = POLUS11.MedalDefs[tostring(medId or "")]
    if not def or not def.auto then return false end
    local sid64 = ply:SteamID64()
    if not sid64 then return false end
    local arr = POLUS11.Medals[sid64] or {}
    POLUS11.Medals[sid64] = arr
    if #arr >= MAX_MEDALS then return false end
    for _, m in ipairs(arr) do
        if m.id == medId then return false end
    end
    arr[#arr + 1] = { id = medId, by = "АВТОНАГРАДА", at = os.time() }
    MedalSave()
    POLUS11.MedalPush(nil)

    net.Start("P11_Announce")
        net.WriteString(def.glyph .. " " .. ply:Nick() .. " — АВТОНАГРАДА СТАНЦИИ: медаль «" .. def.name .. "»")
        net.WriteString("АВТОНАГРАДА")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[ПОЧЁТ] " .. ply:Nick() .. " получает автонаграду — медаль «" .. def.name .. "».")
    POLUS11.Notify(ply, def.glyph .. " САМА СТАНЦИЯ наградила тебя медалью «" .. def.name .. "»: " .. def.desc .. ".")
    POLUS11.Log("АВТОМЕДАЛЬ: " .. ply:Nick() .. " («" .. medId .. "» / «" .. def.name .. "»)")
    return true
end

function POLUS11.MedalStatEvent(ply, key, add)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid64 = ply.SteamID64 and ply:SteamID64() or nil
    if not sid64 then return end
    local st = POLUS11.AutoStats[sid64] or {}
    if key == "blood_test" then
        st.tests = (tonumber(st.tests) or 0) + 1
    elseif key == "heal_player" then
        st.heals = (tonumber(st.heals) or 0) + (tonumber(add) or 1)
    elseif key == "damage_thing" then
        st.dmg = (tonumber(st.dmg) or 0) + (tonumber(add) or 1)
    else
        return
    end
    POLUS11.AutoStats[sid64] = st
    statDirty = true
    for id, a in pairs(POLUS11.AutoMedals) do
        if (tonumber(st[a.stat]) or 0) >= a.need then
            POLUS11.MedalAutoGrant(ply, id)
        end
    end
end

-- звено в цепи TaskEvent (не рвёт цепочку других модулей)
do
    local base = POLUS11.TaskEvent
    POLUS11.TaskEvent = function(ply, key, add)
        if base then base(ply, key, add) end
        POLUS11.MedalStatEvent(ply, key, add)
    end
end

-- страховка автонаград: раз в 2 минуты сервер сверяет счётчики
timer.Create("P11.MedalAutoTick", 120, 0, function()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local st = POLUS11.AutoStats[p:SteamID64()]
            if st then
                for id, a in pairs(POLUS11.AutoMedals) do
                    if (tonumber(st[a.stat]) or 0) >= a.need then
                        POLUS11.MedalAutoGrant(p, id)
                    end
                end
            end
        end
    end
end)

-- ============ NET ============

net.Receive("P11_MedalAct", function(_, ply)
    if not IsValid(ply) then return end
    ply.P11_MedalNext = ply.P11_MedalNext or 0
    if CurTime() < ply.P11_MedalNext then return end
    ply.P11_MedalNext = CurTime() + 0.5

    local act = net.ReadUInt(4)
    if act == 9 then -- просто пересинк (просит клиентская вкладка)
        POLUS11.MedalPush(ply)
        return
    end
    local sid64 = string.sub(net.ReadString() or "", 1, 24)
    if act == 1 then
        POLUS11.MedalAward(ply, sid64, string.sub(net.ReadString() or "", 1, 20))
    elseif act == 2 then
        POLUS11.MedalRevoke(ply, sid64, math.floor(net.ReadUInt(6)))
    end
end)

-- консоль Главы (замок p11_cmdlock): p11_medalgive <сид64|ник> <id>
concommand.Add("p11_medalgive", function(ply, _, args)
    if IsValid(ply) then return end -- только консоль сервера
    local sid64, medId = tostring(args[1] or ""), tostring(args[2] or "")
    for _, p in ipairs(player.GetAll()) do
        if string.lower(p:Nick()):find(string.lower(sid64), 1, true) then
            sid64 = p:SteamID64() break
        end
    end
    local def = POLUS11.MedalDefs[medId]
    if not def then print("[МЕДАЛИ] нет знака «" .. medId .. "»") return end
    local arr = POLUS11.Medals[sid64] or {}
    POLUS11.Medals[sid64] = arr
    for _, m in ipairs(arr) do
        if m.id == medId then print("[МЕДАЛИ] у игрока уже есть «" .. def.name .. "»") return end
    end
    arr[#arr + 1] = { id = medId, by = "КОНСОЛЬ", at = os.time() }
    MedalSave()
    POLUS11.MedalPush(nil)
    print("[МЕДАЛИ] консоль: " .. sid64 .. " + «" .. def.name .. "»")
end)

print("[POLUS-11] медали «ПОЧЁТ» (server) v5.2.3 → v2 (НОВЫЙ ФАЙЛ): реестр + синк WriteString + автонаграды")
