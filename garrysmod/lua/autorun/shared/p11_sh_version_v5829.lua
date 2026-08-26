-- ============================================================
--  ПОЛЮС-11 — ВЕРСИЯ СБОРКИ v5.8.29 (НОВЫЙ ФАЙЛ)
--  Пакет «ДАРКРП»: гейммод = darkrp · СБОР ожил · ключ Главы с сервера
-- ============================================================
--
--  ПОЧЕМУ ЗДЕСЬ ЕЩЁ И ХУК, А НЕ ТОЛЬКО СТРОКА:
--  Порядок загрузки Lua в GMod (wiki.facepunch.com/gmod/Lua_Loading_Order):
--      includes -> ГЕЙММОД (shared.lua, init.lua / cl_init.lua)
--      -> lua/autorun/ (в т.ч. autorun/shared, по алфавиту)
--      -> lua/autorun/server/  (или lua/autorun/client/)
--  То есть наш shared.lua со своим POLUS_BUILD = "5.2.2" отрабатывает РАНЬШЕ,
--  а авторун-версии его перекрывают. НО на клиенте ПОСЛЕ autorun/shared
--  грузится lua/autorun/client/p11_cl_v525_autorun.lua, где жёстко стоит
--  POLUS_BUILD = "5.2.5" — поэтому в игре баннер на клиенте показывал 5.2.5,
--  а в консоли сервера было 5.8.28. Два разных числа у одного сервера.
--  Проверка одной командой в консоли:   lua_run print(POLUS_BUILD)
--
--  Поэтому: строка здесь закрывает сервер и клиент, а хук ниже добивает
--  значение ПОСЛЕ всех загрузок (страховка от будущих авторун-файлов).

POLUS_BUILD = "5.8.29"

local function SetBuild()
    POLUS_BUILD = "5.8.29"
end

hook.Add("PostGamemodeLoaded", "P11.Version.v5829", SetBuild)
hook.Add("InitPostEntity", "P11.Version.v5829", function()
    SetBuild()
    timer.Simple(1, SetBuild)
    timer.Simple(5, SetBuild)
end)
timer.Simple(0, SetBuild)
