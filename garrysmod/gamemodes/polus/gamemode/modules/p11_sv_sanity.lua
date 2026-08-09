-- ============================================================
--  ПОЛЮС-11 — РАССУДОК (server) v4.19.4 «ПОЧЁТ»
--  Заявка владельца: «добавь рассудок, который пополняется
--  чашкой кофе или таблетками — купить может только медсестра
--  и полевой медик в ларьке». Плюс хоррор-слой из аналитики:
--  темнота + одиночество + трупы точат рассудок, тепло компании
--  и буржуйки — лечат.
--
--  ЧИСЛО: 0..100 (NWFloat P11_Sanity), тик 2 сек.
--    МИНУС: авария света, буря, одиночество (>1100 юн до людей),
--           трупы рядом (≤550 юн, до 3 шт).
--    ПЛЮС:  напарник близко (≤450), буржуйка «УГЛИ» (≤450),
--           безопасный дрейф к 70 на свету среди людей.
--  ЛЕКАРСТВА (товары ларька, покупка — только медслужбе):
--    coffee «Чашка горячего кофе»  +30 рассудка
--    pills  «Таблетки Аминазин-С»  +70 рассудка
--  Употребить их может ЛЮБОЙ (медик закупает и разносит) —
--  ветка предмета в p11_sv_inventory.
--  Пороговые вести игроку: <50 «шепчет», <25 «грань».
-- ============================================================

local TICK   = 2
local TRIG50 = "P11_SanityWarn50"
local TRIG25 = "P11_SanityWarn25"
local SAN_DRAIN = CreateConVar("p11_sanitydrain", "1", FCVAR_ARCHIVE) -- v4.22.2 «ТИШИНА»: множитель расхода рассудка 0..3

POLUS11.MedJobs = { -- единый список медслужбы (ларёк сверяется с ним)
    medic = true,
    seed_rkka_medsestra = true,
    seed_rkka_medglav   = true,
    vip_voenvrach       = true,
}

local function SanityGet(ply)
    return tonumber(ply.P11_Sanity) or 100
end

local function SanitySet(ply, v)
    v = math.Clamp(v, 0, 100)
    ply.P11_Sanity = v
    ply:SetNWFloat("P11_Sanity", v)
end

function POLUS11.SanityGet(ply) return SanityGet(ply) end

function POLUS11.SanityAdd(ply, n, why)
    if not (IsValid(ply) and ply:Alive()) then return end
    local was = SanityGet(ply)
    local now = math.Clamp(was + (tonumber(n) or 0), 0, 100)
    SanitySet(ply, now)
    if now > was then
        POLUS11.Notify(ply, "Рассудок +" .. math.floor(now - was) ..
            " (" .. tostring(why or "лекарство") .. "): " .. math.floor(now) .. "/100.")
        if now >= 50 then ply[TRIG50] = false end
        if now >= 25 then ply[TRIG25] = false end
    else
        POLUS11.Notify(ply, "Рассудок на месте: " .. math.floor(now) .. "/100.")
    end
end

timer.Create("P11.SanityTick", TICK, 0, function()
    local blackout = GetGlobalBool("P11_Blackout", false)
    local storm    = GetGlobalBool("P11_Storm", false)

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and not ply:IsBot() then
            local d = 0
            -- v4.22.2 «ТИШИНА»: расход мягче ~ на треть (заявка «анлак»),
            -- живой тюнинг без рестарта — p11_sanitydrain 0..3
            local dm = math.Clamp(SAN_DRAIN:GetFloat(), 0, 3)
            if blackout then d = d - 1.1 * dm end
            if storm    then d = d - 0.3 * dm end

            -- компания
            local near, closeFriend = 0, false
            local ppos = ply:GetPos()
            for _, o in ipairs(player.GetAll()) do
                if o ~= ply and o:Alive() then
                    local ds = ppos:DistToSqr(o:GetPos())
                    if ds < 1100 * 1100 then
                        near = near + 1
                        if ds < 450 * 450 then closeFriend = true end
                    end
                end
            end
            if near == 0 then          d = d - 0.55 * dm
            elseif closeFriend then    d = d + 1.0
            else                       d = d + 0.15 end

            -- трупы и буржуйки — одной сферой
            local corps, hearth = 0, false
            for _, e in ipairs(ents.FindInSphere(ppos, 550)) do
                local cls = e:GetClass()
                if cls == "prop_ragdoll" then
                    corps = corps + 1
                    if corps >= 3 then corps = 3 end
                elseif cls == "polus11_hearth" then
                    hearth = true
                end
            end
            d = d - corps * 0.35 * dm
            if hearth then d = d + 0.9 end

            -- тихий дрейф к 70 (свет, люди, делай своё дело)
            if not blackout and d >= 0 and SanityGet(ply) < 70 then
                d = d + 0.25
            end

            local was = SanityGet(ply)
            local now = math.Clamp(was + d * TICK, 0, 100)
            if now ~= was then SanitySet(ply, now) end

            -- пороговые вести (один раз за погружение)
            if now < 50 and not ply[TRIG50] then
                ply[TRIG50] = true
                POLUS11.Notify(ply, "В голове шепчет, тени дышат... рассудок ниже половины (" ..
                    math.floor(now) .. "/100). Кофе или аминазин — у медслужбы; держись людей и огня.")
            elseif now >= 55 then
                ply[TRIG50] = false
            end
            if now < 25 and not ply[TRIG25] then
                ply[TRIG25] = true
                POLUS11.Notify(ply, "ТЫ НА ГРАНИ (" .. math.floor(now) ..
                    "/100). Станция уже не та... ищи свет, людей и лекарство.")
                ply:EmitSound("ambient/creatures/town_moan1.wav", 60, 85)
            elseif now >= 30 then
                ply[TRIG25] = false
            end
        end
    end
end)

-- смерть отрезвляет: респавн с 60 очками
hook.Add("PlayerSpawn", "P11.SanitySpawn", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then SanitySet(ply, 60) end
    end)
end)

hook.Add("PlayerInitialSpawn", "P11.SanityJoin", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then SanitySet(ply, 100) end
    end)
end)

print("[POLUS-11] рассудок v4.19.4 «ПОЧЁТ»: тьма/одиночество/трупы точат, люди/буржуйка лечат; кофе+30 и аминазин+70 — только медслужба в ларьке")
