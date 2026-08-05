-- ============================================================
--  ПОЛЮС-11 — ПЕРЕОХЛАЖДЕНИЕ (server) v3.7
--  Тело человека на станции — это ресурс: выйдешь в открытую
--  метель без дела — окоченеешь. Тепло:
--   • 100 = в тепле. На улице (над головой небо) медленно уходит,
--     в бури — быстро; внутри восстанавливается;
--   • рядом с работающим генератором греешься быстрее всего;
--     горячий паёк тоже согревает (см. weapon_polus11_ration);
--   • < 30 — лихорадочная дрожь (экран колотит), лёд по краям;
--   • < 12 — обморожение: потеря ХП, можно замёрзнуть насмерть.
--  НЕЧТО (активная зараза) холода не чувствует — оно выживало
--  в леднике тысяч лет. Маскировка это не палит (тоже иммунна).
--  Настройки — POLUS11.Config.Cold* в p11_sh_config.lua.
-- ============================================================

local COLD = {
    DrainOutside = 1.4,   -- тепла/сек под открытым небом
    DrainStorm   = 3.0,   -- тепла/сек на улице в бурю
    RegenInside  = 4.0,   -- тепла/сек в помещении
    RegenByGen   = 9.0,   -- тепла/сек у работающего генератора
    GenRadius    = 320,   -- радиус тепла генератора
    ShiverAt     = 30,    -- ниже — дрожь рук/экрана
    DamageAt     = 12,    -- ниже — обморожение с уроном
    DamageTick   = 2,     -- сек между тиками урона обморожения
    DamagePer    = 2,     -- урона за тик
}

-- на улице ли игрок: над головой — небо
local function IsOutdoors(ply)
    local tr = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + Vector(0, 0, 4096),
        filter = ply,
    })
    return (not tr.Hit) or tr.HitSky
end

-- рядом ли тёплый (живой) генератор
function POLUS11.GeneratorNearWarm(pos, radius)
    radius = radius or COLD.GenRadius
    local r2 = radius * radius
    for _, e in ipairs(ents.FindByClass("polus11_generator")) do
        if IsValid(e) and not e:GetDamaged() and e:GetFuel() > 0
            and e:GetPos():DistToSqr(pos) <= r2 then
            return true
        end
    end
    return false
end

function POLUS11.AddWarmth(ply, amount)
    if not IsValid(ply) then return end
    local w = math.Clamp((ply.P11_Warmth or 100) + amount, 0, 100)
    ply.P11_Warmth = w
    ply:SetNWFloat("P11_Warmth", w)
end

local function SetWarmth(ply, w)
    ply.P11_Warmth = w
    -- сеть дёргаем только при заметной смене (дробные тики не шлём)
    if math.abs(w - (ply.P11_WarmthSent or -1)) >= 0.5 then
        ply:SetNWFloat("P11_Warmth", w)
        ply.P11_WarmthSent = w
    end
end

hook.Add("PlayerSpawn", "P11_ColdSpawn", function(ply)
    ply.P11_Warmth = 100
    ply.P11_WarmthSent = 100
    ply:SetNWFloat("P11_Warmth", 100)
    -- v3.8.2: передышка после спавна — холод не трогает (альфа-баланс)
    local g = (POLUS11.Config and POLUS11.Config.ColdGraceSec) or 150
    ply.P11_ColdGraceUntil = CurTime() + g
    ply.P11_Froze = false
end)

timer.Create("P11_ColdTick", 1, 0, function()
    if not POLUS11.Config.ColdEnabled then return end

    -- v3.8.2: живые значения из конфига (можно крутить без рестарта карты)
    local cfg       = POLUS11.Config
    local drainOut  = cfg.ColdDrainOut    or COLD.DrainOutside
    local drainStm  = cfg.ColdDrainStorm  or COLD.DrainStorm
    local dmgPer    = cfg.ColdDamagePer   or COLD.DamagePer
    local dmgTick   = cfg.ColdDamageTick  or COLD.DamageTick
    local warn      = cfg.ColdWarn ~= false

    local storm = GetGlobalBool("P11_Storm", false)
    local now   = CurTime()

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            -- активная зараза холодом не берётся
            local thing = ply:GetNWBool("P11_Infected", false) and ply:GetNWBool("P11_InfActive", false)
            if thing then
                SetWarmth(ply, 100)
            else
                local w = ply.P11_Warmth or 100
                local outdoors = IsOutdoors(ply)
                local delta

                -- v3.8.2: после (ре)спавна — передышка: только согрев, без мороза
                if now < (ply.P11_ColdGraceUntil or 0) then
                    delta = COLD.RegenInside
                elseif outdoors then
                    delta = storm and -drainStm or -drainOut
                else
                    delta = COLD.RegenInside
                end

                -- генератор греет сильнее комнаты
                if POLUS11.GeneratorNearWarm(ply:GetPos()) then
                    delta = math.max(delta, COLD.RegenByGen)
                end

                w = math.Clamp(w + delta, 0, 100)
                SetWarmth(ply, w)

                -- дрожь при обморожении
                if w <= COLD.ShiverAt then
                    ply.P11_NextShiver = ply.P11_NextShiver or 0
                    if now >= ply.P11_NextShiver then
                        ply.P11_NextShiver = now + math.Rand(2.2, 4.5)
                        ply:ViewPunch(Angle(math.Rand(-2, 2), math.Rand(-3, 3), 0))
                        if math.random() < 0.35 then
                            ply:EmitSound("ambient/wind/wind_hit" .. math.random(1, 3) .. ".wav", 42, 120)
                        end
                        if warn and w > COLD.DamageAt and math.random() < 0.5 then
                            POLUS11.Notify(ply, "Ты замерзаешь! Ищи тепло — генератор, помещение, горячий паёк.")
                        end
                    end
                end

                -- обморожение: потеря ХП (всегда громко объясняем ПРИЧИНУ урона)
                if w <= COLD.DamageAt then
                    ply.P11_NextFrostDmg = ply.P11_NextFrostDmg or 0
                    if now >= ply.P11_NextFrostDmg then
                        ply.P11_NextFrostDmg = now + dmgTick
                        ply.P11_Froze = true
                        local d = DamageInfo()
                        d:SetDamage(dmgPer)
                        d:SetAttacker(game.GetWorld())
                        d:SetInflictor(game.GetWorld())
                        d:SetDamageType(DMG_GENERIC)
                        ply:TakeDamageInfo(d)
                        if warn then
                            POLUS11.Notify(ply, "ОБМОРОЖЕНИЕ! Ты теряешь здоровье от холода — беги к генератору или в помещение!")
                        end
                    end
                elseif w > COLD.ShiverAt then
                    ply.P11_Froze = false
                end
            end
        end
    end
end)

-- красивая строка в killfeed/чате, если человек замёрз
hook.Add("PlayerDeath", "P11_ColdDeath", function(ply)
    if ply.P11_Warmth ~= nil and ply.P11_Warmth <= COLD.DamageAt and ply.P11_Froze then
        PrintMessage(HUD_PRINTTALK, "[СТАНЦИЯ] " .. ply:Nick() .. " замёрз насмерть. Антарктида не прощает.")
        POLUS11.Log(ply:Nick() .. " замёрз насмерть")
    end
    ply.P11_Froze = false
end)
