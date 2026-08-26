-- ============================================================
--  ПОЛЮС-11 — ФОНОВАЯ МУЗЫКА (ЭМБИЕНТ) v5.8.6 — КЛИЕНТ
--  Плеер: sound.PlayFile + EnableLooping(loop) — играет по
--  кругу (эмбиент-фон станции), громкость с сервера.
--    net "P11_MusicPlayV2" { path, vol, loop }
--    net "P11_MusicStop"
--  Индикатор «♪ МУЗЫКА» — внизу справа, пока играет.
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}
P11.MusicSnd = nil

local function StopAny()
    if P11.MusicSnd then
        pcall(function() P11.MusicSnd:Stop() end)
        P11.MusicSnd = nil
    end
end

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
        snd:EnableLooping(loop) -- true = эмбиент по кругу
        P11.MusicSnd = snd
        snd:Play()
    end)
end)

net.Receive("P11_MusicStop", function()
    StopAny()
end)

-- страховка: если звук закончился (loop выключен) — убрать ссылку
hook.Add("Think", "P11.MusicBG.Watch", function()
    if P11.MusicSnd then
        local ok = pcall(function() return P11.MusicSnd:IsPlaying() end)
        if ok and not P11.MusicSnd:IsPlaying() then P11.MusicSnd = nil end
    end
end)

-- индикатор
hook.Add("HUDPaint", "P11.MusicBG.HUD", function()
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

print("[POLUS-11] МУЗЫКА-ГЕЙММОД v5.8.6: клиентский плеер (эмбиент, loop) готов")
