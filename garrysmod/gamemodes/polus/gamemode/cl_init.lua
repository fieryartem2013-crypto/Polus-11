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
    "modules/p11_cl_chat.lua",     -- v9 «ЭФИР»: пульт вырезан, каналы — через ГОТОВЫЙ BonChat (v4.8.6)
    "modules/p11_cl_arrival.lua",  -- заставка прибытия колонны (v4.5.0)
    "modules/p11_cl_cmenu.lua",    -- C-меню: жесты / действия (v4.4.0 — реворк с нуля)
    "modules/p11_cl_models.lua",   -- браузер внешности (v4.4.0 — с нуля)
    "modules/p11_cl_economy.lua",  -- рубли на HUD / инвентарь / ларёк / сейф / расстановка (v4.0; v4.6.9 — броня+диаг)
    "modules/p11_cl_trade.lua",    -- окно обмена игрок↔игрок + выбор партнёра (v4.6.9)
    "modules/p11_cl_minigame.lua", -- миниигры дел + RP (v4.1; v4.19.5: патруль вырезан)
    "modules/p11_cl_duties2.lua",   -- заявки грузчика / досье НКВД (v4.2)
    "modules/p11_cl_mutations.lua", -- HUD мутаций Нечто (v4.2)
    "modules/p11_cl_tutorial.lua",  -- туториал новичка: маяки и подсказки (v4.2)
    "modules/p11_cl_chars.lua",     -- анкета бойца (v4.3.0)
    "modules/p11_cl_donate.lua",    -- v4.8.0: F6 — донат-витрина (плейсхолдер)
    "modules/p11_cl_offer.lua",     -- v4.8.1: особая вакансия — маркер над кадровиком + баннер
    "modules/p11_cl_reports.lua",   -- v4.8.2 «ДОКЛАД»: окно репортов (принять/тп/закрыть)
    "modules/p11_cl_spawnviz.lua",  -- v4.8.4 «ВЫСАДКА»: куб-маркеры точек спавна
    "modules/p11_cl_disguise.lua",  -- v4.8.5 «КРАСНЫЙ ОРЁЛ»: окно кейса маскировки «ЛЕГАТ»
    "modules/p11_cl_thingoffer.lua",-- v4.8.8 «ЛИЧИНА»: красная плашка «особой вакансии» над кадровиком
    "modules/p11_cl_minigames2.lua",-- v4.9.1 «ИГЛА»: стрелка-ползунок — «КРОВЬ-2» и «УКОЛ-С» + окно вердикта
    "modules/p11_cl_chatsel.lua",   -- v4.9.2 «ПРИЁМ»: полоса выбора канала над BonChat (РЕЧЬ/OOC/РАЦИЯ/РЕПОРТ…)
    "modules/p11_sh_bonchatboot.lua", -- v4.8.6 «НАВОДКА»: готовый чат BonChat (MIT) — клиентская база
    "modules/p11_cl_garage.lua",      -- v4.10.0 «ГАРАЖ»: витрина «ПОЛЮС-АВТО» (транспорт LVS)
    "modules/p11_cl_craft.lua",       -- v4.10.0 «ГАРАЖ»: кустарная мастерская (крафт)
    "modules/p11_cl_utility.lua",     -- v4.10.0 «ГАРАЖ»: утилиты выдачи ПОЛЮС-ФЛЮКСА (rank 4+)
    "modules/p11_cl_poi.lua",         -- v4.10.0 «ГАРАЖ»: маяки «куда идти»
    "modules/p11_cl_thingkit.lua",    -- v4.10.0 «ГАРАЖ»: пульт тела Нечто «ЛИЧИНА 3.0» (после cl_mutations!)
    "modules/p11_cl_kazna.lua",       -- v4.14.2 «КАЗНА»: окно-ростер казны (💠 ПФ/₽/⏱) — p11_kazna
    "modules/p11_cl_capture.lua",     -- v4.16.0 «ЗАХВАТ»: HUD точки захвата (до pchat — он всегда последний)
    "modules/p11_cl_medals.lua",      -- v4.19.4 «ПОЧЁТ»: медали — надголовье, ТАБ, окно вручения
    "modules/p11_cl_contracts.lua",   -- v4.19.4 «ПОЧЁТ»: нарядник — окно + HUD-виджет
    "modules/p11_cl_sanity.lua",      -- v4.19.4 «ПОЧЁТ»: рассудок — индикатор + хоррор-слой
    "modules/p11_cl_clues.lua",       -- v4.20.0 «СЛЕД»: планшет-досье улик НКВД по !улики
    "modules/p11_cl_onboard.lua",     -- v4.20.0 «СЛЕД»: плашка «ПЕРВЫЙ ДЕНЬ» (NWInt)
    "modules/p11_cl_raceweek.lua",    -- v4.20.0 «СЛЕД»: полоска «ЛЕДОКОЛ» РККА vs ОРЁЛ
    "modules/p11_cl_skilltree.lua",   -- v4.21.0 «ДРЕВО»: окно древа службы из C-меню
    "modules/p11_cl_pchat.lua",       -- v4.14.0 «СВЯЗЬ»: СВОЙ чат станции (заявка «сделай сам свой кастомный чат») — ВСЕГДА ПОСЛЕДНИЙ (его net.Receive побеждает)
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
