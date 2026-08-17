-- ============================================================
--  ПОЛЮС-11 — v5.8.15 «ООН/ГОК + ЧИСТКА» (server, autorun)
--  Фракция ООН/ГОК и профы теперь ВПИСАНЫ В СИД напрямую
--  (fw_sv_seed_rkka.lua: SEED_FACTIONS.ungoc + SEED_JOBS seed_un_*).
--  Этот скрипт — ЧИСТКИ и СТРАХОВКИ:
--   1) НЕМЕЦКОЕ ОРУЖИЕ из ларька: k98, stg44, mp40, g43, p08;
--   2) СТРАХОВКА: если на сервере остались старые сейвы проф
--      Осовца (jobs_custom.json) или категория osowiec — вырезаем;
--   3) диагностика p11_ungocdiag (админ).
--  Старые файлы не трогаем (кроме разрешённых правок сида).
-- ============================================================

-- ============ ХЕЛПЕРЫ ============
local function Log(txt)
    if P11FW.Log then P11FW.Log(txt) else print("[POLUS-11][v5.8.15] " .. txt) end
end

local function IsOsovecJob(id)
    return isstring(id) and (
        id == "seed_oso_pioner" or id == "seed_oso_strelok" or id == "seed_oso_medik"
        or id == "seed_oso_nco" or id == "seed_oso_vermacht" or id == "seed_oso_oficer"
        or id == "seed_oso_general"
    )
end

-- ============ 1) НЕМЕЦКОЕ ОРУЖИЕ ИЗ ЛАРЬКА ============
local GERMAN_ITEMS = { "k98", "stg44", "mp40", "g43", "p08" }

local function CutGermanShop()
    if not POLUS11.Items then return 0 end
    local n = 0
    for _, id in ipairs(GERMAN_ITEMS) do
        if POLUS11.Items[id] then
            POLUS11.Items[id] = nil
            n = n + 1
        end
    end
    return n
end

-- ============ 2) СТРАХОВКА: ВЫРЕЗАТЬ ОСОВЕЦ (если остался в сейвах) ============
local function CutOsovec()
    local cut = 0

    if P11FW.CustomJobs then
        local keep = {}
        for _, rec in ipairs(P11FW.CustomJobs) do
            if not (rec and IsOsovecJob(rec.id)) then
                keep[#keep + 1] = rec
            else
                cut = cut + 1
            end
        end
        P11FW.CustomJobs = keep
    end

    if P11FW.Jobs then
        for id in pairs(P11FW.Jobs) do
            if IsOsovecJob(id) then
                local t = P11FW.JobTeams and P11FW.JobTeams[id]
                if t then
                    P11FW.TeamJobs[t] = nil
                    P11FW.JobTeams[id] = nil
                end
                P11FW.Jobs[id] = nil
            end
        end
    end

    if P11FW.Categories then
        local keep = {}
        for _, c in ipairs(P11FW.Categories) do
            if not (c and c.id == "osowiec") then keep[#keep + 1] = c end
        end
        P11FW.Categories = keep
    end
    if P11FW.CategoryList then
        local keep = {}
        for _, c in ipairs(P11FW.CategoryList) do
            if not (c and c.id == "osowiec") then keep[#keep + 1] = c end
        end
        P11FW.CategoryList = keep
    end
    if P11FW.CustomFactions and P11FW.CustomFactions.osowiec then
        P11FW.CustomFactions.osowiec = nil
    end

    -- игроки на профах Осовца — на дефолт
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local jid = P11FW.GetJobId and P11FW.GetJobId(p)
            if jid and IsOsovecJob(jid) then
                local def = P11FW.Config and P11FW.Config.DefaultJob
                if def and P11FW.SetJob then
                    P11FW.SetJob(p, def, 1, true)
                end
            end
        end
    end

    if cut > 0 then
        Log("v5.8.15: вырезано проф Осовца из сейвов: " .. cut)
        if P11FW.SaveCustomJobs then P11FW.SaveCustomJobs() end
        if P11FW.SyncCustomJobs then P11FW.SyncCustomJobs() end
    end
    return cut
end

-- ============ ЗАПУСК ПОСЛЕ СИДА ============
hook.Add("InitPostEntity", "P11.V5815.Run", function()
    timer.Simple(4, function()
        local nGerman = CutGermanShop()
        local nOsovec = CutOsovec()
        Log("v5.8.15: готово. Немецкое оружие из ларька: -" .. nGerman
            .. ", Осовец из сейвов: -" .. nOsovec .. " проф. Фракция ООН/ГОК — в сиде.")
    end)
end)
hook.Add("PostCleanupMap", "P11.V5815.Map", function()
    timer.Simple(4, function()
        CutGermanShop()
        CutOsovec()
    end)
end)

-- страховка: при спавне, если кто-то всё ещё в профе Осовца — сбросить
hook.Add("PlayerSpawn", "P11.V5815.Spawn", function(ply)
    timer.Simple(0.3, function()
        if not IsValid(ply) then return end
        local jid = P11FW.GetJobId and P11FW.GetJobId(ply)
        if jid and IsOsovecJob(jid) then
            local def = P11FW.Config and P11FW.Config.DefaultJob
            if def and P11FW.SetJob then P11FW.SetJob(ply, def, 1, true) end
        end
    end)
end)

-- ============ ДИАГНОСТИКА p11_ungocdiag ============
concommand.Add("p11_ungocdiag", function(ply)
    local isAdmin = (not IsValid(ply)) or ply:IsSuperAdmin()
        or (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
    if not isAdmin then
        if IsValid(ply) then ply:ChatPrint("[ООН/ГОК] Только для админов.") end
        return
    end
    local out = { "== ООН/ГОК: ДИАГНОСТИКА (v5.8.16) ==" }
    local hasUN, hasOso = false, false
    for _, c in ipairs(P11FW.CategoryList or {}) do
        if c.id == "ungoc" then hasUN = true end
        if c.id == "osowiec" then hasOso = true end
    end
    out[#out + 1] = "Фракция ООН/ГОК: " .. (hasUN and "ЕСТЬ" or "НЕТ")
    out[#out + 1] = "Фракция Осовец: " .. (hasOso and "ЕСТЬ (не вырезалась!)" or "вырезана")
    local nUN = 0
    for _, r in ipairs(P11FW.CustomJobs or {}) do
        if r.category == "ungoc" then nUN = nUN + 1 end
    end
    out[#out + 1] = "Проф ООН/ГОК: " .. nUN
    local german = {}
    for _, id in ipairs(GERMAN_ITEMS) do
        if POLUS11.Items and POLUS11.Items[id] then german[#german + 1] = id end
    end
    out[#out + 1] = "Немецкое оружие в ларьке: " .. (#german == 0 and "вырезано" or table.concat(german, ", "))
    local text = table.concat(out, "\n")
    print(text)
    if IsValid(ply) then
        for _, line in ipairs(out) do ply:ChatPrint(line) end
    end
end)

print("[POLUS-11] v5.8.15: чистки (немецкое оружие, Осовец из сейвов) + диагностика p11_ungocdiag. Фракция ООН/ГОК — в сиде.")
