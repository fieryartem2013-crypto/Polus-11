-- ============================================================
--  ПОЛЮС FRAMEWORK — АДМИН-МЕНЮ (клиент)
--  Вкладки: ИГРОКИ (арест/рабство/бан/освободить/уволить/
--  выдать должность) • ДОЛЖНОСТИ (создание своих профессий:
--  имя, модели, оружие, лимит — сохраняются навсегда) •
--  УТИЛИТЫ (спавн-поинт, камера ареста, кадровик, бан-лист).
--  Открыть: p11fw_admin в консоль, чат !фвадмин / !fw,
--  кнопка «АДМИНКА» в F4.
-- ============================================================

surface.CreateFont("P11FW.Adm.Tab", { font = "Roboto", size = 18, weight = 700, extended = true })

local AC = {
    bg     = Color(16, 18, 24, 240),
    panel  = Color(26, 30, 40, 255),
    panel2 = Color(32, 38, 50, 255),
    accent = Color(235, 120, 110),
    text   = Color(230, 232, 240),
    dim    = Color(155, 160, 175),
    ok     = Color(110, 210, 130),
    bad    = Color(235, 95, 85),
    gold   = Color(255, 205, 110),
}

-- ============ NET-ПОМОЩНИКИ ============

local function RequestAdminData()
    net.Start("P11FW_AdminData")
    net.SendToServer()
end
P11FW.RequestAdminData = RequestAdminData

local function SendAction(act, writer)
    net.Start("P11FW_AdminAction")
        net.WriteUInt(act, 5)
        if writer then writer() end
    net.SendToServer()
end

local function SendJobEdit(act, rec)
    net.Start("P11FW_JobEdit")
        net.WriteUInt(act, 3)
        net.WriteString(util.TableToJSON(rec) or "{}")
    net.SendToServer()
end

-- ============ ПРИЁМ ДАННЫХ ============

net.Receive("P11FW_AdminData", function()
    if not IsValid(P11FW.AdminFrame) then return end
    local f = P11FW.AdminFrame

    local d = { players = {}, bans = {} }
    d.spawnSet = net.ReadBool()
    d.jailSet  = net.ReadBool()

    local n = net.ReadUInt(8)
    for i = 1, n do
        local p = {
            idx   = net.ReadUInt(8),
            nick  = net.ReadString(),
            jobId = net.ReadString(),
            pun   = net.ReadString(),
            left  = 0,
        }
        if p.pun ~= "" then p.left = net.ReadUInt(10) end
        -- v1.6: ранг / варны / мут для вкладки МОДЕРАЦИЯ
        p.rank     = net.ReadString()
        p.warns    = net.ReadUInt(8)
        p.muted    = net.ReadBool()
        p.muteLeft = p.muted and net.ReadUInt(16) or 0
        p.doc      = net.ReadString() -- v1.6.1: код удостоверения
        d.players[#d.players + 1] = p
    end

    local nb = net.ReadUInt(8)
    for i = 1, nb do
        d.bans[#d.bans + 1] = {
            sid    = net.ReadString(),
            nick   = net.ReadString(),
            reason = net.ReadString(),
            until_ = net.ReadUInt(32),
        }
    end

    f.AdminData = d
    if f.RefreshPlayers  then f:RefreshPlayers() end
    if f.RefreshActs     then f:RefreshActs() end
    if f.RefreshMod      then f:RefreshMod() end
    if f.RefreshFactions then f:RefreshFactions() end
    if f.RefreshUtils    then f:RefreshUtils() end
end)

-- сервер просит открыть меню/обновить данные
net.Receive("P11FW_AdminMenu", function()
    if IsValid(P11FW.AdminFrame) then
        RequestAdminData()
    else
        P11FW.OpenAdminMenu()
    end
end)

-- ============ ОБЩИЕ UI-ХЕЛПЕРЫ ============

local function MakeBtn(parent, text, col, onClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.PText = text
    b.PColor = col or AC.text
    b.Paint = function(s, w, h)
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 30) or Color(255, 255, 255, 14))
        draw.SimpleText(s.PText, "P11FW.Text", w / 2, h / 2, s.PColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function() surface.PlaySound("buttons/button9.wav") onClick() end
    return b
end

local function ParseListEntry(str)
    -- список через запятую/перенос строки → массив непустых строк
    local out = {}
    str = string.gsub(str or "", "\n", ",")
    for part in string.gmatch(str, "([^,]+)") do
        part = string.Trim(part)
        if part ~= "" then out[#out + 1] = part end
    end
    return out
end

-- ============================================================
--  ГЛАВНОЕ АДМИН-МЕНЮ
-- ============================================================

function P11FW.OpenAdminMenu()
    if not IsValid(LocalPlayer()) then return end
    if not P11FW.Config.Admin(LocalPlayer()) then
        chat.AddText(AC.bad, "[P11FW] Только для администрации.")
        return
    end

    if IsValid(P11FW.AdminFrame) then P11FW.AdminFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11FW.AdminFrame = f
    f.P11FW_Start = SysTime()
    f:SetSize(880, 580)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false)
    f.btnMaxim:SetVisible(false)
    f.btnMinim:SetVisible(false)

    f.ActiveTab = "players"

    function f:Paint(w, h)
        Derma_DrawBackgroundBlur(f, f.P11FW_Start or 0)
        draw.RoundedBox(8, 0, 0, w, h, AC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 50, AC.panel2, true, true, false, false)
        surface.SetDrawColor(AC.accent)
        surface.DrawRect(0, 50, w, 2)
        draw.SimpleText("ПОЛЮС-11 — ПАНЕЛЬ АДМИНИСТРАЦИИ", "P11FW.Title", 16, 12, AC.text)
        draw.SimpleText("P11FW v" .. P11FW.Version, "P11FW.Small", w - 18, 28, AC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    function f:OnKeyCodePressed(key)
        if key == KEY_ESCAPE then f:Remove() end
    end

    local xBtn = vgui.Create("DButton", f)
    xBtn:SetPos(880 - 38, 10)
    xBtn:SetSize(26, 26)
    xBtn:SetText("✕")
    xBtn:SetFont("P11FW.Big")
    xBtn:SetTextColor(AC.dim)
    xBtn.Paint = function() end
    xBtn.DoClick = function() f:Remove() end

    -- ============ ВКЛАДКИ ============

    local myLevel = P11FW.GetRankLevel(LocalPlayer())
    local tabs = {
        { id = "players",  name = "ИГРОКИ" },
        { id = "mod",      name = "МОДЕРАЦИЯ", perm = "warn", badge = "!" },
        { id = "acts",     name = "ДЕЙСТВИЯ" },
        { id = "jobs",     name = "ДОЛЖНОСТИ" },
        { id = "factions", name = "ФРАКЦИИ" },
        { id = "utils",    name = "УТИЛИТЫ" },
    }
    f.TabPanels = {}
    f.TabButtons = {}

    surface.SetFont("P11FW.Adm.Tab")
    for i, t in ipairs(tabs) do
        local tb = vgui.Create("DButton", f)
        tb:SetPos(12 + (i - 1) * 143, 58)
        tb:SetSize(137, 32)
        tb:SetText("")
        tb.TabId = t.id
        tb.Paint = function(s, w, h)
            local on = f.ActiveTab == s.TabId
            draw.RoundedBox(5, 0, 0, w, h, on and Color(AC.accent.r, AC.accent.g, AC.accent.b, 55) or Color(255, 255, 255, 8))
            if on then
                surface.SetDrawColor(AC.accent)
                surface.DrawRect(10, h - 2, w - 20, 2)
            end
            -- v1.6: вкладки под права — без прав текст серый
            local col = on and AC.accent or AC.dim
            if t.perm and not P11FW.CanMod(LocalPlayer(), t.perm) then
                col = Color(90, 95, 105)
            end
            draw.SimpleText(t.name, "P11FW.Adm.Tab", w / 2 - (t.badge and 8 or 0), h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if t.badge then
                draw.SimpleText(t.badge, "P11FW.Small", w - 14, 4,
                    P11FW.CanMod(LocalPlayer(), t.perm) and AC.gold or Color(90, 95, 105))
            end
        end
        tb.DoClick = function()
            if t.perm and not P11FW.CanMod(LocalPlayer(), t.perm) then
                surface.PlaySound("buttons/button10.wav") -- недоступно рангу
                chat.AddText(AC.gold, "[P11FW] Вкладка «" .. t.name .. "» доступна с ранга Хелпер (2).")
                return
            end
            f.ActiveTab = t.id
            for id, p in pairs(f.TabPanels) do p:SetVisible(id == t.id) end
            if t.id == "players" or t.id == "utils" or t.id == "acts" or t.id == "mod" then RequestAdminData() end
            surface.PlaySound("buttons/button15.wav")
        end
        f.TabButtons[t.id] = tb
    end

    -- контейнер вкладок
    local function NewTab(id)
        local p = vgui.Create("DPanel", f)
        p:SetPos(12, 98)
        p:SetSize(856, 470)
        p.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel) end
        p:SetVisible(id == f.ActiveTab)
        f.TabPanels[id] = p
        return p
    end

    -- ==================================================
    --  ВКЛАДКА 1: ИГРОКИ
    -- ==================================================
    do
        local p = NewTab("players")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10)
        lv:SetSize(520, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(170)
        lv:AddColumn("КОД"):SetFixedWidth(105)
        lv:AddColumn("Должность"):SetFixedWidth(130)
        lv:AddColumn("Статус"):SetFixedWidth(70)
        lv:AddColumn("Осталось")

        f.PlayersList = lv

        function f:RefreshPlayers()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local job = P11FW.Jobs[pl.jobId]
                local status = pl.pun == "arrest" and "АРЕСТ" or pl.pun == "slavery" and "РАБСТВО" or pl.pun == "ban" and "БАН" or "—"
                local line = lv:AddLine(pl.nick, pl.doc ~= "" and pl.doc or "—", job and job.name or pl.jobId,
                    status, pl.pun ~= "" and (pl.left .. " мин") or "")
                line.PlayerIdx = pl.idx
            end
        end

        -- панель действий
        local act = vgui.Create("DPanel", p)
        act:SetPos(540, 10)
        act:SetSize(306, 450)
        act.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local title = vgui.Create("DLabel", act)
        title:SetPos(10, 8)
        title:SetSize(286, 22)
        title:SetFont("P11FW.Big")
        title:SetTextColor(AC.text)
        title:SetText("Выбери игрока слева")

        lv.OnRowSelected = function(s, id, line)
            title:SetText("Цель: " .. (line:GetValue(1) or "?"))
        end

        local function SelectedIdx()
            local id = lv:GetSelectedLine()
            if not id then return nil end
            local line = lv:GetLine(id)
            return line and line.PlayerIdx or nil
        end

        -- минуты и причина
        local minsLbl = vgui.Create("DLabel", act)
        minsLbl:SetPos(10, 36) minsLbl:SetSize(150, 18)
        minsLbl:SetFont("P11FW.Small") minsLbl:SetTextColor(AC.dim)
        minsLbl:SetText("Срок (минут):")

        local mins = vgui.Create("DNumberWang", act)
        mins:SetPos(10, 56) mins:SetSize(90, 26)
        mins:SetMinMax(1, 10080) mins:SetValue(5)

        local rsLbl = vgui.Create("DLabel", act)
        rsLbl:SetPos(112, 36) rsLbl:SetSize(180, 18)
        rsLbl:SetFont("P11FW.Small") rsLbl:SetTextColor(AC.dim)
        rsLbl:SetText("Причина:")

        local reason = vgui.Create("DTextEntry", act)
        reason:SetPos(112, 56) reason:SetSize(184, 26)
        reason:SetPlaceholderText("нарушение порядка...")

        -- кнопки наказаний
        local grid = vgui.Create("DIconLayout", act)
        grid:SetPos(10, 92)
        grid:SetSize(286, 200)
        grid:SetSpaceX(6) grid:SetSpaceY(6)

        local function PunishBtn(name, actId, col)
            local b = MakeBtn(grid, name, col, function()
                local idx = SelectedIdx()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                SendAction(actId, function()
                    net.WriteUInt(idx, 8)
                    net.WriteUInt(math.max(1, mins:GetValue()), 16)
                    net.WriteString(reason:GetValue())
                end)
            end)
            b:SetSize(138, 36)
            -- v1.6: спрятать то, чего не позволяет ранг
            local need = (actId == 3) and "ban" or "arrest"
            if not P11FW.CanMod(LocalPlayer(), need) then
                b.PColor = AC.dim
                b:SetEnabled(false)
            end
        end

        PunishBtn("АРЕСТ", 1, Color(255, 130, 110))
        PunishBtn("РАБСТВО", 2, Color(255, 160, 95))
        PunishBtn("БАН", 3, AC.bad)
        PunishBtn("ОСВОБОДИТЬ", 4, AC.ok)

        local dem = MakeBtn(act, "УВОЛИТЬ С ДОЛЖНОСТИ", AC.gold, function()
            local idx = SelectedIdx()
            if not idx then surface.PlaySound("buttons/button10.wav") return end
            SendAction(5, function() net.WriteUInt(idx, 8) end)
        end)
        dem:SetPos(10, 252) dem:SetSize(286, 32)

        -- выдать должность
        local comboLbl = vgui.Create("DLabel", act)
        comboLbl:SetPos(10, 296) comboLbl:SetSize(286, 18)
        comboLbl:SetFont("P11FW.Small") comboLbl:SetTextColor(AC.dim)
        comboLbl:SetText("Выдать должность насильно:")

        local combo = vgui.Create("DComboBox", act)
        combo:SetPos(10, 316) combo:SetSize(286, 28)
        combo:SetValue("— выбери должность —")
        combo.JobIds = {}
        for _, jobId in ipairs(P11FW.JobIds) do
            combo:AddChoice(P11FW.Jobs[jobId].name, jobId)
        end

        local give = MakeBtn(act, "ПРИМЕНИТЬ ДОЛЖНОСТЬ", AC.ok, function()
            local idx = SelectedIdx()
            local _, jobId = combo:GetSelected()
            if not idx or not jobId then surface.PlaySound("buttons/button10.wav") return end
            SendAction(6, function()
                net.WriteUInt(idx, 8)
                net.WriteString(jobId)
            end)
        end)
        give:SetPos(10, 352) give:SetSize(286, 34)

        local refr = MakeBtn(act, "ОБНОВИТЬ СПИСОК", AC.dim, function() RequestAdminData() end)
        refr:SetPos(10, 396) refr:SetSize(286, 30)
    end

    -- ==================================================
    --  ВКЛАДКА: МОДЕРАЦИЯ (варн/мут/кик/бан — права по рангам)
    -- ==================================================
    do
        local p = NewTab("mod")
        local me = LocalPlayer()
        local function Can(perm) return P11FW.CanMod(me, perm) end

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10)
        lv:SetSize(396, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(160)
        lv:AddColumn("Ранг"):SetFixedWidth(112)
        lv:AddColumn("Варны"):SetFixedWidth(55)
        lv:AddColumn("Мут")

        function f:RefreshMod()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local r = P11FW.RankById and P11FW.RankById[pl.rank or "user"]
                local rname = r and r.name or (pl.rank or "user")
                local muteTxt = pl.muted and (pl.muteLeft .. " мин") or "—"
                local line = lv:AddLine(pl.nick, rname, pl.warns or 0, muteTxt)
                if r and r.color then line.Columns[2]:SetTextColor(r.color) end
                if (pl.warns or 0) > 0 then line.Columns[3]:SetTextColor(AC.gold) end
                if pl.muted then line.Columns[4]:SetTextColor(Color(235, 145, 90)) end
                line.PlayerIdx = pl.idx
            end
        end

        local ap = vgui.Create("DPanel", p)
        ap:SetPos(416, 10)
        ap:SetSize(430, 450)
        ap.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local ttl = vgui.Create("DLabel", ap)
        ttl:SetPos(10, 8) ttl:SetSize(410, 22)
        ttl:SetFont("P11FW.Big") ttl:SetTextColor(AC.text)
        ttl:SetText("Цель: — выбери игрока слева")

        lv.OnRowSelected = function(s, id, line)
            ttl:SetText("Цель: " .. (line:GetValue(1) or "?"))
        end

        local function Sel()
            local id = lv:GetSelectedLine()
            if not id then return nil end
            local line = lv:GetLine(id)
            return line and line.PlayerIdx or nil
        end

        local rsLbl = vgui.Create("DLabel", ap)
        rsLbl:SetPos(10, 32) rsLbl:SetSize(410, 16)
        rsLbl:SetFont("P11FW.Small") rsLbl:SetTextColor(AC.dim)
        rsLbl:SetText("Причина (общая для всех кнопок ниже):")

        local reason = vgui.Create("DTextEntry", ap)
        reason:SetPos(10, 50) reason:SetSize(410, 26)
        reason:SetPlaceholderText("например: стрельба по своим / флуд в чат...")

        local mutLbl = vgui.Create("DLabel", ap)
        mutLbl:SetPos(10, 84) mutLbl:SetSize(140, 16)
        mutLbl:SetFont("P11FW.Small") mutLbl:SetTextColor(AC.dim)
        mutLbl:SetText("Минут для МУТА:")

        local mutW = vgui.Create("DNumberWang", ap)
        mutW:SetPos(120, 80) mutW:SetSize(90, 24)
        local mutLim = P11FW.PunishLimit(me, "mute")
        mutW:SetMinMax(1, mutLim and (mutLim > 0 and mutLim or 20160) or 1)
        mutW:SetValue(10)

        -- ---- кнопки простых действий ----
        local function Guarded(col, fn)
            return function()
                local idx = Sel()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                fn(idx)
            end
        end

        local bWarn = MakeBtn(ap, "ВЫДАТЬ ВАРН", AC.gold, Guarded(AC.gold, function(idx)
            SendAction(25, function()
                net.WriteUInt(idx, 8)
                net.WriteString(reason:GetValue())
            end)
        end))
        bWarn:SetPos(10, 112) bWarn:SetSize(202, 32)

        local bMute = MakeBtn(ap, "ЗАМУТИТЬ", Color(235, 145, 90), Guarded(nil, function(idx)
            SendAction(26, function()
                net.WriteUInt(idx, 8)
                net.WriteUInt(math.max(1, mutW:GetValue()), 16)
                net.WriteString(reason:GetValue())
            end)
        end))
        bMute:SetPos(218, 112) bMute:SetSize(202, 32)

        local bUnmute = MakeBtn(ap, "СНЯТЬ МУТ", AC.ok, Guarded(nil, function(idx)
            SendAction(27, function() net.WriteUInt(idx, 8) end)
        end))
        bUnmute:SetPos(10, 148) bUnmute:SetSize(202, 32)

        local bKick = MakeBtn(ap, "КИКНУТЬ", Color(240, 105, 95), Guarded(nil, function(idx)
            SendAction(28, function()
                net.WriteUInt(idx, 8)
                net.WriteString(reason:GetValue())
            end)
        end))
        bKick:SetPos(218, 148) bKick:SetSize(202, 32)

        local bUnwarn = MakeBtn(ap, "ОЧИСТИТЬ ВАРНЫ", Color(170, 195, 140), Guarded(nil, function(idx)
            SendAction(30, function() net.WriteUInt(idx, 8) end)
        end))
        bUnwarn:SetPos(10, 184) bUnwarn:SetSize(202, 32)

        -- ---- секция БАНА ----
        local banHead = vgui.Create("DLabel", ap)
        banHead:SetPos(10, 226) banHead:SetSize(410, 20)
        banHead:SetFont("P11FW.Big") banHead:SetTextColor(AC.bad)
        banHead:SetText("— БАН —")

        local banSub = vgui.Create("DLabel", ap)
        banSub:SetPos(10, 248) banSub:SetSize(410, 14)
        banSub:SetFont("P11FW.Small") banSub:SetTextColor(AC.dim)
        banSub:SetText("Срок: дни / часы / минуты (или галочка навсегда):")

        local banD = vgui.Create("DNumberWang", ap)
        banD:SetPos(50, 268) banD:SetSize(60, 24)
        banD:SetMinMax(0, 365) banD:SetValue(0)
        local dl = vgui.Create("DLabel", ap)
        dl:SetPos(10, 272) dl:SetSize(40, 16)
        dl:SetFont("P11FW.Small") dl:SetTextColor(AC.text) dl:SetText("Дни:")

        local banH = vgui.Create("DNumberWang", ap)
        banH:SetPos(156, 268) banH:SetSize(54, 24)
        banH:SetMinMax(0, 23) banH:SetValue(0)
        local hl = vgui.Create("DLabel", ap)
        hl:SetPos(116, 272) hl:SetSize(40, 16)
        hl:SetFont("P11FW.Small") hl:SetTextColor(AC.text) hl:SetText("Часы:")

        local banM = vgui.Create("DNumberWang", ap)
        banM:SetPos(256, 268) banM:SetSize(54, 24)
        banM:SetMinMax(0, 59) banM:SetValue(30)
        local ml = vgui.Create("DLabel", ap)
        ml:SetPos(216, 272) ml:SetSize(40, 16)
        ml:SetFont("P11FW.Small") ml:SetTextColor(AC.text) ml:SetText("Мин.:")

        local permC = vgui.Create("DCheckBoxLabel", ap)
        permC:SetPos(318, 272) permC:SetSize(102, 16)
        permC:SetFont("P11FW.Small") permC:SetTextColor(AC.bad)
        permC:SetText("НАВСЕГДА")
        permC:SetChecked(false)

        local lim = P11FW.PunishLimit(me, "ban")
        local limLbl = vgui.Create("DLabel", ap)
        limLbl:SetPos(10, 298) limLbl:SetSize(410, 16)
        limLbl:SetFont("P11FW.Small") limLbl:SetTextColor(AC.gold)
        if lim == nil then
            limLbl:SetText("БАН недоступен — нужен ранг Админ (4) и выше.")
        elseif lim == 0 then
            limLbl:SetText("Твой лимит: БЕЗЛИМИТ (можно навсегда).")
        else
            limLbl:SetText("Твой лимит: до " .. P11FW.FmtMinutes(lim) .. " — перманент только у Главы.")
        end

        local bBan = MakeBtn(ap, "ЗАБАНИТЬ", AC.bad, Guarded(nil, function(idx)
            local total = math.floor(banD:GetValue()) * 1440
                + math.floor(banH:GetValue()) * 60
                + math.floor(banM:GetValue())
            if permC:GetChecked() then total = 0 end
            if not permC:GetChecked() and total < 1 then
                surface.PlaySound("buttons/button10.wav")
                return
            end
            SendAction(29, function()
                net.WriteUInt(idx, 8)
                net.WriteUInt(total, 20)
                net.WriteString(reason:GetValue())
            end)
        end))
        bBan:SetPos(10, 318) bBan:SetSize(410, 34)

        -- памятка лестницы прав
        local info = vgui.Create("DLabel", ap)
        info:SetPos(10, 360) info:SetSize(410, 60)
        info:SetFont("P11FW.Small") info:SetTextColor(AC.dim)
        info:SetAutoStretchVertical(true)
        info:SetText("Лестница прав: Хелпер — варн + мут до 30 мин.;\n" ..
            "Модератор — кик, арест до 1 ч., мут до 4 ч.;\n" ..
            "Админ — бан до 3 сут.; Куратор — 7 сут.;\n" ..
            "Суперадмин — 30 сут. + разбан; Глава — навсегда.")

        -- серые кнопки по правам
        local function Gate(btn, perm)
            if not Can(perm) then
                btn.PColor = AC.dim
                btn:SetEnabled(false)
            end
        end
        Gate(bWarn, "warn")   Gate(bMute, "mute")  Gate(bUnmute, "mute")
        Gate(bUnwarn, "warn") Gate(bKick, "kick")  Gate(bBan, "ban")
        if not Can("mute") then mutW:SetEnabled(false) end
        if not Can("ban") then
            banD:SetEnabled(false) banH:SetEnabled(false) banM:SetEnabled(false)
        end
        if lim ~= 0 then permC:SetEnabled(false) end

        local refr = MakeBtn(ap, "ОБНОВИТЬ СПИСОК", AC.dim, function() RequestAdminData() end)
        refr:SetPos(10, 418) refr:SetSize(410, 26)
    end

    -- ==================================================
    --  ВКЛАДКА 2: ДОЛЖНОСТИ (редактор профессий)
    -- ==================================================
    do
        local p = NewTab("jobs")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10) lv:SetSize(360, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Должность"):SetFixedWidth(150)
        lv:AddColumn("Фракция"):SetFixedWidth(110)
        lv:AddColumn("Мест"):SetFixedWidth(45)
        lv:AddColumn("Тип")
        f.JobsList = lv

        function f:RefreshJobsTab()
            lv:Clear()
            for _, jobId in ipairs(P11FW.JobIds) do
                local job = P11FW.Jobs[jobId]
                local catName = job.category
                for _, c in ipairs(P11FW.CategoryList) do
                    if c.id == job.category then catName = c.name end
                end
                local line = lv:AddLine(job.name, catName, (job.max or 0) > 0 and job.max or "∞",
                    job.custom and "КАСТОМ" or "встроенная")
                line.JobId = jobId
            end
        end
        f:RefreshJobsTab()

        -- форма
        local form = vgui.Create("DPanel", p)
        form:SetPos(380, 10) form:SetSize(466, 450)
        form.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local function Lbl(txt, x, y)
            local l = vgui.Create("DLabel", form)
            l:SetPos(x, y) l:SetSize(300, 16)
            l:SetFont("P11FW.Small") l:SetTextColor(AC.dim)
            l:SetText(txt)
            return l
        end

        Lbl("Название должности:", 10, 8)
        local nameE = vgui.Create("DTextEntry", form)
        nameE:SetPos(10, 26) nameE:SetSize(280, 26)
        nameE:SetPlaceholderText("Киномеханик")

        Lbl("Фракция:", 300, 8)
        local catC = vgui.Create("DComboBox", form)
        catC:SetPos(300, 26) catC:SetSize(156, 26)
        for _, c in ipairs(P11FW.CategoryList) do
            catC:AddChoice(c.name, c.id)
        end
        catC:SetValue(P11FW.CategoryList[3] and P11FW.CategoryList[3].name or "misc")

        Lbl("Мест (0 = без лимита):", 10, 58)
        local maxW = vgui.Create("DNumberWang", form)
        maxW:SetPos(10, 76) maxW:SetSize(80, 26)
        maxW:SetMinMax(0, 32) maxW:SetValue(0)

        Lbl("Цвет (R/G/B):", 100, 58)
        local colors = {}
        for i, cname in ipairs({ "R", "G", "B" }) do
            local s = vgui.Create("DNumSlider", form)
            s:SetPos(100 + (i - 1) * 120, 66) s:SetSize(110, 22)
            s:SetText(cname) s:SetMin(0) s:SetMax(255) s:SetDecimals(0)
            s:SetValue(i == 1 and 210 or i == 2 and 170 or 120)
            colors[i] = s
        end

        Lbl("Модели (по одной через запятую):", 10, 108)
        local modelsE = vgui.Create("DTextEntry", form)
        modelsE:SetPos(10, 126) modelsE:SetSize(360, 52)
        modelsE:SetMultiline(true)
        modelsE:SetPlaceholderText("models/player/kleiner.mdl, models/player/eli.mdl")

        local addMyModel = MakeBtn(form, "+ МОЯ МОДЕЛЬ", AC.accent, function()
            local m = LocalPlayer():GetModel()
            local cur = string.Trim(modelsE:GetValue())
            modelsE:SetValue(cur == "" and m or (cur .. ", " .. m))
        end)
        addMyModel:SetPos(376, 126) addMyModel:SetSize(80, 24)

        Lbl("Оружие (классы через запятую):", 10, 186)
        local wepsE = vgui.Create("DTextEntry", form)
        wepsE:SetPos(10, 204) wepsE:SetSize(360, 52)
        wepsE:SetMultiline(true)
        wepsE:SetPlaceholderText("weapon_polus11_radio, weapon_pistol")

        local addMyWep = MakeBtn(form, "+ ОРУЖИЕ В РУКАХ", AC.accent, function()
            local w = LocalPlayer():GetActiveWeapon()
            if not IsValid(w) then return end
            local cls = w:GetClass()
            local cur = string.Trim(wepsE:GetValue())
            wepsE:SetValue(cur == "" and cls or (cur .. ", " .. cls))
        end)
        addMyWep:SetPos(376, 204) addMyWep:SetSize(80, 24)

        Lbl("Описание (видно в F4):", 10, 262)
        local descE = vgui.Create("DTextEntry", form)
        descE:SetPos(10, 280) descE:SetSize(446, 74)
        descE:SetMultiline(true)
        descE:SetPlaceholderText("Что делает эта должность на станции...")

        -- v1.5: допуск к сменному терминалу
        local termC = vgui.Create("DCheckBoxLabel", form)
        termC:SetPos(10, 358) termC:SetSize(440, 18)
        termC:SetFont("P11FW.Small") termC:SetTextColor(Color(120, 210, 240))
        termC:SetText("Допуск к СМЕННОМУ ТЕРМИНАЛУ (выдача доп-задач экипажу)")
        termC:SetChecked(false)

        -- выбранная строка списка → заполнить форму
        local editingId = nil
        local status = vgui.Create("DLabel", form)
        status:SetPos(10, 378) status:SetSize(446, 18)
        status:SetFont("P11FW.Small") status:SetTextColor(AC.gold)
        status:SetText("Новая должность (или выбери КАСТОМ из списка для правки)")

        local function CollectForm()
            local _, catId = catC:GetSelected()
            return {
                name     = nameE:GetValue(),
                category = catId or "misc",
                desc     = descE:GetValue(),
                max      = maxW:GetValue(),
                terminal = termC:GetChecked(),
                color    = { r = colors[1]:GetValue(), g = colors[2]:GetValue(), b = colors[3]:GetValue() },
                models   = ParseListEntry(modelsE:GetValue()),
                weapons  = ParseListEntry(wepsE:GetValue()),
            }
        end

        lv.OnRowSelected = function(s, id, line)
            local jobId = line.JobId
            local job = P11FW.Jobs[jobId]
            if not job then return end
            nameE:SetValue(job.name)
            descE:SetValue(job.desc or "")
            maxW:SetValue(job.max or 0)
            modelsE:SetValue(table.concat(job.models or {}, ", "))
            wepsE:SetValue(table.concat(job.weapons or {}, ", "))
            for _, c in ipairs(P11FW.CategoryList) do
                if c.id == job.category then catC:SetValue(c.name) end
            end
            if job.color then
                colors[1]:SetValue(job.color.r) colors[2]:SetValue(job.color.g) colors[3]:SetValue(job.color.b)
            end
            termC:SetChecked(job.terminal == true)
            editingId = job.custom and jobId or nil
            status:SetText(job.custom and ("Правим КАСТОМНУЮ: " .. job.name) or "ВСТРОЕННАЯ — можно только скопировать в новую")
        end

        local btnCreate = MakeBtn(form, "СОЗДАТЬ НОВУЮ", AC.ok, function()
            local rec = CollectForm()
            if string.Trim(rec.name) == "" then status:SetText("⚠ впиши название!") surface.PlaySound("buttons/button10.wav") return end
            SendJobEdit(1, rec)
            status:SetText("Отправлено на сервер...")
        end)
        btnCreate:SetPos(10, 402) btnCreate:SetSize(146, 40)

        local btnUpdate = MakeBtn(form, "СОХРАНИТЬ ПРАВКУ", AC.accent, function()
            if not editingId then status:SetText("⚠ это встроенная или не выбрана кастомная!") surface.PlaySound("buttons/button10.wav") return end
            local rec = CollectForm()
            rec.id = editingId
            SendJobEdit(2, rec)
        end)
        btnUpdate:SetPos(162, 402) btnUpdate:SetSize(146, 40)

        local btnDelete = MakeBtn(form, "УДАЛИТЬ", AC.bad, function()
            if not editingId then status:SetText("⚠ удалить можно только кастомную!") surface.PlaySound("buttons/button10.wav") return end
            SendJobEdit(3, { id = editingId })
            editingId = nil
        end)
        btnDelete:SetPos(314, 402) btnDelete:SetSize(142, 40)

        -- авто-обновление списка при синке с сервера
        f.JobsTabStatus = status
    end

    -- ==================================================
    --  ВКЛАДКА: ДЕЙСТВИЯ С ИГРОКОМ (лечить/возродить/тп/заморозить)
    -- ==================================================
    do
        local p = NewTab("acts")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10) lv:SetSize(430, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Ник"):SetFixedWidth(180)
        lv:AddColumn("Должность"):SetFixedWidth(160)
        lv:AddColumn("Статус")

        function f:RefreshActs()
            lv:Clear()
            for _, pl in ipairs((self.AdminData and self.AdminData.players) or {}) do
                local job = P11FW.Jobs[pl.jobId]
                local status = pl.pun == "arrest" and "АРЕСТ" or pl.pun == "slavery" and "РАБСТВО" or pl.pun == "ban" and "БАН" or "—"
                local line = lv:AddLine(pl.nick, job and job.name or pl.jobId, status)
                line.PlayerIdx = pl.idx
            end
        end

        local ap = vgui.Create("DPanel", p)
        ap:SetPos(450, 10) ap:SetSize(396, 450)
        ap.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local ttl = vgui.Create("DLabel", ap)
        ttl:SetPos(12, 8) ttl:SetSize(370, 22)
        ttl:SetFont("P11FW.Big") ttl:SetTextColor(AC.text)
        ttl:SetText("Цель: —")

        lv.OnRowSelected = function(s, id, line)
            ttl:SetText("Цель: " .. (line:GetValue(1) or "?"))
        end

        local function Sel()
            local id = lv:GetSelectedLine()
            if not id then return nil end
            local line = lv:GetLine(id)
            return line and line.PlayerIdx or nil
        end

        local hint = vgui.Create("DLabel", ap)
        hint:SetPos(12, 32) hint:SetSize(370, 34)
        hint:SetFont("P11FW.Small") hint:SetTextColor(AC.dim)
        hint:SetText("Быстрые рабочие действия. Выбери игрока слева,\nпотом жми кнопку. Никаких сроков и записей.")

        local grid = vgui.Create("DIconLayout", ap)
        grid:SetPos(12, 76) grid:SetSize(372, 340)
        grid:SetSpaceX(6) grid:SetSpaceY(6)

        local canHeal = P11FW.CanMod(LocalPlayer(), "heal")

        local function ActBtn(name, actId, col)
            local b = MakeBtn(grid, name, col, function()
                local idx = Sel()
                if not idx then surface.PlaySound("buttons/button10.wav") return end
                SendAction(actId, function() net.WriteUInt(idx, 8) end)
            end)
            b:SetSize(180, 44)
            if not canHeal then -- v1.6: быстрые действия — с ранга Админ (4)
                b.PColor = AC.dim
                b:SetEnabled(false)
            end
        end

        ActBtn("ЛЕЧИТЬ ПОЛНОСТЬЮ", 14, AC.ok)
        ActBtn("ВОЗРОДИТЬ",       15, Color(230, 200, 120))
        ActBtn("ПРИТАЩИТЬ К СЕБЕ",16, Color(150, 190, 240))
        ActBtn("ТЕЛЕПОРТ К НЕМУ", 17, Color(150, 190, 240))
        ActBtn("ЗАМОРОЗИТЬ/РАЗМ.",18, Color(170, 175, 190))
        ActBtn("УБИТЬ",           19, AC.bad)

        -- v1.5: выдача рангов (сервер пустит только Куратор+)
        local rankLbl = vgui.Create("DLabel", ap)
        rankLbl:SetPos(12, 246) rankLbl:SetSize(372, 16)
        rankLbl:SetFont("P11FW.Small") rankLbl:SetTextColor(AC.gold)
        rankLbl:SetText("РАНГ АДМИНИСТРАЦИИ (User→VIP→Хелпер→…→Глава Полюса-11):")

        local rankC = vgui.Create("DComboBox", ap)
        rankC:SetPos(12, 264) rankC:SetSize(372, 26)
        rankC:SetValue("— выбери ранг —")
        for _, r in ipairs(P11FW.Ranks or {}) do
            local function paintChoice(self2, w, h) end
            rankC:AddChoice(r.name .. "  [" .. r.level .. "]", r.id, false, "")
        end

        local rankBtn = MakeBtn(ap, "ВЫДАТЬ РАНГ ВЫБРАННОМУ", AC.gold, function()
            local idx = Sel()
            local _, rid = rankC:GetSelected()
            if not idx or not rid then surface.PlaySound("buttons/button10.wav") return end
            SendAction(22, function()
                net.WriteUInt(idx, 8)
                net.WriteString(rid)
            end)
        end)
        rankBtn:SetPos(12, 298) rankBtn:SetSize(372, 30)
        if not (P11FW.CanManageRank and P11FW.CanManageRank(LocalPlayer(), nil)) then
            rankBtn.PColor = AC.dim
            rankBtn:SetEnabled(false)
        end

        local rankNote = vgui.Create("DLabel", ap)
        rankNote:SetPos(12, 334) rankNote:SetSize(372, 60)
        rankNote:SetFont("P11FW.Small") rankNote:SetTextColor(AC.dim)
        rankNote:SetText("Выдать может Куратор+ (ниже своего ранга).\n" ..
            "Секрет основателя: p11_access <ключ> в консоли\n(ключ меняется в fw_sh_config.lua).")
        rankNote:SetAutoStretchVertical(true)

        local refr = MakeBtn(ap, "ОБНОВИТЬ СПИСОК", AC.dim, function() RequestAdminData() end)
        refr:SetPos(12, 408) refr:SetSize(372, 30)
    end

    -- ==================================================
    --  ВКЛАДКА: ФРАКЦИИ (создание своих групп персонала)
    -- ==================================================
    do
        local p = NewTab("factions")

        local lv = vgui.Create("DListView", p)
        lv:SetPos(10, 10) lv:SetSize(380, 450)
        lv:SetMultiSelect(false)
        lv:AddColumn("Фракция"):SetFixedWidth(150)
        lv:AddColumn("Должностей"):SetFixedWidth(80)
        lv:AddColumn("Тип")

        function f:RefreshFactions()
            lv:Clear()
            for _, cat in ipairs(P11FW.CategoryList or {}) do
                local jobs = 0
                for _, jid in ipairs(P11FW.JobIds or {}) do
                    local jb = P11FW.Jobs[jid]
                    if jb and (jb.faction or jb.category) == cat.id then jobs = jobs + 1 end
                end
                local line = lv:AddLine(cat.name, jobs, cat.custom and "КАСТОМ" or "встроенная")
                line.CatId   = cat.id
                line.CatData = cat
            end
        end
        f:RefreshFactions()

        local form = vgui.Create("DPanel", p)
        form:SetPos(400, 10) form:SetSize(446, 450)
        form.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, AC.panel2) end

        local function Lbl(txt, x, y)
            local l = vgui.Create("DLabel", form)
            l:SetPos(x, y) l:SetSize(300, 16)
            l:SetFont("P11FW.Small") l:SetTextColor(AC.dim)
            l:SetText(txt)
            return l
        end

        f.SelFactionId = nil

        Lbl("Название фракции:", 10, 8)
        local nameE = vgui.Create("DTextEntry", form)
        nameE:SetPos(10, 26) nameE:SetSize(280, 26)
        nameE:SetPlaceholderText("МЕДИКИ / ЛЁТНЫЙ СОСТАВ / КОНВОЙ...")

        Lbl("Порядок в меню:", 300, 8)
        local orderW = vgui.Create("DNumberWang", form)
        orderW:SetPos(300, 26) orderW:SetSize(60, 26)
        orderW:SetMinMax(1, 999) orderW:SetValue(50)

        Lbl("Цвет (R/G/B):", 10, 58)
        local colors = {}
        for i, cname in ipairs({ "R", "G", "B" }) do
            local s = vgui.Create("DNumSlider", form)
            s:SetPos(10 + (i - 1) * 146, 66) s:SetSize(138, 22)
            s:SetText(cname) s:SetMin(0) s:SetMax(255) s:SetDecimals(0)
            s:SetValue(i == 1 and 200 or i == 2 and 160 or 110)
            colors[i] = s
        end

        -- v1.7: живой превью-чип (цвет + id) — как будет выглядеть секция
        local prev = vgui.Create("DPanel", form)
        prev:SetPos(368, 8) prev:SetSize(88, 44)
        prev.SelText = "новая"
        prev.Paint = function(s, w, h)
            local r = math.floor(colors[1]:GetValue())
            local g = math.floor(colors[2]:GetValue())
            local b = math.floor(colors[3]:GetValue())
            draw.RoundedBox(6, 0, 0, w, h, Color(r, g, b, 42))
            draw.RoundedBoxEx(6, 0, 0, 3, h, Color(r, g, b), true, false, true, false)
            draw.SimpleText(s.SelText, "P11FW.Small", w / 2 + 1, h / 2 - 8,
                Color(r, g, b), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("превью", "P11FW.Small", w / 2 + 1, h / 2 + 9,
                Color(r, g, b, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        Lbl("Описание (для админов):", 10, 108)
        local descE = vgui.Create("DTextEntry", form)
        descE:SetPos(10, 126) descE:SetSize(426, 70)
        descE:SetMultiline(true)
        descE:SetPlaceholderText("Кто входит во фракцию и чем занимается...")

        lv.OnRowSelected = function(s, id, line)
            f.SelFactionId = line.CatData.custom and line.CatId or nil
            nameE:SetValue(line.CatData.name or "")
            descE:SetValue(line.CatData.desc or "")
            orderW:SetValue(line.CatData.order or 50)
            colors[1]:SetValue(line.CatData.color.r)
            colors[2]:SetValue(line.CatData.color.g)
            colors[3]:SetValue(line.CatData.color.b)
            prev.SelText = line.CatData.custom and line.CatId or "встроенная"
        end

        local newB = MakeBtn(form, "НОВАЯ ФОРМА", AC.dim, function()
            f.SelFactionId = nil
            nameE:SetValue("") descE:SetValue("") orderW:SetValue(50)
            prev.SelText = "новая"
        end)
        newB:SetPos(10, 210) newB:SetSize(206, 30)

        local function Collect()
            return {
                id    = f.SelFactionId,
                name  = string.Trim(nameE:GetValue()),
                desc  = descE:GetValue(),
                order = orderW:GetValue(),
                color = { r = colors[1]:GetValue(), g = colors[2]:GetValue(), b = colors[3]:GetValue() },
            }
        end

        local saveB = MakeBtn(form, "СОЗДАТЬ / СОХРАНИТЬ", AC.ok, function()
            SendAction(20, function() net.WriteString(util.TableToJSON(Collect()) or "{}") end)
        end)
        saveB:SetPos(226, 210) saveB:SetSize(210, 30)

        local delB = MakeBtn(form, "УДАЛИТЬ (только кастом)", AC.bad, function()
            if not f.SelFactionId then surface.PlaySound("buttons/button10.wav") return end
            SendAction(21, function() net.WriteString(f.SelFactionId) end)
        end)
        delB:SetPos(10, 250) delB:SetSize(426, 30)

        local note = vgui.Create("DLabel", form)
        note:SetPos(10, 292) note:SetSize(426, 120)
        note:SetFont("P11FW.Small") note:SetTextColor(AC.dim)
        note:SetAutoStretchVertical(true)
        note:SetText("Фракция — это группа должностей.\n" ..
            "После создания она появится в редакторе ДОЛЖНОСТЕЙ\n" ..
            "(поле «Фракция»), в F4 и в табе вопросов (TAB)\n" ..
            "как цветная секция. Сохраняется навсегда:")
        local note2 = vgui.Create("DLabel", form)
        note2:SetPos(10, 372) note2:SetSize(426, 20)
        note2:SetFont("P11FW.Small") note2:SetTextColor(AC.gold)
        note2:SetText("data/polus_framework/factions.json")
    end

    -- ==================================================
    --  ВКЛАДКА 3: УТИЛИТЫ СТАНЦИИ
    -- ==================================================
    do
        local p = NewTab("utils")

        local function UtilRow(y, name, desc, btn1, cb1, btn2, cb2)
            local rowState = vgui.Create("DLabel", p)
            rowState:SetPos(10, y) rowState:SetSize(320, 26)
            rowState:SetFont("P11FW.Big") rowState:SetTextColor(AC.text)

            local d = vgui.Create("DLabel", p)
            d:SetPos(10, y + 26) d:SetSize(420, 16)
            d:SetFont("P11FW.Small") d:SetTextColor(AC.dim)
            d:SetText(desc)

            local b1 = MakeBtn(p, btn1, AC.ok, cb1)
            b1:SetPos(440, y + 8) b1:SetSize(200, 34)
            local b2 = MakeBtn(p, btn2, AC.bad, cb2)
            b2:SetPos(648, y + 8) b2:SetSize(198, 34)
            return rowState
        end

        f.UtilLabels = {}

        f.UtilLabels.spawn = UtilRow(14, "Точка спавна гарнизона", "все игроки появляются в этой точке (с сохранением на карту)",
            "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(7) end,
            "УБРАТЬ", function() SendAction(8) end)

        f.UtilLabels.jail = UtilRow(72, "Камера ареста", "арестованных телепортирует сюда (без точки — заморозка на месте)",
            "ПОСТАВИТЬ ЗДЕСЬ", function() SendAction(9) end,
            "УБРАТЬ", function() SendAction(10) end)

        f.UtilLabels.npc = UtilRow(130, "Кадровик", "NPC выдачи профессий — создать перед собой / убрать ближайшего",
            "СОЗДАТЬ", function() SendAction(11) end,
            "УДАЛИТЬ БЛИЖ.", function() SendAction(12) end)

        f.UtilLabels.term = UtilRow(186, "Сменный терминал", "консоль выдачи ДОП-ЗАДАЧ экипажу (persist на карту), поставить перед собой",
            "ПОСТАВИТЬ", function() SendAction(23) end,
            "УБРАТЬ БЛИЖ.", function() SendAction(24) end)

        -- бан-лист
        local banLbl = vgui.Create("DLabel", p)
        banLbl:SetPos(10, 246) banLbl:SetSize(400, 22)
        banLbl:SetFont("P11FW.Big") banLbl:SetTextColor(AC.text)
        banLbl:SetText("БАН-ЛИСТ СТАНЦИИ")

        local bans = vgui.Create("DListView", p)
        bans:SetPos(10, 270) bans:SetSize(626, 148)
        bans:SetMultiSelect(false)
        bans:AddColumn("SteamID64"):SetFixedWidth(160)
        bans:AddColumn("Ник"):SetFixedWidth(140)
        bans:AddColumn("До"):SetFixedWidth(110)
        bans:AddColumn("Причина")
        f.BansList = bans

        local unban = MakeBtn(p, "СНЯТЬ БАН ВЫБРАННОМУ", AC.ok, function()
            local id = bans:GetSelectedLine()
            if not id then surface.PlaySound("buttons/button10.wav") return end
            local line = bans:GetLine(id)
            if line and line.SID then
                SendAction(13, function() net.WriteString(line.SID) end)
            end
        end)
        unban:SetPos(10, 424) unban:SetSize(300, 34)
        if not P11FW.CanMod(LocalPlayer(), "unban") then
            unban.PColor = AC.dim
            unban:SetEnabled(false)
        end

        local refr = MakeBtn(p, "ОБНОВИТЬ", AC.dim, function() RequestAdminData() end)
        refr:SetPos(648, 424) refr:SetSize(198, 34)

        function f:RefreshUtils()
            local d = self.AdminData
            if not d then return end
            f.UtilLabels.spawn:SetText("Точка спавна гарнизона: " .. (d.spawnSet and "УСТАНОВЛЕНА" or "не задана"))
            f.UtilLabels.jail:SetText("Камера ареста: " .. (d.jailSet and "УСТАНОВЛЕНА" or "не задана (заморозка на месте)"))
            f.UtilLabels.spawn:SetTextColor(d.spawnSet and AC.ok or AC.text)
            f.UtilLabels.jail:SetTextColor(d.jailSet and AC.ok or AC.text)

            bans:Clear()
            for _, b in ipairs(d.bans) do
                local untilTxt = (b.until_ or 0) == 0 and "НАВСЕГДА" or os.date("%d.%m %H:%M", b.until_)
                local line = bans:AddLine(b.sid, b.nick, untilTxt, b.reason)
                line.SID = b.sid
            end
        end
    end

    -- первая загрузка данных
    RequestAdminData()
end

concommand.Add("p11fw_admin", function()
    P11FW.OpenAdminMenu()
end)
