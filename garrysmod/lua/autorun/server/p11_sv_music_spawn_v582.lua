-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА НА СТАНЦИИ v5.8.2 (server, autorun)
--  Как добавить трек:
--    1) кидаешь файл .mp3 (или .wav) в garrysmod/sound/polus11/music/
--    2) НАЗВАНИЕ латиницей, без пробелов: naprimer_trek.mp3
--    3) рестарт сервера (или смена карты)
--  Сервер САМ находит все файлы в этой папке, раздаёт их всем
--  клиентам (resource.AddFile — скачиваются при заходе, один раз)
--  и играет по команде.
--
--  КОМАНДЫ (админ / суперадмин):
--    !музыка          — список треков + текущий
--    !музыка 2        — играть трек №2 всем
--    !музыка стоп     — остановить
--    !музстоп         — то же
--    !музгром 0.6     — громкость 0..1 (по умолчанию 0.6)
--
--  Играет у каждого на клиенте (станционное радио в ушах).
--  Старые файлы НЕ трогаем. Также спавнит энтити polus_p11_musicboot
--  (клиентский плеер + индикатор «♪ МУЗЫКА»).
-- ============================================================

util.AddNetworkString("P11_MusicPlay")  -- сервер -> клиент: играть {path, vol}
util.AddNetworkString("P11_MusicStop")  -- сервер -> клиент: стоп

-- ============ СБОР СПИСКА ТРЕКОВ (sound/polus11/music/) ============
local function ScanTracks()
    local tracks = {}
    local files = file.Find("sound/polus11/music/*", "GAME")
    if files then
        for _, f in ipairs(files) do
            local ext = string.lower(string.GetExtensionFromFilename(f))
            if ext == "mp3" or ext == "wav" or ext == "ogg" then
                -- важные файлы раздаём клиентам: они скачаются при заходе
                resource.AddFile("sound/polus11/music/" .. f)
                tracks[#tracks + 1] = f
            end
        end
    end
    table.sort(tracks)
    return tracks
end

-- пересканирование по таймеру (на случай, если файлы добавили без рестарта)
local TRACKS = ScanTracks()
timer.Create("P11.MusicScan", 300, 0, function()
    TRACKS = ScanTracks()
end)

-- ============ ПАРАМЕТРЫ ============
local VOLUME = 0.6 -- громкость по умолчанию

local function AdminOf(ply)
    return IsValid(ply) and (
        (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
        or ply:IsSuperAdmin()
    )
end

local function Notify(ply, txt)
    if POLUS11.Notify then
        POLUS11.Notify(ply, txt)
    else
        ply:ChatPrint("[Музыка] " .. txt)
    end
end

-- ============ ИГРА/СТОП ============
function POLUS11.MusicStop()
    net.Start("P11_MusicStop")
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", "")
    end
end

function POLUS11.MusicPlay(id, vol)
    if not TRACKS[id] then return false end
    local path = "sound/polus11/music/" .. TRACKS[id]
    vol = vol or VOLUME
    net.Start("P11_MusicPlay")
        net.WriteString(path)
        net.WriteFloat(vol)
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", TRACKS[id])
    end
    return true
end

-- ============ КОМАНДЫ ============
hook.Add("PlayerSay", "P11.MusicCmd", function(ply, text)
    local t = string.Trim(text or "")
    local low = string.lower(t)
    if not string.StartWith(low, "!музыка") and not string.StartWith(low, "!музстоп")
        and not string.StartWith(low, "!музгром") then return end

    if not AdminOf(ply) then
        Notify(ply, "Только администрация станции включает музыку.")
        return ""
    end

    -- !музгром X
    if string.StartWith(low, "!музгром") then
        local arg = string.match(t, "%d*%.?%d+")
        if arg then
            VOLUME = math.Clamp(tonumber(arg) or 0.6, 0, 1)
            Notify(ply, "Громкость музыки: " .. string.format("%.1f", VOLUME))
        else
            Notify(ply, "Текущая громкость: " .. string.format("%.1f", VOLUME) .. " (пример: !музгром 0.5)")
        end
        return ""
    end

    -- !музстоп
    if low == "!музстоп" then
        POLUS11.MusicStop()
        Notify(ply, "Музыка остановлена.")
        return ""
    end

    -- !музыка [N | стоп]
    local rest = string.Trim(string.sub(t, #"!музыка" + 1))
    if rest == "" then
        local list = {}
        for i, f in ipairs(TRACKS) do
            list[#list + 1] = "  " .. i .. ") " .. f
        end
        local cur = ply:GetNWString("P11_MusicNow", "")
        local msg = "♪ МУЗЫКА СТАНЦИИ (треков: " .. #TRACKS .. ")"
            .. (#TRACKS == 0 and " — папка sound/polus11/music пуста! Кидай .mp3 и рестарт." or "")
            .. (cur ~= "" and ("\nСейчас играет: " .. cur) or "")
            .. "\n" .. table.concat(list, "\n")
        ply:ChatPrint(msg)
        return ""
    end

    local lowRest = string.lower(rest)
    if lowRest == "стоп" or lowRest == "стоп" then
        POLUS11.MusicStop()
        Notify(ply, "Музыка остановлена.")
        return ""
    end

    local n = tonumber(rest)
    if n and TRACKS[n] then
        if POLUS11.MusicPlay(n, VOLUME) then
            local all = "♪ Станция играет: «" .. TRACKS[n] .. "»"
            for _, p in ipairs(player.GetAll()) do
                p:ChatPrint(all)
            end
        end
        return ""
    end

    Notify(ply, "Трек не найден. Смотри список: !музыка")
    return ""
end)

-- ============ СПАВН ЭНТИТИ-«КУРЬЕРА» (клиентский плеер) ============
local function SpawnCarrier()
    if ents.FindByClass("polus_p11_musicboot")[1] then return end
    local e = ents.Create("polus_p11_musicboot")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.Music.Start", function()
    timer.Simple(0.5, function()
        SpawnCarrier()
    end)
end)
hook.Add("PostCleanupMap", "P11.Music.Reload", function()
    timer.Simple(3, SpawnCarrier)
end)

print("[POLUS-11] МУЗЫКА v5.8.2: треков найдено — " .. #TRACKS
    .. " (sound/polus11/music). Команды: !музыка [N|стоп], !музстоп, !музгром X")
