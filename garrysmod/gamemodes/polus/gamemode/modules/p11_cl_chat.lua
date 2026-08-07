-- ============================================================
--  ПОЛЮС-11 — ЧАТ (client) v5 «РЕЛЕ» — пересоздан С НУЛЯ
--  ДВА РЕЖИМА + АВТО-ЛЕЧЕНИЕ:
--   • режим 0 (СВОЙ, по умолчанию): ввод нашей строки (Y), лента
--     слева, ваниль скрыта. Покрытие 99% машин.
--   • режим 1 (ДВИЖОК): штатный чат движка; сервер зеркалит туда
--     ВСЕ сообщения каналов — и писать, и читать можно всегда.
--   АВТО-ЛЕЧЕНИЕ: любая ошибка нашей рисовки/окна, или сервер
--   не ответил на рукопожатие за 12 сек — клиент САМ перескакивает
--   в режим 1 и красным пишет в консоль, что случилось. Чат
--   больше НЕ МОЖЕТ умереть молча: всегда останется движковый.
--  Переключение руками: p11_chat_mode 0 / p11_chat_mode 1.
--  Диагностика: p11_chatdiag_cl.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.Chat.Text2", { font = "Roboto", size = 18, weight = 600, extended = true })
surface.CreateFont("P11.Chat.Btn2",  { font = "Roboto", size = 15, weight = 800, extended = true })

local MAJOR = 5 -- версия протокола (должна совпасть с серверной)

local CHAT = P11.Chat or {}
P11.Chat = CHAT
CHAT.lines = CHAT.lines or {}

local MAXW   = 660
local LINE_H = 22
local MAXVIS = 12
local FADE_S = 10

-- ---------- РЕЖИМ И СИНХРОНИЗАЦИЯ ----------
local cvMode = CreateClientConVar("p11_chat_mode", "0", true, true,
    "0 = свой чат-лента, 1 = движковый (аварийный/надёжный)")

local function ModeNow()
    return (cvMode and cvMode:GetInt() == 0) and 0 or 1
end

local function SyncModeToServer()
    net.Start("P11_ChatMode")
        net.WriteUInt(ModeNow(), 2)
    net.SendToServer()
end

local function SetMode(m, why)
    RunConsoleCommand("p11_chat_mode", tostring(m == 0 and 0 or 1))
    CHAT.boxOpen = false
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
    if m ~= 0 then
        print("[P11CHAT] включён ДВИЖКОВЫЙ чат (режим 1). "
            .. (why and ("Причина: " .. why .. ". ") or "")
            .. "Писать: Y как обычно. Вернуть свой: p11_chat_mode 0")
    end
end

cvars.AddChangeCallback("p11_chat_mode", function(_, old, new)
    SyncModeToServer()
end, "P11.ChatModeSync")

-- ---------- переносы строк ----------
local function WrapParts(parts)
    surface.SetFont("P11.Chat.Text2")
    local vlines, cur, curW = {}, {}, 0
    local function Flush() vlines[#vlines + 1] = cur cur, curW = {}, 0 end
    local function PushWord(col, word)
        local w = surface.GetTextSize(word)
        if curW + w > MAXW and curW > 0 then Flush() end
        cur[#cur + 1] = { col = col, txt = word }
        curW = curW + w
    end
    for _, part in ipairs(parts) do
        local col = part.col or color_white
        local txt = tostring(part.txt or "")
        for piece in string.gmatch(txt .. "\n", "(.-)\n") do
            for word in string.gmatch(piece, "%S+%s*") do
                PushWord(col, word)
            end
            if #cur > 0 and piece ~= txt then Flush() end
        end
        if string.sub(txt, -1) == "\n" and #cur > 0 then Flush() end
    end
    if #cur > 0 then Flush() end
    return vlines
end

function CHAT.AddParts(parts)
    local ok, vlines = pcall(WrapParts, parts)
    if not ok or not vlines or #vlines == 0 then return end
    CHAT.lines[#CHAT.lines + 1] = { t = CurTime(), vlines = vlines }
    while #CHAT.lines > 60 do table.remove(CHAT.lines, 1) end
end

local function DrawLine(vline, x, y)
    local cx = x
    surface.SetFont("P11.Chat.Text2")
    for _, part in ipairs(vline) do
        local c = part.col or color_white
        draw.SimpleText(part.txt, "P11.Chat.Text2", cx, y,
            Color(c.r, c.g, c.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        cx = cx + (surface.GetTextSize(part.txt) or 0)
    end
end

-- ---------- лента (броня + авто-лечение в режим 1) ----------
hook.Add("HUDPaint", "P11.ChatPaintV5", function()
    local ok, err = pcall(function()
        if ModeNow() ~= 0 then return end
        if P11B and P11B.open then return end
        local x0, y = 20, ScrH() - 152 - (CHAT.boxOpen and 46 or 0)
        local shown = 0
        for i = #CHAT.lines, 1, -1 do
            local ln = CHAT.lines[i]
            local age = CurTime() - ln.t
            local a = CHAT.boxOpen and 1 or math.Clamp(1 - (age - FADE_S) * 0.5, 0, 1)
            if a <= 0 then break end
            for j = #ln.vlines, 1, -1 do
                if shown >= MAXVIS then return end
                local vh = y - shown * LINE_H - LINE_H
                surface.SetAlphaMultiplier(a * 0.85)
                draw.RoundedBox(4, x0 - 4, vh + 1, 8 + MAXW, LINE_H - 2, Color(10, 14, 20, 150))
                surface.SetAlphaMultiplier(a)
                DrawLine(ln.vlines[j], x0, vh)
                shown = shown + 1
            end
        end
    end)
    surface.SetAlphaMultiplier(1)
    if not ok then
        -- лента умерла на этой машине → живёт движковый чат
        SetMode(1, "ошибка прорисовки ленты: " .. tostring(err))
    end
end)

-- ---------- вход 1: богатые пакеты каналов ----------
net.Receive("P11_ChatMsg", function()
    local ch   = net.ReadUInt(4)
    local name = net.ReadString()
    local text = net.ReadString()
    local ncol = net.ReadColor()
    if ModeNow() ~= 0 then return end -- зеркало уже покажет движками

    if ch == 1 then
        CHAT.AddParts({ { col = ncol, txt = name }, { col = Color(120, 185, 255), txt = " говорит: " }, { col = Color(235, 240, 246), txt = text } })
    elseif ch == 2 then
        CHAT.AddParts({ { col = Color(150, 158, 172), txt = "[OOC] " }, { col = ncol, txt = name }, { col = Color(175, 180, 192), txt = ": " .. text } })
    elseif ch == 3 then
        CHAT.AddParts({ { col = Color(128, 136, 150), txt = "[LOOC] " }, { col = ncol, txt = name }, { col = Color(150, 156, 168), txt = ": " .. text } })
    elseif ch == 4 then
        CHAT.AddParts({ { col = Color(205, 165, 255), txt = "• " .. name .. " " .. text } })
    elseif ch == 5 then
        CHAT.AddParts({ { col = Color(255, 205, 110), txt = "*** " .. text } })
    elseif ch == 6 then
        CHAT.AddParts({ { col = Color(235, 100, 90), txt = "[РЕПОРТ] " }, { col = ncol, txt = name }, { col = Color(240, 150, 140), txt = ": " .. text } })
    end
end)

-- ---------- вход 2: системные chat.AddText ----------
local oldAddText = chat.AddText
function chat.AddText(...)
    local parts, cur = {}, Color(235, 238, 244)
    for _, a in ipairs({ ... }) do
        if IsColor(a) then cur = a
        elseif isstring(a) or isnumber(a) then
            local t = string.gsub(tostring(a), "\n$", "")
            if t ~= "" then parts[#parts + 1] = { col = cur, txt = t } end
        elseif type(a) == "Player" and IsValid(a) then
            parts[#parts + 1] = { col = cur, txt = a:Nick() }
        end
    end
    if #parts > 0 then CHAT.AddParts(parts) end
    return oldAddText(...)
end

-- ---------- движковые речи: в ленту (и глушим ваниль ТОЛЬКО в режиме 0) ----------
hook.Add("OnPlayerChat", "P11.ChatCaptureV5", function(ply, text)
    if ModeNow() ~= 0 then return end
    if IsValid(ply) then
        local col = team.GetColor(ply:Team())
        CHAT.AddParts({ { col = col, txt = ply:Nick() }, { col = Color(235, 240, 246), txt = ": " .. tostring(text) } })
    end
    return true
end)

hook.Add("HUDShouldDraw", "P11.ChatHideV5", function(name)
    if name == "CHudChat" and ModeNow() == 0 then return false end
end)

-- ---------- строка ввода с кнопкой канала ----------
local CHANNELS = {
    { label = "РЕЧЬ",   prefix = "",         col = Color(228, 236, 245) },
    { label = "OOC",    prefix = "/ooc ",    col = Color(170, 176, 188) },
    { label = "LOOC",   prefix = "/looc ",   col = Color(145, 152, 165) },
    { label = "ME",     prefix = "/me ",     col = Color(205, 165, 255) },
    { label = "IT",     prefix = "/it ",     col = Color(255, 205, 110) },
    { label = "РЕПОРТ", prefix = "/report ", col = Color(235, 100, 90)  },
}

function CHAT.Open(withChannel)
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
    CHAT.boxOpen = true

    local W, H = 680, 42
    local f = vgui.Create("DPanel")
    CHAT.Box = f
    f:SetSize(W, H)
    f:SetPos(20, ScrH() - 152)
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    f.Channel = withChannel or CHAT.lastChannel or 1
    CHAT.lastChannel = f.Channel

    f.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(10, 14, 20, 235))
        surface.SetDrawColor(CHANNELS[s.Channel].col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local chBtn = vgui.Create("DButton", f)
    chBtn:SetPos(4, 5) chBtn:SetSize(126, 32)
    chBtn:SetText("")
    chBtn.Paint = function(s, w, h)
        local c = CHANNELS[f.Channel]
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 26) or Color(255, 255, 255, 12))
        draw.RoundedBoxEx(5, 0, 0, 4, h, c.col, true, false, true, false)
        draw.SimpleText(c.label .. " ▸", "P11.Chat.Btn2", 12, h / 2, c.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    chBtn.DoClick = function()
        f.Channel = (f.Channel % #CHANNELS) + 1
        CHAT.lastChannel = f.Channel
        surface.PlaySound("buttons/button9.wav")
        if IsValid(f.Entry) then f.Entry:RequestFocus() end
    end

    local entry = vgui.Create("DTextEntry", f)
    f.Entry = entry
    entry:SetPos(136, 5) entry:SetSize(W - 144, 32)
    entry:SetFont("P11.Chat.Text2")
    entry:SetTextColor(Color(235, 240, 246))
    entry:SetCursorColor(Color(235, 240, 246))
    entry:SetPlaceholderText("текст сообщения… (ENTER — отправить, ESC — закрыть)")
    entry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 6))
        s:DrawTextEntryText(Color(235, 240, 246), Color(120, 185, 255), Color(235, 240, 246))
    end
    entry.OnEnter = function()
        local txt = string.Trim(entry:GetValue() or "")
        if txt ~= "" then
            RunConsoleCommand("say", CHANNELS[f.Channel].prefix .. txt)
        end
        CHAT.Close()
    end
    entry:RequestFocus()

    f.Think = function()
        if input.IsKeyDown(KEY_ESCAPE) then
            gui.HideGameUI()
            CHAT.Close()
        end
    end
end

function CHAT.Close()
    CHAT.boxOpen = false
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
end

-- ---------- бинды: свой ввод с авто-падением в движковый ----------
hook.Add("PlayerBindPress", "P11.ChatOpenV5", function(ply, bind, pressed)
    if not pressed then return end
    local isTeam = string.find(bind, "messagemode2") ~= nil
    local isSay  = string.find(bind, "messagemode") ~= nil and not isTeam
    if not isSay and not isTeam then return end
    if string.find(bind, "^-") then return end -- отпускание

    if ModeNow() ~= 0 then return end -- движковый режим: пусть открывает движок

    local opened = false
    local ok, err = pcall(function()
        CHAT.Open(isTeam and 2 or (CHAT.lastChannel or 1))
        opened = IsValid(CHAT.Box)
    end)
    if not ok or not opened then
        -- окно не создалось ЭЖЕЛУНЕМ → движковый чат спасает сеанс
        SetMode(1, "окно ввода не создалось" .. (ok and "" or (": " .. tostring(err))))
        return -- nil: движок откроет СВОЮ строку прямо сейчас
    end
    gui.HideGameUI() -- закрыть возможный gameui-диалог, чтобы фокус ушёл в окно
    return true
end)

-- ---------- рукопожатие с сервером ----------
local function SendHello()
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
    net.SendToServer()
    SyncModeToServer()
    CHAT.helloSent = (CHAT.helloSent or 0) + 1
    timer.Create("P11.ChatHelloWait", 12, 1, function()
        if not CHAT.acked and ModeNow() == 0 then
            -- сервер нас не слышит → серверный модуль чата НЕ загружен:
            -- наша лента была бы глухая → аварийно в движковый режим
            SetMode(1, "серверный модуль чата не ответил за 12 секунд")
            print("[P11CHAT] ВНИМАНИЕ: админу — серверу нужен p11_sv_chat.lua v5 (проверь строку [P11CHAT-SV] в консоли сервера).")
        end
    end)
end

net.Receive("P11_ChatHello", function()
    local srvMajor = net.ReadUInt(4)
    local ok = net.ReadBool()
    if ok then
        CHAT.acked = true
        CHAT.ackMajor = srvMajor
        CHAT.ackAt = CurTime()
        if srvMajor ~= MAJOR then
            print("[P11CHAT] протокол сервера v" .. srvMajor .. " ≠ клиент v" .. MAJOR
                .. " — обнови файлы, пока всё в порядке версии одной стороны.")
        end
    end
end)

hook.Add("InitPostEntity", "P11.ChatHelloV5", function()
    timer.Simple(3, SendHello)
end)
-- на случай, если модуль перегрузили в рантайме
timer.Simple(5, function()
    if not CHAT.acked then SendHello() end
end)

-- ---------- диагностика ----------
concommand.Add("p11_chatdiag_cl", function()
    print("== ЧАТ v5 «РЕЛЕ»: ДИАГНОСТИКА КЛИЕНТА ==")
    print("  модуль загружен ✔ | протокол v" .. MAJOR)
    print("  режим: " .. (ModeNow() == 0 and "0/СВОЙ (лента+своё окно)" or "1/ДВИЖОК (зеркала сервера)"))
    print("  сервер ответил на hello: " .. (CHAT.acked and ("да, протокол v" .. tostring(CHAT.ackMajor)
        .. ", " .. math.floor(CurTime() - (CHAT.ackAt or 0)) .. "с назад") or "НЕТ (пошло аварийное переключение)"))
    print("  hello отправлено: " .. tostring(CHAT.helloSent or 0)
        .. " | линий в ленте: " .. #CHAT.lines)
    if ModeNow() == 0 then
        CHAT.AddParts({
            { col = Color(120, 255, 120), txt = "[ЧАТ-ТЕСТ]" },
            { col = Color(235, 240, 246), txt = " видишь эту строку слева внизу — лента жива." },
        })
        print("  тест-строка отправлена в ленту (должна быть видна слева внизу).")
    else
        print("  в режиме 1 лента не рисуется — всё идёт штатным чатом движка.")
    end
end)

concommand.Add("p11_chatmode", function(ply, cmd, args)
    local m = tonumber(args[1] or "")
    if m == 0 or m == 1 then
        SetMode(m, "ручное переключение")
        print("[P11CHAT] режим: " .. m)
    else
        print("[P11CHAT] p11_chatmode <0|1> — 0 = свой чат, 1 = движковый. Сейчас: " .. ModeNow())
    end
end)

print("[P11CHAT] v5 «РЕЛЕ» OK — авто-лечение включено (диагностика: p11_chatdiag_cl, режим: p11_chatmode)")
