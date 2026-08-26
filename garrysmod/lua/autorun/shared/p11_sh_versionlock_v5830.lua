-- ============================================================
--  ПОЛЮС-11 — ЗАМОК ВЕРСИИ СБОРКИ v5.8.30 (НОВЫЙ ФАЙЛ, autorun/shared)
-- ============================================================
--  ПРОБЛЕМА (найдена прогоном в движковом VM, а не на глаз):
--  Версию пишут НЕСКОЛЬКО файлов — shared.lua («5.2.2»),
--  p11_sh_version_v526…v5830, p11_cl_v525_autorun.lua («5.2.5»).
--  Каждый ставит своё число в разное время (часть — в файле, часть —
--  в InitPostEntity и таймерах на 1 и 5 секунд). Кто выстрелил последним,
--  того и версия. Прогон показал итог «5.8.29» вместо «5.8.30»:
--  файл v5.8.29 перезатирал более новый.
--
--  ЧТО ДЕЛАЕМ:
--    1) правило «версия только растёт» — число ниже целевого не записывается;
--    2) повторяющийся таймер на 30 секунд — перебивает любого позднего
--       писателя (у остальных писатели заканчиваются к 5-й секунде);
--    3) TARGET меняется одной строкой, файл следующий версии просто
--       поднимает TARGET — и побеждает по тому же правилу.
--
--  Проверка в консоли:  lua_run print(POLUS_BUILD)   →  5.8.30
--  Откат: удалить этот файл.
-- ============================================================

local TARGET = "5.8.30"

--- a > b ? (сравнение «5.8.30» > «5.8.29» по частям)
local function IsNewer(a, b)
    local ta, tb = {}, {}
    for n in string.gmatch(tostring(a), "%d+") do ta[#ta + 1] = tonumber(n) end
    for n in string.gmatch(tostring(b), "%d+") do tb[#tb + 1] = tonumber(n) end
    for i = 1, math.max(#ta, #tb) do
        local x, y = ta[i] or 0, tb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local function Lock()
    local cur = tostring(POLUS_BUILD or "")
    if cur == TARGET then return end
    if IsNewer(cur, TARGET) then return end   -- кто-то новее — не мешаем
    POLUS_BUILD = TARGET
end

-- главный механизм: раз в секунду первые 30 секунд
timer.Create("P11.VersionLock.v5830", 1, 30, Lock)

hook.Add("PostGamemodeLoaded", "P11.VersionLock.v5830", Lock)
hook.Add("InitPostEntity", "P11.VersionLock.v5830", function()
    Lock()
    timer.Simple(1, Lock)
    timer.Simple(6, Lock)
    timer.Simple(12, Lock)
end)
timer.Simple(0, Lock)

-- видно в консоли сервера и клиента, что замок встал
hook.Add("InitPostEntity", "P11.VersionLock.Report.v5830", function()
    timer.Simple(13, function()
        print("[POLUS-11] замок версии v5.8.30: POLUS_BUILD = " .. tostring(POLUS_BUILD))
    end)
end)
