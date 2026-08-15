-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА: ГРОМЧЕ + ОДИН РАЗ v5.8.4 (server, autorun)
--  Жалоба: «песня играет очень тихо и повторяется как эмбиент».
--   • ГРОМКОСТЬ по умолчанию = МАКСИМУМ (1.0);
--   • трек играет ОДИН раз (не эмбиент, не по кругу);
--   • повтор по кругу — ТОЛЬКО по команде !музцикл 1 (кому надо
--     фоновую музыку — включает сам);
--   • новый net-канал P11_MusicPlayV2 (флаг loop), старый канал
--     P11_MusicPlay оставляем в покое — всё новыми файлами.
--
--  КОМАНДЫ (админ):
--    !музыка              — список треков + что играет
--    !музыка 2            — играть по номеру
--    !музыка polus_ost_1  — играть по имени (кусок имени)
--    !музыка стоп / !музстоп — остановить
--    !музгром 0..1        — громкость (по умолчанию 1.0 = макс)
--    !музцикл [0|1]       — повтор по кругу вкл/выкл (0 = один раз)
-- ============================================================

util.AddNetworkString("P11_MusicPlayV2") -- клиент-плеер v2 (loop-флаг)

local VOL  = 1.0   -- громкость по умолчанию: МАКСИМУМ
local LOOP = false -- по умолчанию трек играет ОДИН раз

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

-- ============ ПЛЕЕР (новый канал с loop-флагом) ============
local function PlayTrack(ply, path, name)
    net.Start("P11_MusicPlayV2")
        net.WriteString(path)
        net.WriteFloat(VOL)
        net.WriteBool(LOOP)
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", name)
    end
    for _, p in ipairs(player.GetAll()) do
        local txt = "♪ Станция играет: «" .. name .. "»"
        if LOOP then txt = txt .. " (∞ повтор)" end
        p:ChatPrint(txt)
    end
end

local function StopTrack(ply)
    net.Start("P11_MusicStop")
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", "")
    end
end

-- ============ ОБРАБОТЧИК КОМАНД (полный) ============
local function MusicCmdHandler(ply, text)
    local t = string.Trim(text or "")
    local low = string.lower(t)
    if not string.StartWith(low, "!музыка") and not string.StartWith(low, "!музстоп")
        and not string.StartWith(low, "!музгром") and not string.StartWith(low, "!музцикл") then return end

    local isAdmin = IsValid(ply) and (
        (P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(ply))
        or ply:IsSuperAdmin())
    if not isAdmin then
        if POLUS11.Notify then POLUS11.Notify(ply, "Только администрация станции включает музыку.")
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
            N2("Повтор ВКЛ: музыка играет по кругу (эмбиент).")
        elseif string.find(arg, "0") then
            LOOP = false
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
        N2("Музыка остановлена.")
        return ""
    end

    -- !музыка ...
    local files = MusicFiles()
    local rest = string.Trim(string.sub(t, #"!музыка" + 1))

    if rest == "" then
        local cur = ply:GetNWString("P11_MusicNow", "")
        local lines = { "♪ МУЗЫКА СТАНЦИИ (треков: " .. #files .. ")" }
        if #files == 0 then lines[#lines + 1] = "Папка sound/polus11/music пуста! Кидай .mp3 и рестарт." end
        if cur ~= "" then lines[#lines + 1] = "Сейчас играет: " .. cur end
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

-- ============ УСТАНОВКА ОБРАБОТЧИКА (последним, со страховкой) ============
-- v5.8.2 и v5.8.3 тоже вешают PlayerSay на эти команды и
-- переустанавливают себя таймерами (v5.8.3 — до 6 сек). Наш скрипт
-- ставит СВОЙ обработчик на таймерах ПОЗЖЕ (1/2/4/8/12 сек) — в
-- итоге активным остаётся именно этот, с громкостью и циклом.
local function InstallCmd()
    hook.Remove("PlayerSay", "P11.MusicCmd")
    hook.Add("PlayerSay", "P11.MusicCmd", MusicCmdHandler)
end
InstallCmd()
timer.Simple(1, InstallCmd)
timer.Simple(2, InstallCmd)
timer.Simple(4, InstallCmd)
timer.Simple(8, InstallCmd)
timer.Simple(12, InstallCmd)

-- ============ СПАВН НОВОЙ ЭНТИТИ-ПЛЕЕРА (musicloop) ============
local function SpawnLoop()
    if ents.FindByClass("polus_p11_musicloop")[1] then return end
    local e = ents.Create("polus_p11_musicloop")
    if IsValid(e) then
        e:SetPos(Vector(0, 0, -20000))
        e:Spawn()
    end
end

hook.Add("InitPostEntity", "P11.MV.Start", function()
    timer.Simple(1, SpawnLoop)
end)
hook.Add("PostCleanupMap", "P11.MV.Reload", function()
    timer.Simple(3, SpawnLoop)
end)

print("[POLUS-11] МУЗЫКА v5.8.4: громкость 1.0 (макс), трек один раз, повтор по !музцикл")
