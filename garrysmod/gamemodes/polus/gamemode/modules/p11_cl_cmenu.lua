-- ============================================================
--  ПОЛЮС-11 — С-МЕНЮ ИГРОКА (client) v3.8
--  Холдишь C — станционное меню: ЖЕСТЫ, БЫСТРЫЕ ДЕЙСТВИЯ,
--  у админов — «МЕНЮ МОДЕЛЕЙ» и кнопка админ-панели (/menu).
--
--  v3.8 — ПОЧИНКА ОТКРЫТИЯ:
--  Раньше в shared.lua стояло GM:ContextMenuOpen = false —
--  движок обрывал цепочку +menu_context на корню и у части
--  игроков меню просто НЕ ОТКРЫВАЛОСЬ. Теперь шлюз открыт,
--  а ванильное C-окно глушится перекрытием чистого клиентского
--  GM:OnContextMenuOpen (он же и открывает наше меню), плюс
--  старый перехват через PlayerBindPress оставлен страховкой.
--  ПЛАВНОСТЬ: выезд снизу + нарастание прозрачности + затемнение
--  экрана под меню. Меню моделей отмечает отсутствующие модели
--  (воркшоп-паки) красными ячейками, а не молчаливыми ERROR.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.CM.Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.CM.Text",  { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("P11.CM.Small", { font = "Roboto", size = 13, weight = 400, extended = true })
surface.CreateFont("P11.CM.Mdl",   { font = "Roboto", size = 19, weight = 800, extended = true })

local CC = {
    bg    = Color(12, 17, 24, 240),
    panel = Color(20, 28, 38, 255),
    cyan  = Color(120, 200, 240),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    dim   = Color(150, 165, 180),
    ok    = Color(115, 215, 135),
    bad   = Color(235, 100, 90),
}

-- жесты в порядке серверной таблицы fw_sv_emotes.lua
local EMOTES = {
    { id = 1, glyph = "👋", name = "Махнуть",      desc = "приветствие" },
    { id = 2, glyph = "🫡", name = "Салют",        desc = "по-военному" },
    { id = 3, glyph = "✔", name = "Кивнуть «да»",  desc = "согласие" },
    { id = 4, glyph = "✖", name = "Мотнуть «нет»", desc = "отрицание" },
    { id = 5, glyph = "👉", name = "Сюда!",        desc = "подозвать" },
    { id = 6, glyph = "🎉", name = "Ликовать",     desc = "радость" },
    { id = 7, glyph = "🤝", name = "Отдать",       desc = "протянуть вещь" },
    { id = 8, glyph = "📦", name = "Положить",     desc = "уложить вещь" },
}

local function CButton(parent, x, y, w, h, name, desc, col, click)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y) b:SetSize(w, h)
    b:SetText("")
    b.PName, b.PDesc, b.PCol = name, desc, col or CC.text
    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        draw.RoundedBox(6, 0, 0, ww, hh, hov and Color(255, 255, 255, 22) or CC.panel)
        draw.RoundedBoxEx(6, 0, 0, 4, hh, Color(s.PCol.r, s.PCol.g, s.PCol.b, hov and 255 or 170), true, false, true, false)
        draw.SimpleText(s.PName, "P11.CM.Text", 14, desc and (hh / 2 - 9) or (hh / 2), s.PCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if desc then
            draw.SimpleText(s.PDesc, "P11.CM.Small", 14, hh / 2 + 11, CC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        click()
    end
    return b
end

-- ============================================================
--  ПОЯВЛЕНИЕ: общий помощник «выезд снизу + проявление» (v3.8)
-- ============================================================

local TWEEN_LEN = 0.22

local function TweenK(s)
    local k = math.Clamp((SysTime() - (s.AnimT or 0)) / TWEEN_LEN, 0, 1)
    return 1 - (1 - k) ^ 3 -- easeOutCubic
end

-- вешает на панель: выезд снизу на 22 px + мягкое затемнение ВСЕГО
-- экрана под панелью. k — прогресс анимации (0..1) для Paint.
function P11.AnimateIn(s)
    s.AnimT = SysTime()
    local tx, ty = s:GetPos()
    s:SetPos(tx, ty + 22)
    s.Think = function()
        s:SetPos(tx, ty + 22 * (1 - TweenK(s)))
    end
end

-- рисовать ПЕРВЫМ в Paint: затемнение экрана вокруг окна
function P11.DrawDim(s, strength)
    local x, y = s:GetPos()
    surface.SetDrawColor(5, 9, 13, (strength or 150) * TweenK(s))
    surface.DrawRect(-x, -y, ScrW(), ScrH())
end

function P11.CloseCMenu()
    if IsValid(P11.CMenu) then P11.CMenu:Remove() end
end

-- ============================================================
--  ПАНЕЛЬ C-МЕНЮ
-- ============================================================

function P11.OpenCMenu()
    if IsValid(P11.CMenu) then P11.CMenu:Remove() end

    local me = LocalPlayer()
    local f = vgui.Create("DPanel")
    P11.CMenu = f
    f.T0 = SysTime()
    f:SetSize(560, 470)
    f:Center()
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    P11.AnimateIn(f)

    f.Paint = function(s, w, h)
        P11.DrawDim(s, 165)                                        -- затемнение экрана
        surface.SetAlphaMultiplier(0.25 + 0.75 * TweenK(s))        -- проявление тела
        Derma_DrawBackgroundBlur(s, s.T0 or 0)
        draw.RoundedBox(10, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 52, CC.panel, true, true, false, false)
        surface.SetDrawColor(CC.cyan)
        surface.DrawRect(0, 52, w, 2)
        draw.SimpleText("ДЕЙСТВИЯ НА СТАНЦИИ", "P11.CM.Title", 16, 26, CC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("удерживай C • ESC — закрыть", "P11.CM.Small", w - 14, 26, CC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetAlphaMultiplier(1)
    end

    -- ---- левая колонка: ЖЕСТЫ ----
    local gl = vgui.Create("DLabel", f)
    gl:SetPos(14, 62) gl:SetSize(340, 16)
    gl:SetFont("P11.CM.Small") gl:SetTextColor(CC.cyan)
    gl:SetText("ЖЕСТЫ (видят все вокруг):")

    for i, em in ipairs(EMOTES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        CButton(f, 14 + col * 172, 84 + row * 48, 166, 42,
            em.glyph .. "  " .. em.name, em.desc, CC.text, function()
                net.Start("P11_Emote")
                    net.WriteUInt(em.id, 4)
                net.SendToServer()
            end)
    end

    -- ---- правая колонка: БЫСТРОЕ ----
    local rl = vgui.Create("DLabel", f)
    rl:SetPos(370, 62) rl:SetSize(176, 16)
    rl:SetFont("P11.CM.Small") rl:SetTextColor(CC.cyan)
    rl:SetText("БЫСТРОЕ:")

    CButton(f, 370, 84, 176, 42, "📋 Должности", "меню F4", CC.ok, function()
        P11.CloseCMenu()
        P11FW.OpenJobMenu()
    end)

    CButton(f, 370, 132, 176, 42, "❓ Справка", "памятка новичка F1", CC.text, function()
        P11.CloseCMenu()
        RunConsoleCommand("p11_help")
    end)

    CButton(f, 370, 180, 176, 42, "🎲 Кубик 1-100", "кто идёт в тёмный коридор", CC.gold, function()
        LocalPlayer():ConCommand("say !ролл")
    end)

    CButton(f, 370, 228, 176, 42, "💈 Пустые руки", "знак мира", CC.text, function()
        RunConsoleCommand("use", "weapon_polus11_hands")
    end)

    -- админская секция
    if P11FW.Config.Admin(me) then
        local al = vgui.Create("DLabel", f)
        al:SetPos(370, 280) al:SetSize(176, 16)
        al:SetFont("P11.CM.Small") al:SetTextColor(CC.bad)
        al:SetText("АДМИНИСТРАЦИИ:")

        CButton(f, 370, 300, 176, 42, "🧍 Меню моделей", "браузер внешности", CC.gold, function()
            P11.CloseCMenu()
            P11.OpenModelMenu()
        end)

        CButton(f, 370, 348, 176, 42, "🛡 Админ-панель", "то же, что /menu", CC.bad, function()
            P11.CloseCMenu()
            P11FW.OpenAdminMenu()
        end)
    end

    -- низ: подсказка
    local foot = vgui.Create("DLabel", f)
    foot:SetPos(14, 442) foot:SetSize(532, 18)
    foot:SetFont("P11.CM.Small") foot:SetTextColor(CC.dim)
    local rk = P11FW.GetRankName and P11FW.GetRankName(me) or "User"
    foot:SetText("Ты — " .. rk .. " • документы и пустые руки уже в твоём снаряжении • C закроет это меню")

    -- закрытие по ESC
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end
    f.OpenedAt = CurTime()
end

-- жест C закрывает меню (отпустил — закрылось, с небольшим лагом)
hook.Add("Think", "P11.CMenuClose", function()
    if not IsValid(P11.CMenu) then return end
    if CurTime() - (P11.CMenu.OpenedAt or 0) < 0.35 then return end
    if not input.IsKeyDown(KEY_C) then
        P11.CloseCMenu()
    end
end)

-- ============================================================
--  ОТКРЫТИЕ ПО C — три независимых канала (v3.8)
-- ============================================================

-- 1) КЛИЕНТСКИЙ ПЕРЕХВАТ ГЕЙММОДА: движок вызывает это на зажатие/отпуск
--    +menu_context у base-производных гейммодов. Перекрытие именно ТУТ
--    (а не через ContextMenuOpen=false!) — корень починки «C не работает».
function GAMEMODE:OnContextMenuOpen()
    if P11.IntroOpen then return end
    if not IsValid(P11.CMenu) then
        P11.OpenCMenu()
    end
end

function GAMEMODE:OnContextMenuClose()
    -- отпустил C — закрываем (Think-страховка выше тоже справится)
    if IsValid(P11.CMenu) and CurTime() - (P11.CMenu.OpenedAt or 0) > 0.35 then
        P11.CloseCMenu()
    end
end

-- 2) страховка: прямой перехват бинда (срабатывает раньше натива и там,
--    где натив глушат чужие аддоны). Возврат true глушит ванильные цепочки.
hook.Add("PlayerBindPress", "P11.CMenuBind", function(ply, bind, pressed)
    if not pressed then return end
    if not string.find(bind, "+menu_context") then return end
    if P11.IntroOpen then return true end
    if IsValid(P11.CMenu) then P11.CloseCMenu() else P11.OpenCMenu() end
    return true -- глушим стандартное открытие песочницы
end)

-- ============================================================
--  МЕНЮ МОДЕЛЕЙ (АДМИН) — знакомый браузер внешности
--  v3.8: модели, которых нет на клиенте (воркшоп-паки), показаны
--  красными ячейками-подсказками вместо розовых ERROR, и выезд
--  снизу + затемнение, как у C-меню.
-- ============================================================

function P11.OpenModelMenu()
    if IsValid(P11.ModelFrame) then P11.ModelFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11.ModelFrame = f
    f.T0 = SysTime()
    f:SetSize(760, 560)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)

    P11.AnimateIn(f)

    f.Paint = function(s, w, h)
        P11.DrawDim(s, 165)
        surface.SetAlphaMultiplier(0.25 + 0.75 * TweenK(s))
        Derma_DrawBackgroundBlur(f, f.T0 or 0)
        draw.RoundedBox(10, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 56, CC.panel, true, true, false, false)
        surface.SetDrawColor(CC.gold)
        surface.DrawRect(0, 56, w, 2)
        draw.SimpleText("МЕНЮ МОДЕЛЕЙ — браузер внешности", "P11.CM.Mdl", 14, 28,
            CC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("клик — надеть себе (до респавна/смены должности)", "P11.CM.Small", w - 40, 28,
            CC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetAlphaMultiplier(1)
    end
    function f:OnKeyCodePressed(key) if key == KEY_ESCAPE then f:Remove() end end

    local xB = vgui.Create("DButton", f)
    xB:SetPos(760 - 38, 12) xB:SetSize(24, 24)
    xB:SetText("✕") xB:SetFont("P11.CM.Mdl") xB:SetTextColor(CC.dim)
    xB.Paint = function() end
    xB.DoClick = function() f:Remove() end

    -- поиск
    local search = vgui.Create("DTextEntry", f)
    search:SetPos(12, 64) search:SetSize(520, 26)
    search:SetPlaceholderText("поиск модели по пути (models/player/...)")

    -- статус списка (справа от поиска)
    local stats = vgui.Create("DLabel", f)
    stats:SetPos(540, 69) stats:SetSize(212, 16)
    stats:SetFont("P11.CM.Small") stats:SetTextColor(CC.dim)
    stats:SetText("")

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 96) sc:SetSize(736, 452)
    local sb = sc:GetVBar() sb:SetWide(5)

    local grid = vgui.Create("DIconLayout", sc)
    grid:Dock(FILL)
    grid:SetSpaceX(6) grid:SetSpaceY(6)

    local function Fill(filter)
        grid:Clear()
        filter = string.lower(string.Trim(filter or ""))
        local opts = list.Get("PlayerOptionsModel") or {}
        local names = {}
        for name in pairs(opts) do names[#names + 1] = name end
        table.sort(names)
        local shown, missing = 0, 0
        for _, name in ipairs(names) do
            local mdl = string.lower(tostring(opts[name]))
            if shown + missing < 260 and (filter == "" or string.find(mdl, filter, 1, true)) then
                if file.Exists(mdl, "GAME") then
                    shown = shown + 1
                    local ic = vgui.Create("SpawnIcon", grid)
                    ic:SetSize(72, 72)
                    ic:SetModel(opts[name])
                    ic:SetTooltip(mdl)
                    ic.DoClick = function()
                        surface.PlaySound("buttons/button15.wav")
                        net.Start("P11_AdminModel")
                            net.WriteString(opts[name])
                        net.SendToServer()
                    end
                else
                    -- модели клиент НЕ видит: пак не смонтирован (см. P11FW.Config.WorkshopAddons)
                    missing = missing + 1
                    local bad = vgui.Create("DButton", grid)
                    bad:SetSize(72, 72)
                    bad:SetText("")
                    bad:SetTooltip(mdl .. "\n\n⚠ модель не смонтирована на этом клиенте\n(путь из воркшоп-пака — подключи его на сервере)")
                    bad.Paint = function(s, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(60, 26, 26) or Color(36, 20, 22))
                        surface.SetDrawColor(CC.bad)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                        draw.SimpleText("ВОРК-", "P11.CM.Small", w / 2, h / 2 - 12, CC.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText("ШОП?", "P11.CM.Small", w / 2, h / 2, CC.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        draw.SimpleText("нет на ПК", "P11.CM.Small", w / 2, h / 2 + 12, CC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    bad.DoClick = function()
                        surface.PlaySound("buttons/button10.wav")
                    end
                end
            end
        end
        if shown + missing == 0 then
            local l = grid:Add("DLabel")
            l:SetFont("P11.CM.Small") l:SetTextColor(CC.dim)
            l:SetText("  ничего не найдено")
            l:SizeToContents()
        end
        stats:SetText("моделей: " .. shown .. (missing > 0 and ("  (+ " .. missing .. " без пака)") or ""))
        stats:SizeToContentsX()
    end
    Fill("")
    search.OnChange = function(s) Fill(s:GetValue()) end
end

concommand.Add("p11_models", function()
    if P11FW.Config.Admin(LocalPlayer()) then P11.OpenModelMenu() end
end)
