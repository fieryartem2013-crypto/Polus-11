-- ============================================================
--  ПОЛЮС-11 — ПОДЪЁМ ЗАБЫТЫХ КЛИЕНТСКИХ МОДУЛЕЙ v5.8.29
--  (НОВЫЙ ФАЙЛ, autorun/client)
-- ============================================================
--  ПРОБЛЕМА: init.lua шлёт клиенту AddCSLuaFile'ом 65 файлов, а cl_init.lua
--  включает только 55. Десять скачиваются и никогда не выполняются —
--  среди них две ЖИВЫЕ системы:
--     modules/p11_cl_sbor.lua        — баннер/маркер/итог ЭКСТРЕННОГО СБОРА
--     modules/p11_cl_battlepass.lua  — окно батл-пасса (F5)
--  Серверная часть есть, экранной нет → «нажал и ничего не происходит».
--  Правило владельца: cl_init.lua не редактируем. Поэтому поднимаем их
--  отсюда, ПОСЛЕ загрузки гейммода, полным путём (файлы уже скачаны).
--
--  Откат: удалить этот файл.
-- ============================================================

local FILES = {
    "gamemodes/darkrp/gamemode/modules/p11_cl_sbor.lua",
    "gamemodes/darkrp/gamemode/modules/p11_cl_battlepass.lua",
}

local function BootOne(path)
    local ok, err = pcall(include, path)
    if ok then
        print("[POLUS-11] v5.8.29: поднят клиентский модуль " .. path)
        return true
    end
    print("[POLUS-11][ERROR] v5.8.29: " .. path .. " -> " .. tostring(err))
    return false
end

local function BootAll()
    local n = 0
    for _, f in ipairs(FILES) do
        if BootOne(f) then n = n + 1 end
    end
    return n
end

-- гейммод грузится ПОСЛЕ autorun — ждём его
hook.Add("PostGamemodeLoaded", "P11.ClientBoot.v5829", function()
    timer.Simple(0, BootAll)
    timer.Simple(2, BootAll)
end)
hook.Add("InitPostEntity", "P11.ClientBoot.v5829", function()
    timer.Simple(1, BootAll)
    timer.Simple(6, BootAll)
end)
