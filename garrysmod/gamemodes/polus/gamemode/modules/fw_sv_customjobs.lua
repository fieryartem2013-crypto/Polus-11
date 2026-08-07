-- ============================================================
--  ПОЛЮС FRAMEWORK — кастомные должности, создаваемые в игре
--  Админ: имя, категория, цвет, лимит, модели, оружие.
--  Сохраняются в data/polus_framework/jobs_custom.json и
--  рассылаются всем клиентам (teams регистрируются на обеих
--  сторонах, индексы team = 200+, чтобы не задеть встроенные).
-- ============================================================

util.AddNetworkString("P11FW_JobsSync")
util.AddNetworkString("P11FW_JobEdit")

local FILE = "polus_framework/jobs_custom.json"
local TEAM_CUSTOM_BASE = 200

P11FW.CustomJobs = P11FW.CustomJobs or {} -- массив records

-- ============ ФАЙЛ ============

function P11FW.SaveCustomJobs()
    if not file.IsDir("polus_framework", "DATA") then file.CreateDir("polus_framework") end
    file.Write(FILE, util.TableToJSON(P11FW.CustomJobs, true))
end

function P11FW.LoadCustomJobs()
    local raw = file.Read(FILE, "DATA")
    if not raw then return end
    local tbl = util.JSONToTable(raw)
    if not istable(tbl) then P11FW.CustomJobs = {} return end
    P11FW.CustomJobs = tbl
    P11FW.RegisterCustomJobs(P11FW.CustomJobs)
    P11FW.Log("Кастомных должностей загружено: " .. #P11FW.CustomJobs)
end

-- ============ СИНХРОНИЗАЦИЯ ============

function P11FW.SyncCustomJobs(target)
    local json = util.TableToJSON(P11FW.CustomJobs, true) or "[]"
    net.Start("P11FW_JobsSync")
        net.WriteString(json)
    if IsValid(target) then net.Send(target) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "P11FW.JobsSyncJoin", function(ply)
    timer.Simple(4, function()
        if IsValid(ply) then P11FW.SyncCustomJobs(ply) end
    end)
end)

-- ============ ВАЛИДАЦИЯ ЗАПИСИ ============

local function SanitizeRecord(rec)
    if not istable(rec) then return nil end
    local out = {}

    out.name = string.sub(tostring(rec.name or ""), 1, 40)
    if out.name == "" then return nil end

    local catOk = false
    for _, c in ipairs(P11FW.CategoryList) do
        if c.id == rec.category then catOk = true end
    end
    out.category = catOk and rec.category or "misc"

    out.desc = string.sub(tostring(rec.desc or ""), 1, 400)
    out.terminal = rec.terminal == true
    out.max = math.Clamp(tonumber(rec.max) or 0, 0, 32)

    local c = istable(rec.color) and rec.color or {}
    out.color = {
        r = math.Clamp(tonumber(c.r) or 210, 0, 255),
        g = math.Clamp(tonumber(c.g) or 170, 0, 255),
        b = math.Clamp(tonumber(c.b) or 120, 0, 255),
    }

    out.models = {}
    for _, m in ipairs(istable(rec.models) and rec.models or {}) do
        if isstring(m) and #out.models < 8 then
            out.models[#out.models + 1] = string.sub(m, 1, 128)
        end
    end

    out.weapons = {}
    for _, w in ipairs(istable(rec.weapons) and rec.weapons or {}) do
        if isstring(w) and #out.weapons < 8 then
            out.weapons[#out.weapons + 1] = string.sub(w, 1, 64)
        elseif istable(w) and #out.weapons < 8 then
            -- v4.8.0: СПИСОК КАНДИДАТОВ (EFT ARC9) — живёт таблицей,
            -- сервер выдаст первый существующий класс.
            local cand = {}
            for _, alt in ipairs(w) do
                if isstring(alt) and #cand < 4 then
                    cand[#cand + 1] = string.sub(alt, 1, 64)
                end
            end
            if #cand > 0 then out.weapons[#out.weapons + 1] = cand end
        end
    end

    -- v3.8.2: характеристики (необязательные). nil = оставить как было.
    if rec.hp ~= nil    then out.hp    = math.Clamp(tonumber(rec.hp) or 100, 1, 1000) end
    if rec.armor ~= nil then out.armor = math.Clamp(tonumber(rec.armor) or 0, 0, 500) end
    if rec.event ~= nil then out.event = rec.event == true end

    -- v4.4.0: ВАЙТЛИСТ-галочка. nil = оставить как было при правке.
    if rec.whitelist ~= nil then out.whitelist = rec.whitelist == true end

    -- v4.5.0: ВРЕМЯ для входа (минуты игры, 0 = без требования).
    if rec.time ~= nil then out.time = math.Clamp(tonumber(rec.time) or 0, 0, 50000) end

    -- v4.8.0: VIP-галочка. nil = оставить как было при правке.
    if rec.vip ~= nil then out.vip = rec.vip == true end

    return out
end

local function NextFreeTeam()
    for t = TEAM_CUSTOM_BASE, TEAM_CUSTOM_BASE + 60 do
        if not P11FW.TeamJobs[t] then return t end
    end
    return nil
end

local function FindCustom(id)
    for i, rec in ipairs(P11FW.CustomJobs) do
        if rec.id == id then return rec, i end
    end
    return nil, nil
end

-- ============ NET: правки от админа ============

net.Receive("P11FW_JobEdit", function(len, ply)
    if not IsValid(ply) or not P11FW.Config.Admin(ply) then return end

    ply.P11FW_NextEdit = ply.P11FW_NextEdit or 0
    if CurTime() < ply.P11FW_NextEdit then return end
    ply.P11FW_NextEdit = CurTime() + 1

    local act = net.ReadUInt(3) -- 1 создать, 2 обновить, 3 удалить
    local rec = util.JSONToTable(net.ReadString()) or {}

    if act == 1 then
        local team = NextFreeTeam()
        if not team then P11FW.Notify(ply, "Лимит кастомных должностей исчерпан (60).") return end
        local clean = SanitizeRecord(rec)
        if not clean then P11FW.Notify(ply, "Заполни хотя бы имя должности.") return end

        clean.id = "custom_" .. team
        clean.team = team
        clean.order = 100 + #P11FW.CustomJobs
        P11FW.CustomJobs[#P11FW.CustomJobs + 1] = clean

        P11FW.SaveCustomJobs()
        P11FW.RegisterCustomJobs(P11FW.CustomJobs)
        P11FW.SyncCustomJobs()
        P11FW.Notify(ply, "Должность «" .. clean.name .. "» создана и сохранена.")
        P11FW.Log(ply:Nick() .. " создал должность " .. clean.name)

    elseif act == 2 then
        local old = FindCustom(rec.id)
        if not old then
            -- v3.8.1: ВСТРОЕННУЮ тоже можно править — создаём override
            local job = P11FW.Jobs[rec.id]
            if not job or job.custom then
                P11FW.Notify(ply, "Должность не найдена.")
                return
            end
            local clean = SanitizeRecord(rec)
            if not clean then P11FW.Notify(ply, "Имя не должно быть пустым.") return end
            clean.id = rec.id
            clean.team = P11FW.JobTeams[rec.id]
            clean.order = job.order or 99
            clean.override = true
            P11FW.CustomJobs[#P11FW.CustomJobs + 1] = clean

            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Notify(ply, "Встроенная должность «" .. clean.name .. "» перекрыта правкой оружия/моделей/лимита.")
            P11FW.Log(ply:Nick() .. " перекрыл встроенную должность " .. rec.id)
            return
        end
        local clean = SanitizeRecord(rec)
        if not clean then P11FW.Notify(ply, "Имя не должно быть пустым.") return end

        clean.id = old.id
        clean.team = old.team
        clean.order = old.order
        clean.override = old.override == true
        -- v3.8.2: админ не редактирует ХП/броню — не теряем их при правке
        if clean.hp == nil    then clean.hp    = old.hp    end
        if clean.armor == nil then clean.armor = old.armor end
        if clean.event == nil then clean.event = old.event end
        if clean.whitelist == nil then clean.whitelist = old.whitelist end -- v4.4.0
        if clean.time == nil then clean.time = old.time end -- v4.5.0
        if clean.vip == nil then clean.vip = old.vip end -- v4.8.0
        for i, r in ipairs(P11FW.CustomJobs) do
            if r.id == old.id then P11FW.CustomJobs[i] = clean end
        end

        P11FW.SaveCustomJobs()
        P11FW.RegisterCustomJobs(P11FW.CustomJobs)
        P11FW.SyncCustomJobs()
        P11FW.Notify(ply, "Должность «" .. clean.name .. "» обновлена.")

    elseif act == 3 then
        local old, idx = FindCustom(rec.id)
        if not old then P11FW.Notify(ply, "Снять можно только кастомную/правку.") return end

        -- v3.8.1: снятие ПРАВКИ встроенной — игроки остаются на должности,
        -- заводская версия возвращается сама в RegisterCustomJobs
        if old.override then
            table.remove(P11FW.CustomJobs, idx)
            P11FW.SaveCustomJobs()
            P11FW.RegisterCustomJobs(P11FW.CustomJobs)
            P11FW.SyncCustomJobs()
            P11FW.Notify(ply, "Правка снята — должность «" .. old.name .. "» снова заводская.")
            return
        end

        -- всех, кто на ней, — в новобранцы
        for _, p in ipairs(player.GetAll()) do
            if P11FW.GetJobId(p) == old.id then
                P11FW.SetJob(p, P11FW.Config.DefaultJob, nil, true)
                P11FW.Notify(p, "Ваша должность упразднена.")
            end
        end

        table.remove(P11FW.CustomJobs, idx)
        P11FW.SaveCustomJobs()
        P11FW.RegisterCustomJobs(P11FW.CustomJobs)
        P11FW.SyncCustomJobs()
        P11FW.Notify(ply, "Должность «" .. old.name .. "» удалена.")
    end
end)

-- первичная регистрация при старте сервера
P11FW.LoadCustomJobs()
