-- ============================================================
--  ПОЛЮС-11 — HUD МУТАЦИЙ НЕЧТО (client) v4.2
--  Счётчик жертв, прогресс до следующего тира, список баффов.
-- ============================================================

surface.CreateFont("P11.Mut.Big",   { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.Mut.Small", { font = "Roboto", size = 14, weight = 600, extended = true })
surface.CreateFont("P11.Mut.Tiny",  { font = "Roboto", size = 12, weight = 500, extended = true })

local MUTS = {
    { need = 3,  name = "РЕГЕНЕРАЦИЯ", desc = "плоть зарастает, бег +8%" },
    { need = 5,  name = "МЯСОГИГАНТ",  desc = "+60 ХП, когти +10" },
    { need = 10, name = "АРАХНА",      desc = "паучья туша: +20% бег, прыжки" },
}

hook.Add("HUDPaint", "P11.MutationHUD", function()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if not me:GetNWBool("P11_Infected", false) then return end
    if P11B and P11B.open then return end -- v4.2.1: TAB v2 вместо vgui-панели

    local kills = me:GetNWInt("P11_MutKills", 0)
    local tier  = me:GetNWInt("P11_MutTier", 0)

    local w, h = 240, 96 + 22 * #MUTS
    local x, y = ScrW() - w - 20, ScrH() - h - 20

    -- панель телесного роста
    draw.RoundedBox(8, x, y, w, h, Color(22, 8, 10, 200))
    surface.SetDrawColor(160, 50, 55, 170)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    draw.SimpleText("🩸 МУТАЦИИ ТВАРИ", "P11.Mut.Big", x + 12, y + 10,
        Color(255, 120, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("жертв: " .. kills, "P11.Mut.Small", x + w - 12, y + 14,
        Color(220, 180, 180), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- прогресс до следующего тира
    local nextNeed = nil
    for _, m in ipairs(MUTS) do
        if kills < m.need then nextNeed = m.need break end
    end
    if nextNeed then
        local prev = (nextNeed == 3 and 0) or (nextNeed == 5 and 3) or 5
        local frac = math.Clamp((kills - prev) / (nextNeed - prev), 0, 1)
        draw.RoundedBox(4, x + 12, y + 42, w - 24, 12, Color(50, 22, 24, 230))
        draw.RoundedBox(4, x + 12, y + 42, (w - 24) * frac, 12, Color(200, 60, 60, 230))
        draw.SimpleText("до мутации: " .. kills .. "/" .. nextNeed, "P11.Mut.Tiny",
            x + w / 2, y + 48, Color(240, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("ПИК ЭВОЛЮЦИИ", "P11.Mut.Small", x + w / 2, y + 44,
            Color(255, 150, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- перечень мутаций
    local unlocked = 0
    for i, m in ipairs(MUTS) do
        local got = kills >= m.need
        if got then unlocked = unlocked + 1 end
        local yy = y + 66 + (i - 1) * 22
        draw.SimpleText((got and "✔ " or "○ ") .. m.name .. " (" .. m.need .. ")",
            "P11.Mut.Small", x + 12, yy,
            got and Color(255, 140, 130) or Color(130, 95, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if got then
            draw.SimpleText(m.desc, "P11.Mut.Tiny", x + w - 12, yy + 2,
                Color(190, 150, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end

    if tier > 0 then
        draw.SimpleText("тир: " .. tier .. "/3", "P11.Mut.Tiny", x + 12, y + h - 20,
            Color(255, 180, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- v4.2.1: чья личина надета (имя + документ жертвы)
    local fake = me:GetNWString("P11_FakeNick", "")
    if fake ~= "" then
        local docc = me:GetNWString("P11_DocCode", "")
        draw.SimpleText("личина: " .. fake .. (docc ~= "" and (" · " .. docc) or ""), "P11.Mut.Tiny",
            x + w - 12, y + h - 20, Color(205, 175, 175), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
end)

print("[POLUS-11] HUD мутаций загружен")
