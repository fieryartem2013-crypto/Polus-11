-- ============================================================
--  ПОЛЮС-11 — ВЫДАЧА РАНГОВ: Staff Leader ≠ Administrator
--  v5.8.28 (НОВЫЙ ФАЙЛ, autorun/server)
--  Оборачиваем P11FW.SetRank / CanManageRank БЕЗ правки старых файлов.
--  Попытка выдать запрещённый ранг: блок + чат + лог (дата, SteamID, ранг).
-- ============================================================

local LOG = "polus_framework/rank_grant.log"
local CFG = "polus_framework/rank_grant.json"

local function LoadGrantFile()
    if not file.Exists(CFG, "DATA") then return end
    local raw = file.Read(CFG, "DATA")
    if not raw or raw == "" then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if not (ok and istable(tbl)) then return end
    -- формат: { "staff_leader": ["user","helper", ...] }
    for granter, list in pairs(tbl) do
        if istable(list) then
            P11FW.RankGrantAllow = P11FW.RankGrantAllow or {}
            P11FW.RankGrantAllow[granter] = list
        end
    end
    print("[POLUS-11] v5.8.28: список выдачи рангов прочитан из " .. CFG)
end

local function EnsureGrantFile()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    if file.Exists(CFG, "DATA") then return end
    local dump = {}
    for k, v in pairs(P11FW.RankGrantAllow or {}) do dump[k] = v end
    file.Write(CFG, util.TableToJSON(dump, true) or "{}")
end

local function GrantLog(line)
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    local stamp = os.date("%Y-%m-%d %H:%M:%S")
    file.Append(LOG, "[" .. stamp .. "] " .. tostring(line) .. "\n")
    print("[P11FW][GRANT] " .. stamp .. " " .. tostring(line))
    if P11FW.Log then P11FW.Log("GRANT: " .. tostring(line)) end
end

local function Notify(ply, msg)
    if not IsValid(ply) then return end
    if P11FW.Notify then
        P11FW.Notify(ply, msg)
    else
        ply:ChatPrint("[ПОЛЮС-11] " .. msg)
    end
end

local function WrapSetRank()
    if not P11FW or not P11FW.SetRank then return false end
    if P11FW.SetRank.P11_GrantV5828 then return true end
    local orig = P11FW.SetRank
    local wrap = function(target, rankId, by)
        if IsValid(by) and by:IsPlayer() then
            local gr = P11FW.GetRank and P11FW.GetRank(by)
            local gid = gr and gr.id or ""
            local okA, why = true, nil
            if P11FW.RankGrantAllowed then
                okA, why = P11FW.RankGrantAllowed(gid, rankId)
            end
            if not okA then
                local rec = P11FW.RankById and P11FW.RankById[rankId]
                local want = (rec and rec.name) or tostring(rankId)
                Notify(by, why or "У вас нет прав для выдачи этого ранга")
                GrantLog(string.format("DENY %s [%s] tried '%s' (%s) → %s",
                    by:Nick(), by:SteamID(), tostring(rankId), want,
                    IsValid(target) and target:Nick() or "?"))
                return false, why or "У вас нет прав для выдачи этого ранга"
            end
        end
        return orig(target, rankId, by)
    end
    wrap.P11_GrantV5828 = true
    P11FW.SetRank = wrap
    return true
end

local function WrapCanManage()
    if not P11FW or not P11FW.CanManageRank then return false end
    if P11FW.CanManageRank.P11_GrantV5828 then return true end
    local orig = P11FW.CanManageRank
    local wrap = function(ply, targetLevel)
        local ok = orig(ply, targetLevel)
        if not ok then return false end
        if not IsValid(ply) then return ok end
        local gr = P11FW.GetRank and P11FW.GetRank(ply)
        if not (gr and gr.id == "staff_leader") then return ok end
        -- Staff Leader + цель уровня Administrator (4) → нет
        if targetLevel and tonumber(targetLevel) == 4 then
            return false
        end
        return ok
    end
    wrap.P11_GrantV5828 = true
    P11FW.CanManageRank = wrap
    return true
end

local function Boot()
    LoadGrantFile()
    EnsureGrantFile()
    local a, b = WrapSetRank(), WrapCanManage()
    if a and b then
        print("[POLUS-11] v5.8.28: выдача рангов — Staff Leader не выдаёт Administrator")
    end
end

hook.Add("InitPostEntity", "P11.RankGrant.v5828", function()
    timer.Simple(0.6, Boot)
    timer.Simple(2, Boot)
    timer.Simple(6, Boot)
end)
timer.Simple(0.2, Boot)

concommand.Add("p11_rankgrant_reload", function(ply)
    if IsValid(ply) and not (P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 16) then return end
    LoadGrantFile()
    if IsValid(ply) then Notify(ply, "Список выдачи рангов перечитан.") end
end)
