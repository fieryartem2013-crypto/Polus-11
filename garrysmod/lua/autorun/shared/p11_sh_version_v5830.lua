-- ============================================================
--  ПОЛЮС-11 — ВЕРСИЯ СБОРКИ v5.8.30 (НОВЫЙ ФАЙЛ)
--  Пакет по ТЗ: права на выдачу рангов + Esc/E-меню
-- ============================================================
--  Порядок загрузки Lua в GMod (wiki.facepunch.com/gmod/Lua_Loading_Order):
--      includes -> ГЕЙММОД (shared.lua, init.lua / cl_init.lua)
--      -> lua/autorun/ (в т.ч. autorun/shared, по алфавиту)
--      -> lua/autorun/server/  ИЛИ  lua/autorun/client/
--  Поэтому строка здесь закрывает сервер, а хук добивает значение после
--  всех загрузок (на клиенте последним идёт p11_cl_v525_autorun.lua со
--  своим «5.2.5»).
--  Проверка в консоли:  lua_run print(POLUS_BUILD)

POLUS_BUILD = "5.8.30"

local function SetBuild()
    POLUS_BUILD = "5.8.30"
end

hook.Add("PostGamemodeLoaded", "P11.Version.v5830", SetBuild)
hook.Add("InitPostEntity", "P11.Version.v5830", function()
    SetBuild()
    timer.Simple(1, SetBuild)
    timer.Simple(5, SetBuild)
end)
timer.Simple(0, SetBuild)
