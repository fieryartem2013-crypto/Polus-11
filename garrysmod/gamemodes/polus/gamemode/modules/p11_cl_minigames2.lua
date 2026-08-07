-- ============================================================
--  ПОЛЮС-11 — МИНИИГРЫ ИГЛЫ (client) v4.9.1 «ИГЛА»
--  Единое окно «стрелка-ползунок» для двух новинок:
--   • анализатор «КРОВЬ-2»  — 3 цикла калибровки (нужно ≥60%);
--   • инъектор «УКОЛ-С»     — 1 точная инъекция (≥85% = в самую вену).
--  Управление: ПРОБЕЛ или ЛКМ — зафиксировать стрелку; ESC — обрыв.
--  Плюс окно ВЕРДИКТА крови: виден только тестирующему; заражённый
--  может ПОДМЕНИТЬ официальный исход (тень «Нечто»-82 в деле).
-- ============================================================

surface.CreateFont("P11MG.Title", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11MG.Big",   { font = "Roboto", size = 30, weight = 900, extended = true })
surface.CreateFont("P11MG.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11MG.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

P11MG = P11MG or {}

local C = {
    bg    = Color(10, 14, 20, 248),
    panel = Color(24, 30, 40, 255),
    line  = Color(120, 170, 210, 255),
    text  = Color(228, 238, 248),
    dim   = Color(150, 165, 185),
    green = Color(90, 220, 120),
    yell  = Color(235, 200, 90),
    red   = Color(255, 110, 100),
    mark  = Color(250, 250, 255),
}

-- ============ ОКНО-СТРЕЛКА (общая миниигра) ============

local function CloseSlider()
    if IsValid(P11MG.Slider) then
        P11MG.Slider:Remove()
        P11MG.Slider = nil
    end
end

-- балл попадания: зелень → 75..100 • жёлтый → 40..75 • мимо → 10
local function ZoneScore(v, c)
    local d = math.abs(v - c)
    if d <= 0.12 then
        return 100 - (d / 0.12) * 25
    elseif d <= 0.25 then
        return 40 + ((0.25 - d) / 0.13) * 35
    end
    return 10
end

local function OpenSlider(rounds, title, sub, onFinish)
    CloseSlider()

    local state = {
        idx = 1,
        rounds = rounds,
        scores = {},
        zones = {},
        sent = false,
        openedAt = CurTime(),
    }
    math.randomseed(CurTime() + os.time())
    for i = 1, rounds do
        state.zones[i] = 0.28 + math.random() * 0.44
    end

    local W, H = 540, 300
    local f = vgui.Create("DFrame")
    P11MG.Slider = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(false)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    local function marker()
        local t = (SysTime() * 0.85) % 2
        if t > 1 then t = 2 - t end
        return t
    end

    local function capture()
        if state.sent then return end
        local sc = ZoneScore(marker(), state.zones[state.idx])
        state.scores[state.idx] = sc
        surface.PlaySound(sc >= 75 and "buttons/button9.wav" or (sc >= 40 and "buttons/button17.wav" or "buttons/button10.wav"))
        state.idx = state.idx + 1
        if state.idx > state.rounds then
            local sum = 0
            for _, s2 in ipairs(state.scores) do sum = sum + s2 end
            local avg = sum / state.rounds
            state.sent = true
            onFinish(avg)
            CloseSlider()
        else
            state.flash = CurTime() + 0.45
        end
    end

    local function abort()
        if state.sent then return end
        state.sent = true
        onFinish(0)
    end

    f.Paint = function(s2, w, h)
        Derma_DrawBackgroundBlur(s2, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 58, C.panel, true, true, false, false)
        surface.SetDrawColor(C.line)
        surface.DrawRect(0, 58, w, 2)

        draw.SimpleText(title, "P11MG.Title", 16, 10, C.text)
        draw.SimpleText(sub, "P11MG.Small", 16, 38, C.dim)
        draw.SimpleText("цикл " .. math.min(state.idx, state.rounds) .. " / " .. state.rounds,
            "P11MG.Small", w - 16, 14, C.dim, TEXT_ALIGN_RIGHT)

        -- шкала
        local bx, by, bw, bh = 40, 130, w - 80, 26
        draw.RoundedBox(6, bx - 6, by - 6, bw + 12, bh + 12, C.panel)
        -- зоны
        local c2 = state.zones[math.min(state.idx, state.rounds)]
        draw.RoundedBox(4, bx + (c2 - 0.25) * bw, by, 0.5 * bw, bh, Color(170, 155, 60, 130))
        draw.RoundedBox(4, bx + (c2 - 0.12) * bw, by, 0.24 * bw, bh, Color(60, 180, 90, 170))
        -- бордюр шкалы
        surface.SetDrawColor(C.line)
        surface.DrawOutlinedRect(bx, by, bw, bh, 1)
        -- стрелка
        local v = marker()
        local mx = bx + v * bw
        surface.SetDrawColor(C.mark)
        surface.DrawRect(mx - 2, by - 8, 4, bh + 16)

        draw.SimpleText("ПРОБЕЛ / ЛКМ — зафиксировать стрелку", "P11MG.Text", w / 2, by + 46, C.text, TEXT_ALIGN_CENTER)

        -- прошлые циклы
        local yy = by + 78
        for i = 1, state.rounds do
            local s3 = state.scores[i]
            local mark = s3 and (math.floor(s3) .. "%") or (i == state.idx and "▶" or "·")
            local col2 = C.dim
            if s3 then col2 = (s3 >= 75 and C.green) or (s3 >= 40 and C.yell) or C.red end
            draw.SimpleText(mark, "P11MG.Text", w / 2 - 60 + (i - 1) * 60, yy, col2, TEXT_ALIGN_CENTER)
        end

        draw.SimpleText("ESC — обрыв (результат 0%)", "P11MG.Small", w - 16, h - 16, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local click = vgui.Create("DButton", f)
    click:SetSize(W, H)
    click:SetPos(0, 0)
    click:SetText("")
    click.Paint = function() end
    click.DoClick = function() capture() end
    -- фокус после клика уедет на кнопку — клавиши ловим и на ней
    click.OnKeyCodePressed = function(s2, key)
        if key == KEY_SPACE or key == KEY_ENTER then
            capture()
        elseif key == KEY_ESCAPE then
            abort()
            f:Remove()
        end
    end

    f.OnKeyCodePressed = function(s2, key)
        if key == KEY_SPACE or key == KEY_ENTER then
            capture()
        elseif key == KEY_ESCAPE then
            abort()
            f:Remove()
        end
    end

    -- страховка: 30 сек безмолвия — обрыв
    f.Think = function(s2)
        if not state.sent and CurTime() - state.openedAt > 30 then abort() s2:Remove() end
    end
end

-- ============ ОКНО ВЕРДИКТА КРОВИ ============

local function OpenVerdict(status, donor, canFal)
    if IsValid(P11MG.Verdict) then P11MG.Verdict:Remove() end

    local sent = false
    local W, H = 480, canFal and 250 or 210
    local f = vgui.Create("DFrame")
    P11MG.Verdict = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    local title, titleCol, body
    if status == 0 then
        title, titleCol = "АНАЛИЗ ИСПОРЧЕН", C.yell
        body = "Калибровка смазана (нужно ≥60% точности).\nКолба цела — отнеси её к анализатору ещё раз."
    elseif status == 2 then
        title, titleCol = "ОБРАЗЕЦ: НЕЧТО", C.red
        body = "Кровь донора «" .. donor .. "» КИПИТ на проволоке.\nОбразец нечеловеческий. Донора — под конвой. Тихо."
    else
        title, titleCol = "ОБРАЗЕЦ: ЧИСТ", C.green
        body = "Кровь донора «" .. donor .. "» человеческая.\nПризнаков ассимиляции нет."
    end

    local function reply(fal)
        if sent then return end
        sent = true
        net.Start("P11_BL_VER")
            net.WriteBool(fal and true or false)
        net.SendToServer()
        chat.AddText(Color(255, 205, 100), "[КРОВЬ-2] ", Color(225, 230, 240),
            fal and "Официальный исход ПОДМЕНЁН — все увидят другое. (В журнал лаборатории — правда.)"
                or "Вердикт зафиксирован официально.")
        surface.PlaySound("ui/buttonclickrelease.wav")
        f:Remove()
    end

    f.Paint = function(s2, w, h)
        Derma_DrawBackgroundBlur(s2, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)
        surface.SetDrawColor(titleCol.r, titleCol.g, titleCol.b, 90)
        surface.DrawRect(0, 0, w, 4)
        draw.SimpleText("АНАЛИЗАТОР «КРОВЬ-2» — ВЕРДИКТ", "P11MG.Small", w / 2, 12, C.dim, TEXT_ALIGN_CENTER)
        draw.SimpleText(title, "P11MG.Big", w / 2, 38, titleCol, TEXT_ALIGN_CENTER)
        draw.SimpleText("донор: " .. donor .. "  •  видишь только ТЫ", "P11MG.Small", w / 2, 78, C.dim, TEXT_ALIGN_CENTER)
        local yy = 100
        for ln in string.gmatch(body .. "\n", "([^\n]*)\n") do
            draw.SimpleText(ln, "P11MG.Text", w / 2, yy, C.text, TEXT_ALIGN_CENTER)
            yy = yy + 20
        end
    end

    local function mkBtn(x, w2, txt, col, act)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, H - 52)
        b:SetSize(w2, 38)
        b:SetText("")
        b.Paint = function(s2, bw, bh)
            local hov = s2:IsHovered()
            draw.RoundedBox(8, 0, 0, bw, bh, hov and Color(col.r + 25, col.g + 25, col.b + 25) or Color(col.r, col.g, col.b, 200))
            draw.SimpleText(txt, "P11MG.Text", bw / 2, bh / 2 - 2, Color(12, 16, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = act
    end

    if status == 0 then
        mkBtn(110, 260, "ПОНЯЛ", Color(120, 130, 145), function() reply(false) end)
    elseif canFal then
        mkBtn(20, 210, "ОФИЦИАЛЬНЫЙ", Color(90, 180, 110), function() reply(false) end)
        mkBtn(250, 210, "ПОДМЕНИТЬ", Color(200, 90, 80), function() reply(true) end)
    else
        mkBtn(110, 260, "ЗАНЕСТИ В ЖУРНАЛ", Color(90, 160, 220), function() reply(false) end)
    end

    f.OnKeyCodePressed = function(s2, key)
        if key == KEY_ESCAPE then reply(false) end
    end
    f.OnRemove = function() if not sent then reply(false) end end
end

-- ============ СЕТЬ ============

net.Receive("P11_BL_MG", function()
    local rounds = net.ReadUInt(4)
    local donor = net.ReadString()
    OpenSlider(rounds, "КАЛИБРОВКА АНАЛИЗАТОРА «КРОВЬ-2»",
        "кровь: «" .. donor .. "» — 3 цикла, средняя точность ≥60%", function(avg)
            net.Start("P11_BL_MG")
                net.WriteFloat(avg)
            net.SendToServer()
        end)
end)

net.Receive("P11_UK_MG", function()
    local rounds = net.ReadUInt(4)
    local target = net.ReadString()
    OpenSlider(rounds, "ИНЪЕКЦИЯ «УКОЛ-С»",
        "пациент: «" .. target .. "» — попади стрелкой в вену!", function(avg)
            net.Start("P11_UK_MG")
                net.WriteFloat(avg)
            net.SendToServer()
        end)
end)

net.Receive("P11_BL_VER", function()
    local status = net.ReadUInt(2)
    local donor = net.ReadString()
    local canFal = net.ReadBool()
    OpenVerdict(status, donor, canFal)
end)

print("[POLUS-11] миниигры иглы v4.9.1 загружены (КРОВЬ-2 калибровка + УКОЛ-С вена + окно вердикта)")
