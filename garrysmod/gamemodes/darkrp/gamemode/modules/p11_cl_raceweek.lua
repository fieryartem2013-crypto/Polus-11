-- ============================================================
--  ПОЛЮС-11 — «ЛЕДОКОЛ» (client) v4.20.0 «СЛЕД»
--  Полоска недельной гонки РККА vs ОРЁЛ над виджетом нарядов
--  (правый верх). Данные: SetGlobalString("P11_Race",
--  "неделя|ркка|орёл|бафф"). Знак ▲ — у фракции с баффом
--  недели (+20% к оплате нарядов у интенданта).
-- ============================================================

surface.CreateFont("P11.RACE.Tx",    { font = "Roboto", size = 14, weight = 700, extended = true })
surface.CreateFont("P11.RACE.Small", { font = "Roboto", size = 12, weight = 500, extended = true })

local function RaceRead()
    local s = GetGlobalString("P11_Race", "")
    if s == "" then return nil end
    local p = string.Explode("|", s)
    return {
        week = tostring(p[1] or ""),
        rkka = tonumber(p[2]) or 0,
        oryol = tonumber(p[3]) or 0,
        buff  = tostring(p[4] or ""),
    }
end

hook.Add("HUDPaint", "P11.RaceHUD", function()
    if P11B and P11B.open then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local r = RaceRead()
    if not r or r.week == "" then return end

    local x, y = ScrW() - 340, 68
    local w, h = 316, 28
    draw.RoundedBox(6, x, y, w, h, Color(8, 10, 16, 180))
    surface.SetDrawColor(120, 130, 150, 120)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    draw.SimpleText("ЛЕДОКОЛ", "P11.RACE.Tx", x + 10, y + h / 2, Color(255, 205, 100),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- РККА (красный квадрат) ─ счёт ─ ОРЁЛ (синий квадрат)
    draw.RoundedBox(2, x + 86, y + 8, 11, 11, Color(200, 60, 60))
    local rkT = "РККА " .. r.rkka .. (r.buff == "rkka" and " ▲" or "")
    draw.SimpleText(rkT, "P11.RACE.Tx", x + 102, y + h / 2, Color(230, 130, 120),
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local olT = r.oryol .. " ОРЁЛ" .. (r.buff == "oryol" and " ▲" or "")
    draw.SimpleText(olT, "P11.RACE.Tx", x + w - 26, y + h / 2, Color(130, 175, 245),
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.RoundedBox(2, x + w - 20, y + 8, 11, 11, Color(80, 130, 220))

    draw.SimpleText("сброс в пн", "P11.RACE.Small", x + w / 2, y + h / 2, Color(120, 126, 138),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

print("[POLUS-11] «ЛЕДОКОЛ» (client): полоска недельной гонки на HUD")
