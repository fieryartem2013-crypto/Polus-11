-- ============================================================
--  ПОЛЮС-11 — СТРЕСС при виде Нечто (клиент) v4.8.8 «ЛИЧИНА»
--  ФИКС ЗАЯВКИ «стресс от вида нечто — вечный»:
--  Старая формула тащила panic К МАКСИМУМУ (target = max(panic,
--  near)) и никогда не отпускала обратно → края экрана темнели
--  НАВСЕГДА. Теперь:
--   ● всплеск от крика (P11_FearFX) затухает сам (~8 сек);
--   ● «монстр рядом и на виду» сканируется раз в 0.15 сек
--     (оптимизация: не каждый кадр трассы по игрокам);
--   ● уровень РАСТЁТ быстро, а СПАДАЕТ заметно (~0.25/сек):
--     убежал от твари — через пару секунд отпустило.
--  Рендер (виньетка/тряска/ветер в лёгких) — как был.
-- ============================================================

local panic = 0      -- текущий уровень 0..1
local fear = 0       -- всплеск от крика Нечто (P11_FearFX)
local nearCache = 0  -- «монстр на виду» (скан не каждый кадр)
local nextScan = 0

net.Receive("P11_FearFX", function()
    fear = 1
end)

hook.Add("Think", "P11_PanicThink", function()
    if not POLUS11.Config.PanicFX then return end

    local me = LocalPlayer()
    local dt = FrameTime()
    if dt <= 0 then dt = 1 / 66 end

    -- всплеск крика всегда тает сам (~8 сек до нуля)
    if fear > 0 then
        fear = math.max(0, fear - dt / 8)
    end

    if not IsValid(me) or not me:Alive() then
        panic = math.max(0, panic - dt / 5)
        nearCache = 0
        return
    end

    -- v4.8.8: скан близости/видимости монстра — раз в 0.15 сек
    if CurTime() >= nextScan then
        nextScan = CurTime() + 0.15
        local near = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= me and ply:Alive() then
                local m = ply:GetModel()
                local isMonster = (m == POLUS11.MonsterModels.brute or m == POLUS11.MonsterModels.spider)
                if isMonster then
                    local d = me:GetPos():DistToSqr(ply:GetPos())
                    if d < 900 * 900 then
                        local tr = util.TraceLine({
                            start  = me:EyePos(),
                            endpos = ply:EyePos(),
                            filter = { me, ply },
                        })
                        if not tr.Hit or tr.Entity == ply then
                            local f = 1 - (math.sqrt(d) / 900)
                            if f > near then near = f end
                        end
                    end
                end
            end
        end
        nearCache = near
    end

    local target = math.max(fear, nearCache)
    -- растём БЫСТРО (0.9/сек), остываем ЗАМЕТНО (0.25/сек) →
    -- стресс от вида Нечто больше НЕ вечный
    local rate = (target > panic) and 0.9 or 0.25
    panic = math.Approach(panic, target, rate * dt)
    if target <= 0 and panic < 0.02 then panic = 0 end

    -- тяжёлое дыхание при сильной панике
    if panic > 0.45 then
        P11_NextBreath = P11_NextBreath or 0
        if CurTime() >= P11_NextBreath then
            P11_NextBreath = CurTime() + math.max(2.2, 5 - panic * 3)
            surface.PlaySound("player/suit_sprint.wav")
        end
    end
end)

hook.Add("HUDPaint", "P11_PanicVignette", function()
    if not POLUS11.Config.PanicFX then return end
    if panic <= 0.03 then return end

    local w, h = ScrW(), ScrH()
    local a = math.floor(panic * 170)

    -- затемнение по краям (4 полосы с нарастающей альфой)
    local edge = math.floor(w * 0.16)
    for i = 1, 6 do
        local aa = math.floor(a * (i / 6))
        local lw = math.floor(edge * (7 - i) / 6)
        surface.SetDrawColor(6, 2, 2, aa)
        surface.DrawRect(0, 0, lw, h)              -- лево
        surface.DrawRect(w - lw, 0, lw, h)         -- право
        surface.DrawRect(0, 0, w, lw)              -- верх
        surface.DrawRect(0, h - lw, w, lw)         -- низ
    end

    if panic > 0.75 then
        draw.SimpleTextOutlined("ТЫ ВИДИШЬ ЕГО. ОНО РЯДОМ.", "P11.HUD.Mid", w / 2, h * 0.82,
            Color(255, 120, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
    end
end)

-- лёгкая тряска камеры в панике
hook.Add("CalcView", "P11_PanicShake", function(ply, pos, ang, fov)
    if not POLUS11.Config.PanicFX then return end
    if panic <= 0.25 then return end
    local s = panic * 0.7
    ang.r = ang.r + math.sin(CurTime() * 7) * s
    ang.p = ang.p + math.cos(CurTime() * 9) * s * 0.5
end)

-- на всякий: рестарт уровня = сброс (чтобы стресс точно не «залипал»)
hook.Add("InitPostEntity", "P11_PanicReset", function()
    panic, fear, nearCache = 0, 0, 0
end)

print("[P11-PANIC] v4.8.8 «ЛИЧИНА»: стресс от вида Нечто ТЕПЕРЬ СПАДАЕТ (всплеск крика ~8 сек, остывание 0.25/сек), скан 0.15с — без дыр в FPS")
