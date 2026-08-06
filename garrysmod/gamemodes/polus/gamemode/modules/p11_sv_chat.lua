-- ============================================================
--  ПОЛЮС-11 — СВОЙ ЧАТ (server) v4.5.0
--  Каналы RP-сервера:
--   • обычный текст        — ИГРОК (говорит), слышат рядом (~700 юн)
--   • /ooc <текст>  (// )  — общий НОНРП для всего сервера
--   • /looc <текст>        — локальный НОНРП (~500 юн)
--   • /me <текст>          — действие от 1 лица (~700 юн)
--   • /it <текст>          — окружающий мир от 3 лица (~700 юн)
--   • /report <текст>      — жалоба-тикет администрации (всем админам)
--  Имена в чате — ПОЗЫВНЫЕ (POLUS11.DisplayName: личина Нечто >
--  RP-ник персонажа > стим-ник). Мут честный (кроме /report —
--  жалоба последний канал связи). Команды других модулей
--  (!ролл, /r, /приказ...) НЕ трогаем — они живут своей жизнью.
-- ============================================================

util.AddNetworkString("P11_ChatMsg")

-- id каналов (совпадают на клиенте)
POLUS11.ChatCh = {
    IC     = 1,
    OOC    = 2,
    LOOC   = 3,
    ME     = 4,
    IT     = 5,
    REPORT = 6,
}

local R_IC, R_LOOC, R_ME = 700, 500, 700

-- кто услышит радиусное сообщение
local function InRadius(around, radius)
    local r2 = radius * radius
    local out = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:GetPos():DistToSqr(around) <= r2 then
            out[#out + 1] = p
        end
    end
    return out
end

-- отправка пакета (nameCol — цвет имени, обычно цвет должности)
local function ChatSend(chan, name, text, who, nameCol)
    net.Start("P11_ChatMsg")
        net.WriteUInt(chan, 4)
        net.WriteString(name)
        net.WriteString(string.sub(text, 1, 300))
        net.WriteColor(nameCol or Color(255, 255, 255))
    if who then net.Send(who) else net.Broadcast() end
end
POLUS11.ChatSend = ChatSend

-- имя говорящего: личина Нечто > RP-ник > стим-ник
local function NameOf(ply)
    if POLUS11.DisplayName then return POLUS11.DisplayName(ply) end
    return ply:Nick()
end

-- префиксы чужих команд, которые мы НЕ должны глотать
local FOREIGN = {
    "/r ", "/р ", "/приказ", "/розыск", "/персонаж", "/перс",
    "/char", "/name", "/ник", "/f4", "/menu", "/работа", "/job",
    "/профа", "/рейд", "/итем", "/багаж", "/дать", "/кошелёк",
}

local function ChatCore(ply, text)
    if not IsValid(ply) then return end
    local raw = string.Trim(text or "")
    if raw == "" then return "" end
    local low = string.lower(raw)

    -- восклицательные команды точно не наши (ролл, деньги, приказы и т.д.)
    if string.StartWith(low, "!") then return end

    -- мут: жалобу (/report) пропускаем, остальное глушим
    local muted = P11FW.IsMuted and P11FW.IsMuted(ply)
    local isReport = string.StartWith(low, "/report") or string.StartWith(low, "/репорт")
    if muted and not isReport then return end -- MuteGate сам глушит и шлёт плакат

    -- ============ ПРЕФИКС-КАНАЛЫ ============
    local ch, off
    if string.StartWith(low, "//") then                                 ch, off = POLUS11.ChatCh.OOC, 3
    elseif string.StartWith(low, "/ooc ")  then                         ch, off = POLUS11.ChatCh.OOC, 6
    elseif string.StartWith(low, "/оос ")  then                         ch, off = POLUS11.ChatCh.OOC, 7
    elseif string.StartWith(low, "/looc ") then                         ch, off = POLUS11.ChatCh.LOOC, 7
    elseif string.StartWith(low, "/лоок ") then                         ch, off = POLUS11.ChatCh.LOOC, 7
    elseif string.StartWith(low, "/me ")   then                         ch, off = POLUS11.ChatCh.ME, 5
    elseif string.StartWith(low, "/мя ")   then                         ch, off = POLUS11.ChatCh.ME, 6
    elseif string.StartWith(low, "/it ")   then                         ch, off = POLUS11.ChatCh.IT, 5
    elseif string.StartWith(low, "/ит ")   then                         ch, off = POLUS11.ChatCh.IT, 6
    elseif isReport then
        -- /report / /репорт — тикет админам (есть и !репорт в p11_sv_command)
        local rest = string.Trim(string.sub(raw, (string.StartWith(low, "/report") and 8 or 9) + 1))
        if rest == "" then
            ply:ChatPrint("[ПОЛЮС-11] Напиши суть жалобы: /report <текст>")
            return ""
        end
        if POLUS11.SendReport then POLUS11.SendReport(ply, rest) end
        ply:ChatPrint("[ПОЛЮС-11] Репорт отправлен администрации.")
        return ""
    end

    if ch then
        local msg = string.Trim(string.sub(raw, off))
        if msg == "" then return "" end
        local name = NameOf(ply)
        local ncol = team.GetColor(ply:Team())
        if ch == POLUS11.ChatCh.OOC then
            ChatSend(ch, name, msg, nil, ncol) -- всем
        elseif ch == POLUS11.ChatCh.LOOC then
            ChatSend(ch, name, msg, InRadius(ply:GetPos(), R_LOOC), ncol)
        else -- ME / IT
            ChatSend(ch, name, msg, InRadius(ply:GetPos(), R_ME), ncol)
        end
        return ""
    end

    -- чужие «/команды» — мимо нас
    if string.StartWith(low, "/") then
        for _, pfx in ipairs(FOREIGN) do
            if string.StartWith(low, pfx) then return end
        end
        -- неизвестная слэш-команда: тихо подскажем
        ply:ChatPrint("[ПОЛЮС-11] Команды чата: текст = речь • /ooc • /looc • /me • /it • /report • /r • /приказ")
        return ""
    end

    -- ============ ОБЫЧНАЯ РЕЧЬ (ИГРОК, локально) ============
    ChatSend(POLUS11.ChatCh.IC, NameOf(ply), raw, InRadius(ply:GetPos(), R_IC), team.GetColor(ply:Team()))
    return ""
end

-- v4.6.3: ПРЕДОХРАНИТЕЛЬ. Если в нашем чате где-то ошибка — сообщение
-- НЕ проглатываем молча: пишем в консоль сервера и отпускаем в обычный
-- движок (лента на клиенте ловит его через OnPlayerChat-перехват).
hook.Add("PlayerSay", "P11.ChatCore", function(ply, text)
    local ok, ret = xpcall(function() return ChatCore(ply, text) end, function(err)
        ErrorNoHalt("[POLUS-11 CHAT ERROR] " .. tostring(err) .. "\n")
    end)
    if not ok then
        print("[POLUS-11] ЧАТ: ошибка обработчика, сообщение отпущено в ваниль:", ply, text)
        return -- nil: пусть скажет штатно
    end
    return ret
end)

print("[POLUS-11] свой чат (ядро) загружен: /ooc /looc /me /it /report")
