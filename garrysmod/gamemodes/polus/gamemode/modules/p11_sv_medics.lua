-- ============================================================
--  ПОЛЮС-11 — МЕД-РЕГЛАМЕНТ (server) v4.8.8 «ЛИЧИНА»
--  Заявка владельца: «Шприц — только учёному, остальным профам
--  шприц не доступен». На уровне лоадаутов уже убрано у всех,
--  кроме «Учёного» (сид + миграция syrV488). Здесь — ЖЕЛЕЗНАЯ
--  СТРАХОВКА на уровне движка:
--   ● поднять/взять шприц с пола/с рук может ТОЛЬКО должность
--     «seed_sci_ucheniy» (администрация — для организации опытов);
--   ● аудит раз в 10 сек: шприц в инвентаре у чужой должности —
--     изымается обратно в лабораторию;
--   ● при смене должности с «Учёного» шприц сдаётся сразу.
--  Медицинская помощь — через ванильный медкейс
--  (weapon_polus11_medkit): медик/медсёстры.
-- ============================================================

local SYRINGE = "weapon_polus11_syringe"
local OWNER   = "seed_sci_ucheniy"

local function CanHoldSyringe(ply)
    if not IsValid(ply) then return false end
    if P11FW.Config and P11FW.Config.Admin(ply) then return true end
    return (P11FW.GetJobId and P11FW.GetJobId(ply)) == OWNER
end

-- не поднять с пола
hook.Add("PlayerCanPickupWeapon", "P11.SyringeOnlyScience", function(ply, wep)
    if not IsValid(wep) or wep:GetClass() ~= SYRINGE then return end
    if not CanHoldSyringe(ply) then
        if SERVER then
            P11FW.Notify(ply, "⚗️ Шприц теста крови — только должности «Учёный» (Наука). Обратись к ним.")
        end
        return false
    end
end)

-- аудит: изъять у всех, кому не положен (попал через старые сейвы/выдачу)
timer.Create("P11.SyringeAudit", 10, 0, function()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p:HasWeapon(SYRINGE) and not CanHoldSyringe(p) then
            p:StripWeapon(SYRINGE)
            P11FW.Notify(p, "⚗️ Шприц изъят: тест крови проводит только «Учёный» (Наука).")
        end
    end
end)

-- сменил должность — сразу сдал
hook.Add("P11FW.JobChanged", "P11.SyringeJobAudit", function(ply, jobId)
    if jobId == OWNER then return end
    if IsValid(ply) and ply:HasWeapon(SYRINGE) and not (P11FW.Config and P11FW.Config.Admin(ply)) then
        ply:StripWeapon(SYRINGE)
        P11FW.Notify(ply, "⚗️ Шприц сдан: он положен только «Учёному».")
    end
end)

print("[POLUS-11] мед-регламент v4.8.8 «ЛИЧИНА»: шприц теста крови — ТОЛЬКО «Учёному» (подбор запрещён, аудит 10с); медикам — ванильный медкейс")
