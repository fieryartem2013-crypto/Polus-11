AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
--  ПОЛЮС-11 — ФОНОВАЯ МУЗЫКА (ЭМБИЕНТ) v5.8.6 — СЕРВЕР
--  ВСЁ ВНУТРИ ГЕЙММОДА (папка gamemodes/darkrp/):
--    • музыка:   gamemodes/darkrp/sound/polus11/music/*.mp3
--    • скрипт:   gamemodes/darkrp/entities/entities/polus_p11_musicbg/
--  Это ФОНОВАЯ музыка станции (не интро!): включается сама,
--  повторяется по кругу, громко.
--
--  СКАЧИВАНИЕ: все файлы из sound/polus11/music/ раздаются
--  клиентам через resource.AddFile — игроки качают при заходе
--  (один раз, дальше кэш). Скрипт живёт в init.lua энтити —
--  грузится автоматически при старте гейммода, ничего не надо
--  подключать в init.lua гейммода (мы его не трогаем).
--
--  КОМАНДЫ (админ):
--    !музыка              — список + что играет
--    !музыка 2            — сменить трек (номер)
--    !музыка polus_ost_1  — сменить трек (имя)
--    !музыка стоп/!музстоп— остановить
--    !музгром 0..1        — громкость (по умолчанию 1.0)
--    !музцикл [0|1]       — повтор (по умолчанию ВКЛ)
-- ============================================================

util.AddNetworkString("P11_MusicPlayV2") -- идемпотентно
util.AddNetworkString("P11_MusicStop")

local VOL  = 1.0
local LOOP = true -- эмбиент: повтор по кругу
local CURRENT = nil -- { path, name }

-- ============ СКРИПТ СКАЧИВАНИЯ: раздать все треки клиентам ============
local function RegisterAll()
    local files = file.Find("sound/polus11/music/*", "GAME") or {}
    local n = 0
    for _, f in ipairs(files) do
        local ext = string.lower(string.GetExtensionFromFilename(f))
        if ext == "mp3" or ext == "wav" or ext == "ogg" then
            resource.AddFile("sound/polus11/music/" .. f) -- клиенты качают при заходе
            n = n + 1
        end
    end
    return n
end

local function MusicFiles()
    local out = {}
    for _, f in ipairs(file.Find("sound/polus11/music/*", "GAME") or {}) do
        local ext = string.lower(string.GetExtensionFromFilename(f))
        if ext == "mp3" or ext == "wav" or ext == "ogg" then out[#out + 1] = f end
    end
    table.sort(out)
    return out
end

local function TrackPathByName(name)
    local files = file.Find("sound/polus11/music/" .. name .. ".*", "GAME")
    if files and files[1] then
        local ext = string.lower(string.GetExtensionFromFilename(files[1]))
        if ext == "mp3" or ext == "wav" or ext == "ogg" then
            return "sound/polus11/music/" .. files[1], files[1]
        end
    end
    return nil
end

-- ============ ПЛЕЕР ============
local function SendTrack(ply, path, name)
    net.Start("P11_MusicPlayV2")
        net.WriteString(path)
        net.WriteFloat(VOL)
        net.WriteBool(LOOP)
    if ply then net.Send(ply) else net.Broadcast() end
end

local function PlayTrack(ply, path, name)
    CURRENT = { path = path, name = name }
    SendTrack(nil, path, name)
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", name)
    end
    local txt = "♪ Станция играет: «" .. name .. "»" .. (LOOP and " (∞)" or "")
    for _, p in ipairs(player.GetAll()) do p:ChatPrint(txt) end
end

local function StopTrack(ply)
    CURRENT = nil
    net.Start("P11_MusicStop")
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", "")
    end
end

local function DefaultTrack()
    local p, n = TrackPathByName("polus_ost_1")
    if p then return p, n end
    local files = MusicFiles()
    if files[1] then return "sound/polus11/music/" .. files[1], files[1] end
    return nil
end

-- ============ АВТОВКЛЮЧЕНИЕ (фон, не интро) ============
local function AutoStart()
    if CURRENT then return end
    local p, n = DefaultTrack()
    if p then
        PlayTrack(nil, p, n)
        print("[POLUS-11][МУЗЫКА-ГЕЙММОД] авто-фон играет: «" .. n .. "» (∞, громкость " .. VOL .. ")")
    else
        print("[POLUS-11][МУЗЫКА-ГЕЙММОД] папка sound/polus11/music пуста — музыки нет")
    end
end

-- каждому заходящему — текущий трек автоматически
hook.Add("PlayerInitialSpawn", "P11.MBG.Join", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        if CURRENT then
            SendTrack(ply, CURRENT.path, CURRENT.name)
            ply:SetNWString("P11_MusicNow", CURRENT.name)
        end
    end)
end)

-- ============ КОМАНДЫ ============
local function MusicCmdHandler(ply, text)
    local t = string.Trim(text or "")
    local low = string.lower(t)
    if not string.StartWith(low, "!музыка") and not string.StartWith(low, "!музстоп")
        and not string.StartWith(low, "!музгром") and not string.StartWith(low, "!музцикл") then return end

    local isAdmin = IsValid(ply) and (
        (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
        or ply:IsSuperAdmin())
    if not isAdmin then
        if POLUS11.Notify then POLUS11.Notify(ply, "Только администрация станции управляет музыкой.")
        else ply:ChatPrint("[Музыка] Только админ.") end
        return ""
    end

    local function N2(txt)
        if POLUS11.Notify then POLUS11.Notify(ply, txt) else ply:ChatPrint("[Музыка] " .. txt) end
    end

    if string.StartWith(low, "!музгром") then
        local arg = string.match(t, "%d*%.?%d+")
        if arg then
            VOL = math.Clamp(tonumber(arg) or 1.0, 0, 1)
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end
            N2("Громкость музыки: " .. string.format("%.2f", VOL) .. " (макс 1.00)")
        else
            N2("Текущая громкость: " .. string.format("%.2f", VOL) .. " (пример: !музгром 1.0)")
        end
        return ""
    end

    if string.StartWith(low, "!музцикл") then
        local arg = string.Trim(string.sub(t, #"!музцикл" + 1))
        if string.find(arg, "1") then
            LOOP = true
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end
            N2("Повтор ВКЛ: музыка играет по кругу.")
        elseif string.find(arg, "0") then
            LOOP = false
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end
            N2("Повтор ВЫКЛ: трек играет один раз.")
        else
            N2("Повтор сейчас: " .. (LOOP and "ВКЛ (по кругу)" or "ВЫКЛ (один раз)")
                .. ". Менять: !музцикл 1 / !музцикл 0")
        end
        return ""
    end

    if low == "!музстоп" then
        StopTrack(ply)
        N2("Музыка остановлена. Снова: !музыка <номер/имя> или рестарт карты.")
        return ""
    end

    local files = MusicFiles()
    local rest = string.Trim(string.sub(t, #"!музыка" + 1))

    if rest == "" then
        local lines = { "♪ МУЗЫКА СТАНЦИИ (треков: " .. #files .. ")" }
        if #files == 0 then lines[#lines + 1] = "Папка sound/polus11/music пуста! Кидай .mp3 и рестарт." end
        if CURRENT then lines[#lines + 1] = "Сейчас играет: " .. CURRENT.name end
        lines[#lines + 1] = "Повтор: " .. (LOOP and "ВКЛ" or "ВЫКЛ")
            .. " · громкость: " .. string.format("%.2f", VOL)
        for i, f in ipairs(files) do lines[#lines + 1] = "  " .. i .. ") " .. f end
        ply:ChatPrint(table.concat(lines, "\n"))
        return ""
    end

    local lowRest = string.lower(rest)
    if lowRest == "стоп" then
        StopTrack(ply)
        N2("Музыка остановлена.")
        return ""
    end

    local n = tonumber(rest)
    if n then
        if files[n] then PlayTrack(ply, "sound/polus11/music/" .. files[n], files[n])
        else N2("Трек №" .. n .. " не найден. Список: !музыка") end
        return ""
    end

    local found = nil
    for _, f in ipairs(files) do
        if string.find(string.lower(f), lowRest, 1, true) then found = f break end
    end
    if not found then N2("Трек не найден: «" .. rest .. "». Список: !музыка") return "" end
    PlayTrack(ply, "sound/polus11/music/" .. found, found)
    return ""
end

-- наш обработчик — ПОСЛЕДНИМ (таймеры позже, чем у v5.8.2..5.8.5)
local function InstallCmd()
    hook.Remove("PlayerSay", "P11.MusicCmd")
    hook.Add("PlayerSay", "P11.MusicCmd", MusicCmdHandler)
end
InstallCmd()
timer.Simple(1, InstallCmd)
timer.Simple(2, InstallCmd)
timer.Simple(4, InstallCmd)
timer.Simple(8, InstallCmd)
timer.Simple(16, InstallCmd)
timer.Simple(32, InstallCmd)
timer.Simple(48, InstallCmd)

-- ============ СПАВН САМОЙ СЕБЯ (чтобы cl_init ушёл клиентам) ============
local function SpawnSelf()
    if ents.FindByClass("polus_p11_musicbg")[1] then return end
    local e = ents.Create("polus_p11_musicbg")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.MBG.Start", function()
    local n = RegisterAll()
    timer.Simple(6, AutoStart)  -- фоновая музыка через ~6 сек после старта
    timer.Simple(1, SpawnSelf)
    print("[POLUS-11] МУЗЫКА-ГЕЙММОД v5.8.6: раздаю клиентам " .. n .. " треков, фон включится сам (эмбиент)")
end)
hook.Add("PostCleanupMap", "P11.MBG.Map", function()
    timer.Simple(6, AutoStart)
    timer.Simple(3, SpawnSelf)
end)
