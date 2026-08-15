-- ============================================================
--  ПОЛЮС-11 — ГАРАНТИРОВАННОЕ СКАЧИВАНИЕ ТРЕКА v5.8.3 (server)
--  «На всякий случай»: явно регистрирует файл polus_ost_1 для
--  раздачи клиентам (resource.AddFile → игроки скачивают при
--  заходе, один раз, дальше кэш).
--
--  v5.8.2 и так раздаёт ВСЁ из sound/polus11/music/, но этот
--  скрипт — страховка + игра по ИМЕНИ:
--    !музыка polus_ost_1   — найти и сыграть по имени
--    !музыка               — список
--    !музыка 2             — по номеру
--    !музстоп              — стоп
--    !музгром 0.5          — громкость
--  Проверяет появление файла каждые 60 сек (файл можно добавить
--  БЕЗ рестарта — новые игроки его скачают; старые — при
--  перезаходе). Название НЕ зависит от регистра/расширения:
--  polus_ost_1.mp3 / .wav / .ogg — любой.
--
--  ЧТО СДЕЛАТЬ: положи файл в
--    garrysmod/sound/polus11/music/polus_ost_1.mp3
--  (латиницей, без пробелов) и всё — сервер сам раздаст.
-- ============================================================

util.AddNetworkString("P11_MusicPlay") -- idempotent (уже есть с v5.8.2)
util.AddNetworkString("P11_MusicStop")

local TRACK_NAME = "polus_ost_1" -- имя файла БЕЗ расширения
local VOL = 0.6

-- ============ ПОИСК ФАЙЛОВ ============
local function MusicFiles()
    local list = file.Find("sound/polus11/music/*", "GAME") or {}
    local out = {}
    for _, f in ipairs(list) do
        local ext = string.lower(string.GetExtensionFromFilename(f))
        if ext == "mp3" or ext == "wav" or ext == "ogg" then
            out[#out + 1] = f
        end
    end
    table.sort(out)
    return out
end

-- найти полный путь по имени (любое расширение), вернуть path и имя
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

-- ============ ГАРАНТИРОВАННАЯ РАЗДАЧА polus_ost_1 ============
local loggedMissing = false

local function RegisterTrack()
    local path = TrackPathByName(TRACK_NAME)
    if not path then
        if not loggedMissing then
            loggedMissing = true
            print("[POLUS-11][DL] polus_ost_1 пока НЕ НАЙДЕН в sound/polus11/music/")
            print("[POLUS-11][DL] кидай файл (название polus_ost_1.mp3) — сервер сам раздаст клиентам")
        end
        return
    end
    resource.AddFile(path) -- клиенты скачают при заходе
    print("[POLUS-11][DL] polus_ost_1 зарегистрирован для скачивания: " .. path)
end

hook.Add("InitPostEntity", "P11.DL.Start", function()
    timer.Simple(1, RegisterTrack)
end)

-- на всякий случай: каждые 60 сек перепроверяем (файл могли добавить без рестарта)
timer.Create("P11.DL.Scan", 60, 0, RegisterTrack)

-- ============ ПЛЕЕР (прямой бродкаст, путь всегда актуален) ============
local function PlayTrack(ply, path, name)
    net.Start("P11_MusicPlay")
        net.WriteString(path)
        net.WriteFloat(VOL)
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", name)
    end
    for _, p in ipairs(player.GetAll()) do
        p:ChatPrint("♪ Станция играет: «" .. name .. "»")
    end
end

local function StopTrack(ply)
    net.Start("P11_MusicStop")
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", "")
    end
end

-- ============ ОБРАБОТЧИК !музыка (ЗАМЕНА v5.8.2 — с игрой по имени) ============
local function MusicCmdHandler(ply, text)
    local t = string.Trim(text or "")
    local low = string.lower(t)
    if not string.StartWith(low, "!музыка") and not string.StartWith(low, "!музстоп")
        and not string.StartWith(low, "!музгром") then return end

    local isAdmin = IsValid(ply) and (
        (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
        or ply:IsSuperAdmin())
    if not isAdmin then
        if POLUS11.Notify then
            POLUS11.Notify(ply, "Только администрация станции включает музыку.")
        else
            ply:ChatPrint("[Музыка] Только админ.")
        end
        return ""
    end

    local function Notify2(txt)
        if POLUS11.Notify then POLUS11.Notify(ply, txt) else ply:ChatPrint("[Музыка] " .. txt) end
    end

    -- !музгром X
    if string.StartWith(low, "!музгром") then
        local arg = string.match(t, "%d*%.?%d+")
        if arg then
            VOL = math.Clamp(tonumber(arg) or 0.6, 0, 1)
            Notify2("Громкость музыки: " .. string.format("%.1f", VOL))
        else
            Notify2("Текущая громкость: " .. string.format("%.1f", VOL) .. " (пример: !музгром 0.5)")
        end
        return ""
    end

    -- !музстоп
    if low == "!музстоп" then
        StopTrack(ply)
        Notify2("Музыка остановлена.")
        return ""
    end

    -- !музыка
    local rest = string.Trim(string.sub(t, #"!музыка" + 1))
    local files = MusicFiles()

    if rest == "" then
        local cur = ply:GetNWString("P11_MusicNow", "")
        local lines = { "♪ МУЗЫКА СТАНЦИИ (треков: " .. #files .. ")" }
        if #files == 0 then
            lines[#lines + 1] = "Папка sound/polus11/music пуста! Кидай .mp3 и рестарт."
        end
        if cur ~= "" then lines[#lines + 1] = "Сейчас играет: " .. cur end
        for i, f in ipairs(files) do
            lines[#lines + 1] = "  " .. i .. ") " .. f
        end
        ply:ChatPrint(table.concat(lines, "\n"))
        return ""
    end

    local lowRest = string.lower(rest)
    if lowRest == "стоп" then
        StopTrack(ply)
        Notify2("Музыка остановлена.")
        return ""
    end

    -- по номеру
    local n = tonumber(rest)
    if n then
        if files[n] then
            PlayTrack(ply, "sound/polus11/music/" .. files[n], files[n])
        else
            Notify2("Трек №" .. n .. " не найден. Список: !музыка")
        end
        return ""
    end

    -- ПО ИМЕНИ (частичное совпадение, регистр не важен)
    local found = nil
    for _, f in ipairs(files) do
        if string.find(string.lower(f), lowRest, 1, true) then
            found = f
            break
        end
    end
    if not found then
        Notify2("Трек не найден: «" .. rest .. "». Список: !музыка")
        return ""
    end
    PlayTrack(ply, "sound/polus11/music/" .. found, found)
    return ""
end

-- ставим наш обработчик ПОСЛЕДНИМ (v5.8.2 тоже вешает !музыка —
-- переустанавливаем, чтобы наш был активным; повторы через таймер
-- страхуют от порядка загрузки файлов)
local function InstallCmd()
    hook.Remove("PlayerSay", "P11.MusicCmd")
    hook.Add("PlayerSay", "P11.MusicCmd", MusicCmdHandler)
end
InstallCmd()
timer.Simple(1, InstallCmd)
timer.Simple(3, InstallCmd)
timer.Simple(6, InstallCmd)

-- ============ СПАВН ЭНТИТИ-«КУРЬЕРА» (страховка, если ещё нет) ============
local function SpawnCarrier()
    if ents.FindByClass("polus_p11_musicboot")[1] then return end
    local e = ents.Create("polus_p11_musicboot")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.DL.Spawn", function()
    timer.Simple(1, function()
        RegisterTrack()
        SpawnCarrier()
    end)
end)
hook.Add("PostCleanupMap", "P11.DL.Spawn2", function()
    timer.Simple(3, SpawnCarrier)
end)

print("[POLUS-11] СКАЧИВАНИЕ v5.8.3: polus_ost_1 раздаётся клиентам. Добавь файл в sound/polus11/music/")
