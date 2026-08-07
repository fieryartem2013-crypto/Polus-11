-- ============================================================
--  ПОЛЮС-11 — «ОСОБАЯ ВАКАНСИЯ»: ВИЗУАЛ У КАДРОВИКА (client)
--  v4.8.8 «ЛИЧИНА». Заявка: «нечто спрячь, и чтобы появлялось
--  у кадровщика, а то его не взять даже по ивенту».
--  Раньше вакансия существовала ТОЛЬКО в чат-строчке — никто не
--  понимал, где её брать. Теперь, пока окно открыто
--  (P11_ThingOfferUntil), над КАЖДЫМ кадровиком повисает красная
--  плашка с отсчётом, на экране — баннер-напоминание, раз в
--  15 сек — тихий звуковой бип. Подошёл → нажал E → вакансия твоя.
-- ============================================================

surface.CreateFont("P11.OfferBig", { font = "Tahoma", size = 34, weight = 800, antialias = true })
surface.CreateFont("P11.OfferSm",  { font = "Tahoma", size = 22, weight = 800, antialias = true })

local function OfferLeft()
    return math.max(0, GetGlobalFloat("P11_ThingOfferUntil", 0) - CurTime())
end
local function OfferActive()
    return OfferLeft() > 0
end

-- красная плашка над кадровиком + отсчёт
hook.Add("PostDrawTranslucentRenderables", "P11.ThingOfferMark", function()
    if not OfferActive() then return end
    local left = math.ceil(OfferLeft())
    for _, ent in ipairs(ents.FindByClass("polus_fw_jobnpc")) do
        if IsValid(ent) then
            local top = ent:GetPos() + Vector(0, 0, 100)
            local bang = (top - EyePos()):Angle()
            bang = Angle(0, bang.y - 90, 90)
            cam.Start3D2D(top, bang, 0.12)
                draw.SimpleTextOutlined("🔴 ОСОБАЯ ВАКАНСИЯ", "P11.OfferBig", 0, -26,
                    Color(255, 70, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                    2, Color(0, 0, 0, 230))
                draw.SimpleTextOutlined("подойди и нажми [E] · осталось " .. left .. " сек",
                    "P11.OfferSm", 0, 12, Color(255, 220, 210),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 230))
            cam.End3D2D()
        end
    end
end)

-- экранный баннер + бип-напоминание
local nextBeep = 0
hook.Add("HUDPaint", "P11.ThingOfferHUD", function()
    if not OfferActive() then return end
    local w = ScrW()
    local left = math.ceil(OfferLeft())

    draw.SimpleTextOutlined("🔴 [КАДРЫ] ОСОБАЯ ВАКАНСИЯ у кадровика — " .. left .. " сек",
        "Trebuchet24", w * 0.5, 66, Color(255, 95, 85),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))

    if CurTime() >= nextBeep then
        nextBeep = CurTime() + 15
        surface.PlaySound("buttons/blip1.wav")
    end
end)

print("[P11-OFFER] v4.8.8 «ЛИЧИНА»: вакансия Нечто у кадровика теперь ВИДНА — красная плашка над NPC с отсчётом + баннер + бип")
