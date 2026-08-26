-- ============================================================
--  ПОЛЮС-11 — БОДИГРУППЫ ВНЕШНОСТИ v5.7.7 (КЛИЕНТ, энтити bgmenu)
--  Кнопка «🎭 Внешность» в С-меню → окно управления бодигруппами
--  модели: ◀ ▶ меняет группу, СБРОС — в 0. Изменение сразу видно
--  себе, сервер применяет всем и сохраняет (data/bodygroups.json),
--  при новом спавне внешность восстанавливается.
--
--  ДОСТАВКА: cl_init энтити раздаётся клиентам ВСЕГДА (не зависит
--  от sv_allowcslua). Энтити спавнится сервером.
--  Старые файлы не трогаем — P11.OpenCMenu оборачиваем поверх.
-- ============================================================

if not P11 then P11 = {} end

-- шрифты окна (свои, чтобы не зависеть от порядка загрузки)
surface.CreateFont("P11.BG.Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.BG.Text",  { font = "Roboto", size = 17, weight = 600, extended = true })
surface.CreateFont("P11.BG.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

-- палитра в стиле С-меню
local BG = {
    bg    = Color(10, 14, 20, 250),
    panel = Color(20, 26, 36, 255),
    cyan  = Color(120, 185, 255),
    gold  = Color(255, 205, 110),
    text  = Color(228, 236, 245),
    dim   = Color(150, 165, 180),
    ok    = Color(115, 215, 135),
    bad   = Color(235, 100, 90),
    hover = Color(38, 50, 68, 255),
}

-- =================== ОКНО БОДИГРУПП ===================
-- v5.8.24: защищённая отправка (если канал вдруг не зарегистрирован —
-- не сыпем ошибки «unpooled», просто молча пропускаем)
local function BGNet()
    local ok = pcall(function()
        net.Start("P11_BGSet")
    end)
    return ok
end

local function OpenBodyGroups()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if IsValid(P11.BGFrame) then P11.BGFrame:Remove() end

    local n = me:GetNumBodyGroups()

    local f = vgui.Create("DFrame")
    P11.BGFrame = f
    f:SetSize(520, 62 + n * 46 + 64)
    f:Center()
    f:MakePopup()
    f:SetSizable(false)
    f:SetDeleteOnClose(true)
    f:SetTitle("")
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    f.Paint = function(s, ww, hh)
        draw.RoundedBox(10, 0, 0, ww, hh, BG.bg)
        draw.RoundedBoxEx(10, 0, 0, ww, 44, BG.panel, true, true, false, false)
        draw.SimpleText("ВНЕШНОСТЬ — БОДИГРУППЫ", "P11.BG.Title", 14, 22, BG.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("сохраняется автоматически", "P11.BG.Small", ww - 14, 22, BG.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("◀ ▶ — изменить · СБРОС — в 0", "P11.BG.Small", ww / 2, hh - 12, BG.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local y = 56
    for i = 0, n - 1 do
        local cnt = me:GetBodygroupCount(i)
        local bname = me:GetBodygroupName(i)
        if bname == "" then bname = "Группа " .. (i + 1) end
        local cur = me:GetBodygroup(i)

        local row = vgui.Create("DPanel", f)
        row:SetPos(10, y) row:SetSize(500, 40)
        row.Paint = function(s, ww, hh)
            draw.RoundedBox(6, 0, 0, ww, hh, BG.panel)
            draw.SimpleText(bname, "P11.BG.Text", 12, hh / 2, BG.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local valLab = vgui.Create("DLabel", row)
        valLab:SetPos(320, 0) valLab:SetSize(56, 40)
        valLab:SetFont("P11.BG.Text") valLab:SetTextColor(BG.cyan)
        valLab:SetText(tostring(cur))

        local function Btn(x, w, txt, col, fn, enabled)
            local b = vgui.Create("DButton", row)
            b:SetPos(x, 5) b:SetSize(w, 30)
            b:SetText("")
            b.Paint = function(s, ww, hh)
                local hov = s:IsHovered() and s:IsEnabled()
                draw.RoundedBox(5, 0, 0, ww, hh, hov and Color(col.r + 20, col.g + 20, col.b + 20, 255) or Color(col.r, col.g, col.b, 220))
                draw.SimpleText(txt, "P11.BG.Small", ww / 2, hh / 2, Color(10, 14, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            if enabled == false then b:SetEnabled(false) end
            b.DoClick = fn
            return b
        end

        local function SetVal(v)
            if cnt < 1 then return end
            v = math.Clamp(v, 0, cnt - 1)
            me:SetBodygroup(i, v) -- сразу видно у себя
            valLab:SetText(tostring(v))
            if BGNet() then
                net.WriteInt(i, 8)
                net.WriteUInt(v, 8)
                net.SendToServer()
            end
        end

        if cnt > 1 then
            Btn(382, 34, "◀", BG.cyan, function() SetVal(me:GetBodygroup(i) - 1) end)
            Btn(420, 34, "▶", BG.cyan, function() SetVal(me:GetBodygroup(i) + 1) end)
        else
            local nl = vgui.Create("DLabel", row)
            nl:SetPos(382, 0) nl:SetSize(110, 40)
            nl:SetFont("P11.BG.Small") nl:SetTextColor(BG.dim)
            nl:SetText("нет вариантов")
        end
        Btn(458, 32, "СБРОС", BG.bad, function() SetVal(0) end)

        y = y + 46
    end

    -- сбросить всю внешность
    local rb = vgui.Create("DButton", f)
    rb:SetPos(10, y + 2) rb:SetSize(500, 34)
    rb:SetText("")
    rb.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        draw.RoundedBox(6, 0, 0, ww, hh, hov and Color(70, 30, 28, 255) or Color(52, 22, 20, 255))
        draw.SimpleText("СБРОСИТЬ ВСЮ ВНЕШНОСТЬ", "P11.BG.Text", ww / 2, hh / 2, BG.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    rb.DoClick = function()
        for i = 0, n - 1 do me:SetBodygroup(i, 0) end
        if BGNet() then
            net.WriteInt(-1, 8)
            net.WriteUInt(0, 8)
            net.SendToServer()
        end
        OpenBodyGroups() -- перерисовать
    end
end
P11.OpenBodyGroups = OpenBodyGroups

-- =================== КНОПКА В С-МЕНЮ ===================
local function AddBGButton()
    local m = P11 and P11.CMenu
    if not IsValid(m) then return end
    if IsValid(P11.BGBtn) then return end -- уже добавлена в это меню

    local me = LocalPlayer()
    local isAdmin = P11FW and P11FW.Config and P11FW.Config.Admin and P11FW.Config.Admin(me)
    local canWl = (not isAdmin) and P11FW.CanWhitelist and P11FW.CanWhitelist(me)

    -- у админов/вайтлиста правая колонка занята секцией прав, левая свободна
    local x, y, w, h
    if isAdmin or canWl then
        x, y, w, h = 14, 416, 498, 36
    else
        x, y, w, h = 532, 364, 234, 48
    end

    local b = vgui.Create("DButton", m)
    b:SetPos(x, y) b:SetSize(w, h)
    b:SetText("")
    b.Paint = function(s, ww, hh)
        local hov = s:IsHovered()
        local small = hh <= 40
        draw.RoundedBox(6, 0, 0, ww, hh, hov and BG.hover or Color(24, 30, 42, 255))
        if hov then
            surface.SetDrawColor(BG.cyan)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
        end
        local isz = small and 24 or 28
        draw.RoundedBox(6, 6, (hh - isz) / 2, isz, isz, Color(BG.cyan.r, BG.cyan.g, BG.cyan.b, 40))
        draw.SimpleText("🎭", "P11.BG.Small", 6 + isz / 2, hh / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if small then
            draw.SimpleText("Внешность (бодигруппы)", "P11.BG.Text", 40, hh / 2, BG.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Внешность", "P11.BG.Text", 40, hh / 2 - 9, BG.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("бодигруппы модели", "P11.BG.Small", 40, hh / 2 + 10, BG.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    b.DoClick = function()
        if P11.CloseCMenu then P11.CloseCMenu() end
        OpenBodyGroups()
    end
    P11.BGBtn = b
end

-- ============ ОБЁРТКА ОТКРЫТИЯ С-МЕНЮ (файл гейммода не трогаем) ============
local patched = false
local function EnsurePatch()
    if patched then return true end
    if not P11 or not P11.OpenCMenu then return false end
    local orig = P11.OpenCMenu
    P11.OpenCMenu = function(...)
        if orig then orig(...) end
        AddBGButton()
    end
    patched = true
    return true
end

hook.Add("Think", "P11.BG.Patch", function()
    EnsurePatch()
    -- страховка: меню могло открыться до обёртки
    if IsValid(P11 and P11.CMenu) then AddBGButton() end
end)
