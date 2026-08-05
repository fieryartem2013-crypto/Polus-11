-- ============================================================
--  ПОЛЮС-11 — ОПОВЕЩЕНИЯ СТАНЦИИ (client) v2.9
--  • золотой БАННЕР ПРИКАЗА сверху (от командира/админа);
--  • визуал МЕТЕЛИ: густой снег, белая изморозь по краям,
--    завывание ветра (два слоя), лёгкое затемнение;
--  • метка РАСПОРЯДКА смены справа сверху (под строкой фазы);
--  • красная плашка «ВЫ В РОЗЫСКЕ», когда сам под подозрением.
-- ============================================================

surface.CreateFont("P11.Alerts.Order", { font = "Roboto", size = 23, weight = 800, extended = true })
surface.CreateFont("P11.Alerts.Small", { font = "Roboto", size = 15, weight = 500, extended = true })

P11 = P11 or {}

-- ============ БАННЕР ПРИКАЗА ============

local ORDER = nil -- { text, by, job, until }

net.Receive("P11_Order", function()
    ORDER = {
        text = net.ReadString(),
        by   = net.ReadString(),
        job  = net.ReadString(),
        till = CurTime() + 12,
    }
    surface.PlaySound("buttons/lever3.wav")
    timer.Simple(0.35, function()
        surface.PlaySound("ambient/alarms/warningbell1.wav")
    end)
end)

hook.Add("HUDPaint", "P11.OrderBanner", function()
    P11.OrderLive = nil -- v3.8: сигнал виджету задач «баннер идёт» → он сползает ниже
    if not ORDER or CurTime() > ORDER.till then return end
    if P11.IntroOpen then return end
    P11.OrderLive = ORDER.till

    local left = ORDER.till - CurTime()
    local a = math.Clamp(left / 1.2, 0, 1)
    local inA = math.Clamp((12 - left) / 0.3, 0, 1)
    a = math.min(a, inA)

    local w = ScrW()
    local y = 128

    draw.RoundedBox(0, 0, y, w, 84, Color(28, 22, 6, 215 * a))
    surface.SetDrawColor(255, 205, 110, 220 * a)
    surface.DrawRect(0, y, w, 2)
    surface.DrawRect(0, y + 82, w, 2)

    draw.SimpleText("◈  П Р И К А З   К О М А Н Д И Р А", "P11.Alerts.Small", w / 2, y + 12,
        Color(255, 215, 130, 240 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleTextOutlined(ORDER.text, "P11.Alerts.Order", w / 2, y + 40,
        Color(255, 235, 190, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
        1, Color(0, 0, 0, 200 * a))
    draw.SimpleText("— " .. ORDER.by .. " (" .. ORDER.job .. ")", "P11.Alerts.Small", w / 2, y + 64,
        Color(200, 170, 110, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ============ МЕТЕЛЬ (P11_Storm) ============

local STORM_FLAKES = nil
local windLoop = nil
local nextHit = 0

local function StormOff()
    if windLoop then windLoop:FadeOut(1.5) windLoop = nil end
end

hook.Add("Think", "P11.StormSound", function()
    local on = GetGlobalBool("P11_Storm", false)
    if on and not windLoop then
        if P11.IntroOpen then return end
        local ok, cs = pcall(CreateSound, LocalPlayer(), "ambient/wind/wind_moan4.wav")
        if ok and cs then windLoop = cs cs:PlayEx(0.5, 92) end
    elseif not on then
        StormOff()
    end
    if on and CurTime() >= nextHit then
        nextHit = CurTime() + math.Rand(5, 11)
        surface.PlaySound("ambient/wind/wind_hit" .. math.random(1, 3) .. ".wav")
    end
end)

hook.Add("HUDPaint", "P11.StormFX", function()
    if not GetGlobalBool("P11_Storm", false) then
        STORM_FLAKES = nil
        return
    end
    if P11.IntroOpen then return end

    local w, h = ScrW(), ScrH()
    local ft = FrameTime()

    if not STORM_FLAKES then
        STORM_FLAKES = {}
        for i = 1, 160 do
            STORM_FLAKES[i] = {
                x = math.random(), y = math.random(),
                s = 0.5 + math.random() * 0.9,   -- скорость (доля экр/с)
                vx = -0.25 - math.random() * 0.2, -- боковой ветер влево
                sz = 1 + math.random() * 3,
                a = 90 + math.random() * 150,
            }
        end
    end

    -- изморозь по краям
    surface.SetDrawColor(190, 215, 235, 26)
    surface.DrawRect(0, 0, w, 70)
    surface.DrawRect(0, h - 70, w, 70)
    surface.DrawRect(0, 0, 70, h)
    surface.DrawRect(w - 70, 0, 70, h)

    -- снег косо влево
    for _, fl in ipairs(STORM_FLAKES) do
        fl.y = fl.y + fl.s * ft
        fl.x = fl.x + fl.vx * ft
        if fl.y > 1.02 then fl.y = -0.02 fl.x = math.random() + math.random() * 0.3 end
        if fl.x < -0.02 then fl.x = 1.02 end
        surface.SetDrawColor(215, 230, 245, fl.a)
        surface.DrawRect(fl.x * w, fl.y * h, fl.sz, fl.sz)
    end

    -- подпись состояния
    if (CurTime() % 4) < 2.6 then
        draw.SimpleText("⚠ МАГНИТНАЯ БУРЯ — РАДИОСВЯЗЬ ГЛУШИТСЯ", "P11.Alerts.Small",
            w / 2, h * 0.42, Color(190, 215, 240, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- ============ РАСПОРЯДОК СМЕНЫ (справа сверху, под строкой фазы) ============

hook.Add("HUDPaint", "P11.ShiftLabel", function()
    if P11.IntroOpen then return end
    local shift = GetGlobalString("P11_Shift", "")
    if shift == "" then return end
    draw.SimpleText("☾ " .. shift, "P11.Alerts.Small", ScrW() - 18, 34,
        Color(160, 195, 235, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end)

-- ============ ВЫ В РОЗЫСКЕ (плашка у самого разыскиваемого) ============

hook.Add("HUDPaint", "P11.WantedSelf", function()
    if P11.IntroOpen then return end
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local reason = me:GetNWString("P11_Wanted", "")
    if reason == "" then return end

    local w = ScrW()
    local blink = 0.5 + math.sin(CurTime() * 5) * 0.25
    draw.RoundedBox(0, 0, 216, w, 40, Color(120, 25, 20, 120 + 70 * blink))
    draw.SimpleText("⚠ ВЫ В РОЗЫСКЕ: " .. reason .. "  —  сдайтесь охране или будьте готовы к аресту",
        "P11.Alerts.Small", w / 2, 236, Color(255, 210, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ============ ВЕЧНЫЙ МОРОЗ (v3.0): изморозь по углам экрана ============
-- Всегда-на-посту VFX: лёгкий ледяной оттенок по краям. В бурю
-- усиливается вдвое — интеграция с метелью выше.

hook.Add("HUDPaint", "P11.FrostVignette", function()
    if P11.IntroOpen then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if IsValid(POLUS11 and POLUS11.Scoreboard) then return end

    local w, h = ScrW(), ScrH()
    -- v3.8: вечную изморозь по краям УБРАЛИ (закрывала края интерфейса).
    -- Корка появляется только в БУРЮ или при реальном ПЕРЕОХЛАЖДЕНИИ.
    local storm = GetGlobalBool("P11_Storm", false)
    local wm = me:GetNWFloat("P11_Warmth", 100)
    local a = storm and 16 or 0
    if wm < 65 then
        a = a + (65 - wm) * 0.55 -- чем холоднее, тем гуще лёд
    end
    if a < 1 then return end
    a = math.floor(math.min(a, 120))

    -- углы и кромки подёрнуты инеем
    surface.SetDrawColor(170, 205, 235, a)
    surface.DrawRect(0, 0, w, 26 + (65 - math.max(wm, 40)) * 0.35)
    surface.DrawRect(0, h - (26 + (65 - math.max(wm, 40)) * 0.35), w, 26 + (65 - math.max(wm, 40)) * 0.35)
    surface.DrawRect(0, 0, 30, h)
    surface.DrawRect(w - 30, 0, 30, h)

    -- кристаллики у краёв при сильном обморожении (это уже опасно)
    if wm <= 30 then
        for i = 1, 3 do
            if math.random() < 0.4 then
                local sx = math.random() < 0.5 and math.random(2, 46) or math.random(w - 46, w - 2)
                local sy = math.random(0, h)
                surface.SetDrawColor(225, 245, 255, 90 + math.random(0, 60))
                surface.DrawRect(sx, sy, 2, 2)
            end
        end
        -- пульс «иди грейся» (редко, чтобы не мешал бою)
        if (CurTime() % 5) < 2 then
            draw.SimpleText("❄ ТЫ ЗАМЕРЗАЕШЬ — ИЩИ ТЕПЛО ❄", "P11.Alerts.Small",
                w / 2, h * 0.20, Color(200, 230, 250, 170 + 60 * math.sin(CurTime() * 5)),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- мерцающие искры угловой изморози (очень редко и слабо)
    if math.random() < 0.006 then
        local cx = math.random() < 0.5 and math.random(2, 40) or math.random(w - 40, w - 2)
        local cy = math.random() < 0.5 and math.random(2, 40) or math.random(h - 40, h - 2)
        surface.SetDrawColor(220, 240, 255, 26)
        surface.DrawRect(cx, cy, 2, 2)
    end
end)
