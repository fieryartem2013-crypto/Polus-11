-- ============================================================
--  ПОЛЮС-11 — КЛЮЧ ОСНОВАТЕЛЯ С СЕРВЕРА v5.8.29 (НОВЫЙ ФАЙЛ, server)
-- ============================================================
--  ДЫРА, которую закрываем:
--    modules/fw_sh_config.lua — SHARED-файл. Он уходит каждому клиенту
--    (AddCSLuaFile в init.lua) и лежит в ПУБЛИЧНОМ репозитории GitHub.
--    Значит строка  FounderKey = "..."  известна всем: любой игрок пишет
--    в консоли  p11_access <ключ>  и получает ранг «Глава Проекта»
--    (уровень 16) + superadmin.
--
--  ЧТО ДЕЛАЕМ (старые файлы не трогаем):
--    1) после загрузки гейммода ПЕРЕЗАПИСЫВАЕМ серверную копию
--       P11FW.Config.FounderKey значением из data/polus11/founder.key;
--    2) ключ создаётся сам при первом старте (32 случайных символа)
--       и выводится ТОЛЬКО в консоль/лог сервера — клиентам он не уходит;
--    3) старый ключ из shared больше не принимается (его на сервере нет);
--    4) сменить ключ:  p11_founderkey_reset  (только консоль сервера).
--
--  Откат: удалить этот файл — вернётся ключ из fw_sh_config.lua.
-- ============================================================

local DIR  = "polus11"
local FILE = "polus11/founder.key"

local function MakeKey()
    local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
    -- энтропия: время + часы + CRC от «мусора» (список игроков, карта),
    -- чтобы ключ не угадывался по os.time()
    local seed = tostring(os.time()) .. ":" .. tostring(os.clock()) .. ":" ..
        tostring(SysTime and SysTime() or 0) .. ":" .. tostring(game.GetMap()) ..
        ":" .. tostring(#player.GetAll()) .. ":" .. tostring(math.random(1, 999999))
    local digest = tostring(util.CRC(seed)) .. tostring(util.CRC(seed .. "polus"))
    local t = {}
    for i = 1, 32 do
        local d = tonumber(string.sub(digest, ((i - 1) % #digest) + 1, ((i - 1) % #digest) + 1)) or 0
        local idx = (d + i * 7 + math.random(1, #alphabet)) % #alphabet + 1
        t[#t + 1] = string.sub(alphabet, idx, idx)
    end
    return table.concat(t)
end

local function LoadOrCreateKey()
    if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    local raw = file.Read(FILE, "DATA")
    if raw then
        local key = string.Trim(tostring(raw))
        key = string.gsub(key, "[%c%s]", "")
        if #key >= 16 then return key, false end
    end
    local key = MakeKey()
    file.Write(FILE, key)
    return key, true
end

local CurrentKey = nil

local function Apply(newKey, created)
    if not (P11FW and P11FW.Config) then return false end
    CurrentKey = newKey
    P11FW.Config.FounderKey = newKey          -- серверная копия; клиенты её не видят
    if created then
        print("==========================================================")
        print("[POLUS-11] v5.8.29: создан НОВЫЙ ключ основателя (серверный).")
        print("[POLUS-11] КЛЮЧ: " .. newKey)
        print("[POLUS-11] Хранится в garrysmod/data/" .. FILE)
        print("[POLUS-11] Вход:  p11_access " .. newKey)
        print("[POLUS-11] Старый ключ из fw_sh_config.lua БОЛЬШЕ НЕ РАБОТАЕТ.")
        print("==========================================================")
        if P11FW.Log then
            P11FW.Log("v5.8.29: ключ основателя пересоздан (серверный, data/" .. FILE .. ")")
        end
    else
        print("[POLUS-11] v5.8.29: ключ основателя поднят с сервера (data/" .. FILE .. ")")
    end
    return true
end

local function Boot()
    local key, created = LoadOrCreateKey()
    return Apply(key, created)
end

hook.Add("PostGamemodeLoaded", "P11.FounderKey.v5829", function() timer.Simple(0, Boot) end)
hook.Add("InitPostEntity", "P11.FounderKey.v5829", function()
    timer.Simple(0.5, Boot)
    timer.Simple(3, Boot)
    timer.Simple(10, Boot)
end)
timer.Simple(0.2, Boot)

-- смена ключа — только из консоли сервера
concommand.Add("p11_founderkey_reset", function(ply)
    if IsValid(ply) then
        ply:ChatPrint("[ПОЛЮС-11] Ключ меняется только из консоли СЕРВЕРА: p11_founderkey_reset")
        return
    end
    if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    local key = MakeKey()
    file.Write(FILE, key)
    Apply(key, true)
end)

-- показать текущий ключ в консоль сервера (для владельца)
concommand.Add("p11_founderkey_show", function(ply)
    if IsValid(ply) then return end
    local key = CurrentKey or select(1, LoadOrCreateKey())
    print("[POLUS-11] текущий ключ основателя: " .. tostring(key))
end)
