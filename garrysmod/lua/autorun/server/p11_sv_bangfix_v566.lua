-- ============================================================
--  ПОЛЮС-11 — ПЕРЕХВАТЧИК «!»-КОМАНД v5.6.6 (server, autorun)
--  Проблема: !дежурство / !опыт / !снятьдежурство уходили в OOC,
--  потому что их НЕТ в белом списке BANG_SERVER роутера (p11_sv_chat.lua).
--
--  НАДЁЖНОЕ РЕШЕНИЕ (не зависит от порядка/priority хуков):
--  оборачиваем САМ хук роутера "P11.ChatCore" (из hook.GetTable()):
--  перед вызовом роутера проверяем наши команды — если совпало,
--  выполняем и возвращаем "" (съедено, в OOC не уйдёт).
--  Старые файлы не трогаем.
-- ============================================================

local ok, err = pcall(function()

local function Handle(ply, text)
    if not IsValid(ply) or not isstring(text) then return nil end
    local low = string.lower(string.Trim(text))

    -- !дежурство
    if low == "!дежурство" then
        if POLUS11 and POLUS11.OpenDutyUI then
            POLUS11.OpenDutyUI(ply, ply.P11_DutyNpcEnt)
        end
        return ""
    end

    -- !снятьдежурство / !снятьпост
    if low == "!снятьдежурство" or low == "!снятьпост" then
        if POLUS11 and POLUS11.DutyEnd then
            POLUS11.DutyEnd(ply, false)
        end
        return ""
    end

    -- !опыт / !выдатьопыт / !выдатьxp
    if low == "!опыт" or low == "!выдатьопыт" or low == "!выдатьxp" then
        RunConsoleCommand("p11_xp")
        return ""
    end

    return nil -- не наша команда — пропускаем
end

-- оборачиваем роутер чата
local t = hook.GetTable()
local ps = t and t["PlayerSay"]
if ps and ps["P11.ChatCore"] then
    local orig = ps["P11.ChatCore"]
    ps["P11.ChatCore"] = function(ply, text)
        local eaten = Handle(ply, text)
        if eaten ~= nil then return eaten end
        return orig(ply, text)
    end
    print("[POLUS-11] ПЕРЕХВАТ !-КОМАНД v5.6.6: роутер обёрнут — !дежурство/!опыт/!снятьдежурство работают")
else
    print("[POLUS-11][!команды] роутер P11.ChatCore не найден — команды НЕ перехвачены")
end

end)
if not ok then
    print("[POLUS-11][!команды] ошибка: " .. tostring(err))
end
