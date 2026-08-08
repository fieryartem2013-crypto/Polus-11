-- ============================================================
--  ПОЛЮС-11 — РАЗУМ ЖЕРТВЫ: «ЧТЕНИЕ МЕТОК» (client) v4.19.4
--  Навык усвоенного следователя НКВД: Нечто (флаг сервера
--  P11_MindSled) видит над головами людей ИСТИННЫЕ метки
--  допуска — настоящую должность сквозь любой грим, а чужая
--  личина подсвечивается красным «⚠ ЛИЧИНА». Сквозь стены
--  (разум жертвы чуяет документы), дальность 900 юн.
-- ============================================================

surface.CreateFont("P11.Mind.Mark", { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("P11.Mind.Warn", { font = "Roboto", size = 12, weight = 700, extended = true })

local MARK_DIST = 900 * 900

hook.Add("HUDPaint", "P11.MindMarks", function()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if not me:GetNWBool("P11_MindSled", false) then return end
    if not (P11FW and P11FW.GetJob) then return end

    local myPos = me:GetPos()
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= me and IsValid(ply) and ply:Alive() then
            if myPos:DistToSqr(ply:GetPos()) < MARK_DIST then
                local pos = (ply:EyePos() + Vector(0, 0, 26)):ToScreen()
                if pos.visible then
                    -- истинная должность (команда, НЕ личина)
                    local job = P11FW.GetJob(ply)
                    local jn = (job and job.name) or "?"
                    local jc = (job and job.color) or Color(150, 190, 235)

                    local frac = 1 - math.sqrt(myPos:DistToSqr(ply:GetPos())) / 900
                    local a = math.Clamp(frac * 255, 45, 235)

                    -- чужая личина на нём? (FakeJob ≠ истинная команда)
                    local faked = false
                    local fj = ply:GetNWInt("P11_FakeJob", 0)
                    if fj > 0 and fj ~= ply:Team() then faked = true end
                    local fakeNick = ply:GetNWString("P11_FakeNick", "")

                    draw.SimpleTextOutlined("ДОПУСК: " .. jn, "P11.Mind.Mark",
                        pos.x, pos.y - 10, Color(jc.r, jc.g, jc.b, a),
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.75))

                    if faked then
                        local blink = 0.6 + math.sin(CurTime() * 7) * 0.4
                        draw.SimpleTextOutlined("⚠ ЛИЧИНА" .. (fakeNick ~= "" and (" «" .. fakeNick .. "»") or ""),
                            "P11.Mind.Warn", pos.x, pos.y + 6,
                            Color(255, 80, 70, a * blink),
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.8))
                    end
                end
            end
        end
    end
end)

print("[POLUS-11] разум жертвы (client): метки допуска над людьми + детектор чужих личин")
