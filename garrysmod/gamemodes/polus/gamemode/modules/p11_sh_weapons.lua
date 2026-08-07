-- ============================================================
--  ПОЛЮС-11 — АРСЕНАЛ EFT ARC9 + ФОЛБЭКИ (shared) v4.8.0
--  Заявка владельца: «используй вооружение из пака EFT ARC9».
--
--  КАК РАБОТАЕТ:
--  У должности (job.weapons) запись-оружие может быть:
--    • строкой  "arc9_eft_aks74"          — один класс;
--    • таблицей {"arc9_eft_aks74","weapon_ar2"} — КАНДИДАТЫ:
--      выдаётся ПЕРВЫЙ существующий на сервере класс.
--  Поставил пак [ARC9] EFT Weapons — бойцы ходят с EFT-стволами.
--  Нет пака — автоматом выдаётся стоковый HL2-аналог, и НИКТО
--  не остаётся безоружным. Раньше несуществующий класс просто
--  молча не выдавался (боец без пушки — баг «голый гарнизон»).
--
--  WepFallback — карта для СТРОГО строковых записей (старые сейвы):
--  если класса нет, берём его стоковый аналог.
--
--  Выбранное оружие видно в F4 (чипы снаряжения) теми же именами.
--  Сервер при старте печатает сводку: что встало EFT, что — фолбэк.
-- ============================================================

POLUS11 = POLUS11 or {}

-- HL2-аналоги для строковых записей без кандидатов
POLUS11.WepFallback = {
    arc9_eft_aks74u         = "weapon_smg1",
    arc9_eft_aks74          = "weapon_ar2",
    arc9_eft_ak74           = "weapon_ar2",
    arc9_eft_ak74m          = "weapon_ar2",
    arc9_eft_ak105          = "weapon_ar2",
    arc9_eft_rpk16          = "weapon_ar2",
    arc9_eft_ppsh41         = "weapon_smg1",
    arc9_eft_mosin_infantry = "weapon_crossbow",
    arc9_eft_mosin_sniper   = "weapon_crossbow",
    arc9_eft_svd            = "weapon_crossbow",
    arc9_eft_mr43           = "weapon_shotgun",
    arc9_eft_mr43e          = "weapon_shotgun",
    arc9_eft_mp133          = "weapon_shotgun",
    arc9_eft_mp153          = "weapon_shotgun",
    arc9_eft_saiga12k       = "weapon_shotgun",
    arc9_eft_pm             = "weapon_pistol",
    arc9_eft_tt33           = "weapon_pistol",
    arc9_eft_aps            = "weapon_pistol",
    arc9_doi_k98            = "weapon_crossbow",
    -- v4.8.5 «КРАСНЫЙ ОРЁЛ»: американская резидентура
    arc9_eft_m1911a1        = "weapon_pistol",  -- Colt M1911A1 (.45 ACP)
    arc9_eft_m870           = "weapon_shotgun", -- Remington 870 (помпа США)
    arc9_eft_velociraptor   = "weapon_ar2",     -- v4.8.6: глушёный Velociraptor .300 BLK (исключение Центра)
}

-- боезапас для СТОКОВЫХ фолбэков (EFT-стволам не нужен — своя система)
POLUS11.WepAmmoHL2 = {
    weapon_pistol   = { "pistol",   54 },
    weapon_smg1     = { "smg1",     90 },
    weapon_ar2      = { "ar2",      60 },
    weapon_shotgun  = { "buckshot", 24 },
    weapon_crossbow = { "XBowBolt", 6 },
    weapon_357      = { "357",      12 },
}

--- Класс оружия, которое РЕАЛЬНО существует на этом realm'е.
--- entry — строка или таблица кандидатов; nil — выдать нечего.
function POLUS11.ResolveWeaponClass(entry)
    if istable(entry) then
        for _, alt in ipairs(entry) do
            if isstring(alt) and weapons.Get(alt) then
                return alt
            end
        end
        return nil
    end
    if isstring(entry) then
        if weapons.Get(entry) then return entry end
        local fb = POLUS11.WepFallback and POLUS11.WepFallback[entry]
        if fb and weapons.Get(fb) then return fb end
    end
    return nil
end

-- ============ СТАРТОВАЯ СВОДКА (сервер) ============
--  Видно сразу: определился ли пак EFT ARC9 в этом запуске.
if SERVER then
    hook.Add("InitPostEntity", "P11.WepReport", function()
        timer.Simple(3, function()
            local eft, fb = 0, 0
            local seen = {}
            for jobId, job in pairs(P11FW.Jobs or {}) do
                for _, entry in ipairs(job.weapons or {}) do
                    -- какой из EFT-кандидатов хотели, что получили
                    local want = istable(entry) and entry[1] or entry
                    if isstring(want) and string.StartWith(want, "arc9_") then
                        local got = POLUS11.ResolveWeaponClass(entry)
                        if got and seen[want] == nil then
                            seen[want] = got or false
                            if got == want then eft = eft + 1 else fb = fb + 1 end
                        end
                    end
                end
            end
            print("============================================================")
            print("  [POLUS-11 EFT] сводка арсенала v4.8.0:")
            for want, got in pairs(seen) do
                local line
                if got == want then
                    line = "EFT OK"
                elseif got then
                    line = "ФОЛБЭК -> " .. got
                else
                    line = "НЕ ВЫДАЁТСЯ (нет классов)"
                end
                print("    " .. want .. " — " .. line)
            end
            print("  [POLUS-11 EFT] родных стволов: " .. eft
                .. ", фолбэков: " .. fb
                .. (eft == 0 and "  ← пак ARC9 EFT НЕ НАЙДЕН, бойцы со стоком" or ""))
            print("============================================================")
        end)
    end)
end
