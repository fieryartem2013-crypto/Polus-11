-- ============================================================
--  ПОЛЮС-11 — таблички с именами (client) v4.3.0
--  Вместо «ванильного ника и ХП»:
--   • всегда — СЕРВЕРНЫЙ позывной бойца (анкета) поверх головы;
--   • кто смотрит В УПОР — под именем ПЛАВНО проявляется
--     ОПИСАНИЕ внешности (анкета «дело бойца»);
--   • приоритет имени: личина Нечто → позывной → стим-ник;
--     приоритет описания: украденное жертвой → своё;
--   • розыск мигание, должность+фракция, ранг с FX, динамик.
-- ============================================================

surface.CreateFont("P11.Tag.Desc", { font = "Roboto", size = 14, weight = 500, extended = true })

-- отображаемое имя: личина > позывной > ник
local function TagName(ply)
    local f = ply:GetNWString("P11_FakeNick", "")
    if f ~= "" then return f end
    local c = ply:GetNWString("P11_CharName", "")
    if c ~= "" then return c end
    return ply:Nick()
end

-- отображаемое описание: украденное жертвой > своё
local function TagDesc(ply)
    local f = ply:GetNWString("P11_FakeDesc", "")
    if f ~= "" then return f end
    return ply:GetNWString("P11_CharDesc", "")
end

-- перенос описания на строки по ширине
local function WrapDesc(txt, font, maxW)
    surface.SetFont(font)
    local lines, cur = {}, ""
    for word in string.gmatch(txt, "%S+") do
        local probe = (cur == "") and word or (cur .. " " .. word)
        if (surface.GetTextSize(probe) or 0) > maxW and cur ~= "" then
            lines[#lines + 1] = cur
            cur = word
            if #lines >= 3 then break end
        else
            cur = probe
        end
    end
    if cur ~= "" and #lines < 3 then lines[#lines + 1] = cur end
    -- если что-то не влезло — многоточие
    local joined = table.concat(lines, " ")
    if #joined < #txt and #lines > 0 then
        lines[#lines] = lines[#lines] .. "…"
    end
    return lines
end

-- состояние фокуса «смотрю на человека»
P11.FocusTag = P11.FocusTag or { ent = nil, a = 0 }

hook.Add("HUDPaint", "P11_Nametags", function()
    if not POLUS11.Config.Nametags then return end

    local me = LocalPlayer()
    if not IsValid(me) or not me:EyePos() then return end

    -- ---- кто в фокусе прицела ----
    local focus = nil
    local tr = me:GetEyeTrace()
    local te = tr.Entity
    if IsValid(te) and te:IsPlayer() and te:Alive() and te ~= me
    and me:GetPos():DistToSqr(te:GetPos()) < 700 * 700 then
        focus = te
    end

    local F = P11.FocusTag
    if F.ent ~= focus then F.ent = focus F.a = 0 end
    F.a = Lerp(math.min(FrameTime() * 5, 1), F.a or 0, focus and 1 or 0)

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= me and IsValid(ply) and ply:Alive() then
            local dist = me:GetPos():DistToSqr(ply:GetPos())
            if dist < 450 * 450 then
                -- видим ли мы его
                local tr2 = util.TraceLine({
                    start  = me:EyePos(),
                    endpos = ply:EyePos(),
                    filter = {me, ply},
                })

                if not tr2.Hit or tr2.Entity == ply then
                    local pos = (ply:EyePos() + Vector(0, 0, 14)):ToScreen()
                    if pos.visible then
                        local frac = 1 - (math.sqrt(dist) / 450)
                        local a = math.Clamp(frac * 255, 40, 255)
                        local name = TagName(ply)
                        local col = Color(235, 238, 245, a)

                        -- РОЗЫСК мигает красным над головой
                        local wanted = ply:GetNWString("P11_Wanted", "")
                        if wanted ~= "" then
                            local blink = 0.5 + math.sin(CurTime() * 6) * 0.5
                            draw.SimpleTextOutlined("⚠ РОЗЫСК", "P11.HUD.Text", pos.x, pos.y - 44,
                                Color(255, 70, 60, a * (0.45 + blink * 0.55)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                                2, Color(0, 0, 0, a * 0.8))
                        end

                        draw.SimpleTextOutlined(name, "P11.HUD.Mid", pos.x, pos.y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))

                        -- должность (+ фракция) под именем
                        local bottomY = 6
                        if P11FW and P11FW.GetJobName then
                            -- v4.2.1: нечто в чужой шкуре носит ДОЛЖНОСТЬ ЖЕРТВЫ
                            local job = nil
                            do
                                local fj = ply:GetNWInt("P11_FakeJob", 0)
                                if fj > 0 and P11FW.TeamJobs then
                                    local jid = P11FW.TeamJobs[fj]
                                    if jid then job = P11FW.Jobs[jid] end
                                end
                                if not job then job = P11FW.GetJob(ply) end
                            end
                            local jn = (job and job.name) or ""
                            if jn ~= "" then
                                bottomY = 30
                                local jc = (job and job.color) or Color(150, 190, 235)
                                local facName = nil
                                if job and P11FW.CategoryList then
                                    local cid = job.faction or job.category
                                    for _, c in ipairs(P11FW.CategoryList) do
                                        if c.id == cid then facName = c.name break end
                                    end
                                end
                                local line = facName and (facName .. " · " .. jn) or jn
                                draw.SimpleTextOutlined(line, "P11.HUD.Text", pos.x, pos.y + 30, Color(jc.r, jc.g, jc.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                            end
                        end

                        -- ранг администрации под должностью (Хелпер+), старшие — переливаются
                        if P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 2 then
                            bottomY = 56
                            local rc = P11FW.RankFxColor and P11FW.RankFxColor(ply) or P11FW.GetRankColor(ply)
                            if P11FW.RankHasFx and P11FW.RankHasFx(ply) then
                                local pulse = 0.35 + math.sin(CurTime() * 2.6) * 0.15
                                draw.SimpleTextOutlined("◆ " .. P11FW.GetRankName(ply), "P11.HUD.Text",
                                    pos.x, pos.y + 56, Color(rc.r, rc.g, rc.b, a * pulse),
                                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 4, Color(rc.r, rc.g, rc.b, a * 0.55))
                            end
                            draw.SimpleTextOutlined("◆ " .. P11FW.GetRankName(ply), "P11.HUD.Text",
                                pos.x, pos.y + 56, Color(rc.r, rc.g, rc.b, a),
                                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                        end

                        -- v4.19.4 «ПОЧЁТ»: медали НАД ником (до 3 глифов + «+N»)
                        if P11 and P11.MedalGlyphs then
                            local okM, mg, mn = pcall(P11.MedalGlyphs, ply, 3)
                            if okM and mg and mg ~= "" then
                                local extra = (mn or 0) > 3 and (" +" .. (mn - 3)) or ""
                                draw.SimpleTextOutlined(mg .. extra, "P11.HUD.Text",
                                    pos.x, pos.y - 24, Color(255, 205, 100, a),
                                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                            end
                        end

                        -- динамик говорящего — ПОД табличкой
                        if ply.IsSpeaking and ply:IsSpeaking() then
                            local pulse = 0.55 + math.sin(CurTime() * 10) * 0.45
                            draw.SimpleTextOutlined("🔊", "P11.HUD.Text", pos.x, pos.y + bottomY + 24,
                                Color(130, 220, 250, a * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                                2, Color(0, 0, 0, a * 0.7))
                        end
                    end
                end
            end
        end
    end

    -- ---- v4.3.0: ФОКУС-КАРТОЧКА — позывной + описание, плавное проявление ----
    if IsValid(F.ent) and F.ent:IsPlayer() and F.ent:Alive() and (F.a or 0) > 0.03 then
        local ply = F.ent
        local pos = (ply:EyePos() + Vector(0, 0, 86)):ToScreen()
        if pos.visible then
            local a = math.Clamp((F.a or 0) * 255, 0, 255)
            local name = TagName(ply)
            local desc = TagDesc(ply)

            surface.SetFont("P11.HUD.Mid")
            local wName = surface.GetTextSize(name) or 80
            local lines = desc ~= "" and WrapDesc(desc, "P11.Tag.Desc", 300) or {}
            local wDesc = 0
            for _, ln in ipairs(lines) do
                surface.SetFont("P11.Tag.Desc")
                local wl = surface.GetTextSize(ln) or 0
                if wl > wDesc then wDesc = wl end
            end
            local wBox = math.max(wName, wDesc) + 28
            local hBox = 26 + (#lines > 0 and (#lines * 17 + 8) or 0)

            -- карточка-затемнение за текстом
            draw.RoundedBox(8, pos.x - wBox / 2, pos.y - 10, wBox, hBox, Color(8, 12, 18, a * 0.62))
            surface.SetDrawColor(120, 185, 255, a * 0.35)
            surface.DrawOutlinedRect(pos.x - wBox / 2, pos.y - 10, wBox, hBox, 1)

            draw.SimpleTextOutlined("«" .. name .. "»", "P11.HUD.Mid", pos.x, pos.y + 3,
                Color(240, 246, 252, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.7))

            local yy = pos.y + 20
            for _, ln in ipairs(lines) do
                draw.SimpleTextOutlined(ln, "P11.Tag.Desc", pos.x, yy,
                    Color(205, 215, 228, a * 0.95), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a * 0.6))
                yy = yy + 17
            end
        end
    end
end)
