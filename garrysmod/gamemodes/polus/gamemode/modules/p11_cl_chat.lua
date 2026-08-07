-- ============================================================
--  ПОЛЮС-11 — ЧАТ (client) v7 «ФИЛЬТР» — ПРОЗРАЧНЫЙ, С НУЛЯ
--  Основа — проверенная «СТОК»-архитектура: НОЛЬ своего UI,
--  ввод и показ — ШТАТНЫЙ чат движка (мы ничего не прячем и
--  не перехватываем). Поверх — МИКРОСКОП:
--   • p11chat_trace 1 (по умолчанию ВКЛ на время ЗАТ): каждый
--     принятый чат-пакет пишется в КЛИЕНТСКУЮ консоль — видно,
--     доезжают ли сообщения до машины;
--   • p11_chatdiag_cl: протокол, hello-рукопожатие, СПИСКИ хуков
--     OnPlayerChat / PlayerBindPress / HUDShouldDraw — чужой чат-
--     аддон виден сразу; прямо проверяется «кто прячет CHudChat».
--  Пришли админу вывод p11_chatdiag_cl (+ серверного
--  p11_chatdiag) — по ним остаток чинится за один проход.
-- ============================================================

P11 = P11 or {}

local MAJOR = 6 -- протокол сервера v7

local cvTrace = CreateClientConVar("p11chat_trace", "1", true, false,
    "1 = писать каждый принятый чат-пакет в клиентскую консоль")

local function Trace(msg)
    if cvTrace:GetBool() then print("[P11CHAT-TRACE] " .. msg) end
end

-- ---------- приём пакетов каналов → ШТАТНЫЙ чат движка ----------
local CHNAMES = { [1] = "РЕЧЬ", [2] = "OOC", [3] = "LOOC", [4] = "ME", [5] = "IT", [6] = "РЕПОРТ" }

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

-- ---------- рукопожатие ----------
local function SendHello()
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
    net.SendToServer()
    net.Start("P11_ChatMode")
        net.WriteUInt(0, 2) -- богатая сеть нам, зеркало не надо
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

hook.Add("InitPostEntity", "P11.ChatHelloV7", function()
    timer.Simple(3, SendHello)
end)
timer.Simple(8, function()
    if not P11.ChatAck then SendHello() end
end)

-- ---------- диагностика ----------
local function HookNames(event)
    local out = {}
    for name in pairs(hook.GetTable()[event] or {}) do
        out[#out + 1] = tostring(name)
    end
    table.sort(out)
    return out
end

concommand.Add("p11_chatdiag_cl", function()
    print("== ЧАТ v7 «ФИЛЬТР»: ДИАГНОСТИКА КЛИЕНТА ==")
    print("  модуль загружен ✔ | протокол клиента: v" .. MAJOR)
    print("  сервер ответил на hello: "
        .. (P11.ChatAck and ("да, протокол v" .. tostring(P11.ChatAck) .. ", "
            .. math.floor(CurTime() - (P11.ChatAckAt or 0)) .. "с назад")
            or "НЕТ — читать всё равно можно (сервер зеркалит в штатный чат)"))
    print("  трейс пакетов: " .. tostring(cvTrace:GetBool()) .. " (p11chat_trace 0/1)")
    print("  ввод: штатный движковый (Y) — мы его не трогаем")

    -- КТО ПРЯЧЕТ штатный чат? прямой эксперимент
    local ok, res = pcall(function() return hook.Call("HUDShouldDraw", GAMEMODE, "CHudChat") end)
    if ok and res == false then
        print("  ⚠⚠ CHudChat КТО-ТО ПРЯЧЕТ! Кандидаты ниже (передай админу):")
        for _, n in ipairs(HookNames("HUDShouldDraw")) do
            print("       • " .. n)
        end
    else
        print("  CHudChat: рисуется ✔ (никто не прячет штатный чат)")
    end

    print("  хуки OnPlayerChat (" .. #HookNames("OnPlayerChat") .. "):")
    for _, n in ipairs(HookNames("OnPlayerChat")) do
        print("       • " .. n)
    end

    chat.AddText(Color(120, 255, 120), "[ЧАТ-ТЕСТ] ",
        Color(235, 240, 246), "если видишь эту строку в чате — показ работает.")
    print("  тест-строка отправлена в штатный чат.")
    print("  ПРИШЛИ ЭТОТ ВЫВОД (+ серверный p11_chatdiag) админу — остаток чинится за один проход.")
end)

print("[P11CHAT] v7 «ФИЛЬТР» OK — штатный чат + трейс в консоль (p11_chatdiag_cl, трейс: p11chat_trace 0/1)")
