-- ============================================================
--  ПОЛЮС-11 — РАЗУМ ЖЕРТВЫ: ПРОГРЕССИЯ НЕЧТО (server) v4.19.4
--  Заявка владельца (п.13 банка идей): «поглощённая профа даёт
--  твари навык: медик → реген формы, техник → саботаж
--  генератора руками, следователь → чтение меток допуска».
--  Генератор вырезан из игры («ОТБОЙ» v4.12.0) — саботаж идёт
--  по ЖИВОЙ цели: рассеянная проводка станции → свет гаснет.
--
--  НАВЫКИ (по ПРОФЕ съеденной жертвы, плодятся от обоих каналов
--  нечто: авто-поглощение когтями И R-съедение трупа):
--   • МЕДСЛУЖБА (Полевой медик, Медсёстры РККА, VIP-Военврач)
--     → «ПЛОТЬ МЕДИКА»: реген 2 ХП/0.8с В ЛЮБОМ ВИДЕ — и в
--       явленной форме, и под человеческой личиной (мутации
--       дают реген лишь в явленной — теперь дольше живёт).
--   • ТЕХНИКИ (Техник-механик, Инженер-изобретатель)
--     → «ЗНАНИЕ ПРОВОДКИ»: чат !саботаж — свет станции гаснет
--       на 150 сек (руками коротит жилы), перезарядка 6 мин.
--   • НКВД-СЛЕД (Следователь, Оперуполномоченный НКВД)
--     → «ЧТЕНИЕ МЕТОК»: над головами людей видит ИСТИННЫЕ
--       должности и допуски, чужие личины подсвечены красным
--       (клиент p11_cl_thingmind, флаг NWBool P11_MindSled).
--  Навыки живут весь рейс твари (до рестарта/очистки), берутся
--  один раз за жизнь Нечто. Журнал станции фиксирует каждый.
-- ============================================================

local MEDIC_JOBS = {
    medic = true,
    seed_rkka_medsestra = true,
    seed_rkka_medglav   = true,
    vip_voenvrach       = true,
}
local TECH_JOBS = {
    tech     = true,
    engineer = true,
}
local SLED_JOBS = {
    seed_nkvd_sledovatel = true,
    seed_nkvd_oper       = true,
}

local SAB_LEN = 150   -- сек тьмы от саботажа
local SAB_CD  = 360   -- перезарядка

local function IsThing(ply)
    return IsValid(ply)
        and ply:GetNWBool("P11_Infected", false)
        and ply:GetNWBool("P11_InfActive", false)
end

local function MindSync(ply)
    local list = {}
    for g in pairs(ply.P11_Mind or {}) do list[#list + 1] = g end
    ply:SetNWString("P11_ThingMind", table.concat(list, ","))
    ply:SetNWBool("P11_MindSled", (ply.P11_Mind or {}).sled == true)
end

function POLUS11.MindAbsorb(ply, teamIdx)
    if not IsThing(ply) then return end
    teamIdx = tonumber(teamIdx) or 0
    if teamIdx <= 0 or not (P11FW and P11FW.TeamJobs) then return end
    local jid = P11FW.TeamJobs[teamIdx]
    if not isstring(jid) then return end

    local group = nil
    if MEDIC_JOBS[jid] then group = "medic"
    elseif TECH_JOBS[jid] then group = "tech"
    elseif SLED_JOBS[jid] then group = "sled" end
    if not group then return end

    ply.P11_Mind = ply.P11_Mind or {}
    if ply.P11_Mind[group] then return end -- навык уже усвоен раньше
    ply.P11_Mind[group] = true
    MindSync(ply)

    local jobName = (P11FW.Jobs[jid] and P11FW.Jobs[jid].name) or jid
    local flavor = {
        medic = "ПЛОТЬ МЕДИКА: чужая кровь помнит, как заживлять. Твои раны зарастают ВСЕГДА — и в форме, и под личиной (+2 ХП/0.8с).",
        tech  = "ЗНАНИЕ ПРОВОДКИ: пальцы помнят щитовую станции. Чат !саботаж — СВЕТ ГАСНЕТ на " .. SAB_LEN .. " сек (перезарядка " .. math.floor(SAB_CD / 60) .. " мин).",
        sled  = "ЧТЕНИЕ МЕТОК: глаза следователя теперь твои. Ты видишь ИСТИННЫЕ должности людей над их головами — и ЧУЖИЕ ЛИЧИНЫ красным.",
    }
    POLUS11.Notify(ply, "РАЗУМ ЖЕРТВЫ — «" .. jobName .. "» усвоен! " .. (flavor[group] or ""))
    ply:EmitSound("npc/zombie_poison/pz_alert2.wav", 75, 65)
    POLUS11.Log("РАЗУМ ЖЕРТВЫ: " .. ply:Nick() .. " усвоил «" .. group ..
        "» (жертва: " .. jobName .. ")")
end

-- канал 1: ядро «ЛИЧИНА» съело личность (когти-авто и R-съедение)
hook.Add("Polus11.ThingDevoured", "P11.MindDevour", function(ply, identity)
    if istable(identity) then
        POLUS11.MindAbsorb(ply, identity.job)
    end
end)

-- канал 2: убийство когтями ЛЮБОЙ формы (у Поглотителя/Споровика
-- автопоглощения нет — но разум жертвы честно усваивается тоже)
local THING_WEPS = {
    weapon_polus11_thing = true,
    weapon_polus11_thing_split = true,
    weapon_polus11_thing_brute = true,
    weapon_polus11_thing_spore = true,
}
hook.Add("PlayerDeath", "P11.MindClaws", function(victim, inf, att)
    if not (IsValid(att) and att:IsPlayer() and att ~= victim) then return end
    if not (IsValid(victim) and victim:IsPlayer()) then return end
    if not IsThing(att) then return end
    local wep = att.GetActiveWeapon and att:GetActiveWeapon()
    if not (IsValid(wep) and THING_WEPS[wep:GetClass()]) then return end
    POLUS11.MindAbsorb(att, victim:Team())
end)

-- ============ «ПЛОТЬ МЕДИКА»: РЕГЕН В ЛЮБОМ ВИДЕ ============

timer.Create("P11.MindRegen", 0.8, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and IsThing(ply)
            and ply.P11_Mind and ply.P11_Mind.medic then
            local maxhp = ply:GetMaxHealth()
            if maxhp <= 0 then maxhp = 100 end
            if (ply.P11_MutTier or 0) >= 2 then maxhp = maxhp + 60 end -- мясогигант
            if ply:Health() < maxhp then
                ply:SetHealth(math.min(maxhp, ply:Health() + 2))
            end
        end
    end
end)

-- ============ «ЗНАНИЕ ПРОВОДКИ»: !саботаж гасит свет ============

hook.Add("PlayerSay", "P11.MindSabotage", function(ply, text)
    local t = string.lower(string.Trim(tostring(text or "")))
    if t ~= "!саботаж" and t ~= "!sabotaj" and t ~= "!светвын" then return end
    if not IsThing(ply) then return end
    if not (ply.P11_Mind and ply.P11_Mind.tech) then
        POLUS11.Notify(ply, "Проводка станции тебе неизвестна — поглоти техника или инженера.")
        return ""
    end
    if GetGlobalBool("P11_Blackout", false) then
        POLUS11.Notify(ply, "Проводка уже коротнула — света на станции и так нет.")
        return ""
    end
    ply.P11_SabCD = ply.P11_SabCD or 0
    if CurTime() < ply.P11_SabCD then
        POLUS11.Notify(ply, "Жилы ещё не остыли: саботаж через " ..
            math.ceil(ply.P11_SabCD - CurTime()) .. " сек.")
        return ""
    end
    ply.P11_SabCD = CurTime() + SAB_CD

    if POLUS11.SetBlackout then
        POLUS11.SetBlackout(true)
        timer.Create("P11.MindSabEnd", SAB_LEN, 1, function()
            if GetGlobalBool("P11_Blackout", false) then
                POLUS11.SetBlackout(false)
            end
        end)
        POLUS11.Notify(ply, "САБОТАЖ: ты коротнул жилы щитовой — станция во тьме на " ..
            SAB_LEN .. " сек. Охоться.")
        PrintMessage(HUD_PRINTTALK, "[СТАНЦИЯ] ВНЕЗАПНАЯ АВАРИЯ ЩИТОВОЙ: свет гаснет, ремонтная бригада выехала.")
        POLUS11.Log("РАЗУМ ЖЕРТВЫ: САБОТАЖ СВЕТА от " .. ply:Nick() .. " (" .. SAB_LEN .. " сек)")
    end
    return ""
end)

-- респавн «человеком» (нечто погибло/рейс кончился) — гасим метки
hook.Add("PlayerSpawn", "P11.MindSpawn", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) and not ply:GetNWBool("P11_Infected", false) then
            ply.P11_Mind = nil
            ply:SetNWString("P11_ThingMind", "")
            ply:SetNWBool("P11_MindSled", false)
        end
    end)
end)

print("[POLUS-11] разум жертвы v4.19.4 «ПОЧЁТ»: медик→реген всегда, техник→!саботаж света (150с/6мин), следователь→метки допуска")
