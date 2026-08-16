-- ============================================================
--  ПОЛЮС-11 — ФИКС !ПРОФА + ПОРЯДОК HUD v5.8.14 (server)
--  1) !ПРОФА <название> — не работало с заглавной «П» (старый
--     перехват ловил только строчный регистр). Этот файл грузится
--     ПОСЛЕДНИМ (zz) → обёртка поверх всех: ловит !профа/!Профа/
--     !ПРОФА в любом регистре, меняет название роли в РЕАЛЬНОМ
--     времени (NWString P11_JobName → намики/TAB сразу), не даёт
--     уйти в OOC. Сброс: !профа или !профа сброс.
--  2) Спавнит энтити polus_p11_hudfix (клиент: HUD основной
--     поверх HUD Нечто).
--  Старые файлы не трогаем.
-- ============================================================

-- ============ 1) !ПРОФА (все регистры) ============
local function SetJobName(ply, name)
    if not IsValid(ply) then return end
    name = string.Trim(tostring(name or ""))
    if name == "" or string.lower(name) == "сброс" or string.lower(name) == "reset" then
        ply:SetNWString("P11_JobName", "")
        if POLUS11.Notify then POLUS11.Notify(ply, "Название профессии сброшено (штатное).") end
        return
    end
    name = string.sub(name, 1, 40)
    if #name < 2 then
        if POLUS11.Notify then POLUS11.Notify(ply, "Слишком коротко — минимум 2 символа.") end
        return
    end
    ply:SetNWString("P11_JobName", name)
    if POLUS11.Notify then
        POLUS11.Notify(ply, "Название профессии: «" .. name .. "» — теперь так видно в TAB и над головой.")
    end
    if POLUS11.Log then POLUS11.Log("!Профа: " .. ply:Nick() .. " переименовал профу в «" .. name .. "»") end
end

local function IsProfa(first)
    return first == "!профа" or first == "!Профа" or first == "!ПРОФА"
        or first == "!пРОФА" or first == "!профa" or first == "!Профa"
end

-- обёртка поверх ВСЕХ (этот файл грузится последним — zz в имени)
local function PatchProfa()
    local t = hook.GetTable()
    local ps = t and t.PlayerSay
    local orig = ps and ps["P11.ChatCore"]
    if not orig then return false end
    if orig.P11_ProfaFix then return true end

    local Wrap = function(ply, text)
        local raw = string.Trim(tostring(text or ""))
        local first = string.match(raw, "^(%S+)") or ""
        if IsProfa(first) then
            if IsValid(ply) then
                local name = string.Trim(string.sub(raw, #first + 1))
                SetJobName(ply, name)
            end
            return ""
        end
        return orig(ply, text)
    end
    Wrap.P11_ProfaFix = true
    ps["P11.ChatCore"] = Wrap
    print("[POLUS-11] v5.8.14: !профа (любой регистр) перехвачен — смена роли в реальном времени")
    return true
end

hook.Add("InitPostEntity", "P11.ProfaFix.Start", function()
    timer.Simple(1, PatchProfa)
end)
timer.Simple(0.5, PatchProfa)
timer.Simple(2, PatchProfa)
timer.Simple(5, PatchProfa)
timer.Simple(10, PatchProfa)

-- ============ 2) СПАВН ЭНТИТИ HUD-ФИКСА ============
local function SpawnHudFix()
    if ents.FindByClass("polus_p11_hudfix")[1] then return end
    local e = ents.Create("polus_p11_hudfix")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.HudFix.Spawn", function()
    timer.Simple(1, SpawnHudFix)
end)
hook.Add("PostCleanupMap", "P11.HudFix.Spawn2", function()
    timer.Simple(3, SpawnHudFix)
end)

print("[POLUS-11] v5.8.14: !профа работает во всех регистрах, HUD-фикс спавнится")
