-- ============================================================
--  ПОЛЮС-11 — СВОЙ ЧАТ-UI (client) v4.5.0
--  Полная замена ванильного чата:
--   • Y открывает строку с КНОПКОЙ КАНАЛА слева — кликом листаешь:
--     РЕЧЬ (рядом) / OOC (всем, нонрп) / LOOC (рядом, нонрп) /
--     /me (от 1 лица) / /it (мир от 3 лица) / РЕПОРТ (админам);
--   • u — сразу канал OOC;
--   • курсив команд вводить не нужно — коробка сама подставит
--     /ooc, /me и т.п. по выбранному каналу;
--   • обычные «пишущие» принты сервера (chat.AddText) тоже ловим
--     и рисуем в нашей ленте с цветами;
--   • ванильный CHudChat скрыт, OnPlayerChat подавлен.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.Chat.Text", { font = "Roboto", size = 17, weight = 600, extended = true })
surface.CreateFont("P11.Chat.Name", { font = "Roboto", size = 17, weight = 800, extended = true })
surface.CreateFont("P11.Chat.Btn",  { font = "Roboto", size = 14, weight = 800, extended = true })

local CHAT = P11.Chat or {}
P11.Chat = CHAT
CHAT.lines = CHAT.lines or {}

local MAXW   = 640
local LINE_H = 21
local MAXVIS = 12
local FADE_S = 10   -- секунд до растворения

-- каналы строки ввода (prefix подставляется серверной команде say)
local CHANNELS = {
    { id = 1, label = "РЕЧЬ",   prefix = "",        col = Color(228, 236, 245) },
    { id = 2, label = "OOC",    prefix = "/ooc ",   col = Color(170, 176, 188) },
    { id = 3, label = "LOOC",   prefix = "/looc ",  col = Color(145, 152, 165) },
    { id = 4, label = "ME",     prefix = "/me ",    col = Color(205, 165, 255) },
    { id = 5, label = "IT",     prefix = "/it ",    col = Color(255, 205, 110) },
    { id = 6, label = "РЕПОРТ", prefix = "/report ", col = Color(235, 100, 90) },
}

-- ============================================================
--  ЛЕНТА: part-структуры → переносы → хранение
-- ============================================================

-- parts = { {col=Color, txt="..."}, ... } → vlines (учёт переносов и \n)
local function WrapParts(parts)
    surface.SetFont("P11.Chat.Text")
    local vlines = {}
    local cur = {}
    local curW = 0

    local function Flush()
        vlines[#vlines + 1] = cur
        cur, curW = {}, 0
    end

    local function PushWord(col, word)
        local w = surface.GetTextSize(word)
        if curW + w > MAXW and curW > 0 then Flush() end
        cur[#cur + 1] = { col = col, txt = word }
        curW = curW + w
    end

    for _, part in ipairs(parts) do
        local col = part.col or color_white
        local txt = tostring(part.txt or "")
        -- разрезать по \n; между кусками — принудительный перенос строки
        local pieces = {}
        for piece in string.gmatch(txt .. "\n", "(.-)\n") do
            pieces[#pieces + 1] = piece
        end
        for pi, piece in ipairs(pieces) do
            -- слова + пробелы, чтобы не резать слово по буквам
            for word in string.gmatch(piece, "%S+%s*") do
                PushWord(col, word)
            end
            if pi < #pieces and #cur > 0 then Flush() end
        end
    end
    if #cur > 0 then Flush() end
    return vlines
end

function CHAT.AddParts(parts)
    local vlines = WrapParts(parts)
    if #vlines == 0 then return end
    CHAT.lines[#CHAT.lines + 1] = { t = CurTime(), vlines = vlines }
    -- не раздуваем историю
    while #CHAT.lines > 60 do table.remove(CHAT.lines, 1) end
end

-- цветастые куски одного визуального ряда слева направо
local function DrawParts(vline, x, y, alphaMul)
    local cx = x
    for _, part in ipairs(vline) do
        local c = part.col or color_white
        surface.SetAlphaMultiplier((alphaMul or 1))
        draw.SimpleText(part.txt, "P11.Chat.Text", cx, y,
            Color(c.r, c.g, c.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        surface.SetFont("P11.Chat.Text")
        cx = cx + surface.GetTextSize(part.txt)
    end
    surface.SetAlphaMultiplier(1)
end

local function ChatBaseY()
    -- v4.6.3: панель жизни выросла (полоска тепла) — лента чата сидит ВЫШЕ неё
    return ScrH() - 152 - (CHAT.boxOpen and 46 or 0)
end

hook.Add("HUDPaint", "P11.ChatPaint", function()
    if P11B and P11B.open then return end          -- TAB перекрыл экран
    local x0 = 20
    local y = ChatBaseY()
    local shown = 0

    -- снизу вверх от свежих к старым
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
            DrawParts(ln.vlines[j], x0, vh, math.min(1, a + 0.15))
            shown = shown + 1
        end
    end
end)

-- ============================================================
--  ВХОД: серверные пакеты каналов
-- ============================================================

net.Receive("P11_ChatMsg", function()
    local ch   = net.ReadUInt(4)
    local name = net.ReadString()
    local text = net.ReadString()
    local ncol = net.ReadColor()

    local function TrimNL(s) return string.Trim(s) end
    text = TrimNL(text)

    if ch == 1 then      -- ИГРОК: речь рядом
        CHAT.AddParts({
            { col = ncol, txt = name },
            { col = Color(120, 185, 255), txt = " говорит: " },
            { col = Color(235, 240, 246), txt = text },
        })
    elseif ch == 2 then  -- OOC всем
        CHAT.AddParts({
            { col = Color(150, 158, 172), txt = "[OOC] " },
            { col = ncol, txt = name },
            { col = Color(175, 180, 192), txt = ": " .. text },
        })
    elseif ch == 3 then  -- LOOC рядом
        CHAT.AddParts({
            { col = Color(128, 136, 150), txt = "[LOOC] " },
            { col = ncol, txt = name },
            { col = Color(150, 156, 168), txt = ": " .. text },
        })
    elseif ch == 4 then  -- ME действие
        CHAT.AddParts({
            { col = Color(205, 165, 255), txt = "• " .. name .. " " .. text },
        })
    elseif ch == 5 then  -- IT мир
        CHAT.AddParts({
            { col = Color(255, 205, 110), txt = "*** " .. text },
        })
    elseif ch == 6 then  -- РЕПОРТ админам
        CHAT.AddParts({
            { col = Color(235, 100, 90), txt = "[РЕПОРТ] " },
            { col = ncol, txt = name },
            { col = Color(240, 150, 140), txt = ": " .. text },
        })
    end
end)

-- ============================================================
--  ПЕРЕХВАТ chat.AddText (системные принты сервера/модулей)
-- ============================================================

local oldAddText = chat.AddText
function chat.AddText(...)
    local args = { ... }
    local parts = {}
    local cur = Color(235, 238, 244)
    for _, a in ipairs(args) do
        if IsColor(a) then
            cur = a
        elseif isstring(a) then
            local t = string.gsub(a, "\n$", "") -- PrintMessage докидывает перевод
            if t ~= "" then parts[#parts + 1] = { col = cur, txt = t } end
        elseif isnumber(a) then
            parts[#parts + 1] = { col = cur, txt = tostring(a) }
        elseif type(a) == "Player" and IsValid(a) then
            parts[#parts + 1] = { col = cur, txt = a:Nick() }
        end
    end
    if #parts > 0 then CHAT.AddParts(parts) end
    return oldAddText(...)
end

-- ванильную коробку прячем; движковую речь подавляем (мы рисуем сами)
local cvVanilla = CreateClientConVar("p11_vanilla_chat", "0", true, false,
    "1 = вернуть штатный чат движка (аварийный выход, если своей ленты не видно)")

hook.Add("HUDShouldDraw", "P11.ChatHide", function(name)
    if name == "CHudChat" and not cvVanilla:GetBool() then return false end
end)

-- v4.6.3: не глушим в пустоту, а ЛОВИМ в свою ленту — это и страховка:
-- даже если серверная обработка чата упадёт, движковые сообщения
-- всё равно будут видны игроку.
hook.Add("OnPlayerChat", "P11.ChatCapture", function(ply, text)
    -- аварийный режим: отдаём в ваниль без дублей в нашей ленте
    if cvVanilla:GetBool() then return end
    local nm = IsValid(ply) and ply:Nick() or "???"
    local col = IsValid(ply) and team.GetColor(ply:Team()) or Color(220, 220, 220)
    CHAT.AddParts({
        { col = col, txt = nm },
        { col = Color(235, 240, 246), txt = ": " .. tostring(text) },
    })
    return true
end)

-- ДИАГНОСТИКА (v4.6.5): p11_chatdiag_cl в клиентскую консоль
concommand.Add("p11_chatdiag_cl", function()
    print("[P11CHAT] линий в ленте: " .. #CHAT.lines .. ", ваниль-режим: " .. tostring(cvVanilla:GetBool()))
    CHAT.AddParts({
        { col = Color(120, 255, 120), txt = "[ЧАТ-ТЕСТ]" },
        { col = Color(235, 240, 246), txt = " если видишь эту строку слева внизу — лента рисует." },
    })
    print("[P11CHAT] добавлена тестовая строка. Не видно на экране? Напиши: p11_vanilla_chat 1")
end)

-- ============================================================
--  СТРОКА ВВОДА с КНОПКОЙ КАНАЛА (слева!)
-- ============================================================

function CHAT.Open(withChannel)
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
    CHAT.boxOpen = true

    local W, H = 660, 40
    local f = vgui.Create("DPanel")
    CHAT.Box = f
    f:SetSize(W, H)
    f:SetPos(20, ScrH() - 152) -- v4.6.3: над панелью жизни
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

    -- КНОПКА КАНАЛА (слева, как просили) — кликаешь, листаешь
    local chBtn = vgui.Create("DButton", f)
    chBtn:SetPos(4, 4) chBtn:SetSize(118, 32)
    chBtn:SetText("")
    chBtn.Paint = function(s, w, h)
        local ch = CHANNELS[f.Channel]
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 26) or Color(255, 255, 255, 12))
        draw.RoundedBoxEx(5, 0, 0, 4, h, ch.col, true, false, true, false)
        draw.SimpleText(ch.label .. " ▸", "P11.Chat.Btn", 12, h / 2, ch.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    chBtn.DoClick = function()
        f.Channel = (f.Channel % #CHANNELS) + 1
        CHAT.lastChannel = f.Channel
        surface.PlaySound("buttons/button9.wav")
        -- вернуть фокус набору
        if IsValid(f.Entry) then f.Entry:RequestFocus() end
    end

    local entry = vgui.Create("DTextEntry", f)
    f.Entry = entry
    entry:SetPos(128, 4) entry:SetSize(W - 136, 32)
    entry:SetFont("P11.Chat.Text")
    entry:SetTextColor(Color(235, 240, 246))
    entry:SetCursorColor(Color(235, 240, 246))
    entry:SetPlaceholderText("текст сообщения… (ENTER — отправить, ESC — закрыть, ▸ — канал)")
    entry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 6))
        s:DrawTextEntryText(Color(235, 240, 246), Color(120, 185, 255), Color(235, 240, 246))
    end

    local function Send()
        local txt = string.Trim(entry:GetValue() or "")
        if txt ~= "" then
            local ch = CHANNELS[f.Channel]
            RunConsoleCommand("say", ch.prefix .. txt)
        end
        CHAT.Close()
    end

    entry.OnEnter = Send
    entry.OnLoseFocus = function() end -- не захлопываем, кнопку жмут

    f.Think = function()
        -- ESC / Enter системно закроют
        if input.IsKeyDown(KEY_ESCAPE) then
            gui.HideGameUI()
            CHAT.Close()
        end
    end

    -- закрыть по клику Enter'а системная клавиша вызывает OnEnter сама
    entry:RequestFocus()
end

function CHAT.Close()
    CHAT.boxOpen = false
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
end

-- Y — строка (последний канал), U — сразу OOC, оба глушим от ванили
hook.Add("PlayerBindPress", "P11.ChatOpen", function(ply, bind, pressed)
    if not pressed then return end
    if string.find(bind, "messagemode2") then
        CHAT.Open(2)
        return true
    end
    if string.find(bind, "messagemode") and not string.find(bind, "messagemode2") then
        CHAT.Open(CHAT.lastChannel or 1)
        return true
    end
end)

print("[POLUS-11] свой чат-UI загружен (Y — строка, ▸ слева — канал)")
