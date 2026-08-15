-- ============================================================
--  ПОЛЮС-11 — ГАЙД НОВИЧКА «ПОЛНЫЙ КУРС» (client) v5.4.3 (НОВЫЙ ФАЙЛ)
--  Копия v525 без упоминаний ярмарки (пауза, ярмарка вырезана).
--  Полный онбординг по ВСЕМ механикам станции: как менять профы,
--  какие клавиши жать, экономика, дежурства, происшествия, донат.
--  Показывается АВТОМАТИЧЕСКИ при первом входе (один раз, как
--  туториал), повторно: консоль p11_guide или кнопка в F1-справке
--  не нужна — просто p11_guide в консоли клиента.
--  Старые файлы не трогаем — всё новое в autorun.
-- ============================================================

P11 = P11 or {}

local GUIDE_FILE = "polus11/guide_done.txt"

surface.CreateFont("P11.Guide.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.Guide.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Guide.Tx",    { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.Guide.Small", { font = "Roboto", size = 12, weight = 500, extended = true })

local C = {
    bg   = Color(10, 14, 20, 248),
    pane = Color(24, 30, 40, 255),
    gold = Color(255, 205, 100),
    txt  = Color(232, 238, 245),
    dim  = Color(150, 158, 172),
    grn  = Color(110, 215, 140),
}

-- ============ СОДЕРЖАНИЕ ГАЙДА ============
-- Каждый раздел: заголовок + массив строк (тело)
local SECTIONS = {
    {
        t = "🚀 ПЕРВЫЕ ШАГИ",
        lines = {
            "1) Возьми ДОЛЖНОСТЬ: подойди к кадровику и жми E, или клавиша F4.",
            "2) Открой C-меню (клавиша C): жесты, инвентарь, дела, древо службы.",
            "3) Делай ЗАДАЧИ СМЕНЫ (список слева на экране) — за них рубли.",
            "4) Не уходи на мороз без тепла: грейся у генератора/буржуйки, ешь паёк.",
            "5) Если что-то непонятно — F1 (памятка) или !репорт <текст>.",
        },
    },
    {
        t = "💼 КАК МЕНЯТЬ ПРОФУ",
        lines = {
            "• F4 → список должностей по фракциям (РККА / НКВД / Учёные / Персонал / Криминал).",
            "• Выбери профу, у которой нет замка 🔒 (вайтлист/древо) и есть места (X/Y).",
            "• Некоторые профы открываются ДРЕВОМ СЛУЖБЫ (C-меню → ⭐ ДРЕВО):",
            "  путь РККА, Учёные, Криминал — нужен уровень за дела.",
            "• ВАЙТЛИСТ-профы (НКВД и др.) выдаёт администрация/офицеры.",
            "• Смена профы = смена модели и снаряжения. Новобранец — стартовая.",
        },
    },
    {
        t = "⌨️ КЛАВИШИ И КОМАНДЫ",
        lines = {
            "F1 — памятка экипажа        F4 — должности (профы)",
            "F5 — батл-пасс              F6 — поддержка (донат)",
            "C — C-меню (жесты/дела)     TAB — состав станции",
            "E — использовать/взять/обыскать   R — (Нечто) меню тела",
            "Команды в чат — через «!»:",
            "  !гараж  !крафт  !пульт(админ)  !снятьдежурство  !промо",
            "  !репорт <текст> — жалоба админам",
        },
    },
    {
        t = "💰 ЭКОНОМИКА",
        lines = {
            "• Рубли ₽ — за дела смены, наряды, дежурства, операции.",
            "• Ларёк снабжения (E по торговцу): оружие, пайки, рации, материалы.",
            "• Покупки живут в БАГАЖЕ (C-меню → 🎒): достать/сдать.",
            "• Личный сейф — хранит лишнее (C-меню).",
            "• ПОЛЮС-ФЛЮКС 💠 — донат-валюта за поддержку (F6), товары там же.",
        },
    },
    {
        t = "🛡 ДЕЖУРСТВА",
        lines = {
            "• НПС «Дежурный главы» → E → выбери пост:",
            "  КПП 2 · КПП Приезжая часть · Поверхность · Комплекс за Сотрудником.",
            "• Пока дежуришь: плашка 🛡 над головой, оклад +100₽/мин.",
            "• Снять: меню НПС или !снятьдежурство.",
            "• Смерть/выход снимают пост автоматически.",
        },
    },
    {
        t = "🧟 ПРО НЕЧТО",
        lines = {
            "• Кто-то на станции может быть НЕ ТЕМ, за кого себя выдаёт.",
            "• Тест крови (учёные) — единственный надёжный способ проверить.",
            "• Огонь и огнемёт — лучшее оружие против твари.",
            "• Не оставайся один в темноте. Доверяй, но проверяй.",
            "• НКВД ведёт допросы и досье — это РП, участвуй честно.",
        },
    },
    {
        t = "📣 ПРОИСШЕСТВИЯ СТАНЦИИ",
        lines = {
            "• Каждые 20–40 минут на станции случайное событие:",
            "  обрыв связи, замыкание, сигнал с поверхности, пропажа припасов,",
            "  крик в вентиляции.",
            "• Участвуй — станция это ценит (награды за события).",
            "• Ивенты для себя делают сами игроки, админы всегда помогают —",
            "  пиши в чат, организуй РП-сцену!",
        },
    },
}

local function DoneAlready()
    return file.Exists(GUIDE_FILE, "DATA")
end

local function MarkDone()
    if not file.IsDir("polus11", "DATA") then file.CreateDir("polus11") end
    file.Write(GUIDE_FILE, "done " .. os.date("%Y-%m-%d %H:%M"))
end

function P11.OpenGuide()
    if IsValid(P11.GuideFrame) then P11.GuideFrame:Remove() end

    local W, H = 760, 640
    local f = vgui.Create("DFrame")
    P11.GuideFrame = f
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 56, C.pane, true, true, false, false)
        surface.SetDrawColor(C.gold)
        surface.DrawRect(0, 56, w, 2)
        draw.SimpleText("🧊 ПОЛЮС-11 — ГАЙД НОВИЧКА", "P11.Guide.Big", 16, 12, C.gold)
        draw.SimpleText("все механики станции · ESC закрыть · повторный запуск: p11_guide", "P11.Guide.Tx", 16, 38, C.dim)
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(W - 38, 12) x:SetSize(26, 26) x:SetText("✕")
    x:SetFont("P11.Guide.Mid") x:SetTextColor(C.dim)
    x.Paint = function() end
    x.DoClick = function() f:Remove() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 66) sc:SetSize(W - 24, H - 150)
    local bar = sc:GetVBar() bar:SetWide(5)
    bar.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 14)) end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, C.gold) end

    for _, s in ipairs(SECTIONS) do
        local head = vgui.Create("DPanel", sc)
        head:Dock(TOP) head:DockMargin(0, 4, 0, 0) head:SetTall(34)
        head.Paint = function(pl, w, h)
            draw.RoundedBox(5, 0, 0, w, h, Color(255, 205, 100, 16))
            surface.SetDrawColor(255, 205, 100, 120)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(s.t, "P11.Guide.Mid", 12, h / 2, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        for _, ln in ipairs(s.lines) do
            local row = vgui.Create("DLabel", sc)
            row:Dock(TOP) row:DockMargin(4, 0, 4, 0) row:SetTall(20)
            row:SetFont("P11.Guide.Tx")
            row:SetTextColor(C.txt)
            row:SetText("  " .. ln)
            row:SetWrap(true)
            row:SizeToContentsY()
        end
    end

    local closeBtn = vgui.Create("DButton", f)
    closeBtn:SetPos(12, H - 74) closeBtn:SetSize(W - 24, 46) closeBtn:SetText("")
    closeBtn.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h,
            s:IsHovered() and Color(255, 205, 100, 235) or Color(150, 120, 55, 220))
        draw.SimpleText("ПОНЯТНО, ПОЕХАЛИ →", "P11.Guide.Mid", w / 2, h / 2 - 1,
            Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function() f:Remove() MarkDone() end

    surface.PlaySound("buttons/button14.wav")
end

-- ============ ПЕРВЫЙ ВХОД: показать один раз ============
hook.Add("InitPostEntity", "P11.GuideFirst", function()
    timer.Simple(6, function()
        if not IsValid(LocalPlayer()) then return end
        if DoneAlready() then return end
        P11.OpenGuide()
    end)
end)

-- повторный запуск с консоли
concommand.Add("p11_guide", function()
    P11.OpenGuide()
end)

-- короткая подсказка в чат при первом входе (однажды)
hook.Add("InitPostEntity", "P11.GuideHint", function()
    timer.Simple(8, function()
        if not IsValid(LocalPlayer()) then return end
        if DoneAlready() then return end
        chat.AddText(C.gold, "[ПОЛЮС-11] ", C.txt, "Гайд новичка открыт. Повторно: p11_guide · памятка: F1")
    end)
end)

print("[POLUS-11] ГАЙД НОВИЧКА v5.4.3 (client, autorun): без ярмарки")
