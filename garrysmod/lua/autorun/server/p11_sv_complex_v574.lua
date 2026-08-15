-- ============================================================
--  ПОЛЮС-11 — СОСТОЯНИЕ КОМПЛЕКСА (server) v5.7.4 (НОВЫЙ ФАЙЛ)
--  Владелец: «добавь состояние комплекса» со статусами:
--    Всё нормально / Атака / Выход НКВД / Собрание / Конец комплекса
--
--  Реализация:
--   • глобальная P11_ComplexState (string) — видна всем клиентам;
--   • команды админа (консоль сервера): p11_complex <номер 1..5>
--     или по названию (p11_complex атака);
--   • чат (админ): !состояние <номер/название> — быстрый выбор;
--   • чат (все): !состояние — показать текущее.
--  Старые файлы не трогаем.
-- ============================================================

local ok, err = pcall(function()

POLUS11.ComplexStates = POLUS11.ComplexStates or {
    { id = "ok",       name = "Всё нормально" },
    { id = "attack",   name = "Атака" },
    { id = "nkvd",     name = "Выход НКВД" },
    { id = "meeting",  name = "Собрание" },
    { id = "finale",   name = "Конец комплекса" },
}

function POLUS11.GetComplexState()
    return GetGlobalString("P11_ComplexState", POLUS11.ComplexStates[1].name)
end

function POLUS11.SetComplexState(idx)
    idx = tonumber(idx) or 1
    local st = POLUS11.ComplexStates[idx] or POLUS11.ComplexStates[1]
    SetGlobalString("P11_ComplexState", st.name)
    -- анонс всей станции
    net.Start("P11_Announce")
        net.WriteString("СОСТОЯНИЕ КОМПЛЕКСА: «" .. st.name .. "»")
        net.WriteString("КОМПЛЕКС")
    net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[КОМПЛЕКС] Состояние: «" .. st.name .. "».")
    if POLUS11.Log then POLUS11.Log("СОСТОЯНИЕ КОМПЛЕКСА: «" .. st.name .. "»") end
end

-- поиск состояния по имени/номеру
local function FindState(arg)
    arg = string.lower(string.Trim(tostring(arg or "")))
    if arg == "" then return nil end
    local num = tonumber(arg)
    if num then return POLUS11.ComplexStates[num] end
    for _, st in ipairs(POLUS11.ComplexStates) do
        if string.lower(st.name):find(arg, 1, true) or string.lower(st.id):find(arg, 1, true) then
            return st
        end
    end
    return nil
end

local function IsAdmin(ply)
    return IsValid(ply) and P11FW and P11FW.Config and P11FW.Config.Admin
        and P11FW.Config.Admin(ply)
end

-- консоль сервера: p11_complex <номер|название>
concommand.Add("p11_complex", function(ply, _, args)
    if IsValid(ply) and not IsAdmin(ply) then return end
    local st = FindState(args and args[1])
    if not st then
        local msg = "p11_complex <1..5> — Всё нормально / Атака / Выход НКВД / Собрание / Конец комплекса"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print("[P11] " .. msg) end
        return
    end
    local idx = nil
    for i, s in ipairs(POLUS11.ComplexStates) do if s.id == st.id then idx = i break end end
    POLUS11.SetComplexState(idx or 1)
end)

-- чат: !состояние [номер|название]
do
    local t = hook.GetTable()
    local ps = t and t["PlayerSay"]
    if ps and ps["P11.ChatCore"] then
        local orig = ps["P11.ChatCore"]
        ps["P11.ChatCore"] = function(ply, text)
            if IsValid(ply) and isstring(text) then
                local low = string.lower(string.Trim(text))
                if low == "!состояние" or string.StartWith(low, "!состояние ") then
                    local arg = string.Trim(string.sub(text, 12))
                    if arg == "" then
                        -- показать текущее
                        local cur = POLUS11.GetComplexState()
                        if POLUS11.Notify then POLUS11.Notify(ply, "Состояние комплекса: «" .. cur .. "»") end
                        return ""
                    end
                    if not IsAdmin(ply) then
                        if POLUS11.Notify then POLUS11.Notify(ply, "Менять состояние — только администрации.") end
                        return ""
                    end
                    local st = FindState(arg)
                    if not st then
                        if POLUS11.Notify then POLUS11.Notify(ply, "Нет такого состояния. Варианты: 1..5 / нормально / атака / нквд / собрание / конец") end
                        return ""
                    end
                    local idx = nil
                    for i, s in ipairs(POLUS11.ComplexStates) do if s.id == st.id then idx = i break end end
                    POLUS11.SetComplexState(idx or 1)
                    return ""
                end
            end
            return orig(ply, text)
        end
    end
end

end)
if not ok then
    print("[POLUS-11][СОСТОЯНИЕ] ошибка: " .. tostring(err))
end

print("[POLUS-11] СОСТОЯНИЕ КОМПЛЕКСА v5.7.4 (server): !состояние / p11_complex — 5 статусов")
