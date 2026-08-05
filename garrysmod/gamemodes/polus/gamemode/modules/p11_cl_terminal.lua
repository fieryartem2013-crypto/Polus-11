-- ============================================================
--  ПОЛЮС-11 — СМЕННЫЙ ТЕРМИНАЛ (client) v2.7
--  Меню консоли: игроки | каталог готовых доп-задач | назначенные.
--  Назначить/снять. Данные от сервера (P11_TermData).
-- ============================================================

surface.CreateFont("P11.Term.Big",   { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("P11.Term.Text",  { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11.Term.Small", { font = "Roboto", size = 13, weight = 400, extended = true })

local TC = {
    bg    = Color(10, 16, 20, 245),
    panel = Color(18, 26, 32, 255),
    cyan  = Color(110, 205, 235),
    dim   = Color(150, 165, 178),
    ok    = Color(120, 220, 140),
    bad   = Color(235, 100, 90),
    gold  = Color(230, 200, 110),
}

local function Cmd(act, idx, key)
    net.Start("P11_TermAct")
        net.WriteUInt(act, 2)
        if act ~= 0 then
            net.WriteUInt(idx or 0, 8)
            net.WriteString(key or "")
        end
    net.SendToServer()
end

local TERM = { frame = nil, data = nil }

net.Receive("P11_TermData", function()
    local cat = {}
    for i = 1, net.ReadUInt(8) do
        cat[#cat + 1] = { key = net.ReadString(), name = net.ReadString(), max = net.ReadUInt(12) }
    end
    local plys = {}
    for i = 1, net.ReadUInt(8) do
        plys[#plys + 1] = {
            idx = net.ReadUInt(8),
            nick = net.ReadString(),
            job = net.ReadString(),
            tasks = util.JSONToTable(net.ReadString() or "[]") or {},
        }
    end
    TERM.data = { catalog = cat, players = plys }
    if IsValid(TERM.frame) and TERM.frame.Refresh then TERM.frame:Refresh() end
end)

local function ListRefresh(lv, data, colFunc)
    -- старый мир: Clear и заново (в терминале списки маленькие)
end

local function OpenTerminal()
    if IsValid(TERM.frame) then TERM.frame:Remove() end

    local f = vgui.Create("DFrame")
    TERM.frame = f
    f.T0 = SysTime()
    f:SetSize(860, 520)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)

    function f:Paint(w, h)
        Derma_DrawBackgroundBlur(self, self.T0 or 0)
        draw.RoundedBox(8, 0, 0, w, h, TC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 46, TC.panel, true, true, false, false)
        surface.SetDrawColor(TC.cyan)
        surface.DrawRect(0, 46, w, 2)
        draw.SimpleText("СМЕННЫЙ ТЕРМИНАЛ — ДОП. ЗАДАЧИ ЭКИПАЖУ", "P11.Term.Big", 14, 12, TC.cyan)
        draw.SimpleText("ЭКРАН КАРАУЛЬНОГО", "P11.Term.Small", w - 14, 22, TC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    function f:OnKeyCodePressed(key) if key == KEY_ESCAPE then f:Remove() end end

    local xB = vgui.Create("DButton", f)
    xB:SetPos(860 - 36, 10) xB:SetSize(24, 24)
    xB:SetText("✕") xB:SetFont("P11.Term.Big") xB:SetTextColor(TC.dim)
    xB.Paint = function() end
    xB.DoClick = function() f:Remove() end

    -- ============ КОЛОНКА 1: ИГРОКИ ============
    local lp = vgui.Create("DPanel", f)
    lp:SetPos(12, 58) lp:SetSize(270, 440)
    lp.Paint = function(s, w, h) draw.RoundedBox(5, 0, 0, w, h, TC.panel) end

    local pLbl = vgui.Create("DLabel", lp)
    pLbl:SetPos(8, 6) pLbl:SetSize(254, 18)
    pLbl:SetFont("P11.Term.Small") pLbl:SetTextColor(TC.dim)
    pLbl:SetText("ЭКИПАЖ")

    local plist = vgui.Create("DListView", lp)
    plist:SetPos(8, 28) plist:SetSize(254, 402)
    plist:SetMultiSelect(false)
    plist:AddColumn("Ник"):SetFixedWidth(140)
    plist:AddColumn("Должность")

    -- ============ КОЛОНКА 2: КАТАЛОГ ============
    local cp = vgui.Create("DPanel", f)
    cp:SetPos(294, 58) cp:SetSize(300, 440)
    cp.Paint = function(s, w, h) draw.RoundedBox(5, 0, 0, w, h, TC.panel) end

    local cLbl = vgui.Create("DLabel", cp)
    cLbl:SetPos(8, 6) cLbl:SetSize(284, 18)
    cLbl:SetFont("P11.Term.Small") cLbl:SetTextColor(TC.dim)
    cLbl:SetText("ГОТОВЫЕ ДОП-ЗАДАЧИ")

    local clist = vgui.Create("DListView", cp)
    clist:SetPos(8, 28) clist:SetSize(284, 360)
    clist:SetMultiSelect(false)
    clist:AddColumn("Задача"):SetFixedWidth(210)
    clist:AddColumn("×")

    local assign = vgui.Create("DButton", cp)
    assign:SetPos(8, 396) assign:SetSize(284, 32)
    assign:SetText("")
    assign.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 220, 140, 60) or Color(120, 220, 140, 30))
        draw.SimpleText("◉ НАЗНАЧИТЬ ВЫБРАННОМУ", "P11.Term.Text", w / 2, h / 2, TC.ok, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    assign.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        local pl, ct = plist:GetSelectedLine(), clist:GetSelectedLine()
        if not pl or not ct then surface.PlaySound("buttons/button10.wav") return end
        local pli, cli = plist:GetLine(pl), clist:GetLine(ct)
        Cmd(1, pli.PIdx, cli.CKey)
    end

    -- ============ КОЛОНКА 3: НАЗНАЧЕННЫЕ ============
    local ap = vgui.Create("DPanel", f)
    ap:SetPos(606, 58) ap:SetSize(242, 440)
    ap.Paint = function(s, w, h) draw.RoundedBox(5, 0, 0, w, h, TC.panel) end

    local aLbl = vgui.Create("DLabel", ap)
    aLbl:SetPos(8, 6) aLbl:SetSize(226, 18)
    aLbl:SetFont("P11.Term.Small") aLbl:SetTextColor(TC.dim)
    aLbl:SetText("НАЗНАЧЕННЫЕ (у цели)")

    local alist = vgui.Create("DListView", ap)
    alist:SetPos(8, 28) alist:SetSize(226, 360)
    alist:SetMultiSelect(false)
    alist:AddColumn("Задача"):SetFixedWidth(150)
    alist:AddColumn("Прогр.")

    local revoke = vgui.Create("DButton", ap)
    revoke:SetPos(8, 396) revoke:SetSize(226, 32)
    revoke:SetText("")
    revoke.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(235, 100, 90, 60) or Color(235, 100, 90, 25))
        draw.SimpleText("✕ СНЯТЬ ЗАДАЧУ", "P11.Term.Text", w / 2, h / 2, TC.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    revoke.DoClick = function()
        surface.PlaySound("buttons/button9.wav")
        local pl, at = plist:GetSelectedLine(), alist:GetSelectedLine()
        if not pl or not at then surface.PlaySound("buttons/button10.wav") return end
        local pli, ali = plist:GetLine(pl), alist:GetLine(at)
        Cmd(2, pli.PIdx, ali.CKey)
    end

    -- выбор игрока → его назначенные
    plist.OnRowSelected = function(s, ln, line)
        alist:Clear()
        for _, t in ipairs(line.PTasks or {}) do
            local row = alist:AddLine((t.done and "✔ " or "") .. t.name, math.floor(t.cur) .. "/" .. t.max)
            row.CKey = t.key
        end
    end

    -- ============ ДАННЫЕ ============
    function f:Refresh()
        local keepIdx = nil
        local sel = plist:GetSelectedLine()
        if sel then keepIdx = plist:GetLine(sel).PIdx end

        plist:Clear()
        for _, p in ipairs((TERM.data and TERM.data.players) or {}) do
            local line = plist:AddLine(p.nick, p.job)
            line.PIdx = p.idx
            line.PTasks = p.tasks
            if keepIdx == p.idx then plist:SelectItem(line) plist:OnRowSelected(0, line) end
        end

        clist:Clear()
        for _, c in ipairs((TERM.data and TERM.data.catalog) or {}) do
            local line = clist:AddLine(c.name, "×" .. c.max)
            line.CKey = c.key
        end
    end
    f:Refresh()

    -- авто-обновление данных раз в 3 сек пока открыто
    f.Think = function(s)
        s.NextPull = s.NextPull or 0
        if CurTime() >= s.NextPull then
            s.NextPull = CurTime() + 3
            Cmd(0)
        end
    end
end

net.Receive("P11_TermOpen", function()
    OpenTerminal()
end)
