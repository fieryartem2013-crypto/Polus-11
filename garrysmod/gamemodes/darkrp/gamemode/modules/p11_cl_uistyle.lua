-- ============================================================
--  ПОЛЮС-11 — СТИЛЬ СТАНЦИИ (client) v4.1
--  Единая палитра и конструктор окон для UI сборки.
--  Используют: справка, миниигры; постепенно — все окна.
-- ============================================================

P11UI = P11UI or {}

P11UI.C = {
    bg       = Color(10, 14, 20, 245),
    panel    = Color(20, 26, 36, 255),
    panel2   = Color(27, 34, 47, 255),
    line     = Color(70, 120, 170, 180),
    accent   = Color(120, 185, 255),  -- арктическая синева
    gold     = Color(255, 205, 100),  -- станционная медь
    text     = Color(232, 236, 244),
    dim      = Color(148, 156, 172),
    ok       = Color(110, 215, 140),
    bad      = Color(240, 100, 90),
    science  = Color(170, 220, 255),
    patrol   = Color(140, 200, 255),
}

-- v4.6.2: весь фирменный UI крупнее (заявка владельца: мелкий текст налезал)
surface.CreateFont("P11UI.H1",  { font = "Roboto", size = 27, weight = 900, extended = true })
surface.CreateFont("P11UI.H2",  { font = "Roboto", size = 19, weight = 800, extended = true })
surface.CreateFont("P11UI.Sub", { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("P11UI.Tx",  { font = "Roboto", size = 16, weight = 500, extended = true })

-- единое окно сборки: blur-фон, хедер с акцентом, версия, крестик
function P11UI.Frame(title, subtitle, w, h, accent)
    local C = P11UI.C
    local acc = accent or C.accent

    local f = vgui.Create("DFrame")
    f:SetSize(w, h)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()

    f.Paint = function(s, ww, hh)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, ww, hh, C.bg)
        draw.RoundedBoxEx(10, 0, 0, ww, 54, C.panel, true, true, false, false)

        -- акцентная линия хедера + мягкий градиент вниз
        surface.SetDrawColor(acc)
        surface.DrawRect(0, 54, ww, 2)
        for i = 0, 6 do
            surface.SetDrawColor(acc.r, acc.g, acc.b, 26 - i * 3.5)
            surface.DrawRect(0, 56 + i, ww, 1)
        end

        draw.SimpleText(title, "P11UI.H1", 16, 12, acc)
        draw.SimpleText(subtitle or "", "P11UI.Sub", 17, 38, C.dim)
        draw.SimpleText("ПОЛЮС-11 · v" .. (POLUS_BUILD or "4.1"), "P11UI.Sub", ww - 40, 28,
            C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(w - 32, 14) x:SetSize(22, 22)
    x:SetText("")
    x.Paint = function(s, ww, hh)
        draw.SimpleText("✕", "P11UI.H2", ww / 2, hh / 2,
            s:IsHovered() and C.bad or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    x.DoClick = function() f:Remove() end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE or key == KEY_F1 then f:Remove() end
    end

    return f
end

-- секционный заголовок в скролле
function P11UI.Head(scroll, txt, accent)
    local C = P11UI.C
    local p = scroll:Add("DPanel")
    p:Dock(TOP) p:DockMargin(2, 12, 2, 0) p:SetTall(26)
    p.Paint = function(s, w, h)
        surface.SetDrawColor(accent or C.gold)
        surface.DrawRect(2, 4, 4, h - 8)
        draw.SimpleText(txt, "P11UI.H2", 12, h / 2, accent or C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return p
end

-- абзац текста
function P11UI.Body(scroll, txt, wide)
    local C = P11UI.C
    local l = scroll:Add("DLabel")
    l:Dock(TOP) l:DockMargin(12, 3, 8, 0)
    l:SetWide(wide or 590)
    l:SetFont("P11UI.Tx") l:SetTextColor(C.text)
    l:SetText(txt) l:SetAutoStretchVertical(true) l:SetWrap(true)
    return l
end

-- стилизованный скролл
function P11UI.Scroll(parent, x, y, w, h)
    local C = P11UI.C
    local s = vgui.Create("DScrollPanel", parent)
    s:SetPos(x, y) s:SetSize(w, h)
    local sb = s:GetVBar() sb:SetWide(5)
    sb.Paint = function(_, ww, hh) draw.RoundedBox(2, 0, 0, ww, hh, Color(255, 255, 255, 14)) end
    sb.btnGrip.Paint = function(_, ww, hh) draw.RoundedBox(2, 0, 0, ww, hh, C.accent) end
    return s
end

print("[POLUS-11] стиль станции (P11UI) загружен")

-- ============================================================
--  ЭМАЛЬ v2 (v4.25.0) — ГЛОБАЛЬНЫЙ РЕСКИН стоковых контролов.
--  Заявка: «обнови полностью весь UI на всём сервере, каждую
--  F4 и C-меню». Меню сборки собраны кастом-краской — они сами
--  по себе красивые, их не трогаем (краска инстанса сильнее
--  мета-эмали); всем ОСТАЛЬНЫМ (старые/дефолтные окна, кнопки,
--  поля, чеки, скроллы по всему серверу) едем единой эмалью:
--  тёмное окно + золотая кромка, поля — глубокая тьма, чек —
--  золото, скролл — золотой бегунок на тёмной колее.
-- ============================================================
timer.Simple(0, function() -- ждём регистрации стандартных контролов
    local C = P11UI.C

    -- ОКНА: эмаль + золотая кромка под шапкой
    local FR = vgui.GetControlTable and vgui.GetControlTable("DFrame")
    if FR and not FR.P11EnamelV2 then
        FR.P11EnamelV2 = true
        FR.Paint = function(self, w, h)
            draw.RoundedBox(10, 0, 0, w, h, C.bg)
            draw.RoundedBoxEx(10, 0, 0, w, 26, C.panel2, true, true, false, false)
            surface.SetDrawColor(C.line)
            surface.DrawRect(0, 26, w, 1)
            surface.SetDrawColor(C.gold.r, C.gold.g, C.gold.b, 90)
            surface.DrawRect(0, 27, w, 1)
            local ttl = (self.lblTitle and self.lblTitle.GetText) and self.lblTitle:GetText() or ""
            if ttl ~= "" then
                draw.SimpleText(ttl, "P11UI.Sub", 10, 5, C.text)
            end
        end
    end

    -- КНОПКИ: фирменная эмаль (шрифт/иконка владельца сохраняются)
    local BT = vgui.GetControlTable and vgui.GetControlTable("DButton")
    if BT and not BT.P11EnamelV2 then
        BT.P11EnamelV2 = true
        BT.Paint = function(self, w, h)
            local hv = self:IsHovered() and not self:GetDisabled()
            draw.RoundedBox(6, 0, 0, w, h, hv and C.panel2 or C.panel)
            surface.SetDrawColor(hv and C.gold or C.line)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if self.m_Material then
                surface.SetMaterial(self.m_Material)
                surface.SetDrawColor(255, 255, 255, 255)
                local sz = math.min(w, h) - 8
                surface.DrawTexturedRect((w - sz) / 2, (h - sz) / 2, sz, sz)
            end
            local txt = self:GetText()
            if txt and txt ~= "" then
                local fnt = self:GetFont()
                draw.SimpleText(txt, (fnt and fnt ~= "") and fnt or "P11UI.Sub",
                    w / 2, h / 2, self:GetDisabled() and C.dim or C.text,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return true
        end
    end

    -- ПОЛЯ ВВОДА: глубокая тьма + циан в фокусе
    local TE = vgui.GetControlTable and vgui.GetControlTable("DTextEntry")
    if TE and not TE.P11EnamelV2 then
        TE.P11EnamelV2 = true
        TE.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(12, 16, 22, 255))
            surface.SetDrawColor(self:HasFocus() and C.accent or C.line)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            pcall(function()
                self:DrawTextEntryText(
                    self.GetTextColor and self:GetTextColor() or C.text,
                    self.GetHighlightColor and self:GetHighlightColor() or C.accent,
                    self.GetCursorColor and self:GetCursorColor() or color_white)
            end)
        end
    end

    -- ЧЕКИ: золотая отметина
    local CK = vgui.GetControlTable and vgui.GetControlTable("DCheckBox")
    if CK and not CK.P11EnamelV2 then
        CK.P11EnamelV2 = true
        CK.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(12, 16, 22, 255))
            surface.SetDrawColor(self:GetChecked() and C.gold or C.line)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if self:GetChecked() then
                draw.SimpleText("✓", "P11UI.Sub", w / 2, h / 2, C.gold,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return true
        end
    end

    -- СКРОЛЛБАРЫ: тёмная колея + золотой бегунок
    -- (меню со своей краской бегунка перекрывают её своей — всё честно)
    local SB = vgui.GetControlTable and vgui.GetControlTable("DVScrollBar")
    if SB and not SB.P11EnamelV2 then
        SB.P11EnamelV2 = true
        SB.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 12))
            return true
        end
        local oldSetUp = SB.SetUp
        SB.SetUp = function(self, ...)
            local r = oldSetUp(self, ...)
            local g = self.btnGrip
            if IsValid(g) then
                g.Paint = function(s2, w, h)
                    draw.RoundedBox(4, 0, 0, w, h,
                        s2:IsHovered() and C.gold or Color(185, 150, 70))
                end
            end
            return r
        end
    end
end)

print("[POLUS-11] ЭМАЛЬ v2 (v4.25.0): глобальный рескин UI — окна/кнопки/поля/чеки/скроллы в фирме")
