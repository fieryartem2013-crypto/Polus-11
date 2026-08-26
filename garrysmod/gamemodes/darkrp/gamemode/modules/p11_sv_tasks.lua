-- ============================================================
--  ПОЛЮС-11 — ЗАДАЧИЯ СМЕНЫ (сервер)
--  У каждой должности свой список дел на смену. Прогресс
--  летит на клиент (HUD слева). Выполнил всё — премия и
--  объявление на станцию. Требует ПОЛЮС FRAMEWORK (без
--  профессий задач нет).
-- ============================================================

util.AddNetworkString("P11_TaskSync")
util.AddNetworkString("P11_FearFX")

-- ============ СПИСКИ ЗАДАЧ (по jobId фреймворка) ============
-- time = задача-таймер: прогресс растёт сам (секунды жизни)

POLUS11.TaskDefs = {

    -- v4.12.0 «ОТБОЙ»: генераторов больше НЕТ (вырезаны из игры) — дела смены
    -- перевязаны на новые оси: ОБЫСК лутниц (loot_find) и ВЕРСТАК (craft_do).
    engineer = {
        { key = "craft_do",  name = "Собери изделия на верстаке (×3)", max = 3 },
        { key = "loot_find", name = "Обыщи ящики/бочки станции (×3)", max = 3 },
        { key = "alive",     name = "Дежурство: 5 мин без смерти", max = 300, time = true },
    },

    -- ============ v3.7: задачи новых должностей ============

    porter = {
        { key = "haul",      name = "Перетаскивай грузы (бочки на плече)", max = 4 },
        { key = "loot_find", name = "Притащи добычу из лутниц (×2)", max = 2 },
        { key = "alive",     name = "Смена на складе: 5 мин без смерти", max = 300, time = true },
    },

    -- ТЕХНИК-МЕХАНИК (заявка «дай новые задачи механику»):
    -- машинное закрыто, работа руками — верстак и запчасти с полей.
    tech = {
        { key = "craft_do",  name = "ТО станции: собери на верстаке (×3)", max = 3 },
        { key = "loot_find", name = "Добудь запчасти из лутниц (×2)", max = 2 },
        { key = "alive",     name = "Дежурство механика: 5 мин", max = 300, time = true },
    },

    medic = {
        { key = "heal_player", name = "Обработай раненых (ПКМ шприца)", max = 3 },
        { key = "blood_draw",  name = "Возьми образцы крови", max = 1 },
        { key = "alive",       name = "Дежурство в медблоке: 5 мин", max = 300, time = true },
    },

    -- v3.9: старые встроенные (Вирусолог/Офицер/Охрана/Лаборант) УБРАНЫ,
    -- их дела уехали в категорийные пулы ниже (POLUS11.CategoryTaskDefs).

    janitor = {
        { key = "craft_do",  name = "Собери хозмелочь на верстаке", max = 1 },
        { key = "loot_find", name = "Обыщи лутницу — пригодится что угодно", max = 1 },
        { key = "alive",     name = "Неуловимая спина со шваброй: 5 мин", max = 300, time = true },
    },

    cook = {
        { key = "fed",       name = "Накорми экипаж (разные люди)", max = 3 },
        { key = "loot_find", name = "Обыщи ящик — вдруг попадётся тушёнка", max = 1 },
        { key = "alive",     name = "Камбуз жив: 5 мин без смерти", max = 300, time = true },
    },

    recruit = {
        { key = "job_taken", name = "Получи назначение у кадровика/F4", max = 1 },
        { key = "alive",     name = "Осмотрись на станции: 5 мин", max = 300, time = true },
    },
}

-- ============ v3.9: ПУЛЫ ЗАДАЧ ПО ФРАКЦИЯМ (фолбэк) ============
-- Если у должности нет своего пула (сид-профы РККА/НКВД/Учёные,
-- кастомы админки) — выдаём дела по её фракции.
POLUS11.CategoryTaskDefs = {
    rkka = {
        { key = "damage_thing", name = "Нанеси урона Нечто", max = 150 },
        { key = "radio",        name = "Доложи в рацию (×3)", max = 3 },
        { key = "alive",        name = "Пост РККА: 10 мин без смерти", max = 600, time = true },
    },
    nkvd = {
        { key = "arrest", name = "Задержи подозреваемого (арест)", max = 1 },
        { key = "radio",  name = "Секретный доклад в эфир (×2)", max = 2 },
        { key = "alive",  name = "Наружка: 10 мин в тени событий", max = 600, time = true },
    },
    science = {
        { key = "calibrate",  name = "Откалибруй анализатор (E по столу)", max = 2 },
        { key = "blood_draw", name = "Возьми образцы крови у экипажа", max = 2 },
        { key = "blood_test", name = "Проведи тест крови на столе", max = 1 },
        { key = "alive",      name = "Дежурство в лаборатории: 5 мин", max = 300, time = true },
    },
    personnel = {
        { key = "clean",     name = "Убери грязь на станции (×2)", max = 2 },
        { key = "loot_find", name = "Обыщи ящик или бочку станции (×1)", max = 1 },
        { key = "alive",     name = "Хозработы: 5 мин без происшествий", max = 300, time = true },
    },
}

-- ============ API ============

function POLUS11.AssignTasks(ply)
    ply.P11_Tasks = nil
    if not POLUS11.Config.Tasks then return end
    if not P11FW then return end

    local jobId = P11FW.GetJobId(ply)
    local defs = POLUS11.TaskDefs[jobId]
    if not defs then
        -- v3.9: фолбэк на пул ФРАКЦИИ должности
        local job = P11FW.Jobs and P11FW.Jobs[jobId] or nil
        local catId = (job and (job.faction or job.category)) or "misc"
        defs = POLUS11.CategoryTaskDefs[catId]
    end
    if not defs then
        POLUS11.SyncTasks(ply)
        return
    end

    ply.P11_Tasks = {}
    for i, d in ipairs(defs) do
        ply.P11_Tasks[i] = { key = d.key, name = d.name, max = d.max, cur = 0, time = d.time, done = false }
    end
    POLUS11.SyncTasks(ply)
end

function POLUS11.SyncTasks(ply)
    if not IsValid(ply) then return end
    local rows = {}
    for _, t in ipairs(ply.P11_Tasks or {}) do
        rows[#rows + 1] = { name = t.name, cur = math.floor(t.cur), max = t.max, done = t.done }
    end
    -- v2.9: ложные задачи «прикрытия» замаскированного Нечто —
    -- выглядят ТОЧНО как обычные дела (в том и смысл лжи)
    for _, t in ipairs(ply.P11_FakeTasks or {}) do
        rows[#rows + 1] = { name = t.name, cur = math.floor(t.cur), max = t.max, done = t.done }
    end
    -- v2.7: назначенные через терминал доп-задачи — отдельной секцией
    for _, t in ipairs(ply.P11_XTasks or {}) do
        rows[#rows + 1] = { name = t.name, cur = math.floor(t.cur), max = t.max, done = t.done, extra = true }
    end
    net.Start("P11_TaskSync")
        net.WriteString(util.TableToJSON(rows))
    net.Send(ply)
end

-- событие: ply сделал что-то (key), кол-во по умолчанию 1
function POLUS11.TaskEvent(ply, key, add)
    if not IsValid(ply) then return end
    add = add or 1

    -- сменные задачи должности
    if ply.P11_Tasks then
        for _, t in ipairs(ply.P11_Tasks) do
            if t.key == key and not t.done then
                t.cur = math.min(t.max, t.cur + add)
                if t.cur >= t.max then
                    t.done = true
                    ply:EmitSound("buttons/button9.wav", 60, 110)
                    POLUS11.Notify(ply, "Задача выполнена: " .. t.name)
                end
            end
        end
    end

    -- назначенные через терминал доп-задачи (v2.7)
    if POLUS11.XTaskEvent then
        POLUS11.XTaskEvent(ply, key, add)
    end

    POLUS11.SyncTasks(ply)
    POLUS11.CheckAllTasks(ply)
end

function POLUS11.CheckAllTasks(ply)
    if not ply.P11_Tasks or ply.P11_TasksReward then return end
    for _, t in ipairs(ply.P11_Tasks) do
        if not t.done then return end
    end

    ply.P11_TasksReward = true
    local maxhp = ply:GetMaxHealth() > 0 and ply:GetMaxHealth() or 100
    ply:SetHealth(math.min(maxhp, ply:Health() + 25))
    -- v4.0: премия за полную смену — 2000₽ (модуль экономики)
    if POLUS11.AddMoney then
        POLUS11.AddMoney(ply, (POLUS11.Config and POLUS11.Config.MoneyTaskAll) or 2000, "все задачи смены")
    end
    PrintMessage(HUD_PRINTTALK, "[СТАНЦИЯ] " .. ply:Nick() .. " выполнил(а) ВСЕ задачи смены. Пример для экипажа!")
    ply:EmitSound("buttons/button15.wav", 70, 100)
    POLUS11.Log("ЗАДАЧИ СМЕНЫ ВЫПОЛНЕНЫ: " .. ply:Nick())
end

-- ============ ПОДКЛЮЧЕНИЯ ============

-- назначение при входе / смене должности
hook.Add("PlayerInitialSpawn", "P11_TasksJoin", function(ply)
    timer.Simple(6, function()
        if IsValid(ply) then POLUS11.AssignTasks(ply) end
    end)
end)

hook.Add("P11FW.JobChanged", "P11_TasksOnJob", function(ply, newId, oldId)
    -- засчитать задачу новобранца ДО смены списка
    POLUS11.TaskEvent(ply, "job_taken")
    ply.P11_TasksReward = nil
    POLUS11.AssignTasks(ply)
end)

-- арест/рабство от офицера (сигнал из framework v1.2.1)
hook.Add("P11FW.Punished", "P11_TasksArrest", function(target, ptype, by)
    if IsValid(by) and by:IsPlayer() and by ~= target then
        POLUS11.TaskEvent(by, "arrest")
    end
end)

-- тики задач-таймеров (просто живи)
timer.Create("P11_TaskTimer", 5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() then
            local changed = false
            if ply.P11_Tasks then
                for _, t in ipairs(ply.P11_Tasks) do
                    if t.time and not t.done then
                        t.cur = math.min(t.max, t.cur + 5)
                        changed = true
                        if t.cur >= t.max then
                            t.done = true
                            POLUS11.Notify(ply, "Задача выполнена: " .. t.name)
                        end
                    end
                end
            end
            -- v2.7: доп-задачи-вахты от терминала тоже тикают временем
            if ply.P11_XTasks then
                for _, t in ipairs(ply.P11_XTasks) do
                    if t.key == "alive" and not t.done then
                        t.cur = math.min(t.max, t.cur + 5)
                        changed = true
                        if t.cur >= t.max then
                            t.done = true
                            ply:EmitSound("buttons/button9.wav", 60, 130)
                            POLUS11.Notify(ply, "Доп-задача выполнена: " .. t.name)
                        end
                    end
                end
            end
            if changed then
                POLUS11.SyncTasks(ply)
                POLUS11.CheckAllTasks(ply)
            end
        end
    end
end)

-- v2.7: закрепил призрачный проп — событие стройки (терминал: «закрепи 3 предмета»)
hook.Add("P11.PropSolidified", "P11_TasksBuild", function(ent, owner)
    if IsValid(owner) and owner:IsPlayer() then
        POLUS11.TaskEvent(owner, "build_up")
        POLUS11.TaskEvent(owner, "build_solidify")
    end
end)

-- v2.7: удар кулаками — событие спарринга
hook.Add("P11.FistHit", "P11_TasksFist", function(ply, ent)
    if IsValid(ply) then
        POLUS11.TaskEvent(ply, "fist_hit")
    end
end)

-- урон по Нечто ведёт к задаче охраны (дополняет хук в sv_infection)
hook.Add("P11.ThingDamaged", "P11_TasksThingDmg", function(victim, attacker, dmg)
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        POLUS11.TaskEvent(attacker, "damage_thing", dmg)
    end
end)
