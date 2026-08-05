-- ============================================================
--  ПОЛЮС-11 — энергия станции: блэкаут, буря, тьма (сервер)
-- ============================================================

util.AddNetworkString("P11_BlackoutFX")

-- ======================== БЛЭКАУТ ========================

function POLUS11.SetBlackout(on)
    local cur = GetGlobalBool("P11_Blackout", false)
    if cur == on then return end
    SetGlobalBool("P11_Blackout", on)

    if on then
        POLUS11.Log("БЛЭКАУТ! Свет погас на всей станции.")
        for _, ply in ipairs(player.GetAll()) do
            net.Start("P11_BlackoutFX")
                net.WriteBool(true)
            net.Send(ply)
        end
        -- бафф Нечто в темноте
        timer.Create("P11_DarkRegen", POLUS11.Config.DarkRegenTick, 0, function()
            if not GetGlobalBool("P11_Blackout", false) then
                timer.Remove("P11_DarkRegen")
                return
            end
            for _, ply in ipairs(player.GetAll()) do
                if ply:Alive() and ply:GetNWBool("P11_Infected", false) and ply:GetNWBool("P11_InfActive", false) then
                    local hp = math.min(ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100, ply:Health() + POLUS11.Config.DarkRegenHP)
                    ply:SetHealth(hp)
                end
            end
        end)
        POLUS11.ApplyDarkSpeed(true)
    else
        POLUS11.Log("Энергия восстановлена. Свет есть.")
        for _, ply in ipairs(player.GetAll()) do
            net.Start("P11_BlackoutFX")
                net.WriteBool(false)
            net.Send(ply)
        end
        POLUS11.ApplyDarkSpeed(false)
    end
end

-- скорость Нечто в темноте
function POLUS11.ApplyDarkSpeed(on)
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWBool("P11_Infected", false) and ply:GetNWBool("P11_InfActive", false) then
            if on then
                if not ply.P11_DarkSpeedSaved then
                    ply.P11_DarkSpeedSaved = {w = ply:GetWalkSpeed(), r = ply:GetRunSpeed()}
                end
                ply:SetWalkSpeed(ply.P11_DarkSpeedSaved.w * POLUS11.Config.DarkSpeedMul)
                ply:SetRunSpeed(ply.P11_DarkSpeedSaved.r * POLUS11.Config.DarkSpeedMul)
            else
                if ply.P11_DarkSpeedSaved then
                    ply:SetWalkSpeed(ply.P11_DarkSpeedSaved.w)
                    ply:SetRunSpeed(ply.P11_DarkSpeedSaved.r)
                    ply.P11_DarkSpeedSaved = nil
                end
            end
        end
    end
end

-- ======================== МАГНИТНАЯ БУРЯ ========================

function POLUS11.SetStorm(on, seconds)
    SetGlobalBool("P11_Storm", on)
    if on then
        POLUS11.Log("Магнитная буря! Рации глушит.")
        if seconds and seconds > 0 then
            timer.Create("P11_StormEnd", seconds, 1, function()
                POLUS11.SetStorm(false)
            end)
        end
    else
        POLUS11.Log("Буря стихла.")
        timer.Remove("P11_StormEnd")
    end
end

-- ======================== СРЕДСТВА ДЛЯ ПУЛЬТА ========================

function POLUS11.SetPhase(idx)
    local phases = POLUS11.Config.Phases
    local name = phases[idx] or phases[1]
    SetGlobalString("P11_Phase", name)
    POLUS11.Log("Фаза смены: " .. name)
end

function POLUS11.ScreamsInVent()
    for _, ply in ipairs(player.GetAll()) do
        ply:SendLua([[surface.PlaySound("npc/zombie/zombie_pain" .. math.random(1,3) .. ".wav")]])
    end
    POLUS11.Log("Из вентиляции послышались крики...")
end

function POLUS11.RandomPatientZero()
    local candidates = {}
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() and not ply:GetNWBool("P11_Infected", false) then
            candidates[#candidates + 1] = ply
        end
    end
    if #candidates == 0 then return nil end
    local zero = candidates[math.random(#candidates)]
    POLUS11.Infect(zero, "пациент-ноль", true)
    POLUS11.Notify(zero, "Что-то коснулось вас во тьме...")
    return zero
end
