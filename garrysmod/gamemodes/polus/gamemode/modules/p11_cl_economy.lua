-- ============================================================
--  ПОЛЮС-11 — ЭКОНОМИКА/ИНВЕНТАРЬ (client) v4.0 → v4.6.9
--  v4.6.9: окно ларька под pcall-бронёй (ошибка пишется в консоль,
--  ларёк не «умирает молча»), телеметрия + p11_ecodiag, клиентская
--  команда p11_shop, кнопка КУПИТЬ больше не обрезана.
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
    -- v4.6.9: телеметрия для p11_ecodiag
    P11.Eco.lastSync = CurTime()
    P11.Eco.syncs = (P11.Eco.syncs or 0) + 1
    -- живые окна: перерисовать
    if IsValid(P11.EcoFrame) and P11.EcoFrame.Refill then P11.EcoFrame:Refill() end
end)

local function EcoAct(act, id)
    net.Start("P11_InvAct")
        net.WriteUInt(act, 4)
        net.WriteString(id or "")
    net.SendToServer()
end

-- ============ HUD: РУБЛИ (v4.2.2 — «золотой кошелёк» НАД панелью жизни) ============
--  Раньше текст висел на ScrH()-140 и залезал ПОД панель ХП (начинается
--  с ScrH()-144). Теперь чип прибит к верху панели жизни через
--  P11.VitalsTop, который vitals выставляет каждый кадр.

local moneyShow = 0
local moneyGlow = 0 -- вспышка «деньги пришли»

hook.Add("HUDPaint", "P11.EcoMoney", function()
    if P11.IntroOpen then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if P11B and P11B.open then return end -- v4.2.1: TAB v2

    local target = math.max(P11.Eco.money or 0, me:GetNWInt("P11_Money", 0))
    if target > moneyShow + 0.5 then moneyGlow = 0.8 end -- приход — блеск
    moneyShow = moneyShow + (target - moneyShow) * math.min(FrameTime() * 5, 1)
    if math.abs(moneyShow - target) < 1 then moneyShow = target end
    local shown = math.floor(moneyShow)

    -- геометрия: строго НАД панелью жизни
    local panelTop = tonumber(P11.VitalsTop) or (ScrH() - 144)
    -- v4.6.3: предохранитель от наложения на полоску жизни — садимся
    -- не ниже, чем на 150px над нижним краем (панель жизни: ~118px).
    panelTop = math.min(panelTop, ScrH() - 150)
    local chH = 30
    local chY = panelTop - 8 - chH

    -- ширина под текст
    surface.SetFont("P11.Eco.Med")
    local numTxt = (string.Comma and string.Comma(shown)) or tostring(shown)
    local numW = surface.GetTextSize(numTxt) or 40
    surface.SetFont("P11.Eco.Small")
    local labTxt = "НАЛИЧНЫЕ"
    local labW = surface.GetTextSize(labTxt) or 40
    local chW = 40 + math.max(numW, labW) + 16
    local chX = 16

    -- экспорт для стека значков мута (vitals)
    P11.EcoMoneyTop = chY

    -- тело чипа
    draw.RoundedBox(8, chX, chY, chW, chH, Color(14, 15, 20, 220))
    draw.RoundedBoxEx(8, chX, chY, 4, chH, Color(255, 205, 100), true, false, true, false)
    -- лёгкий верхний блик
    surface.SetDrawColor(255, 235, 180, 16)
    surface.DrawRect(chX + 4, chY + 1, chW - 5, 1)
    -- контур
    surface.SetDrawColor(255, 205, 100, 40 + 120 * math.max(0, moneyGlow))
    surface.DrawOutlinedRect(chX, chY, chW, chH, 1)

    -- монетка: два кольца + ₽
    local cx, cy, cr = chX + 18, chY + chH / 2, 9
    draw.NoTexture()
    surface.SetDrawColor(60, 45, 18, 255)
    surface.DrawCircle(cx, cy, cr + 1, 60, 45, 18, 255)
    surface.DrawCircle(cx, cy, cr, 230, 185, 95, 255)
    surface.DrawCircle(cx, cy, cr - 3, 200, 150, 70, 255)
    draw.SimpleText("₽", "P11.Eco.Small", cx, cy + 1, Color(70, 50, 16),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- цифра (крупно, золотом; при приходе — вспыхивает)
    local aGlow = math.Clamp(moneyGlow, 0, 1)
    local numCol = Color(255, 210 + 30 * aGlow, 110 + 60 * aGlow)
    draw.SimpleText(numTxt, "P11.Eco.Med", chX + 34, chY + chH / 2 - 6, numCol,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(labTxt, "P11.Eco.Small", chX + 34, chY + chH / 2 + 9,
        Color(165, 150, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    moneyGlow = moneyGlow * math.max(0, 1 - FrameTime() * 2.2)
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

local function OpenShopWindow()
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
                if it.sale then -- v4.2: 🔥 СКИДКА ДНЯ
                    surface.SetDrawColor(255, 170, 60, 60 + 60 * math.abs(math.sin(CurTime() * 3)))
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
                draw.SimpleText(it.name, "P11.Eco.Med", 12, 16, TEXT)
                draw.SimpleText(it.desc or "", "P11.Eco.Small", 12, 38, DIM)
                if it.sale then
                    draw.SimpleText("🔥 −40% ДНЯ", "P11.Eco.Small", w - 230, 28,
                        Color(255, 170, 70), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                draw.SimpleText((it.price or 0) .. "₽", "P11.Eco.Med", w - 148, 28,
                    it.sale and Color(255, 170, 70) or (can and Color(255, 210, 110) or BAD),
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            RowButton(pnl, 572, 14, 60, 28, "КУПИТЬ", can and OK or DIM, function()
                EcoAct(2, id)
            end)
        end
        local l = sc:Add("DLabel")
        l:SetFont("P11.Eco.Small") l:SetTextColor(DIM)
        l:SetText("  Купленное падает в 🎒 ИНВЕНТАРЬ (C-меню) — копия переживает смерть и рестарт.")
        l:SizeToContents()
    end
    f:Refill()
end

net.Receive("P11_ShopOpen", function()
    -- v4.6.9: броня — сбой отрисовки пишется в консоль, ларёк не «умирает» молча
    P11.Eco.shopOpens = (P11.Eco.shopOpens or 0) + 1
    local ok, err = pcall(OpenShopWindow)
    if not ok then print("[POLUS][ERROR] окно ларька: " .. tostring(err)) end
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
    local f = EcoFrame("📍 РАССТАВИТЬ ОБЪЕКТЫ — куда смотришь, туда и встанет", 420, 424)
    local roles = {
        { id = "generator", name = "⚡ Генератор",          desc = "старт с полной заправкой" },
        { id = "terminal",  name = "🖥 Сменный терминал",   desc = "допуск: профы с флагом терминала" },
        { id = "shopnpc",   name = "🏪 Ларёк снабжения",    desc = "витрина за рубли (экономика)" },
        { id = "storage",   name = "🗄 Личный сейф",        desc = "общая точка доступа к сейфам" },
        { id = "patrol",    name = "🚩 Пост патруля",       desc = "точка обхода РККА (v4.1)" },
        { id = "kitchen",   name = "🍲 Полевая кухня",      desc = "плита повара: горячие пайки (v4.2)" },
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

-- ============ v4.6.9: ДИАГНОСТИКА + ЗАПАСНОЙ ПУТЬ ============

concommand.Add("p11_ecodiag", function()
    local lp = LocalPlayer()
    print("== ЭКОНОМИКА: ДИАГНОСТИКА v4.6.9 (клиент) ==")
    print("  [P11ECO] модуль жив, время сессии: " .. math.floor(CurTime()) .. "с")
    print("  кошелёк (синк): " .. tostring(P11.Eco.money)
        .. " | NWInt: " .. (IsValid(lp) and lp:GetNWInt("P11_Money", -1) or "?"))
    print("  в инвентаре позиций: " .. table.Count(P11.Eco.items or {})
        .. " | в сейфе: " .. table.Count(P11.Eco.storage or {}))
    print("  товаров в каталоге: " .. table.Count(P11.Eco.catalog or {}))
    print("  синков инвентаря за сессию: " .. tostring(P11.Eco.syncs or 0)
        .. " | открытий ларька: " .. tostring(P11.Eco.shopOpens or 0))
    print("  последний синк: "
        .. (P11.Eco.lastSync and (math.floor(CurTime() - P11.Eco.lastSync) .. "с назад") or "НЕ БЫЛО"))
    print("  если «синков 0» — сервер не шлёт InvSync: смотри его консоль ([POLUS][ERROR]).")
end)

-- запасная клиентская команда: открыть ларёк у ближайшего торговца
concommand.Add("p11_shop", function()
    net.Start("P11_ShopTry")
    net.SendToServer()
end)

print("[P11ECO] v4.6.9 OK — инвентарь/ларёк/сейф (диагностика: p11_ecodiag, ларёк издалека: p11_shop)")
