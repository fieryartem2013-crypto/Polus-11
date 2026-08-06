-- ============================================================
--  ПОЛЮС-11 — ЭКОНОМИКА/ИНВЕНТАРЬ (client) v4.0
--  • счётчик рублей на HUD (над панелью жизни);
--  • 🎒 ИНВЕНТАРЬ (C-меню): использовать предмет → оружие в руки;
--  • 🏪 ЛАРЁК (E по НПС): каталог-витрина с ценами, покупка;
--  • 🗄 СЕЙФ (E по ящику): перекладка инвентарь↔сейф;
--  • 📍 РАССТАВИТЬ (админ, C-меню): генератор / терминал / ларёк / сейф.
-- ============================================================

surface.CreateFont("P11.Eco.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.Eco.Med",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Eco.Small", { font = "Roboto", size = 13, weight = 600, extended = true })

P11 = P11 or {}
P11.Eco = P11.Eco or { items = {}, storage = {}, money = 0, catalog = {} }

-- ============ СИНХРОНИЗАЦИЯ ============

net.Receive("P11_InvSync", function()
    local data = util.JSONToTable(net.ReadString() or "") or {}
    P11.Eco.items   = istable(data.items) and data.items or {}
    P11.Eco.storage = istable(data.storage) and data.storage or {}
    P11.Eco.money   = tonumber(data.money) or LocalPlayer():GetNWInt("P11_Money", 0)
    if istable(data.catalog) then P11.Eco.catalog = data.catalog end
    -- живые окна: перерисовать
    if IsValid(P11.EcoFrame) and P11.EcoFrame.Refill then P11.EcoFrame:Refill() end
end)

local function EcoAct(act, id)
    net.Start("P11_InvAct")
        net.WriteUInt(act, 4)
        net.WriteString(id or "")
    net.SendToServer()
end

-- ============ HUD: РУБЛИ ============

local moneyShow = 0
hook.Add("HUDPaint", "P11.EcoMoney", function()
    if P11.IntroOpen then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if IsValid(POLUS11 and POLUS11.Scoreboard) then return end

    local target = math.max(P11.Eco.money or 0, me:GetNWInt("P11_Money", 0))
    moneyShow = moneyShow + (target - moneyShow) * math.min(FrameTime() * 5, 1)
    if math.abs(moneyShow - target) < 1 then moneyShow = target end

    local px, py = 16, ScrH() - 140
    draw.RoundedBox(6, px - 8, py - 6, 150, 30, Color(16, 18, 24, 215))
    draw.SimpleText("₽ " .. math.floor(moneyShow), "P11.Eco.Big", px + 6, py + 9,
        Color(255, 210, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

-- ============ ОБЩИЙ КОНСТРУИТЕЛЬ ОКНА ============

local ACC  = Color(255, 200, 90)
local BG   = Color(16, 18, 24, 242)
local PANE = Color(24, 27, 36, 255)
local TEXT = Color(235, 238, 245)
local DIM  = Color(150, 155, 170)
local OK   = Color(120, 210, 130)
local BAD  = Color(240, 105, 95)

local function EcoFrame(title, w, h)
    if IsValid(P11.EcoFrame) then P11.EcoFrame:Remove() end
    local f = vgui.Create("DFrame")
    P11.EcoFrame = f
    f:SetSize(w, h)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.Paint = function(s, ww, hh)
        Derma_DrawBackgroundBlur(f, 0)
        draw.RoundedBox(10, 0, 0, ww, hh, BG)
        draw.RoundedBoxEx(10, 0, 0, ww, 52, PANE, true, true, false, false)
        surface.SetDrawColor(ACC)
        surface.DrawRect(0, 52, ww, 2)
        -- v4.1: фирменный штрих — градиент под хедером + тэг версии
        for i = 0, 5 do
            surface.SetDrawColor(ACC.r, ACC.g, ACC.b, 24 - i * 4)
            surface.DrawRect(0, 54 + i, ww, 1)
        end
        draw.SimpleText("ПОЛЮС-11 · v" .. (POLUS_BUILD or "4.1"), "P11.Eco.Small", ww - 38, 26,
            DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(title, "P11.Eco.Big", 14, 26, ACC, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("₽ " .. math.floor(P11.Eco.money or 0), "P11.Eco.Big", ww - 14, 26,
            Color(255, 210, 110), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    function f:OnKeyCodePressed(key) if key == KEY_ESCAPE then f:Remove() end end

    local xB = vgui.Create("DButton", f)
    xB:SetPos(w - 36, 12) xB:SetSize(24, 24)
    xB:SetText("✕") xB:SetFont("P11.Eco.Big") xB:SetTextColor(DIM)
    xB.Paint = function() end
    xB.DoClick = function() f:Remove() end
    return f
end

local function RowButton(parent, x, y, w, h, label, col, act)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y) b:SetSize(w, h) b:SetText("")
    b.Paint = function(s, ww, hh)
        draw.RoundedBox(4, 0, 0, ww, hh,
            s:IsHovered() and Color(col.r, col.g, col.b, 80) or Color(col.r, col.g, col.b, 32))
        draw.SimpleText(label, "P11.Eco.Small", ww / 2, hh / 2,
            col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = act
    return b
end

-- ============ 🎒 ИНВЕНТАРЬ ============

function P11.OpenInventory()
    local f = EcoFrame("🎒 ИНВЕНТАРЬ — взятое отсюда ложится в руки", 620, 460)
    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 62) sc:SetSize(596, 386)
    sc:GetVBar():SetWide(5)

    function f:Refill()
        sc:Clear()
        local any = false
        local keys = {}
        for id in pairs(P11.Eco.items) do keys[#keys + 1] = id end
        table.sort(keys)
        for _, id in ipairs(keys) do
            local cnt = P11.Eco.items[id]
            local it = P11.Eco.catalog[id] or { name = id, desc = "", price = 0 }
            any = true
            local pnl = sc:Add("DPanel")
            pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 6) pnl:SetTall(56)
            pnl.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, PANE)
                draw.SimpleText(it.name .. "  ×" .. cnt, "P11.Eco.Med", 12, 16, TEXT)
                draw.SimpleText(it.desc or "", "P11.Eco.Small", 12, 38, DIM)
            end
            RowButton(pnl, 500, 14, 84, 28, "ИСПОЛЬЗОВАТЬ", OK, function()
                EcoAct(1, id)
            end)
        end
        if not any then
            local l = sc:Add("DLabel")
            l:SetFont("P11.Eco.Med") l:SetTextColor(DIM)
            l:SetText("  Пусто. Сходи к ларьку-снабжению — заработок с задач ждёт траты.")
            l:SizeToContents()
        end
    end
    f:Refill()
end

-- ============ 🏪 ЛАРЁК ============

net.Receive("P11_ShopOpen", function()
    local f = EcoFrame("🏪 ЛАРЁК СНАБЖЕНИЯ — армейская витрина", 660, 520)
    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 62) sc:SetSize(636, 446)
    sc:GetVBar():SetWide(5)

    function f:Refill()
        sc:Clear()
        local keys = {}
        for id in pairs(P11.Eco.catalog) do keys[#keys + 1] = id end
        table.sort(keys, function(a, b)
            return (P11.Eco.catalog[a].price or 0) < (P11.Eco.catalog[b].price or 0)
        end)
        for _, id in ipairs(keys) do
            local it = P11.Eco.catalog[id]
            local can = (P11.Eco.money or 0) >= (it.price or 0)
            local pnl = sc:Add("DPanel")
            pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 6) pnl:SetTall(56)
            pnl.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, PANE)
                draw.SimpleText(it.name, "P11.Eco.Med", 12, 16, TEXT)
                draw.SimpleText(it.desc or "", "P11.Eco.Small", 12, 38, DIM)
                draw.SimpleText((it.price or 0) .. "₽", "P11.Eco.Med", w - 148, 28,
                    can and Color(255, 210, 110) or BAD, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            RowButton(pnl, 584, 14, 50, 28, "КУПИТЬ", can and OK or DIM, function()
                EcoAct(2, id)
            end)
        end
        local l = sc:Add("DLabel")
        l:SetFont("P11.Eco.Small") l:SetTextColor(DIM)
        l:SetText("  Купленное падает в 🎒 ИНВЕНТАРЬ (C-меню) — копия переживает смерть и рестарт.")
        l:SizeToContents()
    end
    f:Refill()
end)

-- ============ 🗄 СЕЙФ ============

net.Receive("P11_StorageOpen", function()
    local f = EcoFrame("🗄 ЛИЧНЫЙ СЕЙФ — инвентарь слева, сейф справа", 760, 480)

    local left = vgui.Create("DScrollPanel", f)
    left:SetPos(12, 62) left:SetSize(364, 406)
    left:GetVBar():SetWide(5)
    local right = vgui.Create("DScrollPanel", f)
    right:SetPos(384, 62) right:SetSize(364, 406)
    right:GetVBar():SetWide(5)

    local lh = vgui.Create("DLabel", f)
    lh:SetPos(212, 62 + 0) -- пустышка, заголовки рисуем в Paint
    lh:SetVisible(false)

    local oldPaint = f.Paint
    f.Paint = function(s, w, h)
        oldPaint(s, w, h)
        draw.SimpleText("🎒 ИНВЕНТАРЬ (→ в сейф)", "P11.Eco.Med", 12, 66, ACC)
        draw.SimpleText("🗄 СЕЙФ (→ в инвентарь)", "P11.Eco.Med", 384, 66, Color(140, 200, 250))
    end
    left:SetPos(12, 92) left:SetSize(364, 376)
    right:SetPos(384, 92) right:SetSize(364, 376)

    local function FillBox(scroll, map, act, btnName, col)
        scroll:Clear()
        local keys = {}
        for id in pairs(map) do keys[#keys + 1] = id end
        table.sort(keys)
        local any = false
        for _, id in ipairs(keys) do
            local cnt = map[id]
            local it = P11.Eco.catalog[id] or { name = id }
            any = true
            local pnl = scroll:Add("DPanel")
            pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 6) pnl:SetTall(40)
            pnl.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, PANE)
                draw.SimpleText(it.name .. "  ×" .. cnt, "P11.Eco.Small", 10, h / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            RowButton(pnl, 268, 8, 88, 24, btnName, col, function()
                EcoAct(act, id)
            end)
        end
        if not any then
            local l = scroll:Add("DLabel")
            l:SetFont("P11.Eco.Small") l:SetTextColor(DIM)
            l:SetText("  пусто")
            l:SizeToContents()
        end
    end

    function f:Refill()
        FillBox(left,  P11.Eco.items,   3, "В СЕЙФ →", OK)
        FillBox(right, P11.Eco.storage, 4, "← ЗАБРАТЬ", Color(140, 200, 250))
    end
    f:Refill()
end)

-- ============ 📍 РАССТАНОВКА (админ) ============

function P11.OpenPlaceMenu()
    if not P11FW.Config.Admin(LocalPlayer()) then return end
    local f = EcoFrame("📍 РАССТАВИТЬ ОБЪЕКТЫ — куда смотришь, туда и встанет", 420, 364)
    local roles = {
        { id = "generator", name = "⚡ Генератор",          desc = "старт с полной заправкой" },
        { id = "terminal",  name = "🖥 Сменный терминал",   desc = "допуск: профы с флагом терминала" },
        { id = "shopnpc",   name = "🏪 Ларёк снабжения",    desc = "витрина за рубли (экономика)" },
        { id = "storage",   name = "🗄 Личный сейф",        desc = "общая точка доступа к сейфам" },
        { id = "patrol",    name = "🚩 Пост патруля",       desc = "точка обхода РККА (v4.1)" },
    }
    for i, r in ipairs(roles) do
        local y = 64 + (i - 1) * 56
        RowButton(f, 12, y, 180, 46, r.name, ACC, function()
            net.Start("P11_PlaceEnt")
                net.WriteString(r.id)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            f:Remove()
        end)
        local d = vgui.Create("DLabel", f)
        d:SetPos(200, y + 2) d:SetSize(208, 42) d:SetFont("P11.Eco.Small") d:SetTextColor(DIM)
        d:SetText(r.desc .. "\n(сохранится на карте)")
        d:SetWrap(true) d:SetAutoStretchVertical(true)
    end
end
