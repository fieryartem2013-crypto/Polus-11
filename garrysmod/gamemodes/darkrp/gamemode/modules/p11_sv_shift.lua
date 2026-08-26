-- ============================================================
--  ПОЛЮС-11 — РАСПОРЯДОК СМЕНЫ + АВТО-БУРЯ (server) v2.9
--  • Часы смены: метки распорядка (подъём/обход/обед/отбой…)
--    ротируются по таймеру, показываются в HUD и TAB, по смене —
--    гудок по станции. НЕ трогают сюжетную P11_Phase (она у пульта).
--  • Авто-МЕТЕЛЬ: каждые 20-30 мин — метеосводка, потом буря
--    на 6-9 мин (пользуется POLUS11.SetStorm из модуля энергии —
--    рации глушит, на клиенте метельный визуал и ветер).
--  Управление: p11_shift <номер> — поставить метку вручную;
--  p11_storm / !буря — буря вкл/выкл (админ).
-- ============================================================

-- ============ РАСПОРЯДОК ============

POLUS11.ShiftMarks = {
    "ПОДЪЁМ · 06:00",
    "ЗАРЯДКА И ЗАВТРАК · 07:00",
    "УТРЕННИЙ ОБХОД · 08:00",
    "РАЗВОД НА РАБОТЫ · 09:00",
    "ОБЕД · 13:00",
    "ПОЛДНИК · 16:00",
    "УЖИН · 19:00",
    "ВЕЧЕРНЯЯ ПЕРЕКЛИЧКА · 21:00",
    "ОТБОЙ · 23:00",
    "НОЧНОЙ ДОЗОР · 02:00",
}

POLUS11.ShiftIdx = POLUS11.ShiftIdx or 1

function POLUS11.SetShiftMark(idx)
    idx = ((idx - 1) % #POLUS11.ShiftMarks) + 1
    POLUS11.ShiftIdx = idx
    local label = POLUS11.ShiftMarks[idx]
    SetGlobalString("P11_Shift", label)
    PrintMessage(HUD_PRINTTALK, "[ГРОМКОГОВОРИТЕЛЬ] Распорядок: " .. label)
    for _, ply in ipairs(player.GetAll()) do
        ply:EmitSound("buttons/lever3.wav", 62, 90)
    end
    POLUS11.Log("Распорядок: " .. label)
end

local SHIFT_EVERY = 210 -- секунд между метками

hook.Add("InitPostEntity", "P11.ShiftStart", function()
    timer.Simple(20, function()
        POLUS11.SetShiftMark(POLUS11.ShiftIdx)
    end)
end)

timer.Create("P11.ShiftTick", SHIFT_EVERY, 0, function()
    POLUS11.SetShiftMark((POLUS11.ShiftIdx or 1) + 1)
end)

concommand.Add("p11_shift", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    POLUS11.SetShiftMark(tonumber(args[1]) or (POLUS11.ShiftIdx or 1) + 1)
end)

-- ============ АВТО-БУРЯ ============
-- v4.6.3: МАГНИТНАЯ БУРЯ УБРАНА по прямой заявке владельца.
-- Вернуть можно одной строкой: AUTOSTORM = true (и ручная !буря оживёт).
local AUTOSTORM = false

local NextWarnAt  = CurTime() + math.Rand(20 * 60, 30 * 60)
local NextStormAt = nil

timer.Create("P11.AutoStorm", 30, 0, function()
    if not AUTOSTORM then return end -- v4.6.3: бури нет
    local now = CurTime()

    -- метеосводка
    if not NextStormAt and now >= NextWarnAt then
        NextStormAt = now + 80 -- буря через ~1.5 мин после сводки
        NextWarnAt  = nil
        PrintMessage(HUD_PRINTTALK, "[ГРОМКОГОВОРИТЕЛЬ] Метеосводка: на станцию надвигается МАГНИТНАЯ БУРЯ. Рации могут замолчать.")
        for _, ply in ipairs(player.GetAll()) do
            ply:EmitSound("ambient/alarms/warningbell1.wav", 58, 82)
        end
        POLUS11.Log("АВТО-БУРЯ: метеосводка передана.")
        return
    end

    -- старт бури
    if NextStormAt and now >= NextStormAt then
        NextStormAt = nil
        NextWarnAt  = CurTime() + math.Rand(20 * 60, 30 * 60) -- следующая не раньше
        if POLUS11.SetStorm then
            POLUS11.SetStorm(true, math.Rand(360, 540)) -- 6-9 минут
            POLUS11.Log("АВТО-БУРЯ: метель накрыла станцию.")
        end
    end
end)

-- админский ручной запуск: p11_storm / !буря
local function AdminStormToggle(ply)
    if not AUTOSTORM then
        if IsValid(ply) then P11FW.Notify(ply, "Магнитная буря УБРАНА в сборке v4.6.3 (включить: AUTOSTORM=true в p11_sv_shift.lua).") end
        return
    end
    if not POLUS11.SetStorm then
        if IsValid(ply) then P11FW.Notify(ply, "Модуль энергии не загружен.") end
        return
    end
    local on = not GetGlobalBool("P11_Storm", false)
    POLUS11.SetStorm(on, on and math.Rand(360, 540) or nil)
    if IsValid(ply) then
        P11FW.Notify(ply, on and "Буря запущена (авто-конец через 6-9 мин)." or "Буря остановлена.")
    end
end

concommand.Add("p11_storm", function(ply)
    if IsValid(ply) and not P11FW.Config.Admin(ply) then return end
    AdminStormToggle(ply)
end)

hook.Add("PlayerSay", "P11.StormChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t ~= "!буря" and t ~= "!storm" then return end
    if not P11FW.Config.Admin(ply) then
        ply:ChatPrint("[ПОЛЮС-11] Бурю управляет только администрация.")
        return ""
    end
    AdminStormToggle(ply)
    return ""
end)
