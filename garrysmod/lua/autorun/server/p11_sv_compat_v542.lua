-- ============================================================
--  ПОЛЮС-11 — СОВМЕСТИМОСТЬ ПОСЛЕ ВЫРЕЗКИ ЯРМАРКИ (server) v5.4.2
--  Владелец: «ярмарку вырежи ПОЛНОСТЬЮ, а не выключай».
--  Все файлы ярмарки удалены. Этот файл (НОВЫЙ) делает две вещи:
--    1) заглушки EV-функций (EVGiveAll/EVAdd/EVSync/EVTake/EVGet) —
--       их вызывают ПРОИСШЕСТВИЯ (p11_sv_events_v525) для награды;
--       без заглушки происшествия упадут с nil. Теперь они просто
--       ничего не начисляют (жетонов больше нет).
--    2) «Солдат Вермахта» остаётся VIP-профой (правка перенесена
--       из удалённого cutfair_v533).
--  Старые файлы не трогаем.
-- ============================================================

-- 1) заглушки EV (жетонов больше нет — но вызовы из происшествий живы)
POLUS11.EVGiveAll  = function() end
POLUS11.EVAdd      = function() end
POLUS11.EVSync     = function() end
POLUS11.EVTake     = function() return false end
POLUS11.EVGet      = function() return 0 end
POLUS11.OpenEVShopUI = function() end

-- 2) Солдат Вермахта → VIP-профа (двойной проход после сида)
local function VipVermacht()
    if not (P11FW and P11FW.CustomJobs and P11FW.Jobs) then return end
    local changed = false
    for _, rec in ipairs(P11FW.CustomJobs) do
        if rec and rec.id == "seed_oso_vermacht" then
            rec.vip = true; rec.hidden = nil; rec.cmdonly = nil; rec.bpUnlock = nil
            changed = true
        end
    end
    local job = P11FW.Jobs["seed_oso_vermacht"]
    if job then
        job.vip = true; job.hidden = nil; job.cmdonly = nil; job.bpUnlock = nil
        changed = true
    end
    if changed and P11FW.RegisterCustomJobs then
        P11FW.RegisterCustomJobs(P11FW.CustomJobs)
        if P11FW.SyncCustomJobs then P11FW.SyncCustomJobs(nil) end
    end
end

hook.Add("InitPostEntity", "P11.VipVermacht542", function()
    timer.Simple(4, VipVermacht)
    timer.Simple(8, VipVermacht)
end)

print("[POLUS-11] v5.4.2 (server, autorun): ярмарка ВЫРЕЗАНА полностью · заглушки EV · Вермахт = VIP")
