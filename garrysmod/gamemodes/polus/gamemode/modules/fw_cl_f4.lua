-- ============================================================
--  ПОЛЮС FRAMEWORK — F4: КАРТОТЕКА ПЕРСОНАЛА (client) v1.7
--  Редизайн v2: шире и красивее — «карта должности» с портретом,
--  значками допусков (терминал/командир), чипами снаряжения,
--  бегущим бликом и анимированной разметкой фракций.
--  Открывается по F4, E у кадровика, чатом !работа.
-- ============================================================

surface.CreateFont("P11FW.Title", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11FW.Huge",  { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11FW.Big",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11FW.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11FW.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

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

        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11»", "P11FW.Title", 18, 12, C.text)
        draw.SimpleText("картотека личного состава • смена 1982", "P11FW.Small", 18, 42, C.dim)

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

    for _, cat in ipairs(P11FW.CategoryList) do
        -- сколько должностей в секции
        local cnt = 0
        for _, jobId in ipairs(P11FW.JobIds) do
            if P11FW.Jobs[jobId] and P11FW.Jobs[jobId].category == cat.id then cnt = cnt + 1 end
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
                draw.SimpleText(cat.name, "P11FW.Big", 12, h / 2, cat.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(cnt .. "", "P11FW.Small", w - 10, h / 2,
                    Color(cat.color.r, cat.color.g, cat.color.b, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            for _, jobId in ipairs(P11FW.JobIds) do
                local job = P11FW.Jobs[jobId]
                if job and job.category == cat.id then
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
                        local taken = P11FW.TeamCount(s.JobId, LocalPlayer():Team() == P11FW.JobTeams[s.JobId] and LocalPlayer() or nil)
                        local slotsTxt = maxT > 0 and (taken .. "/" .. maxT) or "∞"
                        local slotsCol = C.dim
                        if maxT > 0 and taken >= maxT then slotsCol = C.bad end
                        draw.SimpleText("мест: " .. slotsTxt, "P11FW.Small", 16, h / 2 + 12, slotsCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                        local flags = ""
                        if job.terminal then flags = flags .. " ⌨" end
                        if job.command then flags = flags .. " ★" end
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
            draw.SimpleText(string.upper(job.name), "P11FW.Huge", 14, h / 2, jc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local maxT = job.max or 0
            local taken = P11FW.TeamCount(jobId, LocalPlayer():Team() == P11FW.JobTeams[jobId] and LocalPlayer() or nil)
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

        local take = vgui.Create("DButton", bottom)
        take:Dock(FILL)
        take:SetText("")

        local state, stateCol
        if isCurrent then
            state, stateCol = "ВЫ НА ЭТОЙ ДОЛЖНОСТИ ✓", C.dim
        elseif full then
            state, stateCol = "МЕСТ НЕТ — " .. P11FW.TeamCount(jobId, me) .. "/" .. (job.max or 0), C.bad
        else
            state, stateCol = "ЗАНЯТЬ ДОЛЖНОСТЬ ➜", C.ok
        end

        take.Paint = function(s, w, h)
            local locked = isCurrent or full
            local col = locked and Color(66, 72, 80) or Color(38, 88, 56)
            if s:IsHovered() and not locked then col = Color(50, 118, 74) end
            draw.RoundedBox(8, 0, 0, w, h, col)
            draw.RoundedBoxEx(8, 0, 0, w, h / 2, Color(255, 255, 255, locked and 4 or 12), true, true, false, false)
            if not locked then
                -- тихий блик бегущий по кнопке
                local sweep = ((SysTime() * 120) % (w + 160)) - 80
                surface.SetDrawColor(255, 255, 255, 7)
                surface.DrawRect(sweep, 0, 60, h)
            end
            draw.SimpleText(state, "P11FW.Big", w / 2, h / 2, stateCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        take.DoClick = function()
            if isCurrent or full then
                surface.PlaySound("buttons/button10.wav")
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

    -- кнопка АДМИН-ПАНЕЛЬ (внизу слева; то же самое, что чат /menu)
    if P11FW.Config.Admin(LocalPlayer()) then
        local adm = vgui.Create("DButton", f)
        adm:SetPos(12, 586)
        adm:SetSize(312, 40)
        adm:SetText("")
        adm.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, s:IsHovered() and Color(95, 52, 48) or Color(66, 38, 36))
            surface.SetDrawColor(235, 130, 120, 90)
            surface.DrawRect(0, h - 1, w, 1)
            draw.SimpleText("🛡 АДМИН-ПАНЕЛЬ  (/menu)", "P11FW.Text", w / 2, h / 2,
                Color(240, 140, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        adm.DoClick = function()
            surface.PlaySound("buttons/button15.wav")
            P11FW.OpenAdminMenu()
        end
    end
end

function P11FW.CloseJobMenu()
    if IsValid(P11FW.MenuFrame) then P11FW.MenuFrame:Remove() end
end

-- открытие по сети (кадровик, чат-команда)
net.Receive("P11FW_OpenMenu", function()
    P11FW.OpenJobMenu()
end)

-- синк кастомных должностей от сервера (созданные через админку)
net.Receive("P11FW_JobsSync", function()
    local tbl = util.JSONToTable(net.ReadString() or "[]")
    P11FW.RegisterCustomJobs(istable(tbl) and tbl or {})

    if IsValid(P11FW.MenuFrame) then
        P11FW.MenuFrame:Remove()
        P11FW.OpenJobMenu()
    end
    if IsValid(P11FW.AdminFrame) and P11FW.AdminFrame.RefreshJobsTab then
        P11FW.AdminFrame:RefreshJobsTab()
    end
end)

-- ============ F4 ============

hook.Add("PlayerBindPress", "P11FW.F4", function(ply, bind, pressed)
    if not pressed then return end
    if DarkRP then return end
    if not string.find(bind, "gm_showspare2") then return end

    if IsValid(P11FW.MenuFrame) then
        P11FW.CloseJobMenu()
    else
        P11FW.OpenJobMenu()
    end
    return true
end)

-- ============ HUD: текущая должность ============

hook.Add("HUDPaint", "P11FW.JobHud", function()
    if not P11FW.Config.ShowJobHud then return end
    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end

    local name = P11FW.GetJobName(me)
    if name == "" then return end

    local job = P11FW.GetJob(me)
    local col = (job and job.color) or C.text

    surface.SetFont("P11FW.Text")
    local tw = surface.GetTextSize("Должность: " .. name)

    draw.RoundedBox(6, ScrW() - tw - 40, 14, tw + 28, 32, Color(10, 14, 20, 170))
    draw.RoundedBox(3, ScrW() - tw - 38, 16, 4, 28, col)
    draw.SimpleText("Должность: " .. name, "P11FW.Text", ScrW() - 26, 30, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
