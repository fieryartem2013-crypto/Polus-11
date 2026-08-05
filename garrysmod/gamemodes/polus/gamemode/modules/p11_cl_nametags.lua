-- ============================================================
--  ПОЛЮС-11 — таблички с именами над головами
--  Вор личности отображается как ЖЕРТВА (его украденное имя)
-- ============================================================

hook.Add("HUDPaint", "P11_Nametags", function()
    if not POLUS11.Config.Nametags then return end

    local me = LocalPlayer()
    if not IsValid(me) or not me:EyePos() then return end

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= me and IsValid(ply) and ply:Alive() then
            local dist = me:GetPos():DistToSqr(ply:GetPos())
            if dist < 450 * 450 then
                -- видим ли мы его
                local tr = util.TraceLine({
                    start  = me:EyePos(),
                    endpos = ply:EyePos(),
                    filter = {me, ply},
                })

                if not tr.Hit or tr.Entity == ply then
                    local pos = (ply:EyePos() + Vector(0, 0, 14)):ToScreen()
                    if pos.visible then
                        -- подмена: показываем УКРАДЕННОЕ имя
                        local name = ply:GetNWString("P11_FakeNick", "")
                        if name == "" then
                            name = ply:Nick()
                        end

                        local frac = 1 - (math.sqrt(dist) / 450)
                        local a = math.Clamp(frac * 255, 40, 255)

                        -- мёртв/жив
                        local col = Color(235, 238, 245, a)
                        draw.SimpleTextOutlined(name, "P11.HUD.Mid", pos.x, pos.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))

                        -- должность из ПОЛЮС FRAMEWORK (если установлен)
                        if P11FW and P11FW.GetJobName then
                            local jn = P11FW.GetJobName(ply)
                            if jn ~= "" then
                                local job = P11FW.GetJob(ply)
                                local jc = (job and job.color) or Color(150, 190, 235)
                                draw.SimpleTextOutlined(jn, "P11.HUD.Text", pos.x, pos.y + 30, Color(jc.r, jc.g, jc.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                            end
                        end
                    end
                end
            end
        end
    end
end)
