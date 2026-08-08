-- ============================================================
--  ПОЛЮС-11 — «РЕПРОДУКТОР»: ОПОВЕЩЕНИЕ СТАНЦИИ (server)
--  v4.18.0 (заявка владельца: «добавь систему оповещений админов —
--  появляется плашка у всех наверху и там пишется текст, который
--  напишешь, и отдельную для этого вкладку»).
--  ДВЕ ДВЕРИ в одну трубу:
--   • вкладка F4 → АДМИН → «ОПОВЕЩЕНИЕ» (ранг 4+, net P11_Announce);
--   • консоль p11_announce <текст> (гейт Admin внутри; снаружи
--     стоит замок Главы 16 на все p11_* — как у прочих команд).
--  Плашка рисуется клиентом (p11_cl_alerts.lua): наверху экрана,
--  14 сек + дубль в чат; анти-спам 8 сек на админа; журнал станции.
-- ============================================================

util.AddNetworkString("P11_Announce")

local MAX_LEN = 220

local function Broadcast(txt, by)
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString(by)
    net.Broadcast()
end

net.Receive("P11_Announce", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not (P11FW and P11FW.Config and P11FW.Config.Admin(ply)) then
        if POLUS11 and POLUS11.Notify then
            POLUS11.Notify(ply, "Оповещения станции — с ранга Administrator (4+).")
        end
        return
    end

    ply.P11_AnnNext = ply.P11_AnnNext or 0
    if CurTime() < ply.P11_AnnNext then
        if POLUS11 and POLUS11.Notify then
            POLUS11.Notify(ply, "Репродуктор ещё звучит — следующее оповещение через " ..
                math.ceil(ply.P11_AnnNext - CurTime()) .. " сек.")
        end
        return
    end

    local txt = tostring(net.ReadString() or "")
    txt = string.gsub(txt, "[%c]+", " ")   -- переносы/контроль — пробелом
    txt = string.gsub(txt, "%s%s+", " ")
    txt = string.Trim(txt)
    txt = string.sub(txt, 1, MAX_LEN)
    if txt == "" then return end

    ply.P11_AnnNext = CurTime() + 8
    Broadcast(txt, ply:Nick())

    if POLUS11 and POLUS11.Log then
        POLUS11.Log("ОПОВЕЩЕНИЕ от " .. ply:Nick() .. ": " .. txt)
    end
    print("[РЕПРОДУКТОР] " .. ply:Nick() .. ": " .. txt)
end)

-- консольный канал (снаружи — замок cmdlock ранга 16, внутри — Admin 4+)
concommand.Add("p11_announce", function(ply, cmd, args)
    if IsValid(ply) and not (P11FW and P11FW.Config and P11FW.Config.Admin(ply)) then
        if POLUS11 and POLUS11.Notify then
            POLUS11.Notify(ply, "Оповещения станции — с ранга Administrator (4+).")
        end
        return
    end
    local txt = string.Trim(table.concat(args or {}, " "))
    txt = string.sub(txt, 1, MAX_LEN)
    if txt == "" then
        local msg = "p11_announce <текст> — оповещение всей станции (плашка у всех наверху)"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    local by = IsValid(ply) and ply:Nick() or "СЕРВЕР"
    Broadcast(txt, by)
    if POLUS11 and POLUS11.Log then
        POLUS11.Log("ОПОВЕЩЕНИЕ от " .. by .. ": " .. txt)
    end
    print("[РЕПРОДУКТОР] " .. by .. ": " .. txt)
end)

print("[POLUS-11] оповещения «РЕПРОДУКТОР» v4.18.0: плашка у всех наверху · вкладка F4→АДМИН «ОПОВЕЩЕНИЕ» (ранг 4+) · консоль p11_announce")
