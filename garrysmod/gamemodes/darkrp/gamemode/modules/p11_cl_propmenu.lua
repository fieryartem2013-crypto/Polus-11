-- ============================================================
--  ПОЛЮС-11 — ТОЛЬКО ВКЛАДКА «ПРОПЫ» ДЛЯ НЕ-АДМИНОВ (client)
--  v2.5. Обычным игрокам прячем все вкладки спавнменю, кроме
--  вкладки с пропами, и панель инструментов (Tools).
--  Защита в любом случае серверная (вайтлист моделей + гейты
--  спавна), это лишь визуальная чистка интерфейса — поэтому всё
--  завёрнуто в pcall и худший случай = просто видны пустые вкладки.
-- ============================================================

local PROPS_TAB = "#spawnmenu.content_tab"

local function FirstChildOfClass(root, className)
    if not IsValid(root) then return nil end
    if root.ClassName == className then return root end
    for _, c in ipairs(root:GetChildren()) do
        local found = FirstChildOfClass(c, className)
        if found then return found end
    end
    return nil
end

local function StripSpawnTabs()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:IsSuperAdmin() or ply:IsAdmin() then return end

    pcall(function()
        -- 1) разрегистрируем лишние вкладки (если их панели ещё не построены)
        local tabs = spawnmenu.GetCreationTabs and spawnmenu.GetCreationTabs() or {}
        for name in pairs(tabs) do
            if name ~= PROPS_TAB then
                tabs[name] = nil
            end
        end
    end)

    pcall(function()
        if not IsValid(g_SpawnMenu) then return end

        -- 2) уже построенное меню: закрываем все шиты, кроме «Пропы»
        local propsTitle = language.GetPhrase(PROPS_TAB)
        local sheet = FirstChildOfClass(g_SpawnMenu, "DPropertySheet")
        if IsValid(sheet) and sheet.GetItems then
            local toClose = {}
            for _, item in ipairs(sheet:GetItems()) do
                local txt = ""
                if IsValid(item.Tab) and item.Tab.GetText then
                    txt = item.Tab:GetText() or ""
                end
                if txt ~= propsTitle then
                    table.insert(toClose, item.Tab)
                end
            end
            for _, tab in ipairs(toClose) do
                pcall(function() sheet:CloseTab(tab, true) end)
            end
        end

        -- 3) прячем панель инструментов справа
        local toolMenu = FirstChildOfClass(g_SpawnMenu, "ToolMenu")
        if IsValid(toolMenu) then
            toolMenu:Remove()
        end

        if g_SpawnMenu.InvalidateLayout then
            g_SpawnMenu:InvalidateLayout(true)
        end
    end)
end

local stripped = false
hook.Add("SpawnMenuOpen", "P11.PropsOnlyTab", function()
    if stripped then return end
    stripped = true
    -- даём меню дорисоваться, потом чистим
    timer.Simple(0.25, StripSpawnTabs)
end)
