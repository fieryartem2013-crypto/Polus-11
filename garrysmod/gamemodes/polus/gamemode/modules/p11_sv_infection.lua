-- ============================================================
--  ПОЛЮС-11 — ЯДРО ЗАРАЖЕНИЯ (сервер)
-- ============================================================

util.AddNetworkString("P11_InfectFX")
util.AddNetworkString("P11_HiveSync")

local function Log(msg)
    print("[POLUS-11] " .. msg)
    hook.Run("Polus11.Log", msg)
end
POLUS11.Log = Log

local function Notify(ply, msg)
    if not IsValid(ply) then return end
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, 1, 4, msg)
    else
        ply:ChatPrint("[ПОЛЮС-11] " .. msg)
    end
end
POLUS11.Notify = Notify

-- ======================== ЗАРАЖЕНИЕ ========================

function POLUS11.Infect(ply, source, silent)
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:GetNWBool("P11_Infected", false) then return false end

    ply:SetNWBool("P11_Infected", true)
    ply:SetNWBool("P11_InfActive", false)
    ply.P11_InfectedAt = CurTime()
    ply.P11_Incubation = math.random(POLUS11.Config.IncubationMin, POLUS11.Config.IncubationMax)

    Log("ЗАРАЖЁН: " .. ply:Nick() .. " (источник: " .. tostring(source or "?") .. ")")
    hook.Run("Polus11.Infected", ply, source)

    if not silent then
        Notify(ply, "Вы чувствуете странный холод под кожей...")
    end

    POLUS11.SyncHive()
    return true
end

function POLUS11.Cure(ply, silent)
    if not IsValid(ply) then return end
    ply:SetNWBool("P11_Infected", false)
    ply:SetNWBool("P11_InfActive", false)
    ply.P11_Incubation = nil
    if not silent then
        Notify(ply, "Холод отпустил. Вы снова человек.")
    end
    POLUS11.SyncHive()
end

-- активация после инкубации: Нечто просыпается
local function Activate(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetNWBool("P11_InfActive", false) then return end

    ply:SetNWBool("P11_InfActive", true)
    Log("НЕЧТО АКТИВИРОВАНО: " .. ply:Nick())
    Notify(ply, "ЧТО-ТО ВНУТРИ ПРОСНУЛОСЬ. Скоро оно будет голодать.")

    timer.Simple(0.5, function()
        if IsValid(ply) then
            net.Start("P11_InfectFX")
            net.Send(ply)
        end
    end)

    if POLUS11.Config.AutoGiveThing then
        ply:Give("weapon_polus11_thing")
        Notify(ply, "У вас появилось оружие: НЕЧТО. Приручите его.")
    end
end

-- тик: инкубация + треск хрящей
timer.Create("P11_IncubationTick", 3, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWBool("P11_Infected", false)
        and not ply:GetNWBool("P11_InfActive", false)
        and ply.P11_Incubation
        and CurTime() - (ply.P11_InfectedAt or 0) >= ply.P11_Incubation then
            Activate(ply)
        end
    end
end)

-- треск/шорох рядом с носителем
timer.Create("P11_Crackle", 8, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local ok = ply:Alive() and ply:GetNWBool("P11_Infected", false)
        if ok then
            ply.P11_NextCrackle = ply.P11_NextCrackle or (CurTime() + math.random(POLUS11.Config.CrackleEveryMin, POLUS11.Config.CrackleEveryMax))
            if CurTime() >= ply.P11_NextCrackle then
                ply.P11_NextCrackle = CurTime() + math.random(POLUS11.Config.CrackleEveryMin, POLUS11.Config.CrackleEveryMax)

                local pos = ply:GetPos()
                for _, near in ipairs(ents.FindInSphere(pos, POLUS11.Config.CrackleRadius)) do
                    if near:IsPlayer() and near ~= ply and near:Alive() then
                        near:SendLua([[surface.PlaySound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1,4) .. ".wav")]])
                    end
                end
            end
        end
    end
end)

-- ======================== УЛЕЙ (заражённые видят своих) ========================

function POLUS11.SyncHive()
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWBool("P11_Infected", false) then
            net.Start("P11_HiveSync")
                local list = {}
                for _, p2 in ipairs(player.GetAll()) do
                    if p2 ~= ply and p2:GetNWBool("P11_Infected", false) then
                        list[#list + 1] = p2
                    end
                end
                net.WriteUInt(#list, 8)
                for _, p2 in ipairs(list) do
                    net.WriteEntity(p2)
                end
            net.Send(ply)
        end
    end
end

timer.Create("P11_HiveSync", 10, 0, POLUS11.SyncHive)

-- ======================== ЗАЩИТА НЕЧТО: пули vs огонь ========================

hook.Add("EntityTakeDamage", "P11_DamageScale", function(victim, dmg)
    -- игрок-Нечто
    if victim:IsPlayer() and victim:GetNWBool("P11_Infected", false) and victim:GetNWBool("P11_InfActive", false) then
        if dmg:IsDamageType(DMG_BURN) or dmg:IsDamageType(DMG_DIRECT) then
            dmg:ScaleDamage(POLUS11.Config.FireMulVsThing)
        elseif dmg:IsDamageType(DMG_BULLET) or dmg:IsDamageType(DMG_BUCKSHOT) then
            dmg:ScaleDamage(POLUS11.Config.BulletMulVsThing)
        end
        -- для задачи охраны: кто бьёт Нечто
        hook.Run("P11.ThingDamaged", victim, dmg:GetAttacker(), dmg:GetDamage())
        return
    end

    -- босс Тварь
    if victim.P11_IsBoss and (dmg:IsDamageType(DMG_BURN)) then
        dmg:ScaleDamage(POLUS11.Config.FireMulVsBoss)
    end
end)

-- ======================== РЕСПАВН / СМЕРТЬ ========================

hook.Add("PlayerSpawn", "P11_AfterSpawn", function(ply)
    if not POLUS11.Config.InfectionPersists and ply:GetNWBool("P11_Infected", false) then
        POLUS11.Cure(ply, true)
    end

    -- активный Нечто при респавне: вернуть когти (смерть их забрала)
    if POLUS11.Config.AutoGiveThing
    and ply:GetNWBool("P11_Infected", false)
    and ply:GetNWBool("P11_InfActive", false)
    and not ply:HasWeapon("weapon_polus11_thing") then
        timer.Simple(0.5, function()
            if IsValid(ply) and ply:Alive() and not ply:HasWeapon("weapon_polus11_thing") then
                ply:Give("weapon_polus11_thing")
            end
        end)
    end

    -- сброс украденной личности Имитатора
    if DarkRP and ply.setDarkRPVar and ply.P11_TrueIdentity and ply.P11_TrueIdentity.rpname then
        pcall(function()
            ply:setDarkRPVar("rpname", ply.P11_TrueIdentity.rpname)
        end)
    end
    ply.P11_FakeNick = nil
    ply.P11_TrueIdentity = nil
    ply.P11_Revealed = false
    ply.P11_SavedModel = nil
    ply:SetNWString("P11_FakeNick", "")
    -- v4.2.1: возвращаем и свою должность отображения + СВОЙ код документа
    ply:SetNWInt("P11_FakeJob", 0)
    ply:SetNWString("P11_FakeDesc", "")
    if ply.P11_DocCode then ply:SetNWString("P11_DocCode", ply.P11_DocCode) end

    -- сброс тела Поглотителя (умер с классом «brute»)
    if ply.P11_BruteSaved then
        ply:SetMaxHealth(ply.P11_BruteSaved.hp > 0 and ply.P11_BruteSaved.hp or 100)
        ply:SetWalkSpeed(ply.P11_BruteSaved.walk)
        ply:SetRunSpeed(ply.P11_BruteSaved.run)
        ply.P11_BruteSaved = nil
    end
    -- сброс пут Поглотителя
    if ply.P11_RootSaved then
        ply:SetWalkSpeed(ply.P11_RootSaved.walk)
        ply:SetRunSpeed(ply.P11_RootSaved.run)
        ply.P11_RootSaved = nil
    end
    -- «доза спор» обнуляется со смертью
    ply:SetNWFloat("P11_Exposure", 0)

    -- сброс баффа скорости в темноте (умер во время блэкаута)
    if ply.P11_DarkSpeedSaved then
        ply:SetWalkSpeed(ply.P11_DarkSpeedSaved.w)
        ply:SetRunSpeed(ply.P11_DarkSpeedSaved.r)
        ply.P11_DarkSpeedSaved = nil
    end
    -- если блэкаут ещё идёт — переприменить бафф честно (от свежей скорости)
    if GetGlobalBool("P11_Blackout", false) and POLUS11.ApplyDarkSpeed then
        POLUS11.ApplyDarkSpeed(true)
    end
end)

-- ======================== ТРЕКЕР ТРУПОВ (для поглощения личности) ========================

hook.Add("PlayerDeath", "P11_CorpseTrack", function(victim, inf, att)
    if not IsValid(victim) or not victim:IsPlayer() then return end

    -- снимаем личность с живого игрока СРАЗУ (до создания трупа)
    local bg = {}
    for i = 0, victim:GetNumBodyGroups() - 1 do
        bg[i] = victim:GetBodygroup(i)
    end

    local identity = {
        nick   = victim:Nick(),
        model  = victim:GetModel(),
        skin   = victim:GetSkin(),
        color  = victim:GetColor(),
        pcolor = victim:GetPlayerColor(),
        wcolor = victim:GetWeaponColor(),
        bodygroups = bg,
        -- для вскрытия: заражение на момент смерти (трупы не меняются)
        infected = victim:GetNWBool("P11_Infected", false),
    }
    if DarkRP and victim.getDarkRPVar then
        identity.rpname = victim:getDarkRPVar("rpname") or identity.nick
    else
        identity.rpname = identity.nick
    end

    -- v4.2.1: документ и должность — тоже часть личности
    identity.doc = victim:GetNWString("P11_DocCode", "")
    identity.job = victim:Team()
    -- v4.3.0: позывной и описание бойца — тоже часть личности
    identity.desc = victim:GetNWString("P11_CharDesc", "")
    local cn = victim:GetNWString("P11_CharName", "")
    if cn ~= "" then identity.nick = cn end
    -- жертва сама была тварью в чужой личине? передаём личину дальше по цепочке
    local worn = victim:GetNWString("P11_FakeNick", "")
    if worn ~= "" then identity.nick = worn end

    local pos = victim:GetPos()

    -- труп появляется через кадр
    timer.Simple(0, function()
        local best, bestDist
        for _, e in ipairs(ents.FindInSphere(pos, 80)) do
            -- берём только СВЕЖИЙ ragdoll или ragdoll с ТОЙ ЖЕ моделью,
            -- что у жертвы — старые трупы NPC поблизости не помечаются
            if IsValid(e) and e:GetClass() == "prop_ragdoll" and not e.P11_Identity then
                local fresh = (CurTime() - e:GetCreationTime()) < 2
                local sameModel = identity.model ~= nil and e:GetModel() == identity.model
                if fresh or sameModel then
                    local d = e:GetPos():DistToSqr(pos)
                    if not bestDist or d < bestDist then
                        best, bestDist = e, d
                    end
                end
            end
        end
        if IsValid(best) then
            best.P11_Identity = identity
            best:SetNWString("P11_CorpseName", identity.nick)
        end
    end)
end)

hook.Add("PlayerDisconnected", "P11_Disco", function(ply)
    if ply:GetNWBool("P11_Infected", false) then
        Log("Заражённый покинул станцию: " .. ply:Nick())
    end
end)

-- ======================== КОМАНДА АДМИНА: заразить сейчас ========================

concommand.Add("polus11_infect", function(ply, cmd, args)
    if IsValid(ply) and not POLUS11.Config.Admin(ply) then return end
    local target = player.GetByID(tonumber(args[1] or "") or -1)
    if IsValid(target) then
        POLUS11.Infect(target, "админ-команда")
        Log("Админ заразил: " .. target:Nick())
    end
end)
