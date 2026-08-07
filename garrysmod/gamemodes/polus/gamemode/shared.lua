-- ============================================================
--  POLUS-11 RP — ГЕЙММОД (shared) — сборка 4.0 (ЗАТ, «КАССА СТАНЦИИ»)
--  Единая сборка: ПОЛЮС FRAMEWORK v1.9 + ПОЛЮС-11 v3.2
--  (Нечто, заражение, энергия, рация, кровь, задачи, холод,
--  профессии, F4, модерация по рангам v1.9, C-меню, 3-е лицо F2,
--  авто-сид пресетов РККА/НКВД/Наука/Нечто).
--  Стоковый контент HL2/GMod — воркшоп необязателен
--  (паки моделей подключаются через P11FW.Config.WorkshopAddons).
--  Ошибки загрузки смотри в консоли: [POLUS][ERROR]
-- ============================================================

GM.Name    = "POLUS-11 RP"
GM.Author  = "POLUS-11 Dev"
GM.Email   = ""
GM.Website = "https://github.com/fieryartem2013-crypto/polus-11"

DeriveGamemode("sandbox")

-- версии (в аддон-версии лежали в autorun-загрузчиках)
P11FW = P11FW or {}
P11FW.Version = "2.0.0"

POLUS11 = POLUS11 or {}
POLUS11.Version = "3.2"

--[[ 4.8.3 — «ПОГЛОЩЕНИЕ»: реворк Нечто (авто-съедение, R-меню мутаций) ]]--
--[[ 4.8.4 — «ВЫСАДКА»: чат «ПУЛЬТ» (вырезан в 4.8.6) + спавн-рубеж с куб-маркерами ]]--
--[[ 4.8.5 — «КРАСНЫЙ ОРЁЛ»: кейс маскировки «ЛЕГАТ» + отряд шпионов ЦРУ ]]--
POLUS_BUILD = "4.9.2" -- версия сборки (v4.9.2 «ПРИЁМ»: СПАВН-ТОЧКИ — постановка стала дурацко-простой: `p11_arrival here` (своя профа+фракция под ноги) и `p11_arrival all` (ВСЕ фракции+профы за раз), `p11_arrival job` принимает имя профы куском («мед», «пулем»), после любой записи — чтение назад из JSON и громкий ✓/✗ вердикт • РАЦИЯ-ГОЛОС: рация выдана всей науке (мигр. radioV492) + `p11_voiceradio` — самопроверка (рация в снаряге? канал? сколько слышит) — корень «эфир молчит» обычно в отсутствии рации у стороны • ЧАТ: полоса-переключатель каналов над BonChat (РЕЧЬ/OOC/LOOC/РАЦИЯ/РЕПОРТ/ШЁПОТ/КРИК/ME/IT) — клик ставит префикс, JS-скальпель срезает старый, текст цел • ДОНАТ-МОСТ `p11_donorvip` для CraftedStore/EasyDonate: онлайн — VIP сразу, оффлайн — очередь до входа (donor_queue.json); пошаговая инструкция CraftedStore — docs/DONATE.md. Прошлая v4.9.1 «ИГЛА»: кадрово-медицинский пак по заявке: ПУЛЕМЁТЧИК РККА с самодостаточным скриптовым РПД (диск 75, ~620 в/м, паков не просит) • порядок должностей: медсёстры подняты, ГЕНЕРАЛЫ — последние в блоке РККА • шприц теста крови — ВСЯ научная фракция (держать/забор/стол), медсёстры снова носатели и ЛЕЧАТ им (ПКМ; починено «не хилит за медсестру» — роль медика раньше не считала медсестёр) • новый стол «АНАЛИЗАТОР КРОВИ «КРОВЬ-2» с чистого листа: E с колбой → миниигра калибровки (3 цикла, нужно ≥60%), вердикт видит только тестирующий, заражённый может ПОДМЕНИТЬ официальный исход • новая энтити «Инъектор «УКОЛ-С» — миниигра при лечении (2 заряда, +8/+25/+40 ХП по точности попадания в вену) в меню Энтити и в ларьке • ларёк обновлён: +РПД/+медкейс/+УКОЛ-С и цены подняты (инфляция полярной зимы) • авто-АВАРИЯ энергосистемы генератора ВЫРЕЗАНА (топливо/ремонт остались; вернуть: GEN_AUTOCRASH=true в generator/init.lua). Прошлая v4.9.0 «ТАЛОН»: ПРОМОКОДЫ в донат-меню — поле «ТАЛОН НАГРАДЫ» в F6, пути ввода чат «!промо КОД» и консоль «p11_promo КОД», три талона с приколами из коробки: «ПУРГА» +25 000₽, «ПОЛЯРНИК» золотой VIP (уведомление всей станции, повторникам — конверсия в 8 000₽), «ПАЁК82» сухпаёк (+5 000₽/броня/хил+анекдот); код погашается ОДИН раз на SteamID (сейв polus11/promos_used.json), одинаковый отказ «талон не принят» против перебора, текучесть 1.5 сек + карантин 5 мин после 8 промахов, каталог кодов только Главе — p11_promolist; p11_promo занесён в PUBLIC замка консоли, «!промо» — в белый список чат-ядра. Автопродажа реальных денег осознанно НЕ вшита: платежи идут через донат-сервис (EasyDonate/CraftedStore/Tebex) — карт в коде не бывает. Прошлая v4.8.9 «МАЯК»: СПАВН добит — выбор точки вынесен в ПРЯМОЙ оверрайд GM:PlayerSelectSpawn (не зависим от hook в твоей сборке), безусловная страховка 0-тик пишет в консоль КУДА спавнит каждый боец, загрузочная диагностика «точек: общий/фракций/проф» с подсказкой команды расстановки, p11_spawntest — прогон себя на точку за 2 сек. Прошлая v4.8.8 «ЛИЧИНА»: НЕЧТО переписано с нуля — ядро «ЛИЧИНА 2.0» (автопоглощение+автомаскировка после убийства, мутации прямыми каналами) • КРИТ-ФИКС ДЫРЫ ДОПУСКА v4.6.6 (category/order/ВАЙТЛИСТ 20 сид-строк были в комментарии — вот откуда «ниже допуска брали выше») • [ИВЕНТ] Нечто скрыто, вакансия у кадровика теперь ВИДНА (красная плашка+баннер+напоминания) • шприц ТОЛЬКО учёному (+запрет подбора/аудит), медикам ванильный медкейс • стресс спадает • киллфид убран • лабораторный стол в Энтити всем. Прошлая v4.8.7 «ТОЧКА»: СПАВН переписан с чистого листа — ядро «ТОЧКА СБОРА 2.0»: GM:PlayerSelectSpawn ставит точку ДО первого кадра + страховка 0-тик (гонка таймеров 0.05/0.09/0.4 упразднена), приоритет арест → профа → фракция → общий → карта, консоль p11_spawncore/p11_wherespawn; кейс маскировки «ЛЕГАТ» — окно перерисовано заново БЕЗ наложений текста (лейаут курсором, перенос строк по ширине) + ЧЕТЫРЕ способа закрытия (крестик ✕ / кнопка «СВЕРНУТЬ КЕЙС» / ESC / повторный ЛКМ-R по кейсу) и авто-сворачивание после успешного грима. Прошлая v4.8.6 «НАВОДКА»: сам чат ВЫРЕЗАН → ГОТОВЫЙ BonChat (MIT © Bonyoze), адаптирован под станцию (рус. строки/плейсхолдеры с префиксами, настройки на русском); роутер каналов работает как раньше, PlayerSay-nil-фикс; аварийно bonchat_enable 0. Орёл усилен и расширен (оператор/командир/связной; все в вайтлисте кроме связного, кейсы у всех кроме связного), модели usarmy, Velociraptor диверсанту — исключение Центра; медсёстры РККА (медсестра + главная); НКВД fem-модель шефу и заму. Прошлая v4.8.5 «КРАСНЫЙ ОРЁЛ»: кейс маскировки «ЛЕГАТ» — липовой позывной/облик РККА/должность/документ (та же механика личин Нечто), отряд шпионов ЦРУ «Красный Орёл» из 3 должностей с кейсами и американским оружием 1982 (M1911A1, Colt Python, Remington 870) по аналитике в README; админ-зеркало p11_spies. Прошлая 4.8.4 «ВЫСАДКА»: СВОЙ чат «ПУЛЬТ» — выше/удобнее/ничего не теряет, железный захват фокуса + кириллица; СПАВН починен — точка ставится ГДЕ СТОИШЬ (а не по прицелу с открытым меню), куб-маркер показывает её 5 сек, анти-застревание; смена профы переносит на спавн профы/фракции/общий; на спавне — ПОЛНЫЕ ХП и броня профы со страховочной повторной выдачей) (v4.8.3 «ПОГЛОЩЕНИЕ»: реворк Нечто — убийство когтями само жрёт труп и надевает личину, R — меню мутаций (тиры, личина, формы кнопками), ПКМ — способность формы; починена выдача админ-рангов (p11_rank пропускал никого), ТАБЕЛЬ О РАНГАХ в C-меню с шпаргалкой прав по рангам, досье НКВД открывается по /досье, химсвет гаснет зримо (60 сек угасания, полка 14 на карте))

-- ============ ОБЩИЕ МОДУЛИ (shared) ============

local sh = {
    "modules/fw_sh_config.lua",   -- конфиг фреймворка
    "modules/fw_sh_jobs.lua",     -- профессии / команды
    "modules/fw_sh_factions.lua",  -- фракции (расширенные категории)
    "modules/fw_sh_ranks.lua",     -- ранги администрации (User..Глава Проекта + Faction Officer/Leader, v2.0)
    "modules/fw_sh_whitelist.lua", -- вайтлист должностей: хелперы + клиентский синк (v4.4.0)
    "modules/p11_sh_config.lua",  -- конфиг ПОЛЮС-11
    "modules/p11_sh_core.lua",    -- общая логика Нечто/заражения
    "modules/p11_sh_weapons.lua", -- v4.8.0: арсенал EFT ARC9 + стоковые фолбэки
}
for _, f in ipairs(sh) do
    local ok, err = pcall(include, f)
    if not ok then
        print("[POLUS][ERROR] " .. f .. " -> " .. tostring(err))
    end
end

-- ============ ПОВЕДЕНИЕ ПЕСОЧНИЦЫ -> RP ============

local function IsPolusAdmin(ply)
    if not (P11FW and P11FW.Config and P11FW.Config.Admin) then return false end
    if not IsValid(ply) then return false end
    return P11FW.Config.Admin(ply) and true or false
end

--- Модель игрока = модель должности (не из Q-меню).
function GM:PlayerSetModel(ply)
    if P11FW.GetJob and P11FW.ValidModels then
        local job = P11FW.GetJob(ply)
        local models = job and P11FW.ValidModels(job) or nil
        local m = models and models[1]
        if m then
            util.PrecacheModel(m)
            ply:SetModel(m)
            return
        end
    end
    self.BaseClass:PlayerSetModel(ply)
end

--- Лоадаут: фреймворк раздаёт всё сам (P11FW.ApplyLoadout
--- по хуку PlayerSpawn с задержкой 0.1 c — профессия + админ-инструменты).
function GM:PlayerLoadout(ply)
    ply:RemoveAllAmmo()
    return true
end

--- Спавн энтити/оружия/NPC и инструменты из меню — только админам.
--- (Пропы обрабатываются ОТДЕЛЬНО ниже — игрокам разрешён вайтлист;
--- станционные предметы не страдают: они создаются сервером через
--- ents.Create в командах, а не через эти хуки.)
local adminOnlyHooks = {
    "PlayerSpawnRagdoll", "PlayerSpawnEffect",
    "PlayerSpawnVehicle", "PlayerSpawnNPC",
    "PlayerSpawnSENT", "PlayerSpawnSWEP", "PlayerGiveSWEP",
    "CanTool", "CanProperty", "CanEditVariable", "CanDrive",
}
for _, hookName in ipairs(adminOnlyHooks) do
    GM[hookName] = function(self, ply)
        return IsPolusAdmin(ply)
    end
end

--- ПРОПЫ для всех: не-админам — только модели из вайтлиста
--- (POLUS11.Config.Building.AllowedProps). Дальше их призраками
--- занимается модуль p11_sv_build.lua.
function GM:PlayerSpawnProp(ply, model)
    if IsPolusAdmin(ply) then return true end
    local b = POLUS11.Config and POLUS11.Config.Building
    if not (b and b.Enabled and b.AllowedProps) then return false end
    model = string.lower(tostring(model or ""))
    if b.AllowedProps[model] then return true end
    if IsValid(ply) then
        ply:ChatPrint("[Склад] Этот предмет недоступен обычному персоналу.")
    end
    return false
end

--- Лимиты спавна: админам — без потолка, игрокам — только пропы
--- и не больше MaxPerPlayer (остальное всегда «limit reached»).
function GM:PlayerCheckLimit(ply, name, current, defaultMax)
    if IsPolusAdmin(ply) then return true end
    if name == "props" then
        local b = POLUS11.Config and POLUS11.Config.Building
        local max = (b and b.MaxPerPlayer) or 8
        if current >= max then return false end
        return true
    end
    return false
end

--- v4.8.0 «ЗОЛОТОЙ ПРОПУСК»: Q-МЕНЮ ТОЛЬКО ДЛЯ Developer+ (заявка
--- владельца: «девелоперу и выше — да, ниже люди не могут открыть»).
--- Хук клиентский (движок не передаёт игрока — берём LocalPlayer).
--- Ранг ниже порога P11FW.Config.DevMenuLevel (по умолчанию 9) — меню
--- не открывается вообще, в чат — одна подсказка раз в 2.5 сек.
P11_DevMenuDenyT = P11_DevMenuDenyT or 0
function GM:SpawnMenuOpen()
    if CLIENT then
        local ply = LocalPlayer()
        local ok = IsValid(ply) and P11FW.CanDevMenu and P11FW.CanDevMenu(ply)
        if not ok then
            if CurTime() - (P11_DevMenuDenyT or 0) > 2.5 then
                P11_DevMenuDenyT = CurTime()
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(Color(255, 185, 110), "[ПОЛЮС-11] ", Color(225, 230, 240),
                    "Q-меню закрыто для персонала: доступно с ранга Developer и выше.",
                    Color(150, 165, 185), " (порог: P11FW.Config.DevMenuLevel)")
            end
            return false
        end
    end
    return true
end
--- C-меню песочницы ЗАМЕНЕНО (v3.0): на C — станционное меню
--- жестов/действий (p11_cl_cmenu.lua). v3.8: хук ContextMenuOpen
--- больше НЕ блокирует: раньше из-за return false движок рубил ВСЮ
--- цепочку +menu_context на корню и наше меню не открывалось у части
--- билдов. Теперь ванильное окно глушится перекрытием клиентского
--- GM:OnContextMenuOpen (сам дёргает наше меню), а этот шлюз — открыт,
--- чтобы нативный путь C гарантированно доезжал до нашего меню.
--- Инструменты песочницы по-прежнему живут в Q-меню.
function GM:ContextMenuOpen(ply) return true end

--- v3.7: стандартный ТАБ песочницы ПОЛНОСТЬЮ отключён —
--- своё табло живёт в modules/p11_cl_board.lua (v2, с нуля) и само
--- реагирует на +showscores. Если только цепляться хуком,
--- sandbox-скорборд рисуется ПОВЕРХ нашего (баг «ваниль поверх»).
function GM:ScoreboardShow() return true end
function GM:ScoreboardHide() return true end

--- Ноуклип — только админам.
function GM:PlayerNoClip(ply, on)
    return IsPolusAdmin(ply)
end

--- Физган есть у всех (v2.7), но не-админ может поднимать ТОЛЬКО свои
--- призрачные пропы — чужие твёрдые, мировые и игроков нельзя.
--- Игроков вообще таскает только суперадмин.
function GM:PhysgunPickup(ply, ent)
    if not IsValid(ent) then return false end
    if IsPolusAdmin(ply) then
        if ent:IsPlayer() then return ply:IsSuperAdmin() end
        return true
    end
    if ent.P11_Ghost and ent.P11_GhostOwner == ply then return true end
    return false
end

--- Фонарик разрешён всем — на тёмной станции это базовая потребность.
function GM:PlayerSwitchFlashlight(ply, on)
    if not IsValid(ply) then return false end
    return true
end

--- v4.8.1: 3D-ГОЛОС («ЭФИР»). Гейммод-уровень намеренно молчит (nil) ---
--- решение всегда за хуком p11_sv_voice.lua (местная речь с затуханием,
--- рация эфирным линком, буря глушит только эфир, мёртвые не говорят).
function GM:PlayerCanHearPlayersVoice(listener, talker)
    return nil
end

--- v4.8.2: движковые строки команд «!» видит ТОЛЬКО автор.
--- Client-команды (!смена / !пульт / !меню) обязаны пройти через
--- движок до OnPlayerChat отправителя, иначе кнопка не сработает;
--- но всем остальным эта техническая строка со steam-ником не нужна
--- (базовый гейммод тут возвращает true — перекрываем осознанно).
function GM:PlayerCanSeePlayersChat(text, teamOnly, listener, speaker)
    if IsValid(speaker) then
        local t = string.Trim(tostring(text or ""))
        -- «!»-команды и клиентская «/меню» — только автору,
        -- остальным эта техническая строка не нужна
        local lt = string.lower(t)
        -- v4.8.3: клиентские «/меню» и «/досье» — тоже только автору
        local selfSlash = (lt == "/меню" or lt == "/досье" or lt == "/dossier"
            or string.StartWith(lt, "/досье "))
        if string.StartWith(t, "!") or selfSlash then
            return listener == speaker
        end
    end
    if teamOnly and IsValid(listener) and IsValid(speaker) then
        return listener:Team() == speaker:Team()
    end
    return true
end

--- Суицид запрещён арестованным/рабам (обход наказания).
function GM:CanPlayerSuicide(ply)
    if not IsValid(ply) then return false end
    local pun = ply:GetNWString("P11FW_Punish", "")
    if pun == "arrest" or pun == "slavery" then return false end
    return true
end

-- ============================================================
--  v3.8.1: ТЕМП СТАНЦИИ И АНТИ-БАННИХОП (shared для предсказания)
--  Ходьба медленнее, разбег скромнее, прыжок ниже, а набранный по
--  бхоп-цепочке импульс гасится при приземлении (скорость в полёте
--  > разбега → обрезается до разбега ×1.1). Величины — в
--  POLUS11.Config.Movement (модули их же используют).
-- ============================================================

local function MoveCfg()
    local m = POLUS11.Config and POLUS11.Config.Movement or nil
    return (m and m.walk) or 170, (m and m.run) or 330,
           (m and m.jump) or 120, (m and m.antiBhop ~= false)
end

function POLUS11.ApplyMoveSpeeds(ply)
    if not IsValid(ply) then return end
    local w, r, j = MoveCfg()
    ply:SetWalkSpeed(w)
    ply:SetRunSpeed(r)
    ply:SetJumpPower(j)
end

hook.Add("PlayerSpawn", "P11.MoveSpeeds", function(ply)
    -- после фреймворковского лоадаута, чтобы поверх не перетёрли
    timer.Simple(0.15, function()
        if IsValid(ply) and ply:Alive() then POLUS11.ApplyMoveSpeeds(ply) end
    end)
end)

hook.Add("OnPlayerHitGround", "P11.AntiBhop", function(ply, inWater, onFloater)
    if inWater or onFloater then return end
    local _, r, _, allow = MoveCfg()
    if not allow then return end
    local v = ply:GetVelocity()
    local h = math.sqrt(v.x * v.x + v.y * v.y)
    local cap = r * 1.1
    if h > cap then
        -- обрезка горизонтали до разбега (цепочка прыжков «честная»)
        local k = cap / h
        ply:SetVelocity(Vector(-v.x * (1 - k), -v.y * (1 - k), 0))
    end
end)
