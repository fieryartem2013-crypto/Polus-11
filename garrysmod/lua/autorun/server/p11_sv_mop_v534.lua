-- ============================================================
--  ПОЛЮС-11 — ШВАБРА: ВЫДАЧА + МИНИИГРА (server) v5.3.4 (НОВЫЙ ФАЙЛ)
--  Свеп weapon_polus11_mop живёт в entities/weapons — регистрируется
--  сам. ЭТОТ файл:
--    1) выдаёт швабру УБОРЩИКУ при спавне (janitor);
--    2) POLUS11.MopClean(ply, dirt) — миниигра «УБОРКА ШВАБРОЙ»:
--       успех → грязь убрана + деньги (CleanPay ×2) + жетон (если
--       система жетонов активна — но ярмарка вырезана, поэтому
--       деньги и TaskEvent clean, который сам даёт жетон в v5.3.0).
--  Старые файлы не трогаем.
-- ============================================================

-- 1) выдача швабры уборщику при спавне
hook.Add("PlayerSpawn", "P11.MopGive", function(ply)
    if not IsValid(ply) then return end
    if P11FW and P11FW.GetJobId and P11FW.GetJobId(ply) == "janitor" then
        timer.Simple(0.4, function()
            if IsValid(ply) and ply:Alive() then
                ply:Give("weapon_polus11_mop")
            end
        end)
    end
end)

-- 2) миниигра уборки шваброй
function POLUS11.MopClean(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 160 * 160 then return end
    if POLUS11.MiniSessions and POLUS11.MiniSessions[ply] then return end

    POLUS11.MiniStart(ply, ent, {
        steps = 5,
        window = 1.3,
        title = "УБОРКА ШВАБРОЙ",
        cb = function(p, ent2, ok)
            if not IsValid(ent2) then return end
            if ok then
                ent2:EmitSound("ambient/levels/canals/toxic_slime_gurgle1.wav", 55, 130)
                ent2:Remove()
                -- деньги (удвоенный тариф уборки)
                local pay = (POLUS11.Config and POLUS11.Config.CleanPay) or 35
                if POLUS11.AddMoney then
                    POLUS11.AddMoney(p, pay * 2, "уборка шваброй")
                end
                -- событие clean → жетоны (v5.3.0) + задачи
                if POLUS11.TaskEvent then POLUS11.TaskEvent(p, "clean") end
                if POLUS11.Notify then
                    POLUS11.Notify(p, "Прибрано шваброй. Станция чище (+" .. (pay * 2) .. "₽).")
                end
            else
                if POLUS11.Notify then
                    POLUS11.Notify(p, "Размазал по полу. Попробуй аккуратнее.")
                end
            end
        end,
    })
end

print("[POLUS-11] ШВАБРА v5.3.4 (server, autorun): уборщику при спавне, миниигра, +деньги и жетон")
