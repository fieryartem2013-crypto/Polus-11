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

    engineer = {
        { key = "refuel_gen", name = "Долей солярку в генератор", max = 2 },
        { key = "repair_gen", name = "Отремонтируй сломанный генератор", max = 1 },
        { key = "refill_ft",  name = "Заправь огнемёт от генератора", max = 1 },
        { key = "alive",      name = "Дежурство: 5 мин без смерти", max = 300, time = true },
    },

    virologist = {
        { key = "blood_draw", name = "Возьми образцы крови у экипажа", max = 2 },
        { key = "blood_test", name = "Проведи тест крови на столе", max = 1 },
        { key = "autopsy",    name = "Проведи вскрытие трупа", max = 1 },
        { key = "alive",      name = "Дежурство: 5 мин без смерти", max = 300, time = true },
    },

    lab = {
        { key = "blood_draw", name = "Возьми образцы крови у экипажа", max = 3 },
        { key = "blood_test", name = "Проведи тест крови на столе", max = 1 },
        { key = "alive",      name = "Дежурство: 5 мин без смерти", max = 300, time = true },
    },

    guard = {
        { key = "damage_thing", name = "Нанеси урона Нечто", max = 150 },
        { key = "radio",        name = "Доложи в рацию (×3)", max = 3 },
        { key = "alive",        name = "Караул: 10 мин без смерти", max = 600, time = true },
    },

    officer = {
        { key = "arrest",   name = "Посади нарушителя (арест/рабство)", max = 1 },
        { key = "rollcall", name = "Проведи общее построение по сирене", max = 1 },
        { key = "alive",    name = "Караул: 10 мин без смерти", max = 600, time = true },
    },

    cook = {
        { key = "fed",        name = "Накорми экипаж (разные люди)", max = 3 },
        { key = "refuel_gen", name = "Дотащи бочку до генератора", max = 1 },
        { key = "alive",      name = "Камбуз жив: 5 мин без смерти", max = 300, time = true },
    },

    recruit = {
        { key = "job_taken", name = "Получи назначение у кадровика/F4", max = 1 },
        { key = "alive",     name = "Осмотрись на станции: 5 мин", max = 300, time = true },
    },
}

-- ============ API ============

function POLUS11.AssignTasks(ply)
    ply.P11_Tasks = nil
    if not POLUS11.Config.Tasks then return end
    if not P11FW then return end

    local defs = POLUS11.TaskDefs[P11FW.GetJobId(ply)]
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
    net.Start("P11_TaskSync")
        net.WriteString(util.TableToJSON(rows))
    net.Send(ply)
end

-- событие: ply сделал что-то (key), кол-во по умолчанию 1
function POLUS11.TaskEvent(ply, key, add)
    if not IsValid(ply) or not ply.P11_Tasks then return end
    add = add or 1

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
        if ply:Alive() and ply.P11_Tasks then
            local changed = false
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
            if changed then
                POLUS11.SyncTasks(ply)
                POLUS11.CheckAllTasks(ply)
            end
        end
    end
end)

-- урон по Нечто ведёт к задаче охраны (дополняет хук в sv_infection)
hook.Add("P11.ThingDamaged", "P11_TasksThingDmg", function(victim, attacker, dmg)
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        POLUS11.TaskEvent(attacker, "damage_thing", dmg)
    end
end)
