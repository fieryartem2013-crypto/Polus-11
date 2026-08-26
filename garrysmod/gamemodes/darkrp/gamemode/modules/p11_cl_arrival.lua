-- ============================================================
--  ПОЛЮС-11 — ЗОНА ПРИБЫТИЯ (client) v4.5.0
--  Кинематографическая заставка «Колонна доставила тебя» при
--  первом заходе, если для твоей фракции поставлена зона.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.Ar.Big",   { font = "Roboto", size = 44, weight = 800, extended = true })
surface.CreateFont("P11.Ar.Small", { font = "Roboto", size = 18, weight = 500, extended = true })

local fxT0 = 0
local fxFac = ""

net.Receive("P11_ArrivalFX", function()
    fxT0 = CurTime()
    fxFac = net.ReadString()
    surface.PlaySound("ambient/alarms/warningbell1.wav")
end)

hook.Add("HUDPaint", "P11.ArrivalFX", function()
    if fxT0 == 0 then return end
    local age = CurTime() - fxT0
    if age > 6 then fxT0 = 0 return end

    -- раскрыть 0..1 (0.5с), держать, погасить (последняя 1с)
    local a
    if age < 0.5 then a = age / 0.5
    elseif age > 5 then a = math.Clamp((6 - age) / 1, 0, 1)
    else a = 1 end

    surface.SetAlphaMultiplier(a * 0.92)
    draw.RoundedBox(0, 0, ScrH() * 0.30, ScrW(), 120, Color(8, 11, 16, 210))
    surface.SetDrawColor(120, 185, 255, 200)
    surface.DrawRect(0, ScrH() * 0.30, ScrW(), 2)
    surface.DrawRect(0, ScrH() * 0.30 + 118, ScrW(), 2)

    draw.SimpleText("КОЛОННА ДОСТАВИЛА ТЕБЯ", "P11.Ar.Big", ScrW() / 2, ScrH() * 0.30 + 40,
        Color(228, 236, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local facName = fxFac
    for _, c in ipairs(P11FW.CategoryList or {}) do
        if c.id == fxFac then facName = c.name break end
    end
    draw.SimpleText("грузовик остановился • впереди «ПОЛЮС-11» • зона: " .. string.upper(facName),
        "P11.Ar.Small", ScrW() / 2, ScrH() * 0.30 + 88,
        Color(150, 180, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    surface.SetAlphaMultiplier(1)
end)
