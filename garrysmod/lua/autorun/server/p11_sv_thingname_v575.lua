-- ============================================================
--  ПОЛЮС-11 — НЕЧТО: СЛУЧАЙНОЕ ИМЯ + ФИКС ГОЛОСА (server) v5.7.5
--  Владелец:
--    1) «когда Нечто тебя убивает — ему даётся маскировка со
--       СЛУЧАЙНЫМ именем и фамилией»;
--    2) «когда ты за Нечто и маскировался — в голосе ты
--       отображаешься как старый человек» (ванильный voice-ник
--       показывает Steam-имя — чинится на клиенте).
--
--  Этот файл (server):
--   • слушает hook Polus11.ThingDevoured (вызывается при каждом
--     поглощении — и в thingcore, и в thingkit);
--   • после применения личины (P11_FakeNick = имя жертвы) —
--     ПЕРЕЗАПИСЫВАЕТ P11_FakeNick на случайное «Имя Фамилия»
--     из советского пула имён (реалистичные для станции);
--   • сохраняет жертву в P11_LastVictim для памяти (по желанию).
--  Старые файлы не трогаем.
-- ============================================================

local ok, err = pcall(function()

-- советские имена + фамилии (пул для случайной маскировки)
local FIRST_NAMES = {
    "Алексей", "Борис", "Виктор", "Геннадий", "Дмитрий", "Евгений",
    "Иван", "Константин", "Леонид", "Михаил", "Николай", "Олег",
    "Пётр", "Сергей", "Фёдор", "Юрий", "Анатолий", "Валентин",
    "Григорий", "Игорь", "Павел", "Роман", "Семён", "Тимофей",
}
local LAST_NAMES = {
    "Александров", "Беляев", "Волков", "Громов", "Дроздов", "Ефимов",
    "Жуков", "Зайцев", "Иванов", "Ковалёв", "Лебедев", "Морозов",
    "Никитин", "Орлов", "Павлов", "Романов", "Смирнов", "Тихонов",
    "Фёдоров", "Чернов", "Шапошников", "Щербаков", "Яковлев", "Соколов",
}
local function RandomName()
    local fn = FIRST_NAMES[math.random(#FIRST_NAMES)]
    local ln = LAST_NAMES[math.random(#LAST_NAMES)]
    return fn .. " " .. ln
end

-- слушаем поглощение: после личины — случайное имя
hook.Add("Polus11.ThingDevoured", "P11.ThingRandomName575", function(ply, identity)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not (ply:GetNWBool("P11_Infected", false) and ply:GetNWBool("P11_InfActive", false)) then return end

    local fake = RandomName()
    ply.P11_FakeNick = fake
    ply:SetNWString("P11_FakeNick", fake)

    if identity then
        ply.P11_LastVictim = identity.nick or "?"
    end

    if POLUS11.Notify then
        POLUS11.Notify(ply, "Личина принята: ты теперь «" .. fake .. "». В голосе и TAB — это имя.")
    end
    if POLUS11.Log then
        POLUS11.Log("НЕЧТО: " .. ply:Nick() .. " получил случайную личину «" .. fake .. "» (жертва: " .. tostring(ply.P11_LastVictim) .. ")")
    end
end)

end)
if not ok then
    print("[POLUS-11][СЛУЧАЙНАЯ ЛИЧИНА] ошибка: " .. tostring(err))
end

print("[POLUS-11] СЛУЧАЙНАЯ ЛИЧИНА v5.7.5 (server): при поглощении Нечто получает случайное имя+фамилию")
