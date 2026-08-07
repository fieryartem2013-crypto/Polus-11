-- ============================================================
--  ПОЛЮС-11 — ЧАТ (client) v8 «ПУЛЬТ» — v4.8.4 «ВЫСАДКА»
--  СВОЯ панель вместо движковой. По заявкам владельца:
--   • «СДЕЛАЙ ВЫШЕ» — лента поднята: низ окна ~2/3 экрана,
--     а не прибит к самому низу как у движкового чата;
--   • «УДОБНЕЕ» — шапка-чип показывает, КУДА улетит сообщение
--     (РЕЧЬ/OOC/ШЁПОТ/КРИК/РАЦИЯ/АДМИН/КОМАНДА), подсказка
--     префиксов, история своих реплик стрелками ↑/↓, скролл,
--     метки времени [ЧЧ:ММ], авто-затухание в тишине;
--   • «ВСЕ СООБЩЕНИЯ ОТОБРАЖАЛИСЬ» — лента собирает ВООБЩЕ ВСЁ:
--     наши сетевые пакеты каналов, PrintMessage/ChatPrint,
--     чужие chat.AddText (обёртка), движковые строки
--     (OnPlayerChat/ChatText — если серверный роутер выключен
--     p11_chat_passthrough 1, сообщения всё равно видны);
--   • «НАЖИМАЮ — ОТКРЫВАЕТСЯ, НО ПИСАТЬ НЕ МОГУ» — починено:
--     у движкового чата фокус ввода крал зависший попап-слой.
--     Здесь фокус — наш: ТРОЙНОЙ захват при открытии
--     (сразу + на следующем кадре + через 0.05с), клик по
--     ленте возвращает фокус в строку, а p11_chat_repair
--     показывает и сбрасывает вора принудительно.
--     Плюс критично: SetAllowNonAsciiCharacters(true) —
--     без него DTextEntry молча глотает КИРИЛЛИЦУ.
--  Аварийный выход: p11chat_stock 1 = чистый движковый чат
--  (наша панель гасится, ничего не перехватывается).
-- ============================================================

P11 = P11 or {}

local MAJOR = 6 -- протокол сервера v7.x (режим 0 = богатые сетевые пакеты)

local cvTrace = CreateClientConVar("p11chat_trace", "1", true, false,
    "1 = писать каждый принятый чат-пакет в клиентскую консоль")
local cvStock = CreateClientConVar("p11chat_stock", "0", true, false,
    "1 = аварийно вернуть чистый движковый чат (панель «ПУЛЬТ» выключается)")
local cvTime  = CreateClientConVar("p11chat_time", "1", true, false,
    "1 = метки времени [ЧЧ:ММ] у строк чата (действует на новые строки)")
local cvFade  = CreateClientConVar("p11chat_fade", "14", true, false,
    "через сколько секунд тишины лента гаснет (0 = светить всегда)")

surface.CreateFont("P11.Chat",     { font = "Tahoma", size = 17, weight = 600, antialias = true })
surface.CreateFont("P11.ChatChip", { font = "Tahoma", size = 14, weight = 800, antialias = true })
surface.CreateFont("P11.ChatHint", { font = "Tahoma", size = 13, weight = 500, antialias = true })

local function Trace(msg)
    if cvTrace:GetBool() then print("[P11CHAT-TRACE] " .. msg) end
end

-- ============================================================
--  ПАНЕЛЬ «ПУЛЬТ»
-- ============================================================

local PANEL = {}

local CHIPS = {
    { p = { "//" },                             t = "OOC — вне роли, ВСЕМ",      c = Color(150, 158, 172) },
    { p = { "/ooc ", "/оос " },                 t = "OOC — вне роли, ВСЕМ",      c = Color(150, 158, 172) },
    { p = { "/looc ", "/лоок " },               t = "LOOC — вне роли рядом",     c = Color(128, 136, 150) },
    { p = { "/шепот ", "/ш ", "/w ", "/whisper " }, t = "ШЁПОТ — почти на ухо",  c = Color(135, 150, 190) },
    { p = { "/крик ", "/кр ", "/y ", "/yell " },    t = "КРИК — слышно далеко",  c = Color(255, 140, 105) },
    { p = { "/me ", "/мя " },                   t = "ДЕЙСТВИЕ от лица персонажа", c = Color(205, 165, 255) },
    { p = { "/it ", "/ит " },                   t = "ОПИСАНИЕ события рядом",    c = Color(255, 205, 110) },
    { p = { "/r ", "/р " },                     t = "РАЦИЯ — в эфир канала",     c = Color(120, 255, 170) },
    { p = { "/канал" },                         t = "РАЦИЯ — переключение канала", c = Color(120, 255, 170) },
    { p = { "/report", "/репорт" },             t = "РЕПОРТ — жалоба администрации", c = Color(235, 100, 90) },
    { p = { "/приказ", "/розыск", "/wanted" },  t = "КОМАНДИРСКАЯ — приказ/розыск", c = Color(255, 120, 110) },
    { p = { "/досье", "/dossier" },             t = "НКВД — досье (видишь только ты)", c = Color(180, 150, 255) },
}

function PANEL:Init()
    self:SetPaintBackground(true)
    self:SetVisible(false)
    self.Open = false
    self.Alpha = 0
    self.History = {}   -- лента: { t="ЧЧ:ММ", segs={ {c=Color},{t=".."}, ... } }
    self.Sent = {}      -- история СВОИХ реплик (стрелки ↑/↓)
    self.SentIdx = 1
    self.LastMsgAt = 0
    self.NextSendAt = 0
    self.ChipText, self.ChipColor = nil, nil

    -- лента
    self.Holder = vgui.Create("DPanel", self)
    self.Holder:SetPaintBackground(false)

    self.Msgs = vgui.Create("RichText", self.Holder)
    self.Msgs:SetMouseInputEnabled(true) -- скролл колёсиком и ползунком
    pcall(function() self.Msgs:SetBGColor(Color(9, 12, 18, 0)) end)
    pcall(function()
        self.Msgs:SetFontInternal("P11.Chat")
        self.Msgs:SetUnderlineFont("P11.Chat")
    end)
    self.Msgs:SetVerticalScrollbarEnabled(true)

    -- строка ввода
    self.Entry = vgui.Create("DTextEntry", self)
    self.Entry:SetFont("P11.Chat")
    self.Entry:SetTextColor(Color(240, 244, 250))
    self.Entry:SetCursorColor(Color(120, 200, 255))
    self.Entry:SetAllowNonAsciiCharacters(true) -- КИРИЛЛИЦА! без флага панель глотает русский ввод
    self.Entry:SetUpdateOnType(true)
    self.Entry:SetMultiline(false)
    pcall(function()
        self.Entry:SetPlaceholderText("Сообщение…   // OOC · /w шёпот · /y крик · /me действие · /r рация · ! админ")
        self.Entry:SetPlaceholderColor(Color(120, 128, 142, 170))
    end)

    local box = self
    self.Entry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(14, 18, 26, 235))
        local bc = box.ChipColor or Color(70, 84, 104)
        draw.RoundedBox(4, 0, 0, 3, h, Color(bc.r, bc.g, bc.b, 230))
        s:DrawTextEntryText(s:GetTextColor(), Color(80, 170, 255), s:GetCursorColor())
    end
    self.Entry.OnEnter = function() box:Send() end
    self.Entry.OnChange = function() box:UpdateChip() end
    self.Entry.OnKeyCodeTyped = function(s, code)
        if code == KEY_ESCAPE then box:CloseChat() return true end
        if code == KEY_UP then box:HistoryMove(-1) return true end
        if code == KEY_DOWN then box:HistoryMove(1) return true end
    end
    -- клик по ленте — фокус обратно в строку (лечим «открыл, тыкнул — не пишется»)
    self.Msgs.OnMousePressed = function()
        if box.Open then box:FocusEntry() end
    end
    self.OnMousePressed = function()
        if box.Open then box:FocusEntry() end
    end

    -- подсказка под строкой ввода
    self.Hint = vgui.Create("DLabel", self)
    self.Hint:SetFont("P11.ChatHint")
    self.Hint:SetTextColor(Color(150, 158, 172))
    self.Hint:SetText("Enter — отправить · Esc — закрыть · ↑/↓ — твои реплики · // OOC · /w шёпот · /y крик · /r рация · /report жалоба")
    self.Hint:SizeToContents()

    self:FitToScreen()
end

function PANEL:FitToScreen()
    local scrw, scrh = ScrW(), ScrH()
    local w  = math.Clamp(math.floor(scrw * 0.34), 420, 680)
    local mh = math.Clamp(math.floor(scrh * 0.26), 210, 330) -- высота ленты
    local chipH, gap, eh, hh = 20, 6, 30, 16
    local total = chipH + mh + gap + eh + 4 + hh
    -- «ВЫШЕ»: нижний край окна на ~2/3 высоты экрана (движковый — ~95%)
    local bottom = math.floor(scrh * 0.66)
    self:SetPos(10, bottom - total)
    self:SetSize(w, total)
    self.ChipH, self.MsgsH = chipH, mh
    self.Holder:SetPos(0, chipH)
    self.Holder:SetSize(w, mh)
    self.Msgs:Dock(FILL)
    self.Msgs:DockMargin(8, 5, 8, 4)
    self.Entry:SetPos(0, chipH + mh + gap)
    self.Entry:SetSize(w, eh)
    self.Hint:SetPos(3, chipH + mh + gap + eh + 5)

    -- перестройка ленты под новую ширину
    local keep = self.History
    self.Msgs:SetText("")
    for _, line in ipairs(keep) do self:WriteLine(line) end
    self.Msgs:GotoTextEnd()
end

-- ---------- отрисовка ----------

function PANEL:Paint(w, h)
    if self.Alpha <= 1 then return end
    surface.SetAlphaMultiplier(self.Alpha / 255)

    local chipH = self.ChipH
    -- шапка: чип канала (открыт) / тихий заголовок (закрыт)
    draw.RoundedBoxEx(6, 0, 0, w, chipH, Color(12, 16, 24, 210), true, true, false, false)
    if self.Open then
        local cc = self.ChipColor or Color(86, 182, 255)
        draw.RoundedBox(3, 4, 3, 4, chipH - 6, Color(cc.r, cc.g, cc.b, 255))
        if self.ChipText then
            draw.SimpleText(self.ChipText, "P11.ChatChip", 14, chipH * 0.5,
                Color(225, 232, 242), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        draw.SimpleText("НЕЧТО слушает эфир…", "P11.ChatHint", w - 8, chipH * 0.5,
            Color(96, 108, 126), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("ЧАТ СТАНЦИИ «ПОЛЮС-11»", "P11.ChatChip", 8, chipH * 0.5,
            Color(120, 130, 148), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Y — написать", "P11.ChatHint", w - 8, chipH * 0.5,
            Color(96, 108, 126), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- фон ленты
    draw.RoundedBoxEx(6, 0, chipH, w, self.MsgsH,
        Color(9, 12, 18, self.Open and 205 or 132), false, false, true, true)

    surface.SetAlphaMultiplier(1)
end

-- ---------- лента: запись/пересборка/угасание ----------

function PANEL:WriteLine(line)
    local m = self.Msgs
    if cvTime:GetBool() then
        m:InsertColorChange(90, 98, 112, 255)
        m:AppendText("[" .. line.t .. "] ")
    end
    for _, s in ipairs(line.segs) do
        if s.c then m:InsertColorChange(s.c.r, s.c.g, s.c.b, s.c.a or 255) end
        if s.t then m:AppendText(s.t) end
    end
    m:AppendText("\n")
end

function PANEL:AppendLine(segs)
    local line = { t = os.date("%H:%M"), segs = segs }
    self.History[#self.History + 1] = line
    self:WriteLine(line)
    self.Msgs:GotoTextEnd()
    self.LastMsgAt = CurTime()
    if #self.History > 260 then
        while #self.History > 200 do table.remove(self.History, 1) end
        self.Msgs:SetText("")
        for _, l in ipairs(self.History) do self:WriteLine(l) end
        self.Msgs:GotoTextEnd()
    end
end

function PANEL:ApplyAlpha()
    local a = math.Clamp(math.floor(self.Alpha + 0.5), 0, 255)
    self:SetAlpha(a)
    self.Holder:SetAlpha(a)
    self.Msgs:SetAlpha(a)
    self.Entry:SetAlpha(a)
    self.Hint:SetAlpha(a)
end

function PANEL:Think()
    if cvStock:GetBool() then
        if self:IsVisible() then self:SetVisible(false) end
        if self.Open then self:CloseChat() end
        return
    end
    local target
    if self.Open then
        target = 255
    else
        local fadeS = cvFade:GetFloat()
        if fadeS <= 0 then
            target = 255
        else
            local age = CurTime() - self.LastMsgAt
            if age >= fadeS + 0.8 then
                target = 0
            elseif age >= fadeS then
                target = 255 * (1 - (age - fadeS) / 0.8)
            else
                target = 255
            end
        end
    end
    self.Alpha = target
    self:ApplyAlpha()
    self:SetVisible(self.Open or target > 2)
end

-- ---------- чип канала строки ввода ----------

function PANEL:UpdateChip()
    local txt = self.Entry:GetText() or ""
    local low = string.lower(txt)
    local chip, col
    if string.StartWith(low, "!") then
        chip, col = "АДМИН-КОМАНДА / !-чат", Color(255, 110, 90)
    elseif string.StartWith(low, "/") then
        for _, c in ipairs(CHIPS) do
            for _, pfx in ipairs(c.p) do
                if string.StartWith(low, pfx) then chip, col = c.t, c.c break end
            end
            if chip then break end
        end
        if not chip then chip, col = "КОМАНДА СЕРВЕРА", Color(160, 168, 182) end
    else
        chip, col = "РЕЧЬ — слышат рядом (~700u)", Color(120, 185, 255)
    end
    self.ChipText, self.ChipColor = chip, col
end

-- ---------- ввод: отправка, история реплик ----------

function PANEL:Send()
    local text = string.Trim(self.Entry:GetText() or "")
    self:CloseChat()
    if text == "" then return end

    local n = #self.Sent
    if n == 0 or self.Sent[n] ~= text then
        self.Sent[n + 1] = text
        if #self.Sent > 40 then table.remove(self.Sent, 1) end
    end
    self.SentIdx = #self.Sent + 1

    if CurTime() < self.NextSendAt then return end -- мягкий антиспам
    self.NextSendAt = CurTime() + 0.35
    RunConsoleCommand("say", text)
end

function PANEL:HistoryMove(dir)
    if #self.Sent == 0 then return end
    self.SentIdx = math.Clamp(self.SentIdx + dir, 1, #self.Sent + 1)
    local txt = self.Sent[self.SentIdx] or ""
    self.Entry:SetText(txt)
    self.Entry:SetCaretPos(#txt)
    self:UpdateChip()
end

-- ---------- открытие/закрытие: ЖЕЛЕЗНЫЙ фокус ----------

function PANEL:FocusEntry()
    local e = self.Entry
    if not IsValid(e) then return end
    e:RequestFocus()
    -- двойная страховка: на следующем кадре и через 0.05с —
    -- зависший попап отпускает клавиатуру, фокус остаётся наш
    timer.Simple(0, function() if IsValid(e) then e:RequestFocus() end end)
    timer.Simple(0.05, function() if IsValid(e) then e:RequestFocus() end end)
end

function PANEL:OpenChat(prefill)
    self.Open = true
    self.Alpha = 255
    self:ApplyAlpha()
    self:SetVisible(true)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self.Entry:SetEnabled(true)
    if prefill then
        self.Entry:SetText(prefill)
        self.Entry:SetCaretPos(#prefill)
    end
    self:UpdateChip()
    self:FocusEntry()
end

function PANEL:CloseChat()
    self.Open = false
    self.Entry:SetText("")
    self.ChipText, self.ChipColor = nil, nil
    self.Entry:KillFocus()
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
    gui.EnableScreenClicker(false)
    self.LastMsgAt = CurTime() -- лента спокойно догорит по таймеру тишины
end

vgui.Register("P11ChatBox", PANEL, "DPanel")

local frame
local function Box()
    if not IsValid(frame) then
        frame = vgui.Create("P11ChatBox")
    end
    return frame
end

-- глобальный приёмник строки (сегменты {c=Color} / {t="текст"})
function P11.ChatFeed(segs)
    if not istable(segs) then return end
    local f = Box()
    if not IsValid(f) then return end
    f:AppendLine(segs)
end

-- ============================================================
--  ПЕРЕХВАТ chat.AddText → лента (ловит ВСЁ: PrintMessage,
--  чужие аддоны, наши каналы). Защита от зацикливания при
--  lua-рефреше: оригинал храним один раз в P11.ChatRawAddText.
-- ============================================================

local function SegsFromArgs(args)
    local segs = {}
    for _, v in ipairs(args) do
        if IsColor(v) then
            segs[#segs + 1] = { c = v }
        elseif isstring(v) then
            segs[#segs + 1] = { t = v }
        elseif type(v) == "Player" and IsValid(v) then
            local nc = Color(220, 225, 232)
            local ok, tc = pcall(team.GetColor, v:Team())
            if ok and tc then nc = tc end
            segs[#segs + 1] = { c = nc }
            segs[#segs + 1] = { t = v:Nick() }
        elseif v ~= nil then
            segs[#segs + 1] = { t = tostring(v) }
        end
    end
    return segs
end

P11.ChatRawAddText = P11.ChatRawAddText or chat.AddText
local RAW_ADD_TEXT = P11.ChatRawAddText

function chat.AddText(...)
    local args = { ... }
    RAW_ADD_TEXT(...)
    local ok, segs = pcall(SegsFromArgs, args)
    if ok and #segs > 0 then P11.ChatFeed(segs) end
end

-- ============================================================
--  ДВИЖКОВЫЕ ДОРОГИ: если роутер выключен (passthrough) —
--  сообщения приходят сюда; покажем их в ленте. НИЧЕГО не
--  возвращаем: движок рисует свою копию в СКРЫТЫЙ CHudChat,
--  а listener-хуки (!меню и др.) не голодают.
-- ============================================================

hook.Add("OnPlayerChat", "P11.ChatEngineCatch", function(ply, text, teamOnly, dead)
    if cvStock:GetBool() then return end
    local segs = {}
    local nc = Color(240, 240, 240)
    if IsValid(ply) then
        local ok, tc = pcall(team.GetColor, ply:Team())
        if ok and tc then nc = tc end
    end
    if dead then
        segs[#segs + 1] = { t = "*МЁРТВ* ", c = Color(168, 72, 72) }
    end
    if teamOnly then
        segs[#segs + 1] = { t = "(СВОИМ) ", c = Color(110, 150, 110) }
    end
    segs[#segs + 1] = { c = nc }
    segs[#segs + 1] = { t = IsValid(ply) and ply:Nick() or "???" }
    segs[#segs + 1] = { t = ": " .. tostring(text), c = Color(235, 238, 242) }
    P11.ChatFeed(segs)
end)

-- системные строки движка (зашёл/вышел/сменил имя)
local SYSMAP = {
    ["#game_player_joined"]       = "зашёл на станцию",
    ["#game_player_left_game"]    = "покинул станцию",
    ["#game_player_changed_name"] = "сменил позывной",
}
hook.Add("ChatText", "P11.ChatSysCatch", function(idx, name, text, ctype)
    if cvStock:GetBool() then return end
    local human = SYSMAP[text]
    if human then
        P11.ChatFeed({ { c = Color(130, 140, 158) }, { t = "• " .. tostring(name) .. " " .. human } })
    elseif ctype ~= "none" and isstring(text) and text ~= "" and not string.StartWith(text, "#") then
        P11.ChatFeed({ { c = Color(130, 140, 158) }, { t = "• " .. tostring(text) } })
    end
end)

-- ============================================================
--  БИНДЫ: Y/T открывают НАШУ панель; движковый чат спит.
-- ============================================================

hook.Add("PlayerBindPress", "P11.ChatBindV8", function(ply, bind, pressed)
    if not pressed then return end
    if cvStock:GetBool() then return end
    if ply ~= LocalPlayer() then return end
    local b = string.lower(tostring(bind or ""))
    if string.find(b, "messagemode2") then
        Box():OpenChat("// ") -- командный чат = быстрый OOC
        return true
    elseif string.find(b, "messagemode") then
        Box():OpenChat()
        return true
    end
end)

hook.Add("StartChat", "P11.ChatBlockStartV8", function()
    if not cvStock:GetBool() then return true end
end)
hook.Add("FinishChat", "P11.ChatBlockFinishV8", function()
    if not cvStock:GetBool() then return true end
end)

hook.Add("HUDShouldDraw", "P11.ChatHideEngine", function(name)
    if name == "CHudChat" and not cvStock:GetBool() then return false end
end)

-- пересадка панели при смене разрешения экрана
hook.Add("OnScreenSizeChanged", "P11.ChatResizeV8", function()
    if IsValid(frame) then frame:FitToScreen() end
end)

-- программное открытие (для bind-кейсов: bind y p11chat)
concommand.Add("p11chat", function() Box():OpenChat() end)
concommand.Add("p11chat_ooc", function() Box():OpenChat("// ") end)

-- ============================================================
--  ПРИЁМ ПАКЕТОВ КАНАЛОВ (как и раньше — стили каналов)
-- ============================================================

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

-- ============================================================
--  РУКОПОЖАТИЕ С СЕРВЕРОМ (режим 0 = богатые сетевые пакеты)
-- ============================================================

local function SendHello()
    net.Start("P11_ChatHello")
        net.WriteUInt(MAJOR, 4)
    net.SendToServer()
    net.Start("P11_ChatMode")
        net.WriteUInt(0, 2)
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

hook.Add("InitPostEntity", "P11.ChatHelloV8", function()
    timer.Simple(3, SendHello)
end)
timer.Simple(8, function()
    if not P11.ChatAck then SendHello() end
end)

-- ============================================================
--  РЕМОНТ ФОКУСА + ДИАГНОСТИКА
-- ============================================================

local function ThiefLines(maxDepth)
    local out = {}
    local me = IsValid(frame) and frame or nil
    local mine = {}
    if me then
        mine[me] = true
        if IsValid(me.Holder) then mine[me.Holder] = true end
        if IsValid(me.Msgs) then mine[me.Msgs] = true end
        if IsValid(me.Entry) then mine[me.Entry] = true end
        if IsValid(me.Hint) then mine[me.Hint] = true end
    end
    local function scan(p, depth)
        if not IsValid(p) or depth > maxDepth then return end
        local kids = p:GetChildren()
        if not istable(kids) then return end
        for _, c in ipairs(kids) do
            if not mine[c] then
                local kb = c.HasKeyboardInputEnabled and c:HasKeyboardInputEnabled()
                if kb then
                    out[#out + 1] = "  держит клавиатуру: "
                        .. tostring(c.GetName and (c:GetName() .. "") or "?")
                        .. " | vgui-класс: " .. tostring(c.ClassName or "?")
                        .. " | видна: " .. tostring(c:IsVisible())
                end
            end
            scan(c, depth + 1)
        end
    end
    local wp = vgui.GetWorldPanel()
    if IsValid(wp) then pcall(scan, wp, 1) end
    return out
end

concommand.Add("p11_chat_repair", function()
    print("== P11CHAT v8 «ПУЛЬТ»: РЕМОНТ ВВОДА ==")
    if IsValid(frame) then
        frame:CloseChat()
        frame.LastMsgAt = CurTime()
    end
    gui.EnableScreenClicker(false)

    local focus = vgui.GetKeyboardFocus()
    print("  клавиатуру держит сейчас: "
        .. (IsValid(focus) and (tostring(focus:GetName()) .. " / " .. tostring(focus.ClassName or "?"))
            or "НИКТО (это правильно вне чата)"))
    local th = ThiefLines(5)
    if #th > 0 then
        print("  панели с включённой клавиатурой (кандидаты в воры фокуса):")
        for _, l in ipairs(th) do print(l) end
    else
        print("  воров фокуса не видно ✔")
    end
    print("  если писать всё равно не даёт: p11chat_stock 1 — аварийный движковый чат,")
    print("  потом пришли в консоль серверу админу вывод p11_chatdiag_cl.")
end)

local function HookNames(event)
    local out = {}
    for name in pairs(hook.GetTable()[event] or {}) do
        out[#out + 1] = tostring(name)
    end
    table.sort(out)
    return out
end

concommand.Add("p11_chatdiag_cl", function()
    print("== ЧАТ v8 «ПУЛЬТ»: ДИАГНОСТИКА КЛИЕНТА ==")
    print("  панель: " .. (IsValid(frame) and ("жива | открыта: " .. tostring(frame.Open)
        .. " | строк в ленте: " .. #frame.History) or "НЕ СОЗДАНА (баг!)"))
    print("  режим: " .. (cvStock:GetBool() and "АВАРИЙНЫЙ (движковый чат)" or "«ПУЛЬТ» (своя панель)"))
    print("  таймстампы: " .. tostring(cvTime:GetBool())
        .. " | затухание: " .. cvFade:GetString() .. "с | трейс: " .. tostring(cvTrace:GetBool()))
    print("  сервер ответил на hello: "
        .. (P11.ChatAck and ("да, протокол v" .. tostring(P11.ChatAck) .. ", "
            .. math.floor(CurTime() - (P11.ChatAckAt or 0)) .. "с назад")
            or "НЕТ — читать всё равно можно (зеркало сервера → chat.AddText → лента)"))
    local focus = vgui.GetKeyboardFocus()
    print("  фокус клавиатуры: "
        .. (IsValid(focus) and (tostring(focus:GetName()) .. " / " .. tostring(focus.ClassName or "?")) or "НИКТО"))

    local th = ThiefLines(5)
    if #th > 0 then
        print("  ⚠ панели, держащие клавиатуру (воры ввода):")
        for _, l in ipairs(th) do print(l) end
    else
        print("  внешних держателей клавиатуры нет ✔")
    end

    print("  хуки PlayerBindPress (" .. #HookNames("PlayerBindPress") .. "):")
    for _, n in ipairs(HookNames("PlayerBindPress")) do print("     • " .. n) end
    print("  хуки OnPlayerChat (" .. #HookNames("OnPlayerChat") .. "):")
    for _, n in ipairs(HookNames("OnPlayerChat")) do print("     • " .. n) end

    P11.ChatFeed({ { c = Color(120, 255, 120) }, { t = "[ЧАТ-ТЕСТ] " },
        { t = "если видишь эту строку в ленте — показ работает.", c = Color(235, 240, 246) } })
    print("  тест-строка отправлена в ленту. ПРИШЛИ ЭТОТ ВЫВОД (+ серверный p11_chatdiag) админу.")
end)

print("[P11CHAT] v8 «ПУЛЬТ» OK — свой чат ВЫШЕ и УДОБНЕЕ (Y — речь, T — OOC); аварийно: p11chat_stock 1; ремонт ввода: p11_chat_repair")
