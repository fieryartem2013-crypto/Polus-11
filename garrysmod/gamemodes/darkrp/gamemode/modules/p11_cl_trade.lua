-- ============================================================
--  ПОЛЮС-11 — ОБМЕН (торговля игрок ↔ игрок) (client) v4.6.9
--  Окно сделки: слева твой инвентарь (клик — положить), середина
--  твоё предложение (+₽), справа предложение партнёра. Сделка
--  исполняется сервером, КОГДА ОБА жмут «ГОТОВ». Любая правка
--  предложения сбрасывает обе готовности — подменить перед
--  нажатием не выйдет. Разбежались/погибли — обмен рвётся сам.
--  Открыть: C-меню → 🤝 Обмен, или чатом /обмен.
-- ============================================================

P11 = P11 or {}

-- состояние текущего обмена (ведёт сервер, мы лишь отражаем)
P11.Trade = P11.Trade or {
    active = false,
    partnerSid = "", partnerName = "",
    myOffer = { items = {}, money = 0 },
    theirOffer = { items = {}, money = 0 },
    myReady = false, theirReady = false,
}

local TT = {
    bg   = Color(14, 17, 23, 245),
    pane = Color(23, 27, 36, 255),
    acc  = Color(120, 205, 160),
    gold = Color(255, 205, 110),
    text = Color(233, 236, 244),
    dim  = Color(150, 155, 170),
    ok   = Color(120, 215, 135),
    bad  = Color(240, 105, 95),
}

local function TSend(op, writer)
    net.Start("P11_TradeNet")
        net.WriteUInt(op, 4)
        if writer then writer() end
    net.SendToServer()
end

local function SendMyOffer()
    TSend(3, function()
        net.WriteString(util.TableToJSON(P11.Trade.myOffer.items) or "{}")
        net.WriteUInt(math.max(0, math.floor(P11.Trade.myOffer.money or 0)), 24)
    end)
end

local function ItemName(id)
    local it = P11.Eco and P11.Eco.catalog and P11.Eco.catalog[id]
    return (it and it.name) or id
end

-- ============ ОКНО ОБМЕНА ============

function P11.OpenTradeWindow()
    if IsValid(P11.TradeFrame) then P11.TradeFrame:Remove() end
    local f = vgui.Create("DFrame")
    P11.TradeFrame = f
    f:SetSize(880, 560)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, 0)
        draw.RoundedBox(10, 0, 0, w, h, TT.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 52, TT.pane, true, true, false, false)
        surface.SetDrawColor(TT.acc)
        surface.DrawRect(0, 52, w, 2)
        draw.SimpleText("🤝 ОБМЕН  ·  партнёр: " .. P11.Trade.partnerName, "P11.Eco.Big",
            14, 26, TT.acc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("правка предложения сбрасывает «ГОТОВ» у обоих", "P11.Eco.Small",
            w - 14, 26, TT.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    f.OnRemove = function() P11.TradeFrame = nil end

    -- заголовки трёх колонок
    local heads = {
        { x = 14,  w = 300, t = "🎒 ТВОЙ ИНВЕНТАРЬ (клик — положить в обмен)", c = TT.text },
        { x = 324, w = 250, t = "➡ ТЫ ОТДАЁШЬ",  c = TT.gold },
        { x = 584, w = 282, t = "⬅ ОН ОТДАЁТ",   c = TT.acc },
    }
    for _, hd in ipairs(heads) do
        local l = vgui.Create("DLabel", f)
        l:SetPos(hd.x, 60) l:SetSize(hd.w, 16)
        l:SetFont("P11.Eco.Small") l:SetTextColor(hd.c) l:SetText(hd.t)
    end

    local invSC = vgui.Create("DScrollPanel", f)
    invSC:SetPos(14, 80) invSC:SetSize(300, 428)
    invSC:GetVBar():SetWide(5)

    local mySC = vgui.Create("DScrollPanel", f)
    mySC:SetPos(324, 80) mySC:SetSize(250, 380)
    mySC:GetVBar():SetWide(5)

    local theirSC = vgui.Create("DScrollPanel", f)
    theirSC:SetPos(584, 80) theirSC:SetSize(282, 380)
    theirSC:GetVBar():SetWide(5)

    -- ₽ в моём предложении
    local mLab = vgui.Create("DLabel", f)
    mLab:SetPos(324, 464) mLab:SetSize(250, 16)
    mLab:SetFont("P11.Eco.Small") mLab:SetTextColor(TT.gold)

    local mEnt = vgui.Create("DTextEntry", f)
    mEnt:SetPos(324, 482) mEnt:SetSize(160, 26)
    mEnt:SetNumeric(true)
    mEnt:SetPlaceholderText("₽ к обмену")

    local mBtn = vgui.Create("DButton", f)
    mBtn:SetPos(488, 482) mBtn:SetSize(86, 26) mBtn:SetText("")
    mBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h,
            s:IsHovered() and Color(TT.gold.r, TT.gold.g, TT.gold.b, 80) or Color(TT.gold.r, TT.gold.g, TT.gold.b, 32))
        draw.SimpleText("ЗАЛОЖИТЬ", "P11.Eco.Small", w / 2, h / 2, TT.gold,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    mBtn.DoClick = function()
        local v = math.max(0, math.floor(tonumber(mEnt:GetValue()) or 0))
        v = math.min(v, math.floor(P11.Eco.money or 0))
        P11.Trade.myOffer.money = v
        mEnt:SetValue("")
        SendMyOffer()
        surface.PlaySound("buttons/button9.wav")
    end

    -- статус сделки (слева внизу)
    local statusL = vgui.Create("DLabel", f)
    statusL:SetPos(14, 516) statusL:SetSize(560, 40)
    statusL:SetFont("P11.Eco.Small") statusL:SetTextColor(TT.dim)
    statusL:SetWrap(true) statusL:SetAutoStretchVertical(true)

    -- ГОТОВ / ОТМЕНА (справа внизу)
    local readyB = vgui.Create("DButton", f)
    readyB:SetPos(584, 472) readyB:SetSize(282, 40) readyB:SetText("")
    readyB.Paint = function(s, w, h)
        local on = P11.Trade.myReady
        local col = on and TT.ok or TT.acc
        draw.RoundedBox(6, 0, 0, w, h,
            s:IsHovered() and Color(col.r, col.g, col.b, 90) or Color(col.r, col.g, col.b, 40))
        draw.RoundedBox(6, 0, 0, 4, h, col, true, false, true, false)
        draw.SimpleText(on and "✔ Я ГОТОВ (ждём партнёра)" or "ГОТОВ К ОБМЕНУ",
            "P11.Eco.Med", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    readyB.DoClick = function()
        TSend(4, function() net.WriteBool(not P11.Trade.myReady) end)
        surface.PlaySound("buttons/button9.wav")
    end

    local cancelB = vgui.Create("DButton", f)
    cancelB:SetPos(584, 518) cancelB:SetSize(282, 28) cancelB:SetText("")
    cancelB.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h,
            s:IsHovered() and Color(TT.bad.r, TT.bad.g, TT.bad.b, 70) or Color(TT.bad.r, TT.bad.g, TT.bad.b, 28))
        draw.SimpleText("✖ ОТМЕНИТЬ ОБМЕН", "P11.Eco.Small", w / 2, h / 2, TT.bad,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    cancelB.DoClick = function() TSend(5, function() end) end

    -- ---- наполнение ----
    function f:Refill()
        -- левая колонка: что можно выложить
        invSC:Clear()
        local keys = {}
        for id in pairs(P11.Eco.items or {}) do keys[#keys + 1] = id end
        table.sort(keys)
        local any = false
        for _, id in ipairs(keys) do
            local owned = tonumber(P11.Eco.items[id]) or 0
            local inOff = tonumber(P11.Trade.myOffer.items[id]) or 0
            local left = owned - inOff
            if left > 0 then
                any = true
                local row = invSC:Add("DButton")
                row:Dock(TOP) row:DockMargin(0, 0, 0, 4) row:SetTall(28) row:SetText("")
                local nm = ItemName(id)
                row.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h,
                        s:IsHovered() and Color(255, 255, 255, 26) or TT.pane)
                    draw.SimpleText(nm, "P11.Eco.Small", 8, h / 2, TT.text,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("×" .. left .. "  ➕", "P11.Eco.Small", w - 8, h / 2,
                        TT.ok, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                row.DoClick = function()
                    local o = tonumber(P11.Eco.items[id]) or 0
                    local cur = tonumber(P11.Trade.myOffer.items[id]) or 0
                    if cur < o then
                        P11.Trade.myOffer.items[id] = cur + 1
                        SendMyOffer()
                        surface.PlaySound("buttons/button9.wav")
                    end
                end
            end
        end
        if not any then
            local l = invSC:Add("DLabel")
            l:SetFont("P11.Eco.Small") l:SetTextColor(TT.dim)
            l:SetText("  (пусто — или всё уже заложено в обмен)")
            l:SizeToContents()
        end

        -- середина: моё предложение (клик — убрать штуку)
        mySC:Clear()
        local mkeys = {}
        for id in pairs(P11.Trade.myOffer.items or {}) do mkeys[#mkeys + 1] = id end
        table.sort(mkeys)
        for _, id in ipairs(mkeys) do
            local cnt = tonumber(P11.Trade.myOffer.items[id]) or 0
            if cnt > 0 then
                local row = mySC:Add("DButton")
                row:Dock(TOP) row:DockMargin(0, 0, 0, 4) row:SetTall(28) row:SetText("")
                local nm = ItemName(id)
                row.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h,
                        s:IsHovered() and Color(TT.gold.r, TT.gold.g, TT.gold.b, 30) or Color(TT.gold.r, TT.gold.g, TT.gold.b, 14))
                    draw.SimpleText(nm .. "  ×" .. cnt, "P11.Eco.Small", 8, h / 2, TT.gold,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("➖", "P11.Eco.Small", w - 8, h / 2, TT.bad,
                        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                row.DoClick = function()
                    local cur = tonumber(P11.Trade.myOffer.items[id]) or 0
                    cur = cur - 1
                    if cur <= 0 then
                        P11.Trade.myOffer.items[id] = nil
                    else
                        P11.Trade.myOffer.items[id] = cur
                    end
                    SendMyOffer()
                    surface.PlaySound("buttons/button9.wav")
                end
            end
        end

        -- справа: предложение партнёра (только смотреть)
        theirSC:Clear()
        local tkeys = {}
        for id in pairs(P11.Trade.theirOffer.items or {}) do tkeys[#tkeys + 1] = id end
        table.sort(tkeys)
        local hasAny = false
        for _, id in ipairs(tkeys) do
            local cnt = tonumber(P11.Trade.theirOffer.items[id]) or 0
            if cnt > 0 then
                hasAny = true
                local row = theirSC:Add("DPanel")
                row:Dock(TOP) row:DockMargin(0, 0, 0, 4) row:SetTall(28)
                local nm = ItemName(id)
                row.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(TT.acc.r, TT.acc.g, TT.acc.b, 14))
                    draw.SimpleText(nm .. "  ×" .. cnt, "P11.Eco.Small", 8, h / 2, TT.acc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
        end
        if (P11.Trade.theirOffer.money or 0) <= 0 and not hasAny then
            local l = theirSC:Add("DLabel")
            l:SetFont("P11.Eco.Small") l:SetTextColor(TT.dim)
            l:SetText("  (пусто — ждём, что выложит)")
            l:SizeToContents()
        end

        -- строки состояния
        mLab:SetText("Заложено: " .. (P11.Trade.myOffer.money or 0) .. "₽  (у тебя: "
            .. math.floor(P11.Eco.money or 0) .. "₽)")
        statusL:SetText("Партнёр кладёт ₽: " .. (P11.Trade.theirOffer.money or 0) .. "\n"
            .. (P11.Trade.theirReady
                and "Партнёр ГОТОВ ✔ — сделка совершится сразу после твоего «ГОТОВ»."
                or "Партнёр ещё выбирает / не готов."))
    end
    f:Refill()
end

-- ============ ДИАЛОГ ПРИНЯТИЯ ЗАПРОСА ============

local function OpenRequestBox(fromSid, fromName)
    if IsValid(P11.TradeReqBox) then P11.TradeReqBox:Remove() end
    local f = vgui.Create("DFrame")
    P11.TradeReqBox = f
    f:SetSize(420, 152)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.Till = CurTime() + 30
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, 0)
        draw.RoundedBox(8, 0, 0, w, h, TT.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 40, TT.pane, true, true, false, false)
        surface.SetDrawColor(TT.acc)
        surface.DrawRect(0, 40, w, 2)
        draw.SimpleText("🤝 ПРЕДЛОЖЕНИЕ ОБМЕНА", "P11.Eco.Med", 14, 20, TT.acc,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local left = math.max(0, math.ceil(s.Till - CurTime()))
        draw.SimpleText(left .. "с", "P11.Eco.Small", w - 14, 20, TT.dim,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(fromName .. " хочет обменяться.", "P11.Eco.Med", 14, 62, TT.text)
        draw.SimpleText("Держитесь рядом — сделка идёт лицом к лицу.", "P11.Eco.Small", 14, 86, TT.dim)
    end
    f.Think = function(s)
        if CurTime() > s.Till then
            TSend(2, function() net.WriteString(fromSid) net.WriteBool(false) end)
            s:Remove()
        end
    end
    f.OnRemove = function() P11.TradeReqBox = nil end

    local function AnsBtn(x, w, label, col, accept)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, 108) b:SetSize(w, 32) b:SetText("")
        b.Paint = function(s, ww, hh)
            draw.RoundedBox(5, 0, 0, ww, hh,
                s:IsHovered() and Color(col.r, col.g, col.b, 90) or Color(col.r, col.g, col.b, 40))
            draw.SimpleText(label, "P11.Eco.Med", ww / 2, hh / 2, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            TSend(2, function() net.WriteString(fromSid) net.WriteBool(accept) end)
            f:Remove()
            surface.PlaySound(accept and "buttons/button9.wav" or "buttons/button10.wav")
        end
    end
    AnsBtn(14, 190, "✔ ПРИНЯТЬ", TT.ok, true)
    AnsBtn(216, 190, "✖ ОТКЛОНИТЬ", TT.bad, false)

    surface.PlaySound("buttons/button15.wav")
end

-- ============ ВЫБОР ПАРТНЁРА (кто рядом) ============

function P11.OpenTradePicker()
    if IsValid(P11.TradePicker) then P11.TradePicker:Remove() end
    local f = vgui.Create("DFrame")
    P11.TradePicker = f
    f:SetSize(400, 360)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, 0)
        draw.RoundedBox(8, 0, 0, w, h, TT.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 40, TT.pane, true, true, false, false)
        surface.SetDrawColor(TT.acc)
        surface.DrawRect(0, 40, w, 2)
        draw.SimpleText("🤝 ОБМЕН — С КЕМ?", "P11.Eco.Med", 14, 20, TT.acc,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    f.OnRemove = function() P11.TradePicker = nil end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(10, 48) sc:SetSize(380, 302)
    sc:GetVBar():SetWide(5)

    function f:Refill()
        sc:Clear()
        local me = LocalPlayer()
        if not IsValid(me) then return end
        local any = false
        for _, pl in ipairs(player.GetAll()) do
            if pl ~= me and IsValid(pl) then
                local d = math.floor(me:GetPos():Distance(pl:GetPos()))
                if d <= 350 then
                    any = true
                    local row = sc:Add("DButton")
                    row:Dock(TOP) row:DockMargin(0, 0, 0, 4) row:SetTall(32) row:SetText("")
                    local nick, dist, sid = pl:Nick(), d, pl:SteamID()
                    row.Paint = function(s, w, h)
                        draw.RoundedBox(4, 0, 0, w, h,
                            s:IsHovered() and Color(TT.acc.r, TT.acc.g, TT.acc.b, 40) or TT.pane)
                        draw.SimpleText(nick, "P11.Eco.Small", 8, h / 2, TT.text,
                            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        draw.SimpleText(dist .. " юн  🤝", "P11.Eco.Small", w - 8, h / 2, TT.acc,
                            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
                    row.DoClick = function()
                        TSend(1, function() net.WriteString(sid) end)
                        f:Remove()
                        surface.PlaySound("buttons/button9.wav")
                    end
                end
            end
        end
        if not any then
            local l = sc:Add("DLabel")
            l:SetFont("P11.Eco.Med") l:SetTextColor(TT.dim)
            l:SetText("  Пусто. Подойди к человеку на 350 юн —\n  он появится в этом списке.\n  (обмен идёт лицом к лицу)")
            l:SizeToContents()
        end
    end
    f:Refill()
end

-- ============ ПРИЁМ ОТ СЕРВЕРА ============

net.Receive("P11_TradeNet", function()
    local op = net.ReadUInt(4)

    if op == 1 then            -- входящий запрос
        local sid  = net.ReadString()
        local name = net.ReadString()
        OpenRequestBox(sid, name)

    elseif op == 2 then        -- отказ / истёк / не начался
        chat.AddText(TT.dim, "[ОБМЕН] ", TT.text, net.ReadString())
        surface.PlaySound("buttons/button10.wav")

    elseif op == 3 then        -- окно сделки открылось
        P11.Trade.partnerSid  = net.ReadString()
        P11.Trade.partnerName = net.ReadString()
        P11.Trade.active      = true
        P11.Trade.myOffer     = { items = {}, money = 0 }
        P11.Trade.theirOffer  = { items = {}, money = 0 }
        P11.Trade.myReady     = false
        P11.Trade.theirReady  = false
        P11.OpenTradeWindow()
        surface.PlaySound("buttons/button15.wav")

    elseif op == 4 then        -- предложение партнёра сменилось
        P11.Trade.theirOffer.items = util.JSONToTable(net.ReadString() or "") or {}
        P11.Trade.theirOffer.money = net.ReadUInt(24)
        if IsValid(P11.TradeFrame) and P11.TradeFrame.Refill then
            P11.TradeFrame:Refill()
        end

    elseif op == 5 then        -- флаги готовности
        P11.Trade.myReady    = net.ReadBool()
        P11.Trade.theirReady = net.ReadBool()
        if IsValid(P11.TradeFrame) and P11.TradeFrame.Refill then
            P11.TradeFrame:Refill()
        end

    elseif op == 6 then        -- финал (сделка / срыв)
        local ok = net.ReadBool()
        local reason = net.ReadString()
        chat.AddText(ok and TT.ok or TT.bad, "[ОБМЕН] ", TT.text, reason)
        surface.PlaySound(ok and "buttons/button15.wav" or "buttons/button10.wav")
        P11.Trade.active = false
        if IsValid(P11.TradeFrame) then P11.TradeFrame:Remove() end

    elseif op == 9 then        -- открыть выбор партнёра (чат /обмен)
        P11.OpenTradePicker()
    end
end)

print("[P11TRADE] v4.6.9 OK — обмен игрок↔игрок (C-меню: 🤝 Обмен • чат: /обмен)")
