-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА: ПОИСК ПО ВСЕМ ПУТЯМ v5.8.11 (server)
--  Жалоба: «папка пуста, хотя файл кинул». Догадка владельца
--  верна по сути: звуки лежали только в папке ГЕЙММОДА
--  (gamemodes/darkrp/sound/...), а серверный file.Find НЕ видит
--  папку гейммода — она не входит в "GAME" search path.
--  Старые скрипты искали "sound/polus11/music/*" → пусто.
--
--  ЭТОТ СКРИПТ:
--   1) ДОБАВЛЯЕТ папку активного гейммода в search path
--      (file.AddToSearchPath) — теперь видны и звуки гейммода;
--   2) ищет звуки ПО ВСЕМ путям (рекурсивно sound/**, прямая
--      sound/polus11/music, gamemodes/<gm>/sound/**) — файл
--      найдётся, где бы его ни положили (в пределах sound/);
--   3) раздаёт все найденные файлы клиентам (resource.AddFile);
--   4) polus_ost_1 — главный трек, повтор по кругу, автовключение,
--      каждому заходящему;
--   5) ДИАГНОСТИКА: p11_musicpath (админ) — покажет, по каким
--      путям искали и что нашли.
--
--  КУДА КИНУТЬ ФАЙЛ (надёжно):
--    garrysmod/sound/polus11/music/polus_ost_1.mp3
--  (также найдёт, если кинуть в папку гейммода:
--    gamemodes/darkrp/sound/polus11/music/)
-- ============================================================

util.AddNetworkString("P11_MusicPlayV3") -- идемпотентно

local VOL  = 1.0
local LOOP = true
local CURRENT = nil -- { path, name }
local ALL = {}     -- полный список путей треков
local OST = "polus_ost_1"

-- ============ ДОБАВИТЬ ПАПКУ ГЕЙММОДА В SEARCH PATH ============
local GM_FOLDER = nil
local function EnsureGMFolder()
    if GM_FOLDER then return end
    local ok, gm = pcall(engine.ActiveGamemode) -- "darkrp" / "polus"
    if ok and isstring(gm) and gm ~= "" then
        GM_FOLDER = gm
        local path = "gamemodes/" .. gm
        local ok2, err = pcall(file.AddToSearchPath, path, "GAME")
        if ok2 then
            print("[POLUS-11][МУЗЫКА] папка гейммода добавлена в поиск: " .. path)
        else
            print("[POLUS-11][МУЗЫКА] не смог добавить папку гейммода: " .. tostring(err))
        end
    end
end

-- ============ ПОИСК ЗВУКОВ ПО ВСЕМ ПУТЯМ ============
local function IsAudio(f)
    local ext = string.lower(string.GetExtensionFromFilename(f))
    return ext == "mp3" or ext == "wav" or ext == "ogg"
end

local function ScanAll()
    local out, seen = {}, {}
    local function Add(path)
        if path and IsAudio(path) and not seen[path] then
            seen[path] = true
            out[#out + 1] = path
        end
    end

    -- 1) рекурсивно по всей sound/
    for _, f in ipairs(file.Find("sound/**", "GAME") or {}) do
        Add(f:sub(1, 6) == "sound/" and f or ("sound/" .. f))
    end
    -- 2) прямая папка music (страховка)
    for _, f in ipairs(file.Find("sound/polus11/music/*", "GAME") or {}) do
        Add("sound/polus11/music/" .. f)
    end
    -- 3) папка гейммода (если добавилась в search path — уже покрыта,
    --    но на всякий случай проверим явно через прямой путь)
    if GM_FOLDER then
        for _, f in ipairs(file.Find("gamemodes/" .. GM_FOLDER .. "/sound/**", "GAME") or {}) do
            Add(f:sub(1, 6) == "sound/" and f or nil)
        end
    end

    table.sort(out)
    return out
end

-- найти главный трек polus_ost_1 (по любому пути)
local function FindOst()
    for _, path in ipairs(ALL) do
        local base = string.GetFileFromFilename(path)
        local name = string.GetBaseFilename(base)
        if string.lower(name) == OST then
            return path, base
        end
    end
    return nil
end

-- ============ РАЗДАЧА КЛИЕНТАМ ============
local function RegisterAll()
    local n = 0
    for _, path in ipairs(ALL) do
        resource.AddFile(path)
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

-- ============ АВТОВКЛЮЧЕНИЕ ============
local function AutoStart()
    if CURRENT then return end
    local path, name = FindOst()
    if not path then
        if ALL[1] then
            path = ALL[1]
            name = string.GetFileFromFilename(path)
        end
    end
    if path then
        PlayTrack(nil, path, name)
    else
        print("[POLUS-11][МУЗЫКА] звуки не найдены. Кинь файл в garrysmod/sound/polus11/music/")
    end
end

hook.Add("InitPostEntity", "P11.MF.Start", function()
    EnsureGMFolder()
    ALL = ScanAll()
    local n = RegisterAll()
    print("[POLUS-11] МУЗЫКА v5.8.11: найдено треков — " .. #ALL
        .. " (пути: " .. table.concat(ALL, ", ") .. ")")
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
hook.Add("PostCleanupMap", "P11.MF.Map", function()
    ALL = ScanAll()
    RegisterAll()
    timer.Simple(5, AutoStart)
end)

-- каждые 30 сек: пересканировать (новый файл подхватится без рестарта)
timer.Create("P11.MF.Scan", 30, 0, function()
    local before = #ALL
    ALL = ScanAll()
    if #ALL > before then
        RegisterAll()
        print("[POLUS-11][МУЗЫКА] найдено новых треков: " .. (#ALL - before))
        -- если главного ещё не играет — включить
        if not CURRENT then AutoStart() end
    end
end)

-- каждому заходящему — текущий трек
hook.Add("PlayerInitialSpawn", "P11.MF.Join", function(ply)
    timer.Simple(3.5, function()
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

    local rest = string.Trim(string.sub(t, #"!музыка" + 1))

    if rest == "" then
        local lines = { "♪ МУЗЫКА СТАНЦИИ (треков: " .. #ALL .. ")" }
        if #ALL == 0 then lines[#lines + 1] = "Звуки не найдены! Кинь файл в garrysmod/sound/polus11/music/ и перезапусти. Проверка: p11_musicpath (админ)" end
        if CURRENT then lines[#lines + 1] = "Сейчас играет: " .. CURRENT.name end
        lines[#lines + 1] = "Повтор: " .. (LOOP and "ВКЛ" or "ВЫКЛ")
            .. " · громкость: " .. string.format("%.2f", VOL)
        for i, path in ipairs(ALL) do
            lines[#lines + 1] = "  " .. i .. ") " .. string.GetFileFromFilename(path)
        end
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
        if ALL[n] then
            PlayTrack(ply, ALL[n], string.GetFileFromFilename(ALL[n]))
        else
            N2("Трек №" .. n .. " не найден. Список: !музыка")
        end
        return ""
    end

    local found = nil
    for _, path in ipairs(ALL) do
        local f = string.GetFileFromFilename(path)
        if string.find(string.lower(f), lowRest, 1, true) then found = path break end
    end
    if not found then N2("Трек не найден: «" .. rest .. "». Список: !музыка") return "" end
    PlayTrack(ply, found, string.GetFileFromFilename(found))
    return ""
end

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

-- ============ ДИАГНОСТИКА p11_musicpath ============
concommand.Add("p11_musicpath", function(ply)
    local isAdmin = (not IsValid(ply)) or ply:IsSuperAdmin()
        or (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
    if not isAdmin then
        if IsValid(ply) then ply:ChatPrint("[Музыка] Только для админов.") end
        return
    end

    EnsureGMFolder()
    ALL = ScanAll()

    local out = { "== МУЗЫКА: ПУТИ (v5.8.11) ==" }
    out[#out + 1] = "Гейммод: " .. tostring(GM_FOLDER) .. " · папка добавлена в поиск"
    out[#out + 1] = "Ищу: sound/**, sound/polus11/music/*, gamemodes/<gm>/sound/**"
    out[#out + 1] = "Найдено треков: " .. #ALL
    for i, path in ipairs(ALL) do
        out[#out + 1] = "  " .. i .. ") " .. path
    end
    local ost, ostName = FindOst()
    out[#out + 1] = "polus_ost_1: " .. (ost and ("НАЙДЕН → " .. ost) or "НЕ найден")
    out[#out + 1] = "Сейчас играет: " .. tostring(CURRENT and CURRENT.name or "ничего")
    out[#out + 1] = "Плеер v3: " .. tostring(ents.FindByClass("polus_p11_musicv3")[1] ~= nil)
    out[#out + 1] = "Игроков: " .. #player.GetAll()
    for _, p in ipairs(player.GetAll()) do
        out[#out + 1] = "  " .. p:Nick() .. " → " .. p:GetNWString("P11_MusicNow", "-")
    end

    local text = table.concat(out, "\n")
    print(text)
    if IsValid(ply) then
        for _, line in ipairs(out) do ply:ChatPrint(line) end
    end
end)

print("[POLUS-11] МУЗЫКА v5.8.11: поиск по всем путям + папка гейммода + p11_musicpath")
