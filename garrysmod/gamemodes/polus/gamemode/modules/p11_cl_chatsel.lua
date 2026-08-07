-- ============================================================
--  ПОЛЮС-11 — ПЕРЕКЛЮЧАТЕЛЬ КАНАЛОВ ЧАТА (client) v4.9.2 «ПРИЁМ»
--  Заявка владельца: «готовый мод на чат — измени ему UI и добавь
--  систему выбора вида: что писать — ooc, report и так далее».
--  РАБОТАЕТ ПОДЕСЬЮ поверх BonChat (сам пак не трогаем — MIT и
--  обновляемо): сверху чата, пока он открыт, висит ПОЛОСА КАНАЛОВ.
--  Клик по кнопке — поле ввода получает нужный префикс (старое
--  известное слово-префикс срезается JS-скальпелем, твой текст цел).
--  Серверный роутер (p11_sv_chat) префиксы понимает как раньше,
--  поэтому работает ИСКОННАЯ логика: РЕЧЬ радиусом, // = OOC всем,
--  /looc локальный ooc, /r рация фракции, /report админам, /шепот,
--  /крик, /me (действие), /it (повествование).
-- ============================================================

surface.CreateFont("P11SEL.Chip",  { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("P11SEL.Tiny",  { font = "Roboto", size = 13, weight = 400, extended = true })

local MODES = {
    { id = "say",    lbl = "РЕЧЬ",   pfx = "",          col = Color(170, 220, 170) },
    { id = "ooc",    lbl = "OOC",    pfx = "// ",       col = Color(140, 200, 255) },
    { id = "looc",   lbl = "LOOC",   pfx = "/looc ",    col = Color(120, 180, 235) },
    { id = "radio",  lbl = "РАЦИЯ",  pfx = "/r ",       col = Color(255, 205, 110) },
    { id = "report", lbl = "РЕПОРТ", pfx = "/report ",  col = Color(255, 120, 110) },
    { id = "wsp",    lbl = "ШЁПОТ",  pfx = "/шепот ",   col = Color(180, 160, 235) },
    { id = "shout",  lbl = "КРИК",   pfx = "/крик ",    col = Color(255, 150, 90) },
    { id = "me",     lbl = "ME",     pfx = "/me ",      col = Color(235, 185, 120) },
    { id = "it",     lbl = "IT",     pfx = "/it ",      col = Color(160, 190, 160) },
}

-- префиксы, которые JS будет снимать перед заменой (все, кроме пустого)
local JS_PREFIXES = {}
for _, m in ipairs(MODES) do
    if m.pfx ~= "" then JS_PREFIXES[#JS_PREFIXES + 1] = m.pfx end
end
JS_PREFIXES[#JS_PREFIXES + 1] = "/ooc " -- возможный ручной вариант

P11SEL = P11SEL or { Strip = nil, Cur = "say" }

local function ApplyPrefix(m)
    P11SEL.Cur = m.id
    if not IsValid(BonChat.frame) or not IsValid(BonChat.frame.chatbox) then return end

    -- JS-скальпель: срезать старый известный префикс и надеть новый.
    -- Твой набранный текст не трогаем (он остаётся после префикса).
    local parts = {}
    for _, p in ipairs(JS_PREFIXES) do
        parts[#parts + 1] = string.format("%q", p)
    end
    local js = string.format(
        "var t=getText();var ps=[%s];for(var i=0;i<ps.length;i++){if(t.indexOf(ps[i])===0){t=t.slice(ps[i].length);break;}}entryInput.focus();entryInput.text(%s+t);",
        table.concat(parts, ","),
        string.format("%q", m.pfx))
    BonChat.frame.chatbox:CallJS(js)
    surface.PlaySound("ui/buttonclick.wav")
end

local function EnsureStrip()
    if IsValid(P11SEL.Strip) then return P11SEL.Strip end
    if not IsValid(BonChat.frame) then return nil end

    local H = 30
    local strip = vgui.Create("DPanel")
    P11SEL.Strip = strip
    strip:SetTall(H)
    strip:SetPaintBackground(false)

    local x = 2
    for _, m in ipairs(MODES) do
        surface.SetFont("P11SEL.Chip")
        local tw = surface.GetTextSize(m.lbl) + 18
        local b = vgui.Create("DButton", strip)
        b:SetPos(x, 1)
        b:SetSize(tw, H - 2)
        b:SetText("")
        b.Mode = m
        b.Paint = function(s2, w, h)
            local act = P11SEL.Cur == s2.Mode.id
            local hov = s2:IsHovered()
            local c = s2.Mode.col
            draw.RoundedBox(6, 0, 0, w, h, act and Color(c.r, c.g, c.b, 235) or Color(16, 20, 28, 220))
            surface.SetDrawColor(c.r, c.g, c.b, act and 255 or (hov and 180 or 70))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(s2.Mode.lbl, "P11SEL.Chip", w / 2, h / 2 - 1,
                act and Color(10, 14, 18) or c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function(s2) ApplyPrefix(s2.Mode) end
        b:SetTooltip(m.pfx == "" and "обычная речь — слышат рядом" or ("префикс «" .. m.pfx .. "» автоматически"))
        x = x + tw + 4
    end
    strip:SetWide(x)

    return strip
end

-- положение/видимость: полоса показана только при открытом чате
timer.Create("P11.ChatSelPoll", 0.15, 0, function()
    if not IsValid(BonChat.frame) then
        if IsValid(P11SEL.Strip) then P11SEL.Strip:Remove() P11SEL.Strip = nil end
        return
    end
    local open = BonChat.frame.isOpen and true or false
    local strip = EnsureStrip()
    if not strip then return end

    if open and not strip:IsVisible() then
        strip:MakePopup()
        strip:SetKeyboardInputEnabled(false) -- фокус не воруем — печатаем как раньше
    end
    strip:SetVisible(open)
    if open then
        local fx, fy = BonChat.frame:GetPos()
        strip:SetPos(fx, fy - 34)
    end
end)

print("[POLUS-11] переключатель каналов чата v4.9.2 «ПРИЁМ» загружен (полоса-чипы над BonChat: РЕЧЬ/OOC/LOOC/РАЦИЯ/РЕПОРТ/ШЁПОТ/КРИК/ME/IT)")
