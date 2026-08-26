-- ============================================================
--  ПОЛЮС FRAMEWORK — красная плашка наказания (клиент)
--  Сверху экрана чуть краснее + статус + остаток времени.
-- ============================================================

surface.CreateFont("P11FW.Punish.Big",   { font = "Roboto", size = 34, weight = 800, extended = true })
surface.CreateFont("P11FW.Punish.Small", { font = "Roboto", size = 17, weight = 500, extended = true })

local TITLES = {
    arrest  = { txt = "ВЫ АРЕСТОВАНЫ",  col = Color(255, 120, 100) },
    slavery = { txt = "ВЫ В РАБСТВЕ",   col = Color(255, 150, 90)  },
    ban     = { txt = "ВЫ ЗАБАНЕНЫ",    col = Color(255, 70, 60)   },
}

hook.Add("HUDPaint", "P11FW.PunishBanner", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end

    local ptype = me:GetNWString("P11FW_Punish", "")
    if ptype == "" then return end

    local info = TITLES[ptype]
    if not info then return end

    local w = ScrW()

    -- верх экрана чуть краснее (двойная полупрозрачная заливка)
    draw.RoundedBox(0, 0, 0, w, 118, Color(info.col.r, info.col.g, info.col.b, 34))
    draw.RoundedBox(0, 0, 0, w, 74, Color(info.col.r, info.col.g, info.col.b, 46))
    surface.SetDrawColor(info.col.r, info.col.g, info.col.b, 170)
    surface.DrawRect(0, 116, w, 2)

    -- статус
    draw.SimpleTextOutlined(info.txt, "P11FW.Punish.Big", w / 2, 34, info.col,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))

    -- причина + остаток
    local reason = me:GetNWString("P11FW_PunishReason", "")
    local left = me:GetNWInt("P11FW_PunishLeft", 0)
    local sub
    if ptype == "ban" then
        sub = "Причина: " .. reason .. "  •  отключение..."
    else
        sub = "Причина: " .. reason .. "  •  осталось: " .. math.ceil(left / 60) .. " мин"
    end
    draw.SimpleTextOutlined(sub, "P11FW.Punish.Small", w / 2, 88, Color(240, 225, 220),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 160))
end)
