-- ============================================================
--  ПОЛЮС-11 — ЗАПАСНОЙ ВХОД В ДЕЖУРСТВА v5.6.1 (server, autorun)
--  Владелец: «дежурство не открывается». НЕ дублируем net-каналы
--  (дубли ломали!). Просто даём запасной вход:
--    • консоль: p11_duty
--    • чат: !дежурство
--  Оба вызывают УЖЕ существующую POLUS11.OpenDutyUI (из v525) —
--  меню откроется даже если НПС не стоит на карте.
-- ============================================================

local ok, err = pcall(function()
    if not POLUS11.OpenDutyUI then
        print("[POLUS-11][ДЕЖУРСТВА] OpenDutyUI не найдена — модуль не загружен!")
        return
    end

    -- консоль: p11_duty — открыть меню (можно и без НПС)
    concommand.Add("p11_duty", function(ply)
        if IsValid(ply) then
            POLUS11.OpenDutyUI(ply, ply.P11_DutyNpcEnt)
        end
    end)

    -- чат: !дежурство (оборачиваем роутер, чтобы съелась до OOC)
    local t = hook.GetTable()
    local ps = t and t["PlayerSay"]
    if ps and ps["P11.ChatCore"] then
        local orig = ps["P11.ChatCore"]
        ps["P11.ChatCore"] = function(ply, text)
            if IsValid(ply) and text then
                local low = string.lower(string.Trim(text))
                if low == "!дежурство" then
                    POLUS11.OpenDutyUI(ply, ply.P11_DutyNpcEnt)
                    return ""
                end
            end
            return orig(ply, text)
        end
    end
end)
if not ok then
    print("[POLUS-11][ДЕЖУРСТВА] запасной вход: ошибка " .. tostring(err))
end

print("[POLUS-11] ЗАПАСНОЙ ВХОД ДЕЖУРСТВ v5.6.1: !дежурство / p11_duty")
