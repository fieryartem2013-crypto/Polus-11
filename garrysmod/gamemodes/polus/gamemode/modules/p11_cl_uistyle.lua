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

surface.CreateFont("P11UI.H1",  { font = "Roboto", size = 24, weight = 900, extended = true })
surface.CreateFont("P11UI.H2",  { font = "Roboto", size = 17, weight = 800, extended = true })
surface.CreateFont("P11UI.Sub", { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11UI.Tx",  { font = "Roboto", size = 14, weight = 500, extended = true })

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
