-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА: АВТОВКЛЮЧЕНИЕ + ПОВТОР v5.8.5 (server)
--  Заявка: «не один раз, а автоматом пусть включается и
--  повторяется» — фоновая музыка станции.
--   • ПОВТОР ПО КРУГУ по умолчанию (loop = true, эмбиент);
--   • АВТОВКЛЮЧЕНИЕ: при старте сервера / смене карты — сам
--     играет трек (polus_ost_1, если есть; иначе первый);
--   • каждый заходящий игрок АВТОМАТИЧЕСКИ получает текущий
--     трек (через 3 сек после спавна) — слышит музыку сразу;
--   • громкость по умолчанию 1.0 (максимум);
--   • управление остаётся: !музыка, !музстоп, !музгром, !музцикл.
--
--  КОМАНДЫ (админ):
--    !музыка              — список + что играет
--    !музыка 2            — сменить трек (по номеру)
--    !музыка polus_ost_1  — сменить трек (по имени)
--    !музыка стоп/!музстоп— остановить (авто больше не играет)
--    !музгром 0..1        — громкость (по умолчанию 1.0)
--    !музцикл [0|1]       — повтор вкл/выкл (по умолчанию ВКЛ)
-- ============================================================

util.AddNetworkString("P11_MusicPlayV2") -- идемпотентно с v5.8.4

local VOL  = 1.0   -- громкость: максимум
local LOOP = true  -- ПОВТОР ПО УМОЛЧАНИЮ: ВКЛ (эмбиент-фон)
local CURRENT = nil -- { path = ..., name = ... } — что играет сейчас

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
    SendTrack(nil, path, name) -- всем
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

-- выбрать трек по умолчанию: polus_ost_1 → иначе первый в списке
local function DefaultTrack()
    local p, n = TrackPathByName("polus_ost_1")
    if p then return p, n end
    local files = MusicFiles()
    if files[1] then return "sound/polus11/music/" .. files[1], files[1] end
    return nil
end

-- АВТОВКЛЮЧЕНИЕ при старте сервера / смене карты
local function AutoStart()
    if CURRENT then return end -- уже играет
    local p, n = DefaultTrack()
    if p then
        PlayTrack(nil, p, n)
        print("[POLUS-11][МУЗЫКА] авто: играет «" .. n .. "» по кругу (громкость " .. VOL .. ")")
    else
        print("[POLUS-11][МУЗЫКА] авто: папка sound/polus11/music пуста — музыки нет")
    end
end

hook.Add("InitPostEntity", "P11.MAuto.Start", function()
    timer.Simple(6, AutoStart)
end)
hook.Add("PostCleanupMap", "P11.MAuto.Map", function()
    timer.Simple(6, AutoStart)
end)

-- КАЖДОМУ ЗАХОДЯЩЕМУ — текущий трек автоматически
hook.Add("PlayerInitialSpawn", "P11.MAuto.Join", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        if CURRENT then
            SendTrack(ply, CURRENT.path, CURRENT.name)
            ply:SetNWString("P11_MusicNow", CURRENT.name)
        end
    end)
end)

-- ============ КОМАНДЫ (полный обработчик) ============
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

    -- !музгром X
    if string.StartWith(low, "!музгром") then
        local arg = string.match(t, "%d*%.?%d+")
        if arg then
            VOL = math.Clamp(tonumber(arg) or 1.0, 0, 1)
            if CURRENT then SendTrack(nil, CURRENT.path, CURRENT.name) end -- применить сразу
            N2("Громкость музыки: " .. string.format("%.2f", VOL) .. " (макс 1.00)")
        else
            N2("Текущая громкость: " .. string.format("%.2f", VOL) .. " (пример: !музгром 1.0)")
        end
        return ""
    end

    -- !музцикл [0|1]
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

    -- !музстоп
    if low == "!музстоп" then
        StopTrack(ply)
        N2("Музыка остановлена. Снова включится после рестарта карты или: !музыка <номер/имя>")
        return ""
    end

    -- !музыка ...
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

-- ставим обработчик ПОСЛЕДНИМ (таймеры позже, чем у v5.8.2/3/4)
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
timer.Simple(24, InstallCmd)

-- ============ СПАВН ПЛЕЕРА (страховка) ============
local function SpawnLoop()
    if ents.FindByClass("polus_p11_musicloop")[1] then return end
    local e = ents.Create("polus_p11_musicloop")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.MAuto.Spawn", function()
    timer.Simple(1, SpawnLoop)
end)
hook.Add("PostCleanupMap", "P11.MAuto.Spawn2", function()
    timer.Simple(3, SpawnLoop)
end)

print("[POLUS-11] МУЗЫКА v5.8.5: АВТО-включение при старте и для каждого заходящего, повтор по кругу")
