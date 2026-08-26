-- ============================================================
--  ПОЛЮС-11 — ФЛАГИ НА ФУНКЦИЯХ v5.8.29 (НОВЫЙ ФАЙЛ, server)
-- ============================================================
--  НАЙДЕНО ПРОГОНОМ В ДВИЖКОВОМ VM (LuaJIT 2.1), статически не видно.
--
--  В чистом Lua 5.1 / LuaJIT функцию НЕЛЬЗЯ индексировать:
--      local f = function() end
--      f.Флаг = true   -->  «attempt to index a function value»
--  (метатаблицы у функций по умолчанию нет: debug.getmetatable(f) == nil)
--
--  Именно этот приём в сборке используется как «метка: обёртка уже стоит»:
--      p11_sv_bangfix2_spawn_v5813.lua:63   orig.<флаг>            (v5.8.13)
--      p11_sv_zz_fixes_v5814.lua:46         orig.P11_ProfaFix      (v5.8.14)
--      p11_sv_rankgrant_v5828.lua:54        P11FW.SetRank.<флаг>   (v5.8.28)
--      p11_sv_jobhp_speed_v5828.lua:59      POLUS11.ApplyMoveSpeeds.<флаг>
--  Если движок не ставит функциям метатаблицу — ВСЕ эти патчи падают на
--  строке установки флажка и молча не применяются (обёртка не встаёт).
--
--  ЧТО ДЕЛАЕМ: ставим функциям метатаблицу с боковой таблицей (weak keys),
--  чтобы  f.Флаг = true  и  f.Флаг  работали как задумано. Файл грузится в
--  autorun — то есть РАНЬШЕ InitPostEntity и раньше любых таймеров, поэтому
--  повторные попытки перечисленных патчей проходят штатно.
--
--  ПРОВЕРКА НА ЖИВОМ СЕРВЕРЕ (одна команда в консоли):
--      lua_run local f=function() end print(pcall(function() f.x=1 end))
--    false  -> патчи v5.8.13/14/28 без этого файла не работали
--    true   -> движок и так разрешает, файл просто ничего не делает
--
--  Откат: удалить этот файл.
-- ============================================================

local function ProbeWorks()
    local f = function() end
    local ok = pcall(function() f.__p11probe = true end)
    if not ok then return false end
    local v
    pcall(function() v = f.__p11probe end)
    return v == true
end

if ProbeWorks() then
    print("[POLUS-11] v5.8.29: индексация функций разрешена движком — костыль не нужен")
    return
end

if not (debug and debug.setmetatable) then
    print("[POLUS-11][WARN] v5.8.29: нет debug.setmetatable — флаги на функциях не включить")
    return
end

local store = setmetatable({}, { __mode = "k" })

local function slot(f)
    local t = rawget(store, f)
    if not t then t = {}; rawset(store, f, t) end
    return t
end

debug.setmetatable(function() end, {
    __index = function(f, k)
        local t = rawget(store, f)
        return t and t[k] or nil
    end,
    __newindex = function(f, k, v)
        slot(f)[k] = v
    end,
})

-- самопроверка
local probe = function() end
local okSet = pcall(function() probe.__p11ok = true end)
local okGet = false
pcall(function() okGet = probe.__p11ok == true end)

if okSet and okGet then
    print("[POLUS-11] v5.8.29: флаги на функциях ВКЛЮЧЕНЫ — патчи v5.8.13 / v5.8.14 / v5.8.28 смогут встать")
    if P11FW and P11FW.Log then
        P11FW.Log("v5.8.29: включена индексация функций (метки обёрток v5.8.13/14/28)")
    end
else
    print("[POLUS-11][ERROR] v5.8.29: метатаблица функций не заработала")
end
