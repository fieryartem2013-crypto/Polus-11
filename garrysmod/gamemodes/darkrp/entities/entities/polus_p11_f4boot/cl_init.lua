-- ============================================================
--  ПОЛЮС-11 — F4: ПОКАЗ «ЗАКРЫТО» ДЛЯ ДРЕВО-ПРОФ v5.7.2 (client)
--  Владелец: «если профа не открыта через древо — показывать,
--  что она ЗАКРЫТА, а не как будто доступна».
--  Штатный F4 не имел проверки древа → древо-профы выглядели
--  доступными. Этот файл (энтити f4boot, доставка гарантирована)
--  переопределяет P11FW.OpenJobMenu: добавлена блокировка
--  treeBlocked («🔒 ЗАКРЫТО — ДРЕВО СЛУЖБЫ»), кнопка блокируется,
--  клик объясняет причину. Старые файлы не трогаем.
-- ============================================================

local TREE_XP = { 0, 150, 400, 800, 1400, 2200, 3200, 4500, 6000, 8000 }

local TREE_JOB = {
    ["seed_crime_baryga"] = { fac = "dno", id = "cr_bar", lvl = 4, path = false },
    ["seed_crime_bychok"] = { fac = "dno", id = "cr_bych", lvl = 2, path = false },
    ["seed_crime_glavar"] = { fac = "verh", id = "cr_gla", lvl = 7, path = false },
    ["seed_crime_kontrband"] = { fac = "kontr", id = "cr_kon", lvl = 2, path = false },
    ["seed_crime_kurer"] = { fac = "base", id = "cr_kur", lvl = 0, path = false },
    ["seed_crime_skupshik"] = { fac = "verh", id = "cr_sku", lvl = 5, path = false },
    ["seed_crime_vzlomshik"] = { fac = "kontr", id = "cr_vzl", lvl = 4, path = false },
    ["seed_rkka_general"] = { fac = "razved", id = "rk_gen", lvl = 9, path = false },
    ["seed_rkka_generalpeh"] = { fac = "shturm", id = "rk_gpeh", lvl = 9, path = false },
    ["seed_rkka_komissar"] = { fac = "razved", id = "rk_kom", lvl = 6, path = false },
    ["seed_rkka_letchik"] = { fac = "shturm", id = "rk_let", lvl = 7, path = false },
    ["seed_rkka_medglav"] = { fac = "med", id = "rk_mg", lvl = 6, path = false },
    ["seed_rkka_medsestra"] = { fac = "med", id = "rk_ms", lvl = 3, path = false },
    ["seed_rkka_novobranets"] = { fac = "base", id = "rk_nov", lvl = 0, path = false },
    ["seed_rkka_postovoy"] = { fac = "base", id = "rk_post", lvl = 1, path = false },
    ["seed_rkka_pulemetchik"] = { fac = "shturm", id = "rk_pul", lvl = 5, path = false },
    ["seed_rkka_razvedchik"] = { fac = "razved", id = "rk_raz", lvl = 3, path = false },
    ["seed_rkka_shturmovik"] = { fac = "shturm", id = "rk_sht", lvl = 3, path = false },
    ["seed_rkka_snabzhenets"] = { fac = "shturm", id = "rk_snab", lvl = 4, path = false },
    ["seed_rkka_soldat"] = { fac = "base", id = "rk_sold", lvl = 2, path = false },
    ["seed_sci_biohim"] = { fac = "bio", id = "sc_bio", lvl = 2, path = false },
    ["seed_sci_laborant"] = { fac = "base", id = "sc_lab", lvl = 0, path = false },
    ["seed_sci_menedzher"] = { fac = "upr", id = "sc_men", lvl = 5, path = false },
    ["seed_sci_sozdatel"] = { fac = "bio", id = "sc_soz", lvl = 6, path = false },
    ["seed_sci_ucheniy"] = { fac = "base", id = "sc_uch", lvl = 1, path = false },
    ["seed_sci_vedushiy"] = { fac = "upr", id = "sc_ved", lvl = 3, path = false },
}

-- ============================================================
--  ПОЛЮС FRAMEWORK — F4: КАРТОТЕКА ПЕРСОНАЛА (client) v2.0 «СИЯНИЕ» (v4.26.0)
--  Редизайн v2: шире и красивее — «карта должности» с портретом,
--  значками допусков (терминал/командир), чипами снаряжения,
--  бегущим бликом и анимированной разметкой фракций.
--  Открывается по F4, E у кадровика, чатом !работа.
-- ============================================================

-- v4.6.2: F4 крупнее (заявка владельца)
surface.CreateFont("P11FW.Title", { font = "Roboto", size = 28, weight = 800, extended = true })
surface.CreateFont("P11FW.Huge",  { font = "Roboto", size = 32, weight = 800, extended = true })
surface.CreateFont("P11FW.Big",   { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("P11FW.Text",  { font = "Roboto", size = 17, weight = 500, extended = true })
surface.CreateFont("P11FW.Small", { font = "Roboto", size = 15, weight = 400, extended = true })

local C = {
    -- v4.2: единый фирменный фундамент P11UI
    bg      = Color(10, 14, 20, 245),
    panel   = Color(20, 26, 36, 255),
    panel2  = Color(27, 34, 47, 255),
    line    = Color(70, 120, 160, 255),
    accent  = Color(120, 190, 235),
    text    = Color(228, 238, 248),
    dim     = Color(150, 165, 180),
    ok      = Color(110, 215, 135),
    bad     = Color(230, 95, 80),
    gold    = Color(255, 205, 110),
    cyan    = Color(110, 205, 240),
}

-- v4.26.0 «СИЯНИЕ»: пятиконечная звезда полигоном (эмблема шапки)
local function F4Star(cx, cy, r, col)
    local pts = {}
    for i = 1, 10 do
        local a = -math.pi / 2 + math.pi * (i - 1) / 5
        local rr = (i % 2 == 1) and r or r * 0.42
        pts[i] = { x = cx + math.cos(a) * rr, y = cy + math.sin(a) * rr }
    end
    draw.NoTexture()
    surface.SetDrawColor(col.r, col.g, col.b, col.a or 255)
    surface.DrawPoly(pts)
end

-- v3.8: плавное появление окна — выезд снизу + проявление
-- + затемнение всего экрана под меню (как у С-меню)
local TW_LEN = 0.22
local function TweenK(s)
    local k = math.Clamp((SysTime() - (s.AnimT or 0)) / TW_LEN, 0, 1)
    return 1 - (1 - k) ^ 3
end

local function AnimateIn(s)
    s.AnimT = SysTime()
    local tx, ty = s:GetPos()
    s:SetPos(tx, ty + 22)
    s.Think = function() s:SetPos(tx, ty + 22 * (1 - TweenK(s))) end
end

local function DrawDim(s, strength)
    local x, y = s:GetPos()
    surface.SetDrawColor(5, 9, 13, (strength or 150) * TweenK(s))
    surface.DrawRect(-x, -y, ScrW(), ScrH())
end

-- ============================================================
--  ГЛАВНОЕ МЕНЮ
-- ============================================================

function P11FW.OpenJobMenu()
    if IsValid(P11FW.MenuFrame) then P11FW.MenuFrame:Remove() end

    local W, H = 1020, 640

    local f = vgui.Create("DFrame")
    P11FW.MenuFrame = f
    f.P11FW_Start = SysTime()
    f:SetSize(W, H)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    AnimateIn(f) -- v3.8
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    f.SelectedJob = P11FW.GetJobId(LocalPlayer())
    f.ModelIdx = 1

    function f:Paint(w, h)
        DrawDim(f, 155) -- v3.8: затемнение экрана под картотекой
        surface.SetAlphaMultiplier(0.22 + 0.78 * TweenK(f))
        Derma_DrawBackgroundBlur(f, f.P11FW_Start or 0)
        draw.RoundedBox(10, 0, 0, w, h, C.bg)

        -- шапка: глубокий градиент + бегущий блик
        draw.RoundedBoxEx(10, 0, 0, w, 62, C.panel2, true, true, false, false)
        -- v5.0.0 «СБОР»: красное знамя — верхняя кайма шапки (стиль станции)
        draw.RoundedBoxEx(10, 0, 0, w, 3, Color(205, 60, 52, 235), true, true, false, false)
        draw.RoundedBoxEx(10, 0, 0, w, 26, Color(255, 255, 255, 6), true, true, false, false)
        local sweep = ((SysTime() * 90) % (w + 260)) - 130
        surface.SetDrawColor(160, 215, 255, 16)
        surface.DrawRect(sweep, 0, 70, 62)
        surface.SetDrawColor(160, 215, 255, 7)
        surface.DrawRect(sweep + 70, 0, 30, 62)

        -- морозная кромка под шапкой
        surface.SetDrawColor(C.line)
        surface.DrawRect(0, 62, w, 2)
        surface.SetDrawColor(120, 190, 235, 60)
        surface.DrawRect(0, 64, w, 1)

        -- v4.26.0 «СИЯНИЕ»: эмблема — кольца радара + красная звезда смены
        local ex, ey = 32, 31
        surface.DrawCircle(ex, ey, 19, C.accent.r, C.accent.g, C.accent.b, 145)
        surface.DrawCircle(ex, ey, 12, C.accent.r, C.accent.g, C.accent.b, 75)
        local ra = CurTime() * 1.5
        surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 105)
        surface.DrawLine(ex, ey, ex + math.cos(ra) * 18, ey + math.sin(ra) * 18)
        F4Star(ex, ey, 7.5, Color(238, 108, 92))
        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11FW.Title", 60, 8, C.text)
        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11FW.Title", 60, 8,
            Color(C.accent.r, C.accent.g, C.accent.b, 24 + 14 * math.sin(CurTime() * 2))) -- ледяное свечение
        draw.SimpleText("★ КАРТОТЕКА ЛИЧНОГО СОСТАВА · СМЕНА 1982 ★", "P11FW.Small", 60, 40, C.dim)
        draw.SimpleText(os.date("%H:%M") .. " · " .. game.GetMap() .. " · личного состава: " .. player.GetCount(),
            "P11FW.Small", w - 14, 47, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- чип текущей должности
        local me = LocalPlayer()
        local jobName = P11FW.GetJobName(me)
        local job = P11FW.GetJob(me)
        local jc = (job and job.color) or C.gold
        surface.SetFont("P11FW.Text")
        local jw = surface.GetTextSize("ВЫ: " .. (jobName ~= "" and jobName or "—"))
        draw.RoundedBox(14, w - jw - 66, 16, jw + 30, 30, Color(jc.r, jc.g, jc.b, 34))
        draw.RoundedBox(5, w - jw - 60, 23, 4, 16, jc)
        draw.SimpleText("ВЫ: " .. (jobName ~= "" and jobName or "—"), "P11FW.Text",
            w - 46, 31, jc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        draw.SimpleText("F4 / ESC — закрыть", "P11FW.Small", w - 14, h - 12, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetAlphaMultiplier(1)
    end

    function f:OnKeyCodePressed(key)
        if key == KEY_F4 or key == KEY_ESCAPE then
            f:Remove()
        end
    end

    local xBtn = vgui.Create("DButton", f)
    xBtn:SetPos(W - 40, 16)
    xBtn:SetSize(26, 26)
    xBtn:SetText("✕")
    xBtn:SetFont("P11FW.Big")
    xBtn:SetTextColor(C.dim)
    xBtn.Paint = function() end
    xBtn.DoClick = function() f:Remove() end

    -- ============ ЛЕВАЯ КОЛОНКА: фракции и должности ============

    local left = vgui.Create("DScrollPanel", f)
    left:SetPos(12, 74)
    left:SetSize(312, 500)
    local sb = left:GetVBar()
    sb:SetWide(5)
    sb.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 18)) end
    sb.btnGrip.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, C.line) end

    f.JobButtons = {}

    local me0 = LocalPlayer()
    local function JobShown(jobId)
        local j = P11FW.Jobs[jobId]
        if j and j.hidden then
            -- v5.2.2 «БИТВА ВРЕМЕНИ»: профы-награды батл-пасса показываются,
            -- если игрок разблокировал их наградой (P11.BP.data.jobs[id])
            if j.bpUnlock and P11 and P11.BP and P11.BP.data and P11.BP.data.jobs
                and P11.BP.data.jobs[j.bpUnlock] then
                return true
            end
            return false -- v4.24.2 «ЗНАМЯ»: командные профы скрыты из F4
        end
        return not (P11FW.WLHiddenFor and P11FW.WLHiddenFor(me0, jobId))
    end

    for _, cat in ipairs(P11FW.CategoryList) do
        -- сколько должностей в секции (скрытые 🔒 не считаем — v4.6.7)
        local cnt = 0
        for _, jobId in ipairs(P11FW.JobIds) do
            if P11FW.Jobs[jobId] and P11FW.Jobs[jobId].category == cat.id and JobShown(jobId) then cnt = cnt + 1 end
        end
        if cnt > 0 then
            local head = left:Add("DPanel")
            head:SetTall(38)
            head:Dock(TOP)
            head:DockMargin(0, 10, 0, 3)
            head.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(cat.color.r, cat.color.g, cat.color.b, 30))
                draw.RoundedBoxEx(6, 0, 0, 4, h, cat.color, true, false, true, false)
                surface.SetDrawColor(cat.color.r, cat.color.g, cat.color.b, 70)
                surface.DrawRect(4, h - 1, w - 4, 1)
                draw.SimpleText("▸ " .. cat.name, "P11FW.Big", 12, h / 2, cat.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- v4.26.0: пилюля числа должностей
                surface.SetFont("P11FW.Small")
                local cw = surface.GetTextSize(tostring(cnt)) + 16
                draw.RoundedBox(10, w - cw - 10, h / 2 - 10, cw, 20,
                    Color(cat.color.r, cat.color.g, cat.color.b, 46))
                surface.SetDrawColor(cat.color.r, cat.color.g, cat.color.b, 130)
                surface.DrawOutlinedRect(w - cw - 10, h / 2 - 10, cw, 20, 1)
                draw.SimpleText(cnt .. "", "P11FW.Small", w - 10 - cw / 2, h / 2,
                    Color(cat.color.r, cat.color.g, cat.color.b, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            for _, jobId in ipairs(P11FW.JobIds) do
                local job = P11FW.Jobs[jobId]
                if job and job.category == cat.id and JobShown(jobId) then
                    local btn = left:Add("DButton")
                    btn:SetTall(50)
                    btn:Dock(TOP)
                    btn:DockMargin(0, 3, 0, 0)
                    btn:SetText("")
                    btn.JobId = jobId
                    btn.HSlide = 0

                    btn.Paint = function(s, w, h)
                        local sel = (f.SelectedJob == s.JobId)
                        draw.RoundedBox(6, 0, 0, w, h, sel and Color(C.accent.r, C.accent.g, C.accent.b, 42) or C.panel)
                        if sel then -- v4.26.0: выбранная должность светится рамкой
                            surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b,
                                120 + 55 * math.sin(CurTime() * 3.4))
                            surface.DrawOutlinedRect(0, 0, w, h, 1)
                        end
                        if s:IsHovered() then
                            s.HSlide = math.min(6, s.HSlide + FrameTime() * 40)
                            draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 7))
                        else
                            s.HSlide = math.max(0, s.HSlide - FrameTime() * 40)
                        end

                        draw.RoundedBox(3, 3, 3, 5 + s.HSlide, h - 6, job.color or C.text)
                        draw.SimpleText(job.name, "P11FW.Text", 16, h / 2 - 9,
                            sel and C.accent or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                        -- занятые места + допуски
                        local maxT = job.max or 0
                        -- v4.8.2: показываем ОБЩЕЕ число занятых мест (раньше
                        -- вычитали СЕБЯ — отсюда «я на поваре, а мест 0/2»)
                        local taken = P11FW.TeamCount(s.JobId)
                        local slotsTxt = maxT > 0 and (taken .. "/" .. maxT) or "∞"
                        local slotsCol = C.dim
                        if maxT > 0 and taken >= maxT then slotsCol = C.bad end
                        draw.SimpleText("мест: " .. slotsTxt, "P11FW.Small", 16, h / 2 + 12, slotsCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                        local flags = ""
                        if job.terminal then flags = flags .. " ⌨" end
                        if job.command then flags = flags .. " ★" end
                        if job.whitelist then flags = flags .. " 🔒" end -- v4.4.0: ВАЙТЛИСТ
                        if job.vip then flags = flags .. " 💎" end -- v4.8.0: VIP-СЛУЖБА
                        if flags ~= "" then
                            draw.SimpleText(flags, "P11FW.Text", w - 10, h / 2,
                                job.command and C.gold or C.cyan, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        end
                    end

                    btn.DoClick = function()
                        f.SelectedJob = jobId
                        f.ModelIdx = 1
                        surface.PlaySound("buttons/button9.wav")
                        f:RefreshRight()
                    end

                    f.JobButtons[jobId] = btn
                end
            end
        end
    end

    -- ============ ПРАВАЯ КОЛОНКА: «КАРТА ДОЛЖНОСТИ» ============

    local right = vgui.Create("DPanel", f)
    right:SetPos(336, 74)
    right:SetSize(672, 552)
    right.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.panel)
        -- редкий сканлайн-мезмеризм поверх карты
        local sy = (SysTime() * 30) % (h + 40) - 20
        surface.SetDrawColor(140, 200, 240, 5)
        surface.DrawRect(0, sy, w, 2)
    end

    function f:RefreshRight()
        right:Clear()
        local jobId = self.SelectedJob
        local job = P11FW.Jobs[jobId]
        if not job then return end
        local jc = job.color or C.text

        local valids = P11FW.ValidModels(job)
        self.ModelIdx = math.Clamp(self.ModelIdx or 1, 1, #valids)

        -- цветная верхняя полоса карты
        local band = vgui.Create("DPanel", right)
        band:Dock(TOP)
        band:SetTall(54)
        band.Paint = function(s, w, h)
            draw.RoundedBoxEx(8, 0, 0, w, h, Color(jc.r, jc.g, jc.b, 30), true, true, false, false)
            surface.SetDrawColor(jc.r, jc.g, jc.b, 140)
            surface.DrawRect(0, h - 1, w, 1)
            draw.SimpleText("★", "P11FW.Huge", 14, h / 2, jc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) -- v4.26.0
            draw.SimpleText(string.upper(job.name), "P11FW.Huge", 40, h / 2, jc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local maxT = job.max or 0
            local taken = P11FW.TeamCount(jobId) -- v4.8.2: общий счёт занятых
            local st = maxT > 0 and ("мест занято " .. taken .. "/" .. maxT) or "мест без лимита"
            draw.SimpleText(st, "P11FW.Small", w - 14, h / 2,
                (maxT > 0 and taken >= maxT) and C.bad or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- портрет слева
        local mBox = vgui.Create("DPanel", right)
        mBox:Dock(LEFT)
        mBox:SetWide(250)
        mBox:DockMargin(12, 12, 0, 12)
        mBox.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.panel2)
            draw.RoundedBoxEx(8, 0, 0, w, 30, Color(255, 255, 255, 5), true, true, false, false)
            -- v4.26.0: фоторамка досье — уголки + бегущий скан
            surface.SetDrawColor(150, 200, 235, 150)
            surface.DrawRect(6, 6, 22, 2) surface.DrawRect(6, 6, 2, 22)
            surface.DrawRect(w - 28, 6, 22, 2) surface.DrawRect(w - 8, 6, 2, 22)
            surface.DrawRect(6, h - 8, 22, 2) surface.DrawRect(6, h - 30, 2, 22)
            surface.DrawRect(w - 28, h - 8, 22, 2) surface.DrawRect(w - 8, h - 30, 2, 22)
            local sy = 8 + ((SysTime() * 36) % (h - 28))
            surface.SetDrawColor(140, 200, 240, 10)
            surface.DrawRect(6, sy, w - 12, 16)
        end

        local mp = vgui.Create("DModelPanel", mBox)
        mp:Dock(FILL)
        mp:DockMargin(8, 8, 8, 62)
        mp:SetModel(valids[self.ModelIdx])
        mp:SetLookAt(Vector(0, 0, 60))
        mp:SetCamPos(Vector(48, -10, 60))
        mp:SetAnimated(true)
        function mp:LayoutEntity(ent)
            -- лёгкое «дыхание» статику не ломает, оживляет портрет
            ent:SetAngles(Angle(0, math.sin(CurTime() * 0.35) * 16 - 15, 0))
        end

        -- значки допусков под портретом
        local chips = vgui.Create("DIconLayout", mBox)
        chips:Dock(BOTTOM)
        chips:SetTall(52)
        chips:DockMargin(8, 0, 8, 8)
        chips:SetSpaceX(4) chips:SetSpaceY(4)

        local function Chip(txt, col, show)
            if not show then return end
            local ch = vgui.Create("DPanel", chips)
            ch:SetSize(114, 22)
            ch.Paint = function(s, w, h)
                draw.RoundedBox(10, 0, 0, w, h, Color(col.r, col.g, col.b, 36))
                surface.SetDrawColor(col.r, col.g, col.b, 110) -- v4.26.0: обводка чипа
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(txt, "P11FW.Small", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        if #valids > 1 then
            local cycle = vgui.Create("DButton", chips)
            cycle:SetSize(116, 22)
            cycle:SetText("Вариант " .. self.ModelIdx .. "/" .. #valids)
            cycle:SetFont("P11FW.Small")
            cycle:SetTextColor(C.text)
            cycle.Paint = function(s, w, h)
                draw.RoundedBox(10, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 26) or Color(255, 255, 255, 12))
            end
            cycle.DoClick = function()
                self.ModelIdx = (self.ModelIdx % #valids) + 1
                cycle:SetText("Вариант " .. self.ModelIdx .. "/" .. #valids)
                mp:SetModel(valids[self.ModelIdx])
                surface.PlaySound("buttons/button15.wav")
            end
        end
        Chip("⌨ ТЕРМИНАЛ", C.cyan, job.terminal)
        Chip("★ КОМАНДИР", C.gold, job.command)
        Chip("🔒 ВАЙТЛИСТ", Color(255, 180, 110), job.whitelist) -- v4.4.0
        Chip("⏳ " .. (job.time or 0) .. " МИН", Color(150, 200, 255), (job.time or 0) > 0) -- v4.5.0: время игры для профы
        Chip("💎 VIP-СЛУЖБА", Color(235, 205, 100), job.vip == true) -- v4.8.0

        -- текстовый блок справа
        local info = vgui.Create("DPanel", right)
        info:Dock(FILL)
        info:DockMargin(12, 12, 12, 12)
        info.Paint = function() end
        local infoW = 672 - 250 - 36

        local catL = vgui.Create("DLabel", info)
        catL:Dock(TOP)
        catL:SetTall(18)
        catL:SetFont("P11FW.Small")
        local catName = "—"
        for _, cat in ipairs(P11FW.CategoryList) do
            if cat.id == job.category then catName = cat.name end
        end
        catL:SetText("Подразделение: " .. catName .. (job.custom and "  •  кастомная должность" or ""))
        catL:SetTextColor(C.dim)

        local dHead = vgui.Create("DLabel", info)
        dHead:Dock(TOP)
        dHead:SetTall(22)
        dHead:DockMargin(0, 8, 0, 0)
        dHead:SetFont("P11FW.Small")
        dHead:SetText("— ОБЯЗАННОСТИ СМЕНЫ —")
        dHead:SetTextColor(C.accent)

        local dsc = vgui.Create("DScrollPanel", info)
        dsc:Dock(FILL)
        dsc:DockMargin(0, 4, 0, 6)
        local dsb = dsc:GetVBar() dsb:SetWide(4)
        local desc = vgui.Create("DLabel", dsc)
        desc:Dock(TOP)
        desc:SetWide(infoW - 10)
        desc:SetFont("P11FW.Text")
        desc:SetText(job.desc or "")
        desc:SetTextColor(C.text)
        desc:SetWrap(true)
        desc:SetAutoStretchVertical(true)
        desc:SetContentAlignment(7)

        -- чипы снаряжения
        local wHead = vgui.Create("DLabel", info)
        wHead:Dock(BOTTOM)
        wHead:SetTall(18)
        wHead:SetFont("P11FW.Small")
        wHead:SetText("— СНАРЯЖЕНИЕ —")
        wHead:SetTextColor(C.accent)

        local wChips = vgui.Create("DIconLayout", info)
        wChips:Dock(BOTTOM)
        wChips:SetTall(52)
        wChips:DockMargin(0, 0, 0, 8)
        wChips:SetSpaceX(4) wChips:SetSpaceY(4)

        local wNames = {}
        for _, class in ipairs(P11FW.ValidWeapons(job)) do
            local wtab = weapons.Get(class)
            wNames[#wNames + 1] = (wtab and wtab.PrintName and wtab.PrintName ~= "" and wtab.PrintName ~= "Scripted Weapon") and wtab.PrintName or class
        end
        if #wNames == 0 then wNames = { "базовый набор станции" } end
        for _, wname in ipairs(wNames) do
            local ch = vgui.Create("DPanel", wChips)
            surface.SetFont("P11FW.Small")
            ch:SetSize(math.max(70, surface.GetTextSize(wname) + 20), 22)
            ch.Paint = function(s, w, h)
                draw.RoundedBox(10, 0, 0, w, h, Color(255, 255, 255, 10))
                draw.SimpleText(wname, "P11FW.Small", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- нижняя панель с кнопкой-штормом
        local bottom = vgui.Create("DPanel", right)
        bottom:Dock(BOTTOM)
        bottom:SetTall(62)
        bottom:DockMargin(12, 0, 12, 12)
        bottom.Paint = function() end

        local me = LocalPlayer()
        local isCurrent = P11FW.GetJobId(me) == jobId
        local full = P11FW.JobFull(jobId, me)
        -- v4.4.0: ВАЙТЛИСТ-замок — нужен допуск (админов пропускаем)
        local wlBlocked = job.whitelist and not isCurrent
            and not (P11FW.HasWhitelist and P11FW.HasWhitelist(me, jobId))
            and not (P11FW.Config and P11FW.Config.Admin(me))
            and not (P11FW.GetRankLevel(me) >= 16) -- Глава: вайтлистов нет

        -- v4.5.0: ВРЕМЯ ИГРЫ для профы (Super Admin+ — все профы сразу)
        local myMin = me:GetNWInt("P11_PlayMin", 0)
        local needT = job.time or 0
        local timeBlocked = needT > 0 and not isCurrent
            and not (P11FW.GetRankLevel and P11FW.GetRankLevel(me) >= 6)
            and myMin < needT

        -- v4.8.0: 💎 VIP-ЗАМОК — с ранга VIP (P11FW.IsVIP)
        local vipBlocked = job.vip and not isCurrent
            and not (P11FW.IsVIP and P11FW.IsVIP(me))

        -- v5.7.2: 🔒 ДРЕВО СЛУЖБЫ — профа закрыта, если узел не открыт
        local treeBlocked, treeReason = false, ""
        if not isCurrent then
            local tjob = TREE_JOB[jobId]
            if tjob then
                local tXp = tonumber(me:GetNWInt("P11_SkillXP", 0)) or 0
                local tLvl = 0
                for ti = 1, 10 do if tXp >= TREE_XP[ti] then tLvl = ti else break end end
                local okRank = (P11FW.GetRankLevel and P11FW.GetRankLevel(me) or 0) >= 14
                if not okRank then
                    if tjob.lvl > tLvl then
                        treeBlocked = true
                        treeReason = "Профа «" .. (job.name or jobId) .. "» — нужен УРОВЕНЬ СЛУЖБЫ " .. tjob.lvl .. " (у тебя " .. tLvl .. "). Древо: C-меню → ⭐ ДРЕВО СЛУЖБЫ."
                    elseif tjob.path then
                        local tst = P11.Tree and P11.Tree.trees and P11.Tree.trees[tjob.fac]
                        if not (tst and tst.nodes and tst.nodes[tjob.id]) then
                            treeBlocked = true
                            treeReason = "Профа «" .. (job.name or jobId) .. "» закрыта в ДРЕВЕ СЛУЖБЫ. Открой ветку: C-меню → ⭐ ДРЕВО СЛУЖБЫ."
                        end
                    end
                end
            end
        end

        local take = vgui.Create("DButton", bottom)
        take:Dock(FILL)
        take:SetText("")

        local state, stateCol
        if isCurrent then
            state, stateCol = "ВЫ НА ЭТОЙ ДОЛЖНОСТИ ✓", C.dim
        elseif vipBlocked then
            state, stateCol = "💎 ТОЛЬКО ДЛЯ VIP — жми F6 (поддержка станции)", Color(235, 205, 100)
        elseif treeBlocked then
            state, stateCol = "🔒 ЗАКРЫТО — ДРЕВО СЛУЖБЫ", Color(200, 165, 90)
        elseif wlBlocked then
            state, stateCol = "🔒 НУЖЕН ДОПУСК — проси офицера НКВД", Color(255, 180, 110)
        elseif timeBlocked then
            state, stateCol = "⏳ ОТКРОЕТСЯ С " .. needT .. " МИН — у тебя " .. myMin, Color(150, 200, 255)
        elseif full then
            state, stateCol = "МЕСТ НЕТ — " .. P11FW.TeamCount(jobId) .. "/" .. (job.max or 0), C.bad -- v4.8.2: общий счёт
        else
            state, stateCol = "ЗАНЯТЬ ДОЛЖНОСТЬ ➜", C.ok
        end

        take.Paint = function(s, w, h)
            local locked = isCurrent or full or wlBlocked or timeBlocked or vipBlocked or treeBlocked
            local col = locked and Color(66, 72, 80) or Color(38, 88, 56)
            if s:IsHovered() and not locked then col = Color(50, 118, 74) end
            draw.RoundedBox(8, 0, 0, w, h, col)
            draw.RoundedBoxEx(8, 0, 0, w, h / 2, Color(255, 255, 255, locked and 4 or 12), true, true, false, false)
            if not locked then
                -- тихий блик бегущий по кнопке
                local sweep = ((SysTime() * 120) % (w + 160)) - 80
                surface.SetDrawColor(255, 255, 255, 7)
                surface.DrawRect(sweep, 0, 60, h)
                -- v4.26.0: зелёный пульс «должность доступна»
                local pp = 0.5 + math.sin(CurTime() * 3.0) * 0.5
                surface.SetDrawColor(130, 235, 150, 45 + 75 * pp)
                surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 1)
            end
            draw.SimpleText(state, "P11FW.Big", w / 2, h / 2, stateCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        take.DoClick = function()
            if isCurrent or full then
                surface.PlaySound("buttons/button10.wav")
                return
            end
            if vipBlocked then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(Color(235, 205, 100), "[ПОЛЮС-11] Должность 💎 из VIP-СЛУЖБЫ — берётся с ранга VIP.",
                    Color(200, 205, 215), " Жми F6 — там витрина поддержки станции (ранг выдаёт Глава/Куратор).")
                return
            end
            if wlBlocked then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(Color(255, 180, 110), "[ПОЛЮС-11] Должность 🔒 в ВАЙТЛИСТЕ — допуск выдают: администрация или ранги Faction Officer/Leader (вкладка ВАЙТЛИСТ в /menu).")
                return
            end
            if treeBlocked then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(Color(200, 165, 90), "[ПОЛЮС-11] ", Color(230, 235, 245), treeReason or "Профа закрыта в древе службы.")
                return
            end
            if timeBlocked then
                surface.PlaySound("buttons/button10.wav")
                chat.AddText(Color(150, 200, 255), "[ПОЛЮС-11] Профа откроется с " .. needT .. " мин. игры — у тебя " .. myMin ..
                    " (минуты копятся сами, пока ты на сервере). Super Admin+ обходит время.")
                return
            end
            net.Start("P11FW_TakeJob")
                net.WriteString(jobId)
                net.WriteUInt(f.ModelIdx or 0, 5)
            net.SendToServer()
            surface.PlaySound("buttons/button9.wav")
            timer.Simple(0.4, function()
                if IsValid(f) then f:RefreshRight() end
            end)
        end

        -- уволиться
        if P11FW.GetJobId(me) ~= P11FW.Config.DefaultJob then
            local dem = vgui.Create("DButton", bottom)
            dem:Dock(RIGHT)
            dem:SetWide(150)
            dem:DockMargin(8, 0, 0, 0)
            dem:SetText("")
            dem.Paint = function(s, w, h)
                draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(95, 42, 38) or Color(64, 34, 32))
                draw.SimpleText("УВОЛИТЬСЯ", "P11FW.Text", w / 2, h / 2, C.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            dem.DoClick = function()
                net.Start("P11FW_TakeJob")
                    net.WriteString(P11FW.Config.DefaultJob)
                    net.WriteUInt(0, 5)
                net.SendToServer()
                timer.Simple(0.4, function()
                    if IsValid(f) then f:RefreshRight() end
                end)
            end
        end
    end

    f:RefreshRight()

    -- кнопки внизу слева: АДМИН-ПАНЕЛЬ (админам) и 🔒 ВАЙТЛИСТ
    -- (админам + рангам Faction Officer/Leader — v4.4.0)
    local me = LocalPlayer()
    local isAdmin = P11FW.Config.Admin(me)
    local canWl = P11FW.CanWhitelist and P11FW.CanWhitelist(me)

    local function F4Btn(x, y, w, h, name, colBase, colHover, colText, onClick)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, y) b:SetSize(w, h)
        b:SetText("")
        b.Paint = function(s, w2, h2)
            draw.RoundedBox(8, 0, 0, w2, h2, s:IsHovered() and colHover or colBase)
            surface.SetDrawColor(colText.r, colText.g, colText.b, 90)
            surface.DrawRect(0, h2 - 1, w2, 1)
            draw.SimpleText(name, "P11FW.Text", w2 / 2, h2 / 2, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            onClick()
        end
        return b
    end

    if isAdmin then
        F4Btn(12, 586, 152, 40, "🛡 АДМИН-ПАНЕЛЬ", Color(66, 38, 36), Color(95, 52, 48),
            Color(240, 140, 130), function() P11FW.OpenAdminMenu() end)
    end
    if canWl then
        if isAdmin then
            F4Btn(172, 586, 152, 40, "🔒 ВАЙТЛИСТ", Color(62, 46, 26), Color(92, 66, 32),
                Color(255, 185, 110), function() P11FW.OpenAdminMenu("whitelist") end)
        else
            F4Btn(12, 586, 312, 40, "🔒 ВАЙТЛИСТ — выдача допусков", Color(62, 46, 26), Color(92, 66, 32),
                Color(255, 185, 110), function() P11FW.OpenAdminMenu("whitelist") end)
        end
    end
end


print("[POLUS-11] F4 v5.7.2: древо-профы показываются как ЗАКРЫТЫЕ (treeBlocked)")
