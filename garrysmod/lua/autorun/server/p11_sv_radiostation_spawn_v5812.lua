-- ============================================================
--  ПОЛЮС-11 — РАДИО СТАНЦИИ v5.8.12 (server, autorun) — ФИНАЛ
--  Радио, слышное ВСЕМ: единый источник эфира, каждый игрок
--  слышит музыку станции (фоновое радио, повтор по кругу).
--
--  ПОЧЕМУ БЫЛО «ПАПКА ПУСТА»: звуки лежали только в папке
--  гейммода (gamemodes/darkrp/sound/...) — сервер её НЕ видит
--  (не в search path). Файл нужно класть в ОБЩУЮ папку:
--    garrysmod/sound/polus11/music/polus_ost_1.mp3
--  Этот скрипт:
--   1) добавляет папку гейммода в search path (страховка);
--   2) ищет звуки по ВСЕМ путям (sound/**, music/*, гейммод/**);
--   3) раздаёт их клиентам (resource.AddFile);
--   4) polus_ost_1 — ГЛАВНЫЙ трек, ПОВТОР ПО КРУГУ (13:14 ок);
--   5) автовключение при старте/смене карты, каждому заходящему;
--   6) команды !радио / !радиостоп / !радиогром / !музыка ...
--   7) диагностика p11_radiodiag.
--  Работает на канале P11_MusicPlayV3 (клиентский плеер musicv3).
-- ============================================================

util.AddNetworkString("P11_MusicPlayV3") -- идемпотентно
util.AddNetworkString("P11_MusicStop")

local VOL  = 1.0
local LOOP = true
local CURRENT = nil -- { path, name }
local ALL = {}
local OST = "polus_ost_1"

-- ============ ПАПКА ГЕЙММОДА В SEARCH PATH ============
local GM_FOLDER = nil
local function EnsureGM()
    if GM_FOLDER then return end
    local ok, gm = pcall(engine.ActiveGamemode)
    if ok and isstring(gm) and gm ~= "" then
        GM_FOLDER = gm
        pcall(file.AddToSearchPath, "gamemodes/" .. gm, "GAME")
    end
end

-- ============ ПОИСК ЗВУКОВ ============
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
    for _, f in ipairs(file.Find("sound/**", "GAME") or {}) do
        Add(f:sub(1, 6) == "sound/" and f or ("sound/" .. f))
    end
    for _, f in ipairs(file.Find("sound/polus11/music/*", "GAME") or {}) do
        Add("sound/polus11/music/" .. f)
    end
    if GM_FOLDER then
        for _, f in ipairs(file.Find("gamemodes/" .. GM_FOLDER .. "/sound/**", "GAME") or {}) do
            Add(f:sub(1, 6) == "sound/" and f or nil)
        end
    end
    table.sort(out)
    return out
end

local function FindOst()
    for _, path in ipairs(ALL) do
        local base = string.GetFileFromFilename(path)
        if string.lower(string.GetBaseFilename(base)) == OST then
            return path, base
        end
    end
    return nil
end

-- ============ РАЗДАЧА + ПРЕВЬЮ ============
local function RegisterAll()
    local n = 0
    for _, path in ipairs(ALL) do
        resource.AddFile(path)
        n = n + 1
    end
    return n
end

-- ============ ПЛЕЕР (радио, слышное всем) ============
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
    print("[POLUS-11][РАДИО] в эфире: " .. name .. (LOOP and " (повтор)" or ""))
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
    if not path and ALL[1] then
        path = ALL[1]
        name = string.GetFileFromFilename(path)
    end
    if path then
        PlayTrack(nil, path, name)
    else
        print("[POLUS-11][РАДИО] звуки не найдены. Кинь файл в garrysmod/sound/polus11/music/ и перезапусти")
    end
end

hook.Add("InitPostEntity", "P11.RS.Start", function()
    EnsureGM()
    ALL = ScanAll()
    local n = RegisterAll()
    print("[POLUS-11] РАДИО v5.8.12: треков — " .. #ALL .. " (" .. table.concat(ALL, ", ") .. ")")
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
hook.Add("PostCleanupMap", "P11.RS.Map", function()
    ALL = ScanAll()
    RegisterAll()
    timer.Simple(5, AutoStart)
end)

timer.Create("P11.RS.Scan", 30, 0, function()
    local before = #ALL
    ALL = ScanAll()
    if #ALL > before then
        RegisterAll()
        if not CURRENT then AutoStart() end
    end
end)

hook.Add("PlayerInitialSpawn", "P11.RS.Join", function(ply)
    timer.Simple(3.5, function()
        if not IsValid(ply) then return end
        if CURRENT then
            SendTrack(ply, CURRENT.path, CURRENT.name)
            ply:SetNWString("P11_MusicNow", CURRENT.name)
        end
    end)
end)

-- ============ КОМАНДЫ !радио + !музыка ============
local function RadioCmdHandler(ply, text)
    local t = string.Trim(text or "")
    local low = string.lower(t)
    if not string.StartWith(low, "!радио") and not string.StartWith(low, "!радиостоп")
        and not string.StartWith(low, "!радиогром") and not string.StartWith(low, "!музыка")
        and not string.StartWith(low, "!музстоп") and not string.StartWith(low, "!музгром")
        and not string.StartWith(low, "!музцикл") then return end

    local isAdmin = IsValid(ply) and (
        (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
        or ply:IsSuperAdmin())
    if not isAdmin then
        if POLUS11.Notify then POLUS11.Notify(ply, "Только администрация станции управляет радио.")
        else ply:ChatPrint("[Радио] Только админ.") end
        return ""
    end

    local function N2(txt)
        if POLUS11.Notify then POLUS11.Notify(ply, txt) else ply:ChatPrint("[Радио] " .. txt) end
    end

    if string.StartWith(low, "!радиогром") or string.StartWith(low, "!музгром") then
        local arg = string.match(t, "%d*%.?%d+")
        if arg then
            VOL = math.Clamp(tonumber(arg) or 1.0, 0, 1)
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end
            N2("Громкость радио: " .. string.format("%.2f", VOL))
        else
            N2("Текущая громкость: " .. string.format("%.2f", VOL) .. " (пример: !радиогром 1.0)")
        end
        return ""
    end

    if string.StartWith(low, "!музцикл") or string.StartWith(low, "!радиоцикл") then
        local arg = string.Trim(string.sub(t, string.find(t, "%d") or #t + 1))
        if string.find(arg, "1") then
            LOOP = true
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end
            N2("Повтор ВКЛ: радио играет по кругу.")
        elseif string.find(arg, "0") then
            LOOP = false
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end
            N2("Повтор ВЫКЛ: трек один раз.")
        else
            N2("Повтор: " .. (LOOP and "ВКЛ (по кругу)" or "ВЫКЛ") .. ". Менять: !радиоцикл 1 / 0")
        end
        return ""
    end

    if low == "!радиостоп" or low == "!музстоп" then
        StopTrack(ply)
        N2("Радио выключено. Снова: !радио <номер/имя> или рестарт карты.")
        return ""
    end

    -- !радио / !музыка ...
    local rest = string.Trim(string.sub(t, math.min(#"!радио", #"!музыка") + 1))
    if string.StartWith(low, "!музыка") or string.StartWith(low, "!музстоп") then
        rest = string.Trim(string.sub(t, #"!музыка" + 1))
        if low == "!музстоп" then rest = "стоп" end
    elseif string.StartWith(low, "!радиостоп") then
        rest = "стоп"
    end

    if rest == "" then
        local lines = { "📻 РАДИО СТАНЦИИ (треков: " .. #ALL .. ")" }
        if #ALL == 0 then
            lines[#lines + 1] = "Звуки не найдены! Кинь файл: garrysmod/sound/polus11/music/polus_ost_1.mp3 → рестарт."
            lines[#lines + 1] = "Проверка: p11_radiodiag (админ)"
        end
        if CURRENT then lines[#lines + 1] = "В эфире: " .. CURRENT.name end
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
        N2("Радио выключено.")
        return ""
    end

    local n = tonumber(rest)
    if n then
        if ALL[n] then
            PlayTrack(ply, ALL[n], string.GetFileFromFilename(ALL[n]))
        else
            N2("Трек №" .. n .. " не найден. Список: !радио")
        end
        return ""
    end

    local found = nil
    for _, path in ipairs(ALL) do
        local f = string.GetFileFromFilename(path)
        if string.find(string.lower(f), lowRest, 1, true) then found = path break end
    end
    if not found then N2("Трек не найден: «" .. rest .. "». Список: !радио") return "" end
    PlayTrack(ply, found, string.GetFileFromFilename(found))
    return ""
end

local function InstallCmd()
    hook.Remove("PlayerSay", "P11.MusicCmd")
    hook.Add("PlayerSay", "P11.MusicCmd", RadioCmdHandler)
end
InstallCmd()
timer.Simple(1, InstallCmd)
timer.Simple(2, InstallCmd)
timer.Simple(4, InstallCmd)
timer.Simple(8, InstallCmd)
timer.Simple(16, InstallCmd)
timer.Simple(32, InstallCmd)
timer.Simple(60, InstallCmd)

-- ============ ДИАГНОСТИКА p11_radiodiag ============
concommand.Add("p11_radiodiag", function(ply)
    local isAdmin = (not IsValid(ply)) or ply:IsSuperAdmin()
        or (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
    if not isAdmin then
        if IsValid(ply) then ply:ChatPrint("[Радио] Только для админов.") end
        return
    end
    EnsureGM()
    ALL = ScanAll()
    local out = { "== РАДИО: ДИАГНОСТИКА (v5.8.12) ==" }
    out[#out + 1] = "Гейммод: " .. tostring(GM_FOLDER) .. " (папка добавлена в поиск)"
    out[#out + 1] = "Ищу: sound/**, sound/polus11/music/*, gamemodes/<gm>/sound/**"
    out[#out + 1] = "Найдено треков: " .. #ALL
    for i, path in ipairs(ALL) do out[#out + 1] = "  " .. i .. ") " .. path end
    local ost, ostName = FindOst()
    out[#out + 1] = "polus_ost_1: " .. (ost and ("НАЙДЕН → " .. ost) or "НЕ найден")
    out[#out + 1] = "В эфире: " .. tostring(CURRENT and CURRENT.name or "ничего")
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

print("[POLUS-11] РАДИО СТАНЦИИ v5.8.12: эфир для всех, polus_ost_1 главный, !радио, p11_radiodiag")
