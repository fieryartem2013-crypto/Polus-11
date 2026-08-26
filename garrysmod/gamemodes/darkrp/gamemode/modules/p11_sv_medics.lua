-- ============================================================
--  ПОЛЮС-11 — МЕД-РЕГЛАМЕНТ (server) v4.9.1 «ИГЛА»
--  Заявка владельца: «учёная фракция вся может брать шприцы
--  и пользоваться ими; шприц не хилит за медсестру — не работает».
--  ЖЕЛЕЗНЫЕ ПРАВИЛА ДЕРЖАТЕЛЯ ШПРИЦА (уровень движка):
--   ● держать и пользоваться может ВСЯ научная фракция
--     (POLUS11.IsScienceFaction: category «science») + администрация;
--   ● медсостав (медик/медсестра/глав.медсестра — POLUS11.IsMedic)
--     тоже носит шприц: ПКМ-обработка лечит (это и чинит «не хилит
--     за медсестру» — её должность раньше не считалась медиком);
--   ● аудит раз в 10 сек: шприц у посторонней должности — изымается;
--   ● при смене должности на постороннюю шприц сдаётся сразу.
-- ============================================================

local SYRINGE = "weapon_polus11_syringe"

local function CanHoldSyringe(ply)
    if not IsValid(ply) then return false end
    if P11FW.Config and P11FW.Config.Admin(ply) then return true end
    if POLUS11.IsScienceFaction and POLUS11.IsScienceFaction(ply) then return true end
    if POLUS11.IsMedic and POLUS11.IsMedic(ply) then return true end
    return false
end

-- не поднять с пола
hook.Add("PlayerCanPickupWeapon", "P11.SyringeOnlyScience", function(ply, wep)
    if not IsValid(wep) or wep:GetClass() ~= SYRINGE then return end
    if not CanHoldSyringe(ply) then
        if SERVER then
            P11FW.Notify(ply, "⚗️ Шприц — инструмент научной фракции и медсостава. Обратись к ним.")
        end
        return false
    end
end)

-- аудит: изъять у всех, кому не положен (попал через старые сейвы/выдачу)
timer.Create("P11.SyringeAudit", 10, 0, function()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:Alive() and p:HasWeapon(SYRINGE) and not CanHoldSyringe(p) then
            p:StripWeapon(SYRINGE)
            P11FW.Notify(p, "⚗️ Шприц изъят: он положен науке и медсоставу.")
        end
    end
end)

-- сменил должность на постороннюю — сразу сдал
hook.Add("P11FW.JobChanged", "P11.SyringeJobAudit", function(ply)
    if not IsValid(ply) then return end
    if CanHoldSyringe(ply) then return end
    if ply:HasWeapon(SYRINGE) then
        ply:StripWeapon(SYRINGE)
        P11FW.Notify(ply, "⚗️ Шприц сдан: на этой должности он не положен.")
    end
end)

print("[POLUS-11] мед-регламент v4.9.1 «ИГЛА»: шприц — ВСЯ научная фракция + медсостав (медсёстры лечат ПКМ); подбор прочими запрещён, аудит 10с")
