-- ============================================================
--  ПОЛЮС FRAMEWORK — ФРАКЦИИ (server)
--  Создание/редактирование/удаление фракций из админ-меню.
--  Хранятся в data/polus_framework/factions.json, рассылаются
--  всем клиентам (P11FW_FactionsSync, как JobsSync у должностей).
-- ============================================================

util.AddNetworkString("P11FW_FactionsSync")

local FILE = "polus_framework/factions.json"

-- ============ СПИСОК -> RECORDS ============

local function FactionsToRecords()
    local out = {}
    for id, cat in pairs(P11FW.CustomFactions or {}) do
        out[#out + 1] = {
            id       = id,
            name     = cat.name,
            desc     = cat.desc or "",
            order    = cat.order or 50,
            override = cat.override == true, -- v3.8.1: правка встроенной
            color    = { r = cat.color.r, g = cat.color.g, b = cat.color.b },
        }
    end
    table.sort(out, function(a, b) return (a.order or 50) < (b.order or 50) end)
    return out
end

-- ============ ФАЙЛ ============

function P11FW.SaveFactions()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    file.Write(FILE, util.TableToJSON(FactionsToRecords(), true))
end

function P11FW.LoadFactions()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then
        P11FW.RegisterCustomFactions(tbl)
        P11FW.Log("Кастомных фракций загружено: " .. #tbl)
    end
end

hook.Add("InitPostEntity", "P11FW.FactionsLoad", function()
    timer.Simple(0.6, P11FW.LoadFactions)
end)

-- ============ СИНХРОНИЗАЦИЯ ============

function P11FW.SyncFactions(target)
    local json = util.TableToJSON(FactionsToRecords(), true) or "[]"
    net.Start("P11FW_FactionsSync")
        net.WriteString(json)
    if IsValid(target) then net.Send(target) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "P11FW.FactionsSyncJoin", function(ply)
    timer.Simple(4.3, function()
        if IsValid(ply) then P11FW.SyncFactions(ply) end
    end)
end)

-- ============ UPSERT / DELETE (из админки) ============

local function SanitizeFaction(rec)
    if not istable(rec) then return nil end
    local out = {}
    out.name = string.sub(string.Trim(tostring(rec.name or "")), 1, 32)
    if out.name == "" then return nil end
    out.desc  = string.sub(tostring(rec.desc or ""), 1, 300)
    out.order = math.Clamp(tonumber(rec.order) or 50, 1, 999)
    local c = istable(rec.color) and rec.color or {}
    out.color = {
        r = math.Clamp(tonumber(c.r) or 200, 0, 255),
        g = math.Clamp(tonumber(c.g) or 160, 0, 255),
        b = math.Clamp(tonumber(c.b) or 110, 0, 255),
    }
    return out
end

function P11FW.UpsertFaction(rec)
    local clean = SanitizeFaction(rec)
    if not clean then return false, "кривые данные фракции" end

    -- обновление существующей?
    local id = isstring(rec.id) and rec.id or nil
    -- v3.8.1: редактирование ВСТРОЕННОЙ фракции → создаём override-запись
    if id and not P11FW.CustomFactions[id] then
        if P11FW.GetCategory and P11FW.GetCategory(id) and P11FW.GetCategory(id).id == id then
            clean.override = true -- штамп: это правка заводской фракции
        else
            id = nil
        end
    end

    -- новая: сгенерировать свободный id
    if not id then
        local n = 1
        while P11FW.CustomFactions["fac" .. n] or (P11FW.GetCategory("fac" .. n).id == "fac" .. n and not P11FW.CustomFactions["fac" .. n]) do
            -- защита от пересечений со встроенными (их id не facN, так что цикл быстро кончится)
            if P11FW.CustomFactions["fac" .. n] then n = n + 1 else break end
        end
        id = "fac" .. n
    end

    clean.id = id

    local all = FactionsToRecords()
    local replaced = false
    for i, r in ipairs(all) do
        if r.id == id then all[i] = clean replaced = true break end
    end
    if not replaced then all[#all + 1] = clean end

    P11FW.RegisterCustomFactions(all)
    P11FW.SaveFactions()
    P11FW.SyncFactions()
    P11FW.Log("Фракция " .. (replaced and "обновлена" or "создана") .. ": " .. clean.name .. " [" .. id .. "]")
    return true, id
end

function P11FW.DeleteFaction(id)
    if not P11FW.CustomFactions or not P11FW.CustomFactions[id] then
        return false, "такой кастомной фракции нет (встроенные удалять нельзя)"
    end
    local wasOverride = P11FW.CustomFactions[id].override == true
    local all = FactionsToRecords()
    for i, r in ipairs(all) do
        if r.id == id then table.remove(all, i) break end
    end
    P11FW.RegisterCustomFactions(all)
    P11FW.SaveFactions()
    P11FW.SyncFactions()
    P11FW.Log((wasOverride and "Правка фракции снята (встроенная вернулась): " or "Фракция удалена: ") .. id)
    return true
end
