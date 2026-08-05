-- ============================================================
--  ПОЛЮС FRAMEWORK — ФРАКЦИИ (shared)
--  Фракция = группа должностей (гарнизон / учёные / ваши
--  собственные: «медики», «лётный состав», «конвой»...).
--  Технически фракция — расширенная категория: встроенные три
--  + кастомные из админ-меню (сохраняются на сервере,
--  синхронизируются всем клиентам через P11FW_FactionsSync).
--  F4, скорборд и админка группируются по фракциям сами.
-- ============================================================

P11FW = P11FW or {}

-- id -> { id, name, desc, order, color, custom }
P11FW.CustomFactions = P11FW.CustomFactions or {}

-- ============ ПОИСК / ХЕЛПЕРЫ ============

--- Категория(=фракция) по id; неизвестный id -> "misc" (или первую).
function P11FW.GetCategory(id)
    for _, c in ipairs(P11FW.CategoryList or {}) do
        if c.id == id then return c end
    end
    for _, c in ipairs(P11FW.CategoryList or {}) do
        if c.id == "misc" then return c end
    end
    return (P11FW.CategoryList or {})[1]
end

--- Фракция, к которой относится должность.
function P11FW.JobFaction(job)
    if not istable(job) then return P11FW.GetCategory("misc") end
    return P11FW.GetCategory(job.faction or job.category or "misc")
end

--- Текст фракции игрока.
function P11FW.GetFactionName(ply)
    local job = P11FW.GetJob and P11FW.GetJob(ply) or nil
    local cat = P11FW.JobFaction(job)
    return cat and cat.name or ""
end

-- ============ РЕГИСТРАЦИЯ КАСТОМНЫХ ФРАКЦИЙ ============
-- records = { {id, name, desc, order, color={r,g,b}}, ... }

function P11FW.RegisterCustomFactions(records)
    records = istable(records) and records or {}

    -- 1) снести прежние кастомные из общего списка
    local builtins = {}
    for _, c in ipairs(P11FW.Categories or {}) do
        if not c.custom then builtins[#builtins + 1] = c end
    end

    -- 2) собрать заново: встроенные + кастомные
    P11FW.CustomFactions = {}
    P11FW.Categories = builtins

    for _, rec in ipairs(records) do
        if istable(rec) and isstring(rec.id) and isstring(rec.name) and rec.name ~= "" then
            -- не даём кастому перекрыть встроенные id
            local clash = false
            for _, c in ipairs(P11FW.Categories) do
                if c.id == rec.id then clash = true break end
            end
            if not clash then
                local col = istable(rec.color) and rec.color or {}
                local cat = {
                    id     = rec.id,
                    name   = string.sub(rec.name, 1, 32),
                    desc   = string.sub(tostring(rec.desc or ""), 1, 300),
                    order  = tonumber(rec.order) or 50,
                    color  = Color(tonumber(col.r) or 200, tonumber(col.g) or 160, tonumber(col.b) or 110),
                    custom = true,
                }
                P11FW.Categories[#P11FW.Categories + 1] = cat
                P11FW.CustomFactions[rec.id] = cat
            end
        end
    end

    -- 3) пересортированный список для меню
    P11FW.CategoryList = table.Copy(P11FW.Categories)
    table.sort(P11FW.CategoryList, function(a, b) return (a.order or 99) < (b.order or 99) end)

    -- 4) при живой админке/F4 — обновить
    if CLIENT then
        if IsValid(P11FW.AdminFrame) and P11FW.AdminFrame.RefreshFactions then
            P11FW.AdminFrame:RefreshFactions()
        end
        if IsValid(P11FW.AdminFrame) and P11FW.AdminFrame.RefreshJobsTab then
            P11FW.AdminFrame:RefreshJobsTab()
        end
    end
end

-- ============ КЛИЕНТ: ПРИЁМ СИНКА ============

if CLIENT then
    net.Receive("P11FW_FactionsSync", function()
        local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "[]")
        if ok and istable(tbl) then
            P11FW.RegisterCustomFactions(tbl)
        end
    end)
end
