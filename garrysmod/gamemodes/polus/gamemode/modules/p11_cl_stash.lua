-- ============================================================
--  ПОЛЮС-11 — КРИМИНАЛ: КЛАДМЕН (клиент) v4.24.0 «РУБЕЖ»
--  Маяк личной закладки: «► ЗАКЛАДКА · N м» через стены
--  (видит только владелец — NWVector P11_StashPos у игрока),
--  строка срока сверху. Никакого чужого эфира.
-- ============================================================

surface.CreateFont("P11.Stash.Mid", { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Stash.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

hook.Add("HUDPaint", "P11.StashHUD", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local p = me:GetNWVector("P11_StashPos", Vector(0, 0, -99999))
    if p.z < -90000 then return end

    -- строка срока
    local till = me:GetNWFloat("P11_StashTill", 0)
    local left = math.max(0, till - CurTime())
    local w = ScrW()
    draw.RoundedBox(8, w / 2 - 250, 60, 500, 30, Color(60, 20, 60, 210))
    draw.SimpleText("◆ ЗАКЛАДКА ПРИ ТЕБЕ — срок " .. string.format("%d:%02d",
        math.floor(left / 60), math.floor(left % 60)) .. " · спрятать: E в зоне",
        "P11.Stash.Small", w / 2, 66, Color(235, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- маяк сквозь стены
    local sp = p:ToScreen()
    if sp.visible then
        local x, y = sp.x, sp.y
        local d = math.floor(me:GetPos():Distance(p))
        draw.SimpleText("▼", "P11.Stash.Mid", x, y - 26, Color(255, 120, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЗАКЛАДКА · " .. d .. " юн", "P11.Stash.Mid", x, y,
            Color(255, 190, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

print("[POLUS-11] КЛАДМЕН (client) v4.24.0: маяк закладки через стены + срок")
