-- ============================================================
--  ПОЛЮС-11 — F6: ВИТРИНА ПОДДЕРЖКИ + «ПОЛЮС-ФЛЮКС» + ТАЛОНЫ
--  (client) v4.10.0 «ГАРАЖ» — витрина пересобрана целиком.
--
--  Заявка владельца: «добавь много ассортимента в донат-меню
--  и добавь донат валюту и меню утилит меню для выдачи этой
--  донат валюты».
--
--  ОКНО (F6):
--   1) шапка: мой баланс ПОЛЮС-ФЛЮКСА (ПФ) и рублей — живые;
--   2) «ПОПОЛНИТЬ ПОТОК» — три пакета 500₽/900₽/1500₽, клик
--      ведёт в ДИСКОРД станции (оплата СБП по закрепу ДС);
--   3) «ПОТРАТИТЬ ПОТОК» — 9 позиций за ПФ (VIP / рубли / РПД /
--      огнемёт / меднабор / термос / антидот / ключ от Як-2);
--   4) «ТАЛОН НАГРАДЫ» — поле промокода (!промо / p11_promo);
--   5) для стаффа (rank ≥ 4) — кнопка «🛠 УТИЛИТЫ ВЫДАЧИ».
--  Реальных денег (карт) в коде нет: рубли — через ДС/CraftedStore.
-- ============================================================

surface.CreateFont("P11D.Title", { font = "Roboto", size = 28, weight = 800, extended = true })
surface.CreateFont("P11D.Big",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11D.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11D.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

P11D = P11D or { Frame = nil }

-- ДС-магазин: ВСТАВЬ свой инвайт (постоянный: Приглашения → «не истекает»)
local DONATE_URL = "https://discord.gg/kdNXgaetC" -- вставлен владельцем в v4.14.3 «ЗАРЯД» (плашка «ХОЗЯИНУ» убрана)

local C = {
    bg     = Color(10, 14, 20, 246),
    panel  = Color(20, 26, 36, 255),
    panel2 = Color(27, 34, 47, 255),
    card   = Color(24, 31, 42, 255),
    line   = Color(120, 170, 210, 255),
    text   = Color(228, 238, 248),
    dim    = Color(150, 165, 185),
    gold   = Color(235, 205, 100),
    crown  = Color(255, 185, 95),
    shield = Color(150, 200, 255),
    green  = Color(120, 235, 140),
    red    = Color(255, 120, 110),
    flux   = Color(130, 220, 235),
}

-- пакеты пополнения ФЛЮКСА (рубли → ЖД в дискорде: закреп СБП)
local TOPUPS = {
    { rub = "500 ₽",  flux = 100, tag = "стартовый поток" },
    { rub = "900 ₽",  flux = 180, tag = "выгоднее: +20% сверху" },
    { rub = "1500 ₽", flux = 320, tag = "меценатский: +28% сверху" },
}

-- зеркало серверной витрины (p11_sv_donate2 → POLUS11.FluxShop).
-- Цена/получение контролируются СЕРВЕРОМ; тут только витрина.
local FLUX_ITEMS = {
    { id = "vip",      price = 100, icon = "💎", name = "Статус VIP",
        desc = "Золотой ранг VIP + секция 💎 VIP-СЛУЖБА в F4." },
    { id = "money25",  price = 40,  icon = "💰", name = "+25 000 ₽",
        desc = "Казначейский перевод на кошелёк." },
    { id = "money60",  price = 80,  icon = "🏦", name = "+60 000 ₽",
        desc = "Хватит на грузовик в гараже и огнемёт." },
    { id = "rpd",      price = 60,  icon = "🔫", name = "РПД",
        desc = "Пулемёт с диском 75 — в твой инвентарь." },
    { id = "flamer",   price = 70,  icon = "🔥", name = "Кустарный огнемёт",
        desc = "Аргумент против Нечто — без похода к ларьку." },
    { id = "medset",   price = 30,  icon = "🩹", name = "Меднабор",
        desc = "Медкейс + «УКОЛ-С» + шприцы ×3 — в инвентарь." },
    { id = "thermos",  price = 15,  icon = "☕", name = "Термос полярника",
        desc = "Тепло 100 мгновенно + пайки ×3." },
    { id = "antidote", price = 60,  icon = "🧪", name = "Ампула чистой крови",
        desc = "Снимает инкубацию заражения (пока не проснулось)." },
    { id = "yakkey",   price = 350, icon = "🔑", name = "Ключ от Як-2",
        desc = "Бесплатный борт в гараже — самолёт без должности лётчика." },
}

local function CloseDonate()
    if IsValid(P11D.Frame) then
        P11D.Frame:Remove()
        P11D.Frame = nil
    end
end

local function SendPromo(entry)
    if not IsValid(entry) then return end
    local code = string.Trim(entry:GetValue() or "")
    if code == "" then
        P11D.PromoMsg = "Введи код талона в поле слева."
        P11D.PromoOk = nil
        surface.PlaySound("buttons/button10.wav")
        return
    end
    P11D.PromoMsg = "Отправил талон на ЦНИИ-экспедит…"
    P11D.PromoOk = nil
    net.Start("p11_promo_use")
        net.WriteString(code)
    net.SendToServer()
    surface.PlaySound("buttons/button15.wav")
end

local function BuyFlux(id)
    net.Start("P11_FluxBuy")
        net.WriteString(id)
    net.SendToServer()
    surface.PlaySound("buttons/button15.wav")
end

local function OpenDonate()
    CloseDonate()

    local W, H = 800, math.min(ScrH() - 40, 700)
    local f = vgui.Create("DFrame")
    P11D.Frame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)
    f.OnRemove = function() if P11D.Frame == f then P11D.Frame = nil end end
    f.OnKeyCodePressed = function(_, key)
        if key == KEY_F6 or key == KEY_ESCAPE then f:Remove() end
    end

    local me = LocalPlayer()
    local myRank = (P11FW and P11FW.GetRankName and P11FW.GetRankName(me)) or "User"
    local iAmStaff = P11FW and P11FW.GetRankLevel and P11FW.GetRankLevel(me) >= 4

    local sweep = 0
    f.Paint = function(s2, w, h)
        Derma_DrawBackgroundBlur(s2, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 86, C.panel2, true, true, false, false)
        sweep = (SysTime() * 110) % (w + 240) - 120
        surface.SetDrawColor(255, 225, 140, 14)
        surface.DrawRect(sweep, 0, 80, 86)
        surface.SetDrawColor(C.line) surface.DrawRect(0, 86, w, 2)

        draw.SimpleText("ПОДДЕРЖКА СТАНЦИИ", "P11D.Title", 16, 10, C.text)
        draw.SimpleText("ПОЛЮС-ФЛЮКС — валюта покровителей · оплата — ДИСКОРД (СБП в закрепе) · трата — ниже, мгновенно",
            "P11D.Small", 16, 40, C.dim)

        -- живые балансы
        local flux = IsValid(me) and me:GetNWInt("P11_Flux", 0) or 0
        local money = IsValid(me) and me:GetNWInt("P11_Money", 0) or 0
        draw.SimpleText("💠 " .. string.Comma(flux) .. " ПФ", "P11D.Big", w - 16, 22, C.flux, TEXT_ALIGN_RIGHT)
        draw.SimpleText(string.Comma(money) .. " ₽ · ранг: " .. tostring(myRank), "P11D.Small", w - 16, 48, C.dim, TEXT_ALIGN_RIGHT)

        if string.find(DONATE_URL, "ВСТАВЬ_ИНВАЙТ", 1, true) then
            draw.SimpleText("⚠ ХОЗЯИНУ: вставь инвайт ДС в DONATE_URL (p11_cl_donate.lua)", "P11D.Small",
                w / 2, 68, C.red, TEXT_ALIGN_CENTER)
        end
    end

    local xBtn = vgui.Create("DButton", f)
    xBtn:SetPos(W - 40, 12) xBtn:SetSize(26, 24) xBtn:SetText("")
    xBtn.Paint = function(s2, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s2:IsHovered() and Color(120, 44, 40) or Color(50, 34, 32))
        draw.SimpleText("✕", "P11D.Small", w / 2, h / 2 - 1, Color(240, 210, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xBtn.DoClick = function() f:Remove() end

    -- ============ прокручиваемое тело ============
    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(14, 96) sc:SetSize(W - 28, H - 108)
    sc:GetVBar():SetWide(6)

    local function SectionTitle(txt, sub)
        local p = sc:Add("DPanel")
        p:Dock(TOP) p:DockMargin(0, 2, 0, 6) p:SetTall(34)
        p.Txt, p.Sub = txt, sub
        p.Paint = function(s2, w, h)
            draw.SimpleText(s2.Txt, "P11D.Big", 8, 8, C.gold)
            draw.SimpleText(s2.Sub or "", "P11D.Small", w - 8, 12, C.dim, TEXT_ALIGN_RIGHT)
            surface.SetDrawColor(120, 160, 200, 60)
            surface.DrawRect(0, h - 1, w, 1)
        end
        return p
    end

    -- ---------- 1) ПОПОЛНИТЬ ПОТОК ----------
    SectionTitle("💠 ПОПОЛНИТЬ ПОЛЮС-ФЛЮКС", "реальная поддержка: рубли → в ДС (закреп) → ПФ на баланс")

    local topRow = sc:Add("DPanel")
    topRow:Dock(TOP) topRow:DockMargin(0, 0, 0, 12) topRow:SetTall(108)
    topRow.Paint = function() end

    local cardW = math.floor((W - 28 - 24) / 3)
    for i, t in ipairs(TOPUPS) do
        local card = vgui.Create("DPanel", topRow)
        card:SetPos((i - 1) * (cardW + 12), 0)
        card:SetSize(cardW, 108)
        card.T = t
        card.Paint = function(s2, w, h)
            draw.RoundedBox(10, 0, 0, w, h, C.card)
            draw.RoundedBoxEx(10, 0, 0, w, 30, Color(110, 200, 220, 26), true, true, false, false)
            draw.SimpleText(s2.T.rub .. "  →  " .. s2.T.flux .. " ПФ", "P11D.Big", 12, 6, C.flux)
            draw.SimpleText(s2.T.tag, "P11D.Small", 12, 32, C.dim)
            draw.SimpleText("клик — в наш ДИСКОРД-магазин", "P11D.Small", 12, 52, C.dim)
        end
        local b = vgui.Create("DButton", card)
        b:SetPos(12, 74) b:SetSize(cardW - 24, 26) b:SetText("")
        b.Paint = function(s2, w, h)
            draw.RoundedBox(7, 0, 0, w, h, s2:IsHovered() and Color(60, 110, 130) or Color(36, 60, 74))
            surface.SetDrawColor(C.flux)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("КУПИТЬ " .. t.rub .. " → ДС", "P11D.Small", w / 2, h / 2,
                s2:IsHovered() and Color(210, 250, 255) or C.flux, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            P11D.BuyInDiscord("ПОТОК " .. t.flux .. " ПФ", t.rub)
        end
    end

    -- ---------- 2) ПОТРАТИТЬ ПОТОК ----------
    SectionTitle("🛒 ПОТРАТИТЬ ПОТОК — 9 товаров за ПФ", "награда мгновенная · при отказе флюкс возвращается сам")

    local gridW = W - 28
    local cellW = math.floor((gridW - 24) / 3)
    for i, it in ipairs(FLUX_ITEMS) do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        if col == 0 then
            local holder = sc:Add("DPanel")
            holder:Dock(TOP) holder:DockMargin(0, 0, 0, 10) holder:SetTall(128)
            holder.Paint = function() end
            holder.GridRow = row
            P11D["grid" .. row] = holder
        end
        local holder = P11D["grid" .. row]
        local card = vgui.Create("DPanel", holder)
        card:SetPos(col * (cellW + 12), 0)
        card:SetSize(cellW, 128)
        card.It = it
        card.Paint = function(s2, w, h)
            draw.RoundedBox(10, 0, 0, w, h, C.card)
            draw.SimpleText(s2.It.icon .. " " .. s2.It.name, "P11D.Text", 10, 8, C.text)
            draw.SimpleText(s2.It.desc, "P11D.Small", 10, 30, C.dim)
        end
        local b = vgui.Create("DButton", card)
        b:SetPos(10, 92) b:SetSize(cellW - 20, 28) b:SetText("")
        b.Paint = function(s2, w, h)
            local myFlux = IsValid(LocalPlayer()) and LocalPlayer():GetNWInt("P11_Flux", 0) or 0
            local can = myFlux >= it.price
            draw.RoundedBox(7, 0, 0, w, h, can and (s2:IsHovered() and Color(70, 60, 26) or Color(46, 40, 20)) or Color(30, 30, 34))
            surface.SetDrawColor(can and C.gold or C.dim)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText((can and "💠 КУПИТЬ ЗА " or "нужно ") .. it.price .. " ПФ", "P11D.Small",
                w / 2, h / 2, can and C.gold or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            BuyFlux(it.id)
        end
    end

    -- ---------- 3) ТАЛОН НАГРАДЫ ----------
    SectionTitle("🎟 ТАЛОН НАГРАДЫ (промокод)", "также: чат «!промо КОД» · консоль «p11_promo КОД»")

    local foot = sc:Add("DPanel")
    foot:Dock(TOP) foot:DockMargin(0, 0, 0, 12) foot:SetTall(118)
    foot.Paint = function(s2, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.panel2)
        if P11D.PromoMsg then
            local stCol = C.dim
            if P11D.PromoOk == true then stCol = C.green end
            if P11D.PromoOk == false then stCol = C.red end
            surface.SetFont("P11D.Small")
            local msg = tostring(P11D.PromoMsg)
            local words = {}
            for w2 in string.gmatch(msg, "%S+") do words[#words + 1] = w2 end
            local line, yy = "", 50
            for _, wd in ipairs(words) do
                local test = (line == "") and wd or (line .. " " .. wd)
                if (surface.GetTextSize(test) or 0) > w - 28 then
                    draw.SimpleText(line, "P11D.Small", 12, yy, stCol)
                    yy = yy + 17
                    line = wd
                    if yy > 96 then break end
                else
                    line = test
                end
            end
            if line ~= "" and yy <= 96 then draw.SimpleText(line, "P11D.Small", 12, yy, stCol) end
        else
            draw.SimpleText("Код пишется ТОЧНО как выдан (рассылка / дискорд команды станции). Погашается один раз на бойца.",
                "P11D.Small", 12, 52, C.dim)
        end
    end

    local entry = vgui.Create("DTextEntry", foot)
    entry:SetPos(12, 12)
    entry:SetSize(gridW - 24 - 10 - 190 - 12, 32)
    entry:SetFont("P11D.Text")
    entry:SetTextColor(C.text)
    entry:SetPlaceholderText("ВВЕДИ КОД ТАЛОНА…")
    entry:SetPaintBackground(false)
    entry.Paint = function(s2, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 16, 24))
        surface.SetDrawColor(P11D.PromoOk == false and C.red or C.gold)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s2:DrawTextEntryText(C.text, Color(120, 130, 145), C.text)
    end
    entry.OnEnter = function(s2) SendPromo(s2) end

    local go = vgui.Create("DButton", foot)
    go:SetPos(gridW - 24 - 190 + 12, 12)
    go:SetSize(190, 32)
    go:SetText("")
    go.Paint = function(s2, w, h)
        local hov = s2:IsHovered()
        draw.RoundedBox(8, 0, 0, w, h, hov and Color(70, 60, 30) or Color(52, 46, 22))
        surface.SetDrawColor(C.gold)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("ПОГАСИТЬ ТАЛОН", "P11D.Big", w / 2, h / 2 - 2, hov and Color(255, 235, 160) or C.gold,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    go.DoClick = function() SendPromo(entry) end

    -- ---------- 4) СТАФФ: утилиты выдачи ----------
    if iAmStaff then
        SectionTitle("🛠 УТИЛИТЫ ВЫДАЧИ (стаф)", "выдача/списание ПОЛЮС-ФЛЮКСА бойцам онлайн — журналируется")
        local ub = sc:Add("DButton")
        ub:Dock(TOP) ub:DockMargin(0, 0, 0, 14) ub:SetTall(40) ub:SetText("")
        ub.Paint = function(s2, w, h)
            draw.RoundedBox(8, 0, 0, w, h, s2:IsHovered() and Color(50, 70, 90) or Color(32, 48, 64))
            surface.SetDrawColor(C.shield)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("ОТКРЫТЬ УТИЛИТ-МЕНЮ ВЫДАЧИ ФЛЮКСА  (или консоль: p11_utils)", "P11D.Text",
                w / 2, h / 2, C.shield, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        ub.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            RunConsoleCommand("p11_utils")
        end
    end

    surface.PlaySound("ui/buttonclick.wav")
    return f
end

-- ответ сервера на погашение талона
net.Receive("p11_promo_use", function()
    local ok = net.ReadBool()
    local msg = net.ReadString()
    P11D.PromoMsg = msg
    P11D.PromoOk = ok and true or false
    if ok then
        surface.PlaySound("buttons/button9.wav")
        chat.AddText(Color(235, 205, 100), "[ТАЛОН] ", Color(140, 240, 160), msg)
    else
        surface.PlaySound("buttons/button10.wav")
        chat.AddText(Color(235, 205, 100), "[ТАЛОН] ", Color(255, 150, 140), msg)
    end
end)

-- клик по пакету рублей — в ДИСКОРД-магазин (оплата там, выдача тут)
function P11D.BuyInDiscord(packName, price)
    surface.PlaySound("ui/buttonclick.wav")
    if string.find(DONATE_URL, "ВСТАВЬ_ИНВАЙТ", 1, true) then
        chat.AddText(Color(255, 120, 110), "[ПОДДЕРЖКА] ",
            Color(225, 230, 240), "Хозяин сервера ещё не вставил инвайт ДС (DONATE_URL в p11_cl_donate.lua).")
        P11D.PromoMsg = "⚠ Хозяин не вставил инвайт ДС — кнопка покажет ДС, когда он впишет DONATE_URL."
        P11D.PromoOk = false
        return
    end
    P11D.PromoMsg = "Открываю ДИСКОРД-магазин: «" .. tostring(packName) .. "» (" .. tostring(price) .. ")…"
    P11D.PromoOk = true
    gui.OpenURL(DONATE_URL)
    chat.AddText(Color(235, 205, 100), "[ПОДДЕРЖКА] ",
        Color(225, 230, 240), "Открыл ДИСКОРД: оплата по закрепу СБП, пакет «" .. tostring(packName) .. "» за " .. tostring(price)
        .. ". ПФ долетит на баланс (магазин/Глава: p11_fluxgive).")
end

-- ============ КЛАВИША F6 ============

hook.Add("PlayerButtonDown", "P11.DonateF6", function(ply, btn)
    if btn ~= KEY_F6 then return end
    if ply ~= LocalPlayer() then return end
    if IsValid(P11D.Frame) then
        CloseDonate()
        surface.PlaySound("ui/buttonclickrelease.wav")
    else
        OpenDonate()
        surface.PlaySound("ui/buttonclick.wav")
    end
end)

-- консольная копия (запасной путь)
concommand.Add("p11_donate", function()
    if IsValid(P11D.Frame) then CloseDonate() else OpenDonate() end
end)

print("[POLUS-11] витрина поддержки v4.10.0: ПОЛЮС-ФЛЮКС, 9 товаров за ПФ, 3 пакета пополнения → ДС, талоны (F6)")
