-- ============================================================
--  ПОЛЮС-11 — КОМАНДНЫЕ СРЕДСТВА (server) v2.9
--  • ПРИКАЗ командира (!приказ <текст>) — золотой баннер на
--    все экраны; засчитывает задачу офицера «построение».
--  • РОЗЫСК (!розыск <ник> [причина]) — человек под подозрением:
--    метка в TAB, над головой, у него самого красная плашка.
--  • РЕПОРТ (!репорт <текст>) — любой игрок пишет админам,
--    падает в чат админам + в файл data/polus11/reports.txt.
--  • !ролл — кубик 1-100 для спорных моментов.
--  Приказы/розыск: должность с флагом command (v3.9: Генерал/Особист) или админ.
-- ============================================================

util.AddNetworkString("P11_Order")

-- ============ КТО КОМАНДИР ============

function POLUS11.CanOrder(ply)
    if not IsValid(ply) then return false end
    if P11FW.Config.Admin(ply) then return true end
    local job = P11FW.GetJob and P11FW.GetJob(ply)
    return job and job.command == true
end

local function FindPly(part)
    if not part or part == "" then return nil end
    local byId = player.GetByID(tonumber(part) or -1)
    if IsValid(byId) then return byId end
    local low = string.lower(part)
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), low, 1, true) then return p end
    end
    return nil
end

-- ============ ПРИКАЗ ============

function POLUS11.SendOrder(ply, text)
    if not POLUS11.CanOrder(ply) then
        return false, "приказы отдаёт командный состав (Генерал, Особист) и администрация"
    end
    text = string.Trim(tostring(text or ""))
    if text == "" then return false, "пустой приказ" end
    ply.P11_OrderCd = ply.P11_OrderCd or 0
    if CurTime() < ply.P11_OrderCd then
        return false, "следующий приказ через " .. math.ceil(ply.P11_OrderCd - CurTime()) .. " сек"
    end
    ply.P11_OrderCd = CurTime() + 45
    text = string.sub(text, 1, 120)

    local jobName = P11FW.GetJobName and P11FW.GetJobName(ply) or "командование"
    net.Start("P11_Order")
        net.WriteString(text)
        net.WriteString(ply:Nick())
        net.WriteString(jobName)
    net.Broadcast()

    PrintMessage(HUD_PRINTTALK, "[ПРИКАЗ] " .. text .. "  —  " .. ply:Nick() .. " (" .. jobName .. ")")
    POLUS11.Log("ПРИКАЗ от " .. ply:Nick() .. ": " .. text)
    if P11FW.ModLog then P11FW.ModLog("order", ply, "СТАНЦИЯ", text) end
    if POLUS11.TaskEvent then POLUS11.TaskEvent(ply, "rollcall") end -- задача офицера «построение»
    return true
end

-- ============ РОЗЫСК ============

function POLUS11.ToggleWanted(ply, namePart, reason)
    if not POLUS11.CanOrder(ply) then
        return false, "розыск объявляет командный состав (Генерал, Особист) и администрация"
    end
    if not namePart or namePart == "" then
        return false, "использование: !розыск <ник> [причина] (повтор — снять)"
    end
    local t = FindPly(namePart)
    if not IsValid(t) then return false, "игрок не найден: " .. tostring(namePart) end
    if t == ply then return false, "самого себя в розыск подавать нельзя" end

    -- снятие, если уже в розыске
    if t:GetNWString("P11_Wanted", "") ~= "" then
        t:SetNWString("P11_Wanted", "")
        t:SetNWString("P11_WantedBy", "")
        PrintMessage(HUD_PRINTTALK, "[РОЗЫСК] " .. t:Nick() .. " СНЯТ с розыска.")
        POLUS11.Log("РОЗЫСК СНЯТ: " .. t:Nick() .. " (снял " .. ply:Nick() .. ")")
        if P11FW.ModLog then P11FW.ModLog("unwanted", ply, t, nil) end
        return true, "снят с розыска: " .. t:Nick()
    end

    reason = string.Trim(tostring(reason or ""))
    if reason == "" then reason = "подозрение на нарушение порядка" end
    reason = string.sub(reason, 1, 90)

    t:SetNWString("P11_Wanted", reason)
    t:SetNWString("P11_WantedBy", ply:Nick())
    t:EmitSound("ambient/alarms/warningbell1.wav", 70, 108)
    PrintMessage(HUD_PRINTTALK, "[РОЗЫСК] " .. t:Nick() .. " объявлен в РОЗЫСК: " .. reason)
    POLUS11.Log("РОЗЫСК: " .. t:Nick() .. " — " .. reason .. " (объявил " .. ply:Nick() .. ")")
    if P11FW.ModLog then P11FW.ModLog("wanted", ply, t, reason) end
    return true, "объявлен в розыске: " .. t:Nick()
end

-- ============ РЕПОРТ (игрок → админам) ============

local function ReportsDir()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
end

function POLUS11.SendReport(ply, text)
    text = string.Trim(tostring(text or ""))
    if text == "" then return false, "пустой репорт" end
    ply.P11_ReportCd = ply.P11_ReportCd or 0
    if CurTime() < ply.P11_ReportCd then
        return false, "следующий репорт через " .. math.ceil(ply.P11_ReportCd - CurTime()) .. " сек"
    end
    ply.P11_ReportCd = CurTime() + 60
    text = string.sub(text, 1, 220)

    local line = os.date("[%d.%m %H:%M:%S] ") .. ply:Nick() .. " [" .. ply:SteamID() .. "]: " .. text
    ReportsDir()
    file.Append("polus11/reports.txt", line .. "\n")

    -- v4.8.2 «ДОКЛАД»: жалоба становится ТИКЕТОМ окна /репорты —
    -- админы принимают её кнопкой, телепортируются и закрывают.
    if POLUS11.RepAdd then
        local ok, r = POLUS11.RepAdd(ply, text)
        if ok then
            local adm = 0
            for _, a in ipairs(player.GetAll()) do
                if P11FW.Config.Admin(a) then adm = adm + 1 end
            end
            return true, "репорт #" .. r.id .. " отправлен — админы берут его в окне /репорты"
                .. (adm > 0 and (" (" .. adm .. " адм. онлайн)") or " (админов нет онлайн — записан)")
        end
    end

    -- запасная дорога (модуля тикетов нет): прямой пинг, как было
    local got = 0
    for _, a in ipairs(player.GetAll()) do
        if P11FW.Config.Admin(a) then
            a:ChatPrint("[РЕПОРТ] " .. ply:Nick() .. ": " .. text)
            got = got + 1
        end
    end
    if got == 0 then
        P11FW.Log("РЕПОРТ (админов нет онлайн): " .. ply:Nick() .. ": " .. text)
    end
    return true, "репорт отправлен" .. (got > 0 and (" (" .. got .. " адм.)") or " (админов нет онлайн — записан в лог)")
end

-- ============ ЧАТ-КОМАНДЫ ============

hook.Add("PlayerSay", "P11.Command", function(ply, text)
    local args = string.Explode("%s+", string.Trim(text), true)
    local cmd = string.lower(args[1] or "")
    local rest = string.sub(string.Trim(text), #cmd + 2)

    if cmd == "!приказ" or cmd == "/приказ" or cmd == "!order" then
        local ok, err = POLUS11.SendOrder(ply, rest)
        if not ok then ply:ChatPrint("[ПОЛЮС-11] " .. tostring(err)) end
        return ""
    end

    -- v4.8.2: алиасы через слэш — игроки привыкли к /-командам
    if cmd == "!розыск" or cmd == "!wanted" or cmd == "/розыск" or cmd == "/wanted" then
        local who = args[2]
        local reason = string.Trim(string.sub(rest, #(who or "") + 2))
        local ok, err = POLUS11.ToggleWanted(ply, who, reason)
        if ply:IsPlayer() then ply:ChatPrint("[ПОЛЮС-11] " .. tostring(ok and err or err)) end
        return ""
    end

    if cmd == "!репорт" or cmd == "!report" then
        local ok, err = POLUS11.SendReport(ply, rest)
        ply:ChatPrint("[ПОЛЮС-11] " .. tostring(ok and ("Репорт принят: " .. err) or err))
        return ""
    end

    if cmd == "!ролл" or cmd == "!roll" then
        local n = math.random(1, 100)
        PrintMessage(HUD_PRINTTALK, "[КУБИК] " .. ply:Nick() .. " выбросил: " .. n .. " (1-100)")
        return ""
    end
end)

-- ============ КОНСОЛЬНЫЕ КОМАНДЫ (паритет) ============

concommand.Add("p11_order", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local ok, err = POLUS11.SendOrder(ply, table.concat(args, " "))
    if not ok then ply:ChatPrint("[ПОЛЮС-11] " .. tostring(err)) end
end)

concommand.Add("p11_wanted", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local ok, err = POLUS11.ToggleWanted(ply, args[1], table.concat(args, " ", 2))
    ply:ChatPrint("[ПОЛЮС-11] " .. tostring(ok and err or err))
end)

concommand.Add("p11_report", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local ok, err = POLUS11.SendReport(ply, table.concat(args, " "))
    ply:ChatPrint("[ПОЛЮС-11] " .. tostring(ok and ("Репорт принят: " .. err) or err))
end)
