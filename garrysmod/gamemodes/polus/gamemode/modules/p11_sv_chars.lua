-- ============================================================
--  ПОЛЮС-11 — ДЕЛО БОЙЦА (server) v4.3.0
--  Персонаж игрока: ПОЗЫВНОЙ (ник) + ОПИСАНИЕ внешности.
--   • при первом заходе сервер спрашивает анкету (P11_CharAsk);
--   • хранится в data/polus11/chars.json по SteamID64 —
--     живёт до конца сервера (и переживает рестарт);
--   • синк всем: P11_CharName / P11_CharDesc (NW);
--   • редактор снова: чат /персонаж, C-меню «Мой персонаж»;
--   • Нечто, съев труп, носит и описание жертвы (P11_FakeDesc).
-- ============================================================

util.AddNetworkString("P11_CharAsk")
util.AddNetworkString("P11_CharSave")

local CHAR_PATH = "polus11/chars.json"
POLUS11.Chars = POLUS11.Chars or {}

local function CharLoad()
    local raw = file.Read(CHAR_PATH, "DATA")
    if not raw or raw == "" then return end
    local ok, t = pcall(util.JSONToTable, raw)
    if ok and istable(t) then POLUS11.Chars = t end
end

local saveT = 0
local function CharSave()
    saveT = CurTime() + 2
end
timer.Create("P11.CharsSave", 1, 0, function()
    if saveT > 0 and CurTime() >= saveT then
        saveT = 0
        if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
        file.Write(CHAR_PATH, util.TableToJSON(POLUS11.Chars))
    end
end)

local function SidOf(ply)
    local sid = ply:SteamID64()
    if not sid or sid == "0" then sid = ply:SteamID() end
    return sid
end

local function CharSync(ply)
    local c = ply.P11_Char
    ply:SetNWString("P11_CharName", (c and isstring(c.name)) and c.name or "")
    ply:SetNWString("P11_CharDesc", (c and isstring(c.desc)) and c.desc or "")
end
POLUS11.CharSync = CharSync

-- отображаемое имя бойца: личина Нечто > позывной > стим-ник
function POLUS11.DisplayName(ply)
    if not IsValid(ply) then return "?" end
    local f = ply:GetNWString("P11_FakeNick", "")
    if f ~= "" then return f end
    local c = ply:GetNWString("P11_CharName", "")
    if c ~= "" then return c end
    return ply:Nick()
end

-- открыть анкету у игрока (первый заход / правка)
local function AskChar(ply)
    if not IsValid(ply) then return end
    net.Start("P11_CharAsk")
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "P11.CharsJoin", function(ply)
    timer.Simple(6, function()
        if not IsValid(ply) then return end
        local saved = POLUS11.Chars[SidOf(ply)]
        if saved then
            ply.P11_Char = saved
            CharSync(ply)
        else
            AskChar(ply)
        end
    end)
end)

-- приём анкеты
net.Receive("P11_CharSave", function(_, ply)
    if not IsValid(ply) then return end
    if (ply.P11_CharSaveCD or 0) > CurTime() then return end
    ply.P11_CharSaveCD = CurTime() + 2

    local function Clean(str, maxLen)
        str = tostring(str or "")
        str = string.gsub(str, "[%c\n\r\t]+", " ")  -- никаких переводов строк/управляющих
        str = string.gsub(str, "%s%s+", " ")        -- схлопнуть пробелы
        str = string.Trim(str)
        if #str > maxLen then str = string.sub(str, 1, maxLen) end
        return str
    end

    local name = Clean(net.ReadString(), 32)
    local desc = Clean(net.ReadString(), 140)

    if #name < 3 then
        POLUS11.Notify(ply, "Позывной слишком короткий (минимум 3 символа). Анкета вернулась к вам.")
        timer.Simple(0.5, function() if IsValid(ply) then AskChar(ply) end end)
        return
    end

    ply.P11_Char = { name = name, desc = desc, at = os.time() }
    POLUS11.Chars[SidOf(ply)] = ply.P11_Char
    CharSave()
    CharSync(ply)

    POLUS11.Notify(ply, "Дело записано: «" .. name .. "». Увидеть может каждый, кто посмотрит на вас.")
    POLUS11.Log("ПЕРСОНАЖ: " .. ply:Nick() .. " → «" .. name .. "» (" .. #desc .. " зн. описания)")
end)

-- редактор по команде
hook.Add("PlayerSay", "P11.CharsSay", function(ply, text)
    local t = string.lower(string.Trim(text or ""))
    if t == "/персонаж" or t == "/char" or t == "/перс" or t == "!персонаж" then
        AskChar(ply)
        return ""
    end
end)

print("[POLUS-11] дело бойца (персонажи) загружено")
CharLoad()
