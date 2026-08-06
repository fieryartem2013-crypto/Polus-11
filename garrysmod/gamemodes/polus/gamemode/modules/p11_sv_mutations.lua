-- ============================================================
--  ПОЛЮС-11 — МУТАЦИИ НЕЧТО (server) v4.2
--  Единый подсчёт жертв: убийства когтями + поглощения личностей.
--  Пороги:
--   3  → РЕГЕНЕРАЦИЯ (2 ХП/с в явленной форме), разбег +8%
--   5  → МЯСОГИГАНТ: +60 к запасу ХП, когти +10 урона
--   10 → АРАХНА: паучья трёхфазная туша (быстрее +20%, прыжок x2.5,
--        иной облик твари)
--  Формы по-прежнему переключаются !форма — мутации работают В ЛЮБОЙ.
-- ============================================================

local TIERS = {
    [3]  = { name = "РЕГЕНЕРАЦИЯ", desc = "плоть зарастает (2 ХП/с), разбег +8%" },
    [5]  = { name = "МЯСОГИГАНТ",  desc = "+60 ХП запас, когти +10 урона" },
    [10] = { name = "АРАХНА",      desc = "паучья туша: бег +20%, прыжок, новый облик" },
}

local THING_WEPS = {
    weapon_polus11_thing = true,
    weapon_polus11_thing_split = true,
    weapon_polus11_thing_brute = true,
    weapon_polus11_thing_spore = true,
}

local function MutSync(ply)
    ply:SetNWInt("P11_MutKills", ply.P11_MutKills or 0)
    ply:SetNWInt("P11_MutTier", ply.P11_MutTier or 0)
    ply:SetNWInt("P11_MutDmg", (ply.P11_MutTier or 0) >= 2 and 10 or 0)
end

local function MutApplyStats(ply)
    -- запас ХП от МЯСОГИГАНТА
    local maxhp = ply:GetMaxHealth()
    if maxhp <= 0 then maxhp = 100 end
    if (ply.P11_MutTier or 0) >= 2 then
        ply:SetHealth(math.min(maxhp + 60, ply:Health() + 60))
    end
end

function POLUS11.MutationKill(ply, how)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not (ply:GetNWBool("P11_Infected", false)) then return end

    ply.P11_MutKills = (ply.P11_MutKills or 0) + 1
    local kills = ply.P11_MutKills

    -- вычислить новый тир
    local newTier = 0
    for t in pairs(TIERS) do
        if kills >= t then newTier = math.max(newTier, (t == 3 and 1) or (t == 5 and 2) or 3) end
    end

    if newTier > (ply.P11_MutTier or 0) then
        ply.P11_MutTier = newTier
        local tierKey = (newTier == 1 and 3) or (newTier == 2 and 5) or 10
        local mut = TIERS[tierKey]
        POLUS11.Notify(ply, "МУТАЦИЯ: «" .. mut.name .. "»! " .. mut.desc .. " (жертв: " .. kills .. ")")
        ply:EmitSound("npc/zombie_poison/pz_alert2.wav", 80, 80)
        local ed = EffectData()
        ed:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
        util.Effect("BloodImpact", ed, true, true)
        MutApplyStats(ply)
        POLUS11.Log("МУТАЦИЯ НЕЧТО: " .. ply:Nick() .. " → " .. mut.name .. " (тир " .. newTier .. ", жертв " .. kills .. ", " .. how .. ")")
    else
        POLUS11.Notify(ply, "Жертв поглощено: " .. kills .. ". Следующая мутация близко.")
    end
    MutSync(ply)
end

-- убийства когтями (любой формой)
hook.Add("PlayerDeath", "P11.MutationKills", function(victim, inf, att)
    if not IsValid(att) or not att:IsPlayer() then return end
    if att == victim then return end
    local wep = att.GetActiveWeapon and att:GetActiveWeapon() or nil
    local cls = (IsValid(wep) and wep:GetClass()) or ""
    if THING_WEPS[cls] then
        POLUS11.MutationKill(att, "убийство")
    end
end)

-- обёртка поглощений во всех 4 свепах
hook.Add("InitPostEntity", "P11.MutationWrap", function()
    timer.Simple(1, function()
        for cls in pairs(THING_WEPS) do
            local t = weapons.GetStored(cls)
            if t and t.EatCorpse and not t.P11_MutWrapped then
                local old = t.EatCorpse
                t.EatCorpse = function(self, ply, corpse)
                    old(self, ply, corpse)
                    POLUS11.MutationKill(ply, "поглощение личности")
                end
                t.P11_MutWrapped = true
            end
        end
    end)
end)

-- тайник регенерации + паучья скорость (только в явленной форме)
local BASE_RUN, BASE_WALK = 330, 170
timer.Create("P11.MutationVitals", 0.5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local tier = IsValid(ply) and (ply.P11_MutTier or 0) or 0
        local alive = IsValid(ply) and ply:Alive() or false
        if alive and tier > 0 and ply:GetNWBool("P11_Infected", false) then

        if ply.P11_Revealed then
            local mv = (POLUS11.Config and POLUS11.Config.Movement) or {}
            local run0, walk0 = mv.run or BASE_RUN, mv.walk or BASE_WALK
            -- Т1: регенерация
            if tier >= 1 then
                local maxhp = ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100
                if tier >= 2 then maxhp = maxhp + 60 end
                if ply:Health() < maxhp then
                    ply:SetHealth(math.min(maxhp, ply:Health() + 2))
                end
            end
            -- скорость: Т1 +8%, Т3 (Арахна) +20%
            local mul = (tier >= 3) and 1.20 or 1.08
            ply:SetRunSpeed(run0 * mul)
            ply:SetWalkSpeed(walk0 * mul)
            if tier >= 3 then
                ply:SetJumpPower(300)
            end
        else
            -- вернуть человеческую размеренность (не ломать конфиг движения)
            local cfg = (POLUS11.Config and POLUS11.Config.Movement) or {}
            ply:SetRunSpeed(cfg.run or BASE_RUN)
            ply:SetWalkSpeed(cfg.walk or BASE_WALK)
            ply:SetJumpPower(cfg.jump or 120)
        end

        end -- alive/tier gate
    end
end)

-- синк на спавне/возврате
hook.Add("PlayerSpawn", "P11.MutationSpawn", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then MutSync(ply) end
    end)
end)

print("[POLUS-11] мутации Нечто загружены (3/5/10 жертв)")
