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
    local y0 = 150
    if me:GetNWString("P11FW_Punish", "") ~= "" then y0 = 200 end

    local x = 16
    local widest = 0
    surface.SetFont("P11.Task.Text")
    for _, r in ipairs(rows) do
        local txt = (r.done and "✔ " or "• ") .. r.name .. (r.done and "" or ("  —  " .. r.cur .. "/" .. r.max))
        local tw = surface.GetTextSize(txt) or 0
        if tw > widest then widest = tw end
    end

    local h = 34 + #rows * 22
    local hasExtra = false
    for _, r in ipairs(rows) do if r.extra then hasExtra = true break end end
    if hasExtra then h = h + 22 end

    draw.RoundedBox(8, x - 8, y0 - 8, widest + 28, h, Color(8, 12, 18, 150))
    draw.SimpleText("ЗАДАЧИ СМЕНЫ", "P11.Task.Title", x, y0 + 6, Color(140, 190, 235))

    local shownSep = false
    for i, r in ipairs(rows) do
        local yy = y0 + 28 + (i - 1) * 22
        if r.extra and not shownSep then
            shownSep = true
            yy = yy + 16
            draw.SimpleText("— НАЗНАЧЕННЫЕ С ТЕРМИНАЛА", "P11.Task.Text", x - 8, yy, Color(230, 190, 100))
            yy = yy + 6
        elseif shownSep then
            yy = yy + 22
        end
        local txt = r.done
            and ("✔ " .. r.name)
            or  ("• " .. r.name .. "  —  " .. r.cur .. "/" .. r.max)
        draw.SimpleText(txt, "P11.Task.Text", x, yy,
            r.done and Color(120, 220, 140) or (r.extra and Color(230, 200, 130) or Color(210, 218, 228)))
    end
end)
