-- ============================================================
--  ПОЛЮС-11 — ПОРЯДОК HUD v5.8.16 (КЛИЕНТ, энтити hudfix)
--  Жалоба: «HUD основной поверх HUD Нечто».
--  Причина: HUD Нечто (P11.ThingHUD, P11.MutationHUD) грузится
--  ПОСЛЕ основного HUD → рисуется ПОВЕРХ (панели Нечто внизу
--  перекрывали жизни/деньги).
--  Фикс: пересобираем очередь HUDPaint — хуки Нечто становятся
--  ПЕРВЫМИ, основной HUD рисуется поверх них. Старые файлы не
--  трогаем (хуки снимаем и вешаем в новом порядке).
--  v5.8.16: ИСПРАВЛЕНА ошибка hook.lua «attempt to call boolean»
--  (метку готовности храним ВНЕ таблицы хуков — в P11.HudFixDone,
--  а не клали true прямо в HUDPaint, из-за чего движок падал
--  каждый кадр x72).
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}

local THING_HOOKS = { "P11.ThingHUD", "P11.MutationHUD" }

local function ReorderHud()
    local t = hook.GetTable()
    local hud = t and t.HUDPaint
    if not hud then return false end
    if P11.HudFixDone then return true end -- метка ВНЕ таблицы хуков

    -- собрать ВСЕ хуки HUDPaint (только функции — на всякий случай)
    local names, funcs = {}, {}
    for name, fn in pairs(hud) do
        if isfunction(fn) then
            names[#names + 1] = name
            funcs[name] = fn
        end
    end

    -- очистить и перезаписать: сначала HUD Нечто, потом остальные (основной поверх)
    for name in pairs(hud) do hud[name] = nil end
    for _, th in ipairs(THING_HOOKS) do
        if funcs[th] then
            hud[th] = funcs[th]
        end
    end
    for _, name in ipairs(names) do
        if not table.HasValue(THING_HOOKS, name) then
            hud[name] = funcs[name]
        end
    end
    P11.HudFixDone = true -- только флаг в P11, НЕ в таблицу хуков!
    print("[POLUS-11] v5.8.16: порядок HUD исправлен — основной HUD поверх HUD Нечто")
    return true
end

-- cl_init грузится после модулей гейммода, но страхуемся таймерами
ReorderHud()
timer.Simple(1, ReorderHud)
timer.Simple(3, ReorderHud)
timer.Simple(6, ReorderHud)
timer.Simple(10, ReorderHud)
