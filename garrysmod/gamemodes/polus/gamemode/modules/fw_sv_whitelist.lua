-- ============================================================
--  ПОЛЮС FRAMEWORK — ВАЙТЛИСТ ДОЛЖНОСТЕЙ (server) v4.4.0
--  Файл: data/polus_framework/whitelist.json (переживает рестарт).
--  Выдача/снятие: вкладка ВАЙТЛИСТ в /menu (администрация и
--  ранги Faction Officer / Faction Leader) или консоль:
--    p11_whitelist <jobId> <steamid> [1/0]
--    p11_wl_list   — посмотреть все допуски
--  Снятие допуска у игрока, который СЕЙЧАС на этой должности,
--  автоматически переводит его в новобранцы.
-- ============================================================

util.AddNetworkString("P11FW_WL_SYNC")
util.AddNetworkString("P11FW_WL_SET")
util.AddNetworkString("P11FW_WL_REQ")

local FILE = "polus_framework/whitelist.json"

-- ============ ФАЙЛ ============

local function SaveWhitelist()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    -- пустые списки должностей не пишем
    local out = {}
    for jobId, t in pairs(P11FW.Whitelist) do
        if istable(t) then
            local has = false
            for _ in pairs(t) do has = true break end
            if has then out[jobId] = t end
        end
    end
    P11FW.Whitelist = out
    file.Write(FILE, util.TableToJSON(out, true))
end

local function LoadWhitelist()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then
        for jobId, t in pairs(tbl) do
            if istable(t) then
                P11FW.Whitelist[jobId] = P11FW.Whitelist[jobId] or {}
                for sid in pairs(t) do
                    P11FW.Whitelist[jobId][sid] = true
                end
            end
        end
    end
end

hook.Add("InitPostEntity", "P11FW.WLLoad", function()
    timer.Simple(0.6, LoadWhitelist)
end)

-- ============ СИНК ============

function P11FW.SyncWhitelist(target)
    net.Start("P11FW_WL_SYNC")
        net.WriteString(util.TableToJSON(P11FW.Whitelist) or "{}")
    if IsValid(target) then net.Send(target) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "P11FW.WLJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then P11FW.SyncWhitelist(ply) end
    end)
end)

-- клиент просит актуальный слепок (открытие вкладки, лаг входа)
net.Receive("P11FW_WL_REQ", function(len, ply)
    if not IsValid(ply) then return end
    ply.P11WL_NextReq = ply.P11WL_NextReq or 0
    if CurTime() < ply.P11WL_NextReq then return end
    ply.P11WL_NextReq = CurTime() + 2
    P11FW.SyncWhitelist(ply)
end)

-- ============ ЯДРО: выдать/снять допуск ============

function P11FW.SetWhitelist(jobId, sid, allow, by)
    local job = P11FW.Jobs[jobId]
    if not job then return false, "нет такой должности: " .. tostring(jobId) end
    sid = P11FW.NormalizeSteamID(sid)
    if not sid then return false, "некорректный SteamID (нужен STEAM_0:x:y или SteamID64)" end

    P11FW.Whitelist[jobId] = P11FW.Whitelist[jobId] or {}
    if allow then
        P11FW.Whitelist[jobId][sid] = true
    else
        P11FW.Whitelist[jobId][sid] = nil
    end
    SaveWhitelist()
    P11FW.SyncWhitelist()

    local byName = IsValid(by) and by:Nick() or "КОНСОЛЬ"
    P11FW.Log("ВАЙТЛИСТ: " .. (allow and "+ДОПУСК" or "-ДОПУСК") ..
        " [" .. jobId .. "] " .. sid .. " (от: " .. byName .. ")")

    -- цель онлайн? уведомить (+ при снятии уволить с должности)
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID() == sid or p:SteamID64() == sid then
            if allow then
                p:ChatPrint("[ПОЛЮС-11] Тебе ВЫДАН допуск на должность: " .. job.name ..
                    " — бери её в F4 или у кадровика.")
            else
                p:ChatPrint("[ПОЛЮС-11] С тебя СНЯТ допуск на должность: " .. job.name)
                if P11FW.GetJobId(p) == jobId then
                    P11FW.SetJob(p, P11FW.Config.DefaultJob, nil, true)
                    p:ChatPrint("[ПОЛЮС-11] Допуск отозван — ты переведён в новобранцы.")
                end
            end
            break
        end
    end
    return true
end

-- ============ NET: правка из вкладки ВАЙТЛИСТ ============

net.Receive("P11FW_WL_SET", function(len, ply)
    if not IsValid(ply) or not P11FW.CanWhitelist(ply) then return end

    ply.P11WL_NextSet = ply.P11WL_NextSet or 0
    if CurTime() < ply.P11WL_NextSet then return end
    ply.P11WL_NextSet = CurTime() + 0.35

    local jobId = string.sub(net.ReadString(), 1, 64)
    local sid   = string.sub(net.ReadString(), 1, 32)
    local allow = net.ReadBool()

    local ok, err = P11FW.SetWhitelist(jobId, sid, allow, ply)
    if ok then
        P11FW.Notify(ply, (allow and "Допуск ВЫДАН: " or "Допуск СНЯТ: ") .. sid ..
            " → " .. (P11FW.Jobs[jobId] and P11FW.Jobs[jobId].name or jobId))
    else
        P11FW.Notify(ply, "ОТКАЗ: " .. tostring(err))
    end
end)

-- ============ КОНСОЛЬ ============

-- p11_whitelist <jobId> <steamid> [1/0]
concommand.Add("p11_whitelist", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.CanWhitelist(ply) then
        P11FW.Notify(ply, "Вайтлистом управляют администрация и ранги Faction Officer/Leader.")
        return
    end
    if not args[1] or not args[2] then
        local msg = "p11_whitelist <jobId> <steamid> [1/0] — выдать/снять допуск"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print("[P11FW] " .. msg) end
        return
    end
    local allow = tostring(args[3] or "1") ~= "0"
    local ok, err = P11FW.SetWhitelist(args[1], args[2], allow, IsValid(ply) and ply or nil)
    local msg = ok and ("OK: " .. (allow and "выдан" or "снят")) or ("ОШИБКА: " .. tostring(err))
    if IsValid(ply) then P11FW.Notify(ply, msg) else print("[P11FW] " .. msg) end
end)

-- p11_wl_list — все допуски в консоль
concommand.Add("p11_wl_list", function(ply)
    local out = { "== ВАЙТЛИСТ СТАНЦИИ ==" }
    local any = false
    for _, jobId in ipairs(P11FW.JobIds) do
        local job = P11FW.Jobs[jobId]
        if job and job.whitelist then
            out[#out + 1] = "  🔒 " .. job.name .. " [" .. jobId .. "] — допусков: " .. P11FW.WhitelistCount(jobId)
            local t = P11FW.Whitelist[jobId]
            if t then
                for sid in pairs(t) do
                    any = true
                    out[#out + 1] = "       " .. sid
                end
            end
        end
    end
    if not any then out[#out + 1] = "  (допусков пока не выдано)" end
    local text = table.concat(out, "\n")
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end)
