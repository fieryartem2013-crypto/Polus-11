-- ============================================================
--  ПОЛЮС-11 — ФОНОВАЯ МУЗЫКА v5.8.9 (КЛИЕНТ, энтити musicv3)
--  Плеер v3 — железобетонный:
--   1) сначала sound.PlayFile (поддерживает loop) — играет
--      скачанный с сервера файл;
--   2) если не удалось — fallback через CDSound (Sound(path)),
--      при loop=true сам перезапускает по окончании;
--   3) индикатор «♪ МУЗЫКА СТАНЦИИ» внизу справа.
--  Каналы: P11_MusicPlayV3 { path, vol, loop } / P11_MusicStop.
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}
P11.MusicSnd = nil
P11.MusicLoop = false

local function StopAny()
    if P11.MusicSnd then
        pcall(function() P11.MusicSnd:Stop() end)
        P11.MusicSnd = nil
    end
end

local function PlayViaCDSound(path, vol, loop)
    -- fallback: CDSound (не умеет loop — перезапускаем вручную)
    local ok, snd = pcall(Sound, path)
    if not ok or not snd then return false end
    snd:SetVolume(math.Clamp(vol, 0, 1))
    snd:Play()
    P11.MusicSnd = snd
    P11.MusicLoop = loop
    return true
end

net.Receive("P11_MusicPlayV3", function()
    local path = net.ReadString()
    local vol = net.ReadFloat()
    local loop = net.ReadBool()
    if path == "" then return end

    StopAny()

    sound.PlayFile(path, "noplay", function(snd)
        if not snd then
            -- не открылся через PlayFile — пробуем CDSound
            if not PlayViaCDSound(path, vol, loop) then
                print("[POLUS-11][Музыка] не удалось открыть: " .. path)
            end
            return
        end
        snd:SetVolume(math.Clamp(vol, 0, 1))
        snd:EnableLooping(loop)
        P11.MusicSnd = snd
        P11.MusicLoop = loop
        snd:Play()
    end)
end)

net.Receive("P11_MusicStop", function()
    StopAny()
end)

-- страховка: если звук закончился, а loop включён (CDSound fallback) — перезапустить
hook.Add("Think", "P11.MusicV3.Watch", function()
    if not P11.MusicSnd then return end
    local ok = pcall(function() return P11.MusicSnd:IsPlaying() end)
    if ok and not P11.MusicSnd:IsPlaying() then
        local s = P11.MusicSnd
        if P11.MusicLoop and s.Restart then
            pcall(function() s:Restart() end)
        else
            P11.MusicSnd = nil
        end
    end
end)

-- индикатор «♪ МУЗЫКА»
hook.Add("HUDPaint", "P11.MusicV3.HUD", function()
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

print("[POLUS-11] МУЗЫКА v5.8.9: плеер v3 готов (sound.PlayFile + fallback CDSound)")
