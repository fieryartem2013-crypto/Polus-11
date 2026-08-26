-- ============================================================
--  ПОЛЮС-11 — виджет задач смены (клиент)
--  Слева на экране: список дел должности, прогресс, галочки.
--  v4.8.2 «ДОКЛАД»: жалоба «текст залез» — рамка считала ширину
--  только по строкам задач, а заголовок «— НАЗНАЧЕННЫЕ С
--  ТЕРМИНАЛА» и длинные названия вылезали за её край на чужие
--  элементы HUD. Теперь: ширина рамки = максимум по ВСЕМ строкам
--  (заголовок/разделитель включены), но не шире MAXW — длинные
--  строки усекаются с «…», фон гуще (читается поверх маркеров).
-- ============================================================

surface.CreateFont("P11.Task.Title", { font = "Roboto", size = 19, weight = 700, extended = true })
surface.CreateFont("P11.Task.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })

POLUS11.Tasks = POLUS11.Tasks or {}

net.Receive("P11_TaskSync", function()
    local tbl = util.JSONToTable(net.ReadString() or "[]")
    if istable(tbl) then POLUS11.Tasks = tbl end
end)

-- усечение строки до MAXW с многоточием (v4.8.2)
local MAXW = 340
local SEP_TXT = "— НАЗНАЧЕННЫЕ С ТЕРМИНАЛА"

local function ClipRow(txt)
    surface.SetFont("P11.Task.Text")
    local w = surface.GetTextSize(txt) or 0
    if w <= MAXW then return txt, w end
    local t = txt
    while #t > 10 do
        t = string.sub(t, 1, #t - 4)
        local tt = t .. "…"
        w = surface.GetTextSize(tt) or 0
        if w <= MAXW then return tt, w end
    end
    return t .. "…", w
end

hook.Add("HUDPaint", "P11_TasksHud", function()
    if not POLUS11.Config.Tasks then return end
    local rows = POLUS11.Tasks
    if not rows or #rows == 0 then return end

    -- не рисовать поверх плашки наказания
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local y0 = 158 -- v4.6.3: чуть ниже, под баннерами/часами смены
    if me:GetNWString("P11FW_Punish", "") ~= "" then y0 = 208 end
    -- v3.8: идёт баннер приказа командира — список задач сползает ниже,
    -- чтобы не наезжать друг на друга
    if P11 and P11.OrderLive and CurTime() < P11.OrderLive and y0 < 234 then
        y0 = 234
    end

    -- v4.8.2: одна подготовка строк — и меряем, и рисуем одно и то же
    local x = 16
    local widest = 0
    local disp = {}
    for i, r in ipairs(rows) do
        local txt = r.done
            and ("✔ " .. r.name)
            or  ("• " .. r.name .. "  —  " .. r.cur .. "/" .. r.max)
        local dt, dw = ClipRow(txt)
        disp[i] = dt
        if dw > widest then widest = dw end
    end
    -- заголовок рамки тоже участвует в ширине
    surface.SetFont("P11.Task.Title")
    local wt = surface.GetTextSize("ЗАДАЧИ СМЕНЫ") or 0
    if wt > widest then widest = wt end
    -- разделитель «с терминала» тоже
    local hasExtra = false
    for _, r in ipairs(rows) do if r.extra then hasExtra = true break end end
    if hasExtra then
        surface.SetFont("P11.Task.Text")
        local ws = surface.GetTextSize(SEP_TXT) or 0
        if ws > widest then widest = ws end
    end

    local h = 40 + #rows * 26
    if hasExtra then h = h + 34 end

    -- фон гуще: поверх игровых маркеров читается без «двоения»
    draw.RoundedBox(8, x - 8, y0 - 8, widest + 28, h, Color(8, 12, 18, 205))
    draw.SimpleText("ЗАДАЧИ СМЕНЫ", "P11.Task.Title", x, y0 + 6, Color(140, 190, 235))

    -- v4.6.3: строки задач налезали друг на друга — честная сетка с
    -- вычислением высоты ПО ХОДУ, а не магическими сдвигами.
    local ROWH = 26
    local shownSep = false
    local yy = y0 + 34
    for i, r in ipairs(rows) do
        if r.extra and not shownSep then
            shownSep = true
            yy = yy + 8
            draw.SimpleText(SEP_TXT, "P11.Task.Text", x, yy, Color(230, 190, 100)) -- v4.8.2: было x - 8 (вылезал влево)
            yy = yy + ROWH
        end
        draw.SimpleText(disp[i], "P11.Task.Text", x, yy,
            r.done and Color(120, 220, 140) or (r.extra and Color(230, 200, 130) or Color(210, 218, 228)))
        yy = yy + ROWH
    end
end)
