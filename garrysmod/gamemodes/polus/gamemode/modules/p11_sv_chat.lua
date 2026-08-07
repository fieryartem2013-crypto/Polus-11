-- ============================================================
--  ПОЛЮС-11 — ЧАТ (server) v5 «РЕЛЕ» — пересоздан С НУЛЯ
--  АРХИТЕКТУРА ОТКАЗОУСТОЙЧИВОСТИ:
--   • Каждое сообщение уходит СРАЗУ ДВУМЯ дорогами:
--       1) богатая лента P11_ChatMsg (цвета/каналы) — клиентам
--          в ПОЛНОМ режиме (режим 0);
--       2) ДВИЖКОВОЕ зеркало через ChatPrint — клиентам в
--          ДВИЖКОВОМ режиме (режим 1) и всем, чей режим неизвестен.
--     Если причуда клиентской машины ломает нашу ленту, движковый
--     чат всё равно показывает СЛОВО В СЛОВО — ничего не теряется.
--   • Клиент докладывает режим пакетом P11_ChatMode + рукопожатие
--     P11_ChatHello (сервер отвечает ack с мажором протокола);
--     p11_chatdiag показывает живые режимы всех он-лайн клиентов.
--  КАНАЛЫ: РЕЧЬ (~700) • // = /ooc (всем) • /looc (~500) • /me •
--  /it • /report (тикет админам, работает и в муте).
--  Диагностика: p11_chatdiag (админ/серверная консоль).
-- ============================================================

util.AddNetworkString("P11_ChatMsg")
util.AddNetworkString("P11_ChatMode")   -- клиент → сервер: его режим (0/1)
util.AddNetworkString("P11_ChatHello")  -- клиент → сервер → ack обратно

local MAJOR = 5 -- версия протокола чата (должна совпасть с клиентской)

POLUS11.ChatCh = { IC = 1, OOC = 2, LOOC = 3, ME = 4, IT = 5, REPORT = 6 }

local R_NEAR, R_LOOC = 700, 500

-- живая аудитория в радиусе
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

-- плоская строка для движкового зеркала (без цветов, но читаема)
local function MirrorLine(chan, name, text)
    if chan == POLUS11.ChatCh.OOC    then return "[OOC] " .. name .. ": " .. text end
    if chan == POLUS11.ChatCh.LOOC   then return "[LOOC] " .. name .. ": " .. text end
    if chan == POLUS11.ChatCh.ME     then return "* " .. name .. " " .. text end
    if chan == POLUS11.ChatCh.IT     then return "*** " .. text end
    if chan == POLUS11.ChatCh.REPORT then return "[РЕПОРТ] " .. name .. ": " .. text end
    return name .. ": " .. text -- РЕЧЬ
end

-- режим клиента: nil = ещё не докладывал → считаем ДВИЖКОВЫМ (зеркалим!)
local function IsEngineMode(ply)
    return (ply.P11ChatMode or 1) ~= 0
end

local function ChatSend(chan, name, text, who, nameCol)
    text = string.sub(tostring(text or ""), 1, 300)
    name = tostring(name or "?")
    local audience = who or player.GetAll()

    local netList = {}
    local engineText = MirrorLine(chan, name, text)
    for _, p in ipairs(audience) do
        if IsValid(p) then
            if IsEngineMode(p) then
                p:ChatPrint(engineText)        -- дорога 2: движковое зеркало
            else
                netList[#netList + 1] = p      -- дорога 1: богатая лента
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
end
POLUS11.ChatSend = ChatSend

-- позывной: личина Нечто > RP-ник > стим-ник (всё под pcall)
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

-- чужие слэш-команды НЕ глотаем (все чат-команды сборки!)
local FOREIGN = {
    "/r ", "/р ", "/приказ", "/розыск", "/персонаж", "/перс",
    "/char", "/name", "/ник", "/f4", "/menu", "/работа", "/job",
    "/профа", "/рейд", "/итем", "/багаж", "/дать", "/кошелёк",
    "/деньги", "/money", "/баланс", -- экономика
    "/ларёк", "/ларек", "/магазин", "/shop", -- ларёк v4.6.9
    "/обмен", "/trade", -- обмен v4.6.9
    "/p11", -- все служебные p11_*
}

local function ChatCore(ply, text)
    local raw = string.Trim(tostring(text or ""))
    if raw == "" then return "" end
    local low = string.lower(raw)

    if string.StartWith(low, "!") then return end -- чужие банг-команды

    local muted = P11FW.IsMuted and P11FW.IsMuted(ply)
    local isReport = string.StartWith(low, "/report") or string.StartWith(low, "/репорт")
    if muted and not isReport then return end -- MuteGate уже сказал причину

    -- репорт/тикет администрации (работает и в муте)
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

    -- префикс-каналы
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
        else -- ME / IT
            ChatSend(ch, NameOf(ply), raw, InRadius(ply:GetPos(), R_NEAR), ColorOf(ply))
        end
        return ""
    end

    -- чужие слэш-команды — их модули разберутся сами
    if string.StartWith(low, "/") then
        for _, pfx in ipairs(FOREIGN) do
            if string.StartWith(low, pfx) then return end
        end
        ply:ChatPrint("[ПОЛЮС-11] Каналы: текст = речь • // • /ooc • /looc • /me • /it • /report • /r • /ларёк • /обмен")
        return ""
    end

    -- обычная речь (рядом)
    ChatSend(POLUS11.ChatCh.IC, NameOf(ply), raw, InRadius(ply:GetPos(), R_NEAR), ColorOf(ply))
    return ""
end

hook.Add("PlayerSay", "P11.ChatCore", function(ply, text)
    local ok, ret = xpcall(function() return ChatCore(ply, text) end, function(err)
        ErrorNoHalt("[POLUS-11 CHAT ERROR] " .. tostring(err) .. "\n")
    end)
    if not ok then
        print("[POLUS-11] ЧАТ: ошибка обработчика (выше), сообщение ушло движку")
        return -- nil: движок покажет сам
    end
    return ret
end)

-- ============ СИНХРОНИЗАЦИЯ РЕЖИМА КЛИЕНТА ============

net.Receive("P11_ChatMode", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11ChatMode = (net.ReadUInt(2) == 0) and 0 or 1
end)

net.Receive("P11_ChatHello", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11ChatHelloAt = CurTime()
    ply.P11ChatClient = net.ReadUInt(4) or 0 -- мажор клиента
    -- ack: мажор протокола сервера
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
        net.WriteBool(true)
    net.Send(ply)
end)

-- ============ ДИАГНОСТИКА ============
concommand.Add("p11_chatdiag", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end

    local out = { "== ЧАТ v5 «РЕЛЕ»: ДИАГНОСТИКА СЕРВЕРА ==" }
    out[#out + 1] = "  модуль: загружен ✔ | протокол: v" .. MAJOR .. " | клиенты v6 «СТОК» докладывают режим 0"
    for _, p in ipairs(player.GetAll()) do
        local mode = p.P11ChatMode
        out[#out + 1] = string.format("  %-22s режим=%s | клиент чата v%d | hello %s",
            p:Nick(),
            mode == 0 and "0/СВОЙ" or (mode == 1 and "1/ДВИЖОК" or "? (зеркало ВКЛ)"),
            p.P11ChatClient or 0,
            p.P11ChatHelloAt and (math.floor(CurTime() - p.P11ChatHelloAt) .. "с назад") or "НЕ БЫЛО")
    end
    out[#out + 1] = "  тестовые пакеты IC/OOC/ME отправлены (смотри чат)."

    local who = IsValid(ply) and ply or nil
    ChatSend(POLUS11.ChatCh.IC,  "СИСТЕМА", "тест РЕЧИ (радиус 700)", who, Color(120, 255, 120))
    ChatSend(POLUS11.ChatCh.OOC, "СИСТЕМА", "тест OOC (всем)", who, Color(120, 255, 120))
    ChatSend(POLUS11.ChatCh.ME,  "СИСТЕМА", "тест ME-действия", who, Color(120, 255, 120))

    local txt = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, txt) else print(txt) end
end)

print("[P11CHAT-SV] чат v5/v6 загружен: роутинг каналов + движковое зеркало тем, кто не поздоровался (клиенты v6 СТОК — штатный чат)")
