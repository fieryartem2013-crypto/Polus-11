-- ============================================================
--  ПОЛЮС-11 — ОНБОРДИНГ «ПЕРВЫЙ ДЕНЬ» (client) v4.20.0 «СЛЕД»
--  Плашка плана новичка справа (под нарядами). Данные: NWInt
--  P11_OnbStep (0 скрыто / 1..5 шаг / 6 — пройдено, гасим).
--  Имена шагов зеркалят сервер (modules/p11_sv_onboard).
-- ============================================================

surface.CreateFont("P11.ONB.Mid", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11.ONB.Tx",  { font = "Roboto", size = 14, weight = 500, extended = true })

local ONB_STEPS = {
    [1] = "Возьми должность (F4 или кадровик)",
    [2] = "Купи товар в ларьке снабжения (E по торговцу)",
    [3] = "Обыщи ящик/бочку/тайник по станции",
    [4] = "Возьми наряд у интенданта (стойка «НАРЯДНИК»)",
    [5] = "Закрой взятый наряд до конца",
}

hook.Add("HUDPaint", "P11.OnboardHUD", function()
    if P11B and P11B.open then return end -- под ТАБом не лезем
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    local step = me:GetNWInt("P11_OnbStep", 0)
    if step < 1 or step > 5 then return end

    local x, y = ScrW() - 340, 250
    local w, h = 316, 60
    draw.RoundedBox(6, x, y, w, h, Color(8, 14, 12, 190))
    surface.SetDrawColor(110, 215, 140, 160)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText("ПЕРВЫЙ ДЕНЬ · шаг " .. step .. "/5", "P11.ONB.Mid",
        x + 10, y + 8, Color(110, 215, 140))
    draw.SimpleText(ONB_STEPS[step] or "", "P11.ONB.Tx",
        x + 10, y + 32, Color(226, 232, 238))

    -- шкала пройденного
    for i = 1, 5 do
        local bx = x + 10 + (i - 1) * 24
        draw.RoundedBox(2, bx, y + h - 9, 18, 4,
            i < step and Color(110, 215, 140) or Color(60, 66, 74))
    end
end)

print("[POLUS-11] онбординг «ПЕРВЫЙ ДЕНЬ» (client): плашка плана новичка")
