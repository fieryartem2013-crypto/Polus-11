-- ============================================================
--  ПОЛЮС-11 — ХП ПРИ СМЕНЕ ПРОФЫ + ТЕМП ШАГА v5.8.28
--  (НОВЫЙ ФАЙЛ, autorun/server)
--  1) После смены должности ХП/макс/броня = цифры НОВОЙ профы
--     (раньше ApplyLoadout резал только «сверху» — 100 ХП
--     оставались при переходе на штурмовика 125).
--  2) Игрок медленнее: шаг 130 / бег 250 / прыжок 105
--     (было 170 / 330 / 120). Живой тюнер: p11_speed 0.5..1.5
-- ============================================================

-- ============ 1) ХП ПРОФЫ ============
local function ApplyJobVitals(ply, jobId)
    if not IsValid(ply) or not ply:Alive() then return end
    -- активное Нечто держит своё тело (400+) — не сбиваем
    if ply:GetNWBool("P11_InfActive", false) then return end
    if ply:HasWeapon("weapon_polus11_thing")
        or ply:HasWeapon("weapon_polus11_thing_brute")
        or ply:HasWeapon("weapon_polus11_thing_split")
        or ply:HasWeapon("weapon_polus11_thing_spore") then
        return
    end
    local job = (P11FW.Jobs and P11FW.Jobs[jobId]) or (P11FW.GetJob and P11FW.GetJob(ply))
    if not job then return end
    local hp = math.Clamp(tonumber(job.hp) or 100, 1, 1000)
    local ar = math.Clamp(tonumber(job.armor) or 0, 0, 500)
    ply:SetMaxHealth(hp)
    ply:SetHealth(hp)
    ply:SetArmor(ar)
end

hook.Add("P11FW.JobChanged", "P11.JobHP.v5828", function(ply, jobId)
    ApplyJobVitals(ply, jobId)
    -- второй круг: лоадаут/телепорт/thingroot могут перетереть в тот же тик
    timer.Simple(0.25, function() ApplyJobVitals(ply, jobId) end)
    timer.Simple(0.70, function() ApplyJobVitals(ply, jobId) end)
end)

-- ============ 2) ТЕМП ============
local cvMul = CreateConVar("p11_speed", "0.76", FCVAR_ARCHIVE,
    "POLUS-11 v5.8.28: множитель шага/бега (1 = старые 170/330)")

local function ApplySlow(ply)
    if not IsValid(ply) then return end
    local m = POLUS11 and POLUS11.Config and POLUS11.Config.Movement
    local walk = (m and m.walk) or 170
    local run  = (m and m.run) or 330
    local jump = (m and m.jump) or 120
    local mul = math.Clamp(cvMul:GetFloat(), 0.4, 1.5)
    -- целевые «медленные» числа при mul=0.76: ~130 / 250 / ~105
    ply:SetWalkSpeed(math.floor(walk * mul))
    ply:SetRunSpeed(math.floor(run * mul))
    ply:SetJumpPower(math.floor(jump * math.max(0.8, mul)))
    ply:SetMaxSpeed(math.floor(run * mul))
end

-- перекрываем штатный ApplyMoveSpeeds, если он есть
local function WrapMove()
    if not POLUS11 then return end
    if POLUS11.ApplyMoveSpeeds and POLUS11.ApplyMoveSpeeds.P11_SlowV5828 then return end
    local orig = POLUS11.ApplyMoveSpeeds
    POLUS11.ApplyMoveSpeeds = function(ply)
        if orig then orig(ply) end
        ApplySlow(ply)
    end
    POLUS11.ApplyMoveSpeeds.P11_SlowV5828 = true
end

hook.Add("PlayerSpawn", "P11.Slow.v5828", function(ply)
    timer.Simple(0.20, function() ApplySlow(ply) end)
    timer.Simple(0.65, function() ApplySlow(ply) end)
end)

hook.Add("InitPostEntity", "P11.SlowWrap.v5828", function()
    timer.Simple(0.5, WrapMove)
    timer.Simple(3, WrapMove)
end)
timer.Simple(0.1, WrapMove)

cvars.AddChangeCallback("p11_speed", function()
    for _, p in ipairs(player.GetAll()) do ApplySlow(p) end
end, "P11.Slow.v5828")

print("[POLUS-11] v5.8.28: ХП профы при смене · шаг замедлен (p11_speed)")
