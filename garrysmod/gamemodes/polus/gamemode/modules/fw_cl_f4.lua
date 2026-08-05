-- ============================================================
--  ПОЛЮС FRAMEWORK — F4: МЕНЮ ПРОФЕССИЙ (клиент)
--  Морозно-тёмный UI станции. Открывается по F4, по E у
--  кадровика, чат-командой !работа.
-- ============================================================

surface.CreateFont("P11FW.Title", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11FW.Big",   { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("P11FW.Text",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("P11FW.Small", { font = "Roboto", size = 14, weight = 400, extended = true })

local C = {
    bg      = Color(14, 20, 28, 235),
    panel   = Color(24, 34, 46, 255),
    panel2  = Color(30, 42, 56, 255),
    accent  = Color(120, 190, 235),
    text    = Color(225, 235, 245),
    dim     = Color(150, 165, 180),
    ok      = Color(110, 210, 130),
    bad     = Color(230, 95, 80),
    gold    = Color(255, 205, 110),
}

-- лёгкий блюр-подложка
local function Blur(panel)
    Derma_DrawBackgroundBlur(panel, panel.P11FW_Start or 0)
end

-- ============================================================
--  ГЛАВНОЕ МЕНЮ
-- ============================================================

function P11FW.OpenJobMenu()
    if IsValid(P11FW.MenuFrame) then P11FW.MenuFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11FW.MenuFrame = f
    f.P11FW_Start = SysTime()
    f:SetSize(920, 560)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    f.SelectedJob = P11FW.GetJobId(LocalPlayer())
    f.ModelIdx = 1

    function f:Paint(w, h)
        Blur(f)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 54, C.panel2, true, true, false, false)
        surface.SetDrawColor(C.accent)
        surface.DrawRect(0, 54, w, 2)

        draw.SimpleText("СТАНЦИЯ «ПОЛЮС-11» — ЛИЧНЫЙ СОСТАВ", "P11FW.Title", 16, 14, C.text)

        local jobName = P11FW.GetJobName(LocalPlayer())
        draw.SimpleText("Ваша должность: " .. (jobName ~= "" and jobName or "—"), "P11FW.Text",
            w - 18, 30, C.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F4 / ESC — закрыть", "P11FW.Small", w - 18, h - 14, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    function f:OnKeyCodePressed(key)
        if key == KEY_F4 or key == KEY_ESCAPE then
            f:Remove()
        end
    end

    -- крестик в шапке (свой, т.к. стандартный спрятан)
    local xBtn = vgui.Create("DButton", f)
    xBtn:SetPos(920 - 40, 12)
    xBtn:SetSize(28, 28)
    xBtn:SetText("✕")
    xBtn:SetFont("P11FW.Big")
    xBtn:SetTextColor(C.dim)
    xBtn.Paint = function() end
    xBtn.DoClick = function() f:Remove() end

    -- ============ ЛЕВАЯ КОЛОНКА: категории и должности ============

    local left = vgui.Create("DScrollPanel", f)
    left:SetPos(12, 66)
    left:SetSize(300, 432) -- место снизу оставлено под кнопку АДМИНКА
    local sb = left:GetVBar()
    sb:SetWide(6)
    sb.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(255, 255, 255, 20)) end
    sb.btnGrip.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, C.accent) end

    f.JobButtons = {}
    f.SlotLabels = {}

    for _, cat in ipairs(P11FW.CategoryList) do
        local head = left:Add("DPanel")
        head:SetTall(34)
        head:Dock(TOP)
        head:DockMargin(0, 8, 0, 2)
        head.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(cat.color.r, cat.color.g, cat.color.b, 40))
            draw.SimpleText(cat.name, "P11FW.Big", 10, h / 2, cat.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        for _, jobId in ipairs(P11FW.JobIds) do
            local job = P11FW.Jobs[jobId]
            if job.category == cat.id then
                local btn = left:Add("DButton")
                btn:SetTall(46)
                btn:Dock(TOP)
                btn:DockMargin(0, 2, 0, 0)
                btn:SetText("")
                btn.JobId = jobId

                btn.Paint = function(s, w, h)
                    local sel = (f.SelectedJob == s.JobId)
                    draw.RoundedBox(4, 0, 0, w, h, sel and Color(C.accent.r, C.accent.g, C.accent.b, 45) or C.panel)
                    if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 8)) end

                    draw.RoundedBox(2, 3, 3, 5, h - 6, job.color or C.text)
                    draw.SimpleText(job.name, "P11FW.Text", 16, h / 2,
                        sel and C.accent or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                    -- места
                    local maxT = job.max or 0
                    local taken = P11FW.TeamCount(s.JobId, LocalPlayer():Team() == P11FW.JobTeams[s.JobId] and LocalPlayer() or nil)
                    local txt = maxT > 0 and (taken .. "/" .. maxT) or "∞"
                    local col = C.dim
                    if maxT > 0 and taken >= maxT then col = C.bad end
                    draw.SimpleText(txt, "P11FW.Text", w - 10, h / 2, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
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

    -- ============ ПРАВАЯ КОЛОНКА: детали ============

    local right = vgui.Create("DPanel", f)
    right:SetPos(324, 66)
    right:SetSize(584, 470)
    right.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, C.panel) end

    function f:RefreshRight()
        right:Clear()
        local jobId = self.SelectedJob
        local job = P11FW.Jobs[jobId]
        if not job then return end

        local valids = P11FW.ValidModels(job)
        self.ModelIdx = math.Clamp(self.ModelIdx or 1, 1, #valids)

        -- блок модели слева
        local mBox = vgui.Create("DPanel", right)
        mBox:Dock(LEFT)
        mBox:SetWide(216)
        mBox:DockMargin(10, 10, 0, 10)
        mBox.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, C.panel2) end

        local mp = vgui.Create("DModelPanel", mBox)
        mp:Dock(FILL)
        mp:DockMargin(6, 6, 6, 34)
        mp:SetModel(valids[self.ModelIdx])
        mp:SetLookAt(Vector(0, 0, 60))
        mp:SetCamPos(Vector(46, -12, 62))
        mp:SetAnimated(false)
        function mp:LayoutEntity(ent) end -- не вертим

        if #valids > 1 then
            local cycle = vgui.Create("DButton", mBox)
            cycle:Dock(BOTTOM)
            cycle:SetTall(26)
            cycle:DockMargin(6, 0, 6, 6)
            cycle:SetText("Внешность: вариант " .. self.ModelIdx .. "/" .. #valids)
            cycle:SetFont("P11FW.Small")
            cycle:SetTextColor(C.text)
            cycle.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 25) or Color(255, 255, 255, 12))
            end
            cycle.DoClick = function()
                self.ModelIdx = (self.ModelIdx % #valids) + 1
                cycle:SetText("Внешность: вариант " .. self.ModelIdx .. "/" .. #valids)
                mp:SetModel(valids[self.ModelIdx])
                surface.PlaySound("buttons/button15.wav")
            end
        end

        -- текстовый блок справа
        local info = vgui.Create("DPanel", right)
        info:Dock(FILL)
        info:DockMargin(10, 10, 10, 64)
        info.Paint = function() end

        local nameL = vgui.Create("DLabel", info)
        nameL:Dock(TOP)
        nameL:SetTall(30)
        nameL:SetFont("P11FW.Title")
        nameL:SetText(job.name)
        nameL:SetTextColor(job.color or C.text)

        local catName = ""
        for _, cat in ipairs(P11FW.CategoryList) do
            if cat.id == job.category then catName = cat.name end
        end
        local catL = vgui.Create("DLabel", info)
        catL:Dock(TOP)
        catL:SetTall(18)
        catL:SetFont("P11FW.Small")
        catL:SetText("Подразделение: " .. catName)
        catL:SetTextColor(C.dim)

        local desc = vgui.Create("DLabel", info)
        desc:Dock(FILL)
        desc:DockMargin(0, 8, 0, 8)
        desc:SetFont("P11FW.Text")
        desc:SetText(job.desc or "")
        desc:SetTextColor(C.text)
        desc:SetWrap(true)
        desc:SetAutoStretchVertical(true)
        desc:SetContentAlignment(7) -- top-left

        local wepLine = "Снаряжение: "
        local wNames = {}
        for _, class in ipairs(P11FW.ValidWeapons(job)) do
            local wtab = weapons.Get(class)
            wNames[#wNames + 1] = (wtab and wtab.PrintName and wtab.PrintName ~= "" and wtab.PrintName ~= "Scripted Weapon") and wtab.PrintName or class
        end
        wepLine = wepLine .. (#wNames > 0 and table.concat(wNames, ", ") or "только инструменты")
        local wepL = vgui.Create("DLabel", info)
        wepL:Dock(BOTTOM)
        wepL:SetTall(34)
        wepL:SetFont("P11FW.Small")
        wepL:SetText(wepLine)
        wepL:SetTextColor(C.dim)
        wepL:SetWrap(true)
        wepL:SetAutoStretchVertical(true)

        -- нижняя панель с кнопками
        local bottom = vgui.Create("DPanel", right)
        bottom:Dock(BOTTOM)
        bottom:SetTall(52)
        bottom:DockMargin(10, 0, 10, 10)
        bottom.Paint = function() end

        local me = LocalPlayer()
        local isCurrent = P11FW.GetJobId(me) == jobId
        local full = P11FW.JobFull(jobId, me)

        local take = vgui.Create("DButton", bottom)
        take:Dock(FILL)
        take:SetFont("P11FW.Big")
        take:SetText("")

        local state, stateCol
        if isCurrent then
            state, stateCol = "ВЫ НА ЭТОЙ ДОЛЖНОСТИ", C.dim
        elseif full then
            state, stateCol = "МЕСТ НЕТ (" .. P11FW.TeamCount(jobId, me) .. "/" .. (job.max or 0) .. ")", C.bad
        else
            state, stateCol = "ЗАНЯТЬ ДОЛЖНОСТЬ", C.ok
        end

        take.Paint = function(s, w, h)
            local col = (isCurrent or full) and Color(70, 76, 84) or Color(46, 90, 60)
            if s:IsHovered() and not (isCurrent or full) then col = Color(60, 115, 78) end
            draw.RoundedBox(6, 0, 0, w, h, col)
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
            -- перерисуем кнопки через момент (сервер уже сменил team)
            timer.Simple(0.4, function()
                if IsValid(f) then f:RefreshRight() end
            end)
        end

        -- уволиться (если не новобранец)
        if P11FW.GetJobId(me) ~= P11FW.Config.DefaultJob then
            local dem = vgui.Create("DButton", bottom)
            dem:Dock(RIGHT)
            dem:SetWide(150)
            dem:DockMargin(8, 0, 0, 0)
            dem:SetText("Уволиться")
            dem:SetFont("P11FW.Text")
            dem:SetTextColor(C.bad)
            dem.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(90, 40, 38) or Color(64, 34, 32))
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
    -- Примечание: числа занятых мест пересчитываются прямо в Paint,
    -- поэтому список сам «живой», отдельный таймер не нужен.

    -- кнопка АДМИНКА (только админам, внизу слева)
    if P11FW.Config.Admin(LocalPlayer()) then
        local adm = vgui.Create("DButton", f)
        adm:SetPos(12, 506)
        adm:SetSize(300, 34)
        adm:SetText("")
        adm.Paint = function(s, w, h)
            draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(90, 50, 48) or Color(64, 36, 34))
            draw.SimpleText("АДМИНКА — игроки, наказания, утилиты", "P11FW.Text", w / 2, h / 2, Color(235, 130, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

    -- если меню открыты — перебрать списки
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
    if DarkRP then return end -- под DarkRP F4 принадлежит ему
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
