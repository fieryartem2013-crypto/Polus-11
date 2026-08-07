-- ============================================================
--  ПОЛЮС-11 — F6: ВИТРИНА ПОДДЕРЖКИ + ТАЛОНЫ (client) v4.9.0 «ТАЛОН»
--  НОВОЕ (заявка владельца «промокоды в Донат меню»): внизу окна —
--  рабочее поле «ТАЛОН НАГРАДЫ»: вводишь код → сервер (p11_sv_promo)
--  гасит талон и сразу выдаёт награду (деньги / VIP / сюрприз).
--  Ответ сервера = зелёная/красная строка статуса + сообщение в чат.
--  Оплаты реальными деньгами тут по-прежнему НЕТ и НЕ БУДЕТ без
--  донат-сервиса: автопродажу подключим через EasyDonate/CraftedStore/
--  Tebex, когда владелец там зарегистрируется (карты в коде — никогда).
--  Открытие/закрытие: F6. ESC тоже закрывает. Кнопки пакетов пока
--  «СКОРО» — честный плейсхолдер, ранги пока выдаёт Глава/Куратор.
-- ============================================================

surface.CreateFont("P11D.Title", { font = "Roboto", size = 28, weight = 800, extended = true })
surface.CreateFont("P11D.Big",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11D.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11D.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

P11D = P11D or { Frame = nil }

-- v4.9.3 «ГРОШ» — ДИСКОРД-МАГАЗИН: кнопка покупки бросает игрока
-- на ваш ДС (заявка: «при нажатии кидает на наш дс сервер»).
-- ВСТАВЬ свой инвайт сюда (постоянная ссылка: Настройки сервера ДС →
-- Приглашения → создать §{не истекает}): напр. https://discord.gg/AbCdEfG
local DONATE_URL = "https://discord.gg/ВСТАВЬ_ИНВАЙТ"

local C = {
    bg     = Color(10, 14, 20, 246),
    panel  = Color(20, 26, 36, 255),
    panel2 = Color(27, 34, 47, 255),
    line   = Color(120, 170, 210, 255),
    text   = Color(228, 238, 248),
    dim    = Color(150, 165, 185),
    gold   = Color(235, 205, 100),
    crown  = Color(255, 185, 95),
    shield = Color(150, 200, 255),
    green  = Color(120, 235, 140),
    red    = Color(255, 120, 110),
}

-- витрина пакетов (плейсхолдер — кнопки бездействуют)
local PACKS = {
    {
        icon = "💎", name = "VIP", col = C.gold, price = "500 ₽",
        tag = "статус за поддержку",
        perks = {
            "секция 💎 VIP-СЛУЖБА в F4 (Следопыт-охотник, Ветеран Арктики, Военврач) — УЖЕ РАБОТАЕТ",
            "золотой ранг «VIP» в составе станции (TAB)",
            "также даруется золотым ТАЛОНОМ (поле внизу) — если у тебя есть код",
        },
    },
    {
        icon = "👑", name = "VIP+", col = C.crown, price = "900 ₽",
        tag = "расширенный набор — идёт продажа",
        perks = {
            "всё из статуса VIP",
            "уникальная внешность и титул смены на выбор",
            "личный радиочастотный канал (планируется)",
        },
    },
    {
        icon = "🛡", name = "ПОКРОВИТЕЛЬ СТАНЦИИ", col = C.shield, price = "1500 ₽",
        tag = "для меценатов — идёт продажа",
        perks = {
            "всё из VIP+",
            "имя на доске благодарностей у кают-компании (планируется)",
            "участие в закрытых тестах новых смен",
        },
    },
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

local function OpenDonate()
    CloseDonate()

    local W, H = 760, 664
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

    -- моё текущее положение (для статуса «У ВАС»)
    local me = LocalPlayer()
    local myRank = (P11FW and P11FW.GetRankName and P11FW.GetRankName(me)) or "User"
    local iAmVIP = P11FW and P11FW.IsVIP and P11FW.IsVIP(me)

    local sweep = 0
    f.Paint = function(s2, w, h)
        Derma_DrawBackgroundBlur(s2, SysTime())
        draw.RoundedBox(12, 0, 0, w, h, C.bg)

        draw.RoundedBoxEx(12, 0, 0, w, 64, C.panel2, true, true, false, false)
        sweep = (SysTime() * 110) % (w + 240) - 120
        surface.SetDrawColor(255, 225, 140, 14)
        surface.DrawRect(sweep, 0, 80, 64)
        surface.SetDrawColor(C.line)
        surface.DrawRect(0, 64, w, 2)
        surface.SetDrawColor(120, 190, 235, 55)
        surface.DrawRect(0, 66, w, 1)

        draw.SimpleText("ПОДДЕРЖКА СТАНЦИИ", "P11D.Title", 18, 10, C.text)
        draw.SimpleText("есть код? внизу поле ТАЛОНА — награда мгновенная · автопродажа — через донат-сервис, скоро",
            "P11D.Small", 18, 42, C.dim)

        draw.SimpleText("ваш ранг: " .. tostring(myRank) .. (iAmVIP and " (VIP-доступ ЕСТЬ ✔)" or ""),
            "P11D.Small", w - 16, 12, iAmVIP and C.gold or C.dim, TEXT_ALIGN_RIGHT)
    end

    f.OnKeyCodePressed = function(s2, key)
        if key == KEY_F6 or key == KEY_ESCAPE then f:Remove() end
    end

    local xBtn = vgui.Create("DButton", f)
    xBtn:SetPos(W - 38, 14)
    xBtn:SetSize(26, 26)
    xBtn:SetText("✕")
    xBtn:SetFont("P11D.Big")
    xBtn:SetTextColor(C.dim)
    xBtn.Paint = function() end
    xBtn.DoClick = function() f:Remove() end

    -- три карточки пакетов
    local cardW, cardH, gap = 236, 372, 14
    local totalW = cardW * 3 + gap * 2
    local x0 = math.floor((W - totalW) / 2)
    local y0 = 84

    for i, pack in ipairs(PACKS) do
        local pnl = vgui.Create("DPanel", f)
        pnl:SetPos(x0 + (i - 1) * (cardW + gap), y0)
        pnl:SetSize(cardW, cardH)
        pnl.Pack = pack
        pnl.Paint = function(s2, w, h)
            local pc = s2.Pack.col
            draw.RoundedBox(10, 0, 0, w, h, C.panel)
            draw.RoundedBoxEx(10, 0, 0, w, 58, Color(pc.r, pc.g, pc.b, 28), true, true, false, false)
            surface.SetDrawColor(pc.r, pc.g, pc.b, 120)
            surface.DrawRect(0, 58, w, 1)
            draw.SimpleText(s2.Pack.icon .. " " .. s2.Pack.name, "P11D.Big", 12, 12, pc)
            draw.SimpleText(s2.Pack.tag, "P11D.Small", 12, 38, C.dim)

            if s2.Pack.name == "VIP" and iAmVIP then
                draw.RoundedBox(8, w - 74, 12, 62, 22, Color(70, 120, 70, 200))
                draw.SimpleText("У ВАС", "P11D.Small", w - 43, 23, Color(190, 255, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local perks = vgui.Create("DScrollPanel", pnl)
        perks:SetPos(10, 66)
        perks:SetSize(cardW - 20, cardH - 66 - 66)
        perks.Pack = pack
        perks.Paint = function(s2, w, h)
            local yy = 2
            local left = 0
            for _, perk in ipairs(s2.Pack.perks) do
                draw.SimpleText("•", "P11D.Text", left, yy + 4, s2.Pack.col)
                surface.SetFont("P11D.Text")
                local words = {}
                for w2 in string.gmatch(perk, "%S+") do words[#words + 1] = w2 end
                local line = ""
                local lines = {}
                for _, wd in ipairs(words) do
                    local test = (line == "") and wd or (line .. " " .. wd)
                    if (surface.GetTextSize(test) or 0) > w - 18 then
                        lines[#lines + 1] = line
                        line = wd
                    else
                        line = test
                    end
                end
                if line ~= "" then lines[#lines + 1] = line end
                for _, ln in ipairs(lines) do
                    draw.SimpleText(ln, "P11D.Text", left + 12, yy + 4, C.text)
                    yy = yy + 19
                end
                yy = yy + 8
            end
        end

        -- кнопка-заглушка «СКОРО»
        local btn = vgui.Create("DButton", pnl)
        btn:SetPos(12, cardH - 56)
        btn:SetSize(cardW - 24, 42)
        btn:SetText("")
        btn.PackName = pack.name
        btn.PackCol = pack.col
        btn.PackPrice = pack.price or "500 ₽"
        btn.Paint = function(s2, w, h)
            local hov = s2:IsHovered()
            local pc = s2.PackCol
            draw.RoundedBox(8, 0, 0, w, h, hov and Color(pc.r, pc.g, pc.b, 200) or Color(52, 58, 68))
            draw.RoundedBoxEx(8, 0, 0, w, h / 2, Color(255, 255, 255, 5), true, true, false, false)
            surface.SetDrawColor(pc.r, pc.g, pc.b, hov and 255 or 120)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(s2.PackPrice .. " → ДИСКОРД", "P11D.Big", w / 2, h / 2 - 2,
                hov and Color(14, 18, 24) or s2.PackCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(s2)
            P11D.BuyInDiscord(s2.PackName, s2.PackPrice)
        end
    end

    -- ============ ФУТЕР: ТАЛОН НАГРАДЫ (рабочий ввод промокода) ============
    local fy0 = y0 + cardH + 16
    local foot = vgui.Create("DPanel", f)
    foot:SetPos(16, fy0)
    foot:SetSize(W - 32, H - fy0 - 14)
    foot.Paint = function(s2, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.panel2)
        surface.SetDrawColor(255, 225, 140, 35)
        surface.DrawRect(0, 0, w, 1)
        draw.SimpleText("ТАЛОН НАГРАДЫ", "P11D.Big", 14, 8, C.gold)
        draw.SimpleText("цены пакетов: VIP 500₽ · VIP+ 900₽ · ПОКРОВИТЕЛЬ 1500₽ — клик по цене ведёт в ДС", "P11D.Small", w - 14, 12, C.dim, TEXT_ALIGN_RIGHT)
        draw.SimpleText("Талон — одноразовый код от команды станции (рассылка / дискорд). Код пишется ТОЧНО как выдан, большими буквами.",
            "P11D.Small", 14, 32, C.dim)

        -- строка статуса ответа сервера
        if P11D.PromoMsg then
            local stCol = C.dim
            if P11D.PromoOk == true then stCol = C.green end
            if P11D.PromoOk == false then stCol = C.red end
            surface.SetFont("P11D.Small")
            local msg = tostring(P11D.PromoMsg)
            -- перенос статуса в 2 строки по ширине
            local words = {}
            for w2 in string.gmatch(msg, "%S+") do words[#words + 1] = w2 end
            local line, yy = "", 94
            for _, wd in ipairs(words) do
                local test = (line == "") and wd or (line .. " " .. wd)
                if (surface.GetTextSize(test) or 0) > w - 28 then
                    draw.SimpleText(line, "P11D.Small", 14, yy, stCol)
                    yy = yy + 17
                    line = wd
                    if yy > 128 then break end
                else
                    line = test
                end
            end
            if line ~= "" and yy <= 128 then draw.SimpleText(line, "P11D.Small", 14, yy, stCol) end
        else
            draw.SimpleText("Пути ввода талона: это поле • чат «!промо КОД» • консоль «p11_promo КОД».", "P11D.Small", 14, 94, C.dim)
        end

        draw.SimpleText("Без талона VIP можно 1) купить в магазине CraftedStore (хозяину: пошаговая инструкция — docs/DONATE.md, команда p11_donorvip) 2) вручную у Главы (p11_rank).",
            "P11D.Small", 14, 136, C.dim)
        draw.SimpleText("F6 / ESC — закрыть", "P11D.Small", w - 14, h - 14, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- поле кода
    local entry = vgui.Create("DTextEntry", foot)
    entry:SetPos(14, 54)
    entry:SetSize(W - 32 - 14 - 10 - 190 - 14, 32)
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

    -- кнопка погашения
    local go = vgui.Create("DButton", foot)
    go:SetPos(W - 32 - 14 - 190, 54)
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
end

-- ответ сервера на погашение талона (v4.9.0)
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

-- v4.9.3 «ГРОШ»: клик по пакету — в ДИСКОРД-магазин (покупка там,
-- выдача VIP — хозяин руками p11_rank или мостом магазина p11_donorvip)
function P11D.BuyInDiscord(packName, price)
    surface.PlaySound("ui/buttonclick.wav")
    if string.find(DONATE_URL, "ВСТАВЬ_ИНВАЙТ", 1, true) then
        chat.AddText(Color(255, 120, 110), "[ПОДДЕРЖКА] ",
            Color(225, 230, 240), "Хозяин сервера ещё не вставил инвайт ДС (константа DONATE_URL в p11_cl_donate.lua).")
        return
    end
    P11D.PromoMsg = "Открываю ДИСКОРД-магазин: «" .. tostring(packName) .. "» (" .. tostring(price) .. ")…"
    P11D.PromoOk = true
    gui.OpenURL(DONATE_URL)
    chat.AddText(Color(235, 205, 100), "[ПОДДЕРЖКА] ",
        Color(225, 230, 240), "Открыл ДИСКОРД станции: там пакет «" .. tostring(packName) .. "» за " .. tostring(price)
        .. " — после оплаты хозяин/магазин выдаст VIP (мост: p11_donorvip).")
end

-- совместимость: если старая кнопка «СКОРО» где-то осталась
function P11D.PingSoon(packName)
    P11D.BuyInDiscord(packName, "— цена в ДС —")
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

print("[POLUS-11] донат-витрина v4.9.0 загружена (F6 — витрина + поле ТАЛОНА)")
