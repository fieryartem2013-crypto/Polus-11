-- ============================================================
--  ПОЛЮС-11 — ЛОЖНЫЕ ЗАДАЧИ МАСКИРОВКИ (server) v2.9
--  Проблема хоррор-баланса: у Нечто под маской выполнены все
--  задачи — виджет пустой, это ПАЛИТ монстра («а чё у тебя
--  дел-то нет?»). Решение: пока форма НЕ явлена, Нечто само
--  получает «прикрытие» — обычные на вид станционные дела,
--  которые медленно «выполняются сами» без наград и объявлений.
--  При явлении формы прикрытие мгновенно сгорает.
--  Плюс: в терминале прогресс доп-задач замаскированного Нечто
--  показывает завышенный ложный рост (врёт начальству).
-- ============================================================

-- пул обычных станционных дел (без наград, чистая видимость)
local FAKE_POOL = {
    "Пропылесосить коридор блока Б",
    "Проверить дверь склада на лёд",
    "Инвентаризация ящика инструмента",
    "Дежурство у печи-калорифера",
    "Пересчитать бочки с соляркой",
    "Протянуть кабель в отсеке В",
    "Смазать замки наружного люка",
    "Сдать отчёт по ГСМ дежурному",
    "Разобрать ящики на камбузе",
    "Почистить карнизы от сосулек",
    "Перезарядить огнетушители",
    "Проверить аварийные фонари",
}

local function IsMaskedThing(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not ply:GetNWBool("P11_Infected", false) then return false end
    if not ply:GetNWBool("P11_InfActive", false) then return false end
    return ply.P11_Revealed ~= true -- форма скрыта = маскировка
end

POLUS11.IsMaskedThing = IsMaskedThing -- использует также терминал (ложный прогресс)

-- ============ ГЕНЕРАЦИЯ / ОЧИСТКА ============

local SOLO_MAX = { 2, 3, 4 } -- приятная мелкая рутина

function ShadowTasks_Generate(ply)
    ply.P11_FakeTasks = {}
    local used = {}
    for i = 1, 2 do
        local tries = 0
        local name = nil
        repeat
            tries = tries + 1
            name = FAKE_POOL[math.random(#FAKE_POOL)]
        until (not used[name]) or tries > 12
        used[name] = true
        ply.P11_FakeTasks[i] = {
            name = name, max = SOLO_MAX[math.random(#SOLO_MAX)],
            cur = 0, done = false,
        }
    end
    ply.P11_FakeIdle = nil
    if POLUS11.SyncTasks then POLUS11.SyncTasks(ply) end
end

function ShadowTasks_Wipe(ply)
    if not ply.P11_FakeTasks then return end
    ply.P11_FakeTasks = nil
    ply.P11_FakeIdle = nil
    if POLUS11.SyncTasks then POLUS11.SyncTasks(ply) end
end

-- ============ ЖИЗНЕННЫЙ ЦИКЛ ============
-- Каждые 6 сек: замаскированному — лёгкий фон прогресса;
-- всё выполнено → отдохнув 25-40 сек, новая пара дел.
-- Явился → всё сгорает.

timer.Create("P11.ShadowTasks", 6, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsMaskedThing(ply) then
            if not ply.P11_FakeTasks then
                -- прикрытие появляется не мгновенно — как будто «пошёл работать»
                ply.P11_FakeIdle = ply.P11_FakeIdle or (CurTime() + math.Rand(20, 35))
                if CurTime() >= ply.P11_FakeIdle then
                    ShadowTasks_Generate(ply)
                end
            else
                local changed = false
                local allDone = true
                for _, t in ipairs(ply.P11_FakeTasks) do
                    if not t.done then
                        allDone = false
                        if math.random() < 0.6 then
                            t.cur = math.min(t.max, t.cur + 1)
                            changed = true
                            if t.cur >= t.max then t.done = true end
                        end
                        break -- за тик двигаем максимум одну задачу
                    end
                end
                if allDone then
                    ply.P11_FakeIdle = ply.P11_FakeIdle or (CurTime() + math.Rand(25, 40))
                    if CurTime() >= ply.P11_FakeIdle then
                        ShadowTasks_Generate(ply)
                    end
                elseif changed then
                    if POLUS11.SyncTasks then POLUS11.SyncTasks(ply) end
                end
            end
        elseif ply.P11_FakeTasks then
            ShadowTasks_Wipe(ply)
        end
    end
end)

-- смена должности/смерть — пересобрать прикрытие на следующем тике
hook.Add("P11FW.JobChanged", "P11.ShadowJob", function(ply)
    ShadowTasks_Wipe(ply)
end)
hook.Add("PlayerDeath", "P11.ShadowDeath", function(ply)
    ShadowTasks_Wipe(ply)
end)
