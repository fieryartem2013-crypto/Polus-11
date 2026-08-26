-- ============================================================
--  ПОЛЮС-11 — ОКЛАД СЛУЖБЫ (server) v4.6.9
--  Каждые Config.WageEvery секунд (по умолчанию 7 минут) живой
--  боец НА ДОЛЖНОСТИ получает оклад казначейства: WageBase ₽,
--  терминальным (руководящим) должностям — +WageTerminalBonus ₽.
--  Закрывает экономическую петлю: заработал → потратил в
--  ларьке / поменялся с соседом → снова в службу. Тюнинг чисел —
--  в p11_sh_config.lua (блок v4.6.9). Движок выплат —
--  POLUS11.AddMoney (кошелёк + золотое оповещение в чат).
-- ============================================================

local function WageTick()
    local cfg    = POLUS11.Config or {}
    local base   = cfg.WageBase or 150
    local tbonus = cfg.WageTerminalBonus or 80

    local paid = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            local jobId = P11FW.GetJobId and P11FW.GetJobId(ply)
            local job = jobId and P11FW.Jobs and P11FW.Jobs[jobId]
            if job then
                local sum = base + ((job.terminal == true) and tbonus or 0)
                POLUS11.AddMoney(ply, sum,
                    "оклад службы (" .. job.name .. ") — зачислено казначейством")
                paid = paid + 1
            end
        end
    end
    if paid > 0 and P11FW and P11FW.Log then
        P11FW.Log("ОКЛАД: начислено " .. paid .. " служащим")
    end
end

timer.Create("P11.Wage", (POLUS11.Config and POLUS11.Config.WageEvery) or 420, 0, WageTick)

print("[POLUS-11] оклад v4.6.9: казначейство платит каждые "
    .. string.format("%.0f", ((POLUS11.Config and POLUS11.Config.WageEvery) or 420) / 60)
    .. " мин (база " .. tostring((POLUS11.Config and POLUS11.Config.WageBase) or 150) .. "₽)")
