-- ============================================================
--  ПОЛЮС-11 — С-МЕНЮ ИГРОКА (client) v5.1 «КОМАНДОР» (v4.30.0)
--  v5.1: стаффу (Хелпер+) меню ВЫШЕ на полосу «БЫСТРЫЕ КОМАНДЫ» —
--  пять кнопок: ВАРН/БАН/КИК/К НЕМУ/К СЕБЕ. Клик → выбор бойца
--  списком → причина/срок (своё окно P11.StringRequest) → штатный
--  пакет P11FW_AdminAction. Права/лимиты — на сервере, кнопки без
--  прав серые. Исходный набор команд: /warn /ban /kick /mute /unmute
--  (см. p11_sv_admincmds).
--  Зажал C → станционное меню: ЖЕСТЫ, БЫСТРЫЕ ДЕЙСТВИЯ, персонаж,
--  браузер внешности, админ-панель / вайтлист-панель для рангов.
--
--  ПОЧЕМУ РЕВОРК: у части игроков меню не открывалось — цепочка
--  +menu_context рвалась в четырёх разных местах (таймер-сторож,
--  бинд-перехват, гейммод-хуки, чат), которые жили РАЗДЕЛЬНО и
--  могли «перекрыть» друг друга (open→close в одно нажатие).
--  Теперь ОДИН менеджер ввода: единая точка TryOpen/Toggle,
--  единый детектор фронта KEY_C в Think, а бинд/гейммод/чат/консоль —
--  только тонкие адаптеры к нему. Гонок open/close больше нет.
--
--  ОТКРЫТЬ: клавиша C (удерживать) • p11_cmenu • !меню в чат.
--  ЗАКРЫТЬ: отпустить C / ESC / повторная команда.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.CM.Title", { font = "Roboto", size = 27, weight = 800, extended = true })
surface.CreateFont("P11.CM.Text",  { font = "Roboto", size = 19, weight = 600, extended = true })
surface.CreateFont("P11.CM.Small", { font = "Roboto", size = 15, weight = 400, extended = true })
surface.CreateFont("P11.CM.Mdl",   { font = "Roboto", size = 22, weight = 800, extended = true })

-- палитра — фирменный P11UI
local CC = {
    bg    = Color(10, 14, 20, 245),
    panel = Color(20, 26, 36, 255),
    cyan  = Color(120, 185, 255),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    dim   = Color(150, 165, 180),
    ok    = Color(115, 215, 135),
    bad   = Color(235, 100, 90),
}

-- v4.26.0 «СИЯНИЕ»: пятиконечная звезда полигоном (эмблема пульта)
local function CMStar(cx, cy, r, col)
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

-- жесты в порядке серверной таблицы fw_sv_emotes.lua
local EMOTES = {
    { id = 1, glyph = "👋", name = "Махнуть",      desc = "приветствие" },
    { id = 2, glyph = "🫡", name = "Салют",        desc = "по-военному" },
    { id = 3, glyph = "✔", name = "Кивнуть «да»",  desc = "согласие" },
    { id = 4, glyph = "✖", name = "Мотнуть «нет»", desc = "отрицание" },
    { id = 5, glyph = "👉", name = "Сюда! ",       desc = "подозвать" },
    { id = 6, glyph = "🎉", name = "Ликовать",     desc = "радость" },
    { id = 7, glyph = "🤝", name = "Отдать",       desc = "протянуть вещь" },
    { id = 8, glyph = "📦", name = "Положить",     desc = "уложить вещь" },
}

-- v4.26.0 «СИЯНИЕ»: кнопка-КАРТОЧКА — глиф живёт в цветной ячейке слева,
-- ховер поджигает контур и выдвигает стрелку; big=true — баннер-режим.
local function CButton(parent, x, y, w, h, name, desc, col, click, big)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y) b:SetSize(w, h)
    b:SetText("")
    local icon, rest = string.match(name, "^(%S+)%s+(.+)$")
    if not rest then icon, rest = "•", name end
    b.PIcon, b.PName, b.PDesc, b.PCol = icon, rest, desc, col or CC.text
    b.PBig = big and true or false
    b.PCell = b.PBig and 46 or 36
    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        local cw = s.PCell
        draw.RoundedBox(6, 0, 0, ww, hh, hov and Color(255, 255, 255, 20) or CC.panel)
        if s.PBig then -- баннер-режим: верхний ледяной скол
            draw.RoundedBoxEx(6, 0, 0, ww, math.floor(hh / 2), Color(255, 255, 255, 7), true, true, false, false)
        end
        -- ячейка глифа слева
        draw.RoundedBoxEx(6, 0, 0, cw, hh,
            Color(s.PCol.r, s.PCol.g, s.PCol.b, hov and 62 or 32), true, false, true, false)
        surface.SetDrawColor(s.PCol.r, s.PCol.g, s.PCol.b, 110)
        surface.DrawRect(cw, 0, 1, hh)
        draw.SimpleText(s.PIcon, "P11.CM.Mdl", cw / 2, hh / 2,
            Color(s.PCol.r, s.PCol.g, s.PCol.b, hov and 255 or 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local dy = s.PDesc and (hh / 2 - 9) or (hh / 2)
        draw.SimpleText(s.PName, "P11.CM.Text", cw + 10, dy, s.PCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if s.PDesc then
            draw.SimpleText(s.PDesc, "P11.CM.Small", cw + 10, hh / 2 + 11, CC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        if hov then
            surface.SetDrawColor(s.PCol.r, s.PCol.g, s.PCol.b, 150)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            draw.SimpleText("►", "P11.CM.Small", ww - 10, hh / 2, s.PCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            s:SetCursor("hand")
        end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        click()
    end
    return b
end

-- ============================================================
--  ОБЩИЕ UI-ПОМОЩНИКИ (глобалы — их используют и другие модули)
-- ============================================================

local TWEEN_LEN = 0.22

local function TweenK(s)
    local k = math.Clamp((SysTime() - (s.AnimT or 0)) / TWEEN_LEN, 0, 1)
    return 1 - (1 - k) ^ 3 -- easeOutCubic
end

-- выезд снизу на 22 px + прогресс анимации для Paint
function P11.AnimateIn(s)
    s.AnimT = SysTime()
    local tx, ty = s:GetPos()
    s:SetPos(tx, ty + 22)
    s.Think = function()
        s:SetPos(tx, ty + 22 * (1 - TweenK(s)))
    end
end

-- рисовать ПЕРВЫМ в Paint: затемнение экрана вокруг окна
function P11.DrawDim(s, strength)
    local x, y = s:GetPos()
    surface.SetDrawColor(5, 9, 13, (strength or 150) * TweenK(s))
    surface.DrawRect(-x, -y, ScrW(), ScrH())
end

function P11.CloseCMenu()
    if IsValid(P11.CMenu) then P11.CMenu:Remove() end
end

-- ============================================================
--  v4.8.2: СВОЁ ОКНО ВВОДА СТРОКИ (замена Derma_StringRequest)
--  Жалоба: штатная Derma-форма заявки грузчику «вспыхивает на
--  секунду и пропадает, второй раз вообще не открывается».
--  Теперь окно полностью наше: живёт, пока сам не закроешь
--  (Enter — отправить, Esc / ✕ — отмена), стиль станции.
-- ============================================================
function P11.StringRequest(title, label, default, onOk)
    if IsValid(P11.StrReq) then P11.StrReq:Remove() end

    local f = vgui.Create("DFrame")
    P11.StrReq = f
    f:SetSize(452, 158)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(false)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f:MoveToFront()
    f.OnRemove = function() if P11.StrReq == f then P11.StrReq = nil end end
    f.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 36, CC.panel, true, true, false, false)
        surface.SetDrawColor(CC.cyan.r, CC.cyan.g, CC.cyan.b, 140)
        surface.DrawRect(0, 36, w, 1)
        surface.SetDrawColor(150, 215, 245, 90)
        surface.DrawRect(0, 0, 26, 2)
        surface.DrawRect(0, 0, 2, 26)
        draw.SimpleText(title or "ВВОД", "P11.CM.Text", 14, 18, CC.cyan, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(label or "", "P11.CM.Small", 14, 52, CC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(452 - 34, 7) xb:SetSize(24, 22)
    xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 40, 36) or Color(60, 30, 28))
        draw.SimpleText("✕", "P11.CM.Small", w / 2, h / 2 - 1, Color(240, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() surface.PlaySound("buttons/button10.wav") f:Remove() end

    local entry = vgui.Create("DTextEntry", f)
    entry:SetPos(14, 66) entry:SetSize(424, 30)
    entry:SetFont("P11.CM.Text")
    entry:SetTextColor(CC.text)
    entry:SetCursorColor(CC.cyan)
    entry:SetText(default or "")
    entry:SetMaxLength(60)
    entry.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(6, 10, 15, 255))
        surface.SetDrawColor(CC.cyan.r, CC.cyan.g, CC.cyan.b, s:HasFocus() and 170 or 60)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(CC.text, CC.cyan, CC.text)
    end
    timer.Simple(0, function()
        if IsValid(entry) then entry:RequestFocus() end
    end)

    local function Submit()
        if not IsValid(f) then return end
        local txt = string.Trim(entry:GetValue() or "")
        f:Remove()
        surface.PlaySound("buttons/button15.wav")
        if onOk then onOk(txt) end
    end
    entry.OnEnter = Submit
    entry.OnLoseFocus = function(s) timer.Simple(0, function() if IsValid(s) then s:RequestFocus() end end) end -- v4.8.2: фокус не отдаём, пока окно живо

    local function SBtn(x, w, name, col, fn)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, 110) b:SetSize(w, 34)
        b:SetText("")
        b.Paint = function(s, ww, hh)
            draw.RoundedBox(6, 0, 0, ww, hh, s:IsHovered() and Color(col.r, col.g, col.b, 70) or Color(col.r, col.g, col.b, 34))
            surface.SetDrawColor(col.r, col.g, col.b, 150)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            draw.SimpleText(name, "P11.CM.Text", ww / 2, hh / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = fn
        return b
    end
    SBtn(14, 208, "ОТПРАВИТЬ ➜", CC.ok, Submit)
    SBtn(230, 208, "ОТМЕНА (Esc)", CC.bad, function()
        surface.PlaySound("buttons/button10.wav")
        f:Remove()
    end)

    -- Esc закрывает даже из-под фокуса поля ввода
    entry.OnKeyCodeTyped = function(s, code)
        if code == KEY_ESCAPE then f:Remove() return true end
    end
    f.OnKeyCodePressed = function(s, code)
        if code == KEY_ESCAPE then f:Remove() end
    end
    return f
end

-- ============================================================
--  v4.8.3: ТАБЕЛЬ О РАНГАХ — инструкция админам «какие права»
--  Все 16 рангов проекта + что открывает каждый (строки из
--  P11FW.RankRightsInfo — одна матрица правды с сервером).
-- ============================================================
function P11.OpenRankTable()
    if IsValid(P11.RankTbl) then P11.RankTbl:Remove() end
    local me = LocalPlayer()

    local f = vgui.Create("DFrame")
    P11.RankTbl = f
    f:SetSize(560, 580)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.OnRemove = function() if P11.RankTbl == f then P11.RankTbl = nil end end

    f.Paint = function(s, w, h)
        if P11.DrawDim then P11.DrawDim(s, 140) end
        draw.RoundedBox(10, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 66, CC.panel, true, true, false, false)
        draw.RoundedBoxEx(10, 0, 0, w, 3, Color(205, 60, 52, 235), true, true, false, false) -- v5.0.0: красное знамя
        surface.SetDrawColor(CC.gold.r, CC.gold.g, CC.gold.b, 150)
        surface.DrawRect(0, 66, w, 1)
        draw.SimpleText("📜 ТАБЕЛЬ О РАНГАХ ПРОЕКТА", "P11.CM.Text", 14, 20, CC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- мой ранг — крупно
        local rk = P11FW.GetRank and P11FW.GetRank(me) or nil
        local myName = rk and (rk.name .. "  •  ур. " .. (rk.level or 0)) or "User • ур. 0"
        local myCol = rk and rk.color or CC.dim
        draw.SimpleText("ТВОЙ РАНГ: " .. myName, "P11.CM.Small", 14, 44, myCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("что открывает каждый ранг — от юзера до Главы", "P11.CM.Small", w - 14, 20, CC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(560 - 34, 8) xb:SetSize(24, 22)
    xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 40, 36) or Color(60, 30, 28))
        draw.SimpleText("✕", "P11.CM.Small", w / 2, h / 2 - 1, Color(240, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() surface.PlaySound("buttons/button10.wav") f:Remove() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 76) sc:SetSize(536, 456)
    local sb = sc:GetVBar()
    sb:SetWide(5)
    sb.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 18)) end
    sb.btnGrip.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, CC.gold) end

    local myRank = P11FW.GetRank and P11FW.GetRank(me) or nil
    local myId = myRank and myRank.id or "user"

    -- ранги сверху вниз (от Главы к юзеру), чтобы власть читалась сразу
    local ranks = {}
    for _, r in ipairs(P11FW.Ranks or {}) do ranks[#ranks + 1] = r end
    table.sort(ranks, function(a, b) return (a.level or 0) > (b.level or 0) end)

    for _, r in ipairs(ranks) do
        local rights = (P11FW.RankRightsInfo and P11FW.RankRightsInfo(r)) or {}
        local cardH = 34 + 16 * #rights + 10
        local mine = (r.id == myId)

        local card = sc:Add("DPanel")
        card:Dock(TOP) card:DockMargin(2, 2, 6, 5)
        card:SetTall(cardH)
        card.R, card.CR, card.Mine, card.Rights = r, r.color or CC.dim, mine, rights
        card.Paint = function(s2, w, h)
            local col = s2.CR
            draw.RoundedBox(8, 0, 0, w, h, s2.Mine and Color(30, 36, 50, 255) or Color(15, 20, 28, 255))
            surface.SetDrawColor(col.r, col.g, col.b, s2.Mine and 220 or 120)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.RoundedBoxEx(8, 0, 0, 4, h, col, true, false, true, false)
            local nm = s2.R.name .. (s2.Mine and "   ◀ ЭТО ТЫ" or "")
            draw.SimpleText(nm, "P11.CM.Text", 12, 15, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ур. " .. (s2.R.level or 0) .. (s2.R.wl and "  🔒" or ""), "P11.CM.Small", w - 10, 15, CC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            for i, line in ipairs(s2.Rights) do
                draw.SimpleText("• " .. line, "P11.CM.Small", 12, 28 + (i - 1) * 16, Color(205, 214, 224), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end

    local foot = vgui.Create("DLabel", f)
    foot:SetPos(14, 540) foot:SetSize(532, 32)
    foot:SetFont("P11.CM.Small") foot:SetTextColor(CC.dim)
    foot:SetAutoStretchVertical(true)
    foot:SetText("Шпаргалка админа: !пульт — пульт Нечто • /menu /ранги — панели • /tp /goto /bring /return — ходьба • " ..
        "!розыск ник / !приказ текст — командование • /репорты — жалобы • ранг выдать: вкладка АДМИНКИ или p11_rank ник id • вход Главы: p11_access <секретное слово>")

    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end
    if P11.AnimateIn then P11.AnimateIn(f) end
    return f
end

-- ============================================================
--  v4.30.0 «КОМАНДОР»: ПЯТЁРКА БЫСТРЫХ КОМАНД СТАФФА
--  Выбор бойца списком (не прицелом — так не промахнёшься) и
--  отправка штатных актов 25/29/28/17/16 (варн/бан/кик/тп/притащить).
-- ============================================================

-- выбрать бойца из списка (себя в списке нет — все пять команд про других)
function P11.QuickPickPlayers(title, onPick)
    if IsValid(P11.QPick) then P11.QPick:Remove() end
    local me = LocalPlayer()

    local f = vgui.Create("DFrame")
    P11.QPick = f
    f:SetSize(340, 420)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(false)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.OnRemove = function() if P11.QPick == f then P11.QPick = nil end end
    f.Paint = function(s2, w, h)
        if P11.DrawDim then P11.DrawDim(s2, 120) end
        draw.RoundedBox(8, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 36, CC.panel, true, true, false, false)
        surface.SetDrawColor(CC.gold.r, CC.gold.g, CC.gold.b, 140)
        surface.DrawRect(0, 36, w, 1)
        draw.SimpleText(title or "ВЫБОР БОЙЦА", "P11.CM.Text", 14, 18, CC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(340 - 34, 7) xb:SetSize(24, 22)
    xb:SetText("")
    xb.Paint = function(s2, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s2:IsHovered() and Color(120, 40, 36) or Color(60, 30, 28))
        draw.SimpleText("✕", "P11.CM.Small", w / 2, h / 2 - 1, Color(240, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() surface.PlaySound("buttons/button10.wav") f:Remove() end

    local list = {}
    for _, p in ipairs(player.GetAll()) do
        if p ~= me then list[#list + 1] = p end
    end
    table.sort(list, function(a, b)
        return string.lower(a:Nick()) < string.lower(b:Nick())
    end)

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(8, 44) sc:SetSize(324, 368)
    local sb = sc:GetVBar()
    sb:SetWide(5)
    sb.Paint = function(s2, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 18)) end
    sb.btnGrip.Paint = function(s2, w, h) draw.RoundedBox(2, 0, 0, w, h, CC.gold) end

    if #list == 0 then
        local none = sc:Add("DLabel")
        none:Dock(TOP) none:DockMargin(6, 10, 6, 0)
        none:SetFont("P11.CM.Small") none:SetTextColor(CC.dim)
        none:SetText("Кроме тебя на станции никого.")
        return f
    end

    for _, p in ipairs(list) do
        local row = sc:Add("DButton")
        row:Dock(TOP) row:DockMargin(2, 2, 6, 3)
        row:SetTall(38)
        row:SetText("")
        row.PTarget = p
        row.Paint = function(s2, w, h)
            local ply = s2.PTarget
            if not IsValid(ply) then
                draw.RoundedBox(6, 0, 0, w, h, Color(40, 24, 24, 255))
                draw.SimpleText("вышел со станции", "P11.CM.Small", 10, h / 2, CC.bad, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                return
            end
            local hov = s2:IsHovered()
            draw.RoundedBox(6, 0, 0, w, h, hov and Color(255, 255, 255, 20) or CC.panel)
            draw.SimpleText(ply:Nick(), "P11.CM.Text", 10, h / 2, CC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local jn = P11FW.GetJobName and P11FW.GetJobName(ply) or ""
            draw.SimpleText(jn, "P11.CM.Small", w - 8, h / 2, CC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            if hov then
                surface.SetDrawColor(CC.gold.r, CC.gold.g, CC.gold.b, 150)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                s2:SetCursor("hand")
            end
        end
        row.DoClick = function(s2)
            local ply = s2.PTarget
            if not IsValid(ply) then surface.PlaySound("buttons/button10.wav") return end
            surface.PlaySound("buttons/button9.wav")
            f:Remove()
            onPick(ply)
        end
    end

    f.OnKeyCodePressed = function(s2, key)
        if key == KEY_ESCAPE then f:Remove() end
    end
    return f
end

-- отправка акта в штатный приёмник P11FW_AdminAction (тот же, что у админки)
local function QAct(act, writer)
    net.Start("P11FW_AdminAction")
        net.WriteUInt(act, 6)
        if writer then writer() end
    net.SendToServer()
end

local function QuickBan()
    P11.CloseCMenu()
    P11.QuickPickPlayers("■ БАН — КОГО?", function(p)
        if not IsValid(p) then return end
        P11.StringRequest("■ БАН: " .. p:Nick(),
            "Срок в МИНУТАХ (0 = навсегда; лимит твоего ранга урежет сам).", "30", function(mtxt)
                local mins = tonumber(string.match(mtxt or "", "%d+"))
                if not mins then surface.PlaySound("buttons/button10.wav") return end
                mins = math.min(mins, 525600)
                P11.StringRequest("■ БАН: " .. p:Nick(),
                    "Причина бана (видит журнал модерации). Срок: " .. mins .. " мин.", "", function(txt)
                        txt = string.Trim(txt or "")
                        if txt == "" then return end
                        if not IsValid(p) then surface.PlaySound("buttons/button10.wav") return end
                        QAct(29, function()
                            net.WriteUInt(p:EntIndex(), 8)
                            net.WriteUInt(mins, 20)
                            net.WriteString(txt)
                        end)
                    end)
            end)
    end)
end

local function QuickWarn()
    P11.CloseCMenu()
    P11.QuickPickPlayers("▲ ВАРН — КОМУ?", function(p)
        if not IsValid(p) then return end
        P11.StringRequest("▲ ВАРН: " .. p:Nick(),
            "Причина предупреждения (3-й варн = автокик).", "", function(txt)
                txt = string.Trim(txt or "")
                if txt == "" then return end
                if not IsValid(p) then surface.PlaySound("buttons/button10.wav") return end
                QAct(25, function()
                    net.WriteUInt(p:EntIndex(), 8)
                    net.WriteString(txt)
                end)
            end)
    end)
end

local function QuickKick()
    P11.CloseCMenu()
    P11.QuickPickPlayers("● КИК — КОГО?", function(p)
        if not IsValid(p) then return end
        P11.StringRequest("● КИК: " .. p:Nick(),
            "Причина кика (видна кикнутому и в журнале).", "", function(txt)
                txt = string.Trim(txt or "")
                if txt == "" then return end
                if not IsValid(p) then surface.PlaySound("buttons/button10.wav") return end
                QAct(28, function()
                    net.WriteUInt(p:EntIndex(), 8)
                    net.WriteString(txt)
                end)
            end)
    end)
end

local function QuickGoto()
    P11.CloseCMenu()
    P11.QuickPickPlayers("► ТЕЛЕПОРТ — К КОМУ?", function(p)
        if not IsValid(p) then return end
        QAct(17, function() net.WriteUInt(p:EntIndex(), 8) end)
    end)
end

local function QuickBring()
    P11.CloseCMenu()
    P11.QuickPickPlayers("◄ ПРИТАЩИТЬ — КОГО?", function(p)
        if not IsValid(p) then return end
        QAct(16, function() net.WriteUInt(p:EntIndex(), 8) end)
    end)
end

-- ============================================================
--  ПАНЕЛЬ C-МЕНЮ
-- ============================================================

function P11.OpenCMenu()
    if IsValid(P11.CMenu) then P11.CMenu:Remove() end

    local me = LocalPlayer()
    local isAdmin = P11FW.Config and P11FW.Config.Admin(me)
    local canWl = (not isAdmin) and P11FW.CanWhitelist and P11FW.CanWhitelist(me)
    -- v4.30.0 «КОМАНДОР»: стаффу (Хелпер+, ранг 2+) меню ВЫШЕ — полоса быстрых команд
    local isStaff = (P11FW.GetRankLevel and P11FW.GetRankLevel(me) or 0) >= 2

    local f = vgui.Create("DPanel")
    P11.CMenu = f
    f.T0 = SysTime()
    f.PStaff = isStaff
    f:SetSize(math.min(780, ScrW() - 40), math.min(isStaff and 678 or 600, ScrH() - 40)) -- v4.30.0: расширено для стаффа
    f:Center()
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    P11.AnimateIn(f)

    f.Paint = function(s, w, h)
        P11.DrawDim(s, 165)                                        -- затемнение экрана
        surface.SetAlphaMultiplier(0.25 + 0.75 * TweenK(s))        -- проявление тела
        Derma_DrawBackgroundBlur(s, s.T0 or 0)
        draw.RoundedBox(10, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 52, CC.panel, true, true, false, false)
        draw.RoundedBoxEx(10, 0, 0, w, 20, Color(255, 255, 255, 5), true, true, false, false)
        -- v4.26.0 «СИЯНИЕ»: эмблема пульта + живая шапка
        local ex, ey = 26, 26
        surface.DrawCircle(ex, ey, 15, CC.cyan.r, CC.cyan.g, CC.cyan.b, 145)
        local ra = CurTime() * 1.7
        surface.SetDrawColor(CC.cyan.r, CC.cyan.g, CC.cyan.b, 100)
        surface.DrawLine(ex, ey, ex + math.cos(ra) * 14, ey + math.sin(ra) * 14)
        CMStar(ex, ey, 6.5, CC.gold)
        draw.SimpleText("ПУЛЬТ СМЕНЫ", "P11.CM.Title", 52, 12, CC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local rk = P11FW.GetRankName and P11FW.GetRankName(me) or "User"
        local jn = P11FW.GetJobName and P11FW.GetJobName(me) or ""
        draw.SimpleText(me:Nick() .. (jn ~= "" and (" · " .. jn) or "") .. " · " .. rk,
            "P11.CM.Small", 52, 39, CC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        -- кошелёк бойца
        local mt = me:GetNWInt("P11_Money", 0) .. " ₽"
        surface.SetFont("P11.CM.Text")
        local mw = surface.GetTextSize(mt) + 22
        draw.RoundedBox(13, w - mw - 12, 9, mw, 26, Color(CC.gold.r, CC.gold.g, CC.gold.b, 26))
        surface.SetDrawColor(CC.gold.r, CC.gold.g, CC.gold.b, 130)
        surface.DrawOutlinedRect(w - mw - 12, 9, mw, 26, 1)
        draw.SimpleText(mt, "P11.CM.Text", w - mw / 2 - 12, 22, CC.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("удерживай C • ESC — закрыть • F6 — поддержка",
            "P11.CM.Small", w - 14, 44, CC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(CC.cyan)
        surface.DrawRect(0, 52, w, 2)
        -- секции-панели под колонками кнопок
        draw.RoundedBox(8, 8, 78, 504, 366, Color(255, 255, 255, 5))
        draw.RoundedBox(8, 526, 78, 240, 366, Color(255, 255, 255, 5))
        if s.PStaff then -- v4.30.0 «КОМАНДОР»: подложка полосы быстрых команд
            draw.RoundedBox(8, 8, 556, 764, 84, Color(255, 255, 255, 5))
            surface.SetDrawColor(CC.bad.r, CC.bad.g, CC.bad.b, 60)
            surface.DrawOutlinedRect(8, 556, 764, 84, 1)
        end
        surface.SetAlphaMultiplier(1)
    end

    -- ---- левая колонка: ЖЕСТЫ ----
    local gl = vgui.Create("DLabel", f)
    gl:SetPos(14, 62) gl:SetSize(500, 18)
    gl:SetFont("P11.CM.Small") gl:SetTextColor(CC.cyan)
    gl:SetText("ЖЕСТЫ (видят все вокруг):")

    for i, em in ipairs(EMOTES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        CButton(f, 14 + col * 252, 84 + row * 56, 246, 48,
            em.glyph .. "  " .. em.name, em.desc, CC.text, function()
                net.Start("P11_Emote")
                    net.WriteUInt(em.id, 4)
                net.SendToServer()
            end)
    end

    -- анкета бойца (позывной + описание)
    CButton(f, 14, 312, 498, 48, "🪪 Мой персонаж", "позывной и описание внешности", CC.cyan, function()
        P11.CloseCMenu()
        if P11.OpenCharUI then P11.OpenCharUI() end
    end)

    -- v4.6.9: экономика станции — ларёк (запасной путь, E не нужен)
    CButton(f, 14, 368, 246, 48, "🏪 Ларёк рядом", "витрина снабжения у торговца", CC.gold, function()
        P11.CloseCMenu()
        net.Start("P11_ShopTry")
        net.SendToServer()
    end)
    -- v4.6.9: торговля лицом к лицу
    CButton(f, 266, 368, 246, 48, "🤝 Обмен", "торговля с тем, кто рядом", CC.ok, function()
        P11.CloseCMenu()
        if P11.OpenTradePicker then P11.OpenTradePicker() end
    end)

    -- ---- правая колонка: БЫСТРОЕ ----
    local rl = vgui.Create("DLabel", f)
    rl:SetPos(532, 62) rl:SetSize(234, 18)
    rl:SetFont("P11.CM.Small") rl:SetTextColor(CC.cyan)
    rl:SetText("БЫСТРОЕ:")

    CButton(f, 532, 84, 234, 48, "📋 Должности", "меню F4", CC.ok, function()
        P11.CloseCMenu()
        P11FW.OpenJobMenu()
    end)

    CButton(f, 532, 140, 234, 48, "❓ Справка", "памятка новичка F1", CC.text, function()
        P11.CloseCMenu()
        RunConsoleCommand("p11_help")
    end)

    CButton(f, 532, 196, 234, 48, "🎲 Кубик 1-100", "кто идёт в тёмный коридор", CC.gold, function()
        LocalPlayer():ConCommand("say !ролл")
    end)

    CButton(f, 532, 252, 234, 48, "💈 Пустые руки", "знак мира", CC.text, function()
        RunConsoleCommand("use", "weapon_polus11_hands")
    end)

    CButton(f, 532, 308, 234, 48, "🧍 Меню моделей", "браузер внешности", CC.gold, function()
        P11.CloseCMenu()
        if P11.OpenModelMenu then P11.OpenModelMenu() end
    end)

    -- служебная секция: админам — админка; рангам вайтлиста — вайтлист
    if isAdmin then
        local al = vgui.Create("DLabel", f)
        al:SetPos(532, 372) al:SetSize(234, 18)
        al:SetFont("P11.CM.Small") al:SetTextColor(CC.bad)
        al:SetText("АДМИНИСТРАЦИИ:")

        CButton(f, 532, 390, 114, 48, "🛡 Админка", "то же, что /menu", CC.bad, function()
            P11.CloseCMenu()
            P11FW.OpenAdminMenu()
        end)
        -- v4.8.3: инструкция по правам — табель о рангах
        CButton(f, 652, 390, 114, 48, "📜 Табель", "кто что может", CC.gold, function()
            P11.CloseCMenu()
            P11.OpenRankTable()
        end)
    elseif canWl then
        local wl = vgui.Create("DLabel", f)
        wl:SetPos(532, 372) wl:SetSize(234, 18)
        wl:SetFont("P11.CM.Small") wl:SetTextColor(CC.gold)
        wl:SetText("ОФИЦЕРУ ФРАКЦИИ:")

        CButton(f, 532, 390, 234, 48, "🔒 Вайтлист", "допуски должностей", CC.gold, function()
            P11.CloseCMenu()
            P11FW.OpenAdminMenu("whitelist")
        end)
    end

    -- заявка грузчику + багаж + админская постановка объектов
    -- v4.12.2 «ЭФИР»: GPS-прибор станции — наводка к точке из C-меню (маяки больше не висят в мире сами)
    CButton(f, 14, 452, 364, 46, "🧭 GPS-КУРС", "к точке станции: ларёк/сейф/верстак — один маяк до цели", CC.cyan, function()
        P11.CloseCMenu()
        if P11POI and P11POI.GpsOpen then P11POI.GpsOpen() end
    end)
    CButton(f, 390, 452, 130, 46, "📦 Грузчик", "заявка снабжения", CC.gold, function()
        P11.CloseCMenu()
        P11.StringRequest("📦 ЗАЯВКА СНАБЖЕНИЯ", "Что притащить и зачем? Видят ВСЕ грузчики (максимум 60 знаков).",
            "", function(txt)
                net.Start("P11_PorterReq")
                    net.WriteString(txt or "")
                net.SendToServer()
            end)
    end)
    CButton(f, 532, 452, 106, 46, "🎒 Багаж", "инвентарь", CC.gold, function()
        P11.CloseCMenu()
        if P11.OpenInventory then P11.OpenInventory() end
    end)
    if isAdmin then
        CButton(f, 650, 452, 116, 46, "📍 Поставить", "генератор/ларёк", CC.gold, function()
            P11.CloseCMenu()
            if P11.OpenPlaceMenu then P11.OpenPlaceMenu() end
        end)
    end

    -- v4.21.0 «ДРЕВО» + v4.24.0 «РУБЕЖ»: полоса пополам — ДРЕВО и ОПЕРАЦИИ
    CButton(f, 14, 504, 370, 46, "⭐ ДРЕВО СЛУЖБЫ",
        "уровень за дела смены · РККА и Учёные по 3 пути · откат за 100 000₽ сохраняет опыт",
        CC.ok, function()
            P11.CloseCMenu()
            if P11.OpenSkillTree then P11.OpenSkillTree() end
        end, true) -- v4.26.0: баннер-режим
    CButton(f, 396, 504, 370, 46, "⚔ ОПЕРАЦИИ",
        "админ-ивент: СССР vs АМЕРИКА · бой за точки 30 мин · лидерборд · 5000₽/1000₽",
        CC.gold, function()
            P11.CloseCMenu()
            if P11.OpenOps then P11.OpenOps() end
        end, true) -- v4.26.0: баннер-режим

    -- v4.30.0 «КОМАНДОР»: ПЯТЁРКА БЫСТРЫХ КОМАНД (Хелпер+).
    -- Клик → список бойцов → причина/срок → пакет админки. Без прав — серая.
    if isStaff then
        local qlab = vgui.Create("DLabel", f)
        qlab:SetPos(14, 560) qlab:SetSize(748, 16)
        qlab:SetFont("P11.CM.Small") qlab:SetTextColor(CC.bad)
        qlab:SetText("⚡ БЫСТРЫЕ КОМАНДЫ: варн — Хелпер+ • кик/тп — Модератор+ (v4.30.1) • бан — Админ+ (те же, что /warn /ban /kick /tp /bring)")

        local function QBtn(x, name, desc, col, perm, fn)
            local b = CButton(f, x, 580, 146, 48, name, desc, col, fn)
            if perm and not (P11FW.CanMod and P11FW.CanMod(me, perm)) then
                b:SetEnabled(false)
                b.PCol = CC.dim
                b.PDesc = "нужен ранг выше"
            end
            return b
        end
        QBtn(9,   "▲ Варн",   "предупреждение",  CC.gold,             "warn",  QuickWarn)
        QBtn(163, "■ Бан",    "срок / навсегда", CC.bad,              "ban",   QuickBan)
        QBtn(317, "● Кик",    "выкинуть",        Color(240, 105, 95), "kick",  QuickKick)
        QBtn(471, "► К нему", "телепорт к нему", CC.cyan,             "heal",  QuickGoto)
        QBtn(625, "◄ К себе", "притащить",       CC.cyan,             "heal",  QuickBring)
    end

    -- низ: подсказка
    local foot = vgui.Create("DLabel", f)
    foot:SetPos(14, isStaff and 646 or 556) foot:SetSize(748, 20)
    foot:SetFont("P11.CM.Small") foot:SetTextColor(CC.dim)
    local rk = P11FW.GetRankName and P11FW.GetRankName(me) or "User"
    foot:SetText("Ты — " .. rk .. " • F6 — поддержка станции • документы и пустые руки уже в снаряжении • C закроет это меню")

    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end
    f.OpenedAt = CurTime()
end

-- ============================================================
--  ЕДИНЫЙ МЕНЕДЖЕР ВВОДА (v4.4.0)
--  Одна точка правды: CanOpen / TryOpen / Toggle. Все каналы —
--  только адаптеры к ней. Закрытие по отпусканию C — здесь же.
-- ============================================================

local function IntroBlocks()
    return P11.IntroOpen == true
end

local function TypingBlocks(me)
    if not IsValid(me) then return true end
    if vgui.GetKeyboardFocus() ~= nil then return true end -- чат/ввод/консоль
    if me.IsTyping and me:IsTyping() then return true end
    return false
end

-- открыть (с защитами). true = меню появилось
function P11.TryOpenCMenu()
    if IntroBlocks() then return false end
    local me = LocalPlayer()
    if TypingBlocks(me) then return false end
    if IsValid(P11.CMenu) then return true end -- уже открыто
    local ok, err = pcall(P11.OpenCMenu)
    if not ok then
        -- один лог вместо краша кадра
        if not P11.CMenuErrLogged then
            P11.CMenuErrLogged = true
            print("[POLUS][ERROR] С-меню: " .. tostring(err))
        end
        return false
    end
    return true
end

function P11.ToggleCMenu()
    if IsValid(P11.CMenu) then
        P11.CloseCMenu()
    else
        P11.TryOpenCMenu()
    end
end

-- ---- 1) ГЛАВНЫЙ КАНАЛ: детектор фронта KEY_C в Think. ----
--    Не зависит от того, доехал ли +menu_context до движка:
--    спрашиваем клавишу напрямую у input каждый кадр.
local cDownLast = false
hook.Add("Think", "P11.CMenuInput", function()
    local down = input.IsKeyDown(KEY_C)

    -- фронт нажатия → открыть
    if down and not cDownLast then
        if not IsValid(P11.CMenu) then
            P11.TryOpenCMenu()
        end
    end

    -- отпустил C → закрыть (с короткой передержкой, чтобы не
    -- захлопнуться из-за микро-просадки опроса)
    if not down and cDownLast then
        if IsValid(P11.CMenu) and CurTime() - (P11.CMenu.OpenedAt or 0) > 0.35 then
            P11.CloseCMenu()
        end
    end

    cDownLast = down
end)

-- ---- 2) адаптер: прямой перехват бинда (приходит раньше Think
--    на части клиентов). return true глушит ванильное контекстное меню.
hook.Add("PlayerBindPress", "P11.CMenuInput", function(ply, bind, pressed)
    if not pressed then return end
    if not string.find(bind, "+menu_context") then return end
    if IntroBlocks() then return true end
    P11.TryOpenCMenu() -- НЕ toggle: Think-канал мог открыть наносекундой раньше
    return true
end)

-- ---- 3) адаптер: гейммод-хуки песочницы (нужны, чтобы движок не
--    рисовал своё контекстное меню поверх — оно подавлено return true
--    в бинде, но держим и этот шлюз для модов, зовущих хук напрямую).
function GAMEMODE:OnContextMenuOpen()
    if not IntroBlocks() then
        P11.TryOpenCMenu()
    end
end

function GAMEMODE:OnContextMenuClose()
    if IsValid(P11.CMenu) and CurTime() - (P11.CMenu.OpenedAt or 0) > 0.35 then
        P11.CloseCMenu()
    end
end

-- ---- 4) адаптеры: консольная команда и чат ----
concommand.Add("p11_cmenu", function()
    P11.ToggleCMenu()
end)

hook.Add("OnPlayerChat", "P11.CMenuChat", function(ply, text)
    if ply ~= LocalPlayer() then return end
    local t = string.lower(string.Trim(text or ""))
    if t == "!меню" or t == "/меню" or t == "!menu" then
        P11.ToggleCMenu()
        return true
    end
end)

print("[POLUS-11] С-меню v5.1 «КОМАНДОР» загружено (клавиша C • p11_cmenu • !меню • пятёрка быстрых команд стаффа v4.30.0)")
