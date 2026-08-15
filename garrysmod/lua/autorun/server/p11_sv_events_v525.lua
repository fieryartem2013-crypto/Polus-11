-- ============================================================
--  ПОЛЮС-11 — ПРОЦЕДУРНЫЕ ПРОИСШЕСТВИЯ (server) v5.2.5 (НОВЫЙ ФАЙЛ)
--  Владелец (из аналитики, идея №3): «каждые 20–40 минут случайное
--  событие: обрыв связи, замыкание, сигнал с поверхности, пропажа
--  припасов, крик в вентиляции. Разнообразит смену без админа».
--
--  Реализация: таймер (первый ~10–15 мин, дальше 20–40 мин),
--  случайное событие → плашка-анонс всей станции (P11_Announce,
--  готовая труба «РЕПРОДУКТОРА») + звук тревоги + иногда эффект
--  (блэкаут через POLUS11.SetBlackout). Участвующим (онлайн на
--  станции) капают жетоны ярмарки 🎫 через POLUS11.EVGiveAll
--  (модуль ивент-магазина; если его нет — просто анонс).
--  Старые файлы НЕ трогаем — всё в autorun/server.
-- ============================================================

local function Announce(txt)
    net.Start("P11_Announce")
        net.WriteString(txt)
        net.WriteString("ПРОИСШЕСТВИЕ")
    net.Broadcast()
end

local function Siren()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            p:EmitSound("ambient/alarms/warningbell1.wav", 75, 100)
        end
    end
end

local function Reward(amount)
    timer.Simple(5, function()
        if POLUS11 and POLUS11.EVGiveAll then
            POLUS11.EVGiveAll(amount or 2, "участие в происшествии")
        end
    end)
end

-- ============ ПУЛ СОБЫТИЙ ============

local EVENTS = {
    {
        name = "ОБРЫВ СВЯЗИ",
        txt = "⚠ СВЯЗЬ С ЦЕНТРОМ ПРЕРВАНА. Рации трещат помехами, радист не может достучаться до Большой Земли. Соблюдайте спокойствие, продолжайте смену.",
        fn = function() end, -- только анонс
    },
    {
        name = "ЗАМЫКАНИЕ",
        txt = "⚡ ЗАМЫКАНИЕ В ЭНЕРГОСЕТИ! Свет моргает, часть систем уходит в резерв. Электрики — проверьте щиты, остальные — не паникуйте.",
        fn = function()
            if POLUS11 and POLUS11.SetBlackout then
                POLUS11.SetBlackout(true)
                timer.Simple(20, function()
                    if POLUS11 and POLUS11.SetBlackout then POLUS11.SetBlackout(false) end
                end)
            end
        end,
    },
    {
        name = "СИГНАЛ С ПОВЕРХНОСТИ",
        txt = "📡 НА ПУЛЬТ ПРИШЁЛ СИГНАЛ С ПОВЕРХНОСТИ — код «ГРОМ». До проверки никого наверх не пускать. Это может быть помеха… или нет.",
        fn = function() end,
    },
    {
        name = "ПРОПАЖА ПРИПАСОВ",
        txt = "📦 НА СКЛАДЕ НЕДОСТАЧА: ящик сухпайка и канистра солярки. Интендант просит всех проверить свои секции и доложить НКВД о подозрительном.",
        fn = function() end,
    },
    {
        name = "КРИК В ВЕНТИЛЯЦИИ",
        txt = "📢 КРИК В ВЕНТИЛЯЦИИ! Похоже на человеческий. Патрульные — проверьте решётки, остальные — держитесь группами и не открывайте люки.",
        fn = function() end,
    },
    {
        name = "ДАВЛЕНИЕ ПАДАЕТ",
        txt = "🌬 ДАВЛЕНИЕ ВОЗДУХА ПАДАЕТ НА 3%. Проверьте герметичность шлюзов и наружных дверей. Кто последний был на поверхности?",
        fn = function() end,
    },
    {
        name = "АНОМАЛЬНАЯ ТЕМПЕРАТУРА",
        txt = "🌡 В КОРИДОРЕ Б-7 ДАТЧИКИ ПОКАЗЫВАЮТ +40°C. Там должно быть −20°C. Источник тепла неизвестен. Учёные — проверьте.",
        fn = function() end,
    },
}

-- ============ ТАЙМЕР: ПЕРВЫЙ ~10–15 МИН, ДАЛЬШЕ 20–40 МИН ============

local function ScheduleNext()
    local first = not POLUS11.EV_Started
    POLUS11.EV_Started = true
    local delay = first and math.random(600, 900) or math.random(1200, 2400) -- 10–15 мин / 20–40 мин
    timer.Create("P11.Events", delay, 1, function()
        local ev = EVENTS[math.random(#EVENTS)]
        if ev then
            Siren()
            timer.Simple(0.8, function()
                Announce(ev.txt)
                if ev.fn then pcall(ev.fn) end
                Reward(2)
            end)
        end
        ScheduleNext()
    end)
end

hook.Add("InitPostEntity", "P11.EventsStart", function()
    timer.Simple(math.random(600, 900), function()
        local ev = EVENTS[math.random(#EVENTS)]
        if ev then
            Siren()
            timer.Simple(0.8, function()
                Announce(ev.txt)
                if ev.fn then pcall(ev.fn) end
                Reward(2)
            end)
        end
        ScheduleNext()
    end)
end)

-- ручной запуск (админ/ивент): p11_event <номер 1..7> или случайно
concommand.Add("p11_event", function(ply, _, args)
    if IsValid(ply) then return end -- только консоль сервера
    local n = tonumber(args[1] or "")
    local ev = (n and EVENTS[n]) or EVENTS[math.random(#EVENTS)]
    if ev then
        Siren()
        timer.Simple(0.8, function()
            Announce(ev.txt)
            if ev.fn then pcall(ev.fn) end
            Reward(2)
        end)
    end
end)

print("[POLUS-11] ПРОИСШЕСТВИЯ v5.2.5 (server, autorun): 7 событий, каждые 20–40 мин, жетоны участникам")
