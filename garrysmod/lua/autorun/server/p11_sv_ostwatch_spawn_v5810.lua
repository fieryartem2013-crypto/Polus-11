-- ============================================================
--  ПОЛЮС-11 — ГЛАВНЫЙ ТРЕК polus_ost_1: ГАРАНТИЯ v5.8.10 (server)
--  Заявка: «играть должно polus_ost_1.mp3 и повторяться после
--  окончания (песня 13:14)».
--  • polus_ost_1 — ГЛАВНЫЙ трек станции: как только файл появился
--    в sound/polus11/music/, система сама переключается на него
--    (проверка каждые 60 сек — можно кинуть файл БЕЗ рестарта);
--  • пока файла нет — играют демо, но как только появился —
--    включается он;
--  • ПОВТОР ПО КРУГУ (loop=true): после окончания трек играет
--    снова; длительность любая (13:14 — ок);
--  • каждому заходящему — сразу главный трек;
--  • работает на канале P11_MusicPlayV3 (как v5.8.9), ничего не
--    ломает; старые файлы не трогаем.
--
--  ЧТО СДЕЛАТЬ: положи файл
--    garrysmod/sound/polus11/music/polus_ost_1.mp3
--  (латиницей, без пробелов) → всё: он станет главным треком.
-- ============================================================

util.AddNetworkString("P11_MusicPlayV3") -- идемпотентно (уже с v5.8.9)

local OST = "polus_ost_1"

-- найти файл главного трека (любое расширение)
local function OstTrack()
    local files = file.Find("sound/polus11/music/" .. OST .. ".*", "GAME")
    if files and files[1] then
        local ext = string.lower(string.GetExtensionFromFilename(files[1]))
        if ext == "mp3" or ext == "wav" or ext == "ogg" then
            return "sound/polus11/music/" .. files[1], files[1]
        end
    end
    return nil
end

-- что сейчас слышно у любого игрока (по NW-флагу)
local function NowPlayingAny()
    for _, p in ipairs(player.GetAll()) do
        local n = p:GetNWString("P11_MusicNow", "")
        if n ~= "" then return n end
    end
    return ""
end

-- включить главный трек (если ещё не играет)
local function PlayOst()
    local path, name = OstTrack()
    if not path then return false end
    resource.AddFile(path) -- раздаём новым игрокам

    local cur = NowPlayingAny()
    if cur == name then return true end -- уже играет этот трек

    net.Start("P11_MusicPlayV3")
        net.WriteString(path)
        net.WriteFloat(1.0) -- громко
        net.WriteBool(true) -- повтор по кругу
    net.Broadcast()
    for _, p in ipairs(player.GetAll()) do
        p:SetNWString("P11_MusicNow", name)
    end
    print("[POLUS-11][OST] главный трек включён: " .. name .. " (повтор по кругу)")
    return true
end

-- при старте сервера / смене карты
hook.Add("InitPostEntity", "P11.OST.Start", function()
    timer.Simple(4, function()
        if not PlayOst() then
            print("[POLUS-11][OST] polus_ost_1 пока нет — играют демо. Жду файл: sound/polus11/music/polus_ost_1.mp3")
        end
    end)
end)
hook.Add("PostCleanupMap", "P11.OST.Map", function()
    timer.Simple(4, PlayOst)
end)

-- каждому заходящему — сразу главный трек (3.5 сек, побеждает после v589)
hook.Add("PlayerInitialSpawn", "P11.OST.Join", function(ply)
    timer.Simple(3.5, function()
        if not IsValid(ply) then return end
        local path, name = OstTrack()
        if not path then return end
        net.Start("P11_MusicPlayV3")
            net.WriteString(path)
            net.WriteFloat(1.0)
            net.WriteBool(true)
        net.Send(ply)
        ply:SetNWString("P11_MusicNow", name)
    end)
end)

-- каждые 60 сек: как только файл появился — включаем его
timer.Create("P11.OST.Watch", 60, 0, PlayOst)

print("[POLUS-11] OST-WATCH v5.8.10: главный трек polus_ost_1, повтор по кругу")
