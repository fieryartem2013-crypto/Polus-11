-- ============================================================
--  ПОЛЮС-11 — MENUV2 «КРАСОТА» v5.7.8 (КЛИЕНТ, энтити menuv2)
--  1) МИНИ-ИНТРО в стиле Хелиса: чистая тёмная заставка —
--     эмблема (кольца радара + звезда), заголовок «ПОЛЮС-11»,
--     тонкая линия, «НАЖМИТЕ, ЧТОБЫ ПРОДОЛЖИТЬ». Заменяет
--     длинное киношное интро (переопределяем net-приёмник).
--  2) НОВОЕ МЕНЮ ПЕРСОНАЖА: стеклянное окно «ЛИЧНОЕ ДЕЛО»,
--     слева — живой аватар (модель игрока) + предпросмотр
--     позывного, справа — поля с счётчиками, золотая кнопка.
--  3) ПОЛИРОВКА С-МЕНЮ «ПУЛЬТ СМЕНЫ»: стекло/градиент, живая
--     эмблема с радаром, красивые кнопки с подсветкой и
--     тултипами, аккуратные секции.
--
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА
--  (не зависит от sv_allowcslua). Старые файлы НЕ трогаем:
--  всё поверх — обёртки P11.OpenCMenu / P11.OpenCharUI и
--  переопределение net.Receive("P11_IntroShow").
-- ============================================================

if not P11 then P11 = {} end

-- ===================== ШРИФТЫ И ПАЛИТРА =====================
surface.CreateFont("P11.MV.IntroTitle", { font = "Roboto", size = 76, weight = 900, extended = true })
surface.CreateFont("P11.MV.IntroSub",    { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("P11.MV.IntroHint",   { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.MV.Title",       { font = "Roboto", size = 25, weight = 800, extended = true })
surface.CreateFont("P11.MV.Sub",         { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("P11.MV.Text",        { font = "Roboto", size = 18, weight = 700, extended = true })
surface.CreateFont("P11.MV.Small",       { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.MV.Tiny",        { font = "Roboto", size = 12, weight = 500, extended = true })
surface.CreateFont("P11.MV.Icon",        { font = "Roboto", size = 30, weight = 700, extended = true })
surface.CreateFont("P11.MV.IconSm",      { font = "Roboto", size = 24, weight = 700, extended = true })
surface.CreateFont("P11.MV.Counter",     { font = "Roboto", size = 13, weight = 700, extended = true })

local MV = {
    bg      = Color(9, 12, 20, 250),
    panel   = Color(20, 27, 40, 255),
    panel2  = Color(24, 32, 46, 255),
    cyan    = Color(120, 185, 255),
    cyan2   = Color(80, 150, 235),
    gold    = Color(255, 205, 110),
    text    = Color(228, 236, 245),
    dim     = Color(150, 165, 180),
    faint   = Color(95, 110, 130),
    ok      = Color(115, 215, 135),
    bad     = Color(235, 100, 90),
    hover   = Color(34, 46, 66, 255),
}

-- ===================== ХЕЛПЕРЫ РИСОВАНИЯ =====================
-- текст с разрядкой (по буквам) — стиль Хелиса
local function DrawSpaced(font, text, x, y, space, col)
    surface.SetFont(font)
    local total = 0
    for i = 1, #text do
        total = total + surface.GetTextSize(text:sub(i, i)) + space
    end
    local cx = x - total / 2
    for i = 1, #text do
        local ch = text:sub(i, i)
        surface.SetFont(font)
        local wch = surface.GetTextSize(ch)
        draw.SimpleText(ch, font, cx, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        cx = cx + wch + space
    end
end

-- пятиконечная звезда (полигоном, без текстур)
local function Star(cx, cy, r, col)
    local pts = {}
    for i = 1, 10 do
        local a = -math.pi / 2 + math.pi * (i - 1) / 5
        local rr = (i % 2 == 1) and r or r * 0.42
        pts[i] = { x = cx + math.cos(a) * rr, y = cy + math.sin(a) * rr }
    end
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawPoly(pts)
end

-- эмблема «радар + звезда» (анимированная)
local function Emblem(cx, cy, r, t)
    t = t or CurTime()
    for i = 3, 1, -1 do
        local rr = r + i * 11
        surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 60 - i * 8)
        surface.DrawCircle(cx, cy, rr, MV.cyan.r, MV.cyan.g, MV.cyan.b, 60 - i * 8)
    end
    surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 150)
    surface.DrawCircle(cx, cy, r, MV.cyan.r, MV.cyan.g, MV.cyan.b, 150)
    local a = t * 1.5
    surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 120)
    surface.DrawLine(cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r)
    surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 40)
    surface.DrawCircle(cx, cy, r * 0.62, MV.cyan.r, MV.cyan.g, MV.cyan.b, 40)
    Star(cx, cy, r * 0.42, MV.gold)
end

-- вертикальный градиент в прямоугольнике
local function GradBox(x, y, w, h, c1, c2, radius)
    if radius and radius > 0 then
        draw.RoundedBox(radius, x, y, w, h, c1)
    end
    surface.SetDrawColor(255, 255, 255, 255)
    for i = 0, h - 1, 3 do
        local t = i / math.max(1, h - 1)
        local c = LerpColor(t, c1, c2)
        surface.SetDrawColor(c.r, c.g, c.b, 255)
        surface.DrawRect(x, y + i, w, math.min(3, h - i))
    end
end

-- светлая верхняя грань панели
local function PanelHighlight(x, y, w, col, a)
    draw.RoundedBoxEx(8, x, y, w, 2, Color(col.r, col.g, col.b, a), true, true, false, false)
end

-- лёгкий снег (для интро)
local FLAKES = {}
local function InitFlakes()
    for i = 1, 70 do
        FLAKES[i] = {
            x = math.random(), y = math.random(),
            s = 12 + math.random() * 42,
            d = (math.random() - 0.5) * 0.05,
            a = 30 + math.random() * 90,
            ph = math.random() * 20,
        }
    end
end
InitFlakes()

-- ============================================================
--  1) МИНИ-ИНТРО В СТИЛЕ ХЕЛИСА
--     Чисто: эмблема → заголовок → линия → подзаголовок →
--     «НАЖМИТЕ, ЧТОБЫ ПРОДОЛЖИТЬ». ~12 сек, пропуск — клик/
--     любая клавиша. Уважает p11_intro 0 (отключить).
--     Переопределяем net.Receive("P11_IntroShow") — старый
--     приёмник затирается, длинное киношное интро не играет.
-- ============================================================

CreateClientConVar("p11_intro", "1", true, false)

local MINTRO = { active = false, shown = false, t = 0, frame = nil }

local function CloseMiniIntro()
    if not MINTRO.active then return end
    MINTRO.active = false
    P11.IntroOpen = false
    if IsValid(MINTRO.frame) then MINTRO.frame:Remove() MINTRO.frame = nil end
    hook.Remove("Think", "P11.MV.IntroThink")
end

local function OpenMiniIntro()
    if MINTRO.active then return end
    if MINTRO.shown then return end
    if GetConVarNumber("p11_intro", 1) == 0 then MINTRO.shown = true return end
    MINTRO.shown = true
    MINTRO.active = true
    MINTRO.t = CurTime()
    P11.IntroOpen = true

    local f = vgui.Create("DPanel")
    MINTRO.frame = f
    f:SetSize(ScrW(), ScrH())
    f:SetPos(0, 0)
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    f.Paint = function(s, w, h)
        -- фон: глубокий сине-чёрный градиент
        GradBox(0, 0, w, h, Color(8, 11, 19, 255), Color(13, 20, 32, 255))
        -- лёгкий шум-зерно
        for i = 1, 30 do
            surface.SetDrawColor(255, 255, 255, math.random(1, 5))
            surface.DrawRect(math.random(0, w), math.random(0, h), 1, 1)
        end
        -- снег
        for _, fl in ipairs(FLAKES) do
            local sy = (fl.y + CurTime() * 0.01 * fl.s) % 1
            surface.SetDrawColor(220, 235, 245, fl.a)
            surface.DrawRect(fl.x * w, sy * h, fl.s * 0.16, fl.s * 0.16)
        end
        -- виньетка
        surface.SetDrawColor(0, 0, 0, 90)
        surface.DrawRect(0, 0, w, 3)
        surface.DrawRect(0, h - 3, w, 3)
        surface.DrawRect(0, 0, 3, h)
        surface.DrawRect(w - 3, 0, 3, h)

        local el = CurTime() - MINTRO.t
        local t = math.Clamp(el / 0.8, 0, 1)
        local e = 1 - (1 - t) * (1 - t) -- ease-out

        -- эмблема
        surface.SetAlphaMultiplier(e)
        Emblem(w / 2, h * 0.40, 46, CurTime())

        -- заголовок с разрядкой
        surface.SetAlphaMultiplier(e)
        DrawSpaced("P11.MV.IntroTitle", "ПОЛЮС-11", w / 2, h * 0.52, 10, MV.text)

        -- тонкая линия-разделитель (растёт)
        local lw = math.min(320, 320 * e)
        surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 160 * e)
        surface.DrawRect(w / 2 - lw / 2, h * 0.52 + 52, lw, 2)

        -- подзаголовок
        if el > 0.9 then
            surface.SetAlphaMultiplier(math.min(1, (el - 0.9) / 0.6))
            DrawSpaced("P11.MV.IntroSub", "ИССЛЕДОВАТЕЛЬСКАЯ СТАНЦИЯ · АНТАРКТИДА · ЗИМА 1982",
                w / 2, h * 0.52 + 72, 3, MV.dim)
        end

        -- сегменты прогресса (снизу, стиль Хелиса)
        local frac = math.Clamp(el / 12, 0, 1)
        local seg = 34
        local segW = 4
        local gap = 6
        local totalW = seg * (segW + gap) - gap
        local lit = math.floor(frac * seg + 0.5)
        for i = 1, seg do
            local sx = w / 2 - totalW / 2 + (i - 1) * (segW + gap)
            if i <= lit then
                surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 190)
            else
                surface.SetDrawColor(60, 75, 95, 120)
            end
            surface.DrawRect(sx, h * 0.86, segW, 3)
        end

        -- «НАЖМИТЕ, ЧТОБЫ ПРОДОЛЖИТЬ»
        if (CurTime() % 1.3) < 0.95 then
            draw.SimpleText("НАЖМИТЕ, ЧТОБЫ ПРОДОЛЖИТЬ", "P11.MV.IntroHint",
                w / 2, h * 0.92, MV.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        surface.SetAlphaMultiplier(1)
    end

    f.OnMousePressed = function() CloseMiniIntro() end
    f.OnKeyCodePressed = function(s, key)
        if key ~= 0 then CloseMiniIntro() end
    end

    hook.Add("Think", "P11.MV.IntroThink", function()
        if not MINTRO.active then hook.Remove("Think", "P11.MV.IntroThink") return end
        if input.IsKeyDown(KEY_ESCAPE) or input.IsKeyDown(KEY_ENTER)
            or input.IsKeyDown(KEY_SPACE) or input.IsMouseDown(MOUSE_LEFT) then
            CloseMiniIntro()
        end
        if CurTime() - MINTRO.t > 14 then CloseMiniIntro() end
    end)
end

-- переопределяем приёмник — старый длинный интро не играет
net.Receive("P11_IntroShow", function()
    timer.Simple(0.6, OpenMiniIntro)
end)

-- ручной повтор: p11_intro_show
concommand.Add("p11_intro_show", function()
    MINTRO.shown = false
    OpenMiniIntro()
end)

-- ============================================================
--  2) НОВОЕ МЕНЮ ПЕРСОНАЖА (ЛИЧНОЕ ДЕЛО)
--     Стеклянное окно: слева аватар с моделью + живой
--     предпросмотр позывного; справа поля и золотая кнопка.
--     Та же логика и net-пакет "P11_CharSave" (3–32 / до 140).
--     Заменяет P11.OpenCharUI (гейммодный файл не трогаем).
-- ============================================================

local function OpenCharUI()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if IsValid(P11.CharFrame) then P11.CharFrame:Remove() end

    local oldName = me:GetNWString("P11_CharName", "")
    local oldDesc = me:GetNWString("P11_CharDesc", "")

    local f = vgui.Create("DFrame")
    P11.CharFrame = f
    f:SetSize(600, 420)
    f:Center()
    f:MakePopup()
    f:SetSizable(false)
    f:SetDeleteOnClose(true)
    f:SetTitle("")
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, 0)
        GradBox(0, 0, w, h, Color(11, 15, 24, 248), Color(8, 11, 18, 248), 10)
        -- шапка
        GradBox(0, 0, w, 52, Color(18, 25, 38, 255), Color(13, 19, 30, 255))
        draw.RoundedBoxEx(10, 0, 0, w, 52, Color(18, 25, 38, 255), true, true, false, false)
        PanelHighlight(1, 1, w - 2, MV.cyan, 40)
        -- эмблема в шапке
        local ra = CurTime() * 1.4
        surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 90)
        surface.DrawCircle(26, 26, 15, MV.cyan.r, MV.cyan.g, MV.cyan.b, 90)
        surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 120)
        surface.DrawLine(26, 26, 26 + math.cos(ra) * 13, 26 + math.sin(ra) * 13)
        Star(26, 26, 7, MV.gold)
        draw.SimpleText("ЛИЧНОЕ ДЕЛО БОЙЦА", "P11.MV.Title", 50, 26, MV.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("позывной и внешность — видят все", "P11.MV.Tiny", w - 14, 26, MV.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- ---- ЛЕВАЯ КАРТОЧКА: аватар + живой предпросмотр ----
    local card = vgui.Create("DPanel", f)
    card:SetPos(16, 64) card:SetSize(220, 300)
    card.Paint = function(s, ww, hh)
        draw.RoundedBox(8, 0, 0, ww, hh, Color(16, 22, 33, 235))
        PanelHighlight(0, 0, ww, MV.cyan, 26)
        -- слот модели
        draw.RoundedBox(6, 8, 8, ww - 16, 176, Color(10, 14, 22, 255))
    end

    -- модель игрока (аватар)
    local mdlOK = pcall(function()
        local av = vgui.Create("DModelPanel", card)
        av:SetPos(8, 8) av:SetSize(card:GetWide() - 16, 176)
        av:SetModel(me:GetModel())
        av:SetFOV(38)
        av:SetCamPos(Vector(52, 0, 40))
        av:SetLookAng(Angle(0, 0, 0))
        av:SetAnimated(true)
        av.LayoutEntity = function() return end
    end)

    -- живой предпросмотр позывного
    local namePrev = vgui.Create("DLabel", card)
    namePrev:SetPos(10, 196) namePrev:SetSize(200, 26)
    namePrev:SetFont("P11.MV.Text") namePrev:SetTextColor(MV.gold)
    namePrev:SetText("")

    local descPrev = vgui.Create("DLabel", card)
    descPrev:SetPos(10, 226) descPrev:SetSize(200, 60)
    descPrev:SetFont("P11.MV.Tiny") descPrev:SetTextColor(MV.dim)
    descPrev:SetWrap(true)
    descPrev:SetText("")

    local function UpdatePrev(name, desc)
        local n = string.Trim(name or "")
        if n == "" then n = "твой позывной" end
        namePrev:SetText(n)
        local d = string.Trim(desc or "")
        if d == "" then d = "описание внешности появится здесь…" end
        descPrev:SetText(d)
    end
    UpdatePrev(oldName, oldDesc)

    -- ---- ПРАВАЯ ЧАСТЬ: поля ----
    local l1 = vgui.Create("DLabel", f)
    l1:SetPos(250, 66) l1:SetSize(334, 18)
    l1:SetFont("P11.MV.Tiny") l1:SetTextColor(MV.cyan)
    l1:SetText("ПОЗЫВНОЙ (3–32 знака) — так тебя видят на станции")

    local e1 = vgui.Create("DTextEntry", f)
    e1:SetPos(250, 86) e1:SetSize(334, 32)
    e1:SetFont("P11.MV.Small")
    e1:SetText(oldName)
    e1:SetPlaceholderText("напр.: ст. сержант КРАСНОВ")
    e1:SetUpdateOnType(true)
    e1.OnTextChanged = function()
        UpdatePrev(e1:GetText(), e2:GetText())
        Validate()
    end

    local cnt1 = vgui.Create("DLabel", f)
    cnt1:SetPos(250, 120) cnt1:SetSize(334, 14)
    cnt1:SetFont("P11.MV.Counter") cnt1:SetTextColor(MV.faint)

    local l2 = vgui.Create("DLabel", f)
    l2:SetPos(250, 146) l2:SetSize(334, 18)
    l2:SetFont("P11.MV.Tiny") l2:SetTextColor(MV.cyan)
    l2:SetText("ОПИСАНИЕ ВНЕШНОСТИ (до 140 знаков)")

    local e2 = vgui.Create("DTextEntry", f)
    e2:SetPos(250, 166) e2:SetSize(334, 120)
    e2:SetMultiline(true)
    e2:SetFont("P11.MV.Tiny")
    e2:SetText(oldDesc)
    e2:SetPlaceholderText("напр.: высокий, шрам через бровь, потёртый полушубок, за пазухой — блокнот")
    e2:SetUpdateOnType(true)
    e2.OnTextChanged = function()
        UpdatePrev(e1:GetText(), e2:GetText())
        Validate()
    end

    local cnt2 = vgui.Create("DLabel", f)
    cnt2:SetPos(250, 288) cnt2:SetSize(334, 14)
    cnt2:SetFont("P11.MV.Counter") cnt2:SetTextColor(MV.faint)

    -- ---- КНОПКИ ----
    local bSave = vgui.Create("DButton", f)
    bSave:SetPos(250, 318) bSave:SetSize(220, 44)
    bSave:SetText("")

    local bLater = vgui.Create("DButton", f)
    bLater:SetPos(484, 318) bLater:SetSize(100, 44)
    bLater:SetText("")

    local function Validate()
        local name = string.Trim(e1:GetText() or "")
        local desc = string.Trim(e2:GetText() or "")
        cnt1:SetText(#name .. "/32" .. (#name > 32 and " — лишнее отрежется" or ""))
        cnt2:SetText(#desc .. "/140" .. (#desc > 140 and " — лишнее отрежется" or ""))
        return #name >= 3
    end

    bSave.Paint = function(s, ww, hh)
        local can = Validate()
        local hov = s:IsHovered() and can
        draw.RoundedBox(8, 0, 0, ww, hh, Color(24, 32, 46, 255))
        if hov then
            surface.SetDrawColor(MV.gold.r, MV.gold.g, MV.gold.b, 110)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        end
        draw.RoundedBoxEx(8, 0, 0, ww, math.floor(hh / 2), Color(255, 255, 255, 6), true, true, false, false)
        -- золотой акцент-уголки
        surface.SetDrawColor(MV.gold.r, MV.gold.g, MV.gold.b, can and 220 or 60)
        surface.DrawRect(0, 0, 14, 2) surface.DrawRect(0, 0, 2, 14)
        surface.DrawRect(ww - 14, 0, 14, 2) surface.DrawRect(ww - 2, 0, 2, 14)
        surface.DrawRect(0, hh - 2, 14, 2) surface.DrawRect(0, hh - 14, 2, 14)
        surface.DrawRect(ww - 14, hh - 2, 14, 2) surface.DrawRect(ww - 2, hh - 14, 2, 14)
        draw.SimpleText("ЗАПИСАТЬ В ДЕЛО", "P11.MV.Small", ww / 2, hh / 2,
            can and MV.gold or Color(110, 118, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    bLater.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        draw.RoundedBox(8, 0, 0, ww, hh, hov and Color(38, 48, 62, 255) or Color(22, 29, 40, 255))
        surface.SetDrawColor(110, 125, 145, 90)
        surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        draw.SimpleText("позже", "P11.MV.Small", ww / 2, hh / 2,
            MV.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    bSave.DoClick = function()
        local name = string.Trim(e1:GetText() or "")
        if #name < 3 then
            surface.PlaySound("buttons/button10.wav")
            return
        end
        surface.PlaySound("buttons/button15.wav")
        net.Start("P11_CharSave")
            net.WriteString(name)
            net.WriteString(string.Trim(e2:GetText() or ""))
        net.SendToServer()
        f:Remove()
    end
    bLater.DoClick = function() f:Remove() end

    -- нижняя подсказка
    local foot = vgui.Create("DLabel", f)
    foot:SetPos(16, 372) foot:SetSize(568, 16)
    foot:SetFont("P11.MV.Tiny") foot:SetTextColor(MV.faint)
    foot:SetText("анкета видна всем, кто смотрит на тебя · ESC — закрыть · сохраняется на станции")

    Validate()
end
P11.OpenCharUI = OpenCharUI

-- ============================================================
--  3) ПОЛИРОВКА С-МЕНЮ «ПУЛЬТ СМЕНЫ»
--     Оборачиваем P11.OpenCMenu: после сборки перекрашиваем
--     фон/шапку/секции и все CButton-кнопки (по полям PName).
--     Сами кнопки не трогаем по логике — только Paint поверх.
-- ============================================================

-- перекраска одной CButton-кнопки
local function ReskinButton(b)
    if b.P11Skinned then return end
    b.P11Skinned = true

    local icon = b.PIcon or "•"
    local name = b.PName or ""
    local desc = b.PDesc or ""
    local col = b.PCol or Color(228, 236, 245)
    local big = b.PBig == true

    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered() and s:IsEnabled()
        local dis = not s:IsEnabled()
        local cell = big and 46 or 34

        -- фон кнопки
        if hov then
            draw.RoundedBox(8, 0, 0, ww, hh, Color(32, 44, 62, 255))
            surface.SetDrawColor(col.r, col.g, col.b, 95)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        elseif dis then
            draw.RoundedBox(8, 0, 0, ww, hh, Color(15, 19, 27, 210))
        else
            draw.RoundedBox(8, 0, 0, ww, hh, Color(20, 27, 39, 240))
            draw.RoundedBoxEx(8, 0, 0, ww, math.floor(hh / 2), Color(255, 255, 255, 5), true, true, false, false)
        end

        -- ячейка-иконка слева
        draw.RoundedBox(6, 6, (hh - cell) / 2, cell, cell,
            dis and Color(40, 48, 60, 255) or Color(col.r, col.g, col.b, hov and 66 or 38))
        draw.SimpleText(icon, big and "P11.MV.Icon" or "P11.MV.IconSm",
            6 + cell / 2, hh / 2,
            dis and Color(120, 130, 145) or Color(240, 248, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- текст: имя + описание (узкие кнопки — компактнее)
        local nameF = "P11.MV.Text"
        local descF = "P11.MV.Tiny"
        if ww < 150 then
            nameF = "P11.MV.Small"
        end
        local tx = 6 + cell + 10
        if hh >= 44 then
            draw.SimpleText(name, nameF, tx, hh / 2 - 9, dis and Color(120, 130, 145) or MV.text,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(desc, descF, tx, hh / 2 + 11, dis and Color(90, 100, 115) or MV.faint,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(name, nameF, tx, hh / 2, dis and Color(120, 130, 145) or MV.text,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- стрелка при ховере
        if hov and ww > 180 then
            draw.SimpleText("›", "P11.MV.IconSm", ww - 14, hh / 2, MV.cyan, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    b:SetTooltip(desc)
end

-- перекраска заголовков-секций (DLabel с фикс. текстом)
local SECTIONS = { "ЖЕСТЫ", "БЫСТРОЕ:", "АДМИНИСТРАЦИИ:", "ОФИЦЕРУ", "⚡ БЫСТРЫЕ" }
local function ReskinLabel(l)
    if l.P11Skinned then return end
    l.P11Skinned = true
    local base = l.Paint
    l.Paint = function(s, ww, hh)
        if base then base(s, ww, hh) end
        local tx = s:GetText() or ""
        local col = MV.cyan
        if string.find(tx, "АДМИНИСТРАЦИИ") or string.find(tx, "БЫСТРЫЕ") then col = MV.bad end
        surface.SetDrawColor(col.r, col.g, col.b, 70)
        surface.DrawRect(0, hh - 2, math.min(64, ww), 2)
    end
end

local function WalkChildren(pnl)
    for _, ch in ipairs(pnl:GetChildren()) do
        if ch:GetClassName() == "DButton" then
            if ch.PName and not ch.P11Skinned then ReskinButton(ch) end
        elseif ch:GetClassName() == "DLabel" then
            local tx = ch:GetText() or ""
            for _, s in ipairs(SECTIONS) do
                if string.find(tx, s, 1, true) then
                    ReskinLabel(ch)
                    break
                end
            end
        end
        WalkChildren(ch)
    end
end

-- полировка самого окна
local function PolishFrame(f)
    if f.P11Polished then return end
    f.P11Polished = true

    local me = LocalPlayer()
    local isStaff = f.PStaff == true

    f.Paint = function(s, w, h)
        local el = SysTime() - (s.T0 or SysTime())
        local e = math.Clamp(el / 0.3, 0, 1)
        e = 1 - (1 - e) * (1 - e)

        surface.SetAlphaMultiplier(0.25 + 0.75 * e)
        Derma_DrawBackgroundBlur(s, s.T0 or 0)

        -- стеклянная основа
        GradBox(0, 0, w, h, Color(13, 18, 29, 250), Color(8, 11, 19, 250), 10)

        -- сетка-подложка (едва заметная)
        surface.SetDrawColor(120, 180, 255, 4)
        for gx = 0, w, 26 do surface.DrawRect(gx, 0, 1, h) end
        for gy = 0, h, 26 do surface.DrawRect(0, gy, w, 1) end

        -- шапка
        GradBox(0, 0, w, 54, Color(19, 26, 40, 255), Color(13, 19, 30, 255))
        draw.RoundedBoxEx(10, 0, 0, w, 54, Color(19, 26, 40, 255), true, true, false, false)
        PanelHighlight(1, 1, w - 2, MV.cyan, 45)

        -- эмблема-радар в шапке
        Emblem(28, 27, 15, CurTime())

        -- заголовок
        draw.SimpleText("ПУЛЬТ СМЕНЫ", "P11.MV.Title", 52, 15, MV.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local rk = P11FW.GetRankName and P11FW.GetRankName(me) or "User"
        local jn = P11FW.GetJobName and P11FW.GetJobName(me) or ""
        draw.SimpleText(me:Nick() .. (jn ~= "" and (" · " .. jn) or "") .. " · " .. rk,
            "P11.MV.Tiny", 52, 42, MV.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- кошелёк с мягким свечением
        local mt = me:GetNWInt("P11_Money", 0) .. " ₽"
        surface.SetFont("P11.MV.Text")
        local mw = surface.GetTextSize(mt) + 26
        local pulse = 0.75 + math.sin(CurTime() * 2.4) * 0.25
        draw.RoundedBox(13, w - mw - 12, 8, mw, 26, Color(MV.gold.r, MV.gold.g, MV.gold.b, 30))
        surface.SetDrawColor(MV.gold.r, MV.gold.g, MV.gold.b, math.floor(150 * pulse))
        surface.DrawOutlinedRect(w - mw - 12, 8, mw, 26, 1)
        draw.SimpleText(mt, "P11.MV.Text", w - mw / 2 - 12, 21, MV.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("удерживай C • ESC — закрыть • F6 — поддержка",
            "P11.MV.Tiny", w - 14, 45, MV.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- секции-подложки
        draw.RoundedBox(10, 8, 78, 504, 366, Color(255, 255, 255, 6))
        PanelHighlight(9, 79, 502, MV.cyan, 22)
        draw.RoundedBox(10, 526, 78, 240, 366, Color(255, 255, 255, 6))
        PanelHighlight(527, 79, 238, MV.cyan, 22)
        if isStaff then
            draw.RoundedBox(10, 8, 556, 764, 84, Color(255, 90, 75, 16))
            surface.SetDrawColor(MV.bad.r, MV.bad.g, MV.bad.b, 70)
            surface.DrawOutlinedRect(8, 556, 764, 84, 1)
            PanelHighlight(9, 557, 762, MV.bad, 30)
        end

        -- уголки рамки
        surface.SetDrawColor(MV.cyan.r, MV.cyan.g, MV.cyan.b, 90)
        surface.DrawRect(0, 0, 16, 2) surface.DrawRect(0, 0, 2, 16)
        surface.DrawRect(w - 16, 0, 16, 2) surface.DrawRect(w - 2, 0, 2, 16)
        surface.DrawRect(0, h - 2, 16, 2) surface.DrawRect(0, h - 16, 2, 16)
        surface.DrawRect(w - 16, h - 2, 16, 2) surface.DrawRect(w - 2, h - 16, 2, 16)

        surface.SetAlphaMultiplier(1)
    end

    WalkChildren(f)
end

-- обёртка открытия С-меню
local patched = false
local function EnsurePatch()
    if patched then return true end
    if not P11 or not P11.OpenCMenu then return false end
    local orig = P11.OpenCMenu
    P11.OpenCMenu = function(...)
        if orig then orig(...) end
        if IsValid(P11.CMenu) then PolishFrame(P11.CMenu) end
    end
    patched = true
    return true
end

hook.Add("Think", "P11.MV.Patch", function()
    EnsurePatch()
    if IsValid(P11 and P11.CMenu) then PolishFrame(P11.CMenu) end
end)

print("[POLUS-11] MENUV2 v5.7.8: мини-интро Хелис + новое меню персонажа + полировка С-меню")
