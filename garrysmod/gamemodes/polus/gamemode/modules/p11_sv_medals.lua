-- ============================================================
--  ПОЛЮС-11 — МЕДАЛИ «ПОЧЁТ» (server) v4.19.4
--  Заявка владельца: «добавь систему медалий, в ТАБе будет при
--  открытии и над игроком над ником; выдавать могут фракционный
--  лидер и Developer и выше по рангу; админы — в отдельной
--  вкладке (Доска Почёта)».
--
--  ХРАНЕНИЕ: data/polus11/medals.json
--    [steamid64] = { {id=..., by="ник выдавшего", at=unix}, ... }
--  КЛИЕНТУ: весь реестр одним пакетом P11_MedalSync (JSON,
--  сжат): каталог знаков + список sid64 → {id,...}. Пакет летит
--  при входе игрока и после каждой выдачи/снятия.
--
--  ПРАВА ВЫДАЧИ (сервер решает ВСЕГДА, клиент лишь показывает):
--   • ранг Developer (ур.9) и выше   → ВСЕ медали, снятие тоже;
--   • Faction Leader (wl-ранг)       → только ВЕДОМСТВЕННЫЕ
--     (dept=true), не себе, перезарядка 5 минут между наградами.
-- ============================================================

util.AddNetworkString("P11_MedalSync")
util.AddNetworkString("P11_MedalAct")

local FILE = "polus11/medals.json"
local MAX_MEDALS = 10        -- у одного бойца
local LEADER_CD  = 300       -- сек между наградами Faction Leader'а

-- ★ глифы только из WGL4-набора (Arial/Roboto рисуют их у всех,
--   эмодзи в кастомные шрифты станции не жгём — устав сборки).
POLUS11.MedalDefs = {
    -- -- ведомственные (может Faction Leader и Developer+) --
    zorkiy   = { glyph = "○", name = "Зоркий Глаз",        dept = true,  desc = "за бдительность и вовремя поднятую тревогу" },
    obhod    = { glyph = "▲", name = "Честная Вахта",      dept = true,  desc = "постовая дисциплина: вахта ни разу не брошена" }, -- v4.19.5 «ДОПРОС»: патруля нет — знак переименован (id тот же, сейвы целы)
    sluzhba  = { glyph = "■", name = "Верная Служба",      dept = true,  desc = "верность станции, уставу и смене" },
    -- -- штабные (только Developer и выше) --
    geroy    = { glyph = "★", name = "Герой Полюса",       dept = false, desc = "высшая отметка: подвиг во имя гарнизона" },
    mercy    = { glyph = "♥", name = "Милосердие",         dept = false, desc = "за спасённые жизни бойцов" },
    poriadok = { glyph = "♦", name = "Хранитель Порядка",  dept = false, desc = "порядок на станции — его рук дело" },
    veteran  = { glyph = "◆", name = "Ветеран Станции",    dept = false, desc = "долгие смены, пережитые бури и Нечто" },
    legenda  = { glyph = "☆", name = "Легенда Полюса",     dept = false, desc = "о таком расскажут следующим зимовкам" },
}

POLUS11.Medals = POLUS11.Medals or {}

-- ============ ЗАГРУЗКА / СОХРАНЕНИЕ ============

local function MedalSave()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(FILE, util.TableToJSON(POLUS11.Medals, true) or "{}")
end

local function MedalLoad()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then POLUS11.Medals = tbl end
end

hook.Add("InitPostEntity", "P11.MedalLoad", function()
    timer.Simple(1.2, MedalLoad)
end)
hook.Add("PlayerDisconnected", "P11.MedalBye", function() MedalSave() end)

-- ============ ПРАВА ============

--- Возвращает "full" (Developer+, всё можно), "dept" (Faction
--- Leader, только ведомственные, не себе) или nil (нельзя).
function POLUS11.MedalScope(ply)
    if not IsValid(ply) then return nil end
    if ply:IsListenServerHost() then return "full" end
    if P11FW and P11FW.GetRankLevel then
        local lvl = tonumber(P11FW.GetRankLevel(ply)) or 0
        if lvl >= 9 then return "full" end
        local r = P11FW.GetRank and P11FW.GetRank(ply)
        if r and r.id == "faction_leader" then return "dept" end
    end
    return nil
end

-- ============ СИНХРОНИЗАЦИЯ ============

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
    return util.Compress(util.TableToJSON({ defs = defs, list = list }) or "{}")
end

function POLUS11.MedalPush(ply)
    local blob = MedalPacket()
    net.Start("P11_MedalSync")
        net.WriteData(blob, #blob)
    if IsValid(ply) then net.Send(ply) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "P11.MedalJoin", function(ply)
    timer.Simple(6, function()
        if IsValid(ply) then POLUS11.MedalPush(ply) end
    end)
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
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return false
    end
    local def = POLUS11.MedalDefs[tostring(medId or "")]
    if not def then return false end
    sid64 = string.sub(tostring(sid64 or ""), 1, 24)
    if sid64 == "" then return false end

    if scope == "dept" then
        if not def.dept then
            POLUS11.Notify(ply, "Faction Leader вручает только ВЕДОМСТВЕННЫЕ медали (○ ▲ ■). Штабные — ранг Developer+.")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return false
        end
        if IsValid(ply) and ply.SteamID64 and ply:SteamID64() == sid64 then
            POLUS11.Notify(ply, "Самому себе медаль не вручают — честь отмечают другие.")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return false
        end
        ply.P11_MedalCD = ply.P11_MedalCD or 0
        if CurTime() < ply.P11_MedalCD then
            POLUS11.Notify(ply, "Следующая награда через " .. math.ceil(ply.P11_MedalCD - CurTime()) .. " сек — орденская казна не резиновая.")
            ply:EmitSound("buttons/button10.wav", 60, 90)
            return false
        end
        ply.P11_MedalCD = CurTime() + LEADER_CD
    end

    POLUS11.Medals[sid64] = POLUS11.Medals[sid64] or {}
    local arr = POLUS11.Medals[sid64]
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
    -- плашка станции (та же труба, что у «РЕПРОДУКТОРА»)
    net.Start("P11_Announce")
        net.WriteString(def.glyph .. " " .. tn .. " награждён медалью «" .. def.name .. "»")
        net.WriteString("НАГРАЖДЕНИЕ")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[ПОЧЁТ] " .. tn .. " награждён медалью «" .. def.name .. "» — " .. ply:Nick() .. ".")
    POLUS11.Log("МЕДАЛЬ: " .. ply:Nick() .. " → " .. tn .. " «" .. def.name .. "» (" .. medId .. ")")

    for _, p in ipairs(player.GetAll()) do
        if p:SteamID64() == sid64 then
            p:EmitSound("buttons/button15.wav", 70, 100)
            POLUS11.Notify(p, def.glyph .. " Тебя наградили медалью «" .. def.name .. "»: " .. def.desc .. ".")
        end
    end
    return true
end

function POLUS11.MedalRevoke(ply, sid64, idx)
    if POLUS11.MedalScope(ply) ~= "full" then
        POLUS11.Notify(ply, "Снятие медалей — только ранг Developer и выше (через вкладку МЕДАЛИ).")
        ply:EmitSound("buttons/button10.wav", 60, 90)
        return false
    end
    local arr = POLUS11.Medals[tostring(sid64)]
    if not istable(arr) then return false end
    idx = math.floor(tonumber(idx) or #arr)
    local m = arr[idx]
    if not m then return false end
    local def = POLUS11.MedalDefs[m.id]
    table.remove(arr, idx)
    if #arr == 0 then POLUS11.Medals[tostring(sid64)] = nil end
    MedalSave()
    POLUS11.MedalPush(nil)
    POLUS11.Notify(ply, "Медаль «" .. (def and def.name or m.id) .. "» снята с " .. MedalNick(sid64) .. ".")
    POLUS11.Log("МЕДАЛЬ СНЯТА: " .. ply:Nick() .. " у " .. MedalNick(sid64) .. " «" .. (def and def.name or m.id) .. "»")
    return true
end

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
        local medId = string.sub(net.ReadString() or "", 1, 20)
        POLUS11.MedalAward(ply, sid64, medId)
    elseif act == 2 then
        local idx = math.floor(net.ReadUInt(6) or 0)
        POLUS11.MedalRevoke(ply, sid64, idx)
    end
end)

-- консоль Главы (замок p11_cmdlock: ранг 16): p11_medalgive <сид64|ник> <id>
concommand.Add("p11_medalgive", function(ply, _, args)
    if IsValid(ply) then return end -- только консоль сервера (внутри уже гейт Главы)
    local sid64, medId = tostring(args[1] or ""), tostring(args[2] or "")
    for _, p in ipairs(player.GetAll()) do
        if string.lower(p:Nick()):find(string.lower(sid64), 1, true) then
            sid64 = p:SteamID64() break
        end
    end
    local arr = POLUS11.Medals[sid64] or {}
    POLUS11.Medals[sid64] = arr
    local def = POLUS11.MedalDefs[medId]
    if not def then print("[МЕДАЛИ] нет знака «" .. medId .. "»") return end
    arr[#arr + 1] = { id = medId, by = "КОНСОЛЬ", at = os.time() }
    MedalSave()
    POLUS11.MedalPush(nil)
    print("[МЕДАЛИ] консоль: " .. sid64 .. " + «" .. def.name .. "»")
end)

print("[POLUS-11] медали «ПОЧЁТ» v4.19.4: реестр+синк; выдают Faction Leader (ведомств.) и Developer+ (все, вкладка МЕДАЛИ)")
