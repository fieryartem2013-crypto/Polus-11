-- ============================================================
--  ПОЛЮС-11 — КОНТЕКСТНОЕ МЕНЮ ПО Е v5.8.21 (КЛИЕНТ, энтити emenu)
--  Смотришь на игрока (до ~250 юнитов) и УДЕРЖИВАЕШЬ Е 0.7 сек →
--  открывается меню действий:
--    💰 Передать деньги  👋 Подозвать  📄 Документы
--    💨 Толкнуть  ⭐ Опыт (командиры)  🔫 Случайное оружие
--  Быстрый тап Е — обычное использование (на игроках ничего не
--  делает, на НПС/энтити — как раньше: пропускаем).
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА.
-- ============================================================

P11 = P11 or {}

local HOLD_TIME = 0.7  -- сек удержания до открытия
local E_DIST = 250

local EM = {
    bg    = Color(10, 14, 20, 246),
    panel = Color(22, 29, 42, 255),
    cyan  = Color(120, 185, 255),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    dim   = Color(150, 165, 180),
    ok    = Color(115, 215, 135),
    bad   = Color(235, 100, 90),
    hover = Color(34, 46, 66, 255),
}

surface.CreateFont("P11.EM.Title", { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("P11.EM.Btn",   { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11.EM.Tiny",  { font = "Roboto", size = 12, weight = 500, extended = true })

-- ============ ЦЕЛЬ (игрок в прицеле) ============
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

-- ============ МЕНЮ ============
local MenuFrame = nil

local function CloseMenu()
    if IsValid(MenuFrame) then MenuFrame:Remove() end
    MenuFrame = nil
end

local function SendAction(op, target, amt)
    net.Start("P11_EMenu")
        net.WriteString(op)
        net.WriteEntity(target)
        if amt then net.WriteUInt(amt, 20) end
    net.SendToServer()
    CloseMenu()
end

local function Btn(parent, y, txt, col, fn)
    local b = vgui.Create("DButton", parent)
    b:SetPos(12, y) b:SetSize(236, 34)
    b:SetText("")
    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        draw.RoundedBox(6, 0, 0, ww, hh, hov and EM.hover or EM.panel)
        if hov then
            surface.SetDrawColor(col.r, col.g, col.b, 160)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        end
        draw.SimpleText(txt, "P11.EM.Btn", ww / 2, hh / 2, hov and col or EM.text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("ui/buttonclickrelease.wav")
        fn()
    end
    return b
end

local function OpenMenu(target)
    CloseMenu()
    local me = LocalPlayer()

    local f = vgui.Create("DFrame")
    MenuFrame = f
    f:SetSize(260, 292)
    f:SetPos(math.floor(ScrW() / 2 - 130), math.floor(ScrH() / 2 - 146))
    f:SetTitle("")
    f:SetDraggable(false)
    f:SetSizable(false)
    f:ShowCloseButton(false)
    f:MakePopup()
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then CloseMenu() end
    end

    f.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, EM.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 40, EM.panel, true, true, false, false)
        surface.SetDrawColor(EM.cyan.r, EM.cyan.g, EM.cyan.b, 140)
        surface.DrawRect(0, 40, w, 1)
        draw.SimpleText("🎯 ДЕЙСТВИЯ: " .. target:Nick(), "P11.EM.Title", 12, 20,
            EM.cyan, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- 💰 передать деньги
    Btn(f, 48, "💰 Передать деньги", EM.ok, function()
        if P11.StringRequest then
            P11.StringRequest("💸 ПЕРЕДАТЬ ДЕНЬГИ", "Сколько ₽ передать " .. target:Nick() .. "? (1–50 000)",
                "500", function(txt)
                    local amt = tonumber(txt or "")
                    if amt and amt > 0 then SendAction("money", target, math.floor(amt)) end
                end)
        end
        CloseMenu()
    end)
    -- 👋 подозвать (жест «Сюда!»)
    Btn(f, 86, "👋 Подозвать", EM.cyan, function()
        net.Start("P11_EMenu_Beckon")
        net.SendToServer()
        CloseMenu()
    end)
    -- 📄 документы
    Btn(f, 124, "📄 Показать документы", EM.gold, function()
        SendAction("docs", target)
    end)
    -- 💨 толкнуть
    Btn(f, 162, "💨 Толкнуть", EM.text, function()
        SendAction("push", target)
    end)
    -- ⭐ опыт (командиры)
    Btn(f, 200, "⭐ Выдать опыт (командир)", EM.cyan, function()
        if P11.StringRequest then
            P11.StringRequest("⭐ ОПЫТ СЛУЖБЫ", "Сколько опыта (древо) выдать " .. target:Nick() .. "? (1–1000)",
                "100", function(txt)
                    local amt = tonumber(txt or "")
                    if amt and amt > 0 then SendAction("xp", target, math.floor(amt)) end
                end)
        end
        CloseMenu()
    end)
    -- 🔫 случайное оружие из багажа
    Btn(f, 238, "🔫 Оружие из багажа", EM.bad, function()
        SendAction("gun", target)
    end)
end

-- ============ УДЕРЖАНИЕ Е ============
local HoldState = { down = false, t = 0, opened = false }

hook.Add("PlayerBindPress", "P11.EMenu.Use", function(ply, bind, pressed)
    if bind ~= "+use" then return end
    local target = AimPlayer()
    if pressed then
        if target then
            -- блокируем ванильное использование на игроке, начинаем удержание
            HoldState.down = true
            HoldState.t = CurTime()
            HoldState.opened = false
            return true
        end
        HoldState.down = false
        return nil -- НПС/энтити — как раньше
    else
        HoldState.down = false
        -- отпустили до открытия — ничего не делаем (на игроках use бесполезен)
        if HoldState.opened then
            HoldState.opened = false
        end
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

print("[POLUS-11] E-МЕНЮ v5.8.21: удержать Е на игроке → меню действий")
