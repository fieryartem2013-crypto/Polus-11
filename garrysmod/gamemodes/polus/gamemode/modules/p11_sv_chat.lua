-- ============================================================
--  ПОЛЮС-11 — ЧАТ (server) v4.6.8 — ПОЛНОСТЬЮ С НУЛЯ
--  Минимум движущихся частей, всё проверяемо с консоли.
--  Каналы:
--   • обычный текст       — РЕЧЬ (рядом ~700)
--   • /ooc (//)           — общий нонрп (всем)
--   • /looc               — локальный нонрп (~500)
--   • /me                 — действие от 1 лица (~700)
--   • /it                 — мир от 3 лица (~700)
--   • /report             — тикет администрации
--  Диагностика: p11_chatdiag (серверная консоль/админ).
-- ============================================================

util.AddNetworkString("P11_ChatMsg")

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

local function ChatSend(chan, name, text, who, nameCol)
    net.Start("P11_ChatMsg")
        net.WriteUInt(chan, 4)
        net.WriteString(tostring(name or "?"))
        net.WriteString(string.sub(tostring(text or ""), 1, 300))
        net.WriteColor(nameCol or color_white)
    if who then net.Send(who) else net.Broadcast() end
end
POLUS11.ChatSend = ChatSend

-- позывной: личина Нечто > RP-ник > стим-ник (всё под защитой pcall)
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

-- чужие команды не глотаем
local FOREIGN = {
    "/r ", "/р ", "/приказ", "/розыск", "/персонаж", "/перс",
    "/char", "/name", "/ник", "/f4", "/menu", "/работа", "/job",
    "/профа", "/рейд", "/итем", "/багаж", "/дать", "/кошелёк",
}

local function ChatCore(ply, text)
    local raw = string.Trim(tostring(text or ""))
    if raw == "" then return "" end
    local low = string.lower(raw)

    if string.StartWith(low, "!") then return end -- другие модули

    local muted = P11FW.IsMuted and P11FW.IsMuted(ply)
    local isReport = string.StartWith(low, "/report") or string.StartWith(low, "/репорт")
    if muted and not isReport then return end -- MuteGate уже сказал причину

    -- репорт/тикет администрации (работает и в муте — последняя линия связи)
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

    -- чужие слэш-команды пропускаем дальше
    if string.StartWith(low, "/") then
        for _, pfx in ipairs(FOREIGN) do
            if string.StartWith(low, pfx) then return end
        end
        ply:ChatPrint("[ПОЛЮС-11] Каналы: текст = речь • // • /ooc • /looc • /me • /it • /report • /r")
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
        print("[POLUS-11] ЧАТ: ошибка обработчика (выше), сообщение ушло в ваниль")
        return -- nil: движок покажет сам, клиент ловит OnPlayerChat
    end
    return ret
end)

-- ============ ДИАГНОСТИКА ============
concommand.Add("p11_chatdiag", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    local who = IsValid(ply) and ply or nil
    ChatSend(POLUS11.ChatCh.IC,  "СИСТЕМА", "тест РЕЧИ (видна в радиусе 700)", who, Color(120, 255, 120))
    ChatSend(POLUS11.ChatCh.OOC, "СИСТЕМА", "тест OOC (видна всем)", who, Color(120, 255, 120))
    ChatSend(POLUS11.ChatCh.ME,  "СИСТЕМА", "тест ME-действия", who, Color(120, 255, 120))
    local msg = "[P11CHAT] v4.6.8: тесты IC/OOC/ME отправлены"
    if IsValid(ply) then P11FW.Notify(ply, msg) end
    print(msg)
    print("[P11CHAT] у клиента должно быть в консоли: [P11CHAT] v4.6.8 OK. Нет — ставь файлы v4.6.8, не правь поверх.")
end)

print("[POLUS-11] чат v4.6.8 (с нуля) загружен: речь // /ooc /looc /me /it /report")
