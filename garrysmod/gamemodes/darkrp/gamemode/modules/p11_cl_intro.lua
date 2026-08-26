-- ============================================================
--  ПОЛЮС-11 — ИНТРО v4 «СИЯНИЕ» (client) v4.26.0
--  Кинематографичная заставка при входе, ПОЛНЫЙ РЕВОРК:
--   • РАДИОЖУРНАЛ: строки лора идут с метками времени [03:12];
--   • после красной строки на экран с размаху ложится ПЕЧАТЬ
--     «СТРОГО СЕКРЕТНО» (шкала-удар, потрёпанная тушь);
--   • САМОДИАГНОСТИКА СТАНЦИИ слева внизу (дизель / радиобуй /
--     датчик сектора 7 — статусы зелёным и красным);
--   • финал — эмблема: кольца радара + КРАСНАЯ ЗВЕЗДА и логотип.
--  Снег двумя слоями, сияние, зерно, сканлайны, виньетка — на месте.
--  Пропуск — ЛКМ / ESC / ПРОБЕЛ / ENTER. Один раз за сессию.
--  Отключить себе: p11_intro 0 (сохраняется).
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.Intro.Title", { font = "Roboto", size = 68, weight = 900, extended = true })
surface.CreateFont("P11.Intro.Big",   { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11.Intro.Mid",   { font = "Roboto", size = 19, weight = 600, extended = true })
surface.CreateFont("P11.Intro.Small", { font = "Roboto", size = 15, weight = 400, extended = true })
surface.CreateFont("P11.Intro.Ts",    { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("P11.Intro.Boot",  { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.Intro.Stamp", { font = "Roboto", size = 46, weight = 900, extended = true })

local CONVAR = CreateClientConVar("p11_intro", "1", true, false)

-- радиожурнал смены: [время] + строка лора (red = льётся красным)
local LINES = {
    { ts = "03:12", t = "АНТАРКТИДА. ЗИМА 1982 ГОДА.", big = true },
    { ts = "03:19", t = "Исследовательская станция «ПОЛЮС-11»." },
    { ts = "03:41", t = "Связь с миром оборвалась трое суток назад." },
    { ts = "04:02", t = "На льду нашли то, что не должно двигаться." },
    { ts = "04:27", t = "Оно поглощает жертву и копирует её досконально: лицо, голос, память, привычки." },
    { ts = "04:55", t = "Единственная правда — раскалённая проволока и кровь, которая боится боли." },
    { ts = "05:03", t = "Доверяй огню. Доверяй тесту. Больше — никому.", red = true },
    { ts = "05:10", t = "Смена начинается.", big = true },
}

-- самодиагностика станции слева внизу (терминальный текст)
local BOOT = {
    { t = "ПИТАНИЕ · ДИЗЕЛЬ-2",                 st = "[ ОК ]",              ok = true },
    { t = "АНТЕННА «СЕВЕР-3»",                  st = "[ ОБЛЕДЕНЕЛА ]",      ok = true },
    { t = "РАДИОБУЙ №14 · ЭКИПАЖ МАКМЕРДО",     st = "[ МОЛЧИТ ]",          ok = false },
    { t = "ДАТЧИК ДВИЖЕНИЯ · СЕКТОР 7",         st = "[ АКТИВНОСТЬ ]",      ok = false },
    { t = "ВРАТА ЛАБОРАТОРИИ",                  st = "[ ЗАПЕРТЫ ИЗНУТРИ ]", ok = false },
}

local INTRO = { active = false, shown = false, t = 0, chars = 0 }

local ColText = Color(170, 215, 240)
local ColDim  = Color(100, 125, 140)
local ColRed  = Color(240, 90, 80)
local ColGold = Color(255, 205, 110)

-- v4.26.0: пятиконечная звезда полигоном (без текстур, не зависит от шрифтов)
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

-- ============ СНЕГ ============

local FLAKES, FLAKES2 = nil, nil
local function BuildFlakes()
    FLAKES, FLAKES2 = {}, {}
    for i = 1, 130 do
        FLAKES[i] = {
            x = math.random(), y = math.random(),
            s = 16 + math.random() * 60,
            d = (math.random() - 0.5) * 0.06,
            w = 1 + math.random() * 2,
            a = 60 + math.random() * 160,
            ph = math.random() * 10,
        }
    end
    -- передний план — крупные медленные снежинки (параллакс)
    for i = 1, 34 do
        FLAKES2[i] = {
            x = math.random(), y = math.random(),
            s = 30 + math.random() * 46,
            d = (math.random() - 0.5) * 0.05,
            w = 3 + math.random() * 3.5,
            a = 26 + math.random() * 60,
            ph = math.random() * 10,
        }
    end
end

local function CloseIntro()
    if not INTRO.active then return end
    INTRO.active = false
    P11.IntroOpen = false
    if INTRO.wind then INTRO.wind:FadeOut(1.2) INTRO.wind = nil end
    if INTRO.wind2 then INTRO.wind2:FadeOut(1.2) INTRO.wind2 = nil end
    if IsValid(INTRO.frame) then INTRO.frame:Remove() INTRO.frame = nil end
    hook.Remove("Think", "P11.IntroThink")
end

local function OpenIntro()
    if INTRO.active or INTRO.shown then return end
    if CONVAR:GetInt() == 0 then INTRO.shown = true return end
    INTRO.shown = true
    INTRO.active = true
    INTRO.t = CurTime()
    INTRO.chars = 0
    INTRO.total = 0
    for _, l in ipairs(LINES) do
        INTRO.total = INTRO.total + #l.t
        l.doneT = nil l.glitched = nil
    end
    INTRO.logoSounded = false
    INTRO.stampT = nil INTRO.stamped = nil -- v4.26.0: сброс печати
    P11.IntroOpen = true
    if not FLAKES then BuildFlakes() end

    -- два слоя ветра: гул станции + порывы
    local ok, cs = pcall(CreateSound, LocalPlayer(), "ambient/atmosphere/ambience_base.wav")
    if ok and cs then INTRO.wind = cs cs:PlayEx(0.5, 95) end
    local ok2, cs2 = pcall(CreateSound, LocalPlayer(), "ambient/wind/wind_moan1.wav")
    if ok2 and cs2 then INTRO.wind2 = cs2 cs2:PlayEx(0.35, 88) end
    surface.PlaySound("ambient/wind/wind_hit1.wav")

    local okf, f = pcall(vgui.Create, "DPanel")
    if not okf or not IsValid(f) then
        -- если окно не родилось — НЕ застреваем в «интро-режиме»
        P11.IntroOpen = false
        INTRO.active = false
        print("[POLUS][ERROR] интро: " .. tostring(f))
        if INTRO.wind then INTRO.wind:FadeOut(0.5) INTRO.wind = nil end
        if INTRO.wind2 then INTRO.wind2:FadeOut(0.5) INTRO.wind2 = nil end
        return
    end
    INTRO.frame = f
    f:SetSize(ScrW(), ScrH())
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    f.Paint = function(s, w, h)
        local el = CurTime() - INTRO.t
        local ft = FrameTime()
        INTRO.chars = INTRO.chars + ft * 27 -- скорость машинки
        local charsLeft = math.floor(INTRO.chars)

        -- фон
        draw.RoundedBox(0, 0, 0, w, h, Color(4, 6, 10, 255))

        -- ПОЛЯРНОЕ СИЯНИЕ — три дышащих занавеса у горизонта
        if not INTRO.noAurora then
            for band = 1, 3 do
                local baseY = h * (0.10 + band * 0.055)
                local drift = math.sin(CurTime() * 0.35 + band * 1.9) * w * 0.05
                local hue = (band % 2 == 0)
                for i = 0, 15 do
                    local yy = baseY + i * math.floor(h * 0.006) + math.sin(CurTime() * 0.8 + i * 0.55 + band) * 6
                    local a = math.max(0, 22 - i * 1.35) * (0.7 + 0.3 * math.sin(CurTime() * 0.5 + band * 2.4 + i * 0.3))
                    if hue then
                        surface.SetDrawColor(60, 200, 160, a)
                    else
                        surface.SetDrawColor(80, 160, 220, a)
                    end
                    surface.DrawRect(0, yy - drift * 0.02, w, math.floor(h * 0.006) + 1)
                end
            end
        end

        -- мягкий холодный градиент снизу (как отсвет льда)
        for i = 0, 11 do
            surface.SetDrawColor(14, 30, 44, 10)
            surface.DrawRect(0, h - h * 0.30 + (h * 0.30 / 12) * i, w, h * 0.30 / 12 + 1)
        end

        -- СНЕГ
        for _, fl in ipairs(FLAKES) do
            fl.y = fl.y + (fl.s / 1000) * ft * 3.2
            fl.x = fl.x + fl.d * ft + math.sin(CurTime() + fl.ph) * 0.0003
            if fl.y > 1.02 then fl.y = -0.02 fl.x = math.random() end
            if fl.x > 1.02 then fl.x = -0.02 elseif fl.x < -0.02 then fl.x = 1.02 end
            surface.SetDrawColor(200, 225, 245, fl.a)
            surface.DrawRect(fl.x * w, fl.y * h, fl.w, fl.w)
        end
        if FLAKES2 then
            for _, fl in ipairs(FLAKES2) do
                fl.y = fl.y + (fl.s / 1000) * ft * 2.4
                fl.x = fl.x + fl.d * ft + math.sin(CurTime() * 0.7 + fl.ph) * 0.0009
                if fl.y > 1.05 then fl.y = -0.05 fl.x = math.random() end
                if fl.x > 1.05 then fl.x = -0.05 elseif fl.x < -0.05 then fl.x = 1.05 end
                surface.SetDrawColor(215, 232, 250, fl.a)
                surface.DrawRect(fl.x * w, fl.y * h, fl.w, fl.w)
                surface.SetDrawColor(215, 232, 250, fl.a * 0.35)
                surface.DrawRect(fl.x * w - 1, fl.y * h - 1, fl.w + 2, fl.w + 2)
            end
        end

        -- кино-ПОЛОСЫ с заездом
        local barH = math.floor(h * 0.095)
        local slide = math.Clamp(el / 1.3, 0, 1)
        local off = math.floor((1 - slide) * (1 - slide) * (barH + 4))
        draw.RoundedBox(0, 0, -4 - barH + barH - off + 1, w, barH, Color(0, 0, 0, 255))
        draw.RoundedBox(0, 0, h - barH + off, w, barH, Color(0, 0, 0, 255))
        surface.SetDrawColor(50, 85, 105, 140)
        surface.DrawRect(0, barH - off, w, 1)
        surface.DrawRect(0, h - barH + off - 1, w, 1)

        -- РАДИОЖУРНАЛ: строки лора с метками времени
        local y = h * 0.24
        local allDone = true
        for i, l in ipairs(LINES) do
            if charsLeft <= 0 then allDone = false break end
            -- метка времени отпечатывается мгновенно в начале строки
            draw.SimpleText(l.ts, "P11.Intro.Ts", w / 2 - 328, y,
                Color(100, 155, 185, 185), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            local take = math.min(charsLeft, #l.t)
            local part = string.sub(l.t, 1, take)
            charsLeft = charsLeft - take
            local done = take >= #l.t
            local font = l.big and "P11.Intro.Big" or "P11.Intro.Mid"
            local col
            if l.red then
                col = done and ColRed or Color(160, 70, 65)
            else
                col = done and ColText or ColDim
            end
            draw.SimpleTextOutlined(part .. ((not done) and "▌" or ""), font,
                w / 2, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                1, Color(0, 0, 0, 200))

            -- красная строка завершилась → удар ПЕЧАТИ
            if l.red and done then
                if not INTRO.stampT then INTRO.stampT = CurTime() + 0.35 end
                l.doneT = l.doneT or CurTime()
                local age = CurTime() - l.doneT
                if age < 0.9 then
                    if not l.glitched and age < 0.15 then
                        l.glitched = true
                        surface.PlaySound("buttons/button17.wav")
                    end
                    if math.random() < 0.35 then
                        local dx = math.random(-3, 3)
                        local dy = math.random(-1, 1)
                        draw.SimpleText(part, font, w / 2 + dx - 2, y + dy,
                            Color(255, 60, 50, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText(part, font, w / 2 + dx + 2, y - dy,
                            Color(120, 200, 255, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end

            y = y + (l.big and 54 or 40)
            if not done then allDone = false break end
        end

        -- v4.26.0 «СИЯНИЕ»: ПЕЧАТЬ «СТРОГО СЕКРЕТНО» — удар с размаху
        if INTRO.stampT then
            local age = CurTime() - INTRO.stampT
            if age >= 0 then
                if not INTRO.stamped then
                    INTRO.stamped = true
                    surface.PlaySound("physics/metal/metal_box_impact_hard2.wav")
                end
                local k = math.Clamp(age / 0.22, 0, 1)
                k = 1 - (1 - k) ^ 3
                local s = 1.55 - 0.55 * k            -- въезжает крупным, встает на место
                local a = (0.95 - 0.10 * k) * math.Clamp(age / 0.12, 0, 1)
                local cx2, cy2 = w * 0.735, h * 0.315
                local m = Matrix()
                m:Translate(Vector(cx2, cy2, 0))
                m:Scale(Vector(s, s, 1))
                m:Translate(Vector(-cx2, -cy2, 0))
                cam.PushModelMatrix(m)
                surface.SetDrawColor(210, 60, 50, 205 * a)
                surface.DrawOutlinedRect(cx2 - 196, cy2 - 46, 392, 92, 3)
                surface.SetDrawColor(210, 60, 50, 120 * a)
                surface.DrawOutlinedRect(cx2 - 187, cy2 - 37, 374, 74, 1)
                -- уголки папки
                surface.SetDrawColor(210, 60, 50, 160 * a)
                surface.DrawRect(cx2 - 196, cy2 - 46, 26, 3) surface.DrawRect(cx2 - 196, cy2 - 46, 3, 26)
                surface.DrawRect(cx2 + 170, cy2 - 46, 26, 3) surface.DrawRect(cx2 + 193, cy2 - 46, 3, 26)
                surface.DrawRect(cx2 - 196, cy2 + 43, 26, 3) surface.DrawRect(cx2 - 196, cy2 + 20, 3, 26)
                surface.DrawRect(cx2 + 170, cy2 + 43, 26, 3) surface.DrawRect(cx2 + 193, cy2 + 20, 3, 26)
                draw.SimpleText("СТРОГО СЕКРЕТНО", "P11.Intro.Stamp", cx2, cy2 - 12,
                    Color(225, 70, 60, 235 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("ОСОБАЯ ПАПКА · АНТАРКТИДА · 1982", "P11.Intro.Boot", cx2, cy2 + 24,
                    Color(225, 100, 90, 210 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- потрёпанность штемпельной туши
                for i = 1, 26 do
                    surface.SetDrawColor(4, 6, 10, 110 * a)
                    surface.DrawRect(cx2 - 196 + math.random(0, 392), cy2 - 46 + math.random(0, 92),
                        math.random(1, 7), math.random(1, 3))
                end
                cam.PopModelMatrix()
            end
        end

        -- ФИНАЛ: логотип станции
        if allDone then
            if not INTRO.logoSounded then
                INTRO.logoSounded = true
                surface.PlaySound("ambient/atmosphere/hole_hit2.wav")
            end
            local lt = el - (INTRO.total / 27)
            local glow = 0.5 + math.sin(CurTime() * 2.2) * 0.22
            local a = math.Clamp(lt / 1.1, 0, 1)

            -- эмблема: два кольца радара + перекрестье + КРАСНАЯ ЗВЕЗДА
            local cx, cy = w / 2, h * 0.24 - 56
            surface.DrawCircle(cx, cy, 40, ColText.r, ColText.g, ColText.b, 150 * a)
            surface.DrawCircle(cx, cy, 29, ColText.r, ColText.g, ColText.b, 90 * a)
            surface.SetDrawColor(ColText.r, ColText.g, ColText.b, 130 * a)
            surface.DrawLine(cx - 48, cy, cx - 41, cy)
            surface.DrawLine(cx + 41, cy, cx + 48, cy)
            surface.DrawLine(cx, cy - 48, cx, cy - 41)
            surface.DrawLine(cx, cy + 41, cx, cy + 48)
            local ra = CurTime() * 1.6
            surface.SetDrawColor(120, 200, 230, 130 * a)
            surface.DrawLine(cx, cy, cx + math.cos(ra) * 39, cy + math.sin(ra) * 39)
            Star(cx, cy, 16, Color(228, 82, 70, 230 * a * (0.75 + 0.25 * glow)))

            -- трепет лампы в первую полсекунду логотипа
            if lt < 0.55 then
                a = a * (math.random() < 0.45 and math.Rand(0.25, 0.7) or 1)
            end

            -- логотип: три прохода = свечение + лёд
            draw.SimpleText("ПОЛЮС-11", "P11.Intro.Title", w / 2, h * 0.24 + 18,
                Color(ColText.r, ColText.g, ColText.b, 80 * a * glow),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            draw.SimpleText("ПОЛЮС-11", "P11.Intro.Title", w / 2 + 2, h * 0.24 + 20,
                Color(60, 120, 160, 140 * a),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            draw.SimpleTextOutlined("ПОЛЮС-11", "P11.Intro.Title", w / 2, h * 0.24 + 18,
                Color(232, 246, 255, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
                2, Color(30, 60, 80, 200 * a))
            draw.SimpleText("★ ВОЕННАЯ ЗОНА ОСОБОГО НАЗНАЧЕНИЯ ★", "P11.Intro.Small",
                w / 2, h * 0.24 + 32, Color(228, 120, 105, 220 * a),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("MILITARY HORROR RP  •  THE THING 1982", "P11.Intro.Small",
                w / 2, h * 0.24 + 52, Color(ColDim.r, ColDim.g, ColDim.b, 220 * a),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            if el > (INTRO.total / 27) + 4.0 then
                CloseIntro()
                return
            end
        end

        -- v4.26.0 «СИЯНИЕ»: САМОДИАГНОСТИКА СТАНЦИИ (слева внизу)
        if el > 1.0 then
            local bx = 22
            local by = h - barH + off - 34 - #BOOT * 18 - 10
            for i, bl in ipairs(BOOT) do
                local lat = el - 1.0 - (i - 1) * 0.7
                if lat > 0 then
                    local la = math.Clamp(lat / 0.35, 0, 1)
                    local mono = Color(118, 172, 152, 235 * la)
                    draw.SimpleText("▸ " .. bl.t .. "  …", "P11.Intro.Boot", bx, by + (i - 1) * 18,
                        mono, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    surface.SetFont("P11.Intro.Boot")
                    local twl = surface.GetTextSize("▸ " .. bl.t .. "  … ")
                    local stc = bl.ok and Color(120, 200, 140, 235 * la) or Color(235, 110, 95, 245 * la)
                    if not bl.ok then
                        -- нештатный статус подмигивает
                        stc.a = stc.a * (0.7 + 0.3 * math.sin(CurTime() * 3.5 + i))
                    end
                    draw.SimpleText(bl.st, "P11.Intro.Boot", bx + twl + 4, by + (i - 1) * 18,
                        stc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
        end

        -- штамп экспедиции — мигающий курсор печатающей машинки
        if (CurTime() % 1.1) < 0.75 then
            draw.SimpleText("ЭКСПЕДИЦИЯ-4 · 66°33′ ю.ш. 93°02′ в.д. · ЗИМА 1982", "P11.Intro.Small",
                18, h - barH + off - 34, Color(110, 140, 155, 170),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- зерно плёнки
        for i = 1, 46 do
            surface.SetDrawColor(255, 255, 255, math.random(2, 11))
            surface.DrawRect(math.random(0, w), math.random(0, h), 1, 1)
        end

        -- виньетка по краям (лесенкой, без шейдеров)
        for i = 0, 9 do
            local va = 7 + i * 2.4
            local th = 6 - i * 0.5
            if th < 1 then th = 1 end
            surface.SetDrawColor(0, 0, 0, va)
            surface.DrawRect(0, i * 12, w, th)
            surface.DrawRect(0, h - i * 12 - th, w, th)
            surface.DrawRect(i * 12, 0, th, h)
            surface.DrawRect(w - i * 12 - th, 0, th, h)
        end

        -- сканлайны
        surface.SetDrawColor(0, 0, 0, 14)
        for sy = 0, h, 4 do
            surface.DrawRect(0, sy, w, 1)
        end

        -- прогресс СЕГМЕНТАМИ + подсказка
        local dur = (INTRO.total / 27) + 4.0
        local frac = math.Clamp(el / dur, 0, 1)
        local seg = 26
        local segW = (w * 0.32 - (seg - 1) * 3) / seg
        local lit = math.floor(frac * seg + 0.5)
        for i = 1, seg do
            local sx = w * 0.34 + (i - 1) * (segW + 3)
            if i <= lit then
                surface.SetDrawColor(120, 190, 220, 210)
            else
                surface.SetDrawColor(40, 60, 75, 130)
            end
            surface.DrawRect(sx, h - barH + off - 18, segW, 3)
        end

        if (CurTime() % 1.2) < 0.9 then
            draw.SimpleText("ПРОПУСК — ЛЮБАЯ КЛАВИША / КЛИК", "P11.Intro.Small",
                w - 22, h - barH + off - 34, Color(ColDim.r, ColDim.g, ColDim.b, 190),
                TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- пропуск
    f.OnMousePressed = function() CloseIntro() end
    f.OnKeyCodePressed = function(s, key)
        if key ~= 0 then CloseIntro() end
    end

    -- ЯВНАЯ кнопка «ПРОПУСТИТЬ»
    local skipB = vgui.Create("DButton", f)
    skipB:SetSize(190, 42)
    skipB:SetPos(ScrW() - 190 - 24, ScrH() - math.floor(ScrH() * 0.095) - 42 - 18)
    skipB:SetText("")
    skipB.Paint = function(s2, bw, bh)
        local hov = s2:IsHovered()
        local pulse = 0.72 + math.sin(CurTime() * 3.2) * 0.28
        draw.RoundedBox(8, 0, 0, bw, bh, hov and Color(30, 46, 60, 245) or Color(16, 26, 36, 225))
        draw.RoundedBoxEx(8, 0, 0, bw, math.floor(bh / 2), Color(255, 255, 255, hov and 14 or 6), true, true, false, false)
        surface.SetDrawColor(150, 215, 250, (hov and 235 or 130) * pulse + 60)
        surface.DrawOutlinedRect(0, 0, bw, bh, hov and 2 or 1)
        -- морозные уголки
        surface.SetDrawColor(190, 230, 250, hov and 200 or 90)
        surface.DrawRect(0, 0, 16, 2) surface.DrawRect(0, 0, 2, 16)
        surface.DrawRect(bw - 16, 0, 16, 2) surface.DrawRect(bw - 2, 0, 2, 16)
        surface.DrawRect(0, bh - 2, 16, 2) surface.DrawRect(0, bh - 16, 2, 16)
        surface.DrawRect(bw - 16, bh - 2, 16, 2) surface.DrawRect(bw - 2, bh - 16, 2, 16)
        draw.SimpleText("ПРОПУСТИТЬ  ▶▶", "P11.Intro.Mid", bw / 2, bh / 2,
            hov and Color(230, 245, 255) or Color(160, 200, 225),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if hov then s2:SetCursor("hand") end
    end
    skipB.DoClick = function()
        surface.PlaySound("buttons/button14.wav")
        if IsValid(INTRO.frame) then INTRO.frame:Remove() INTRO.frame = nil end
        CloseIntro()
    end

    -- страховка: мировые клавиши + жёсткий таймаут
    hook.Add("Think", "P11.IntroThink", function()
        if not INTRO.active then hook.Remove("Think", "P11.IntroThink") return end
        if input.IsKeyDown(KEY_ESCAPE) or input.IsKeyDown(KEY_ENTER)
            or input.IsKeyDown(KEY_SPACE) or input.IsMouseDown(MOUSE_LEFT) then
            CloseIntro()
        end
        if CurTime() - INTRO.t > 60 then CloseIntro() end
    end)
end

net.Receive("P11_IntroShow", function()
    timer.Simple(0.6, OpenIntro)
end)

-- ручной повтор: p11_intro_show
concommand.Add("p11_intro_show", function()
    INTRO.shown = false
    OpenIntro()
end)
