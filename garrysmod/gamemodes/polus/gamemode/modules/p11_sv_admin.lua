-- ============================================================
--  ПОЛЮС-11 — ПУЛЬТ ДЕЖУРНОГО (сервер): фазы, ивенты, лог, босс
-- ============================================================

util.AddNetworkString("P11_PanelData")
util.AddNetworkString("P11_PanelAction")

-- ============ ЛОГ ============

POLUS11.LogLines = POLUS11.LogLines or {}

hook.Add("Polus11.Log", "P11_LogStore", function(msg)
    local line = "[" .. os.date("%H:%M:%S") .. "] " .. msg
    table.insert(POLUS11.LogLines, line)
    if #POLUS11.LogLines > 40 then
        table.remove(POLUS11.LogLines, 1)
    end

    -- обновить пульт у админов, у которых он открыт
    for _, ply in ipairs(player.GetAll()) do
        if ply.P11_PanelOpen then
            POLUS11.SendPanelData(ply)
        end
    end
end)

-- ============ ОТПРАВКА ДАННЫХ В ПУЛЬТ ============

function POLUS11.SendPanelData(ply)
    if not POLUS11.Config.Admin(ply) then return end

    net.Start("P11_PanelData")
        -- игроки
        local plys = {}
        for _, p in ipairs(player.GetAll()) do
            plys[#plys + 1] = p
        end
        net.WriteUInt(#plys, 8)
        for _, p in ipairs(plys) do
            net.WriteString(p:Nick())
            net.WriteUInt(p:EntIndex(), 8)
            net.WriteBool(p:GetNWBool("P11_Infected", false))
            net.WriteBool(p:GetNWBool("P11_InfActive", false))
        end

        -- фаза, свет, буря
        net.WriteString(GetGlobalString("P11_Phase", POLUS11.Config.Phases[1]))
        net.WriteBool(GetGlobalBool("P11_Blackout", false))
        net.WriteBool(GetGlobalBool("P11_Storm", false))

        -- топливо по генераторам
        local gens = ents.FindByClass("polus11_generator")
        net.WriteUInt(#gens, 8)
        for _, g in ipairs(gens) do
            net.WriteUInt(math.floor(g.GetFuel and g:GetFuel() or 0), 16)
            net.WriteBool(g:GetDamaged())
        end

        -- лог (последние 20)
        local n = math.min(#POLUS11.LogLines, 20)
        net.WriteUInt(n, 8)
        for i = #POLUS11.LogLines - n + 1, #POLUS11.LogLines do
            net.WriteString(POLUS11.LogLines[i])
        end
    net.Send(ply)
end

-- ============ ДЕЙСТВИЯ ПУЛЬТА ============

net.Receive("P11_PanelAction", function(len, ply)
    if not IsValid(ply) or not POLUS11.Config.Admin(ply) then return end

    local act = net.ReadUInt(8)

    if act == 1 then -- заразить выбранного
        local idx = net.ReadUInt(8)
        local t = Entity(idx)
        if IsValid(t) and t:IsPlayer() then
            POLUS11.Infect(t, "пульт (" .. ply:Nick() .. ")")
            POLUS11.Notify(ply, "Заражён: " .. t:Nick())
        end

    elseif act == 2 then -- случайный пациент-ноль
        local zero = POLUS11.RandomPatientZero()
        if IsValid(zero) then
            POLUS11.Notify(ply, "Пациент-ноль: " .. zero:Nick())
        else
            POLUS11.Notify(ply, "Нет кандидатов.")
        end

    elseif act == 3 then -- смена фазы
        local ph = net.ReadUInt(4)
        POLUS11.SetPhase(ph)

    elseif act == 4 then -- авария: блэкаут на 120 сек
        POLUS11.SetBlackout(true)
        POLUS11.Notify(ply, "Авария! Свет отключён на 2 минуты.")
        timer.Simple(120, function()
            if GetGlobalBool("P11_Blackout", false) then
                POLUS11.SetBlackout(false)
            end
        end)

    elseif act == 5 then -- магнитная буря 90 сек
        POLUS11.SetStorm(true, 90)

    elseif act == 6 then -- крики из вентиляции
        POLUS11.ScreamsInVent()
        POLUS11.Notify(ply, "Крики пошли в эфир...")

    elseif act == 7 then -- спавн Твари из Теплицы
        local tr = ply:GetEyeTrace()
        POLUS11.SpawnBoss(tr.HitPos + Vector(0, 0, 10))
        POLUS11.Notify(ply, "ТВАРЬ ИЗ ТЕПЛИЦЫ ВЫШЛА НА ОХОТУ!")

    elseif act == 8 then -- вылечить всех (рестарт сценария)
        for _, p in ipairs(player.GetAll()) do
            p:SetNWBool("P11_Infected", false)
            p:SetNWBool("P11_InfActive", false)
            p.P11_Incubation = nil
        end
        POLUS11.SyncHive()
        POLUS11.SetPhase(1)
        POLUS11.Log("Пульт: все вылечены, смена перезапущена.")

    elseif act == 9 then -- вернуть свет
        POLUS11.SetBlackout(false)

    elseif act == 10 then -- пульт открыт/закрыт (флаг)
        ply.P11_PanelOpen = net.ReadBool()

    elseif act == 11 then -- рестарт топлива генераторов
        for _, g in ipairs(ents.FindByClass("polus11_generator")) do
            g:AddFuelBarrel(0.5)
        end
        POLUS11.Notify(ply, "Генераторы долиты (+полбочки).")

    elseif act == 12 then -- СИРЕНА: общее построение
        POLUS11.TriggerSiren(ply)
    end

    -- обновить данные
    POLUS11.SendPanelData(ply)
end)

-- ============ СИРЕНА ОБЩЕГО ПОСТРОЕНИЯ ============

function POLUS11.TriggerSiren(ply)
    POLUS11.NextSiren = POLUS11.NextSiren or 0
    if CurTime() < POLUS11.NextSiren then
        POLUS11.Notify(ply, "Сирена на перезарядке (" .. math.ceil(POLUS11.NextSiren - CurTime()) .. " сек)")
        return
    end
    POLUS11.NextSiren = CurTime() + (POLUS11.Config.SirenCooldown or 90)

    POLUS11.Broadcast("!!! ОБЩЕЕ ПОСТРОЕНИЕ !!! Всему экипажу собраться у дежурного офицера. 7 СЕКУНД!")

    for _, p in ipairs(player.GetAll()) do
        for i = 0, 2 do
            timer.Simple(i * 2.2, function()
                if IsValid(p) then
                    p:SendLua([[surface.PlaySound("ambient/alarms/warningbell1.wav")]])
                end
            end)
        end
    end

    -- замер построения через 7 сек: командир, рядом с которым ≥40% станции → задача сделана
    -- v3.9: id должности «officer» упразднён — проверяем флаг command
    -- (генералы РККА, особисты НКВД и любые правки из админки).
    timer.Simple(7, function()
        local all = #player.GetAll()
        if all < 2 then return end
        for _, off in ipairs(player.GetAll()) do
            local offJob = P11FW and P11FW.GetJob and P11FW.GetJob(off) or nil
            if offJob and offJob.command == true then
                local near = 0
                for _, p in ipairs(player.GetAll()) do
                    if p:Alive() and p:GetPos():DistToSqr(off:GetPos()) <= 600 * 600 then
                        near = near + 1
                    end
                end
                if near / all >= 0.4 then
                    if POLUS11.TaskEvent then POLUS11.TaskEvent(off, "rollcall") end
                    POLUS11.Log("Построение ПРОВЕДЕНО офицером " .. off:Nick() .. " (" .. near .. "/" .. all .. ")")
                end
            end
        end
    end)
end

-- ============ БОСС: ТВАРЬ ИЗ ТЕПЛИЦЫ ============

function POLUS11.SpawnBoss(pos)
    local boss = ents.Create("npc_fast_zombie")
    if not IsValid(boss) then return end

    boss:SetPos(pos)
    boss:Spawn()
    boss:SetHealth(900)
    boss:SetMaxHealth(900)
    boss.P11_IsBoss = true

    -- увеличиваем (после тика, чтобы применилось)
    timer.Simple(0.1, function()
        if IsValid(boss) then
            boss:SetModelScale(2.2, 0.5)
        end
    end)

    boss:EmitSound("npc/zombie_poison/pz_alert1.wav", 100, 90)
    POLUS11.Log("!!! ТВАРЬ ИЗ ТЕПЛИЦЫ заспавнена ивент-мастером")

    -- периодически выпускает малых имитаторов
    local idx = boss:EntIndex()
    timer.Create("P11_BossMinions_" .. idx, 9, 0, function()
        if not IsValid(boss) or not boss:Alive() then
            timer.Remove("P11_BossMinions_" .. idx)
            timer.Remove("P11_BossRoar_" .. idx)
            return
        end

        -- не больше 4 малых одновременно
        local small = 0
        for _, e in ipairs(ents.FindByClass("npc_fast_zombie")) do
            if e ~= boss and e.P11_BossMinion then small = small + 1 end
        end
        if small >= 4 then return end

        local min = ents.Create("npc_fast_zombie")
        if IsValid(min) then
            local ang = math.random() * math.pi * 2
            min:SetPos(boss:GetPos() + Vector(math.cos(ang) * 120, math.sin(ang) * 120, 10))
            min:Spawn()
            min.P11_BossMinion = true
            min:EmitSound("npc/fast_zombie/idle2.wav", 80, 110)
        end
    end)

    -- рык-волна: отбрасывает людей каждые 14 секунд
    timer.Create("P11_BossRoar_" .. idx, 14, 0, function()
        if not IsValid(boss) or not boss:Alive() then
            timer.Remove("P11_BossRoar_" .. idx)
            return
        end
        boss:EmitSound("npc/fast_zombie/fz_scream1.wav", 110, 75)

        local bpos = boss:GetPos()
        for _, p in ipairs(player.GetAll()) do
            if p:Alive() and p:GetPos():DistToSqr(bpos) <= 700 * 700 then
                local push = (p:GetPos() - bpos):GetNormalized() * 320
                p:SetVelocity(push + Vector(0, 0, 140))
                p:ViewPunch(Angle(math.random(-16, 16), math.random(-16, 16), 0))
            end
        end
    end)

    return boss
end

-- урон боссу: пули -50%
hook.Add("EntityTakeDamage", "P11_BossArmor", function(victim, dmg)
    if victim.P11_IsBoss then
        if dmg:IsDamageType(DMG_BULLET) or dmg:IsDamageType(DMG_BUCKSHOT) then
            dmg:ScaleDamage(0.5)
        elseif dmg:IsDamageType(DMG_BURN) then
            dmg:ScaleDamage(5) -- огонь — его смерть
        end
    end
end)
