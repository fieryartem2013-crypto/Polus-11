-- ============================================================
--  ПОЛЮС-11 — ОПЕРАЦИИ «РУБЕЖ» (клиент) v4.24.2 «ЗНАМЯ»
--  Перерисовано красиво: окно выбора сторон — две панели со
--  звёздами и живым счётом записи; HUD боя — большой центральный
--  таймер, прогресс-бары серий удержания (до 3:00), цветные
--  фишки четырёх точек (буква = владелец, красная искра = жмут);
--  лидерборд с баннером победителя и медалями мест; маяки
--  точек «▼ А · N юн» (v4.24.1). Сетевой контракт тот же.
-- ============================================================

surface.CreateFont("P11.Op.Huge",  { font = "Roboto", size = 44, weight = 800, extended = true })
surface.CreateFont("P11.Op.Title", { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11.Op.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.Op.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Op.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

local USSR_COL  = Color(215, 90, 80)
local USA_COL   = Color(100, 160, 240)
local GOLD      = Color(255, 205, 100)
local NEUTRAL_C = Color(150, 158, 172)
local DIMC      = Color(160, 168, 180)
local BG        = Color(12, 16, 22, 245)
local PANE      = Color(26, 32, 42, 255)

local HOLD_WIN = 180  -- сек серии для досрочной победы (зеркало сервера, v4.28.0)

local SIDE_SHORT = { rkka = "СССР", eagle = "США" }
local SIDE_COL   = { rkka = USSR_COL, eagle = USA_COL }

local PickFrame, BoardFrame, OpsFrame

local function OpState()
    local raw = GetGlobalString("P11_Op", "")
    if raw == "" then return { phase = "idle" } end
    local t = string.Explode("|", raw)
    local st = { phase = t[1] or "idle", left = tonumber(t[2]) or 0 }
    if st.phase == "recruit" then
        st.nA = tonumber(t[3]) or 0
        st.nB = tonumber(t[4]) or 0
    else
        st.holdA = tonumber(t[3]) or 0
        st.holdB = tonumber(t[4]) or 0
        st.ownA  = tonumber(t[5]) or 0
        st.ownB  = tonumber(t[6]) or 0
        st.pts   = tonumber(t[7]) or 0
        st.nA    = tonumber(t[8]) or 0
        st.nB    = tonumber(t[9]) or 0
    end
    return st
end

local function FmtTime(sec)
    sec = math.floor(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- v4.33.0 «ПАТРОН»: плавные значения (бары серий едут без рывков)
local SMOOTH = {}
local function SmoothVal(key, target)
    local cur = SMOOTH[key] or target
    cur = cur + (target - cur) * math.min(FrameTime() * 5, 1)
    if math.abs(cur - target) < 0.005 then cur = target end
    SMOOTH[key] = cur
    return cur
end

local function HoldBar(x, y, w, frac, col, t)
    draw.RoundedBox(4, x, y, w, 10, Color(16, 20, 26, 240))
    local fw = math.floor(w * math.Clamp(frac, 0, 1))
    if fw > 2 then
        draw.RoundedBox(4, x, y, fw, 10, col)
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawRect(x + 1, y + 1, fw - 2, 3)
        -- бегущий блик
        if t then
            local ph = (t * 1.6) % 1.4 - 0.2
            if ph > -0.15 and ph < 1 then
                surface.SetDrawColor(255, 255, 255, 34)
                surface.DrawRect(x + ph * w, y, 12, 10)
            end
        end
    end
    surface.SetDrawColor(255, 205, 100, 46)
    surface.DrawOutlinedRect(x, y, w, 10, 1)
end

-- ============ HUD-полоса ============

hook.Add("HUDPaint", "P11.OpHUD", function()
    local st = OpState()
    if st.phase == "idle" then return end
    local w = ScrW()
    local mine = LocalPlayer():GetNWString("P11_OpSide", "")

    if st.phase == "recruit" then
        draw.RoundedBox(8, w / 2 - 300, 92, 600, 52, Color(58, 40, 16, 228))
        surface.SetDrawColor(255, 205, 100, 60)
        surface.DrawOutlinedRect(w / 2 - 300, 92, 600, 52, 1)
        surface.SetDrawColor(255, 205, 100, 90 + math.sin(CurTime() * 1.4) * 20)
        surface.DrawRect(w / 2 - 300, 92, 600, 1)
        draw.SimpleText("★ ОПЕРАЦИЯ «РУБЕЖ» — запись сторон " .. FmtTime(st.left),
            "P11.Op.Mid", w / 2, 100, GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("★ СССР ×" .. (st.nA or 0) .. "    ★ США ×" .. (st.nB or 0) ..
            (mine ~= "" and ("    —    ты за «" .. (SIDE_SHORT[mine] or "?") .. "»") or ""),
            "P11.Op.Small", w / 2, 124, Color(238, 228, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        return
    end

    if st.phase == "battle" then
        -- главная панель: стороны + большой таймер (v4.33.0: знамя-кайма)
        draw.RoundedBox(8, w / 2 - 400, 92, 800, 46, Color(14, 18, 26, 228))
        surface.SetDrawColor(255, 255, 255, 14)
        surface.DrawOutlinedRect(w / 2 - 400, 92, 800, 46, 1)
        surface.SetDrawColor(255, 205, 100, 90 + math.sin(CurTime() * 1.4) * 20)
        surface.DrawRect(w / 2 - 400, 92, 800, 1)
        -- цветные кромки сторон
        draw.RoundedBoxEx(8, w / 2 - 400, 92, 4, 46, USSR_COL, true, false, true, false)
        draw.RoundedBoxEx(8, w / 2 + 396, 92, 4, 46, USA_COL, false, true, false, true)

        -- СССР слева: имя, счёт точек, бар серии
        local ca = (mine == "rkka") and GOLD or USSR_COL
        draw.SimpleText("★ СССР  " .. (st.ownA or 0) .. "/" .. (st.pts or 0),
            "P11.Op.Mid", w / 2 - 384, 98, ca, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        HoldBar(w / 2 - 384, 122, 170, SmoothVal("holdA", (st.holdA or 0) / HOLD_WIN), ca, CurTime())

        -- центр: большой таймер (пульсирует красным под минуту)
        local leftT = st.left or 0
        local tcol = Color(240, 242, 246)
        if leftT < 60 then
            local p = 0.5 + math.sin(CurTime() * 6) * 0.5
            tcol = Color(255, 120 + 60 * p, 100 + 40 * p)
        end
        draw.SimpleText(FmtTime(leftT), "P11.Op.Title", w / 2, 93,
            tcol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- США справа
        local cb = (mine == "eagle") and GOLD or USA_COL
        draw.SimpleText((st.ownB or 0) .. "/" .. (st.pts or 0) .. "  США ★",
            "P11.Op.Mid", w / 2 + 384, 98, cb, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        HoldBar(w / 2 + 384 - 170, 122, 170, SmoothVal("holdB", (st.holdB or 0) / HOLD_WIN), cb, CurTime())

        -- фишки точек под панелью (буква в цвете владельца, мягкая тень)
        local chips = {}
        for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
            if IsValid(e) and e:GetNWBool("P11_OpPoint", false) then
                chips[#chips + 1] = {
                    nm  = e.GetPointName and e:GetPointName() or "?",
                    ow  = e.GetOwnerFact and e:GetOwnerFact() or "",
                    cap = e.GetCapFact and e:GetCapFact() or "",
                }
            end
        end
        table.sort(chips, function(a, b) return a.nm < b.nm end)
        if #chips > 0 then
            local x = w / 2 - (#chips * 64) / 2
            for _, c in ipairs(chips) do
                local col = SIDE_COL[c.ow] or NEUTRAL_C
                local hot = c.cap ~= "" and c.cap ~= c.ow -- точку жмёт чужая сторона
                local a = hot and (140 + math.sin(CurTime() * 8) * 80) or 235
                -- тень
                draw.RoundedBox(6, x + 1, 145, 56, 26, Color(0, 0, 0, 120))
                draw.RoundedBox(6, x, 144, 56, 26, Color(14, 18, 26, a))
                surface.SetDrawColor(col.r, col.g, col.b, hot and (120 + math.sin(CurTime() * 8) * 80) or 60)
                surface.DrawOutlinedRect(x, 144, 56, 26, 1)
                draw.SimpleText(c.nm, "P11.Op.Mid", x + 28, 157, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                if hot then
                    draw.RoundedBox(3, x + 8, 172, 40, 3, SIDE_COL[c.cap] or NEUTRAL_C)
                end
                x = x + 64
            end
        end

        draw.SimpleText("в строю: ★ СССР ×" .. (st.nA or 0) ..
            "   ·   ★ США ×" .. (st.nB or 0),
            "P11.Op.Small", w / 2, 182, DIMC, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        return
    end

    if st.phase == "end" then
        draw.RoundedBox(8, w / 2 - 250, 92, 500, 38, Color(16, 40, 24, 228))
        surface.SetDrawColor(150, 230, 170, 50)
        surface.DrawOutlinedRect(w / 2 - 250, 92, 500, 38, 1)
        draw.SimpleText("★ ОПЕРАЦИЯ ЗАВЕРШЕНА — лидерборд на экране ★",
            "P11.Op.Mid", w / 2, 100, Color(150, 230, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

-- ============ МАЯКИ ТОЧЕК (v4.24.1 «МАЯК»): где лежат точки боя ============

hook.Add("HUDPaint", "P11.OpBeacons", function()
    local st = OpState()
    if st.phase ~= "battle" then return end
    local me = LocalPlayer()
    if not IsValid(me) then return end
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) and e:GetNWBool("P11_OpPoint", false) then
            local scr = (e:GetPos() + Vector(0, 0, 110)):ToScreen()
            if scr.visible then
                local ow = e.GetOwnerFact and e:GetOwnerFact() or ""
                local col = SIDE_COL[ow] or NEUTRAL_C
                local nm = e.GetPointName and e:GetPointName() or "?"
                local d = math.floor(me:GetPos():Distance(e:GetPos()))
                draw.SimpleTextOutlined("▼", "P11.Op.Big", scr.x, scr.y - 26, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
                draw.SimpleTextOutlined(nm .. " · " .. d .. " юн", "P11.Op.Small",
                    scr.x, scr.y + 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                    1, Color(0, 0, 0, 220))
            end
        end
    end
end)

-- ============ ЗОВ: ВЫБОР СТОРОНЫ (звёзды + живой счёт) ============

local function OpenPick()
    if IsValid(PickFrame) then PickFrame:Remove() end
    local f = vgui.Create("DFrame")
    f:SetSize(560, 336)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.T0 = SysTime()
    f.Paint = function(s, pw, ph)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(12, 0, 0, pw, ph, BG)
        -- v4.33.0: знамя — красная шапка с золотой каймой
        draw.RoundedBoxEx(12, 0, 0, pw, 58, Color(64, 36, 16, 255), true, true, false, false)
        surface.SetDrawColor(205, 60, 52, 90)
        surface.DrawRect(0, 0, pw, 3)
        surface.SetDrawColor(255, 205, 100, 120)
        surface.DrawLine(10, 58, pw - 10, 58)
        draw.SimpleText("★ ОПЕРАЦИЯ «РУБЕЖ» ★", "P11.Op.Big", pw / 2, 8,
            GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("вахты сброшены командованием — ВСТАНЬ ПОД ЗНАМЯ СТОРОНЫ",
            "P11.Op.Small", pw / 2, 36, Color(235, 220, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    f.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then f:Remove() end end
    PickFrame = f

    local info = vgui.Create("DLabel", f)
    info:SetPos(20, 66) info:SetSize(520, 30)
    info:SetFont("P11.Op.Small") info:SetTextColor(DIMC)
    info:SetContentAlignment(5)
    info:SetText("Выбранная сторона выдаёт солдата автоматически — бой за точки, 30 минут.")

    local function SidePanel(x, sideName, col, fac)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, 102) b:SetSize(258, 168) b:SetText("")
        b.Paint = function(s, pw, ph)
            local hv = s:IsHovered()
            draw.RoundedBox(10, 0, 0, pw, ph,
                Color(math.floor(col.r * 0.20), math.floor(col.g * 0.20), math.floor(col.b * 0.20), 255))
            surface.SetDrawColor(col.r, col.g, col.b, hv and 255 or 120)
            surface.DrawOutlinedRect(0, 0, pw, ph, 2)
            -- внутренняя золотая рамка при наведении
            if hv then
                surface.SetDrawColor(255, 205, 100, 120)
                surface.DrawOutlinedRect(4, 4, pw - 8, ph - 8, 1)
            end
            draw.SimpleText("★", "P11.Op.Huge", pw / 2, 16,
                hv and Color(255, 226, 140) or col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(sideName, "P11.Op.Title", pw / 2, 72,
                Color(240, 242, 246), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("встать под знамя", "P11.Op.Small", pw / 2, 116,
                DIMC, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("солдат выдаётся автоматом", "P11.Op.Small", pw / 2, 136,
                DIMC, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
        b.DoClick = function()
            net.Start("P11_OpPick")
                net.WriteString(fac)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            f:Remove()
        end
    end
    SidePanel(18,  "СССР",    USSR_COL, "rkka")
    SidePanel(284, "АМЕРИКА", USA_COL,  "eagle")

    -- живой счёт записи (обновляется сам)
    local cnt = vgui.Create("DLabel", f)
    cnt:SetPos(20, 280) cnt:SetSize(520, 20)
    cnt:SetFont("P11.Op.Mid") cnt:SetTextColor(Color(235, 232, 225)) cnt:SetContentAlignment(5)
    f.Think = function()
        local st = OpState()
        cnt:SetText("уже на рубеже:  ★ СССР ×" .. (st.nA or 0) ..
            "    ·    ★ США ×" .. (st.nB or 0))
    end

    local rw = vgui.Create("DLabel", f)
    rw:SetPos(20, 306) rw:SetSize(520, 18)
    rw:SetFont("P11.Op.Small") rw:SetTextColor(GOLD) rw:SetContentAlignment(5)
    rw:SetText("победителям 5000₽  ·  проигравшим 1000₽  ·  удержать ВСЕ точки 3:00 — досрочная победа")
end

net.Receive("P11_OpUI", function()
    local msg = net.ReadString() or ""
    if msg == "call" then
        OpenPick()
    elseif msg == "battle" then
        if IsValid(PickFrame) then PickFrame:Remove() end
    elseif string.sub(msg, 1, 7) == "joined|" then
        if IsValid(PickFrame) then PickFrame:Remove() end
    end
end)

-- ============ ЛИДЕРБОРД (баннер победителя + медали мест) ============

net.Receive("P11_OpBoard", function()
    local ok, b = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(b) then return end
    if IsValid(BoardFrame) then BoardFrame:Remove() end

    local wcol = (b.winner == "rkka") and USSR_COL or (b.winner == "eagle") and USA_COL
        or Color(120, 200, 140)

    local f = vgui.Create("DFrame")
    f:SetSize(560, 480)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.T0 = SysTime()
    f.Paint = function(s, pw, ph)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(12, 0, 0, pw, ph, BG)
        -- v4.33.0: шапка в цвет победителя + золотая кайма
        draw.RoundedBoxEx(12, 0, 0, pw, 66, Color(20, 44, 28, 255), true, true, false, false)
        draw.RoundedBoxEx(12, 0, 0, pw, 4, wcol, true, true, false, false)
        surface.SetDrawColor(255, 205, 100, 100)
        surface.DrawLine(12, 66, pw - 12, 66)
        draw.SimpleText("★ ЛИДЕРБОРД ОПЕРАЦИИ ★", "P11.Op.Big", pw / 2, 8,
            GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("★  " .. tostring(b.wname or "") .. "  ★", "P11.Op.Mid", pw / 2, 40,
            wcol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    f.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then f:Remove() end end
    BoardFrame = f
    timer.Simple(25, function() if IsValid(f) then f:Remove() end end)

    -- три карточки статистики
    local function Card(x, title, line, col)
        local p = vgui.Create("DPanel", f)
        p:SetPos(x, 82) p:SetSize(168, 66)
        p.Paint = function(s, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, PANE)
            surface.SetDrawColor(255, 255, 255, 16)
            surface.DrawOutlinedRect(0, 0, pw, ph, 1)
            draw.SimpleText(title, "P11.Op.Small", pw / 2, 8, DIMC,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(line, "P11.Op.Small", pw / 2, 30, col or Color(232, 235, 240),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end
    Card(16,  "УДЕРЖАНИЕ ВСЕХ ТОЧЕК",
        "СССР " .. FmtTime(b.holdA or 0) .. "  ·  США " .. FmtTime(b.holdB or 0))
    Card(196, "ФРАГИ СТОРОН",
        "СССР " .. (b.killsA or 0) .. "  ·  США " .. (b.killsB or 0))
    Card(376, "ВЫПЛАТЫ УЧАСТНИКАМ",
        "+" .. (b.winPay or 5000) .. "₽ / +" .. (b.losePay or 1000) .. "₽", GOLD)

    local hd = vgui.Create("DLabel", f)
    hd:SetPos(24, 162) hd:SetSize(512, 24)
    hd:SetFont("P11.Op.Mid") hd:SetTextColor(Color(150, 200, 255))
    hd:SetText("ТОП БОЙЦОВ ПО ФРАГАМ")

    local MEDAL = {
        [1] = Color(255, 210, 90),
        [2] = Color(210, 215, 225),
        [3] = Color(205, 145, 90),
    }
    local y = 194
    for i, rec in ipairs(b.top or {}) do
        if i > 8 then break end
        local row = vgui.Create("DPanel", f)
        row:SetPos(24, y) row:SetSize(512, 30)
        local fac = (rec.fac == "eagle") and "США" or "СССР"
        local col = (rec.fac == "eagle") and USA_COL or USSR_COL
        local mcol = MEDAL[i] or Color(120, 126, 136)
        row.Paint = function(s, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, i % 2 == 0 and Color(20, 26, 34, 255) or Color(16, 21, 28, 255))
            draw.SimpleText("●", "P11.Op.Mid", 12, ph / 2, mcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(i .. ". " .. tostring(rec.name or "?"), "P11.Op.Mid", 40, ph / 2,
                Color(232, 235, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(fac, "P11.Op.Small", pw - 110, ph / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText((rec.k or 0) .. " фр.", "P11.Op.Mid", pw - 12, ph / 2,
                Color(232, 235, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        y = y + 32
    end
    if #(b.top or {}) == 0 then
        local no = vgui.Create("DLabel", f)
        no:SetPos(24, y) no:SetSize(512, 22)
        no:SetFont("P11.Op.Small") no:SetTextColor(DIMC)
        no:SetText("Без крови — точки дрались на нервах.")
    end
end)

-- ============ ВКЛАДКА ОПЕРАЦИИ (из C-меню) ============

function P11.OpenOps()
    if IsValid(OpsFrame) then OpsFrame:Remove() end
    local st = OpState()

    local f = vgui.Create("DFrame")
    f:SetSize(520, 380)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.T0 = SysTime()
    OpsFrame = f
    f.Paint = function(s, pw, ph)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(12, 0, 0, pw, ph, BG)
        draw.RoundedBoxEx(12, 0, 0, pw, 54, PANE, true, true, false, false)
        draw.RoundedBoxEx(12, 0, 0, pw, 3, Color(205, 60, 52, 200), true, true, false, false)
        surface.SetDrawColor(255, 205, 100, 60)
        surface.DrawLine(10, 54, pw - 10, 54)
        draw.SimpleText("★ ОПЕРАЦИИ", "P11.Op.Big", 18, 12, GOLD)
        draw.SimpleText("«РУБЕЖ» — бой сторон за точки", "P11.Op.Small",
            pw - 18, 20, DIMC, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
    f.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then f:Remove() end end

    -- статус-карта
    local stat = vgui.Create("DPanel", f)
    stat:SetPos(18, 66) stat:SetSize(484, 120)
    stat.Paint = function(s, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, PANE)
        surface.SetDrawColor(255, 255, 255, 16)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
    end
    local stl = vgui.Create("DLabel", stat)
    stl:SetPos(16, 12) stl:SetSize(452, 100)
    stl:SetFont("P11.Op.Small") stl:SetTextColor(Color(228, 231, 236))
    local txt = "Сейчас тихо. Командование (ранг 4+) может объявить операцию: сброс вахт, " ..
        "выбор стороны со звёздой, случайные точки захвата, бой 30 минут. Удержать ВСЕ точки " ..
        "3 минуты — досрочная победа. Награды: 5000₽ победителям, 1000₽ остальным."
    if st.phase == "recruit" then
        txt = "ИДЁТ ЗАПИСЬ СТОРОН: осталось " .. FmtTime(st.left) ..
            ". Уже записались: ★ СССР ×" .. (st.nA or 0) .. ", ★ США ×" .. (st.nB or 0) ..
            ". Окно выбора — у всех на экране!"
    elseif st.phase == "battle" then
        txt = "БОЙ! ★ СССР " .. (st.ownA or 0) .. "/" .. (st.pts or 0) .. " (серия " ..
            FmtTime(st.holdA or 0) .. ")  —  ★ США " .. (st.ownB or 0) .. "/" .. (st.pts or 0) ..
            " (серия " .. FmtTime(st.holdB or 0) .. "). До конца " .. FmtTime(st.left) ..
            ". В строю: ×" .. (st.nA or 0) .. " против ×" .. (st.nB or 0) .. "."
    elseif st.phase == "end" then
        txt = "Финал: лидерборд на экранах участников, выплаты ушли."
    end
    stl:SetText(txt)
    stl:SetWrap(true) stl:SetAutoStretchVertical(true)

    local yb = 202
    if P11FW.Config.Admin(LocalPlayer()) then
        local function AdmBtn(y, txt2, col, msg)
            local b = vgui.Create("DButton", f)
            b:SetPos(18, y) b:SetSize(484, 44) b:SetText("")
            b.Paint = function(s, pw, ph)
                draw.RoundedBox(8, 0, 0, pw, ph, s:IsHovered() and
                    Color(col.r + 25, col.g + 25, col.b + 25, 255) or col)
                surface.SetDrawColor(255, 255, 255, 26)
                surface.DrawOutlinedRect(0, 0, pw, ph, 1)
                draw.SimpleText(txt2, "P11.Op.Mid", pw / 2, ph / 2, Color(242, 242, 246),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                net.Start("P11_OpPick")
                    net.WriteString(msg)
                net.SendToServer()
                surface.PlaySound("buttons/button15.wav")
                f:Remove()
            end
        end
        if st.phase == "idle" then
            AdmBtn(yb, "▲ ОБЪЯВИТЬ ОПЕРАЦИЮ (станция услышит)", Color(140, 90, 30, 255), "adm_start")
        else
            AdmBtn(yb, "✕ ЗАВЕРШИТЬ/ОТМЕНИТЬ ОПЕРАЦИЮ", Color(120, 30, 26, 255), "adm_stop")
        end
        yb = yb + 54
    end

    if (st.phase == "recruit" or st.phase == "battle")
        and LocalPlayer():GetNWString("P11_OpSide", "") == "" then
        local jb = vgui.Create("DButton", f)
        jb:SetPos(18, yb) jb:SetSize(484, 40) jb:SetText("")
        jb.Paint = function(s, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, s:IsHovered() and Color(60, 90, 50, 255) or Color(40, 62, 34, 255))
            draw.SimpleText("ВСТУПИТЬ В ОПЕРАЦИЮ (выбрать сторону)", "P11.Op.Mid", pw / 2, ph / 2,
                Color(190, 240, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        jb.DoClick = function()
            f:Remove()
            OpenPick()
        end
    end

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(18, 336) hint:SetSize(484, 20)
    hint:SetFont("P11.Op.Small") hint:SetTextColor(DIMC) hint:SetContentAlignment(5)
    hint:SetText("канал рации стороны закрепляется сам: ★ СССР / ★ США · маяки точек — «▼ А · N юн»")
end

print("[POLUS-11] ОПЕРАЦИИ «РУБЕЖ» (client) v4.24.2 «ЗНАМЯ»: звёзды, живой счёт, бары серий, медали")
