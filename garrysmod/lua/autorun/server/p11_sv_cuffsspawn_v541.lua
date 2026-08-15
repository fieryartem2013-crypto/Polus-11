-- ============================================================
--  ПОЛЮС-11 — НАРУЧНИКИ В Q-МЕНЮ (server) v5.4.1 (НОВЫЙ ФАЙЛ)
--  Владелец: «добавь наручники во вкладку оружие, категорию ПОЛЮС-11».
--  У свепа weapon_polus11_cuffs стояло SWEP.Spawnable = false —
--  поэтому наручников не было в Q-меню. Старый файл НЕ трогаем:
--  этот файл (autorun, грузится после гейммода) переопределяет
--  флаги свепа в рантайме → наручники появляются в Q → Оружие →
--  ПОЛЮС-11 (спавнить может админ; в руки игрокам выдаёт система).
-- ============================================================

-- дождаться, пока свепы зарегистрируются гейммодом, и включить спавн
hook.Add("InitPostEntity", "P11.CuffsSpawn541", function()
    timer.Simple(1, function()
        local stored = scripted_ents and scripted_ents.GetStored and scripted_ents.GetStored("weapon_polus11_cuffs")
        if stored and stored.t then
            stored.t.Spawnable = true
            stored.t.AdminSpawnable = true
            stored.t.Category = "ПОЛЮС-11"
            if P11FW and P11FW.Log then
                P11FW.Log("v5.4.1: наручники включены в Q-меню (Оружие → ПОЛЮС-11)")
            end
        else
            print("[POLUS-11] v5.4.1: свеп наручников не найден в scripted_ents (проверь entities/weapons/weapon_polus11_cuffs)")
        end
    end)
end)

print("[POLUS-11] v5.4.1 (server, autorun): наручники → Q-меню (Оружие → ПОЛЮС-11)")
