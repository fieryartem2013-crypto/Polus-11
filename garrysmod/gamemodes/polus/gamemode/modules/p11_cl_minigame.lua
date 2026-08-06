-- ============================================================
--  ПОЛЮС-11 — МИНИИГРЫ И ПАТРУЛЬ (client) v4.1
--  Окно «нажми клавишу вовремя», маркер следующего поста
--  патруля, счётчик очков науки (RP) у учёных.
-- ============================================================

surface.CreateFont("P11.Mini.Big",   { font = "Roboto", size = 64, weight = 900, extended = true })
surface.CreateFont("P11.Mini.Mid",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11.Mini.Small", { font = "Roboto", size = 15, weight = 500, extended = true })

P11 = P11 or {}
P11.Mini = { active = false, title = "", steps = 0, step = 0, letter = "", untilT = 0, window = 2, hits = 0 }
P11.Patrol = { pts = {}, next = 0 }

local KEY_BY_LETTER = { R = KEY_R, F = KEY_F, T = KEY_T, G = KEY_G }

-- ============ СЕТЬ ============

net.Receive("P11_MiniOpen", function()
    P11.Mini.active = true
    P11.Mini.title  = net.ReadString()
    P11.Mini.steps  = net.ReadUInt(4)
    P11.Mini.step   = 0
    P11.Mini.hits   = 0
    P11.Mini.letter = ""
    surface.PlaySound("buttons/button9.wav")
end)

net.Receive("P11_MiniStep", function()
    P11.Mini.step   = net.ReadUInt(4)
    P11.Mini.letter = net.ReadString()
    P11.Mini.window = net.ReadFloat() or 2
    P11.Mini.untilT = CurTime() + P11.Mini.window
    P11.Mini.sent   = false
    surface.PlaySound("buttons/button17.wav")
end)

net.Receive("P11_MiniEnd", function()
    local ok = net.ReadBool()
    P11.Mini.active = false
    P11.Mini.letter = ""
    surface.PlaySound(ok and "buttons/button15.wav" or "buttons/button10.wav")
end)

net.Receive("P11_PatrolSync", function()
    local ok, data = pcall(util.JSONToTable, net.ReadString() or "{}")
    if ok and istable(data) then
        P11.Patrol.pts  = data.pts or {}
        P11.Patrol.next = data.next or 0
    end
end)

-- ============ НАЖАТИЯ ============

hook.Add("PlayerButtonDown", "P11.MiniKeys", function(ply, btn)
    if ply ~= LocalPlayer() then return end
    local M = P11.Mini
    if not M.active or M.letter == "" or M.sent then return end

    local want = KEY_BY_LETTER[M.letter]
    if btn == want then
        M.sent = true
        M.hits = M.hits + 1
    end
    -- шлём сервер: любую нажатую из набора (он сам судит попадание)
    for letter, key in pairs(KEY_BY_LETTER) do
        if btn == key then
            net.Start("P11_MiniHit")
                net.WriteUInt(M.step, 4)
                net.WriteString(letter)
            net.SendToServer()
            if btn ~= want then M.sent = true end
            return
        end
    end
end)

-- таймаут клиента: окно сгорело — сообщаем промах (сервер дождётся пакет)
hook.Add("Think", "P11.MiniTimeout", function()
    local M = P11.Mini
    if M.active and M.letter ~= "" and not M.sent and CurTime() > M.untilT then
        M.sent = true
        net.Start("P11_MiniHit")
            net.WriteUInt(M.step, 4)
            net.WriteString("-") -- «промазал мимо окна»
        net.SendToServer()
    end
end)

-- ============ РИСОВАНИЕ ============

local function DrawMini(M, w, h)
    local cx, cy = w / 2, h * 0.62

    -- панель
    draw.RoundedBox(10, cx - 200, cy - 96, 400, 190, Color(8, 12, 18, 215))
    surface.SetDrawColor(80, 160, 255, 160)
    surface.DrawOutlinedRect(cx - 200, cy - 96, 400, 190, 2)

    draw.SimpleText(M.title, "P11.Mini.Mid", cx, cy - 74, Color(150, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- точки шагов
    for i = 1, M.steps do
        local x = cx - (M.steps - 1) * 15 + (i - 1) * 30
        local col = Color(70, 80, 95)
        if i < M.step then col = Color(90, 220, 130) end
        if i == M.step then col = Color(255, 210, 110) end
        draw.RoundedBox(6, x - 9, cy - 46, 18, 18, col)
    end

    if M.letter ~= "" then
        local frac = math.Clamp((M.untilT - CurTime()) / math.max(0.1, M.window), 0, 1)

        -- буква
        local col = M.sent and Color(90, 220, 130) or Color(255, 225, 150)
        draw.SimpleTextOutlined(M.letter, "P11.Mini.Big", cx, cy + 26, col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 3, Color(0, 0, 0, 230))

        -- кольцо окна времени (сжимается)
        local r = 40 + 70 * frac
        surface.SetDrawColor(80, 160, 255, 200 * frac + 40)
        for i = 0, 31 do
            local a1 = math.rad(i / 32 * 360) + CurTime()
            local a2 = math.rad((i + 1) / 32 * 360) + CurTime()
            surface.DrawLine(cx + math.cos(a1) * r, cy + 28 + math.sin(a1) * r,
                             cx + math.cos(a2) * r, cy + 28 + math.sin(a2) * r)
        end

        draw.SimpleText("[ " .. M.letter .. " ] — жми!", "P11.Mini.Small", cx, cy + 78,
            Color(220, 225, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("стой на месте…", "P11.Mini.Small", cx, cy + 30,
            Color(160, 170, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function DrawPatrolHUD(w, h)
    local P = P11.Patrol
    if not P or not P.pts or #P.pts == 0 then return end

    -- маркер следующего поста в мире
    if P.next and P.next ~= 0 then
        for _, p in ipairs(P.pts) do
            if p.id == P.next then
                local pos = Vector(p.x, p.y, p.z) + Vector(0, 0, 60)
                local scr = pos:ToScreen()
                if scr.visible then
                    local dist = math.floor(LocalPlayer():GetPos():Distance(Vector(p.x, p.y, p.z)))
                    local pulse = 0.6 + math.sin(CurTime() * 4) * 0.4
                    draw.RoundedBox(6, scr.x - 60, scr.y - 30, 120, 44, Color(10, 14, 20, 200))
                    surface.SetDrawColor(120, 180, 255, 140 + 90 * pulse)
                    surface.DrawOutlinedRect(scr.x - 60, scr.y - 30, 120, 44, 1)
                    draw.SimpleText("🚩 ПОСТ №" .. tostring(p.n), "P11.Mini.Small", scr.x, scr.y - 19,
                        Color(140, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText(dist .. " м", "P11.Mini.Small", scr.x, scr.y - 2,
                        Color(180, 190, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                break
            end
        end
    end

    -- строка статуса патруля (для бойцов, чей курс идёт)
    if (P.next or 0) ~= 0 then
        local total = #P.pts
        local passed = 0
        draw.RoundedBox(6, 16, h - 108, 170, 24, Color(8, 12, 18, 170))
        draw.SimpleText("ПАТРУЛЬ: постов " .. total .. ", иди к маркеру", "P11.Mini.Small", 26, h - 96,
            Color(140, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function DrawRPBadge(w, h)
    local rp = LocalPlayer():GetNWInt("P11_RP", 0)
    if rp <= 0 then return end
    draw.RoundedBox(6, 16, h - 80, 170, 24, Color(8, 12, 18, 170))
    draw.SimpleText("🔬 Наука: " .. rp .. " RP", "P11.Mini.Small", 26, h - 68,
        Color(170, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "P11.MiniHUD", function()
    local w, h = ScrW(), ScrH()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end

    if P11.Mini.active then DrawMini(P11.Mini, w, h) end
    DrawPatrolHUD(w, h)
    DrawRPBadge(w, h)
end)

print("[POLUS-11] клиент миниигр/патруля загружен")
