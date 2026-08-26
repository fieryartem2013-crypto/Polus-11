-- ============================================================
--  ПОЛЮС-11 — КУБ-МАРКЕРЫ ТОЧЕК СПАВНА (client) v4.8.4 «ВЫСАДКА»
--  По заявке владельца: «чтобы спавн ставился ВИДЕ КУБИКОВ на
--  5 сек, чтобы было видно, где будет спавн». Когда админ
--  ставит точку (/menu → УТИЛИТЫ, p11_arrival, polus_fw_setspawn),
--  сервер шлёт P11_SpawnMark → на месте точки прорастает
--  полупрозрачный силуэт бойца (36×36×72, как хулл игрока)
--  с табличкой ЧТО это за точка и обратным отсчётом.
--  Команда «СПИСОК СПАВНОВ» показывает ВСЕ точки разом (8 сек).
-- ============================================================

P11 = P11 or {}
P11.SpawnMarks = P11.SpawnMarks or {}

local KIND = {
    [1] = { col = Color(120, 255, 140), name = "СПАВН ПРОФЫ" },
    [2] = { col = Color(90, 200, 255),  name = "ЗОНА ФРАКЦИИ" },
    [3] = { col = Color(255, 220, 90),  name = "ОБЩИЙ СПАВН" },
    [4] = { col = Color(255, 90, 90),   name = "КАМЕРА АРЕСТА" },
    [5] = { col = Color(255, 170, 80),  name = "ГРУЗОВИК КОЛОННЫ" },
}

surface.CreateFont("P11.MarkFont",   { font = "Tahoma", size = 30, weight = 800, antialias = true })
surface.CreateFont("P11.MarkFontSm", { font = "Tahoma", size = 22, weight = 800, antialias = true })

net.Receive("P11_SpawnMark", function()
    local pos   = net.ReadVector()
    local yaw   = net.ReadFloat()
    local kind  = net.ReadUInt(3)
    local label = net.ReadString()
    local dur   = net.ReadFloat()
    if not (pos and isvector(pos)) then return end
    P11.SpawnMarks[#P11.SpawnMarks + 1] = {
        pos = pos, ang = Angle(0, yaw or 0, 0), kind = kind,
        label = tostring(label or "СПАВН"), deadline = CurTime() + ((tonumber(dur) or 5) > 0 and dur or 5),
        born = CurTime(),
    }
    if #P11.SpawnMarks > 40 then table.remove(P11.SpawnMarks, 1) end
end)

hook.Add("PostDrawTranslucentRenderables", "P11.SpawnMarkDraw", function()
    if #P11.SpawnMarks == 0 then return end
    local now = CurTime()
    for i = #P11.SpawnMarks, 1, -1 do
        local m = P11.SpawnMarks[i]
        if now > m.deadline + 0.8 then
            table.remove(P11.SpawnMarks, i)
        else
            local left = m.deadline - now
            local a = 255
            if left < 0 then
                a = math.max(0, 255 * (1 + left / 0.8)) -- 0.8с затухания в конце
            end
            local k = KIND[m.kind] or KIND[1]

            -- мягкое «прорастание» в первые 0.25с
            local age = now - m.born
            local puff = (age < 0.25) and ((1 - age / 0.25) * 5) or 0

            local he = 18 + puff
            local mins = Vector(-he, -he, -36 - puff * 2)
            local maxs = Vector(he, he, 36 + puff * 2)
            local center = m.pos + Vector(0, 0, 36)

            render.SetColorMaterial()
            render.DrawBox(center, m.ang, mins, maxs,
                Color(k.col.r, k.col.g, k.col.b, math.min(80, a * 0.30)))
            render.DrawWireframeBox(center, m.ang, mins, maxs,
                Color(k.col.r, k.col.g, k.col.b, a), true)

            -- «ноги» — метка земли, чтобы точку видно было издалека
            render.DrawWireframeBox(m.pos + Vector(0, 0, 1), m.ang,
                Vector(-24, -24, -1), Vector(24, 24, 1),
                Color(k.col.r, k.col.g, k.col.b, math.min(160, a)), true)

            -- парящая табличка: вид точки + обратный отсчёт
            local top = m.pos + Vector(0, 0, 92)
            local bang = (top - EyePos()):Angle()
            bang = Angle(0, bang.y - 90, 90)
            cam.Start3D2D(top, bang, 0.10)
                draw.SimpleTextOutlined("⬢ " .. k.name, "P11.MarkFontSm", 0, -22,
                    Color(k.col.r, k.col.g, k.col.b, a),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a))
                draw.SimpleTextOutlined(m.label, "P11.MarkFont", 0, 4,
                    Color(255, 255, 255, a),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a))
                draw.SimpleTextOutlined(string.format("%.0f", math.max(0, left)) .. "с",
                    "P11.MarkFontSm", 0, 30, Color(220, 226, 236, a),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a))
            cam.End3D2D()
        end
    end
end)

print("[P11-SPAWN-VIZ] куб-маркеры спавна (v4.8.4) — точку спавна покажут силуэтом на 5 сек")
