-- ============================================================
--  ПОЛЮС-11 — ЧАТ (server) v7 «ФИЛЬТР» — ПРОЗРАЧНЫЙ, С НУЛЯ
--  Чем отличается от всех прошлых ревизий: ПОЛНАЯ ОСВЕЩЕННОСТЬ.
--  Каждая ступень маршрута сообщения видна в консоли сервера
--  (трейс), а диагностика показывает ВСЕ обработчики PlayerSay —
--  чужой чат-аддон виден мгновенно. Плюс аварийный выключатель:
--  p11_chat_passthrough 1 = чистый движковый чат (роутинг спит).
--
--  АРХИТЕКТУРА ДОРОГ (как в «РЕЛЕ» — она уцелела аудитом):
--   • клиенты v6/v7 (поздоровались, режим 0) — богатые пакеты сетью;
--   • все остальные — ДВИЖКОВОЕ зеркало ChatPrint (запасная дорога).
--
--  КАНАЛЫ: РЕЧЬ (~700) • // = /ooc (всем) • /looc (~500) •
--  /me • /it • /report (тикет, работает и в муте).
--  КОНСОЛЬ СЕРВЕРА: p11_chatdiag • p11_chat_trace 0/1 •
--  p11_chat_passthrough 0/1.
-- ============================================================

util.AddNetworkString("P11_ChatMsg")
util.AddNetworkString("P11_ChatMode")
util.AddNetworkString("P11_ChatHello")

local MAJOR = 6

-- трейс в консоль сервера (включён по умолчанию на время ЗАТ)
local cvTrace = CreateConVar("p11_chat_trace", "1", FCVAR_ARCHIVE,
    "1 = писать каждую ступень чат-маршрута в консоль сервера")
-- аварийный режим: чистый ванильный чат движка (роутинг отключён)
local cvPass = CreateConVar("p11_chat_passthrough", "0", FCVAR_ARCHIVE,
    "1 = чат полностью движковый (без каналов/радиусов)")

local function Trace(msg)
    if cvTrace:GetBool() then print("[CHAT-TRACE] " .. msg) end
end

POLUS11.ChatCh = { IC = 1, OOC = 2, LOOC = 3, ME = 4, IT = 5, REPORT = 6 }
local CHNAME = { [1] = "РЕЧЬ", [2] = "OOC", [3] = "LOOC", [4] = "ME", [5] = "IT", [6] = "РЕПОРТ" }

local R_NEAR, R_LOOC = 700, 500

local function InRadius(pos, radius)
    local r2 = radius * radius
    local out = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p:GetPos():DistToSqr(pos) <= r2 then
            out[#out + 1] = p
        end
    end
    return out
end

local function MirrorLine(chan, name, text)
    if chan == POLUS11.ChatCh.OOC    then return "[OOC] " .. name .. ": " .. text end
    if chan == POLUS11.ChatCh.LOOC   then return "[LOOC] " .. name .. ": " .. text end
    if chan == POLUS11.ChatCh.ME     then return "* " .. name .. " " .. text end
    if chan == POLUS11.ChatCh.IT     then return "*** " .. text end
    if chan == POLUS11.ChatCh.REPORT then return "[РЕПОРТ] " .. name .. ": " .. text end
    return name .. ": " .. text
end

local function IsEngineMode(ply)
    return (ply.P11ChatMode or 1) ~= 0
end

local function ChatSend(chan, name, text, who, nameCol)
    text = string.sub(tostring(text or ""), 1, 300)
    name = tostring(name or "?")
    local audience = who or player.GetAll()

    local netList, mirrors = {}, 0
    local engineText = MirrorLine(chan, name, text)
    for _, p in ipairs(audience) do
        if IsValid(p) then
            if IsEngineMode(p) then
                p:ChatPrint(engineText)
                mirrors = mirrors + 1
            else
                netList[#netList + 1] = p
            end
        end
    end
    if #netList > 0 then
        net.Start("P11_ChatMsg")
            net.WriteUInt(chan, 4)
            net.WriteString(name)
            net.WriteString(text)
            net.WriteColor(nameCol or color_white)
        net.Send(netList)
    end
    Trace("канал=" .. (CHNAME[chan] or chan) .. " | от: " .. name ..
        " | получателей: " .. #netList + mirrors .. " (сеть " .. #netList ..
        ", зеркало " .. mirrors .. ") | «" .. string.sub(text, 1, 60) .. "»")
end
POLUS11.ChatSend = ChatSend

local function NameOf(ply)
    local ok, nm = pcall(function()
        if POLUS11.DisplayName then return POLUS11.DisplayName(ply) end
    end)
    if ok and isstring(nm) and nm ~= "" then return nm end
    return ply:Nick()
end

local function ColorOf(ply)
    local ok, c = pcall(team.GetColor, ply:Team())
    if ok and c then return c end
    return Color(220, 225, 232)
end

local FOREIGN = {
    "/r ", "/р ", "/приказ", "/розыск", "/персонаж", "/перс",
    "/char", "/name", "/ник", "/f4", "/menu", "/работа", "/job",
    "/профа", "/рейд", "/итем", "/багаж", "/дать", "/кошелёк",
    "/деньги", "/money", "/баланс",
    "/ларёк", "/ларек", "/магазин", "/shop",
    "/обмен", "/trade",
    "/p11",
}

local function ChatCore(ply, text)
    local raw = string.Trim(tostring(text or ""))
    if raw == "" then return "" end
    local low = string.lower(raw)

    if string.StartWith(low, "!") then return end

    local muted = P11FW.IsMuted and P11FW.IsMuted(ply)
    local isReport = string.StartWith(low, "/report") or string.StartWith(low, "/репорт")
    if muted and not isReport then
        Trace("ОТКЛОНЕНО мутом: " .. ply:Nick() .. " | «" .. string.sub(raw, 1, 40) .. "»")
        return end

    if isReport then
        local pfx = string.StartWith(low, "/report") and "/report" or "/репорт"
        local rest = string.Trim(string.sub(raw, #pfx + 1))
        if rest == "" then
            ply:ChatPrint("[ПОЛЮС-11] Напиши суть жалобы: /report <текст>")
            return ""
        end
        if POLUS11.SendReport then POLUS11.SendReport(ply, rest) end
        ply:ChatPrint("[ПОЛЮС-11] Репорт отправлен администрации.")
        return ""
    end

    local ch = nil
    if     string.StartWith(low, "//")      then ch = POLUS11.ChatCh.OOC;  raw = string.Trim(string.sub(raw, 3))
    elseif string.StartWith(low, "/ooc ")   then ch = POLUS11.ChatCh.OOC;  raw = string.Trim(string.sub(raw, 6))
    elseif string.StartWith(low, "/оос ")   then ch = POLUS11.ChatCh.OOC;  raw = string.Trim(string.sub(raw, 9))
    elseif string.StartWith(low, "/looc ")  then ch = POLUS11.ChatCh.LOOC; raw = string.Trim(string.sub(raw, 7))
    elseif string.StartWith(low, "/лоок ")  then ch = POLUS11.ChatCh.LOOC; raw = string.Trim(string.sub(raw, 11))
    elseif string.StartWith(low, "/me ")    then ch = POLUS11.ChatCh.ME;   raw = string.Trim(string.sub(raw, 5))
    elseif string.StartWith(low, "/мя ")    then ch = POLUS11.ChatCh.ME;   raw = string.Trim(string.sub(raw, 7))
    elseif string.StartWith(low, "/it ")    then ch = POLUS11.ChatCh.IT;   raw = string.Trim(string.sub(raw, 5))
    elseif string.StartWith(low, "/ит ")    then ch = POLUS11.ChatCh.IT;   raw = string.Trim(string.sub(raw, 7))
    end

    if ch then
        if raw == "" then return "" end
        if ch == POLUS11.ChatCh.OOC then
            ChatSend(ch, NameOf(ply), raw, nil, ColorOf(ply))
        elseif ch == POLUS11.ChatCh.LOOC then
            ChatSend(ch, NameOf(ply), raw, InRadius(ply:GetPos(), R_LOOC), ColorOf(ply))
        else
            ChatSend(ch, NameOf(ply), raw, InRadius(ply:GetPos(), R_NEAR), ColorOf(ply))
        end
        return ""
    end

    if string.StartWith(low, "/") then
        for _, pfx in ipairs(FOREIGN) do
            if string.StartWith(low, pfx) then return end
        end
        ply:ChatPrint("[ПОЛЮС-11] Каналы: текст = речь • // • /ooc • /looc • /me • /it • /report • /r • /ларёк • /обмен")
        return ""
    end

    ChatSend(POLUS11.ChatCh.IC, NameOf(ply), raw, InRadius(ply:GetPos(), R_NEAR), ColorOf(ply))
    return ""
end

hook.Add("PlayerSay", "P11.ChatCore", function(ply, text)
    -- аварийный режим: вообще ничего не роутим, всё движку
    if cvPass:GetBool() then return end

    Trace("ВХОД: " .. ply:Nick() .. " («" .. ply:SteamID() .. "»): «" .. string.sub(tostring(text or ""), 1, 60) .. "»")
    local ok, ret = xpcall(function() return ChatCore(ply, text) end, function(err)
        ErrorNoHalt("[POLUS-11 CHAT ERROR] " .. tostring(err) .. "\n")
    end)
    if not ok then
        print("[POLUS-11] ЧАТ: ошибка обработчика (выше), сообщение ушло движку")
        return
    end
    return ret
end)

-- ============ СИНХРОНИЗАЦИЯ РЕЖИМА КЛИЕНТА ============

net.Receive("P11_ChatMode", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11ChatMode = (net.ReadUInt(2) == 0) and 0 or 1
    Trace("смена режима: " .. ply:Nick() .. " → " .. ply.P11ChatMode)
end)

net.Receive("P11_ChatHello", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11ChatHelloAt = CurTime()
    ply.P11ChatClient = net.ReadUInt(4) or 0
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
        net.WriteBool(true)
    net.Send(ply)
    Trace("hello от " .. ply:Nick() .. " (клиент чата v" .. (ply.P11ChatClient or 0) .. ")")
end)

-- ============ ДИАГНОСТИКА v7 ============
concommand.Add("p11_chatdiag", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end

    local out = { "== ЧАТ v7 «ФИЛЬТР»: ДИАГНОСТИКА СЕРВЕРА ==" }
    out[#out + 1] = "  модуль: загружен ✔ | протокол v" .. MAJOR
        .. " | трейс: " .. tostring(cvTrace:GetBool())
        .. " | аварийный passthrough: " .. tostring(cvPass:GetBool())

    out[#out + 1] = "  -- обработчики PlayerSay (чужой чат-аддон виден здесь!):"
    for name in pairs(hook.GetTable()["PlayerSay"] or {}) do
        out[#out + 1] = "     • " .. tostring(name)
    end

    out[#out + 1] = "  -- игроки:"
    for _, p in ipairs(player.GetAll()) do
        local mode = p.P11ChatMode
        out[#out + 1] = string.format("     %-22s режим=%s | клиент v%d | hello %s",
            p:Nick(),
            mode == 0 and "0/СЕТЬ" or (mode == 1 and "1/ЗЕРКАЛО" or "? (зеркало ВКЛ)"),
            p.P11ChatClient or 0,
            p.P11ChatHelloAt and (math.floor(CurTime() - p.P11ChatHelloAt) .. "с назад") or "НЕ БЫЛО")
    end
    out[#out + 1] = "  ниже летят 3 тестовых пакета — смотри [CHAT-TRACE] выше."
    out[#out + 1] = "  если чат душится без нашего роутинга: p11_chat_passthrough 1 (чистый движок)."

    local who = IsValid(ply) and ply or nil
    ChatSend(POLUS11.ChatCh.IC,  "СИСТЕМА", "тест РЕЧИ (радиус 700)", who, Color(120, 255, 120))
    ChatSend(POLUS11.ChatCh.OOC, "СИСТЕМА", "тест OOC (всем)", who, Color(120, 255, 120))
    ChatSend(POLUS11.ChatCh.ME,  "СИСТЕМА", "тест ME-действия", who, Color(120, 255, 120))

    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[P11CHAT-SV] чат v7 «ФИЛЬТР» загружен: трейс каждого сообщения в консоль (p11_chatdiag / p11_chat_trace / p11_chat_passthrough)")
