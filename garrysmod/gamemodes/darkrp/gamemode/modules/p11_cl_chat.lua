-- ============================================================
--  ПОЛЮС-11 — ЧАТ v9 «ЭФИР» (client) — v4.8.6 «НАВОДКА»
--  ПО УКАЗУ ВЛАДЕЛЬЦА: самодельный интерфейс «ПУЛЬТ» ВЫРЕЗАН
--  ПОЛНОСТЬЮ. Фронтенд чата — ГОТОВЫЙ проверенный **BonChat**
--  (MIT © Bonyoze, github.com/Bonyoze/legacy-bonchat; лицензия:
--  gamemode/bonchat/LICENSE), адаптированный под станцию
--  (bootstrap: p11_sh_bonchatboot.lua).
--
--  Этот файл оставляет только НАШУ часть:
--   • приём СТИЛЬНЫХ пакетов каналов (РЕЧЬ/OOC/LOOC/ME/IT/РЕПОРТ/
--     ШЁПОТ/КРИК) от серверного роутера p11_sv_chat → chat.AddText.
--     BonChat сам перехватил chat.AddText и рисует всё красиво;
--   • рукопожатие режима 0 (богатые сетевые пакеты вместо зеркала);
--   • трейс пакетов в консоль (p11chat_trace) и диагностика.
--
--  НИКАКИХ своих окон/биндов/скрытия CHudChat здесь больше нет —
--  всё это делает BonChat. Аварийный выход: bonchat_enable 0.
-- ============================================================

P11 = P11 or {}

local MAJOR = 6 -- протокол сервера v7.x (режим 0 = богатые сетевые пакеты)

local cvTrace = CreateClientConVar("p11chat_trace", "1", true, false,
    "1 = писать каждый принятый чат-пакет в клиентскую консоль")

local function Trace(msg)
    if cvTrace:GetBool() then print("[P11CHAT-TRACE] " .. msg) end
end

-- ---------- приём пакетов каналов → chat.AddText (рисует BonChat) ----------
local CHNAMES = { [1] = "РЕЧЬ", [2] = "OOC", [3] = "LOOC", [4] = "ME", [5] = "IT", [6] = "РЕПОРТ", [7] = "ШЁПОТ", [8] = "КРИК" }

local function AddStyled(chan, name, text, ncol)
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
    elseif chan == 7 then
        chat.AddText(Color(135, 150, 190), "[шёпот] ", ncol, name,
            Color(175, 185, 210), ": " .. text)
    elseif chan == 8 then
        chat.AddText(Color(255, 140, 105), "[КРИК] ", ncol, name,
            Color(255, 200, 180), ": " .. text)
    end
end

net.Receive("P11_ChatMsg", function()
    local ok, err = pcall(function()
        local ch   = net.ReadUInt(4)
        local name = net.ReadString()
        local text = net.ReadString()
        local ncol = net.ReadColor()
        Trace("пакет: канал=" .. (CHNAMES[ch] or ch) .. " | от: " .. name
            .. " | «" .. string.sub(text, 1, 60) .. "»")
        AddStyled(ch, name, text, ncol)
    end)
    if not ok then
        ErrorNoHalt("[P11CHAT] пакет не разобрать: " .. tostring(err) .. "\n")
    end
end)

-- ---------- рукопожатие с роутером сервера ----------
local function SendHello()
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
    net.SendToServer()
    net.Start("P11_ChatMode")
        net.WriteUInt(0, 2) -- богатые сетевые пакеты, зеркало не надо
    net.SendToServer()
    Trace("hello отправлено (протокол v" .. MAJOR .. ")")
end

net.Receive("P11_ChatHello", function()
    local srvMajor = net.ReadUInt(4)
    local ok = net.ReadBool()
    P11.ChatAck = ok and srvMajor or false
    P11.ChatAckAt = CurTime()
    Trace("hello-ответ от сервера: протокол v" .. tostring(srvMajor))
end)

hook.Add("InitPostEntity", "P11.ChatHelloV9", function()
    timer.Simple(3, SendHello)
end)
timer.Simple(8, function()
    if not P11.ChatAck then SendHello() end
end)

-- ---------- диагностика ----------
concommand.Add("p11_chatdiag_cl", function()
    print("== ЧАТ v9 «ЭФИР»: ДИАГНОСТИКА КЛИЕНТА ==")
    print("  фронтенд: BonChat (MIT © Bonyoze) — " .. (BonChat and "ЗАГРУЖЕН ✔" or "НЕТ! bootstrap не доехал"))
    print("  панель фрейма: " .. (BonChat and IsValid(BonChat.frame) and "жива ✔" or "нет"))
    print("  включён: " .. tostring(BonChat and BonChat.enabled)
        .. " (аварийно движковый чат: bonchat_enable 0, обратно: bonchat_enable 1)")
    print("  сервер-рукопожатие: " .. (P11.ChatAck and ("да, протокол v" .. tostring(P11.ChatAck)
        .. ", " .. math.floor(CurTime() - (P11.ChatAckAt or 0)) .. "с назад") or "НЕТ — каналы доедут зеркалом"))
    print("  трейс пакетов: " .. tostring(cvTrace:GetBool()) .. " (p11chat_trace 0/1)")
    print("  ремонт панели: bonchat_reload · чистка: bonchat_clear")
    chat.AddText(Color(120, 255, 120), "[ЧАТ-ТЕСТ] ",
        Color(235, 240, 246), "если видишь эту строку в эфире — показ работает.")
    print("  тест-строка отправлена. ПРИШЛИ ВЫВОД админу (+ серверный p11_chatdiag).")
end)

print("[P11CHAT] v9 «ЭФИР» OK — фронт: BonChat (MIT); каналы станции идут штатно; аварийно: bonchat_enable 0")
