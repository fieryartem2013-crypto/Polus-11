-- ============================================================
--  ПОЛЮС FRAMEWORK — ВАЙТЛИСТ ДОЛЖНОСТЕЙ (shared) v4.4.0
--  Должность с флагом whitelist = true (напр. ВСЁ НКВД) берётся
--  ТОЛЬКО с допуском. Управляют допусками: администрация и
--  ранги Faction Officer / Faction Leader (флаг wl в ранге) —
--  у них НЕТ админки, но есть вкладка ВАЙТЛИСТ в /menu.
--  Содержимое вайтлиста синкается на всех клиентов (только
--  SteamID'ы, трафик копеечный) — так F4 сразу рисует 🔒,
--  а вкладка ВАЙТЛИСТ работает без запросов к серверу.
--  Хранение: data/polus_framework/whitelist.json
--    { [jobId] = { ["STEAM_0:x:y"]=true, ["7656..."]=true } }
-- ============================================================

P11FW = P11FW or {}

P11FW.Whitelist = P11FW.Whitelist or {} -- jobId -> { sid = true }

--- Нужен ли должности допуск (галочка «ВАЙТЛИСТ» в редакторе проф)
function P11FW.JobNeedsWhitelist(jobId)
    local job = P11FW.Jobs and P11FW.Jobs[jobId]
    return job ~= nil and job.whitelist == true
end

--- Есть ли у игрока допуск на должность.
--- Принимаются оба формата: STEAM_0:x:y и SteamID64.
function P11FW.HasWhitelist(ply, jobId)
    if not IsValid(ply) or not jobId then return false end
    local t = P11FW.Whitelist and P11FW.Whitelist[jobId]
    if not t then return false end
    local sid = ply:SteamID()
    if sid and t[sid] then return true end
    local s64 = ply:SteamID64()
    if s64 and t[s64] then return true end
    return false
end

--- v4.6.7: надо ли ПРЯТАТЬ вайтлист-профу от игрока в списках (F4).
--- Прячем, если включён Config.HideWhitelistJobs и у игрока нет ни
--- допуска, ни прав (админ / Глава 16 — те видят и могут брать).
function P11FW.WLHiddenFor(ply, jobId)
    if not (P11FW.Config and P11FW.Config.HideWhitelistJobs) then return false end
    if not P11FW.JobNeedsWhitelist(jobId) then return false end
    if IsValid(ply) then
        if P11FW.Config.Admin and P11FW.Config.Admin(ply) then return false end
        if P11FW.GetRankLevel and P11FW.GetRankLevel(ply) >= 16 then return false end
        if P11FW.HasWhitelist(ply, jobId) then return false end
    end
    return true
end

--- Сколько допусков выдано на должность
function P11FW.WhitelistCount(jobId)
    local t = P11FW.Whitelist and P11FW.Whitelist[jobId]
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Аккуратная нормализация SteamID (ввод руками из меню/консоли):
--- лишние пробелы долой, верхний регистр, только валидные формы.
function P11FW.NormalizeSteamID(s)
    s = string.Trim(tostring(s or ""))
    if s == "" then return nil end
    s = string.upper(s)
    if string.match(s, "^STEAM_%d:%d:%d+$") then return s end
    if string.match(s, "^%d+$") and #s >= 15 and #s <= 20 then return s end -- SteamID64
    return nil
end

-- ============ КЛИЕНТ: приём полного синка ============
if CLIENT then
    net.Receive("P11FW_WL_SYNC", function()
        local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
        if ok and istable(tbl) then
            P11FW.Whitelist = tbl
        end
        -- обновить открытые меню
        if IsValid(P11FW.AdminFrame) and P11FW.AdminFrame.RefreshWhitelistTab then
            P11FW.AdminFrame:RefreshWhitelistTab()
        end
        if IsValid(P11FW.MenuFrame) and P11FW.MenuFrame.RefreshRight then
            P11FW.MenuFrame:RefreshRight()
        end
    end)
end
