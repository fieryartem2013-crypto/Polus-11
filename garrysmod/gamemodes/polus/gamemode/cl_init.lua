-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (client bootstrap)
-- ============================================================

include("shared.lua")

local cl = {
    "modules/fw_cl_f4.lua",        -- F4-меню профессий
    "modules/fw_cl_punish.lua",    -- красный плакат наказания
    "modules/fw_cl_admin.lua",     -- админ-меню P11FW
    "modules/p11_cl_hud.lua",      -- HUD станции (фазы, улей, тест крови)
    "modules/p11_cl_vitals.lua",   -- HUD жизни: HP / броня / патроны / тосты
    "modules/p11_cl_admin.lua",    -- пульт Нечто (клиент)
    "modules/p11_cl_board.lua",      -- TAB v2 «состав станции»: ноль vgui, не падает (v4.2.1)
    "modules/p11_cl_nametags.lua", -- ники/должности над головами
    "modules/p11_cl_tasks.lua",    -- виджет задач
    "modules/p11_cl_panic.lua",    -- эффекты паники
    "modules/p11_cl_propmenu.lua", -- только вкладка «Пропы» не-админам
    "modules/p11_cl_thinghud.lua", -- HUD Нечто (форма/маскировка/кулдауны)
    "modules/p11_cl_intro.lua",    -- интро-заставка станции
    "modules/p11_cl_terminal.lua", -- меню сменного терминала
    "modules/p11_cl_uistyle.lua",  -- фирменный стиль UI (v4.1)
    "modules/p11_cl_help.lua",     -- F1-справка новичка
    "modules/p11_cl_alerts.lua",   -- приказ-баннер / метель / розыск / распорядок
    "modules/p11_cl_view.lua",     -- F2 третье лицо / F3 курсор / голос-панели (v3.8)
    "modules/p11_cl_chat.lua",     -- свой чат-UI: каналы РЕЧЬ/OOC/LOOC/ME/IT/РЕПОРТ (v4.5.0)
    "modules/p11_cl_arrival.lua",  -- заставка прибытия колонны (v4.5.0)
    "modules/p11_cl_cmenu.lua",    -- C-меню: жесты / действия (v4.4.0 — реворк с нуля)
    "modules/p11_cl_models.lua",   -- браузер внешности (v4.4.0 — с нуля)
    "modules/p11_cl_spawnmenu.lua", -- экран вербовки: выбор фракции и профессии при спавне (v4.6.0)
    "modules/p11_cl_economy.lua",  -- рубли на HUD / инвентарь / ларёк / сейф / расстановка (v4.0)
    "modules/p11_cl_minigame.lua", -- миниигры дел + патрульные маркеры + RP (v4.1)
    "modules/p11_cl_duties2.lua",   -- заявки грузчика / досье НКВД (v4.2)
    "modules/p11_cl_mutations.lua", -- HUD мутаций Нечто (v4.2)
    "modules/p11_cl_tutorial.lua",  -- туториал новичка: маяки и подсказки (v4.2)
    "modules/p11_cl_chars.lua",     -- анкета бойца (v4.3.0)
}

local loaded = 0
for _, f in ipairs(cl) do
    local ok, err = pcall(include, f)
    if ok then
        loaded = loaded + 1
    else
        print("[POLUS][ERROR] " .. f .. " -> " .. tostring(err))
    end
end

-- скрываем стандартный HL2-HUD (у станции свой HUD)
local hidden = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudDamageIndicator = true,
    CHudSuitPower = true,
}
hook.Add("HUDShouldDraw", "P11GM.HideDefaultHUD", function(name)
    if hidden[name] then return false end
end)

print("[POLUS-11 RP v" .. tostring(POLUS_BUILD) .. "] Клиент: "
    .. loaded .. "/" .. #cl .. " модулей. F4 — должности, TAB — состав.")

-- ============================================================
--  ГЛОБАЛЬНЫЙ ФИКС: dscrollpanel.lua:111 "Tried to use a NULL Panel!"
--  Известный баг движка: DScrollPanel:PerformLayoutInternal() трогает
--  канвас, когда тот уже удалён (быстрое пересоздание меню — F4,
--  админка, терминал, TAB). Ловим на корню: храним ссылку на канвас
--  после СОЗДАНИЯ панели (раньше срабатывало GetCanvas()=nil из-за
--  скрытого удаления в момент ParentToHUD) и проверяем IsValid.
-- ============================================================
timer.Simple(0, function() -- ждём, пока загрузятся стандартные контролы
    local SP = vgui.GetControlTable and vgui.GetControlTable("DScrollPanel")
    if not SP or SP.P11NullFixed then return end
    SP.P11NullFixed = true

    -- 1) если канвас вдруг помер (быстрое пересоздание меню) —
    --    пересоздаём его тихо, а не падаем в PerformLayoutInternal
    local oldGetCanvas = SP.GetCanvas
    SP.GetCanvas = function(self)
        if not IsValid(self.pnlCanvas) then
            self.pnlCanvas = vgui.Create("Panel", self)
            self.pnlCanvas.OnMousePressed = function() end
            self.pnlCanvas:SetPaintBackground(false)
        end
        return self.pnlCanvas
    end

    -- 2) оригинальную раскладку оборачиваем в pcall: даже если что-то
    --    ещё сломалось внутри — кадр визуально пропускаем, не спамим ошибку
    local oldLayout = SP.PerformLayoutInternal
    SP.PerformLayoutInternal = function(self, w, h)
        if not IsValid(self:GetCanvas()) then return end
        if not IsValid(self.VBar) then return oldLayout(self, w, h) end
        local ok = pcall(oldLayout, self, w, h)
        if not ok and not SP.P11Warned then
            SP.P11Warned = true
            print("[P11] DScrollPanel layout guarded (один пропущенный кадр, это норма при пересоздании меню)")
        end
    end

    -- 3) OnVScroll тоже дергает канвас
    local oldV = SP.OnVScroll
    SP.OnVScroll = function(self, i)
        if not IsValid(self:GetCanvas()) then return end
        oldV(self, i)
    end
end)
