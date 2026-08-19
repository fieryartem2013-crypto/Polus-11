-- ============================================================
--  ПОЛЮС-11 — ЧЕРТЕЖИ ОРУЖИЯ ДЛЯ КРАФТА v5.8.21 (server, autorun)
--  Заявка: «чертежи оружия для крафта».
--  Чертежи — новые предметы в ларьке (категория материалов):
--    • Чертёж «АК-74»      (blueprint_ak)      5 000₽
--    • Чертёж «СВД Драгунова» (blueprint_svd)  7 000₽
--    • Чертёж «РПК-16»     (blueprint_rpk16)   8 000₽
--    • Чертёж «Кустарный огнемёт» (blueprint_flamer) 4 000₽
--  Рецепты на верстаке (!!!крафт): чертёж + материалы → оружие
--  в инвентарь (оттуда «ИСПОЛЬЗОВАТЬ» → в руки).
--  Нужен ARC9-пак для EFT-стволов (как у всех EFT-проф);
--  без пака сервер честно скажет «не собрать».
--  Старые файлы не трогаем — всё в рантайме после загрузки.
-- ============================================================

local BLUEPRINTS = {
    blueprint_ak     = { name = "Чертёж «АК-74»",        price = 5000,
        desc = "Схема сборки АК-74 из лома и запчастей. Верстак: !крафт." },
    blueprint_svd    = { name = "Чертёж «СВД Драгунова»",price = 7000,
        desc = "Снайперская схема: оптика, ствол, терпение. Верстак: !крафт." },
    blueprint_rpk16  = { name = "Чертёж «РПК-16»",       price = 8000,
        desc = "Ручной пулемёт по бумажке. Дорого, но пуля — дешевле жизни." },
    blueprint_flamer = { name = "Чертёж «Кустарный огнемёт»", price = 4000,
        desc = "Главный чертёж станции: соляра → струя огня против Нечто." },
}

local RECIPES = {
    craft_ak = {
        name = "АК-74 (по чертежу)",
        give = "ak74",
        -- v5.8.22: крафт усложнён (чертёж + много материалов + патроны)
        needs = { blueprint_ak = 1, scrap = 6, parts = 4, spirit = 3, fuel = 1 },
        desc = "Чертёж + много лома/запчастей/спирта/соляры. Долгая сборка.",
    },
    craft_svd = {
        name = "СВД «Драгунова» (по чертежу)",
        give = "svd",
        needs = { blueprint_svd = 1, scrap = 8, parts = 6, spirit = 4, fuel = 2, cloth = 2 },
        desc = "Снайперская по чертежу: оптика, ствол, терпение, материалы.",
    },
    craft_rpk16 = {
        name = "РПК-16 (по чертежу)",
        give = "rpk16",
        needs = { blueprint_rpk16 = 1, scrap = 10, parts = 6, fuel = 3, spirit = 2, cons = 2 },
        desc = "Пулемёт из бумаги и тонны металла.",
    },
    craft_flamer2 = {
        name = "Кустарный огнемёт (по чертежу)",
        give = "flamer",
        needs = { blueprint_flamer = 1, fuel = 5, parts = 4, scrap = 4, spirit = 2 },
        desc = "Чертёж огнемёта: много соляры, запчастей, лома.",
    },
}

local function Install()
    -- предметы в каталог ларька (материалы)
    if POLUS11.Items then
        for id, it in pairs(BLUEPRINTS) do
            if not POLUS11.Items[id] then
                POLUS11.Items[id] = {
                    name = it.name, price = it.price,
                    mat = true, -- материал мастерской: в руки не применяется
                    desc = it.desc,
                }
            end
        end
    end
    -- рецепты на верстак
    if POLUS11.Crafts then
        for id, rc in pairs(RECIPES) do
            if not POLUS11.Crafts[id] then
                POLUS11.Crafts[id] = rc
            end
        end
    end
    -- материалы для подписей в клиенте мастерской
    if POLUS11.CraftMats then
        for id in pairs(BLUEPRINTS) do
            local found = false
            for _, m in ipairs(POLUS11.CraftMats) do
                if m == id then found = true break end
            end
            if not found then POLUS11.CraftMats[#POLUS11.CraftMats + 1] = id end
        end
    end
    print("[POLUS-11] ЧЕРТЕЖИ v5.8.21: добавлено предметов " .. table.Count(BLUEPRINTS)
        .. ", рецептов " .. table.Count(RECIPES) .. " (верстак: !крафт)")
end

hook.Add("InitPostEntity", "P11.Blueprints.Start", function()
    timer.Simple(4, Install) -- после ларька/крафта
end)
hook.Add("PostCleanupMap", "P11.Blueprints.Map", function()
    timer.Simple(4, Install)
end)
