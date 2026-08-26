-- ============================================================
--  ПОЛЮС-11 — ЭКСТРЕННЫЙ СБОР (client) v5.0.0 «СБОР»
--  Баннер сбора с ПРИЧИНОЙ и таймером, маркер-стрелка к месту
--  сбора, фишка «ТЫ НА СБОРЕ» при входе в радиус, окно итога
--  переклички (20 сек).
-- ============================================================

surface.CreateFont("P11.Sbor.Title", { font = "Roboto", size = 26, weight = 900, extended = true })
surface.CreateFont("P11.Sbor.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Sbor.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

P11.Sbor = P11.Sbor or { list = {}, result = nil }

-- состояние: список активных сборов
net.Receive("P11_SborState", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "[]")
    if ok and istable(tbl) then P11.Sbor.list = tbl end
end)

-- итог переклички
net.Receive("P11_SborResult", function()
    local reason = net.ReadString()
    local byName = net.ReadString()
    local n = net.ReadUInt(8)
    local total = net.ReadUInt(8)
    local names = net.ReadString()
    P11.Sbor.result = { reason = reason, by = byName, n = n, total = total, names = names, t0 = SysTime() }
    surface.PlaySound("buttons/button15.wav")
end)

-- ============ HUD: баннер + маркер ============

hook.Add("HUDPaint", "P11.SborHUD", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local w, h = ScrW(), ScrH()
    local t = CurTime()

    for _, s in ipairs(P11.Sbor.list or {}) do
        -- баннер сверху (под полосой операций/рейдов, y=200)
        local left = s.left or 0
        local pulse = left < 15 and (0.5 + math.sin(t * 6) * 0.5) or 0
        local bcol = Color(58, 16, 12, 235 + 20 * pulse)
        draw.RoundedBox(8, w / 2 - 360, 200, 720, 54, bcol)
        surface.SetDrawColor(255, 205, 100, 90 + math.sin(t * 1.4) * 20)
        surface.DrawRect(w / 2 - 360, 200, 720, 2)
        draw.RoundedBoxEx(8, w / 2 - 360, 200, 5, 54, Color(205, 60, 52, 255), true, false, true, false)
        surface.SetDrawColor(255, 170, 140, left < 15 and (90 + 120 * pulse) or 40)
        surface.DrawOutlinedRect(w / 2 - 360, 200, 720, 54, 1)

        draw.SimpleText("⚠ ЭКСТРЕННЫЙ СБОР — " .. tostring(s.reason or ""),
            "P11.Sbor.Title", w / 2, 208, Color(255, 200, 180),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("место: " .. tostring(s.by or "") .. " · явиться за " .. left .. " сек",
            "P11.Sbor.Small", w / 2, 238, Color(235, 225, 210),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- маркер-стрелка к месту (3D)
        local sp = Vector(s.x or 0, s.y or 0, s.z or 0)
        local dist = me:GetPos():Distance(sp)
        local onSpot = dist <= 400
        local scr = (sp + Vector(0, 0, 120)):ToScreen()
        if scr.visible then
            local col = onSpot and Color(120, 230, 140) or Color(255, 170, 140)
            draw.SimpleTextOutlined("▼ СБОР", "P11.Sbor.Mid", scr.x, scr.y - 30, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
            draw.SimpleTextOutlined(math.floor(dist) .. " юн", "P11.Sbor.Small",
                scr.x, scr.y - 6, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
        end
        -- фишка «ты на сборе»
        if onSpot and me:Alive() then
            draw.SimpleText("★ ТЫ НА СБОРЕ ★", "P11.Sbor.Mid", w / 2, 262,
                Color(150, 240, 160, 200 + 55 * math.sin(t * 4)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- итог переклички (20 сек)
    local r = P11.Sbor.result
    if r and SysTime() - r.t0 < 20 then
        local a = math.Clamp(20 - (SysTime() - r.t0), 0, 1) * 255
        local bw, bh = 560, 96
        local bx, by = w / 2 - bw / 2, h * 0.30
        draw.RoundedBox(10, bx, by, bw, bh, Color(14, 12, 10, 235 * a / 255))
        surface.SetDrawColor(255, 205, 100, 100 * a / 255)
        surface.DrawOutlinedRect(bx, by, bw, bh, 1)
        draw.SimpleText("СБОР ЗАВЕРШЁН: «" .. r.reason .. "»", "P11.Sbor.Mid", w / 2, by + 12,
            Color(255, 205, 100, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("явились " .. r.n .. " из " .. r.total ..
            (r.names ~= "" and (" · " .. r.names) or ""),
            "P11.Sbor.Small", w / 2, by + 44, Color(235, 225, 210, a),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("объявил(а): " .. r.by, "P11.Sbor.Small", w / 2, by + 68,
            Color(170, 180, 195, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

print("[POLUS-11] ЭКСТРЕННЫЙ СБОР (client) v5.0.0 «СБОР»: баннер причины + маркер места + итог")
