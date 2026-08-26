-- ============================================================
--  ПОЛЮС-11 — КОНТЕКСТНОЕ МЕНЮ ПО Е v5.8.22 (КЛИЕНТ, энтити emenu)
--  Смотришь на игрока + удерживаешь Е 0.7 сек → КРУГЛОЕ меню
--  (радиальные кнопки вокруг центра) с ПЛАВНЫМ появлением
--  (масштаб + прозрачность + выезд) и плавным сопровождением.
--    💰 Передать  👋 Подозвать  📄 Документы
--    💨 Толкнуть  ⭐ Опыт (командиры)  🔫 Оружие из багажа
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}

local HOLD_TIME = 0.7
local E_DIST = 250

local EM = {
    cyan  = Color(120, 185, 255),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    ok    = Color(115, 215, 135),
    bad   = Color(235, 100, 90),
}

surface.CreateFont("P11.EM.Icon",  { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11.EM.Lbl",   { font = "Roboto", size = 13, weight = 700, extended = true })
surface.CreateFont("P11.EM.Title", { font = "Roboto", size = 17, weight = 800, extended = true })

-- ============ ЦЕЛЬ ============
local function AimPlayer()
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return nil end
    local tr = me:GetEyeTrace()
    local e = tr and tr.Entity
    if IsValid(e) and e:IsPlayer() and e ~= me and e:Alive() then
        if me:GetPos():DistToSqr(e:GetPos()) <= E_DIST * E_DIST then
            return e
        end
    end
    return nil
end

-- ============ МЕНЮ (круглое, плавное) ============
local MENU = nil -- { panel, btns, t0, target }

local function CloseMenu()
    if MENU and IsValid(MENU.panel) then MENU.panel:Remove() end
    MENU = nil
end

local function SendAction(op, target, amt)
    net.Start("P11_EMenu")
        net.WriteString(op)
        net.WriteEntity(target)
        if amt then net.WriteUInt(amt, 20) end
    net.SendToServer()
    CloseMenu()
end

-- действия: иконка, подпись, цвет
local ACTIONS = {
    { icon = "💰", lbl = "Деньги", col = EM.ok },
    { icon = "👋", lbl = "Подозвать", col = EM.cyan },
    { icon = "📄", lbl = "Документы", col = EM.gold },
    { icon = "💨", lbl = "Толкнуть", col = EM.text },
    { icon = "⭐", lbl = "Опыт", col = EM.cyan },
    { icon = "🔫", lbl = "Оружие", col = EM.bad },
}

local function OpenMenu(target)
    CloseMenu()

    -- полноэкранный прозрачный слой (ловит клики, гасит фон чуть-чуть)
    local p = vgui.Create("DPanel")
    p:SetPos(0, 0) p:SetSize(ScrW(), ScrH())
    p:SetKeyboardInputEnabled(true)
    p:SetMouseInputEnabled(true)
    p:MakePopup()
    MENU = { panel = p, t0 = CurTime(), target = target, btns = {}, cx = ScrW() / 2, cy = ScrH() / 2 }
    p.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then CloseMenu() end
    end

    local cx, cy = ScrW() / 2, ScrH() / 2
    local R = 138 -- радиус кнопок

    p.Paint = function(s, w, h)
        -- плавное появление: 0..1 за 0.22с (easeOutCubic)
        local el = CurTime() - MENU.t0
        local k = math.Clamp(el / 0.22, 0, 1)
        local e = 1 - (1 - k) * (1 - k) * (1 - k)
        local a = math.floor(235 * e)

        -- центр (следит за мышью через Think)
        local pcx = MENU.cx or (w / 2)
        local pcy = MENU.cy or (h / 2)

        -- затемнение фона (мягкое)
        surface.SetDrawColor(0, 0, 0, math.floor(70 * e))
        surface.DrawRect(0, 0, w, h)

        -- круг-подложка
        surface.SetDrawColor(20, 26, 40, math.floor(225 * e))
        surface.DrawCircle(pcx, pcy, R + 44, 20, 26, 40, math.floor(225 * e))
        surface.SetDrawColor(120, 185, 255, math.floor(150 * e))
        surface.DrawCircle(pcx, pcy, R + 44, 120, 185, 255, math.floor(150 * e))

        -- заголовок по центру
        surface.SetAlphaMultiplier(e)
        draw.SimpleText(MENU.target:Nick(), "P11.EM.Title", pcx, pcy - R - 60,
            Color(255, 205, 110, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        surface.SetAlphaMultiplier(1)
    end

    -- радиальные кнопки
    for i, act in ipairs(ACTIONS) do
        local ang = (i - 1) * (360 / #ACTIONS) - 90 -- с верхней, по кругу
        local rad = math.rad(ang)
        local bx = cx + math.cos(rad) * R - 30
        local by = cy + math.sin(rad) * R - 30

        local b = vgui.Create("DButton", p)
        b:SetPos(bx, by) b:SetSize(60, 60)
        b:SetText("")
        b.Act = act
        b.BaseX, b.BaseY = bx, by
        b.Paint = function(s, ww, hh)
            local el = CurTime() - MENU.t0
            local k = math.Clamp(el / 0.22, 0, 1)
            local e = 1 - (1 - k) * (1 - k) * (1 - k)
            local hov = s:IsHovered()
            local c = s.Act.col
            -- плавный выезд кнопок из центра
            local dr = (1 - e) * 34
            local ox = math.cos(rad) * dr
            local oy = math.sin(rad) * dr
            s:SetPos(s.BaseX - ox, s.BaseY - oy)

            surface.SetAlphaMultiplier(e)
            draw.RoundedBox(14, 0, 0, ww, hh,
                hov and Color(c.r, c.g, c.b, 120) or Color(28, 36, 52, 230))
            if hov then
                surface.SetDrawColor(c.r, c.g, c.b, 220)
                surface.DrawOutlinedRect(0, 0, ww, hh, 2)
            else
                surface.SetDrawColor(c.r, c.g, c.b, 90)
                surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            end
            draw.SimpleText(s.Act.icon, "P11.EM.Icon", ww / 2, hh / 2 - 6,
                Color(240, 248, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(s.Act.lbl, "P11.EM.Lbl", ww / 2, hh - 8,
                hov and Color(255, 255, 255, 255) or c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetAlphaMultiplier(1)
        end
        b.DoClick = function()
            surface.PlaySound("ui/buttonclickrelease.wav")
            if i == 1 then
                if P11.StringRequest then
                    P11.StringRequest("💸 ПЕРЕДАТЬ ДЕНЬГИ", "Сколько ₽ передать " .. MENU.target:Nick() .. "? (1–50 000)",
                        "500", function(txt)
                            local amt = tonumber(txt or "")
                            if amt and amt > 0 then SendAction("money", MENU.target, math.floor(amt)) end
                        end)
                end
                CloseMenu()
            elseif i == 2 then
                net.Start("P11_EMenu_Beckon")
                net.SendToServer()
                CloseMenu()
            elseif i == 3 then
                SendAction("docs", MENU.target)
            elseif i == 4 then
                SendAction("push", MENU.target)
            elseif i == 5 then
                if P11.StringRequest then
                    P11.StringRequest("⭐ ОПЫТ СЛУЖБЫ", "Сколько опыта (древо) выдать " .. MENU.target:Nick() .. "? (1–1000)",
                        "100", function(txt)
                            local amt = tonumber(txt or "")
                            if amt and amt > 0 then SendAction("xp", MENU.target, math.floor(amt)) end
                        end)
                end
                CloseMenu()
            else
                SendAction("gun", MENU.target)
            end
        end
        table.insert(MENU.btns, b)
    end

    -- плавное сопровождение: меню мягко дрейфует за движением мыши
    local lastX, lastY = ScrW() / 2, ScrH() / 2
    p.Think = function(s)
        local mx, my = gui.MousePos()
        -- плавное движение (lerp), без рывков
        local ncx = Lerp(0.12, cx + (mx - cx) * 0.06, cx)
        local ncy = Lerp(0.12, cy + (my - cy) * 0.06, cy)
        -- перемещаем кнопки следом
        for idx, b in ipairs(MENU.btns) do
            local a = (idx - 1) * (360 / #ACTIONS) - 90
            local rr = math.rad(a)
            b.BaseX = ncx + math.cos(rr) * R - 30
            b.BaseY = ncy + math.sin(rr) * R - 30
        end
        -- центр для отрисовки
        MENU.cx, MENU.cy = ncx, ncy
        lastX, lastY = ncx, ncy
    end
end

-- ============ УДЕРЖАНИЕ Е ============
local HoldState = { down = false, t = 0, opened = false }

hook.Add("PlayerBindPress", "P11.EMenu.Use", function(ply, bind, pressed)
    if bind ~= "+use" then return end
    local target = AimPlayer()
    if pressed then
        if target then
            HoldState.down = true
            HoldState.t = CurTime()
            HoldState.opened = false
            return true
        end
        HoldState.down = false
        return nil
    else
        HoldState.down = false
    end
end)

hook.Add("Think", "P11.EMenu.Hold", function()
    if not HoldState.down then return end
    local target = AimPlayer()
    if not target then
        HoldState.down = false
        return
    end
    if not HoldState.opened and CurTime() - HoldState.t >= HOLD_TIME then
        HoldState.opened = true
        OpenMenu(target)
    end
end)

-- жест «Сюда!» от сервера (подозвать)
net.Receive("P11_EMenu_Emote", function()
    local id = net.ReadUInt(4)
    net.Start("P11_Emote")
        net.WriteUInt(id, 4)
    net.SendToServer()
end)

print("[POLUS-11] E-МЕНЮ v5.8.22: круглое, плавное появление и сопровождение")
