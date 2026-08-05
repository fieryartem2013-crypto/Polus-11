-- ============================================================
--  ПОЛЮС-11 — СПРАВКА НОВИЧКА (F1) (client) v2.7
--  Дёшево и сердито снимает 80% вопросов «а что делать?».
--  F1 / concommand p11_help. Контент правится текстом тут.
-- ============================================================

surface.CreateFont("P11.Help.Big", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.Help.Mid", { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Help.Text", { font = "Roboto", size = 14, weight = 400, extended = true })

local HELP = {
    { h = "ЧТО ЭТО ЗА РЕЖИМ?", t = "Станция «Полюс-11», Антарктида, 1982. Гарнизон и учёные против НЕЧТО — существа, которое съедает человека и идеально копирует его: лицо, голос, даже имя в чате. Кто-то из присутствующих уже может быть не тем, за кого себя выдаёт." },
    { h = "С ЧЕГО НАЧАТЬ?", t = "1) Подойди к NPC-кадровику (E) или жми F4 и возьми должность. 2) Выполняй задачи смены (список слева на экране). 3) Следи за генератором: без солярки — темнота, а в темноте работает Нечто. 4) Доверяй только огню и тесту крови." },
    { h = "КЛАВИШИ", t = "F1 — эта справка • F4 — должности • F2 — ВИД ОТ 3-ГО ЛИЦА / назад • F3 — СВОБОДНЫЙ КУРСОР • TAB — состав станции • C (удерживать) — ДЕЙСТВИЯ/ЖЕСТЫ • Q — строительство (пропы-«призраки», E — взять/поставить) • /р + текст — рация • !работа — меню должностей • !репорт — написать админам • !ролл — кубик • /menu — админам панель." },
    { h = "ГЕНЕРАТОР И ХОЛОД (v3.7)", t = "Генератор ИЗНАШИВАЕТСЯ: шкала износа на нём; после 50% ломается (перегрев/утечка/стартер/скачки) — держи E для техосмотра. CTRL+E — режим ОСНОВНОЙ/РЕЗЕРВ (резерв молчит, пока свет есть). Замёрзнешь на морозе — грейся у работающего генератора, в помещении, ешь горячий паёк. Бочки с соляркой таскает ГРУЗЧИК (E — на плечо)." },
    { h = "НОВЫЕ ЛИЦА (v3.7)", t = "Грузчик — переноска грузов на плече, почти не сбавляет шаг. Техник-механик — дежурный по генераторам, чинит вдвое быстрее. Полевой медик — ПКМ шприца ЛЕЧИТ раненых (+12 ХП)." },
    { h = "ДОКУМЕНТЫ", t = "У каждого в снаряжении есть удостоверение (SWEP «Документы») с уникальным кодом, ЗАКРЕПЛЁННЫМ ЗА ТОБОЙ на всю смену (код не меняется после смерти — только при перезаходе). ЛКМ/R — предъявить ближайшему: он увидит имя, ФРАКЦИЮ, должность и код. Нечто под маской покажет украденное имя — проверка личности только усиливает паранойю." },
    { h = "КТО ЗДЕСЬ КТО?", t = "Охрана — периметр. Офицер — ПРИКАЗ (!приказ) и РОЗЫСК (!розыск). Повар — кормит, таскает бочки. ГРУЗЧИК — носит грузы на плече, бочка у генератора сама заправит. Лаборант/Вирусолог — кровь и тесты. МЕДИК — лечит ПКМ шприца. Инженер — огнемёт и аварии. ТЕХНИК — дежурный по генераторам (износ, поломки, режимы)." },
    { h = "НОВИНКИ v3.8", t = "F2 — красивое третье лицо (оглядеть себя и угол за спиной), F3 — отцепить курсор и потыкать экраны. Код документов теперь твой на всю смену. TАB и никтеги показывают, ЧЬЯ фракция/профа. Динамик говорящего висит ПОД именем, а панельки голосового чата переехали влево вниз — ничего не закрывают. Вечную изморозь по краям экрана убрали: лёд только в бурю и при обморожении." },
    { h = "ЕСЛИ ТЫ НЕЧТО...", t = "Никому не показывайся. Поглощай трупы, воруй личности, действуй в темноте. R — маскировка под человека, !крик — устрашение, !форма — смена тела (Имитатор/Поглотитель/Споровик/Разделённый). Помни: тест крови и вскрытие выдают тебя с потрохами." },
    { h = "ПРАВИЛА СТАНЦИИ", t = "Не мешай RP. Не палюй стройку (пропы твердеют, только когда рядом никого). Арест/рабство/бан — за дело, жалобы на экране вверху. Вопросы — администрации (звание в TAB)." },
}

local function ToggleHelp()
    if IsValid(POLUS11.HelpFrame) then POLUS11.HelpFrame:Remove() return end

    local f = vgui.Create("DFrame")
    POLUS11.HelpFrame = f
    f.T0 = SysTime()
    f:SetSize(640, 560)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)

    function f:Paint(w, h)
        Derma_DrawBackgroundBlur(self, self.T0 or 0)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 16, 22, 245))
        draw.RoundedBoxEx(8, 0, 0, w, 52, Color(22, 30, 40), true, true, false, false)
        surface.SetDrawColor(140, 200, 240)
        surface.DrawRect(0, 52, w, 2)
        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11» — ПАМЯТКА СМЕНЫ", "P11.Help.Big", 16, 13, Color(150, 210, 240))
        draw.SimpleText("F1 — закрыть", "P11.Help.Text", w - 14, 26, Color(140, 150, 165), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    function f:OnKeyCodePressed(key) if key == KEY_F1 or key == KEY_ESCAPE then f:Remove() end end

    local xB = vgui.Create("DButton", f)
    xB:SetPos(640 - 36, 12) xB:SetSize(24, 24)
    xB:SetText("✕") xB:SetFont("P11.Help.Big") xB:SetTextColor(Color(140, 150, 165))
    xB.Paint = function() end
    xB.DoClick = function() f:Remove() end

    local scroll = vgui.Create("DScrollPanel", f)
    scroll:SetPos(12, 62) scroll:SetSize(616, 488)
    local sb = scroll:GetVBar() sb:SetWide(6)
    sb.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(255, 255, 255, 18)) end
    sb.btnGrip.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(140, 200, 240)) end

    for _, block in ipairs(HELP) do
        local head = scroll:Add("DLabel")
        head:Dock(TOP) head:DockMargin(4, 12, 0, 0)
        head:SetFont("P11.Help.Mid") head:SetTextColor(Color(230, 200, 110))
        head:SetText(block.h) head:SizeToContents()

        local body = scroll:Add("DLabel")
        body:Dock(TOP) body:DockMargin(8, 2, 8, 0)
        body:SetWide(590)
        body:SetFont("P11.Help.Text") body:SetTextColor(Color(215, 220, 228))
        body:SetText(block.t) body:SetAutoStretchVertical(true) body:SetWrap(true)
    end
end

concommand.Add("p11_help", ToggleHelp)

hook.Add("PlayerBindPress", "P11.HelpF1", function(ply, bind, pressed)
    if not pressed then return end
    if bind == "gm_showhelp" then
        ToggleHelp()
        return true
    end
end)
