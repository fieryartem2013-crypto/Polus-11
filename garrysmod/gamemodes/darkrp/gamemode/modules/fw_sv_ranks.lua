-- ============================================================
--  ПОЛЮС FRAMEWORK — РАНГИ (server) v1.5
--  Хранение ranks.json, выдача, маппинг на GMod-группы,
--  секретный ключ основателя (p11_access), консоль p11_rank.
-- ============================================================

local FILE = "polus_framework/ranks.json"

P11FW.RankData = P11FW.RankData or {} -- steamid -> rankId

-- ============ ФАЙЛ ============

local function SaveRanks()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    file.Write(FILE, util.TableToJSON(P11FW.RankData, true))
end

local function LoadRanks()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then P11FW.RankData = tbl end
end

hook.Add("InitPostEntity", "P11FW.RanksLoad", function()
    timer.Simple(0.4, LoadRanks)
end)

-- ============ ПРИМЕНЕНИЕ ============

local function ApplyRank(ply)
    local id = P11FW.RankData[ply:SteamID()] or "user"
    id = (P11FW.RankLegacy and P11FW.RankLegacy[id]) or id -- v3.8.2: старые id -> новые
    if not P11FW.RankById[id] then id = "user" end
    ply.P11FW_RankId = id
    ply:SetNWString("P11FW_Rank", id)

    -- маппинг на движковые группы (для ноклипа/спавнменю/чужих плагинов)
    local lvl = P11FW.RankById[id].level or 0
    if not ply:IsListenServerHost() then
        if lvl >= 6 then
            ply:SetUserGroup("superadmin")
        elseif lvl >= 3 then
            ply:SetUserGroup("admin")
        else
            ply:SetUserGroup("user")
        end
    end
end

hook.Add("PlayerInitialSpawn", "P11FW.RankJoin", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then ApplyRank(ply) end
    end)
end)

-- ============ ВЫДАЧА ============

function P11FW.SetRank(target, rankId, by)
    if not (IsValid(target) and target:IsPlayer()) then return false, "нет игрока" end
    local rec = P11FW.RankById[rankId]
    if not rec then return false, "нет такого ранга: " .. tostring(rankId) end

    if IsValid(by) then
        if not P11FW.CanManageRank(by, rec.level) then
            return false, "недостаточно прав (нужен Куратор+, ранг не выше своего)"
        end
    end
    -- консоль/секрет (by = nil) проходят без проверки

    P11FW.RankData[target:SteamID()] = rankId
    ApplyRank(target)
    SaveRanks()

    local byName = IsValid(by) and by:Nick() or "КОНСОЛЬ/КЛЮЧ"
    P11FW.Log("РАНГ: " .. target:Nick() .. " → " .. rec.name .. " (выдал: " .. byName .. ")")
    if IsValid(by) then P11FW.Notify(by, "Ранг выдан: " .. target:Nick() .. " → " .. rec.name) end
    target:ChatPrint("[ПОЛЮС-11] Тебе выдан ранг: " .. rec.name)
    return true
end

-- консоль: p11_rank <игрок> <ранг>
-- v4.8.3 «ПОГЛОЩЕНИЕ» КОРЕНЬ БАГА «админка не выдаётся»: сюда
-- передавали targetLevel=99, а CanManageRank требует цель НИЖЕ
-- своего ранга (99 >= любого) — поэтому выдача молча умирала
-- ВСЕГДА. Проверяем только наличие права; потолок уровня сам
-- смотрит P11FW.SetRank через CanManageRank(by, rec.level).
concommand.Add("p11_rank", function(ply, cmd, args)
    if IsValid(ply) and not P11FW.CanManageRank(ply, nil) then
        P11FW.Notify(ply, "Выдавать ранги может Куратор и выше.")
        return
    end
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if p:Nick() == args[1] or p:SteamID() == args[1] or tostring(p:EntIndex()) == args[1] then
            target = p break
        end
    end
    if not IsValid(target) then
        print("[P11FW] игрок не найден: " .. tostring(args[1]))
        return
    end
    local ok, err = P11FW.SetRank(target, args[2], IsValid(ply) and ply or nil)
    if not ok then
        if IsValid(ply) then P11FW.Notify(ply, err) else print("[P11FW] " .. err) end
    else
        print("[P11FW] " .. target:Nick() .. " получил ранг " .. tostring(args[2]))
    end
end)

-- список рангов в консоль: p11_ranks
concommand.Add("p11_ranks", function(ply)
    local out = "[P11FW] Ранги: "
    for _, r in ipairs(P11FW.Ranks) do out = out .. r.id .. "(" .. r.level .. ") " end
    if IsValid(ply) then ply:ChatPrint(out) else print(out) end
end)

-- ============ СЕКРЕТНЫЙ КЛЮЧ ОСНОВАТЕЛЯ ============
-- p11_access <ключ> → ранг «Глава Полюса-11» + superadmin.
-- Ключ меняется в modules/fw_sh_config.lua (Config.FounderKey).

concommand.Add("p11_access", function(ply, cmd, args)
    if not IsValid(ply) then return end
    local want = (P11FW.Config and P11FW.Config.FounderKey) or ""
    local got = string.Trim(table.concat(args or {}, " "))

    if want == "" or got == "" or got ~= want then
        ply:ChatPrint("[ПОЛЮС-11] Неверный ключ доступа.")
        P11FW.Log("НЕВЕРНЫЙ КЛЮЧ основателя от " .. ply:Nick() .. " [" .. ply:SteamID() .. "]")
        return
    end

    P11FW.SetRank(ply, "glava", nil) -- без by: ключ и есть право
    ply:SetUserGroup("superadmin")
    local gname = (P11FW.RankById.glava and P11FW.RankById.glava.name) or "Глава Проекта"
    ply:ChatPrint("[ПОЛЮС-11] КЛЮЧ ПРИНЯТ. Ты теперь " .. gname .. " (superadmin).")
    P11FW.Log("!!! КЛЮЧ ОСНОВАТЕЛЯ ИСПОЛЬЗОВАН: " .. ply:Nick() .. " [" .. ply:SteamID() .. "] !!!")
end)
