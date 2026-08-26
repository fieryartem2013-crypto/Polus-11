-- ============================================================
--  ПОЛЮС-11 — BUGFIX v5.8.1 (КЛИЕНТ, энтити bugfix581)
--  1) КНОПКА «БАГАЖ» (и другие узкие кнопки С-меню): текст
--     сливался — имя/описание/стрелка не влезали в 106px.
--     Рескин: компактная ячейка-иконка + имя с обрезкой по
--     ширине (безопасно для UTF-8), описание — в тултип.
--  2) ОКНО ДОКУМЕНТА: «выдано/проверено» (слева) и «любая
--     проверка кода…» (справа) были на одной строке и НАЛЕЗАЛИ
--     друг на друга. Переопределяем net.Receive("P11_DocShow")
--     своей читаемой вёрсткой (строки разнесены, длинные
--     имя/должность обрезаются, печать не пересекает текст).
--  3) ПОДСКАЗКА РАЦИИ: если выбран канал «РАЦИЯ», а рация не
--     в руках — показываем, как её достать из багажа.
--
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
--  Старые файлы не трогаем.
-- ============================================================

if not P11 then P11 = {} end

-- ================== 2) ОКНО ДОКУМЕНТА (читаемое) ==================
-- (объявляем раньше, чтобы хук ре-регистрации ниже видел функцию)

surface.CreateFont("P11.BF.DocBig",   { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.BF.DocMid",   { font = "Roboto", size = 17, weight = 600, extended = true })
surface.CreateFont("P11.BF.DocSmall", { font = "Roboto", size = 13, weight = 400, extended = true })
surface.CreateFont("P11.BF.DocTiny",  { font = "Roboto", size = 11, weight = 500, extended = true })

-- обрезка по ширине (безопасно для UTF-8) — для мелких полей (счётчики)
local function TrimToWidth(text, font, maxw)
    text = text or ""
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxw then return text end
    local out = ""
    local i, n = 1, #text
    while i <= n do
        local b = string.byte(text, i)
        local len = 1
        if b >= 0xF0 then len = 4
        elseif b >= 0xE0 then len = 3
        elseif b >= 0xC0 then len = 2 end
        local ch = string.sub(text, i, i + len - 1)
        if surface.GetTextSize(out .. ch .. "…") > maxw then break end
        out = out .. ch
        i = i + len
    end
    if out == "" then out = string.sub(text, 1, math.max(1, math.floor(maxw / 8))) end
    return out .. "…"
end

-- v5.8.14: перенос ПО СЛОВАМ (до maxLines строк) — длинные имена/должности
-- (например «Командир Отряда „Красный Орёл“») показываются ЦЕЛИКОМ,
-- без обрезки. Возвращает массив строк.
local function WrapWords(text, font, maxw, maxLines)
    text = text or ""
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxw then return { text } end

    local words = {}
    for w in string.gmatch(text, "%S+") do
        words[#words + 1] = w
    end
    local lines, cur = {}, ""
    for _, w in ipairs(words) do
        local test = cur == "" and w or (cur .. " " .. w)
        if surface.GetTextSize(test) <= maxw or cur == "" then
            cur = test
        else
            lines[#lines + 1] = cur
            cur = w
            if #lines >= maxLines then break end
        end
    end
    if cur ~= "" and #lines < maxLines then
        lines[#lines + 1] = cur
    end
    return lines
end

-- нарисовать строки с переносом, вернуть конечный y
local function DrawWrapped(lines, font, x, y, col, lh)
    lh = lh or 19
    for _, ln in ipairs(lines) do
        draw.SimpleText(ln, font, x, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        y = y + lh
    end
    return y
end

local function DocHandler()
    local name = net.ReadString()
    local jobName = net.ReadString()
    local code = net.ReadString()
    local stamp = net.ReadString()
    local facName = net.ReadString()

    if IsValid(P11.BFDocFrame) then P11.BFDocFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11.BFDocFrame = f
    f.T0 = SysTime()
    f:SetSize(460, 372)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then s:Remove() end end

    -- код «П11-АБВГ-123» с дефисами (как в штатном)
    local function FormatCode(c)
        if string.find(c or "", "-", 1, true) then return c end
        local letters = string.match(c or "", "^(%D+)") or (c or "")
        local digits  = string.match(c or "", "(%d+)$") or ""
        return letters .. (digits ~= "" and ("-" .. digits) or "")
    end

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0 or 0)
        -- «картон» удостоверения
        draw.RoundedBox(8, 0, 0, w, h, Color(226, 214, 180, 255))
        draw.RoundedBox(8, 5, 5, w - 10, h - 10, Color(240, 230, 198, 255))
        -- шапка
        draw.RoundedBoxEx(6, 5, 5, w - 10, 46, Color(24, 30, 40, 255), true, true, false, false)
        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11.BF.DocBig", w / 2, 28,
            Color(220, 195, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("УДОСТОВЕРЕНИЕ ЛИЧНОСТИ", "P11.BF.DocTiny", w / 2, 60,
            Color(70, 60, 44), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local x = 24
        local maxw = w - 48
        local y = 82
        local col = Color(40, 36, 26)

        -- Имя (перенос по словам, до 2 строк)
        y = DrawWrapped(WrapWords("Имя: " .. (name or ""), "P11.BF.DocMid", maxw, 2),
            "P11.BF.DocMid", x, y, col, 19)
        -- Фракция крупно (перенос по словам)
        y = y + 4
        y = DrawWrapped(WrapWords(string.upper(facName or ""), "P11.BF.DocMid", maxw, 2),
            "P11.BF.DocMid", x, y, Color(90, 62, 30), 19)
        -- Должность (перенос по словам — «Орёл» виден целиком)
        y = y + 4
        y = DrawWrapped(WrapWords("Должность: " .. (jobName or ""), "P11.BF.DocSmall", maxw, 2),
            "P11.BF.DocSmall", x, y, col, 17)

        -- КОД — главное (после текста, не пересекает)
        local codeY = y + 8
        draw.RoundedBox(4, 24, codeY, w - 48, 40, Color(24, 30, 40, 255))
        draw.SimpleText("КОД: " .. FormatCode(code), "P11.BF.DocMid", w / 2, codeY + 20,
            Color(230, 220, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- выдача/проверка
        local lowY = codeY + 52
        draw.SimpleText("выдано/проверено: " .. TrimToWidth(stamp, "P11.BF.DocTiny", w - 110),
            "P11.BF.DocTiny", 24, lowY, Color(90, 80, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("проверка кода — через КАРАУЛЬНЫЙ ТЕРМИНАЛ",
            "P11.BF.DocTiny", w / 2, lowY + 22, Color(120, 105, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- печать — справа внизу, текст её не пересекает
        surface.SetDrawColor(70, 60, 40, 200)
        surface.DrawOutlinedRect(w - 96, h - 62, 70, 40, 3)
        draw.SimpleText("П-11", "P11.BF.DocMid", w - 61, h - 42, Color(70, 60, 40, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local xB = vgui.Create("DButton", f)
    xB:SetPos(460 - 34, 10) xB:SetSize(22, 22)
    xB:SetText("✕") xB:SetFont("P11.BF.DocSmall") xB:SetTextColor(Color(200, 180, 140))
    xB.Paint = function() end
    xB.DoClick = function() f:Remove() end

    timer.Simple(14, function() if IsValid(f) then f:Remove() end end)
end

-- регистрируем НЕСКОЛЬКО раз с задержкой: побеждает последний
-- (порядок загрузки с файлом оружия weapon_polus11_docs не гарантирован)
local function ReHookDoc()
    net.Receive("P11_DocShow", DocHandler)
end
ReHookDoc()
timer.Simple(1, ReHookDoc)
timer.Simple(3, ReHookDoc)
timer.Simple(6, ReHookDoc)

-- ================== 1) УЗКИЕ КНОПКИ С-МЕНЮ (БАГАЖ и др.) ==================

local function ReskinNarrow(b)
    if b.P11Narrow then return end
    b.P11Narrow = true

    local icon = b.PIcon or "•"
    local name = b.PName or ""
    local desc = b.PDesc or ""
    local col = b.PCol or Color(228, 236, 245)

    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered() and s:IsEnabled()
        local dis = not s:IsEnabled()

        draw.RoundedBox(6, 0, 0, ww, hh,
            hov and Color(32, 44, 62, 255) or (dis and Color(15, 19, 27, 210) or Color(20, 27, 39, 240)))
        -- ячейка-иконка
        draw.RoundedBox(6, 6, 5, 36, hh - 10, Color(col.r, col.g, col.b, hov and 66 or 38))
        draw.SimpleText(icon, "P11.CM.Mdl", 24, hh / 2,
            dis and Color(120, 130, 145) or Color(240, 248, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        -- имя компактно с обрезкой по ширине (UTF-8 безопасно)
        local tx = 50
        local avail = ww - tx - 4
        surface.SetFont("P11.CM.Small")
        local shown = name
        if surface.GetTextSize(shown) > avail then shown = TrimToWidth(shown, "P11.CM.Small", avail) end
        draw.SimpleText(shown, "P11.CM.Small", tx, hh / 2,
            dis and Color(120, 130, 145) or col,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if hov then
            surface.SetDrawColor(col.r, col.g, col.b, 150)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        end
    end
    b:SetTooltip(desc)
end

-- обход детей панели: перекрашиваем УЗКИЕ CButton (ширина < 150)
local function WalkNarrow(pnl)
    if not IsValid(pnl) then return end
    for _, ch in ipairs(pnl:GetChildren()) do
        if ch:GetClassName() == "DButton" and ch.PName and not ch.P11Narrow then
            local ww = ch:GetWide()
            if ww > 0 and ww < 150 then ReskinNarrow(ch) end
        end
        WalkNarrow(ch)
    end
end

hook.Add("Think", "P11.BF.Narrow", function()
    if IsValid(P11 and P11.CMenu) then WalkNarrow(P11.CMenu) end
end)

-- ================== 3) ПОДСКАЗКА РАЦИИ ==================
hook.Add("HUDPaint", "P11.BF.RadioHint", function()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if not (P11SEL and P11SEL.Cur == "radio") then return end
    if me:HasWeapon("weapon_polus11_radio") then return end
    if (chat and chat.IsChatInputActive and chat.IsChatInputActive()) == false then return end

    -- пульсация, чтобы не пропустили
    local a = 150 + math.sin(CurTime() * 3.2) * 70
    draw.SimpleText("⚠ РАЦИЯ НЕ В РУКАХ — сообщение в эфир не уйдёт!",
        "P11.HUD.Text", ScrW() / 2, ScrH() * 0.60, Color(255, 205, 110, a),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Достань: 🎒 Багаж → ИСПОЛЬЗОВАТЬ «Рация» (или купи у снабженца 1800₽)",
        "P11.HUD.Text", ScrW() / 2, ScrH() * 0.60 + 22, Color(200, 215, 230, 180),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

print("[POLUS-11] BUGFIX v5.8.1: кнопка «Багаж», документы, подсказка рации")
