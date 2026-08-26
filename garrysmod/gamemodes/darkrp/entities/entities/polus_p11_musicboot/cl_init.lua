-- ============================================================
--  ПОЛЮС-11 — МУЗЫКА СТАНЦИИ v5.8.2 (КЛИЕНТ, энтити musicboot)
--  Приём команд сервера и игра треков (станционное радио):
--    net "P11_MusicPlay" { path, vol } — играть
--    net "P11_MusicStop"              — остановить
--  HUD-индикатор «♪ МУЗЫКА: <трек>» внизу справа, пока играет.
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}
P11.MusicSnd = nil

-- ============ ПЛЕЕР ============
net.Receive("P11_MusicPlay", function()
    local path = net.ReadString()
    local vol = net.ReadFloat()
    if path == "" then return end

    if IsValid(P11.MusicSnd) then
        P11.MusicSnd:Stop()
        P11.MusicSnd = nil
    end

    local s = Sound(path) -- CDSound: играет скачанный с сервера файл
    s:SetVolume(math.Clamp(vol, 0, 1))
    s:Play()
    P11.MusicSnd = s
end)

net.Receive("P11_MusicStop", function()
    if IsValid(P11.MusicSnd) then
        P11.MusicSnd:Stop()
        P11.MusicSnd = nil
    end
end)

-- страховка: если звук закончился сам — снять индикатор
hook.Add("Think", "P11.Music.Watch", function()
    if not IsValid(P11.MusicSnd) then return end
    if not P11.MusicSnd:IsPlaying() then
        P11.MusicSnd = nil
    end
end)

-- ============ ИНДИКАТОР «♪ МУЗЫКА» ============
hook.Add("HUDPaint", "P11.Music.HUD", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local now = me:GetNWString("P11_MusicNow", "")
    if now == "" then return end

    local a = 190 + math.sin(CurTime() * 2.6) * 60
    draw.SimpleText("♪ МУЗЫКА СТАНЦИИ", "P11.HUD.Text", ScrW() - 14, ScrH() - 118,
        Color(255, 205, 110, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(now, "P11.HUD.Text", ScrW() - 14, ScrH() - 94,
        Color(200, 215, 230, math.max(120, a - 60)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)

print("[POLUS-11] МУЗЫКА v5.8.2: клиентский плеер станции готов")
