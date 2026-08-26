-- ============================================================
--  ПОЛЮС-11 — общая логика (shared)
-- ============================================================

POLUS11 = POLUS11 or {}

-- ============ СОСТОЯНИЕ (через NW для клиента) ============

function POLUS11.IsInfected(ply)
    if not IsValid(ply) then return false end
    return ply:GetNWBool("P11_Infected", false)
end

function POLUS11.InfectionActive(ply)
    if not IsValid(ply) then return false end
    return ply:GetNWBool("P11_InfActive", false)
end

function POLUS11.IsBlackout()
    return GetGlobalBool("P11_Blackout", false)
end

function POLUS11.IsStorm()
    return GetGlobalBool("P11_Storm", false)
end

function POLUS11.GetPhase()
    return GetGlobalString("P11_Phase", POLUS11.Config.Phases[1])
end

-- ============ ПРОФЕССИИ ============

function POLUS11.GetTeamName(ply)
    -- приоритет: наш фреймворк профессий
    if P11FW and P11FW.GetJobName then
        local n = P11FW.GetJobName(ply)
        if n and n ~= "" then return n end
    end
    if DarkRP and ply.getJobTable and ply:getJobTable() then
        return ply:getJobTable().name or ""
    end
    return team.GetName(ply:Team()) or ""
end

function POLUS11.IsScientist(ply)
    if not POLUS11.Config.RestrictJobs then return true end
    if not P11FW and not DarkRP then return true end -- нет системы профессий — не мешаем
    local n = POLUS11.GetTeamName(ply)
    for _, t in ipairs(POLUS11.Config.ScientistTeams) do
        if t == n then return true end
    end
    return false
end

function POLUS11.IsEngineer(ply)
    if not POLUS11.Config.RestrictJobs then return true end
    if not P11FW and not DarkRP then return true end
    local n = POLUS11.GetTeamName(ply)
    for _, t in ipairs(POLUS11.Config.EngineerTeams) do
        if t == n then return true end
    end
    return false
end

-- ============ v4.9.1 «ИГЛА»: ДОЛЖНОСТНЫЕ РОЛИ ============

--- Вся НАУЧНАЯ фракция (category «science» любой должности).
--- Учёный/лаборант/био-химик/ведущий/менеджер/создатель — все «свои» в лабе.
function POLUS11.IsScienceFaction(ply)
    if not IsValid(ply) then return false end
    if P11FW and P11FW.GetJob then
        local j = P11FW.GetJob(ply) -- таблица должности P11FW.Jobs[jobId]
        if j and j.category == "science" then return true end
    end
    return POLUS11.IsScientist(ply) -- старый путь по имени состава (не мешает)
end

--- Медсостав: медик (базовая), медсестра и главная медсестра РККА.
local MEDIC_JOBS = {
    medic = true,
    seed_rkka_medsestra = true,
    seed_rkka_medglav = true,
}

function POLUS11.IsMedic(ply)
    if not IsValid(ply) then return false end
    if P11FW and P11FW.GetJobId then
        if MEDIC_JOBS[P11FW.GetJobId(ply) or ""] then return true end
    end
    return false
end

-- ============ МОДЕЛИ ДЛЯ НЕЧТО ============
-- Модель «жуткой» формы при трансформации (по классам)

POLUS11.MonsterModels = {
    spider = "models/zombie/fast_torso.mdl",
    brute  = "models/zombie/poison.mdl",
    spore  = "models/zombie/classic.mdl",
}
