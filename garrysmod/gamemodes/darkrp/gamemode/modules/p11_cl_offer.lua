-- ============================================================
--  ПОЛЮС-11 — «ОСОБАЯ ВАКАНСИЯ»: ЗРИМОСТЬ (client) v4.8.1
--  Жалоба владельца: «особой вакансии нет — у кадровика не
--  появляется». КОРЕНЬ: окно вакансии открывалось СЕРВЕРОМ
--  исправно (SetGlobalFloat P11_ThingOfferUntil), но ЕДИНСТВЕННЫМ
--  следом была одна строка в чат — никакого маркера на станции.
--  Успев не прочесть чат, вакансию не увидишь вообще.
--  Теперь, пока окно открыто:
--   • над кадровиком горит красный маркер «⚠ ОСОБАЯ ВАКАНСИЯ»
--     (мигает, виден сквозь стены если вплотную? — нет, как
--     неймтаг: только в прямой видимости, честно);
--   • на экране — пульсирующий баннер напоминалка (8 сек после
--     открытия, потом сворачивается в мини-строку-статус);
--   • звук-объявление радиопомехой при открытии окна.
--  Логика открытия/заражения — серверная (p11_sv_thingoffer),
--  тут ТОЛЬКО показ: состояние читаем из глобального флоата,
--  никаких новых сетевых пакетов.
-- ============================================================

surface.CreateFont("P11O.Big",   { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11O.Mid",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11O.Small", { font = "Roboto", size = 15, weight = 500, extended = true })

P11O = P11O or { lastUntil = 0, openAt = 0 }

local NPC_CLASS = "polus_fw_jobnpc"

local function OfferLeft()
    local left = GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime()
    if left <= 0 then return 0 end
    return left
end

-- фронт окна: заметили открытие — запускаем баннер + звук
hook.Add("Think", "P11.OfferWatch", function()
    local untilT = GetGlobalFloat("P11_ThingOfferUntil", 0)
    if untilT > CurTime() and untilT ~= (P11O.lastUntil or 0) then
        P11O.openAt = CurTime()
        surface.PlaySound("npc/combine_soldier/die1.wav")
    end
    P11O.lastUntil = untilT
end)

-- ============ МАРКЕР НАД КАДРОВИКОМ (3D2D) ============

hook.Add("PostDrawTranslucentRenderables", "P11.OfferMarker", function(_, isSkybox, isDraw3DSkybox)
    if isSkybox or isDraw3DSkybox then return end
    local left = OfferLeft()
    if left <= 0 then return end

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local myPos = me:GetPos()

    for _, ent in ipairs(ents.FindByClass(NPC_CLASS)) do
        if IsValid(ent) then
            local pos = ent:GetPos() + Vector(0, 0, 84)
            if pos:DistToSqr(myPos) < 4200 * 4200 then
                local ang = (myPos - pos):Angle()
                ang.p, ang.r = 0, 0
                ang:RotateAroundAxis(ang:Up(), -90)
                ang:RotateAroundAxis(ang:Forward(), 90)

                local blink = 0.5 + math.sin(CurTime() * 7) * 0.5
                cam.Start3D2D(pos, ang, 0.16)
                    surface.SetAlphaMultiplier(0.42 + 0.58 * blink)
                    draw.RoundedBox(8, -190, -46, 380, 66, Color(26, 8, 10, 210))
                    surface.SetDrawColor(255, 70, 60, 235)
                    surface.DrawOutlinedRect(-190, -46, 380, 66, 2)
                    draw.SimpleText("⚠ ОСОБАЯ ВАКАНСИЯ", "P11O.Big", 0, -34,
                        Color(255, 90, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("подойди и жми E · осталось " .. math.ceil(left) .. " сек",
                        "P11O.Small", 0, 0, Color(255, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    surface.SetAlphaMultiplier(1)
                cam.End3D2D()
            end
        end
    end
end)

-- ============ БАННЕР НА ЭКРАНЕ ============

hook.Add("HUDPaint", "P11.OfferBanner", function()
    local left = OfferLeft()
    if left <= 0 then return end

    local w = ScrW()
    local sinceOpen = CurTime() - (P11O.openAt or 0)

    if sinceOpen < 8 then
        -- большое объявление при открытии
        local k = math.Clamp(sinceOpen / 8, 0, 1)
        local alpha = (k < 0.85) and 1 or (1 - (k - 0.85) / 0.15)
        local bob = math.sin(CurTime() * 5) * 3
        surface.SetAlphaMultiplier(alpha)
        draw.RoundedBox(10, w / 2 - 300, 64 + bob, 600, 74, Color(30, 8, 10, 225))
        surface.SetDrawColor(255, 70, 60, 190 + 60 * math.sin(CurTime() * 6))
        surface.DrawOutlinedRect(w / 2 - 300, 64 + bob, 600, 74, 2)
        draw.SimpleText("⚠ ОСОБАЯ ВАКАНСИЯ У КАДРОВИКА", "P11O.Big",
            w / 2, 78 + bob, Color(255, 90, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Первый, кто нажмёт E по NPC кадров — возьмёт её. Осталось " .. math.ceil(left) .. " сек.",
            "P11O.Small", w / 2, 112 + bob, Color(255, 205, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        surface.SetAlphaMultiplier(1)
    else
        -- свёрнутый статус, пока окно открыто
        draw.RoundedBox(8, w - 268, 96, 256, 26, Color(30, 8, 10, 190))
        draw.SimpleText("⚠ вакансия у кадровика: " .. math.ceil(left) .. " сек",
            "P11O.Small", w - 142, 109, Color(255, 160, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

print("[POLUS-11] вакансия-визуал v4.8.1 (маркер над кадровиком + баннер)")
