-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА v5.8.4 (КЛИЕНТ, энтити musicloop)
--  Плеер v2: sound.PlayFile играет трек ОДИН раз (без повтора),
--  громкость 0..1 из сервера, повтор по кругу — только если
--  сервер прислал loop=true (!музцикл 1).
--    net "P11_MusicPlayV2" { path, vol, loop } — играть
--    net "P11_MusicStop"                          — остановить
--  Индикатор «♪ МУЗЫКА» — уже в musicboot (P11_MusicNow).
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}
P11.MusicSnd = nil

local function StopAny()
    if P11.MusicSnd then
        local ok = pcall(function() P11.MusicSnd:Stop() end)
        if not ok then end
        P11.MusicSnd = nil
    end
end

-- флаг "noplay": сами запустим после настройки громкости
net.Receive("P11_MusicPlayV2", function()
    local path = net.ReadString()
    local vol = net.ReadFloat()
    local loop = net.ReadBool()
    if path == "" then return end

    StopAny()

    sound.PlayFile(path, "noplay", function(snd)
        if not snd then
            print("[POLUS-11][Музыка] не удалось открыть: " .. path)
            return
        end
        snd:SetVolume(math.Clamp(vol, 0, 1))
        snd:EnableLooping(loop) -- false = один раз
        P11.MusicSnd = snd
        snd:Play()
    end)
end)

net.Receive("P11_MusicStop", function()
    StopAny()
end)

-- страховка: если звук закончился сам (не loop) — убрать ссылку
hook.Add("Think", "P11.MusicLoop.Watch", function()
    if P11.MusicSnd then
        local ok = pcall(function() return P11.MusicSnd:IsPlaying() end)
        if ok and not P11.MusicSnd:IsPlaying() then P11.MusicSnd = nil end
    end
end)

print("[POLUS-11] МУЗЫКА v5.8.4: плеер v2 — один раз, громкость с сервера")
