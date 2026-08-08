-- ============================================================
--  ПОЛЮС-11 — ГАРАЖ «ПОЛЮС-АВТО»: окно-каталог (client)
--  v4.10.0 «ГАРАЖ». Открывается: E по Гараж-мастеру / !гараж /
--  клиентская команда p11_garage (рядом с торговцем).
--  Самостоятельное окно (без зависимостей от других UI-модулей).
-- ============================================================

surface.CreateFont("P11G.Title", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11G.Big",   { font = "Roboto", size = 19, weight = 700, extended = true })
surface.CreateFont("P11G.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11G.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

local C = {
    bg    = Color(10, 13, 18, 246),
    panel = Color(20, 26, 34, 255),
    card  = Color(27, 34, 44, 255),
    gold  = Color(255, 190, 90),
    text  = Color(230, 238, 246),
    dim   = Color(150, 162, 178),
    ok    = Color(140, 235, 150),
    red   = Color(255, 120, 110),
    line  = Color(90, 120, 150, 140),
}

P11G = P11G or { Frame = nil, Cat = {} }

local function CloseGarage()
    if IsValid(P11G.Frame) then P11G.Frame:Remove() P11G.Frame = nil end
end

local function Buy(id)
    net.Start("P11_GarageBuy")
        net.WriteString(id)
    net.SendToServer()
    surface.PlaySound("buttons/button15.wav")
end

local function OpenGarageWindow()
    CloseGarage()

    local me = LocalPlayer()
    -- v4.14.5 «ТИШИНА»: показываем то же, что HUD-чип (max двух каналов денег)
    local money = IsValid(me)
        and math.max((P11.Eco and tonumber(P11.Eco.money)) or 0, me:GetNWInt("P11_Money", 0)) or 0

    local W, H = 680, 170 + 96 * math.max(1, #P11G.Cat)
    if H > ScrH() - 80 then H = ScrH() - 80 end

    local f = vgui.Create("DFrame")
    P11G.Frame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    f.OnRemove = function() if P11G.Frame == f then P11G.Frame = nil end end
    f.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then f:Remove() end end

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 74, C.panel, true, true, false, false)
        surface.SetDrawColor(C.line) surface.DrawRect(0, 74, w, 1)
        draw.SimpleText("🚗 ГАРАЖ «ПОЛЮС-АВТО»", "P11G.Title", 18, 22, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("транспорт с конвейера — выдача на площадке у торговца", "P11G.Small", 18, 52, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.Comma(money) .. " ₽", "P11G.Big", w - 56, 38, C.ok, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local xb = vgui.Create("DButton", f)
    xb:SetPos(W - 40, 16) xb:SetSize(26, 24) xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 44, 40) or Color(50, 34, 32))
        draw.SimpleText("✕", "P11G.Small", w / 2, h / 2 - 1, Color(240, 210, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() f:Remove() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(14, 84) sc:SetSize(W - 28, H - 96)
    sc:GetVBar():SetWide(5)

    for _, it in ipairs(P11G.Cat) do
        local can = it.ok and it.skyok
        local card = sc:Add("DPanel")
        card:Dock(TOP) card:DockMargin(0, 0, 0, 8) card:SetTall(88)

        local b = vgui.Create("DButton", card)
        b:SetSize(150, 34) b:SetText("")
        b.DoClick = function()
            if not can then surface.PlaySound("buttons/button10.wav") return end
            Buy(it.id)
        end
        b.Paint = function(s, w, h)
            local a = can and (s:IsHovered() and 80 or 46) or 18
            draw.RoundedBox(7, 0, 0, w, h, Color(C.gold.r, C.gold.g, C.gold.b, a))
            surface.SetDrawColor(C.gold.r, C.gold.g, C.gold.b, can and 200 or 60)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local lbl = can and ("КУПИТЬ · " .. string.Comma(it.price) .. " ₽") or (not it.ok and "НЕТ ПАКА" or "НЕТ ДОПУСКА")
            draw.SimpleText(lbl, "P11G.Small", w / 2, h / 2, can and C.gold or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        card.PerformLayout = function(s, w, h)
            b:SetPos(w - 162, (h - 34) / 2)
        end
        card.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.card)
            draw.RoundedBoxEx(8, 0, 0, 5, h, can and C.gold or Color(80, 70, 60), true, false, true, false)
            draw.SimpleText(it.name, "P11G.Big", 16, 12, can and C.text or C.dim, TEXT_ALIGN_LEFT)
            draw.SimpleText(it.desc, "P11G.Small", 16, 38, C.dim, TEXT_ALIGN_LEFT)
            local note
            if not it.ok then
                note = "✖ пака LVS «" .. it.id .. "» нет на сервере — денег не возьмёт"
            elseif it.pilot and not it.skyok then
                note = "✈ допуск в небо: должность «Лётчик РККА» (F4) или ключ ФЛЮКСА из витрины F6"
            elseif it.pilot and it.fluxkey then
                note = "🔑 у тебя ключ ФЛЮКСА — бесплатный борт (разово)"
            elseif it.pilot then
                note = "✈ у тебя допуск в небо (лётчик)"
            end
            if note then
                draw.SimpleText(note, "P11G.Small", 16, 62,
                    it.ok and (it.skyok and C.ok or C.red) or C.red, TEXT_ALIGN_LEFT)
            end
        end
    end

    surface.PlaySound("ui/buttonclick.wav")
    return f
end

net.Receive("P11_GarageOpen", function()
    local cat = util.JSONToTable(net.ReadString() or "") or {}
    P11G.Cat = cat
    OpenGarageWindow()
end)

-- запасная команда: открыть гараж у ближайшего торговца (как p11_shop)
concommand.Add("p11_garage", function()
    net.Start("P11_GarageTry")
    net.SendToServer()
end)

print("[P11GARAGE] v4.10.0 OK — окно «ПОЛЮС-АВТО» (E по торговцу / !гараж / p11_garage рядом)")
