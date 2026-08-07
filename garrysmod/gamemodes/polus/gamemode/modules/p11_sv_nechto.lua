-- ============================================================
--  ПОЛЮС-11 — НЕЧТО 2.0 (сервер)
--  • Крик ужаса (!крик): все рядом — толчок, паника, звон
--  • Смена формы (!форма поглотитель/споровик/имитатор)
--    — у Нечто теперь ТРИ класса (два новых в v2.3)
--  • Выдача химсвета экипажу на спавне
-- ============================================================

-- классы Нечто: id -> оружие + тело монстра (v2.6: у каждой формы СВОЯ модель)
util.AddNetworkString("P11_ThingAct") -- v4.8.3: кнопки меню мутаций (R)

POLUS11.ThingForms = {
    imitator     = { wep = "weapon_polus11_thing",       name = "Имитатор",    model = "models/zombie/classic.mdl" },
    brute        = { wep = "weapon_polus11_thing_brute", name = "Поглотитель", model = "models/zombie/poison.mdl" },
    spore        = { wep = "weapon_polus11_thing_spore", name = "Споровик",    model = "models/zombie/fast.mdl" },
    split        = { wep = "weapon_polus11_thing_split", name = "Разделённый", model = "models/zombie/fast_torso.mdl" },
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
    ply:SetNWString("P11_ThingForm", formId)
    POLUS11.Notify(ply, "Форма сменена: «" .. form.name .. "».")
    POLUS11.Log(ply:Nick() .. " сменил форму Нечто на " .. form.name)
    return true
end

-- ============ МАСКИРОВКА (v2.6: единая для ВСЕХ форм) ============
-- Прячет/являет тело монстра. У Поглотителя вместе с маскировкой
-- снимается и тяжёлое тело (замаскирован = обычные человеческие 100 хп).

function POLUS11.ToggleMask(ply)
    if not IsActiveThing(ply) then
        POLUS11.Notify(ply, "Это доступно только активному Нечто.")
        return
    end
    ply.P11_NextMask = ply.P11_NextMask or 0
    if CurTime() < ply.P11_NextMask then return end
    ply.P11_NextMask = CurTime() + 1.2

    if ply.P11_Revealed then
        -- только что дрался — пусть остынет пару секунд
        if CurTime() - (ply.P11_RevealedAt or 0) < 4 then
            POLUS11.Notify(ply, "Нечто слишком разгорячён — подождите пару секунд.")
            return
        end
        POLUS11_HideThing(ply)
        ply:EmitSound("npc/zombie/zombie_voice_idle2.wav", 60, 90)
        POLUS11.Notify(ply, "Маскировка: ты снова выглядишь как человек.")
    else
        POLUS11_RevealThing(ply, ply:GetActiveWeapon())
        POLUS11.Notify(ply, "ФОРМА ЯВЛЕНА. Люди поблизости кричат.")
    end
end

concommand.Add("p11_mask", function(ply)
    if IsValid(ply) then POLUS11.ToggleMask(ply) end
end)

-- ============ РАЗРЫВ СПОРОВИКА (!разрыв) ============

function POLUS11.SporeSelfBurst(ply)
    if not IsActiveThing(ply) then return end
    if (ply.P11_ThingForm or "") ~= "spore" then
        POLUS11.Notify(ply, "Разрыв доступен только форме «Споровик».")
        return
    end
    ply.P11_NextBurst = ply.P11_NextBurst or 0
    if CurTime() < ply.P11_NextBurst then
        POLUS11.Notify(ply, "Разрыв не готов (" .. math.ceil(ply.P11_NextBurst - CurTime()) .. " сек)")
        return
    end
    if ply:Health() <= 70 then
        POLUS11.Notify(ply, "Слишком мало плоти для разрыва (нужно > 70 хп).")
        return
    end
    ply.P11_NextBurst = CurTime() + 20

    ply:EmitSound("npc/zombie/zombie_alert" .. math.random(1, 3) .. ".wav", 90, 70)
    ply:SetHealth(ply:Health() - 60)

    local cloud = ents.Create("polus11_sporecloud")
    if IsValid(cloud) then
        cloud:SetPos(ply:GetPos() + Vector(0, 0, 40))
        cloud:SetOwner(ply)
        cloud:Spawn()
    end

    local ed = EffectData()
    ed:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
    util.Effect("BloodImpact", ed, true, true)
    util.Effect("bloodspray", ed, true, true)

    POLUS11.Notify(ply, "Вы РАЗОРВАЛИСЬ облаком спор. Люди рядом заражаются...")
    POLUS11.Log("РАЗРЫВ СПОРОВИКА: " .. ply:Nick())
end

-- ============ КРИК УЖАСА ============

function POLUS11.ThingScream(ply)
    ply.P11_NextScream = ply.P11_NextScream or 0
    if CurTime() < ply.P11_NextScream then
        POLUS11.Notify(ply, "Крик не готов (" .. math.ceil(ply.P11_NextScream - CurTime()) .. " сек)")
        return
    end
    ply.P11_NextScream = CurTime() + (POLUS11.Config.ScreamCooldown or 45)
    ply:SetNWFloat("P11_ScreamCd", ply.P11_NextScream)

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
    local isMask  = (t == "!маскировка" or t == "!маск" or t == "!маскировка вкл")
    local isBurst = (t == "!разрыв" or t == "!взрыв")
    local isScream = (t == "!крик" or t == "!крик ужаса")
    if not isScream and not isMask and not isBurst and not t:StartWith("!форма") then return end

    if not IsActiveThing(ply) then
        POLUS11.Notify(ply, "Это доступно только активному Нечто.")
        return ""
    end

    if isScream then
        POLUS11.ThingScream(ply)
        return ""
    end

    if isMask then
        POLUS11.ToggleMask(ply)
        return ""
    end

    if isBurst then
        POLUS11.SporeSelfBurst(ply)
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
    if not formId then
        POLUS11.Notify(ply, "Формы: !форма поглотитель / споровик / имитатор / разделённый")
        return ""
    end

    if POLUS11.SetThingForm(ply, formId) then
        ply.P11_NextForm = CurTime() + (POLUS11.Config.ClassSwitchCooldown or 60)
        ply:SetNWFloat("P11_FormCd", ply.P11_NextForm)
    end
    return ""
end)


-- ============================================================
--  v4.8.3 «ПОГЛОЩЕНИЕ»: РЕВОРК НЕЧТО (заявка владельца)
--  1) при убийстве когтями Нечто АВТОМАТОМ жрёт труп и становится
--     им (личина жертвы: модель, имя, должность, код документа);
--  2) R — МЕНЮ МУТАЦИЙ (клиент), это — серверная часть кнопок;
--  3) ПКМ — способность формы (укол/масса/споры/плевок, как было).
-- ============================================================

-- 1) авто-съедение: свежий труп помечен инфекцией → съедаем сами
hook.Add("Polus11.CorpseTagged", "P11.ThingAutoDevour", function(corpse, identity, victim, att)
    if not (POLUS11.Config and POLUS11.Config.ThingAutoDevour) then return end
    if not (IsValid(att) and att:IsPlayer() and IsValid(victim) and att ~= victim) then return end
    if not (att:GetNWBool("P11_Infected", false) and att:GetNWBool("P11_InfActive", false)) then return end
    -- только КОГТЯМИ Имитатора (у остальных форм съедения личности нет)
    local wep = att.GetActiveWeapon and att:GetActiveWeapon()
    if not (IsValid(wep) and wep:GetClass() == "weapon_polus11_thing") then return end
    local cls = wep:GetClass()

    timer.Simple(0.45, function()
        if not (IsValid(att) and att:Alive() and IsValid(corpse)) then return end
        if not istable(corpse.P11_Identity) then return end
        local w = att:GetWeapon(cls)
        if IsValid(w) and w.EatCorpse then
            w:EatCorpse(att, corpse) -- личина + лечение + мутации (обёртка модуля мутаций)
            POLUS11.Log("АВТО-ПОГЛОЩЕНИЕ: " .. att:Nick() .. " сожрал труп своей жертвы «"
                .. tostring(identity.nick) .. "»")
        end
    end)
end)

-- 2) серверная часть кнопок меню мутаций
net.Receive("P11_ThingAct", function(len, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not (ply:GetNWBool("P11_Infected", false) and ply:GetNWBool("P11_InfActive", false)) then
        return -- меню Нечто — только активному Нечто
    end
    local act = net.ReadString()

    if act == "mask" then -- явить/скрыть форму монстра
        if POLUS11.ToggleMask then POLUS11.ToggleMask(ply) end

    elseif act == "unmask" then -- сбросить чужую личину
        if not ply.P11_FakeNick then
            POLUS11.Notify(ply, "Ты сейчас не в чужой личине.")
            return
        end
        if CurTime() - (ply.P11_IdentityTakenAt or 0) < 5 then
            POLUS11.Notify(ply, "Нечто ещё переваривает… "
                .. math.ceil(5 - (CurTime() - ply.P11_IdentityTakenAt)) .. " сек")
            return
        end
        if POLUS11_RestoreTrueIdentity then
            POLUS11_RestoreTrueIdentity(ply)
            ply:EmitSound("npc/zombie/zombie_voice_idle2.wav", 60, 90)
            POLUS11.Notify(ply, "Вы сбросили чужую личность.")
        end

    elseif act == "spider" then -- паучья форма Разделённого
        if (ply.P11_ThingForm or "") ~= "split" then
            POLUS11.Notify(ply, "Паучья форма — у Разделённого.")
            return
        end
        if POLUS11_ToggleSpider then POLUS11_ToggleSpider(ply) end

    elseif act == "form" then -- смена формы с кулдауном как в чате
        local formId = net.ReadString()
        if not POLUS11.ThingForms[formId] then return end
        ply.P11_NextForm = ply.P11_NextForm or 0
        if CurTime() < ply.P11_NextForm then
            POLUS11.Notify(ply, "Форму можно сменить через "
                .. math.ceil(ply.P11_NextForm - CurTime()) .. " сек")
            return
        end
        if POLUS11.SetThingForm(ply, formId) then
            ply.P11_NextForm = CurTime() + (POLUS11.Config.ClassSwitchCooldown or 60)
            ply:SetNWFloat("P11_FormCd", ply.P11_NextForm)
        end
    end
end)

print("[POLUS-11] реворк Нечто v4.8.3 «ПОГЛОЩЕНИЕ»: авто-съедение трупа при убийстве, R — меню мутаций (P11_ThingAct)")
