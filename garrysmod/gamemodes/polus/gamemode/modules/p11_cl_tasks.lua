-- ============================================================
--  ПОЛЮС-11 — виджет задач смены (клиент)
--  Слева на экране: список дел должности, прогресс, галочки.
-- ============================================================

surface.CreateFont("P11.Task.Title", { font = "Roboto", size = 19, weight = 700, extended = true })
surface.CreateFont("P11.Task.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })

POLUS11.Tasks = POLUS11.Tasks or {}

net.Receive("P11_TaskSync", function()
    local tbl = util.JSONToTable(net.ReadString() or "[]")
    if istable(tbl) then POLUS11.Tasks = tbl end
end)

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

    local x = 16
    local widest = 0
    surface.SetFont("P11.Task.Text")
    for _, r in ipairs(rows) do
        local txt = (r.done and "✔ " or "• ") .. r.name .. (r.done and "" or ("  —  " .. r.cur .. "/" .. r.max))
        local tw = surface.GetTextSize(txt) or 0
        if tw > widest then widest = tw end
    end

    local h = 40 + #rows * 26
    local hasExtra = false
    for _, r in ipairs(rows) do if r.extra then hasExtra = true break end end
    if hasExtra then h = h + 34 end

    draw.RoundedBox(8, x - 8, y0 - 8, widest + 28, h, Color(8, 12, 18, 150))
    draw.SimpleText("ЗАДАЧИ СМЕНЫ", "P11.Task.Title", x, y0 + 6, Color(140, 190, 235))

    -- v4.6.3: строки задач налезали друг на друга — честная сетка с
    -- вычислением высоты ПО ХОДУ, а не магическими сдвигами.
    local ROWH = 26 -- высота одной строки (шрифт 15px свободно дышит)
    local shownSep = false
    local yy = y0 + 34
    for i, r in ipairs(rows) do
        if r.extra and not shownSep then
            shownSep = true
            yy = yy + 8
            draw.SimpleText("— НАЗНАЧЕННЫЕ С ТЕРМИНАЛА", "P11.Task.Text", x - 8, yy, Color(230, 190, 100))
            yy = yy + ROWH
        end
        local txt = r.done
            and ("✔ " .. r.name)
            or  ("• " .. r.name .. "  —  " .. r.cur .. "/" .. r.max)
        draw.SimpleText(txt, "P11.Task.Text", x, yy,
            r.done and Color(120, 220, 140) or (r.extra and Color(230, 200, 130) or Color(210, 218, 228)))
        yy = yy + ROWH
    end
end)
