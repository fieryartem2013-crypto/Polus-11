-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА v5.8.9 (server, autorun) — ЖЕЛЕЗОБЕТОННЫЙ
--  Почему раньше молчала: 4 старых скрипта (v582..v585) спорили
--  между собой, а энтити musicbg спавнила САМА СЕБЯ из своего
--  init.lua — а init.lua не грузится, пока энтити не создана
--  (замкнутый круг). Старые файлы НЕ трогаем.
--
--  ЭТОТ СКРИПТ (новый):
--   • работает на НОВОМ канале P11_MusicPlayV3 — старые плееры
--     (v2) молчат, конфликта нет;
--   • раздаёт ВСЕ файлы из sound/polus11/music/* (и из общей
--     garrysmod/sound/, и из папки гейммода) через resource.AddFile;
--   • АВТОВКЛЮЧЕНИЕ через ~5 сек после старта/смены карты;
--   • каждому заходящему — текущий трек через 3 сек;
--   • команды !музыка / !музстоп / !музгром / !музцикл
--     (обработчик заменяет старые — таймеры до 60 сек);
--   • спавнит энтити polus_p11_musicv3 (клиентский плеер v3);
--   • диагностика: p11_musictest (админ).
--
--  КАК ДОБАВИТЬ ТРЕК: файл .mp3 латиницей без пробелов в
--  garrysmod/sound/polus11/music/ (или в папку гейммода
--  gamemodes/darkrp/sound/polus11/music/) → рестарт.
-- ============================================================

util.AddNetworkString("P11_MusicPlayV3")
util.AddNetworkString("P11_MusicStop")

local VOL  = 1.0
local LOOP = true -- эмбиент: по кругу
local CURRENT = nil -- { path, name }
local STARTED = false

-- ============ ФАЙЛЫ ============
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

-- ============ РАЗДАЧА КЛИЕНТАМ (называется многократно — безопасно) ============
local function RegisterAll()
    local files = MusicFiles()
    local n = 0
    for _, f in ipairs(files) do
        resource.AddFile("sound/polus11/music/" .. f)
        n = n + 1
    end
    return n
end

-- ============ ПЛЕЕР ============
local function SendTrack(ply, path, name)
    net.Start("P11_MusicPlayV3")
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
    print("[POLUS-11][МУЗЫКА] играет: " .. name)
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

-- ============ АВТОВКЛЮЧЕНИЕ ============
local function AutoStart()
    if CURRENT then return end
    local p, n = DefaultTrack()
    if p then
        PlayTrack(nil, p, n)
    else
        print("[POLUS-11][МУЗЫКА] папка sound/polus11/music пуста — музыки нет")
    end
end

hook.Add("InitPostEntity", "P11.MV3.Start", function()
    local n = RegisterAll()
    print("[POLUS-11] МУЗЫКА v5.8.9: раздаю клиентам " .. n .. " треков")
    timer.Simple(5, AutoStart)
    timer.Simple(1, function()
        if ents.FindByClass("polus_p11_musicv3")[1] then return end
        local e = ents.Create("polus_p11_musicv3")
        if IsValid(e) then
            e:SetPos(Vector(0, 0, -20000))
            e:Spawn()
        end
    end)
end)
hook.Add("PostCleanupMap", "P11.MV3.Map", function()
    local n = RegisterAll()
    timer.Simple(5, AutoStart)
end)

-- каждому заходящему — текущий трек
hook.Add("PlayerInitialSpawn", "P11.MV3.Join", function(ply)
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
            N2("Громкость музыки: " .. string.format("%.2f", VOL))
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

-- заменяем обработчики старых скриптов (v582..v585) — наш последний и активный
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
timer.Simple(60, InstallCmd)

-- ============ ДИАГНОСТИКА p11_musictest ============
concommand.Add("p11_musictest", function(ply)
    local isAdmin = (not IsValid(ply)) or ply:IsSuperAdmin()
        or (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
    if not isAdmin then
        if IsValid(ply) then ply:ChatPrint("[Музыка] Только для админов.") end
        return
    end
    local files = MusicFiles()
    local out = { "== МУЗЫКА: ДИАГНОСТИКА ==" }
    out[#out + 1] = "Треков найдено: " .. #files
    for i, f in ipairs(files) do out[#out + 1] = "  " .. i .. ") " .. f end
    out[#out + 1] = "Сейчас играет: " .. tostring(CURRENT and CURRENT.name or "ничего")
    out[#out + 1] = "Повтор: " .. (LOOP and "ВКЛ" or "ВЫКЛ") .. " · громкость: " .. string.format("%.2f", VOL)
    out[#out + 1] = "Игроков: " .. #player.GetAll() .. " · энтити v3: " .. tostring(ents.FindByClass("polus_p11_musicv3")[1] ~= nil)
    local text = table.concat(out, "\n")
    print(text)
    if IsValid(ply) then
        for _, line in ipairs(out) do ply:ChatPrint(line) end
    end
end)

print("[POLUS-11] МУЗЫКА v5.8.9: единый скрипт — автовключение, канал V3, p11_musictest")
