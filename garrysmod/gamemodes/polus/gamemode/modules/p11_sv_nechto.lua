-- ============================================================
--  ПОЛЮС-11 — НЕЧТО 2.0 (сервер)
--  • Крик ужаса (!крик): все рядом — толчок, паника, звон
--  • Смена формы (!форма поглотитель/споровик/имитатор)
--    — у Нечто теперь ТРИ класса (два новых в v2.3)
--  • Выдача химсвета экипажу на спавне
-- ============================================================

-- классы Нечто: id -> оружие
POLUS11.ThingForms = {
    imitator     = { wep = "weapon_polus11_thing",     name = "Имитатор" },
    brute        = { wep = "weapon_polus11_thing_brute", name = "Поглотитель" },
    spore        = { wep = "weapon_polus11_thing_spore", name = "Споровик" },
}

local function IsActiveThing(ply)
    return IsValid(ply)
        and ply:GetNWBool("P11_Infected", false)
        and ply:GetNWBool("P11_InfActive", false)
end

-- ============ СМЕНА ФОРМЫ ============

function POLUS11.SetThingForm(ply, formId)
    local form = POLUS11.ThingForms[formId]
    if not form then return false end

    ply:StripWeapon("weapon_polus11_thing")
    ply:StripWeapon("weapon_polus11_thing_split")
    ply:StripWeapon("weapon_polus11_thing_brute")
    ply:StripWeapon("weapon_polus11_thing_spore")

    ply:Give(form.wep)
    ply.P11_ThingForm = formId
    POLUS11.Notify(ply, "Форма сменена: «" .. form.name .. "».")
    POLUS11.Log(ply:Nick() .. " сменил форму Нечто на " .. form.name)
    return true
end

-- ============ КРИК УЖАСА ============

function POLUS11.ThingScream(ply)
    ply.P11_NextScream = ply.P11_NextScream or 0
    if CurTime() < ply.P11_NextScream then
        POLUS11.Notify(ply, "Крик не готов (" .. math.ceil(ply.P11_NextScream - CurTime()) .. " сек)")
        return
    end
    ply.P11_NextScream = CurTime() + (POLUS11.Config.ScreamCooldown or 45)

    ply:EmitSound("npc/fast_zombie/fz_scream1.wav", 100, 85)
    timer.Simple(0.4, function()
        if IsValid(ply) then ply:EmitSound("npc/zombie_poison/pz_alert2.wav", 100, 70) end
    end)

    local radius = POLUS11.Config.ScreamRadius or 700
    local myPos = ply:GetPos()
    for _, vic in ipairs(player.GetAll()) do
        if vic ~= ply and vic:Alive() and vic:GetPos():DistToSqr(myPos) <= radius * radius then
            -- люди: паника + отброс (заражённым крик только подбадривает)
            local isThing = vic:GetNWBool("P11_Infected", false) and vic:GetNWBool("P11_InfActive", false)
            if not isThing then
                local push = (vic:GetPos() - myPos):GetNormalized() * 220
                vic:SetVelocity(push + Vector(0, 0, 60))
                vic:ViewPunch(Angle(math.random(-14, 14), math.random(-14, 14), 0))
                net.Start("P11_FearFX") net.Send(vic)

                -- человек на виду у Нечто, когда оно орёт — ПАЛЕВНО с точки зрения задач охраны
            end
        end
    end

    POLUS11.Log("КРИК НЕЧТО: " .. ply:Nick())
end

-- ============ СПАД «ДОЗЫ СПОР» ВНЕ ОБЛАКА ============

timer.Create("P11_ExposureDecay", 2, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local cur = ply:GetNWFloat("P11_Exposure", 0)
        if cur > 0 then
            ply:SetNWFloat("P11_Exposure", math.max(0, cur - (POLUS11.Config.ExposureDecay or 8)))
        end
    end
end)

-- ============ ХИМСВЕТ ЭКИПАЖУ ============

hook.Add("PlayerSpawn", "P11_ChemlightIssue", function(ply)
    if (POLUS11.Config.ChemlightGive or 0) <= 0 then return end
    timer.Simple(0.3, function()
        if IsValid(ply) and ply:Alive() and not ply:HasWeapon("weapon_polus11_chemlight") then
            ply:Give("weapon_polus11_chemlight")
            local wep = ply:GetWeapon("weapon_polus11_chemlight")
            if IsValid(wep) and wep.SetCharges then
                wep:SetCharges(POLUS11.Config.ChemlightGive)
            end
        end
    end)
end)

-- ============ ЧАТ-КОМАНДЫ НЕЧТО ============

hook.Add("PlayerSay", "P11_ThingChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t ~= "!крик" and t ~= "!крик ужаса" and not t:StartWith("!форма") then return end

    if not IsActiveThing(ply) then
        POLUS11.Notify(ply, "Это доступно только активному Нечто.")
        return ""
    end

    if t == "!крик" or t == "!крик ужаса" then
        POLUS11.ThingScream(ply)
        return ""
    end

    -- !форма <класс>
    ply.P11_NextForm = ply.P11_NextForm or 0
    if CurTime() < ply.P11_NextForm then
        POLUS11.Notify(ply, "Форму можно сменить через " .. math.ceil(ply.P11_NextForm - CurTime()) .. " сек")
        return ""
    end

    local arg = string.Trim(string.sub(t, 7))
    local map = {
        ["поглотитель"] = "brute",
        ["споровик"] = "spore",
        ["имитатор"] = "imitator",
        ["разделённый"] = "split",
        ["разделенный"] = "split",
    }
    local formId = map[arg]
    if formId == "split" then
        -- старый класс: просто вернуть ему его оружие
        ply.P11_NextForm = CurTime() + (POLUS11.Config.ClassSwitchCooldown or 60)
        ply:StripWeapon("weapon_polus11_thing")
        ply:StripWeapon("weapon_polus11_thing_brute")
        ply:StripWeapon("weapon_polus11_thing_spore")
        ply:Give("weapon_polus11_thing_split")
        ply.P11_ThingForm = "split"
        POLUS11.Notify(ply, "Форма сменена: «Разделённый».")
        return ""
    end
    if not formId then
        POLUS11.Notify(ply, "Формы: !форма поглотитель / споровик / имитатор / разделённый")
        return ""
    end

    if POLUS11.SetThingForm(ply, formId) then
        ply.P11_NextForm = CurTime() + (POLUS11.Config.ClassSwitchCooldown or 60)
    end
    return ""
end)
