-- ============================================================
--  ПОЛЮС-11 — ЧАТ «СВЯЗЬ» (client) v4.14.0
--  ЗАЯВКА ВЛАДЕЛЬЦА: «сделай пж САМ свой кастомный чат с теми же
--  приколами, чтобы быстро выбирать там — так далее».
--
--  СВОЙ чат с ЧИСТОГО ЛИСТА, без BonChat/HTML:
--   1) ПОЛОСА КАНАЛОВ нативно (кнопки дермы, не JS-скальпель):
--      РЕЧЬ / ШЁПОТ / КРИК / OOC / LOOC / РАЦИЯ / ME / IT / РЕПОРТ.
--      Клик — канал выбран; TAB (и Shift+TAB) в поле ввода —
--      крутит каналы колесом. Префикс НЕ лезет в твой текст —
--      он подставляется при отправке, набранное не трогается.
--   2) Богатые пакеты серверного роутера (P11_ChatMsg) рисуются
--      прямо здесь (эта рука перехватывает у старого cl_chat:
--      net.Receive одноимённый — побеждает включённый позже).
--   3) Всё движковое (ChatPrint системы, рация, join/leave,
--      «/команды не найдены») тоже вливается в наш журнал
--      (обёртка chat.AddText + ChatText + OnPlayerChat с личиной:
--      P11_FakeNick > позывной > стим-ник — маскировка цела).
--   4) Приколы: история ввода (↑/↓), метки времени, 9-сек
--      затухание, счётчик пропущенных, звонок на новое слово,
--      авто-подстройка ширины, скролл-колёсико с тонким бегунком.
--   5) BonChat усыплён, но не выброшен: p11_ownchat 0 → старый
--      тандем (BonChat/движок) оживает обратно. Страховка бутстрапа
--      (p11_sh_bonchatboot) про это знает и держит расклад.
-- ============================================================

local cvOn    = CreateClientConVar("p11_ownchat", "1", true, false,
    "1 = свой чат станции «СВЯЗЬ» (0 = BonChat/движковый чат)")
local cvTrace = CreateClientConVar("p11pchat_trace", "0", true, false,
    "1 = трейс принятых чат-пакетов в консоль клиента")

P11CHAT = P11CHAT or {}
local CH = P11CHAT
CH.Cur     = CH.Cur or "say"
CH.Hist    = CH.Hist or {}
CH.HistIdx = 0
CH.Lines   = {}
CH.Rows    = {}
CH.Scroll  = 0
CH.Unread  = 0
CH.Open_   = false
CH.lastMsg = 0
CH.logW    = 0 -- ширина журнала, под которую собраны строки

local function Trace(msg)
    if cvTrace:GetBool() then print("[P11CHAT-СВЯЗЬ] " .. msg) end
end

-- ============ ШРИФТЫ / СТИЛЬ ============
-- v4.15.0 «УГЛИ»: крупнее на 2pt (заявка «увеличь чат — маленький очень»)
surface.CreateFont("P11CHAT.Main", { font = "Roboto", size = 19, weight = 600, extended = true, antialias = true })
surface.CreateFont("P11CHAT.Bold", { font = "Roboto", size = 19, weight = 800, extended = true, antialias = true })
surface.CreateFont("P11CHAT.Chip", { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("P11CHAT.Tiny", { font = "Roboto", size = 14, weight = 500, extended = true })

local COL_BG     = Color(9, 12, 18, 225)
local COL_BG2    = Color(13, 17, 25, 235)
local COL_EDGE   = Color(70, 95, 130, 120)
local COL_TEXT   = Color(232, 238, 245)
local COL_TS     = Color(105, 120, 140)
local ROW_H      = 22 -- v4.15.0: строки выше под крупный шрифт
local MAX_LINES  = 220
local FADE_SHOW  = 8  -- сек после последнего сообщения журнал виден
local FADE_OUT   = 2  -- сек затухания

-- ============ КАНАЛЫ (та же палитра, что у полосы над BonChat) ============
local MODES = {
    { id = "say",    lbl = "РЕЧЬ",   pfx = "",         col = Color(170, 220, 170),
      hint = "обычная речь — слышат рядом" },
    { id = "wsp",    lbl = "ШЁПОТ",  pfx = "/шепот ",  col = Color(180, 160, 235),
      hint = "тихо — только у самого уха" },
    { id = "shout",  lbl = "КРИК",   pfx = "/крик ",   col = Color(255, 150, 90),
      hint = "громко — почти через станцию" },
    { id = "ooc",    lbl = "OOC",    pfx = "// ",      col = Color(140, 200, 255),
      hint = "вне роли — слышат все" },
    { id = "looc",   lbl = "LOOC",   pfx = "/looc ",   col = Color(120, 180, 235),
      hint = "вне роли — рядом" },
    { id = "radio",  lbl = "РАЦИЯ",  pfx = "/r ",      col = Color(255, 205, 110),
      hint = "эфир твоего канала рации" },
    { id = "me",     lbl = "ME",     pfx = "/me ",     col = Color(235, 185, 120),
      hint = "действие от 3-го лица" },
    { id = "it",     lbl = "IT",     pfx = "/it ",     col = Color(160, 190, 160),
      hint = "повествование вокруг" },
    { id = "report", lbl = "РЕПОРТ", pfx = "/report ", col = Color(255, 120, 110),
      hint = "жалоба администрации" },
}
local function ModeOf(id)
    for i, m in ipairs(MODES) do
        if m.id == id then return m, i end
    end
    return MODES[1], 1
end

-- ============ ГЕОМЕТРИЯ ============
-- v4.15.0 «УГЛИ»: шире/выше; поднят НАД худом ХП и денег (якорь −200 от низа)
local function Layout()
    local w = math.min(1040, math.floor(ScrW() * 0.72)) -- v4.15.3 «КУРСОР»: расширен по заявке
    if w < 460 then w = 460 end
    local logH = 320
    local H = 30 + 4 + logH + 4 + 32 -- полоса каналов + журнал + поле ввода
    return w, H, logH
end
local function ChatPos()
    local _, H = Layout()
    return 16, ScrH() - H - 200 -- над зоной виталов: HUD ХП/денег не перекрываем
end

-- ============ РАЗБИВКА СТРОК (word-wrap с цветами) ============
local ROW_FONT = "P11CHAT.Main"

local function PushToken(tokens, col, word)
    tokens[#tokens + 1] = { col = col, txt = word }
end

-- utf8-безопасные куски слова (режем только по границам символов)
local function EachChar(s, fn)
    for c in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
        fn(c)
    end
end

local function RebuildRows()
    surface.SetFont(ROW_FONT)
    local maxW = CH.logW - 46
    if maxW < 160 then maxW = 160 end
    local spW = surface.GetTextSize(" ")

    CH.Rows = {}
    for _, ln in ipairs(CH.Lines) do
        -- токены строки: время + части
        local tokens = {}
        PushToken(tokens, COL_TS, "[" .. ln.ts .. "]")
        for _, p in ipairs(ln.parts) do
            local col, txt = p.col, p.txt
            for word in string.gmatch(txt, "%S+") do
                PushToken(tokens, col, word)
            end
        end

        -- жадная набивка рядов
        local row, rowW = {}, 0
        local function FlushRow()
            CH.Rows[#CH.Rows + 1] = row
            row, rowW = {}, 0
        end
        for _, t in ipairs(tokens) do
            local tw = surface.GetTextSize(t.txt)
            local need = tw + (#row > 0 and spW or 0)
            if #row > 0 and rowW + need > maxW then FlushRow() need = tw end
            if tw > maxW then
                -- глазной случай: одно слово шире журнала — режем по буквам
                local chunk, cw = "", 0
                EachChar(t.txt, function(c)
                    local cwch = surface.GetTextSize(c)
                    if cw + cwch > maxW then
                        row[#row + 1] = { col = t.col, txt = chunk }
                        FlushRow()
                        chunk, cw = "", 0
                    end
                    chunk = chunk .. c
                    cw = cw + cwch
                end)
                if chunk ~= "" then
                    row[#row + 1] = { col = t.col, txt = chunk }
                    rowW = cw
                end
            else
                row[#row + 1] = { col = t.col, txt = t.txt }
                rowW = rowW + need
            end
        end
        if #row > 0 then FlushRow() end
    end

    -- потолок рядов
    while #CH.Rows > 900 do table.remove(CH.Rows, 1) end
    CH.Scroll = math.max(0, math.min(CH.Scroll, #CH.Rows))
end

-- ============ ЖУРНАЛ ============
function CH.AddLine(parts)
    if not (istable(parts) and #parts > 0) then return end
    CH.Lines[#CH.Lines + 1] = { ts = os.date("%H:%M"), parts = parts }
    while #CH.Lines > MAX_LINES do table.remove(CH.Lines, 1) end
    RebuildRows()
    CH.lastMsg = CurTime()
    if not CH.Open_ then
        CH.Unread = CH.Unread + 1
        if CH.Scroll <= 2 then CH.Scroll = 0 end
    end
    chat.PlaySound()
end

function CH.Sys(text, col)
    CH.AddLine({ { col = col or Color(165, 200, 165), txt = tostring(text or "") } })
end

-- стильные строки каналов серверного роутера
local function StyledParts(chan, name, text, ncol)
    local white = COL_TEXT
    if chan == 1 then
        return { { col = ncol, txt = name }, { col = Color(120, 185, 255), txt = " говорит: " }, { col = white, txt = text } }
    elseif chan == 2 then
        return { { col = Color(150, 158, 172), txt = "[OOC] " }, { col = ncol, txt = name }, { col = Color(185, 190, 202), txt = ": " .. text } }
    elseif chan == 3 then
        return { { col = Color(128, 136, 150), txt = "[LOOC] " }, { col = ncol, txt = name }, { col = Color(160, 166, 180), txt = ": " .. text } }
    elseif chan == 4 then
        return { { col = Color(205, 165, 255), txt = "• " .. name .. " " .. text } }
    elseif chan == 5 then
        return { { col = Color(255, 205, 110), txt = "*** " .. text } }
    elseif chan == 6 then
        return { { col = Color(235, 100, 90), txt = "[РЕПОРТ] " }, { col = ncol, txt = name }, { col = Color(240, 150, 140), txt = ": " .. text } }
    elseif chan == 7 then
        return { { col = Color(135, 150, 190), txt = "[шёпот] " }, { col = ncol, txt = name }, { col = Color(180, 190, 215), txt = ": " .. text } }
    elseif chan == 8 then
        return { { col = Color(255, 140, 105), txt = "[КРИК] " }, { col = ncol, txt = name }, { col = Color(255, 200, 180), txt = ": " .. text } }
    end
    return { { col = ncol, txt = name }, { col = white, txt = ": " .. text } }
end

function CH.Styled(chan, name, text, ncol)
    CH.AddLine(StyledParts(chan, name, text, ncol))
end

-- ============ ПРИЁМНИКИ ============

-- богатые пакеты роутера: этот приёмник ПОСЛЕДНИЙ — он и победил
net.Receive("P11_ChatMsg", function()
    local chan = net.ReadUInt(4)
    local name = net.ReadString()
    local text = net.ReadString()
    local ncol = net.ReadColor()
    Trace("пакет: канал=" .. chan .. " | «" .. tostring(name) .. "» | " .. string.sub(tostring(text), 1, 40))
    if cvOn:GetBool() then
        CH.Styled(chan, name, text, ncol)
    else
        -- выключены: возвращаем старое поведение (BonChat/движок рисуют)
        local parts = StyledParts(chan, name, text, ncol)
        local args = {}
        for _, p in ipairs(parts) do
            args[#args + 1] = p.col
            args[#args + 1] = p.txt
        end
        chat.AddText(unpack(args))
    end
end)

-- всё движковое вливаем в свой журнал (и в консоль — как раньше)
if not CH.oldAddText then CH.oldAddText = chat.AddText end
function chat.AddText(...)
    if CH.oldAddText then CH.oldAddText(...) end
    if not cvOn:GetBool() then return end
    local args = { ... }
    local parts = {}
    local cur = COL_TEXT
    local plain = ""
    for _, a in ipairs(args) do
        if (IsColor and IsColor(a)) or (istable(a) and isnumber(a.r) and isnumber(a.g) and isnumber(a.b)) then
            cur = a
        elseif isstring(a) then
            parts[#parts + 1] = { col = cur, txt = a }
            plain = plain .. a
        elseif isentity(a) and IsValid(a) and a:IsPlayer() then
            -- маскировка цела: личина > позывной > стим-ник
            local nm, col = a:Nick(), team.GetColor(a:Team())
            local fake = a.GetNWString and a:GetNWString("P11_FakeNick", "") or ""
            if fake ~= "" then
                nm = fake
                local fj = tonumber(a:GetNWInt("P11_FakeJob", 0)) or 0
                if fj > 0 and team.GetName(fj) and team.GetName(fj) ~= "" then
                    local fc = team.GetColor(fj)
                    if fc then col = fc end
                end
            else
                local cnm = a:GetNWString("P11_CharName", "")
                if cnm ~= "" then nm = cnm end
            end
            parts[#parts + 1] = { col = col, txt = nm }
            plain = plain .. nm
        elseif a ~= nil then
            parts[#parts + 1] = { col = cur, txt = tostring(a) }
            plain = plain .. tostring(a)
        end
    end
    -- рация — янтарем (узнаём по префиксу; строка собрана сервером)
    if string.StartWith(plain, "[Рация") or string.StartWith(plain, "[Pация") then
        parts = { { col = Color(255, 205, 110), txt = plain } }
    end
    if #parts > 0 then CH.AddLine(parts) end
end

hook.Add("ChatText", "P11CHAT.ChatText", function(_, _, text, type)
    if not cvOn:GetBool() then return end
    text = tostring(text or "")
    if type == "servermsg" then
        CH.Sys(text, Color(255, 205, 110))
    elseif type == "none" then
        CH.Sys(text, Color(190, 198, 210))
    else
        CH.Sys(text, Color(150, 205, 150)) -- join/leave и прочие движковые
    end
    return true
end)

hook.Add("OnPlayerChat", "P11CHAT.Raw", function(ply, text, team2, isDead)
    if not cvOn:GetBool() then return end
    local parts = {}
    if isDead then parts[#parts + 1] = { col = Color(255, 90, 90), txt = "*МЁРТВ* " } end
    if team2 then parts[#parts + 1] = { col = Color(90, 200, 110), txt = "(TEAM) " } end
    if IsValid(ply) then
        local nm, col = ply:Nick(), team.GetColor(ply:Team())
        local fake = ply:GetNWString("P11_FakeNick", "")
        if fake ~= "" then
            nm = fake
            local fj = tonumber(ply:GetNWInt("P11_FakeJob", 0)) or 0
            if fj > 0 and team.GetName(fj) and team.GetName(fj) ~= "" then
                local fc = team.GetColor(fj)
                if fc then col = fc end
            end
        else
            local cnm = ply:GetNWString("P11_CharName", "")
            if cnm ~= "" then nm = cnm end
        end
        parts[#parts + 1] = { col = col, txt = nm }
    else
        parts[#parts + 1] = { col = Color(200, 200, 200), txt = "КОНСОЛЬ" }
    end
    parts[#parts + 1] = { col = COL_TEXT, txt = ": " .. tostring(text or "") }
    CH.AddLine(parts)
    return true
end)

-- скрыть движковый чат, пока наша «СВЯЗЬ» включена
hook.Add("HUDShouldDraw", "P11CHAT.HideEngine", function(name)
    if cvOn:GetBool() and name == "CHudChat" then return false end
end)

-- ============ ОКНО ============
function CH.Build()
    if IsValid(CH.Frame) then CH.Frame:Remove() end
    CH.Rows, CH.logW = {}, 0

    local W, H, logH = Layout()
    local px, py = ChatPos()
    -- DFrame вместо DPanel: родные MakePopup/курсор/фокус (v4.15.0 — боевой
    -- почин «не закрывается по ESC / опции не кликаются / строки ввода нет»)
    local f = vgui.Create("DFrame")
    CH.Frame = f
    f:SetSize(W, H)
    f:SetPos(px, py)
    f:SetTitle("")
    f:SetDraggable(false)
    f:SetSizable(false)
    f:SetDeleteOnClose(false)
    f:ShowCloseButton(false)
    if IsValid(f.btnMinim) then f.btnMinim:SetVisible(false) end
    if IsValid(f.btnMaxim) then f.btnMaxim:SetVisible(false) end
    f:SetMouseInputEnabled(false)
    f:SetKeyboardInputEnabled(false)

    local logTop, stripH = 30 + 4, 30
    local entryH = 32

    f.Paint = function(s, w, h)
        if not cvOn:GetBool() then return end
        local open = CH.Open_
        local since = CurTime() - CH.lastMsg
        local a
        if open then a = 255
        elseif since < FADE_SHOW then a = 175
        elseif since < FADE_SHOW + FADE_OUT then a = 175 * (1 - (since - FADE_SHOW) / FADE_OUT)
        else a = 0 end
        if a <= 1 then return end

        -- журнал: фон + ряды снизу вверх
        local bgA = math.floor(math.min(a, 235) * (open and 0.96 or 0.75))
        draw.RoundedBox(6, 0, logTop, w, logH, Color(COL_BG.r, COL_BG.g, COL_BG.b, bgA))
        surface.SetDrawColor(COL_EDGE.r, COL_EDGE.g, COL_EDGE.b, math.floor(a * 0.5))
        surface.DrawOutlinedRect(0, logTop, w, logH, 1)

        surface.SetFont(ROW_FONT)
        local y = logTop + logH - ROW_H - 4
        local li = #CH.Rows - CH.Scroll
        local drawn = 0
        while li >= 1 and y >= logTop + 1 do
            local row = CH.Rows[li]
            local x = 8
            for k, t in ipairs(row) do
                local wtxt = surface.GetTextSize(t.txt)
                draw.SimpleText(t.txt, ROW_FONT, x, y + 1, Color(0, 0, 0, math.floor(a * 0.55)))
                draw.SimpleText(t.txt, ROW_FONT, x, y, ColorAlpha(t.col, a))
                x = x + wtxt + ((k < #row) and surface.GetTextSize(" ") or 0)
            end
            y = y - ROW_H
            li = li - 1
            drawn = drawn + 1
        end

        -- тонкий бегунок
        if #CH.Rows * ROW_H > logH - 8 then
            local frac = (logH - 8) / (#CH.Rows * ROW_H)
            local barH = math.max(24, (logH - 8) * frac)
            local maxScroll = #CH.Rows - math.floor((logH - 8) / ROW_H)
            local pos = (maxScroll > 0) and (1 - CH.Scroll / maxScroll) or 1
            local bw = 3
            local bx = w - 6
            local by = logTop + 4 + (logH - 8 - barH) * pos
            draw.RoundedBox(2, bx, by, bw, barH, Color(120, 150, 190, math.floor(a * 0.65)))
        end
    end

    f.OnMouseWheeled = function(s, delta)
        local maxScroll = #CH.Rows - math.floor((logH - 8) / ROW_H)
        if maxScroll < 0 then maxScroll = 0 end
        CH.Scroll = math.max(0, math.min(maxScroll, CH.Scroll + delta * 3))
        return true
    end

    -- полоса каналов
    local strip = vgui.Create("DPanel", f)
    CH.Strip = strip
    strip:SetPos(0, 0)
    strip:SetSize(W, stripH)
    strip:SetPaintBackground(false)
    strip:Hide()

    -- поле ввода
    local entry = vgui.Create("DTextEntry", f)
    CH.Entry = entry
    entry:SetPos(0, H - entryH)
    entry:SetSize(W, entryH)
    entry:SetFont("P11CHAT.Main")
    entry:SetTextColor(COL_TEXT)
    entry:SetCursorColor(Color(140, 200, 255))
    entry:SetUpdateOnType(false)
    entry:Hide()
    entry.Paint = function(s, w2, h2)
        draw.RoundedBox(6, 0, 0, w2, h2, COL_BG2)
        local m = ModeOf(CH.Cur)
        surface.SetDrawColor(m.col.r, m.col.g, m.col.b, 190)
        surface.DrawOutlinedRect(0, 0, w2, h2, 1)
        s:DrawTextEntryText(COL_TEXT, m.col, COL_TEXT)
    end

    -- v4.15.0 «УГЛИ»: второй ESC-контур опросом (фокус может сидеть на окне,
    -- а не на поле) — страхует OnKeyCodeTyped поля
    f.Think = function()
        if not CH.Open_ then CH._escHeld = false return end
        local down = input.IsKeyDown(KEY_ESCAPE)
        if down and not CH._escHeld then
            CH._escHeld = true
            CH.Close()
            gui.HideGameUI()
        elseif not down then
            CH._escHeld = false
        end
    end

    function entry:OnEnter() CH.Submit() end
    function entry:OnKeyCodeTyped(code)
        if code == KEY_ESCAPE then
            CH.Close()
            gui.HideGameUI()
            return true
        elseif code == KEY_TAB then
            local _, idx = ModeOf(CH.Cur)
            if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
                idx = idx - 1
                if idx < 1 then idx = #MODES end
            else
                idx = idx + 1
                if idx > #MODES then idx = 1 end
            end
            CH.SetMode(MODES[idx].id, true)
            return true
        elseif code == KEY_UP then
            if #CH.Hist > 0 then
                if CH.HistIdx <= 0 then CH.HistIdx = #CH.Hist + 1 end
                CH.HistIdx = CH.HistIdx - 1
                if CH.HistIdx >= 1 then
                    entry:SetText(CH.Hist[CH.HistIdx] or "")
                    entry:SetCaretPos(#(CH.Hist[CH.HistIdx] or ""))
                else
                    entry:SetText("")
                end
            end
            return true
        elseif code == KEY_DOWN then
            if CH.HistIdx > 0 then
                CH.HistIdx = CH.HistIdx + 1
                if CH.HistIdx > #CH.Hist then
                    CH.HistIdx = 0
                    entry:SetText("")
                else
                    entry:SetText(CH.Hist[CH.HistIdx] or "")
                    entry:SetCaretPos(#(CH.Hist[CH.HistIdx] or ""))
                end
            end
            return true
        end
    end

    -- кнопки каналов (+ v4.15.3 «КУРСОР»: прямоугольники для ручного
    -- хит-теста — клики работают ДАЖЕ если дерма где-то глотает мышь)
    CH.ChipRects = {}
    local x = 2
    for _, m in ipairs(MODES) do
        surface.SetFont("P11CHAT.Chip")
        local tw = surface.GetTextSize(m.lbl) + 16
        CH.ChipRects[#CH.ChipRects + 1] = { x1 = x, x2 = x + tw, id = m.id }
        local b = vgui.Create("DButton", strip)
        b:SetPos(x, 1)
        b:SetSize(tw, stripH - 2)
        b:SetText("")
        b.Mode = m
        b.Paint = function(s2, w2, h2)
            local act = CH.Cur == s2.Mode.id
            local c = s2.Mode.col
            draw.RoundedBox(6, 0, 0, w2, h2,
                act and Color(c.r, c.g, c.b, 235) or Color(14, 18, 26, 225))
            surface.SetDrawColor(c.r, c.g, c.b, act and 255 or (s2:IsHovered() and 200 or 80))
            surface.DrawOutlinedRect(0, 0, w2, h2, 1)
            draw.SimpleText(s2.Mode.lbl, "P11CHAT.Chip", w2 / 2, h2 / 2 - 1,
                act and Color(10, 14, 18) or c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function(s2)
            CH.SetMode(s2.Mode.id, true)
            if IsValid(CH.Entry) then CH.Entry:RequestFocus() end
        end
        b:SetTooltip(m.hint .. (m.pfx ~= "" and (" • «" .. m.pfx .. "»") or ""))
        x = x + tw + 4
    end
    strip:SetWide(x)

    -- v4.15.3 «КУРСОР»: ЖЕЛЕЗНЫЙ ввод на рамке окна.
    -- ЛКМ в любом месте чата = возможность писать (фокус в поле сразу);
    -- ЛКМ по полосе каналов = выбор канала (хит-тест по прямоугольникам,
    -- не зависит от того, дошёл ли клик до самих кнопок дермы).
    local function FrameClick(code)
        if not CH.Open_ then return end
        if code ~= MOUSE_LEFT then return end
        local mx, my = gui.MouseX(), gui.MouseY()
        local fx, fy = f:GetPos()
        local lx, ly = mx - fx, my - fy
        if ly >= 0 and ly <= stripH and CH.ChipRects then
            for _, r in ipairs(CH.ChipRects) do
                if lx >= r.x1 and lx <= r.x2 then
                    if CH.Cur ~= r.id then CH.SetMode(r.id, true) end
                    break
                end
            end
        end
        if IsValid(CH.Entry) then
            CH.Entry:RequestFocus()
            CH.Entry:SetCaretPos(#(CH.Entry:GetText() or ""))
        end
    end
    f.OnMousePressed = function(_, code) FrameClick(code) end
    strip.OnMousePressed = function(_, code) FrameClick(code) end

    -- плейсхолдер-напоминалка рисуется поверх пустого поля
    entry.PaintOver = function(s, w2, h2)
        if s:GetText() == "" then
            local m = ModeOf(CH.Cur)
            draw.SimpleText(m.lbl .. ": пиши сюда… (клик = курсор, TAB/клик в шапку = канал, ↑ — история)",
                "P11CHAT.Tiny", 8, h2 / 2, Color(150, 162, 178), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    RebuildRows()
    return f
end

-- ============ РЕЖИМ / АПИ ============
function CH.SetMode(id, ping)
    CH.Cur = id
    if ping then surface.PlaySound("ui/buttonclick.wav") end
end

function CH.Open()
    if not cvOn:GetBool() then return end
    if CH.Open_ then return end
    if not IsValid(CH.Frame) then CH.Build() end
    CH.Open_ = true
    CH.Unread = 0
    CH.Scroll = 0
    CH.HistIdx = 0
    local f = CH.Frame
    f:Show()
    f:SetMouseInputEnabled(true)
    f:SetKeyboardInputEnabled(true)
    CH.Strip:Show()
    CH.Strip:SetMouseInputEnabled(true) -- v4.15.3: ярус полосы тоже
    CH.Entry:Show()
    CH.Entry:SetEnabled(true)
    CH.Entry:SetMouseInputEnabled(true)
    CH.Entry:SetKeyboardInputEnabled(true)
    f:MakePopup()
    f:MoveToFront()
    gui.EnableScreenClicker(true) -- страховь курсора (попап его и так даст)
    surface.PlaySound("UI/buttonclickrelease.wav")
    -- v4.15.0 «УГЛИ»: фокус строго СЛЕДУЮЩИМ тиком — в тот же тик поле ещё
    -- «не нарисовалось» и фокус молча слетал (отсюда «не могу писать»)
    timer.Simple(0.05, function()
        if not CH.Open_ or not IsValid(CH.Entry) then return end
        CH.Entry:RequestFocus()
        CH.Entry:SetCaretPos(#(CH.Entry:GetText() or ""))
    end)
    LocalPlayer().bonchatIsTyping = true -- титул «печатает» идёт по старому проводу
end

function CH.Close()
    if not CH.Open_ then return end
    CH.Open_ = false
    if IsValid(CH.Entry) and vgui.GetKeyboardFocus() == CH.Entry then
        CH.Entry:KillFocus()
    end
    if IsValid(CH.Strip) then CH.Strip:Hide() end
    if IsValid(CH.Entry) then CH.Entry:Hide() end
    if IsValid(CH.Frame) then
        CH.Frame:SetMouseInputEnabled(false)
        CH.Frame:SetKeyboardInputEnabled(false)
        CH.Frame:KillFocus()
    end
    gui.EnableScreenClicker(false) -- v4.15.3: парно к страховке в Open
    if IsValid(LocalPlayer()) then LocalPlayer().bonchatIsTyping = false end
end

function CH.Submit()
    local m = ModeOf(CH.Cur)
    local txt = string.Trim(IsValid(CH.Entry) and (CH.Entry:GetText() or "") or "")
    if txt ~= "" then
        local full = string.sub(m.pfx .. txt, 1, 300)
        RunConsoleCommand("say", full)
        CH.Hist[#CH.Hist + 1] = txt
        while #CH.Hist > 40 do table.remove(CH.Hist, 1) end
        CH.HistIdx = 0
    end
    CH.Close()
end

-- клавиши чата (Y и U по умолчанию; у кого перебиндено — теми же именами)
hook.Add("PlayerBindPress", "P11CHAT.Bind", function(ply, bind, pressed)
    if not cvOn:GetBool() then return end
    if not pressed then return end
    if bind == "messagemode" or bind == "messagemode2" then
        CH.Open()
        return true
    end
end)

-- счётчик пропущенных, когда чат закрыт
hook.Add("HUDPaint", "P11CHAT.Unread", function()
    if not cvOn:GetBool() or CH.Open_ or CH.Unread <= 0 then return end
    local px, py = ChatPos()
    draw.SimpleText("ПРОПУЩЕНО: " .. CH.Unread .. " — чат: клавиша Y",
        "P11CHAT.Tiny", px + 2, py - 18, Color(255, 214, 110))
end)

-- ресайз экрана — пересобрать геометрию и строки
hook.Add("OnScreenSizeChanged", "P11CHAT.Resize", function()
    if IsValid(CH.Frame) then
        local W, H = Layout()
        local px, py = ChatPos()
        CH.Frame:SetSize(W, H)
        CH.Frame:SetPos(px, py)
    end
    CH.logW = select(1, Layout())
    RebuildRows()
end)
CH.logW = select(1, Layout())

-- ============ СТАРТ ============
timer.Simple(1, function()
    local ok, err = pcall(CH.Build)
    if not ok then
        ErrorNoHalt("[P11CHAT-СВЯЗЬ] окно не поднялось: " .. tostring(err) .. " — возвращаю BonChat\n")
        RunConsoleCommand("bonchat_enable", "1")
        return
    end
    if cvOn:GetBool() then
        local bcv = GetConVar("bonchat_enable")
        if bcv and bcv:GetBool() then
            RunConsoleCommand("bonchat_enable", "0")
            print("[P11CHAT-СВЯЗЬ] свой чат старший — BonChat усыплён (вернуть: p11_ownchat 0)")
        end
    end
    print("[P11CHAT-СВЯЗЬ] v4.15.3 «КУРСОР» OK — ЖЕЛЕЗНЫЙ ввод: клик по чату = фокус поля, клик по полосе = канал (ручной хит-тест), ESC×2 контура, чат шире; выкл: p11_ownchat 0")
end)

-- переключение рубильника на лету
cvars.AddChangeCallback("p11_ownchat", function(_, _, newV)
    if newV == "1" then
        if not IsValid(P11CHAT.Frame) then pcall(CH.Build) end
        local bcv = GetConVar("bonchat_enable")
        if bcv and bcv:GetBool() then RunConsoleCommand("bonchat_enable", "0") end
    else
        CH.Close()
        if IsValid(CH.Frame) then CH.Frame:Remove() CH.Frame = nil end
        local bcv = GetConVar("bonchat_enable")
        if bcv and not bcv:GetBool() then RunConsoleCommand("bonchat_enable", "1") end
    end
end, "P11CHAT.Toggle")

concommand.Add("p11_pchat", function()
    print("[P11CHAT-СВЯЗЬ] статус: включён=" .. tostring(cvOn:GetBool())
        .. " | окно=" .. (IsValid(CH.Frame) and "ЖИВО" or "НЕТ")
        .. " | строк=" .. #CH.Lines .. " рядов=" .. #CH.Rows)
    if cvOn:GetBool() then CH.Open() end
end, nil, "Свой чат «СВЯЗЬ»: статус + открыть окно (p11_ownchat 1/0 — вкл/выкл)")

print("[P11CHAT-СВЯЗЬ] модуль чата v4.15.3 «КУРСОР» загружен (окно соберётся через сек)")
