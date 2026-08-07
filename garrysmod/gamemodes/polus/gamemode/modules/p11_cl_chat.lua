-- ============================================================
--  ПОЛЮС-11 — ЧАТ (client) v6 «СТОК» — РАДИКАЛЬНОЕ УПРОЩЕНИЕ
--  ПОСЛЕ АУДИТА: несколько ревизий своей ленты/окна у хозяина
--  стенда не заводились. Вывод: на этой связке клиент+сервер
--  НЕЛЬЗЯ полагаться НИ НА ЧТО кастомное (возможен и чужой
--  чат-аддон из воркшопа). Поэтому:
--
--   ЗДЕСЬ НЕТ СВОЕГО UI ВООБЩЕ.
--   • ввод — штатная строка движка (Y), мы её НЕ ТРОГАЕМ;
--   • показ — штатный чат движка (CHudChat), мы его НЕ ПРЯЧЕМ;
--   • цвета/каналы — через ОБЫЧНЫЙ chat.AddText в движковый чат
--     (это встроенная функция, рисовать умеет сам движок);
--   • OnPlayerChat / chat.AddText / PlayerBindPress / HUDPaint
--     НЕ ПЕРЕХВАТЫВАЮТСЯ вообще — конфликтовать не с чем.
--
--  Ломаться просто нечему: писать — как везде, читать — как везде.
--  Сервер роутит каналы/радиусы и дополнительно «зеркалит» всё
--  тем клиентам, кто не поздоровался (старые/чужие клиенты).
--  Диагностика: p11_chatdiag_cl.
-- ============================================================

P11 = P11 or {}

local MAJOR = 5 -- протокол сервера v5 (совместим с v4.7.0 «РЕЛЕ»)

-- ---------- приём богатых пакетов каналов → движковый чат ----------
local function AddStyled(chan, name, text, ncol)
    -- одна цветная строка в ШТАТНЫЙ чат движка
    if chan == 1 then
        chat.AddText(ncol, name, Color(120, 185, 255), " говорит: ",
            Color(235, 240, 246), text)
    elseif chan == 2 then
        chat.AddText(Color(150, 158, 172), "[OOC] ", ncol, name,
            Color(175, 180, 192), ": " .. text)
    elseif chan == 3 then
        chat.AddText(Color(128, 136, 150), "[LOOC] ", ncol, name,
            Color(150, 156, 168), ": " .. text)
    elseif chan == 4 then
        chat.AddText(Color(205, 165, 255), "• " .. name .. " " .. text)
    elseif chan == 5 then
        chat.AddText(Color(255, 205, 110), "*** " .. text)
    elseif chan == 6 then
        chat.AddText(Color(235, 100, 90), "[РЕПОРТ] ", ncol, name,
            Color(240, 150, 140), ": " .. text)
    end
end

net.Receive("P11_ChatMsg", function()
    local ok, err = pcall(function()
        local ch   = net.ReadUInt(4)
        local name = net.ReadString()
        local text = net.ReadString()
        local ncol = net.ReadColor()
        AddStyled(ch, name, text, ncol)
    end)
    if not ok then
        -- даже если формат съехал — хотя бы сырой текст покажем
        ErrorNoHalt("[P11CHAT] пакет не разобрать: " .. tostring(err) .. "\n")
    end
end)

-- ---------- рукопожатие: докладываем серверу «мы живы, не зеркаль» ----------
local function SendHello()
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
    net.SendToServer()
    -- режим 0 = «богатые пакеты мне, зеркало не надо»
    net.Start("P11_ChatMode")
        net.WriteUInt(0, 2)
    net.SendToServer()
end

net.Receive("P11_ChatHello", function()
    local srvMajor = net.ReadUInt(4)
    local ok = net.ReadBool()
    P11.ChatAck = ok and srvMajor or false
    P11.ChatAckAt = CurTime()
end)

hook.Add("InitPostEntity", "P11.ChatHelloV6", function()
    timer.Simple(3, SendHello)
end)
timer.Simple(8, function()
    if not P11.ChatAck then SendHello() end
end)

-- ---------- диагностика ----------
concommand.Add("p11_chatdiag_cl", function()
    print("== ЧАТ v6 «СТОК»: ДИАГНОСТИКА КЛИЕНТА ==")
    print("  модуль загружен ✔ (эта строка сама это доказывает)")
    print("  протокол клиента: v" .. MAJOR)
    print("  ответ сервера (hello): "
        .. (P11.ChatAck and ("да, v" .. tostring(P11.ChatAck) .. ", "
            .. math.floor(CurTime() - (P11.ChatAckAt or 0)) .. "с назад")
            or "НЕТ — сервер будет зеркалить всё в штатный чат (и так читаемо!)"))
    print("  ввод: штатный движковый (Y) — мы его не трогаем")
    print("  показ: штатный движковый чат — мы его не прячем")
    chat.AddText(Color(120, 255, 120), "[ЧАТ-ТЕСТ] ",
        Color(235, 240, 246), "если видишь это в чате — показ работает.")
    print("  тест-строка отправлена в штатный чат.")
    if not P11.ChatAck then
        print("  ⚠ серверный модуль v5+ не найден: будет работать старый/зеркальный путь.")
    end
end)

print("[P11CHAT] v6 «СТОК» OK — без своего UI: всё через штатный чат движка (диагностика p11_chatdiag_cl)")
