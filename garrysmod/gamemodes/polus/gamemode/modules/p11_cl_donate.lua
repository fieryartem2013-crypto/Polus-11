-- ============================================================
--  ПОЛЮС-11 — F6: ВИТРИНА ПОДДЕРЖКИ СТАНЦИИ (client) v4.8.0
--  ПЛЕЙСХОЛДЕР донат-меню (заявка владельца: «сделай на F6 донат
--  меню, которое пока что как плейсхолдер»). Оплаты/выдачи тут
--  НЕТ: витрина показывает, ЧТО откроется за поддержку, и честно
--  сообщает, что ранги сейчас выдаются вручную — Главой Проекта
--  или Куратором (вкладка АДМИНКИ в /menu, консоль p11_rank).
--  Уже рабочее: ранг VIP (ур.1) сам по себе ОТКРЫВАЕТ секцию
--  💎 VIP-СЛУЖБА в F4 — см. fw_sv_jobs / fw_sh_ranks.IsVIP.
--  Открытие/закрытие: F6. ESC тоже закрывает.
-- ============================================================

surface.CreateFont("P11D.Title", { font = "Roboto", size = 28, weight = 800, extended = true })
surface.CreateFont("P11D.Big",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11D.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11D.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

P11D = P11D or { Frame = nil }

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
}

-- витрина пакетов (плейсхолдер — кнопки бездействуют)
local PACKS = {
    {
        icon = "💎", name = "VIP", col = C.gold,
        tag = "статус за поддержку",
        perks = {
            "секция 💎 VIP-СЛУЖБА в F4 (Следопыт-охотник, Ветеран Арктики, Военврач) — УЖЕ РАБОТАЕТ",
            "золотой ранг «VIP» в составе станции (TAB)",
            "уважение экипажа и приоритет в очередях смены",
        },
    },
    {
        icon = "👑", name = "VIP+", col = C.crown,
        tag = "расширенный набор — скоро",
        perks = {
            "всё из статуса VIP",
            "уникальная внешность и титул смены на выбор",
            "личный радиочастотный канал (планируется)",
        },
    },
    {
        icon = "🛡", name = "ПОКРОВИТЕЛЬ СТАНЦИИ", col = C.shield,
        tag = "для меценатов — скоро",
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

local function OpenDonate()
    CloseDonate()

    local W, H = 760, 600
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

        -- шапка с морозной кромкой
        draw.RoundedBoxEx(12, 0, 0, w, 64, C.panel2, true, true, false, false)
        sweep = (SysTime() * 110) % (w + 240) - 120
        surface.SetDrawColor(255, 225, 140, 14)
        surface.DrawRect(sweep, 0, 80, 64)
        surface.SetDrawColor(C.line)
        surface.DrawRect(0, 64, w, 2)
        surface.SetDrawColor(120, 190, 235, 55)
        surface.DrawRect(0, 66, w, 1)

        draw.SimpleText("ПОДДЕРЖКА СТАНЦИИ", "P11D.Title", 18, 10, C.text)
        draw.SimpleText("витрина-плейсхолдер · приёмка платежей «ЦНИИ-экспедит» ещё не настроена",
            "P11D.Small", 18, 42, C.dim)

        -- статус моего ранга справа в шапке
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

            -- маркер «У ВАС» для текущих VIP
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
                -- текст перка в колонку: простая отрисовка с переносом
                draw.SimpleText("•", "P11D.Text", left, yy + 4, s2.Pack.col)
                surface.SetFont("P11D.Text")
                -- переносим по ширине вручную через длину строки
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
        btn.Paint = function(s2, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(52, 58, 68))
            draw.RoundedBoxEx(8, 0, 0, w, h / 2, Color(255, 255, 255, 5), true, true, false, false)
            draw.SimpleText("СКОРО", "P11D.Big", w / 2, h / 2 - 2, s2.PackCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function(s2)
            surface.PlaySound("buttons/button10.wav")
            P11D.PingSoon(s2.PackName)
        end
    end

    -- футер: как получить СЕЙЧАС (ручная выдача)
    local foot = vgui.Create("DPanel", f)
    foot:SetPos(16, y0 + cardH + 16)
    foot:SetSize(W - 32, 600 - (y0 + cardH + 16) - 14)
    foot.Paint = function(s2, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.panel2)
        surface.SetDrawColor(255, 225, 140, 35)
        surface.DrawRect(0, 0, w, 1)
        draw.SimpleText("КАК ПОЛУЧИТЬ СЕЙЧАС", "P11D.Big", 14, 10, C.gold)
        draw.SimpleText("Платёжный автомат ещё не завезён — это витрина. Привилегии выдаются ВРУЧНУЮ:", "P11D.Text", 14, 38, C.text)
        draw.SimpleText("1) договорись с Главой Проекта / Куратором сервера   2) они выдадут тебе ранг VIP (/menu → АДМИНКИ или p11_rank)", "P11D.Small", 14, 62, C.dim)
        draw.SimpleText("3) открой F4 — появится секция 💎 VIP-СЛУЖБА с профами   4) в TAB твой ранг станет золотым «VIP»", "P11D.Small", 14, 82, C.dim)

        draw.SimpleText("F6 / ESC — закрыть витрину", "P11D.Small", w - 14, h - 12, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

-- подтверждение клика по «СКОРО» (честный плейсхолдер)
function P11D.PingSoon(packName)
    chat.AddText(Color(235, 205, 100), "[ПОДДЕРЖКА] ",
        Color(225, 230, 240), "Пакет «" .. tostring(packName) .. "» пока в разработке — ",
        Color(150, 165, 185), "ранг VIP уже выдаётся вручную Главой/Куратором и открывает 💎 VIP-профы в F4.")
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

-- консольная копия (меню может перехватывать фокус — пусть будет запасной путь)
concommand.Add("p11_donate", function()
    if IsValid(P11D.Frame) then CloseDonate() else OpenDonate() end
end)

print("[POLUS-11] донат-витрина v4.8.0 загружена (F6 — плейсхолдер)")
